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

    const invoices = await db.salesInvoice.findMany({
      where,
      include: {
        business: {
          select: { id: true, name: true },
        },
        items: {
          include: {
            product: {
              select: { id: true, name: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json(invoices)
  } catch (error) {
    console.error('Error fetching sales invoices:', error)
    return NextResponse.json(
      { error: 'Failed to fetch sales invoices' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      clientName,
      clientPhone,
      clientId,
      items,
      discountAmount,
      taxAmount,
      dueDate,
      notes,
      paidAmount,
      status,
      paymentMethod,
      paymentDate,
      accountId,
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
        const lineTotal =
          (item.unitPrice || 0) * (item.quantity || 1) - (item.discountAmount || 0)
        return sum + lineTotal
      },
      0
    )

    const totalDiscount = discountAmount ? parseFloat(String(discountAmount)) : 0
    const totalTax = taxAmount ? parseFloat(String(taxAmount)) : 0
    const total = subtotal - totalDiscount + totalTax

    // Determine invoice status and paid amount
    const invoicePaidAmount = paidAmount ? parseFloat(String(paidAmount)) : 0
    let invoiceStatus = status || 'draft'
    if (invoiceStatus === 'draft' || !status) {
      if (invoicePaidAmount >= total && total > 0) {
        invoiceStatus = 'paid'
      } else if (invoicePaidAmount > 0) {
        invoiceStatus = 'partial'
      } else if (status === 'unpaid') {
        invoiceStatus = 'unpaid'
      }
    }

    // Resolve accountId
    const resolvedAccountId = accountId ? parseInt(String(accountId)) : null

    // Generate invoice number
    const count = await db.salesInvoice.count({
      where: { businessId },
    })
    const invoiceNumber = `SI-${String(count + 1).padStart(5, '0')}`

    // Wrap everything in a transaction for atomicity
    const invoice = await db.$transaction(async (tx) => {
      // Create the invoice with items
      const createdInvoice = await tx.salesInvoice.create({
        data: {
          businessId,
          invoiceNumber,
          clientId: clientId ? parseInt(String(clientId)) : null,
          clientName,
          clientPhone,
          subtotal,
          discountAmount: totalDiscount,
          taxAmount: totalTax,
          total,
          paidAmount: invoicePaidAmount,
          status: invoiceStatus,
          paymentMethod: paymentMethod || null,
          paymentDate: paymentDate ? new Date(paymentDate) : null,
          accountId: resolvedAccountId,
          dueDate: dueDate ? new Date(dueDate) : null,
          notes: notes ? `${notes}${paymentMethod ? ` | طريقة الدفع: ${paymentMethod}` : ''}${paymentDate ? ` | تاريخ الدفع: ${paymentDate}` : ''}` : `${paymentMethod ? `طريقة الدفع: ${paymentMethod}` : ''}${paymentDate ? ` | تاريخ الدفع: ${paymentDate}` : ''}`,
          issuedAt: new Date(),
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

      // Decrease stock for each item with a productId and create ProductMovement
      for (const item of createdInvoice.items) {
        if (item.productId) {
          const qty = Math.round(item.quantity)

          // Decrease product stock
          await tx.product.update({
            where: { id: item.productId },
            data: { stockQuantity: { decrement: qty } },
          })

          // Create product movement record
          await tx.productMovement.create({
            data: {
              productId: item.productId,
              businessId,
              movementType: 'sale',
              quantity: -qty,
              referenceType: 'sales_invoice',
              referenceId: createdInvoice.id,
              notes: `فاتورة بيع رقم ${createdInvoice.invoiceNumber}`,
            },
          })
        }
      }

      // If invoice is paid and has an accountId, create BusinessTransaction and update account
      if (invoicePaidAmount > 0 && resolvedAccountId) {
        // Create BusinessTransaction for the income
        await tx.businessTransaction.create({
          data: {
            businessId,
            type: 'income',
            amount: invoicePaidAmount,
            description: `إيراد فاتورة بيع رقم ${createdInvoice.invoiceNumber}${clientName ? ` - ${clientName}` : ''}`,
            category: 'sales',
            referenceType: 'sales_invoice',
            referenceId: createdInvoice.id,
            creditAccountId: resolvedAccountId,
            transactionDate: createdInvoice.paymentDate || createdInvoice.issuedAt || new Date(),
          },
        })

        // Update account currentBalance (increase)
        await tx.account.update({
          where: { id: resolvedAccountId },
          data: { currentBalance: { increment: invoicePaidAmount } },
        })

        // Update BusinessSummary
        const existingSummary = await tx.businessSummary.findFirst({
          where: { businessId },
        })

        if (existingSummary) {
          const newTotalIncome = existingSummary.totalIncome + invoicePaidAmount
          await tx.businessSummary.update({
            where: { id: existingSummary.id },
            data: {
              totalIncome: newTotalIncome,
              netProfit: newTotalIncome - existingSummary.totalExpenses,
              transactionCount: existingSummary.transactionCount + 1,
              lastUpdated: new Date(),
            },
          })
        } else {
          await tx.businessSummary.create({
            data: {
              businessId,
              totalIncome: invoicePaidAmount,
              totalExpenses: 0,
              totalPurchases: 0,
              netProfit: invoicePaidAmount,
              transactionCount: 1,
            },
          })
        }
      }

      return createdInvoice
    })

    await logAudit({
      businessId,
      action: 'CREATE',
      entity: 'SalesInvoice',
      entityId: invoice.id,
      changes: { after: { invoiceNumber: invoice.invoiceNumber, total: invoice.total, clientName: invoice.clientName } },
    })

    return NextResponse.json(invoice, { status: 201 })
  } catch (error) {
    console.error('Error creating sales invoice:', error)
    return NextResponse.json(
      { error: 'Failed to create sales invoice' },
      { status: 500 }
    )
  }
}
