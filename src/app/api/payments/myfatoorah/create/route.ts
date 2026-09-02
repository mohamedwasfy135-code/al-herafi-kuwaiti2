import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } })

// ✅ إزالة القيم الافتراضية تماماً للأمان
const MYFATOORAH_API = process.env.MYFATOORAH_API_URL
const MYFATOORAH_TOKEN = process.env.MYFATOORAH_TOKEN

if (!MYFATOORAH_API || !MYFATOORAH_TOKEN) {
  console.error('❌ MyFatoorah credentials are missing in environment variables')
}

export async function POST(request: NextRequest) {
  try {
    if (!MYFATOORAH_API || !MYFATOORAH_TOKEN) {
      return NextResponse.json({ error: 'تهيئة بوابة الدفع غير مكتملة في الخادم' }, { status: 500 })
    }

    const { requestId, amount, type, customerName, customerPhone, customerEmail } = await request.json()

    if (!requestId || !amount || !type) {
      return NextResponse.json({ error: 'بيانات ناقصة' }, { status: 400 })
    }

    let name = customerName, phone = customerPhone, email = customerEmail
    if (!name || !phone) {
      const reqData = await pool.query(`
        SELECT u.name, u.phone, u.email FROM "Request" r
        JOIN "User" u ON r."clientId" = u.id
        WHERE r.id = $1
      `, [requestId])
      if (reqData.rows[0]) {
        name = name || reqData.rows[0].name
        phone = phone || reqData.rows[0].phone
        email = email || reqData.rows[0].email || `${phone}@temp.com`
      }
    }

    const response = await fetch(`${MYFATOORAH_API}/v2/SendPayment`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${MYFATOORAH_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        CustomerName: name,
        CustomerMobile: phone,
        CustomerEmail: email || `${phone}@temp.com`,
        InvoiceValue: amount,
        NotificationOption: 'LNK',
        CallBackUrl: `${process.env.NEXT_PUBLIC_APP_URL}/api/payments/myfatoorah/callback`,
        ErrorUrl: `${process.env.NEXT_PUBLIC_APP_URL}/payment-error`,
        Language: 'ar',
        DisplayCurrencyIso: 'KWD'
      })
    })

    const data = await response.json()
    if (!data.IsSuccess) {
      return NextResponse.json({ error: data.Message || 'فشل إنشاء الدفع' }, { status: 400 })
    }

    // ملاحظة: paymentId عمود إلزامي بالـ schema، ولا نملكه بعد وقت الإنشاء
    // لذلك نضع InvoiceId مؤقتاً فيه، وسيُستبدل بالقيمة الحقيقية عند الـ callback
    const result = await pool.query(
      `INSERT INTO "PaymentTransaction" ("requestId", amount, type, "paymentId", "invoiceId", "paymentUrl", status)
      VALUES ($1, $2, $3, $4, $5, $6, 'pending')
      RETURNING id`,
      [requestId, amount, type, data.Data.InvoiceId, data.Data.InvoiceId, data.Data.InvoiceURL]
    )

    return NextResponse.json({
      success: true,
      paymentUrl: data.Data.InvoiceURL,
      transactionId: result.rows[0].id,
      invoiceId: data.Data.InvoiceId
    })
  } catch (error: any) {
    console.error('MyFatoorah create error:', error)
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}
