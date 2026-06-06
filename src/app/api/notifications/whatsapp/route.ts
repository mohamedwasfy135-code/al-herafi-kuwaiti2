import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

// POST /api/notifications/whatsapp - Generate wa.me link and store notification
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { businessId, phone, message, type } = body

    if (!businessId || !phone || !message) {
      return NextResponse.json({ error: 'businessId, phone, and message are required' }, { status: 400 })
    }

    // Clean phone number (remove non-numeric chars except +)
    const cleanPhone = phone.replace(/[^\d+]/g, '')
    // Format for wa.me: remove leading + or 0, add country code if needed
    let waPhone = cleanPhone.replace(/^00/, '').replace(/^\+/, '')
    if (waPhone.startsWith('0')) {
      waPhone = '965' + waPhone.substring(1) // Kuwait default
    }

    // Generate wa.me link with pre-filled message
    const waMeLink = `https://wa.me/${waPhone}?text=${encodeURIComponent(message)}`

    // Store notification log
    const log = await db.notificationLog.create({
      data: {
        businessId,
        type: type || 'daily_report',
        channel: 'whatsapp',
        recipient: phone,
        title: type === 'ai_analysis' ? 'تحليل ذكي' : 'تقرير يومي',
        message,
        status: 'pending',
      },
    })

    return NextResponse.json({
      success: true,
      waMeLink,
      logId: log.id,
    })
  } catch (error) {
    console.error('Error sending WhatsApp notification:', error)
    return NextResponse.json({ error: 'Failed to send WhatsApp notification' }, { status: 500 })
  }
}
