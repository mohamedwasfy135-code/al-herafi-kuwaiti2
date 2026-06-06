import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { sourceProductId, targetProductId } = body

    if (!sourceProductId || !targetProductId) {
      return NextResponse.json({ error: 'يجب تحديد المنتج المصدر والمنتج الهدف' }, { status: 400 })
    }

    if (sourceProductId === targetProductId) {
      return NextResponse.json({ error: 'لا يمكن دمج المنتج مع نفسه' }, { status: 400 })
    }

    // Verify both products exist and belong to the business
    const [source, target] = await Promise.all([
      db.product.findUnique({ where: { id: sourceProductId } }),
      db.product.findUnique({ where: { id: targetProductId } }),
    ])

    if (!source || !target) {
      return NextResponse.json({ error: 'أحد المنتجات غير موجود' }, { status: 404 })
    }

    if (!source.isActive) {
      return NextResponse.json({ error: 'لا يمكن دمج منتج معطل' }, { status: 400 })
    }

    // Use a transaction to ensure atomicity
    const result = await db.$transaction(async (tx) => {
      // 1. Move all SalesInvoiceItems from source to target
      await tx.salesInvoiceItem.updateMany({
        where: { productId: sourceProductId },
        data: { productId: targetProductId },
      })

      // 2. Move all PurchaseInvoiceItems from source to target
      await tx.purchaseInvoiceItem.updateMany({
        where: { productId: sourceProductId },
        data: { productId: targetProductId },
      })

      // 3. Move all ProductMovements from source to target
      await tx.productMovement.updateMany({
        where: { productId: sourceProductId },
        data: { productId: targetProductId },
      })

      // 4. Move all WarehouseProducts from source to target
      // For warehouse products, we need to merge quantities if target already has an entry in same warehouse
      const sourceWarehouseProducts = await tx.warehouseProduct.findMany({
        where: { productId: sourceProductId },
      })

      for (const swp of sourceWarehouseProducts) {
        const existingTarget = await tx.warehouseProduct.findUnique({
          where: {
            warehouseId_productId: {
              warehouseId: swp.warehouseId,
              productId: targetProductId,
            },
          },
        })

        if (existingTarget) {
          // Merge quantities
          await tx.warehouseProduct.update({
            where: { id: existingTarget.id },
            data: { quantity: existingTarget.quantity + swp.quantity },
          })
          await tx.warehouseProduct.delete({ where: { id: swp.id } })
        } else {
          // Move to target product
          await tx.warehouseProduct.update({
            where: { id: swp.id },
            data: { productId: targetProductId },
          })
        }
      }

      // 5. Add source stock to target stock
      await tx.product.update({
        where: { id: targetProductId },
        data: {
          stockQuantity: { increment: source.stockQuantity },
        },
      })

      // 6. Soft-delete the source product
      await tx.product.update({
        where: { id: sourceProductId },
        data: { isActive: false },
      })

      return await tx.product.findUnique({ where: { id: targetProductId } })
    })

    return NextResponse.json({ message: 'تم دمج المنتجات بنجاح', product: result })
  } catch (error) {
    console.error('Error merging products:', error)
    return NextResponse.json({ error: 'فشل دمج المنتجات' }, { status: 500 })
  }
}
