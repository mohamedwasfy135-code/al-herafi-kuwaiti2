import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const status = searchParams.get('status') || ''
    const businessId = searchParams.get('businessId') || ''
    const page = parseInt(searchParams.get('page') || '1')
    const limit = parseInt(searchParams.get('limit') || '20')
    const skip = (page - 1) * limit

    const where: Record<string, unknown> = {}

    if (status) {
      where.status = status
    }

    if (businessId) {
      where.businessId = businessId
    }

    const [requests, total] = await Promise.all([
      db.request.findMany({
        where,
        include: {
          client: {
            select: { id: true, name: true, phone: true },
          },
          craftsman: {
            select: { id: true, name: true, phone: true },
          },
          business: {
            select: { id: true, name: true },
          },
          priceOffers: {
            select: { id: true, proposedPrice: true, status: true },
          },
          _count: {
            select: { reviews: true, workPhotos: true },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      db.request.count({ where }),
    ])

    return NextResponse.json({
      data: requests,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    })
  } catch (error) {
    console.error('Error fetching requests:', error)
    return NextResponse.json(
      { error: 'Failed to fetch requests' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      clientId,
      craftsmanId,
      businessId,
      serviceType,
      description,
      images,
      governorate,
      city,
      address,
      estimatedPrice,
    } = body

    if (!clientId || !serviceType) {
      return NextResponse.json(
        { error: 'clientId and serviceType are required' },
        { status: 400 }
      )
    }

    const newRequest = await db.request.create({
      data: {
        clientId,
        craftsmanId,
        businessId,
        serviceType,
        description,
        images,
        governorate,
        city,
        address,
        estimatedPrice: estimatedPrice ? parseFloat(String(estimatedPrice)) : null,
      },
    })

    return NextResponse.json(newRequest, { status: 201 })
  } catch (error) {
    console.error('Error creating request:', error)
    return NextResponse.json(
      { error: 'Failed to create request' },
      { status: 500 }
    )
  }
}
