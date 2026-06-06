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

    const updateData: Record<string, unknown> = {}
    if (paidAmount !== undefined) updateData.paidAmount = parseFloat(String(paidAmount))
    if (status !== undefined) updateData.status = status

    // Append payment info to notes
    const existing = await db.purchaseInvoice.findUnique({ where: { id: invoiceId } })
    if (existing && (paymentMethod || paymentDate)) {
      const paymentNote = `${paymentMethod ? `طريقة الدفع: ${paymentMethod}` : ''}${paymentDate ? ` | تاريخ الدفع: ${paymentDate}` : ''}`
      updateData.notes = existing.notes
        ? `${existing.notes} | ${paymentNote}`
        : paymentNote
    }

    const invoice = await db.purchaseInvoice.update({
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

    return NextResponse.json(invoice)
  } catch (error) {
    console.error('Error updating purchase invoice:', error)
    return NextResponse.json(
      { error: 'Failed to update purchase invoice' },
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
    await db.purchaseInvoiceItem.deleteMany({ where: { invoiceId } })
    await db.purchaseInvoice.delete({ where: { id: invoiceId } })

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Error deleting purchase invoice:', error)
    return NextResponse.json(
      { error: 'Failed to delete purchase invoice' },
      { status: 500 }
    )
  }
}
