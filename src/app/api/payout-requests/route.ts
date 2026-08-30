import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
})

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { craftsmanId, amount } = body

    if (!craftsmanId || !amount || amount <= 0) {
      return NextResponse.json({ error: 'يرجى تقديم craftsmanId و amount صحيح' }, { status: 400 })
    }

    const insertQuery = `
      INSERT INTO payout_requests (craftsman_id, amount, status)
      VALUES ($1, $2, 'pending')
      RETURNING *
    `
    const values = [craftsmanId, parseFloat(amount)]
    const result = await pool.query(insertQuery, values)

    return NextResponse.json({ payout: result.rows[0] }, { status: 201 })
  } catch (error: any) {
    console.error('Error creating payout request:', error)
    return NextResponse.json({ error: 'فشل إنشاء طلب الدفعة' }, { status: 500 })
  }
}
