import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

// GET /api/offers/[id] - جلب عرض واحد
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const offer = await db.offer.findUnique({
      where: { id: parseInt(id) },
    })

    if (!offer) {
      return NextResponse.json({ error: 'Offer not found' }, { status: 404 })
    }

    return NextResponse.json(offer)
  } catch (error) {
    console.error('Error fetching offer:', error)
    return NextResponse.json({ error: 'Failed to fetch offer' }, { status: 500 })
  }
}

// PUT /api/offers/[id] - تحديث عرض
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const body = await request.json()
    const {
      title,
      description,
      discountPercentage,
      originalPrice,
      offerPrice,
      startDate,
      endDate,
      isActive,
      images,
    } = body

    const offer = await db.offer.update({
      where: { id: parseInt(id) },
      data: {
        ...(title !== undefined && { title }),
        ...(description !== undefined && { description }),
        ...(discountPercentage !== undefined && { discountPercentage: discountPercentage ? parseFloat(String(discountPercentage)) : null }),
        ...(originalPrice !== undefined && { originalPrice: originalPrice ? parseFloat(String(originalPrice)) : null }),
        ...(offerPrice !== undefined && { offerPrice: offerPrice ? parseFloat(String(offerPrice)) : null }),
        ...(startDate !== undefined && { startDate: startDate ? new Date(startDate) : null }),
        ...(endDate !== undefined && { endDate: endDate ? new Date(endDate) : null }),
        ...(isActive !== undefined && { isActive }),
        ...(images !== undefined && { images }),
      },
    })

    return NextResponse.json(offer)
  } catch (error) {
    console.error('Error updating offer:', error)
    return NextResponse.json({ error: 'Failed to update offer' }, { status: 500 })
  }
}

// DELETE /api/offers/[id] - حذف عرض
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    await db.offer.delete({
      where: { id: parseInt(id) },
    })

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Error deleting offer:', error)
    return NextResponse.json({ error: 'Failed to delete offer' }, { status: 500 })
  }
}
