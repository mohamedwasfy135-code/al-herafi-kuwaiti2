import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } })

export async function POST(request: NextRequest) {
  try {
    const { craftsmanId, newCategoryId, reason } = await request.json()
    if (!craftsmanId || !newCategoryId || !reason) {
      return NextResponse.json({ error: 'جميع الحقول مطلوبة' }, { status: 400 })
    }

    // الحصول على الفئة القديمة من الخدمة الحالية للحرفي
    const oldService = await pool.query(
      `SELECT category_id FROM services WHERE craftsman_id = $1 LIMIT 1`,
      [craftsmanId]
    )
    const oldCategoryId = oldService.rows[0]?.category_id || null

    await pool.query(
      `INSERT INTO profession_change_requests (craftsman_id, old_category_id, new_category_id, reason)
       VALUES ($1, $2, $3, $4)`,
      [craftsmanId, oldCategoryId, newCategoryId, reason]
    )

    return NextResponse.json({ success: true, message: 'تم إرسال الطلب إلى الأدمن' })
  } catch (err: any) {
    console.error(err)
    return NextResponse.json({ error: err.message }, { status: 500 })
  }
}
