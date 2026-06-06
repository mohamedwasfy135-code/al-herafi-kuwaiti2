import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { logAudit } from '@/lib/audit'

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const productId = parseInt(id)

    const product = await db.product.findUnique({
      where: { id: productId },
      include: {
        business: {
          select: { id: true, name: true },
        },
        movements: {
          orderBy: { createdAt: 'desc' },
          take: 20,
        },
      },
    })

    if (!product) {
      return NextResponse.json(
        { error: 'Product not found' },
        { status: 404 }
      )
    }

    return NextResponse.json(product)
  } catch (error) {
    console.error('Error fetching product:', error)
    return NextResponse.json(
      { error: 'Failed to fetch product' },
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
    const productId = parseInt(id)
    const body = await request.json()

    const existing = await db.product.findUnique({ where: { id: productId } })
    if (!existing) {
      return NextResponse.json(
        { error: 'Product not found' },
        { status: 404 }
      )
    }

    const product = await db.product.update({
      where: { id: productId },
      data: {
        name: body.name,
        nameEn: body.nameEn,
        description: body.description,
        sku: body.sku,
        barcode: body.barcode,
        price: body.price !== undefined ? parseFloat(String(body.price)) : undefined,
        costPrice: body.costPrice !== undefined ? parseFloat(String(body.costPrice)) : undefined,
        discountPrice: body.discountPrice ? parseFloat(String(body.discountPrice)) : null,
        stockQuantity: body.stockQuantity !== undefined ? parseInt(String(body.stockQuantity)) : undefined,
        category: body.category,
        unit: body.unit,
        images: body.images,
        isActive: body.isActive,
        isFeatured: body.isFeatured,
      },
    })

    await logAudit({
      businessId: existing.businessId,
      action: 'UPDATE',
      entity: 'Product',
      entityId: product.id,
      changes: { before: { name: existing.name, price: existing.price }, after: { name: product.name, price: product.price } },
    })

    return NextResponse.json(product)
  } catch (error) {
    console.error('Error updating product:', error)
    return NextResponse.json(
      { error: 'Failed to update product' },
      { status: 500 }
    )
  }
}

export async function DELETE(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const productId = parseInt(id)

    const existing = await db.product.findUnique({ where: { id: productId } })
    if (!existing) {
      return NextResponse.json(
        { error: 'Product not found' },
        { status: 404 }
      )
    }

    // Before deleting, check if product has any transactions
    const invoiceItemCount = await db.salesInvoiceItem.count({ where: { productId } })
    const purchaseItemCount = await db.purchaseInvoiceItem.count({ where: { productId } })
    const movementCount = await db.productMovement.count({ where: { productId } })

    if (invoiceItemCount > 0 || purchaseItemCount > 0 || movementCount > 0) {
      return NextResponse.json(
        { error: 'لا يمكن حذف هذا المنتج لأنه مرتبط بمعاملات (فواتير أو حركات مخزون). يمكنك تعطيله بدلاً من ذلك.' },
        { status: 400 }
      )
    }

    await db.product.update({
      where: { id: productId },
      data: { isActive: false },
    })

    await logAudit({
      businessId: existing.businessId,
      action: 'DELETE',
      entity: 'Product',
      entityId: existing.id,
      changes: { before: { name: existing.name, price: existing.price } },
    })

    return NextResponse.json({ message: 'Product deleted successfully' })
  } catch (error) {
    console.error('Error deleting product:', error)
    return NextResponse.json(
      { error: 'Failed to delete product' },
      { status: 500 }
    )
  }
}
