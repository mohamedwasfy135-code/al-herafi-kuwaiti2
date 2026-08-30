import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } })

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const requestId = searchParams.get('requestId')
  if (!requestId) {
    return NextResponse.json({ error: 'requestId required' }, { status: 400 })
  }
  const result = await pool.query(
    `SELECT ra.*, u.name as craftsman_name 
     FROM request_assignments ra
     LEFT JOIN users u ON ra.craftsman_id = u.id
     WHERE ra.request_id = $1`,
    [requestId]
  )
  return NextResponse.json({ assignments: result.rows })
}
