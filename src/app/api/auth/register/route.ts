import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { createSessionToken, setSessionCookie } from '@/lib/auth'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { name, phone, password, role } = body

    console.log('[REGISTER] Attempt:', { name, phone, role })

    if (!name || !phone || !password) {
      return NextResponse.json(
        { error: 'الاسم ورقم الجوال وكلمة المرور مطلوبون' },
        { status: 400 }
      )
    }

    const validRole = ['craftsman', 'business', 'client'].includes(role) ? role : 'client'

    const existingUser = await db.user.findFirst({
      where: { phone: phone },
      select: { id: true }
    })

    if (existingUser) {
      console.log('[REGISTER] Phone already exists:', phone)
      return NextResponse.json(
        { error: 'رقم الجوال مسجل مسبقاً' },
        { status: 409 }
      )
    }

    const user = await db.user.create({
      data: {
        name,
        phone,
        password,
        role: validRole,
      }
    })

    // If business role, create a Business record
    if (validRole === 'business') {
      await db.business.create({
        data: {
          ownerId: user.id,
          name: name,
          phone: phone,
          businessType: 'shop',
        }
      })
    }

    // إنشاء JWT token
    const token = await createSessionToken({
      userId: user.id,
      role: user.role,
      name: user.name || '',
    })

    // إنشاء الاستجابة وضبط الكوكي عليها مباشرة
    let businessId: string | null = null
    if (validRole === 'business') {
      const biz = await db.business.findFirst({ where: { ownerId: user.id }, select: { id: true } })
      businessId = biz?.id || null
    }

    const response = NextResponse.json({
      success: true,
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        role: user.role,
        ...(businessId && { businessId }),
      }
    })

    setSessionCookie(response, token)

    console.log('[REGISTER] Success:', { id: user.id, role: user.role, name: user.name })

    return response

  } catch (error) {
    console.error('[REGISTER] Error:', error)
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    )
  }
}
