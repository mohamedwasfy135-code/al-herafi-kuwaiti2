import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

// GET /api/notifications - List notification logs
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const businessId = searchParams.get('businessId')
    const type = searchParams.get('type')
    const status = searchParams.get('status')
    const page = parseInt(searchParams.get('page') || '1')
    const limit = parseInt(searchParams.get('limit') || '20')

    if (!businessId) {
      return NextResponse.json({ error: 'businessId is required' }, { status: 400 })
    }

    const where: Record<string, unknown> = { businessId }
    if (type) where.type = type
    if (status) where.status = status

    const [logs, total] = await Promise.all([
      db.notificationLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      db.notificationLog.count({ where }),
    ])

    return NextResponse.json({ logs, total, page, limit })
  } catch (error) {
    console.error('Error fetching notifications:', error)
    return NextResponse.json({ error: 'Failed to fetch notifications' }, { status: 500 })
  }
}

// POST /api/notifications - Create a notification log
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { businessId, type, channel, recipient, title, message } = body

    if (!businessId || !type || !recipient || !title) {
      return NextResponse.json({ error: 'businessId, type, recipient, and title are required' }, { status: 400 })
    }

    const log = await db.notificationLog.create({
      data: {
        businessId,
        type,
        channel: channel || 'whatsapp',
        recipient,
        title,
        message,
        status: 'pending',
      },
    })

    return NextResponse.json(log, { status: 201 })
  } catch (error) {
    console.error('Error creating notification:', error)
    return NextResponse.json({ error: 'Failed to create notification' }, { status: 500 })
  }
}
