import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    
    // ماي فاتورة ترسل إشعارات بصيغة مختلفة عن الـ Redirect
    const invoiceId = body.InvoiceId || body.invoiceId
    const status = body.InvoiceStatus || body.status
    
    if (!invoiceId) {
      console.error('❌ [Webhook] InvoiceId مفقود:', body)
      return new NextResponse(null, { status: 400 })
    }

    console.log(`[Webhook] استلام إشعار: InvoiceId=${invoiceId}, Status=${status}`)

    // البحث عن المعاملة
    const transaction = await db.paymentTransaction.findFirst({
      where: { invoiceId: String(invoiceId) },
      include: { request: true }
    })

    if (!transaction) {
      console.error('❌ [Webhook] معاملة غير موجودة:', invoiceId)
      return new NextResponse(null, { status: 404 })
    }

    if (transaction.status === 'paid') {
      console.log('ℹ️ [Webhook] مدفوع مسبقاً')
      return new NextResponse(null, { status: 200 })
    }

    if (status === 'Paid') {
      await db.$transaction(async (tx) => {
        await tx.paymentTransaction.update({
          where: { id: transaction.id },
          data: { status: 'paid', paidAt: new Date() }
        })

        const updateData: any = {}
        if (transaction.type === 'visit_fee') {
          updateData.visitFeePaid = true
          updateData.status = 'inspection_paid'
        } else if (transaction.type === 'final_payment') {
          updateData.status = 'completed'
        }

        if (Object.keys(updateData).length > 0 && transaction.requestId) {
          await tx.request.update({
            where: { id: transaction.requestId },
            data: updateData
          })
        }
      })

      console.log(`✅ [Webhook] تم تحديث الطلب #${transaction.requestId}`)
    }

    return new NextResponse(null, { status: 200 })
  } catch (error: any) {
    console.error('💥 [Webhook] خطأ:', error.message)
    return new NextResponse(null, { status: 500 })
  }
}
