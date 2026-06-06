import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const invoiceId = parseInt(id)
    const body = await request.json()
    const { paidAmount, status, paymentMethod, paymentDate } = body

    // Wrap in transaction for atomicity
    const invoice = await db.$transaction(async (tx) => {
      const existing = await tx.salesInvoice.findUnique({
        where: { id: invoiceId },
      })
      if (!existing) {
        throw new Error('Invoice not found')
      }

      const updateData: Record<string, unknown> = {}
      const additionalPaidAmount = paidAmount !== undefined
        ? parseFloat(String(paidAmount)) - existing.paidAmount
        : 0
      if (paidAmount !== undefined) updateData.paidAmount = parseFloat(String(paidAmount))
      if (status !== undefined) updateData.status = status

      // Append payment info to notes
      if (paymentMethod || paymentDate) {
        const paymentNote = `${paymentMethod ? `طريقة الدفع: ${paymentMethod}` : ''}${paymentDate ? ` | تاريخ الدفع: ${paymentDate}` : ''}`
        updateData.notes = existing.notes
          ? `${existing.notes} | ${paymentNote}`
          : paymentNote
      }

      const updatedInvoice = await tx.salesInvoice.update({
        where: { id: invoiceId },
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

      // If additional payment is being made and invoice has an accountId
      if (additionalPaidAmount > 0 && existing.accountId) {
        // Create BusinessTransaction for the additional payment
        await tx.businessTransaction.create({
          data: {
            businessId: existing.businessId,
            type: 'income',
            amount: additionalPaidAmount,
            description: `سداد فاتورة بيع رقم ${existing.invoiceNumber}${existing.clientName ? ` - ${existing.clientName}` : ''}`,
            category: 'sales',
            referenceType: 'sales_invoice',
            referenceId: existing.id,
            creditAccountId: existing.accountId,
            transactionDate: new Date(),
          },
        })

        // Update account currentBalance (increase)
        await tx.account.update({
          where: { id: existing.accountId },
          data: { currentBalance: { increment: additionalPaidAmount } },
        })

        // Update BusinessSummary
        const existingSummary = await tx.businessSummary.findFirst({
          where: { businessId: existing.businessId },
        })

        if (existingSummary) {
          const newTotalIncome = existingSummary.totalIncome + additionalPaidAmount
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
              businessId: existing.businessId,
              totalIncome: additionalPaidAmount,
              totalExpenses: 0,
              totalPurchases: 0,
              netProfit: additionalPaidAmount,
              transactionCount: 1,
            },
          })
        }
      }

      return updatedInvoice
    })

    return NextResponse.json(invoice)
  } catch (error) {
    console.error('Error updating sales invoice:', error)
    return NextResponse.json(
      { error: 'Failed to update sales invoice' },
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
    const invoiceId = parseInt(id)

    // Delete items first, then invoice
    await db.salesInvoiceItem.deleteMany({ where: { invoiceId } })
    await db.salesInvoice.delete({ where: { id: invoiceId } })

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Error deleting sales invoice:', error)
    return NextResponse.json(
      { error: 'Failed to delete sales invoice' },
      { status: 500 }
    )
  }
}
