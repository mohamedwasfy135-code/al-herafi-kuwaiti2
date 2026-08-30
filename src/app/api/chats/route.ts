import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
})

export async function GET(request: NextRequest) {
  try {
    return NextResponse.json({ chats: [] })
  } catch (error) {
    return NextResponse.json({ error: 'فشل جلب المحادثات' }, { status: 500 })
  }
}
