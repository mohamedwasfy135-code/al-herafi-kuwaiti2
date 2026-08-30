import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const type = searchParams.get('type') // service أو business

    const where = type ? { type } : {}

    const categories = await db.category.findMany({
      where,
      select: {
        id: true,
        name: true,
        nameEn: true,
        icon: true,
        type: true,
      },
      orderBy: {
        name: 'asc',
      },
    })

    return NextResponse.json({
      success: true,
      categories,
    })
  } catch (error) {
    console.error('خطأ في GET /api/categories:', error)
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    )
  }
}
