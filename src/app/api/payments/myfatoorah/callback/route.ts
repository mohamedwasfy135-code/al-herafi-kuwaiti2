import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } })

// ✅ إزالة القيم الافتراضية تماماً للأمان
const MYFATOORAH_API = process.env.MYFATOORAH_API_URL
const MYFATOORAH_TOKEN = process.env.MYFATOORAH_TOKEN

export async function GET(request: NextRequest) {
  if (!MYFATOORAH_API || !MYFATOORAH_TOKEN) {
    console.error('❌ MyFatoorah credentials missing during callback')
    return NextResponse.redirect(`${process.env.NEXT_PUBLIC_APP_URL}/dashboard?payment=failed`)
  }

  const { searchParams } = new URL(request.url)
  const paymentId = searchParams.get('paymentId')
  const invoiceId = searchParams.get('invoiceId')

  if (!paymentId && !invoiceId) {
    return NextResponse.redirect(`${process.env.NEXT_PUBLIC_APP_URL}/dashboard?payment=failed`)
  }

  try {
    const response = await fetch(`${MYFATOORAH_API}/v2/getPaymentStatus`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${MYFATOORAH_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ Key: paymentId || invoiceId, KeyType: paymentId ? 'PaymentId' : 'InvoiceId' })
    })
    const data = await response.json()

    if (data.IsSuccess && data.Data.InvoiceStatus === 'Paid') {
      await pool.query(
        `UPDATE payment_transactions 
         SET status = 'paid', paymentId = $1, updated_at = NOW()
         WHERE invoiceId = $2`,
        [data.Data.PaymentId, data.Data.InvoiceId]
      )

      console.log("[Callback] البحث عن معاملة بـ InvoiceId:", data.Data.InvoiceId);
      const trans = await pool.query(
        `SELECT requestId, type FROM payment_transactions WHERE invoiceId = $1 OR paymentId = $1`,
        [data.Data.InvoiceId]
      )
      console.log("[Callback] تم العثور على معاملة:", JSON.stringify(trans.rows[0]));
      if (trans.rows.length > 0) {
        const { requestId, type } = trans.rows[0]
        if (type === 'visit_fee') {
          await pool.query(
            `UPDATE requests SET status = 'inspection_paid', updated_at = NOW() WHERE id = $1`,
            [requestId]
          )
          const req = await pool.query(`SELECT craftsmanId FROM requests WHERE id = $1`, [requestId])
          if (req.rows[0]?.craftsmanId) {
            await pool.query(
              `INSERT INTO notifications (user_id, title, body, type, related_id)
               VALUES ($1, '✅ تم دفع رسوم الكشف', 'تم دفع رسوم الكشف للطلب رقم $2، يمكنك التوجه إلى موقع العمل الآن', 'payment_confirmed', $2)`,
              [req.rows[0].craftsmanId, requestId]
            )
          }
        } else if (type === 'final_payment') {
          await pool.query(
            `UPDATE requests SET status = 'completed', updated_at = NOW() WHERE id = $1`,
            [requestId]
          )
          const req = await pool.query(`SELECT clientId, craftsmanId FROM requests WHERE id = $1`, [requestId])
          if (req.rows[0]) {
            await pool.query(
              `INSERT INTO notifications (user_id, title, body, type, related_id)
               VALUES 
                 ($1, '🎉 تم اكتمال الطلب', 'تم استلام الدفعة النهائية للطلب رقم $2', 'order_completed', $2),
                 ($3, '🎉 تم اكتمال الطلب', 'تم إكمال الطلب رقم $2 بنجاح', 'order_completed', $2)`,
              [req.rows[0].clientId, requestId, req.rows[0].craftsmanId]
            )
          }
        }
      }
    }
    return NextResponse.redirect(`${process.env.NEXT_PUBLIC_APP_URL}/dashboard?payment=success`)
  } catch (error) {
    console.error('Callback error:', error)
    return NextResponse.redirect(`${process.env.NEXT_PUBLIC_APP_URL}/dashboard?payment=failed`)
  }
}
