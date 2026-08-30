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
         SET status = 'paid', myfatoorah_payment_id = $1, updated_at = NOW()
         WHERE myfatoorah_invoice_id = $2`,
        [data.Data.PaymentId, data.Data.InvoiceId]
      )

      const trans = await pool.query(
        `SELECT request_id, type FROM payment_transactions WHERE myfatoorah_invoice_id = $1`,
        [data.Data.InvoiceId]
      )
      if (trans.rows.length > 0) {
        const { request_id, type } = trans.rows[0]
        if (type === 'inspection_fee') {
          await pool.query(
            `UPDATE requests SET status = 'inspection_paid', updated_at = NOW() WHERE id = $1`,
            [request_id]
          )
          const req = await pool.query(`SELECT craftsman_id FROM requests WHERE id = $1`, [request_id])
          if (req.rows[0]?.craftsman_id) {
            await pool.query(
              `INSERT INTO notifications (user_id, title, body, type, related_id)
               VALUES ($1, '✅ تم دفع رسوم الكشف', 'تم دفع رسوم الكشف للطلب رقم $2، يمكنك التوجه إلى موقع العمل الآن', 'payment_confirmed', $2)`,
              [req.rows[0].craftsman_id, request_id]
            )
          }
        } else if (type === 'final_payment') {
          await pool.query(
            `UPDATE requests SET status = 'completed', updated_at = NOW() WHERE id = $1`,
            [request_id]
          )
          const req = await pool.query(`SELECT client_id, craftsman_id FROM requests WHERE id = $1`, [request_id])
          if (req.rows[0]) {
            await pool.query(
              `INSERT INTO notifications (user_id, title, body, type, related_id)
               VALUES 
                 ($1, '🎉 تم اكتمال الطلب', 'تم استلام الدفعة النهائية للطلب رقم $2', 'order_completed', $2),
                 ($3, '🎉 تم اكتمال الطلب', 'تم إكمال الطلب رقم $2 بنجاح', 'order_completed', $2)`,
              [req.rows[0].client_id, request_id, req.rows[0].craftsman_id]
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
