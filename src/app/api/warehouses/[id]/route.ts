import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function PUT(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params
    const body = await request.json()
    const { name, nameEn, code, address, managerName, managerPhone, isActive } = body

    const warehouse = await db.warehouse.update({
      where: { id: parseInt(id) },
      data: {
        ...(name !== undefined && { name }),
        ...(nameEn !== undefined && { nameEn }),
        ...(code !== undefined && { code }),
        ...(address !== undefined && { address }),
        ...(managerName !== undefined && { managerName }),
        ...(managerPhone !== undefined && { managerPhone }),
        ...(isActive !== undefined && { isActive }),
      },
    })

    return NextResponse.json(warehouse)
  } catch (error) {
    console.error('[WAREHOUSE] PUT error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params
    await db.warehouse.delete({ where: { id: parseInt(id) } })
    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('[WAREHOUSE] DELETE error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
