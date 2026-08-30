import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } })

export async function POST(request: NextRequest) {
  try {
    const { requestId, clientId, reason } = await request.json()
    if (!requestId || !clientId) {
      return NextResponse.json({ error: 'بيانات ناقصة' }, { status: 400 })
    }

    // التحقق من أن العميل هو صاحب الطلب
    const reqCheck = await pool.query(
      `SELECT client_id, status FROM requests WHERE id = $1`,
      [requestId]
    )
    if (reqCheck.rows[0]?.client_id !== clientId) {
      return NextResponse.json({ error: 'غير مصرح لك' }, { status: 403 })
    }
    if (reqCheck.rows[0]?.status !== 'inspection_paid') {
      return NextResponse.json({ error: 'لا يمكن طلب استرداد الآن' }, { status: 400 })
    }

    // التحقق من مرور 48 ساعة على دفع الكشف
    const payment = await pool.query(
      `SELECT id, amount, created_at FROM payment_transactions 
       WHERE request_id = $1 AND type = 'inspection_fee' AND status = 'paid'
       ORDER BY created_at DESC LIMIT 1`,
      [requestId]
    )
    if (payment.rows.length === 0) {
      return NextResponse.json({ error: 'لا توجد معاملة دفع كشف' }, { status: 404 })
    }
    const paymentTime = new Date(payment.rows[0].created_at)
    const now = new Date()
    const hoursPassed = (now.getTime() - paymentTime.getTime()) / (1000 * 60 * 60)
    if (hoursPassed < 48) {
      return NextResponse.json({ error: 'لا يمكن طلب الاسترداد إلا بعد 48 ساعة من الدفع' }, { status: 400 })
    }

    // حساب المبلغ المسترد (ناقص 10% رسوم منصة وعمولة ماي فاتوره ~2% مثلاً)
    const originalAmount = parseFloat(payment.rows[0].amount)
    const platformFee = originalAmount * 0.10
    const myfatoorahFee = originalAmount * 0.02 // تقريبية
    const refundAmount = originalAmount - platformFee - myfatoorahFee

    // إنشاء طلب استرداد
    const result = await pool.query(
      `INSERT INTO refund_requests (payment_transaction_id, request_id, amount, reason, status)
       VALUES ($1, $2, $3, $4, 'pending')
       RETURNING id`,
      [payment.rows[0].id, requestId, refundAmount, reason || 'طلب استرداد من العميل']
    )

    // إشعار للأدمن
    await pool.query(
      `INSERT INTO notifications (user_id, title, body, type, related_id)
       SELECT id, '💰 طلب استرداد جديد', 'طلب استرداد بمبلغ $1 د.ك للطلب رقم $2', 'refund_request', $3
       FROM users WHERE role = 'admin'`,
      [refundAmount, requestId, result.rows[0].id]
    )

    return NextResponse.json({ success: true, refundId: result.rows[0].id, amount: refundAmount })
  } catch (error: any) {
    console.error('Refund request error:', error)
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}
