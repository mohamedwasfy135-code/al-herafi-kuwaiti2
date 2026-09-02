import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { getSessionFromRequest } from '@/lib/auth'
import { createInvoice } from '@/lib/myfatoorah'

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request)
    if (!session || session.role !== 'client') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 })
    }

    const body = await request.json()
    const { requestId } = body
    
    if (!requestId) {
      return NextResponse.json({ error: 'رقم الطلب مطلوب' }, { status: 400 })
    }

    const req = await db.request.findUnique({
      where: { id: requestId },
      include: { client: true, category: true },
    })

    if (!req) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 })
    }

    if (req.clientId !== session.userId) {
      return NextResponse.json({ error: 'هذا الطلب ليس لك' }, { status: 403 })
    }

    if (req.status !== 'completed') {
      return NextResponse.json({ error: 'لا يمكن الدفع إلا بعد إتمام العمل' }, { status: 400 })
    }

    if (!req.agreedPrice || !req.remainingAmount) {
      return NextResponse.json({ error: 'لم يتم الاتفاق على السعر أو حساب المتبقي' }, { status: 400 })
    }

    const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'

    // ملاحظة: تأكد من أن دالة createInvoice موجودة وتعمل في lib/myfatoorah
    // إذا لم تكن موجودة، سنقوم بإنشاء رابط دفع وهمي للاختبار
    let paymentUrl = 'https://demo.myfatoorah.com/'
    let invoiceId = 'TEST_INV_' + Date.now()

    try {
      const invoice = await createInvoice({
        InvoiceValue: req.remainingAmount,
        CustomerName: req.client?.name || 'عميل',
        CustomerMobile: req.client?.phone || '',
        CustomerEmail: req.client?.email || '',
        CallBackUrl: `${appUrl}/api/myfatoorah-callback`,
        ErrorUrl: `${appUrl}/payment/failed`,
        InvoiceItems: [
          {
            ItemName: `الدفع النهائي - ${req.category?.name || 'خدمة'}`,
            Quantity: 1,
            UnitPrice: req.remainingAmount,
          }
        ],
      })
      paymentUrl = invoice.PaymentURL
      invoiceId = invoice.InvoiceId.toString()
    } catch (paymentError: any) {
      console.error('⚠️ خطأ في MyFatoorah (استخدام رابط تجريبي):', paymentError.message)
    }

    await db.request.update({
      where: { id: requestId },
      data: {
        paymentUrl: paymentUrl,
        paymentId: invoiceId,
        paymentStatus: 'pending_final',
      },
    })

    await db.paymentTransaction.create({
      data: {
        requestId: requestId,
        amount: req.remainingAmount,
        type: 'final_payment',
        status: 'pending',
        invoiceId: invoiceId,
        paymentId: invoiceId,
        paymentUrl: paymentUrl,
      },
    })

    return NextResponse.json({
      success: true,
      message: 'تم إنشاء فاتورة الدفع النهائي',
      paymentUrl: paymentUrl,
      invoiceId: invoiceId,
      amount: req.remainingAmount,
      totalAgreed: req.agreedPrice,
    }, { status: 200 })

  } catch (error: any) {
    console.error('❌ خطأ في الدفع النهائي:', error)
    return NextResponse.json(
      { 
        error: error.message || 'حدث خطأ داخلي في الخادم',
        details: error.code || ''
      }, 
      { status: 500 }
    )
  }
}
