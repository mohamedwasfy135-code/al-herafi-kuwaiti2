import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'

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

    const categories = await db.productCategory.findMany({
      where: { businessId },
      include: {
        children: {
          include: {
            _count: { select: { products: true } },
          },
        },
        _count: { select: { products: true } },
      },
      orderBy: { sortOrder: 'asc' },
    })

    // Only return root categories (parentId is null)
    const rootCategories = categories.filter((c) => !c.parentId)

    return NextResponse.json(rootCategories)
  } catch (error) {
    console.error('[PRODUCT_CATEGORIES] GET error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { businessId: rawBusinessId, name, nameEn, parentId, icon, sortOrder } = body

    if (!name) {
      return NextResponse.json({ error: 'اسم الفئة مطلوب' }, { status: 400 })
    }

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const category = await db.productCategory.create({
      data: {
        businessId,
        name,
        nameEn: nameEn || null,
        parentId: parentId || null,
        icon: icon || null,
        sortOrder: sortOrder || 0,
      },
    })

    return NextResponse.json(category, { status: 201 })
  } catch (error) {
    console.error('[PRODUCT_CATEGORIES] POST error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
