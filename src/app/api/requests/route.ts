import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const clientId = searchParams.get('clientId')

    if (!clientId) {
      return NextResponse.json({ error: 'معرف العميل مطلوب' }, { status: 400 })
    }

    const requests = await db.request.findMany({
      where: { clientId },
      include: {
        client: { select: { id: true, name: true, phone: true } },
        craftsman: { select: { id: true, name: true, phone: true, rating: true } },
        category: { select: { id: true, name: true, icon: true } }
      },
      orderBy: { createdAt: 'desc' },
    })

    console.log('📦 [API] عدد الطلبات:', requests.length)
    if (requests.length > 0) {
      console.log('📦 [API] تفاصيل الطلب الأول:', JSON.stringify({
        id: requests[0].id,
        status: requests[0].status,
        proposedPrice: requests[0].proposedPrice,
        remainingAmount: requests[0].remainingAmount
      }, null, 2))
    }

    return NextResponse.json({ success: true, requests })
  } catch (error: any) {
    console.error('❌ Fetch requests error:', error)
    return NextResponse.json({ error: error.message || 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    if (!body.clientId || !body.description || !body.address) {
      return NextResponse.json({ error: 'بيانات ناقصة' }, { status: 400 })
    }

    const newRequest = await db.request.create({
      data: {
        clientId: body.clientId,
        categoryId: body.categoryId ? parseInt(body.categoryId) : null,
        type: body.type || 'service',
        description: body.description,
        address: body.address,
        governorate: body.governorate || null,
        city: body.city || null,
        status: 'pending',
      },
    })

    return NextResponse.json({ success: true, requestId: newRequest.id }, { status: 201 })
  } catch (error: any) {
    console.error('❌ خطأ في إنشاء الطلب:', error)
    return NextResponse.json({ error: error.message || 'حدث خطأ داخلي' }, { status: 500 })
  }
}
