import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const search = searchParams.get('search') || ''
    const businessType = searchParams.get('type') || ''

    const where: Record<string, unknown> = { isActive: true }

    if (search) {
      where.OR = [
        { name: { contains: search } },
        { nameEn: { contains: search } },
        { phone: { contains: search } },
        { email: { contains: search } },
      ]
    }

    if (businessType) {
      where.businessType = businessType
    }

    const businesses = await db.business.findMany({
      where,
      include: {
        owner: {
          select: { id: true, name: true, phone: true },
        },
        categoryRef: {
          select: { id: true, name: true },
        },
        _count: {
          select: { products: true, requests: true, businessClients: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json(businesses)
  } catch (error) {
    console.error('Error fetching businesses:', error)
    return NextResponse.json(
      { error: 'Failed to fetch businesses' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      ownerId,
      name,
      nameEn,
      description,
      phone,
      email,
      website,
      businessType,
      categoryId,
      governorate,
      city,
      address,
    } = body

    if (!ownerId || !name) {
      return NextResponse.json(
        { error: 'ownerId and name are required' },
        { status: 400 }
      )
    }

    const business = await db.business.create({
      data: {
        ownerId,
        name,
        nameEn,
        description,
        phone,
        email,
        website,
        businessType: businessType || 'shop',
        categoryId: categoryId ? parseInt(String(categoryId)) : null,
        governorate,
        city,
        address,
      },
    })

    return NextResponse.json(business, { status: 201 })
  } catch (error) {
    console.error('Error creating business:', error)
    return NextResponse.json(
      { error: 'Failed to create business' },
      { status: 500 }
    )
  }
}
