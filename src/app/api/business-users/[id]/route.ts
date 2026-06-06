import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    const user = await db.businessUser.findUnique({
      where: { id },
      select: {
        id: true,
        businessId: true,
        userId: true,
        name: true,
        phone: true,
        email: true,
        role: true,
        permissions: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
    })

    if (!user) {
      return NextResponse.json(
        { error: 'المستخدم غير موجود' },
        { status: 404 }
      )
    }

    return NextResponse.json(user)
  } catch (error) {
    console.error('[BUSINESS-USERS] GET [id] Error:', error)
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    )
  }
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const body = await request.json()
    const { name, phone, email, password, role, permissions, isActive } = body

    const existing = await db.businessUser.findUnique({ where: { id } })
    if (!existing) {
      return NextResponse.json(
        { error: 'المستخدم غير موجود' },
        { status: 404 }
      )
    }

    // Check for duplicate phone within the same business (excluding current user)
    if (phone && phone !== existing.phone) {
      const duplicatePhone = await db.businessUser.findFirst({
        where: { businessId: existing.businessId, phone, id: { not: id } },
      })
      if (duplicatePhone) {
        return NextResponse.json(
          { error: 'رقم الهاتف مستخدم بالفعل في هذا النشاط' },
          { status: 400 }
        )
      }
    }

    // Check for duplicate email within the same business (excluding current user)
    if (email && email !== existing.email) {
      const duplicateEmail = await db.businessUser.findFirst({
        where: { businessId: existing.businessId, email, id: { not: id } },
      })
      if (duplicateEmail) {
        return NextResponse.json(
          { error: 'البريد الإلكتروني مستخدم بالفعل في هذا النشاط' },
          { status: 400 }
        )
      }
    }

    const validRoles = ['owner', 'accountant', 'seller']
    const updateData: Record<string, unknown> = {}
    if (name !== undefined) updateData.name = name
    if (phone !== undefined) updateData.phone = phone || null
    if (email !== undefined) updateData.email = email || null
    if (password !== undefined) updateData.password = password
    if (role !== undefined && validRoles.includes(role)) updateData.role = role
    if (permissions !== undefined) updateData.permissions = permissions
    if (isActive !== undefined) updateData.isActive = isActive

    const updated = await db.businessUser.update({
      where: { id },
      data: updateData,
      select: {
        id: true,
        businessId: true,
        userId: true,
        name: true,
        phone: true,
        email: true,
        role: true,
        permissions: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
    })

    return NextResponse.json(updated)
  } catch (error) {
    console.error('[BUSINESS-USERS] PATCH [id] Error:', error)
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    )
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    const existing = await db.businessUser.findUnique({ where: { id } })
    if (!existing) {
      return NextResponse.json(
        { error: 'المستخدم غير موجود' },
        { status: 404 }
      )
    }

    await db.businessUser.delete({ where: { id } })

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('[BUSINESS-USERS] DELETE [id] Error:', error)
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    )
  }
}
