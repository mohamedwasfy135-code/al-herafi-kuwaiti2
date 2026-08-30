import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
})

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  return NextResponse.json({ messages: [] })
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const body = await request.json()
    return NextResponse.json({
      message: {
        id: Date.now().toString(),
        content: body.content,
        senderId: 'current',
        createdAt: new Date().toISOString(),
      },
    })
  } catch (error) {
    return NextResponse.json({ error: 'فشل إرسال الرسالة' }, { status: 500 })
  }
}
