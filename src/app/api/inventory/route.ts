import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    const productId = searchParams.get('productId')
    const warehouseId = searchParams.get('warehouseId')
    const movementType = searchParams.get('movementType')
    const dateFrom = searchParams.get('dateFrom')
    const dateTo = searchParams.get('dateTo')

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const where: Record<string, unknown> = { businessId }
    if (productId) where.productId = parseInt(productId)
    if (warehouseId) where.warehouseId = parseInt(warehouseId)
    if (movementType) where.movementType = movementType
    if (dateFrom || dateTo) {
      where.createdAt = {
        ...(dateFrom && { gte: new Date(dateFrom) }),
        ...(dateTo && { lte: new Date(dateTo) }),
      }
    }

    const movements = await db.productMovement.findMany({
      where,
      include: {
        product: { select: { id: true, name: true, unit: true } },
        warehouse: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    })

    return NextResponse.json(movements)
  } catch (error) {
    console.error('[INVENTORY] GET error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      productId,
      warehouseId,
      movementType,
      quantity,
      notes,
    } = body

    if (!productId || !movementType || !quantity) {
      return NextResponse.json(
        { error: 'المنتج ونوع الحركة والكمية مطلوبون' },
        { status: 400 }
      )
    }

    const validTypes = ['in', 'out', 'transfer', 'adjustment', 'return']
    if (!validTypes.includes(movementType)) {
      return NextResponse.json({ error: 'نوع الحركة غير صحيح' }, { status: 400 })
    }

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    // Create the movement record
    const movement = await db.productMovement.create({
      data: {
        businessId,
        productId: parseInt(productId),
        warehouseId: warehouseId ? parseInt(warehouseId) : null,
        movementType,
        quantity: parseInt(quantity),
        notes: notes || null,
      },
    })

    // Update product stock quantity
    const product = await db.product.findUnique({ where: { id: parseInt(productId) } })
    if (product) {
      let newQty = product.stockQuantity
      if (movementType === 'in' || movementType === 'return') {
        newQty += parseInt(quantity)
      } else if (movementType === 'out') {
        newQty -= parseInt(quantity)
      } else if (movementType === 'adjustment') {
        newQty = parseInt(quantity) // adjustment sets the quantity directly
      }
      await db.product.update({
        where: { id: parseInt(productId) },
        data: { stockQuantity: Math.max(0, newQty) },
      })
    }

    // Update warehouse product quantity if warehouse specified
    if (warehouseId) {
      const wp = await db.warehouseProduct.findUnique({
        where: {
          warehouseId_productId: {
            warehouseId: parseInt(warehouseId),
            productId: parseInt(productId),
          },
        },
      })

      if (wp) {
        let newQty = wp.quantity
        if (movementType === 'in' || movementType === 'return') {
          newQty += parseInt(quantity)
        } else if (movementType === 'out') {
          newQty -= parseInt(quantity)
        } else if (movementType === 'adjustment') {
          newQty = parseInt(quantity)
        }
        await db.warehouseProduct.update({
          where: { id: wp.id },
          data: { quantity: Math.max(0, newQty) },
        })
      } else {
        // Create warehouse product entry
        await db.warehouseProduct.create({
          data: {
            warehouseId: parseInt(warehouseId),
            productId: parseInt(productId),
            quantity: (movementType === 'in' || movementType === 'return') ? parseInt(quantity) : 0,
          },
        })
      }
    }

    return NextResponse.json(movement, { status: 201 })
  } catch (error) {
    console.error('[INVENTORY] POST error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
