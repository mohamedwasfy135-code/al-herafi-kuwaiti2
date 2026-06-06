import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'
import { getSessionFromRequest } from '@/lib/auth'

// GET /api/business/profile - جلب بيانات النشاط التجاري
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const business = await db.business.findUnique({
      where: { id: businessId },
      include: {
        owner: {
          select: { id: true, name: true, phone: true, email: true, avatarUrl: true },
        },
        subscriptions: {
          select: { id: true, plan: true, startDate: true, endDate: true, autoRenew: true, status: true },
          take: 1,
          orderBy: { createdAt: 'desc' },
        },
      },
    })

    if (!business) {
      return NextResponse.json({ error: 'Business not found' }, { status: 404 })
    }

    return NextResponse.json(business)
  } catch (error) {
    console.error('Error fetching business profile:', error)
    return NextResponse.json(
      { error: 'Failed to fetch business profile' },
      { status: 500 }
    )
  }
}

// PUT /api/business/profile - تحديث بيانات النشاط التجاري
export async function PUT(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      name,
      nameEn,
      phone,
      email,
      website,
      businessType,
      governorate,
      city,
      address,
      description,
      logoUrl,
      coverUrl,
      invoiceFooterText,
    } = body

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId is required' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const updateData: Record<string, unknown> = {}
    if (name !== undefined) updateData.name = name
    if (nameEn !== undefined) updateData.nameEn = nameEn
    if (phone !== undefined) updateData.phone = phone
    if (email !== undefined) updateData.email = email
    if (website !== undefined) updateData.website = website
    if (businessType !== undefined) updateData.businessType = businessType
    if (governorate !== undefined) updateData.governorate = governorate
    if (city !== undefined) updateData.city = city
    if (address !== undefined) updateData.address = address
    if (description !== undefined) updateData.description = description
    if (logoUrl !== undefined) updateData.logoUrl = logoUrl
    if (coverUrl !== undefined) updateData.coverUrl = coverUrl
    if (invoiceFooterText !== undefined) updateData.invoiceFooterText = invoiceFooterText

    const business = await db.business.update({
      where: { id: businessId },
      data: updateData,
    })

    return NextResponse.json(business)
  } catch (error) {
    console.error('Error updating business profile:', error)
    return NextResponse.json(
      { error: 'Failed to update business profile' },
      { status: 500 }
    )
  }
}
