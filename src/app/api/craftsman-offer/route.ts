import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } })

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { requestId, craftsmanId, notes } = body
    const price = body.price ?? body.proposedPrice

    if (!requestId || price === undefined || !craftsmanId) {
      return NextResponse.json({ error: 'requestId, price, craftsmanId مطلوبة' }, { status: 400 })
    }

    const existing = await pool.query(
      'SELECT id FROM price_offers WHERE request_id = $1 AND craftsman_id = $2',
      [requestId, craftsmanId]
    )

    if (existing.rows.length > 0) {
      const result = await pool.query(
        'UPDATE price_offers SET proposed_price = $1, notes = $2, status = $3, updated_at = NOW() WHERE request_id = $4 AND craftsman_id = $5 RETURNING *',
        [price, notes || null, 'submitted', requestId, craftsmanId]
      )
      return NextResponse.json({ success: true, offer: result.rows[0] })
    }

    const result = await pool.query(
      `INSERT INTO price_offers (request_id, craftsman_id, proposed_price, notes, status, created_at, updated_at)
       VALUES ($1, $2, $3, $4, 'submitted', NOW(), NOW()) RETURNING *`,
      [requestId, craftsmanId, price, notes || null]
    )
    return NextResponse.json({ success: true, offer: result.rows[0] }, { status: 201 })
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}
