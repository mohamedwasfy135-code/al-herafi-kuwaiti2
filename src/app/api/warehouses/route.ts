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

    const warehouses = await db.warehouse.findMany({
      where: { businessId },
      include: {
        _count: { select: { products: true } },
        products: {
          include: {
            product: { select: { price: true, costPrice: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    const warehousesWithValue = warehouses.map((w) => {
      const totalStockValue = w.products.reduce((sum, wp) => {
        return sum + wp.quantity * (wp.product.costPrice || wp.product.price)
      }, 0)
      return {
        id: w.id,
        name: w.name,
        nameEn: w.nameEn,
        code: w.code,
        address: w.address,
        managerName: w.managerName,
        managerPhone: w.managerPhone,
        isActive: w.isActive,
        productCount: w._count.products,
        totalStockValue,
        createdAt: w.createdAt,
      }
    })

    return NextResponse.json(warehousesWithValue)
  } catch (error) {
    console.error('[WAREHOUSES] GET error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { businessId: rawBusinessId, name, nameEn, code, address, managerName, managerPhone } = body

    if (!name) {
      return NextResponse.json({ error: 'اسم المستودع مطلوب' }, { status: 400 })
    }

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const warehouse = await db.warehouse.create({
      data: {
        businessId,
        name,
        nameEn: nameEn || null,
        code: code || null,
        address: address || null,
        managerName: managerName || null,
        managerPhone: managerPhone || null,
      },
    })

    return NextResponse.json(warehouse, { status: 201 })
  } catch (error) {
    console.error('[WAREHOUSES] POST error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
