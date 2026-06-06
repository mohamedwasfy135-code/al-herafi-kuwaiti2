import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'
import { logAudit } from '@/lib/audit'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const quoteId = parseInt(id)

    const quote = await db.priceQuote.findUnique({
      where: { id: quoteId },
      include: {
        business: {
          select: { id: true, name: true, phone: true, address: true, logoUrl: true },
        },
        items: {
          include: {
            product: {
              select: { id: true, name: true, sku: true },
            },
          },
        },
        convertedToInvoice: {
          select: { id: true, invoiceNumber: true },
        },
      },
    })

    if (!quote) {
      return NextResponse.json({ error: 'Price quote not found' }, { status: 404 })
    }

    return NextResponse.json(quote)
  } catch (error) {
    console.error('Error fetching price quote:', error)
    return NextResponse.json(
      { error: 'Failed to fetch price quote' },
      { status: 500 }
    )
  }
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const quoteId = parseInt(id)
    const body = await request.json()

    const existing = await db.priceQuote.findUnique({
      where: { id: quoteId },
    })
    if (!existing) {
      return NextResponse.json({ error: 'Price quote not found' }, { status: 404 })
    }

    if (existing.status === 'converted') {
      return NextResponse.json({ error: 'Cannot edit a converted quote' }, { status: 400 })
    }

    const updateData: Record<string, unknown> = {}

    // Simple field updates
    if (body.status !== undefined) updateData.status = body.status
    if (body.clientName !== undefined) updateData.clientName = body.clientName
    if (body.clientPhone !== undefined) updateData.clientPhone = body.clientPhone
    if (body.clientId !== undefined) updateData.clientId = body.clientId ? parseInt(String(body.clientId)) : null
    if (body.notes !== undefined) updateData.notes = body.notes
    if (body.validUntil !== undefined) updateData.validUntil = body.validUntil ? new Date(body.validUntil) : null
    if (body.discountAmount !== undefined) updateData.discountAmount = parseFloat(String(body.discountAmount))
    if (body.taxAmount !== undefined) updateData.taxAmount = parseFloat(String(body.taxAmount))

    // If items are provided, replace them
    if (body.items && Array.isArray(body.items)) {
      const subtotal = body.items.reduce(
        (sum: number, item: { total?: number; unitPrice?: number; quantity?: number; discountAmount?: number }) => {
          if (item.total) return sum + item.total
          const lineTotal =
            (item.unitPrice || 0) * (item.quantity || 1) - (item.discountAmount || 0)
          return sum + lineTotal
        },
        0
      )

      const totalDiscount = body.discountAmount ? parseFloat(String(body.discountAmount)) : existing.discountAmount
      const totalTax = body.taxAmount ? parseFloat(String(body.taxAmount)) : existing.taxAmount
      const total = subtotal - totalDiscount + totalTax

      updateData.subtotal = subtotal
      updateData.total = total

      // Delete old items and create new ones
      await db.priceQuoteItem.deleteMany({ where: { quoteId } })

      const updatedQuote = await db.priceQuote.update({
        where: { id: quoteId },
        data: {
          ...updateData,
          items: {
            create: body.items.map(
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
                discountAmount: item.discountAmount || 0,
                total:
                  item.total ||
                  (item.unitPrice || 0) * (item.quantity || 1) -
                    (item.discountAmount || 0),
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

      await logAudit({
        businessId: existing.businessId,
        action: 'UPDATE',
        entity: 'PriceQuote',
        entityId: quoteId,
        changes: { after: { quoteNumber: existing.quoteNumber, status: updatedQuote.status } },
      })

      return NextResponse.json(updatedQuote)
    }

    // Recalculate total if discount/tax changed without items
    if (body.discountAmount !== undefined || body.taxAmount !== undefined) {
      const totalDiscount = body.discountAmount !== undefined ? parseFloat(String(body.discountAmount)) : existing.discountAmount
      const totalTax = body.taxAmount !== undefined ? parseFloat(String(body.taxAmount)) : existing.taxAmount
      updateData.total = existing.subtotal - totalDiscount + totalTax
    }

    const updatedQuote = await db.priceQuote.update({
      where: { id: quoteId },
      data: updateData,
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

    await logAudit({
      businessId: existing.businessId,
      action: 'UPDATE',
      entity: 'PriceQuote',
      entityId: quoteId,
      changes: { after: { quoteNumber: existing.quoteNumber, status: updatedQuote.status } },
    })

    return NextResponse.json(updatedQuote)
  } catch (error) {
    console.error('Error updating price quote:', error)
    return NextResponse.json(
      { error: 'Failed to update price quote' },
      { status: 500 }
    )
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const quoteId = parseInt(id)

    const existing = await db.priceQuote.findUnique({
      where: { id: quoteId },
    })
    if (!existing) {
      return NextResponse.json({ error: 'Price quote not found' }, { status: 404 })
    }

    if (existing.status === 'converted') {
      return NextResponse.json({ error: 'Cannot delete a converted quote' }, { status: 400 })
    }

    // Delete items first, then quote
    await db.priceQuoteItem.deleteMany({ where: { quoteId } })
    await db.priceQuote.delete({ where: { id: quoteId } })

    await logAudit({
      businessId: existing.businessId,
      action: 'DELETE',
      entity: 'PriceQuote',
      entityId: quoteId,
      changes: { before: { quoteNumber: existing.quoteNumber, total: existing.total } },
    })

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Error deleting price quote:', error)
    return NextResponse.json(
      { error: 'Failed to delete price quote' },
      { status: 500 }
    )
  }
}

// POST with action="convert" - Convert quote to sales invoice
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const quoteId = parseInt(id)
    const body = await request.json()
    const { action } = body

    if (action !== 'convert') {
      return NextResponse.json({ error: 'Invalid action' }, { status: 400 })
    }

    const quote = await db.priceQuote.findUnique({
      where: { id: quoteId },
      include: {
        items: {
          include: {
            product: {
              select: { id: true, name: true, sku: true, stockQuantity: true },
            },
          },
        },
      },
    })

    if (!quote) {
      return NextResponse.json({ error: 'Price quote not found' }, { status: 404 })
    }

    if (quote.status === 'converted') {
      return NextResponse.json({ error: 'Quote already converted' }, { status: 400 })
    }

    // Use transaction to create invoice + update quote atomically
    const result = await db.$transaction(async (tx) => {
      // Generate invoice number
      const businessId = quote.businessId
      const count = await tx.salesInvoice.count({ where: { businessId } })
      const invoiceNumber = `SI-${String(count + 1).padStart(5, '0')}`

      // Create SalesInvoice from quote items
      const invoice = await tx.salesInvoice.create({
        data: {
          businessId,
          invoiceNumber,
          clientId: quote.clientId,
          clientName: quote.clientName,
          clientPhone: quote.clientPhone,
          subtotal: quote.subtotal,
          discountAmount: quote.discountAmount,
          taxAmount: quote.taxAmount,
          total: quote.total,
          paidAmount: 0,
          status: 'unpaid',
          notes: quote.notes ? `من عرض سعر ${quote.quoteNumber} | ${quote.notes}` : `من عرض سعر ${quote.quoteNumber}`,
          issuedAt: new Date(),
          items: {
            create: quote.items.map((item) => ({
              productId: item.productId,
              description: item.description,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              discountAmount: item.discountAmount,
              total: item.total,
            })),
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

      // Decrease stock for each item with a productId
      for (const item of invoice.items) {
        if (item.productId) {
          const qty = Math.round(item.quantity)

          await tx.product.update({
            where: { id: item.productId },
            data: { stockQuantity: { decrement: qty } },
          })

          await tx.productMovement.create({
            data: {
              productId: item.productId,
              businessId,
              movementType: 'sale',
              quantity: -qty,
              referenceType: 'sales_invoice',
              referenceId: invoice.id,
              notes: `فاتورة بيع رقم ${invoice.invoiceNumber} (من عرض سعر ${quote.quoteNumber})`,
            },
          })
        }
      }

      // Update quote status to "converted" and link to the new invoice
      await tx.priceQuote.update({
        where: { id: quoteId },
        data: {
          status: 'converted',
          convertedToInvoiceId: invoice.id,
        },
      })

      return invoice
    })

    await logAudit({
      businessId: quote.businessId,
      action: 'UPDATE',
      entity: 'PriceQuote',
      entityId: quoteId,
      changes: { after: { quoteNumber: quote.quoteNumber, status: 'converted', convertedToInvoiceId: result.id } },
    })

    return NextResponse.json(result)
  } catch (error) {
    console.error('Error converting price quote:', error)
    return NextResponse.json(
      { error: 'Failed to convert price quote' },
      { status: 500 }
    )
  }
}
