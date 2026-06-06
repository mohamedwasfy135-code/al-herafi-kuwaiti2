import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'

// GET /api/offers - جلب قائمة العروض
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    const isActive = searchParams.get('isActive')

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const where: Record<string, unknown> = { businessId }

    if (isActive !== null && isActive !== undefined && isActive !== '') {
      where.isActive = isActive === 'true'
    }

    const offers = await db.offer.findMany({
      where,
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json(offers)
  } catch (error) {
    console.error('Error fetching offers:', error)
    return NextResponse.json(
      { error: 'Failed to fetch offers' },
      { status: 500 }
    )
  }
}

// POST /api/offers - إنشاء عرض جديد
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      title,
      description,
      discountPercentage,
      originalPrice,
      offerPrice,
      startDate,
      endDate,
      productId,
      serviceId,
      images,
      isActive,
    } = body

    if (!rawBusinessId) {
      return NextResponse.json(
        { error: 'businessId و عنوان العرض مطلوبان' },
        { status: 400 }
      )
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    if (!title) {
      return NextResponse.json(
        { error: 'businessId و عنوان العرض مطلوبان' },
        { status: 400 }
      )
    }

    const offer = await db.offer.create({
      data: {
        businessId,
        title,
        description: description || null,
        discountPercentage: discountPercentage ? parseFloat(String(discountPercentage)) : null,
        originalPrice: originalPrice ? parseFloat(String(originalPrice)) : null,
        offerPrice: offerPrice ? parseFloat(String(offerPrice)) : null,
        startDate: startDate ? new Date(startDate) : new Date(),
        endDate: endDate ? new Date(endDate) : null,
        productId: productId ? parseInt(String(productId)) : null,
        imageUrl: images || null,
        isActive: isActive !== undefined ? isActive : true,
      },
    })

    return NextResponse.json(offer, { status: 201 })
  } catch (error) {
    console.error('Error creating offer:', error)
    return NextResponse.json(
      { error: 'Failed to create offer' },
      { status: 500 }
    )
  }
}
