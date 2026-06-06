import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    const warehouseId = searchParams.get('warehouseId')

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId is required' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'Business not found' }, { status: 404 })
    }

    if (warehouseId) {
      // Get products for a specific warehouse
      const warehouseProducts = await db.warehouseProduct.findMany({
        where: {
          warehouseId: parseInt(warehouseId),
          warehouse: { businessId },
        },
        include: {
          product: {
            select: {
              id: true,
              name: true,
              stockQuantity: true,
              price: true,
              costPrice: true,
              unit: true,
              isActive: true,
            },
          },
        },
      })

      const result = warehouseProducts
        .filter((wp) => wp.product.isActive)
        .map((wp) => ({
          productId: wp.productId,
          warehouseId: wp.warehouseId,
          warehouseQuantity: wp.quantity,
          product: wp.product,
        }))

      return NextResponse.json(result)
    }

    // Get all warehouse-product relationships for the business
    const warehouseProducts = await db.warehouseProduct.findMany({
      where: {
        warehouse: { businessId },
      },
      include: {
        product: {
          select: {
            id: true,
            name: true,
            stockQuantity: true,
            isActive: true,
          },
        },
      },
    })

    const result = warehouseProducts
      .filter((wp) => wp.product.isActive)
      .map((wp) => ({
        productId: wp.productId,
        warehouseId: wp.warehouseId,
        warehouseQuantity: wp.quantity,
      }))

    return NextResponse.json(result)
  } catch (error) {
    console.error('[WAREHOUSE-PRODUCTS] GET error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
