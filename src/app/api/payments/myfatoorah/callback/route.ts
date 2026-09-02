import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({ 
  connectionString: process.env.DATABASE_URL, 
  ssl: { rejectUnauthorized: false } 
})

const MYFATOORAH_API = process.env.MYFATOORAH_API_URL
const MYFATOORAH_TOKEN = process.env.MYFATOORAH_TOKEN

export async function GET(request: NextRequest) {
  if (!MYFATOORAH_API || !MYFATOORAH_TOKEN) {
    console.error('❌ MyFatoorah credentials missing')
    return NextResponse.redirect(`${process.env.NEXT_PUBLIC_APP_URL}/dashboard?payment=failed`)
  }

  const { searchParams } = new URL(request.url)
  const paymentId = searchParams.get('paymentId')
  const invoiceId = searchParams.get('invoiceId')

  if (!paymentId && !invoiceId) {
    console.error('❌ No ID provided in callback')
    return NextResponse.redirect(`${process.env.NEXT_PUBLIC_APP_URL}/dashboard?payment=failed`)
  }

  try {
    // 1. التحقق من حالة الدفع من ماي فاتورة
    const response = await fetch(`${MYFATOORAH_API}/v2/getPaymentStatus`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${MYFATOORAH_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ 
        Key: paymentId || invoiceId, 
        KeyType: paymentId ? 'PaymentId' : 'InvoiceId' 
      })
    })
    const data = await response.json()

    console.log('[Callback] Response from MyFatoorah:', JSON.stringify(data))

    if (data.IsSuccess && data.Data.InvoiceStatus === 'Paid') {
      const mfPaymentId = data.Data.PaymentId
      const mfInvoiceId = data.Data.InvoiceId

      // 2. تحديث المعاملة باستخدام الأسماء الصحيحة للأعمدة (updated_at NOT updatedAt)
      await pool.query(
        `UPDATE "PaymentTransaction"
         SET status = 'paid', "paymentId" = $1, updated_at = NOW()
         WHERE "invoiceId" = $2 OR "paymentId" = $2`,
        [mfPaymentId, mfInvoiceId]
      )

      console.log("[Callback] Transaction updated for InvoiceId:", mfInvoiceId);

      // 3. جلب بيانات المعاملة لتحديث الطلب
      const trans = await pool.query(
        `SELECT "requestId", type FROM "PaymentTransaction" 
         WHERE "invoiceId" = $1 OR "paymentId" = $1 
         LIMIT 1`,
        [mfInvoiceId]
      )

      console.log("[Callback] Found transaction:", JSON.stringify(trans.rows[0]));

      if (trans.rows.length > 0) {
        const { requestId, type } = trans.rows[0]
        
        if (type === 'visit_fee') {
          // تحديث حالة الطلب لدفعة الزيارة
          await pool.query(
            `UPDATE "Request" SET status = 'inspection_paid', updated_at = NOW() WHERE id = $1`,
            [requestId]
          )
          
          // إرسال إشعار للحرفي
          const req = await pool.query(`SELECT "craftsmanId" FROM "Request" WHERE id = $1`, [requestId])
          if (req.rows[0]?.craftsmanId) {
            await pool.query(
              `INSERT INTO "Notification" ("userId", title, body, type, created_at, updated_at)
               VALUES ($1, $2, $3, 'payment_confirmed', NOW(), NOW())`,
              [req.rows[0].craftsmanId, '✅ تم دفع رسوم الكشف', `تم دفع رسوم الكشف للطلب رقم ${requestId}`]
            )
          }
        } else if (type === 'final_payment') {
          // تحديث حالة الطلب للدفع النهائي
          await pool.query(
            `UPDATE "Request" SET status = 'completed', updated_at = NOW() WHERE id = $1`,
            [requestId]
          )
          
          // إرسال إشعارات للعميل والحرفي
          const req = await pool.query(`SELECT "clientId", "craftsmanId" FROM "Request" WHERE id = $1`, [requestId])
          if (req.rows[0]) {
            await pool.query(
              `INSERT INTO "Notification" ("userId", title, body, type, created_at, updated_at)
               VALUES ($1, $2, $3, 'order_completed', NOW(), NOW())`,
              [req.rows[0].clientId, ' تم اكتمال الطلب', `تم استلام الدفعة النهائية للطلب رقم ${requestId}`]
            )
            if (req.rows[0].craftsmanId) {
              await pool.query(
                `INSERT INTO "Notification" ("userId", title, body, type, created_at, updated_at)
                 VALUES ($1, $2, $3, 'order_completed', NOW(), NOW())`,
                [req.rows[0].craftsmanId, ' تم اكتمال الطلب', `تم إكمال الطلب رقم ${requestId} بنجاح`]
              )
            }
          }
        }
        console.log(`[Callback] Request #${requestId} updated successfully to ${type === 'visit_fee' ? 'inspection_paid' : 'completed'}`);
      } else {
        console.error("[Callback] No transaction found for InvoiceId:", mfInvoiceId);
      }
    } else {
      console.warn("[Callback] Payment not paid or failed:", data.Data?.InvoiceStatus);
    }

    return NextResponse.redirect(`${process.env.NEXT_PUBLIC_APP_URL}/dashboard?payment=success`)
  } catch (error: any) {
    console.error('💥 Callback fatal error:', error.message)
    return NextResponse.redirect(`${process.env.NEXT_PUBLIC_APP_URL}/dashboard?payment=failed`)
  }
}
