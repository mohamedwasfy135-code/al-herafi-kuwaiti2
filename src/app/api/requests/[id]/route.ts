import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const requestId = parseInt(id)

    const requestRecord = await db.request.findUnique({
      where: { id: requestId },
      include: {
        client: {
          select: { id: true, name: true, phone: true, email: true, avatarUrl: true },
        },
        craftsman: {
          select: { id: true, name: true, phone: true, email: true, avatarUrl: true, rating: true },
        },
        business: {
          select: { id: true, name: true, phone: true },
        },
        priceOffers: {
          include: {
            craftsman: {
              select: { id: true, name: true, rating: true },
            },
          },
        },
        reviews: true,
        workPhotos: true,
        payments: true,
      },
    })

    if (!requestRecord) {
      return NextResponse.json(
        { error: 'Request not found' },
        { status: 404 }
      )
    }

    return NextResponse.json(requestRecord)
  } catch (error) {
    console.error('Error fetching request:', error)
    return NextResponse.json(
      { error: 'Failed to fetch request' },
      { status: 500 }
    )
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const requestId = parseInt(id)
    const body = await request.json()

    const existing = await db.request.findUnique({ where: { id: requestId } })
    if (!existing) {
      return NextResponse.json(
        { error: 'Request not found' },
        { status: 404 }
      )
    }

    const updateData: Record<string, unknown> = {}

    if (body.status) {
      updateData.status = body.status
    }
    if (body.craftsmanId !== undefined) {
      updateData.craftsmanId = body.craftsmanId
    }
    if (body.agreedPrice !== undefined) {
      updateData.agreedPrice = parseFloat(String(body.agreedPrice))
    }
    if (body.finalPrice !== undefined) {
      updateData.finalPrice = parseFloat(String(body.finalPrice))
    }
    if (body.description !== undefined) {
      updateData.description = body.description
    }
    if (body.status === 'accepted' || body.status === 'in_progress') {
      updateData.assignedAt = new Date()
    }

    const updated = await db.request.update({
      where: { id: requestId },
      data: updateData,
    })

    return NextResponse.json(updated)
  } catch (error) {
    console.error('Error updating request:', error)
    return NextResponse.json(
      { error: 'Failed to update request' },
      { status: 500 }
    )
  }
}
