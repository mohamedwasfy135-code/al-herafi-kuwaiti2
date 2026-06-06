import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const businessIdParam = searchParams.get('businessId')

    if (!businessIdParam) {
      return NextResponse.json(
        { error: 'businessId مطلوب' },
        { status: 400 }
      )
    }

    const businessId = await resolveBusinessId(businessIdParam)
    if (!businessId) {
      return NextResponse.json(
        { error: 'النشاط التجاري غير موجود' },
        { status: 404 }
      )
    }

    const users = await db.businessUser.findMany({
      where: { businessId },
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
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json(users)
  } catch (error) {
    console.error('[BUSINESS-USERS] GET Error:', error)
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { businessId: businessIdParam, name, phone, email, password, role, permissions } = body

    if (!businessIdParam) {
      return NextResponse.json(
        { error: 'businessId مطلوب' },
        { status: 400 }
      )
    }

    if (!name || !password) {
      return NextResponse.json(
        { error: 'الاسم وكلمة المرور مطلوبان' },
        { status: 400 }
      )
    }

    const businessId = await resolveBusinessId(businessIdParam)
    if (!businessId) {
      return NextResponse.json(
        { error: 'النشاط التجاري غير موجود' },
        { status: 404 }
      )
    }

    // Check for duplicate phone or email within the same business
    if (phone) {
      const existingPhone = await db.businessUser.findFirst({
        where: { businessId, phone },
      })
      if (existingPhone) {
        return NextResponse.json(
          { error: 'رقم الهاتف مستخدم بالفعل في هذا النشاط' },
          { status: 400 }
        )
      }
    }

    if (email) {
      const existingEmail = await db.businessUser.findFirst({
        where: { businessId, email },
      })
      if (existingEmail) {
        return NextResponse.json(
          { error: 'البريد الإلكتروني مستخدم بالفعل في هذا النشاط' },
          { status: 400 }
        )
      }
    }

    const validRoles = ['owner', 'accountant', 'seller']
    const userRole = validRoles.includes(role) ? role : 'seller'

    const user = await db.businessUser.create({
      data: {
        businessId,
        name,
        phone: phone || null,
        email: email || null,
        password,
        role: userRole,
        permissions: permissions || null,
        isActive: true,
      },
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

    return NextResponse.json(user, { status: 201 })
  } catch (error) {
    console.error('[BUSINESS-USERS] POST Error:', error)
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    )
  }
}
