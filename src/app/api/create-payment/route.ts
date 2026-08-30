import { NextResponse } from 'next/server'

// ضع هنا بيانات ماي فاتورة الحقيقية عند التفعيل
const MYFATOORAH_API_KEY = process.env.MYFATOORAH_API_KEY || ''
const MYFATOORAH_BASE_URL = 'https://api.myfatoorah.com/v2'

export async function POST(request: Request) {
  try {
    const { amount, requestId } = await request.json()

    // --- في وضع الاختبار: نرجع رابط دفع وهمي ---
    if (!MYFATOORAH_API_KEY) {
      const mockPaymentUrl = `https://sandbox.myfatoorah.com/Invoice/Payment?invoiceId=TEST-${Date.now()}`
      return NextResponse.json({ paymentUrl: mockPaymentUrl })
    }

    // --- الكود الحقيقي لماي فاتورة (علّق عند وجود المفاتيح) ---
    /*
    const initRes = await fetch(`${MYFATOORAH_BASE_URL}/InitiatePayment`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${MYFATOORAH_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        InvoiceAmount: amount,
        CurrencyIso: 'KWD',
        CallBackUrl: `${process.env.NEXT_PUBLIC_URL}/payment-result?requestId=${requestId}`,
        ErrorUrl: `${process.env.NEXT_PUBLIC_URL}/payment-error`,
      })
    })
    const initData = await initRes.json()
    if (initData.IsSuccess) {
      return NextResponse.json({ paymentUrl: initData.Data.InvoiceURL })
    } else {
      return NextResponse.json({ error: initData.Message }, { status: 400 })
    }
    */

  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}
