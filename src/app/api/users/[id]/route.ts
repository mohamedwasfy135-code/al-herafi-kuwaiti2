import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
})

// دالة مساعدة لإزالة كلمة المرور من صف المستخدم
function sanitizeUser(user: any) {
  if (!user) return null
  const { password, ...safe } = user
  return safe
}

// GET: جلب مستخدم
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  try {
    const result = await pool.query(`SELECT * FROM users WHERE id = $1`, [id])
    if (result.rows.length === 0) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 })
    }
    return NextResponse.json({ user: sanitizeUser(result.rows[0]) })
  } catch (error: any) {
    console.error('GET user error:', error)
    return NextResponse.json({ error: 'فشل جلب بيانات المستخدم' }, { status: 500 })
  }
}

// PUT: تحديث بيانات المستخدم
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  try {
    const body = await request.json()
    const { name, email, phone, governorate, city } = body

    // بناء جملة التحديث الديناميكية
    const updates: string[] = []
    const values: any[] = []
    let idx = 1

    if (name !== undefined) {
      updates.push(`name = $${idx++}`)
      values.push(name)
    }
    if (email !== undefined) {
      updates.push(`email = $${idx++}`)
      values.push(email)
    }
    if (phone !== undefined) {
      updates.push(`phone = $${idx++}`)
      values.push(phone)
    }
    if (governorate !== undefined) {
      updates.push(`governorate = $${idx++}`)
      values.push(governorate)
    }
    if (city !== undefined) {
      updates.push(`city = $${idx++}`)
      values.push(city)
    }

    if (updates.length === 0) {
      return NextResponse.json({ error: 'لا توجد بيانات للتحديث' }, { status: 400 })
    }

    values.push(id)
    const query = `UPDATE users SET ${updates.join(', ')} WHERE id = $${idx} RETURNING *`
    const result = await pool.query(query, values)

    if (result.rows.length === 0) {
      return NextResponse.json({ error: 'المستخدم غير موجود' }, { status: 404 })
    }

    return NextResponse.json({ user: sanitizeUser(result.rows[0]) })
  } catch (error: any) {
    console.error('PUT user error:', error)
    // أثناء التطوير، نُظهر تفاصيل الخطأ للمساعدة في التشخيص
    const detail = process.env.NODE_ENV !== 'production' ? error.message : undefined
    return NextResponse.json({ error: 'فشل تحديث بيانات المستخدم', detail }, { status: 500 })
  }
}
