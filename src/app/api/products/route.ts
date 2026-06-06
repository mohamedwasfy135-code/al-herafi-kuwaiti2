import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'
import { logAudit } from '@/lib/audit'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    const search = searchParams.get('search') || ''
    const category = searchParams.get('category') || ''

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const where: Record<string, unknown> = { businessId, isActive: true }

    if (search) {
      where.OR = [
        { name: { contains: search } },
        { nameEn: { contains: search } },
        { sku: { contains: search } },
        { barcode: { contains: search } },
      ]
    }

    if (category) {
      where.category = category
    }

    const products = await db.product.findMany({
      where,
      include: {
        business: {
          select: { id: true, name: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json(products)
  } catch (error) {
    console.error('Error fetching products:', error)
    return NextResponse.json(
      { error: 'Failed to fetch products' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      name,
      nameEn,
      description,
      sku,
      barcode,
      price,
      costPrice,
      discountPrice,
      stockQuantity,
      category,
      unit,
      images,
      isFeatured,
    } = body

    if (!rawBusinessId) {
      return NextResponse.json(
        { error: 'businessId and name are required' },
        { status: 400 }
      )
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    if (!name) {
      return NextResponse.json(
        { error: 'businessId and name are required' },
        { status: 400 }
      )
    }

    const product = await db.product.create({
      data: {
        businessId,
        name,
        nameEn,
        description,
        sku,
        barcode,
        price: parseFloat(String(price || 0)),
        costPrice: parseFloat(String(costPrice || 0)),
        discountPrice: discountPrice ? parseFloat(String(discountPrice)) : null,
        stockQuantity: parseInt(String(stockQuantity || 0)),
        category,
        unit,
        images,
        isFeatured: isFeatured || false,
      },
    })

    await logAudit({
      businessId,
      action: 'CREATE',
      entity: 'Product',
      entityId: product.id,
      changes: { after: { name: product.name, price: product.price } },
    })

    return NextResponse.json(product, { status: 201 })
  } catch (error) {
    console.error('Error creating product:', error)
    return NextResponse.json(
      { error: 'Failed to create product' },
      { status: 500 }
    )
  }
}
