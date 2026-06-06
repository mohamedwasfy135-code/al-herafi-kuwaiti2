import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'
import { logAudit } from '@/lib/audit'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    const status = searchParams.get('status') || ''

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const where: Record<string, unknown> = { businessId }

    if (status) {
      where.status = status
    }

    const invoices = await db.purchaseInvoice.findMany({
      where,
      include: {
        business: {
          select: { id: true, name: true, phone: true, address: true, logoUrl: true },
        },
        supplier: {
          select: { id: true, name: true, phone: true, address: true },
        },
        items: {
          include: {
            product: {
              select: { id: true, name: true, sku: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json(invoices)
  } catch (error) {
    console.error('Error fetching purchase invoices:', error)
    return NextResponse.json(
      { error: 'Failed to fetch purchase invoices' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      supplierId,
      supplierName,
      supplierPhone,
      items,
      discountAmount,
      taxAmount,
      paidAmount,
      status,
      paymentMethod,
      paymentDate,
      dueDate,
      notes,
    } = body

    if (!rawBusinessId) {
      return NextResponse.json(
        { error: 'businessId and items are required' },
        { status: 400 }
      )
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    if (!items || items.length === 0) {
      return NextResponse.json(
        { error: 'businessId and items are required' },
        { status: 400 }
      )
    }

    // Calculate totals
    const subtotal = items.reduce(
      (sum: number, item: { total?: number; unitPrice?: number; quantity?: number; discountAmount?: number }) => {
        if (item.total) return sum + item.total
        const lineTotal = (item.unitPrice || 0) * (item.quantity || 1) - (item.discountAmount || 0)
        return sum + lineTotal
      },
      0
    )

    const totalDiscount = discountAmount ? parseFloat(String(discountAmount)) : 0
    const totalTax = taxAmount ? parseFloat(String(taxAmount)) : 0
    const total = subtotal - totalDiscount + totalTax

    // Determine status
    const paid = paidAmount ? parseFloat(String(paidAmount)) : 0
    let invoiceStatus: string
    if (status) {
      invoiceStatus = status
    } else if (paid >= total && total > 0) {
      invoiceStatus = 'paid'
    } else if (paid > 0) {
      invoiceStatus = 'partial'
    } else {
      invoiceStatus = 'unpaid'
    }

    // Generate invoice number
    const count = await db.purchaseInvoice.count({
      where: { businessId },
    })
    const invoiceNumber = `PI-${String(count + 1).padStart(5, '0')}`

    // Resolve supplier ID if provided as string
    let resolvedSupplierId: number | undefined = undefined
    if (supplierId) {
      resolvedSupplierId = parseInt(String(supplierId))
    }

    const invoice = await db.purchaseInvoice.create({
      data: {
        businessId,
        invoiceNumber,
        supplierId: resolvedSupplierId || null,
        supplierName,
        supplierPhone,
        subtotal,
        taxAmount: totalTax,
        total,
        status: invoiceStatus,
        paidAmount: paid,
        paymentMethod: paymentMethod || null,
        paymentDate: paymentDate ? new Date(paymentDate) : null,
        dueDate: dueDate ? new Date(dueDate) : (paymentDate ? new Date(paymentDate) : null),
        notes,
        items: {
          create: items.map(
            (item: {
              productId?: number
              description?: string
              quantity?: number
              unitPrice?: number
              discountAmount?: number
              total?: number
            }) => ({
              productId: item.productId ? parseInt(String(item.productId)) : null,
              description: item.description,
              quantity: item.quantity || 1,
              unitPrice: item.unitPrice || 0,
              total:
                item.total ||
                (item.unitPrice || 0) * (item.quantity || 1) - (item.discountAmount || 0),
            })
          ),
        },
      },
      include: {
        items: {
          include: {
            product: {
              select: { id: true, name: true, sku: true },
            },
          },
        },
      },
    })

    // ─── Increase stock for each product and create ProductMovement records ───
    for (const item of items) {
      if (item.productId) {
        const productId = parseInt(String(item.productId))
        const qty = item.quantity ? parseInt(String(item.quantity)) : 1

        // Increase stock
        try {
          await db.product.update({
            where: { id: productId },
            data: {
              stockQuantity: {
                increment: qty,
              },
            },
          })
        } catch (err) {
          console.error(`Failed to update stock for product ${productId}:`, err)
        }

        // Create ProductMovement record
        try {
          await db.productMovement.create({
            data: {
              productId,
              businessId,
              movementType: 'purchase',
              quantity: qty,
              referenceType: 'purchase_invoice',
              referenceId: invoice.id,
              notes: `فاتورة شراء ${invoiceNumber}`,
            },
          })
        } catch (err) {
          console.error(`Failed to create product movement for product ${productId}:`, err)
        }
      }
    }

    await logAudit({
      businessId,
      action: 'CREATE',
      entity: 'PurchaseInvoice',
      entityId: invoice.id,
      changes: { after: { invoiceNumber: invoice.invoiceNumber, total: invoice.total, supplierName: invoice.supplierName } },
    })

    return NextResponse.json(invoice, { status: 201 })
  } catch (error) {
    console.error('Error creating purchase invoice:', error)
    return NextResponse.json(
      { error: 'Failed to create purchase invoice' },
      { status: 500 }
    )
  }
}
