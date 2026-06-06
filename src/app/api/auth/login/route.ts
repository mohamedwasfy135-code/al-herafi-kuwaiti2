import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { createSessionToken, setSessionCookie } from '@/lib/auth'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { phone, email, password, loginType } = body

    console.log('[LOGIN] Attempt:', { phone, email, loginType })

    if (!password) {
      return NextResponse.json(
        { error: 'كلمة المرور مطلوبة' },
        { status: 400 }
      )
    }

    // Business sub-user login (seller/accountant)
    if (loginType === 'business_user') {
      if (!phone && !email) {
        return NextResponse.json(
          { error: 'رقم الجوال أو البريد الإلكتروني مطلوب' },
          { status: 400 }
        )
      }

      // Find BusinessUser by phone or email
      const businessUser = await db.businessUser.findFirst({
        where: {
          OR: [
            ...(phone ? [{ phone }] : []),
            ...(email ? [{ email }] : []),
          ],
          isActive: true,
        },
        include: {
          business: {
            select: { id: true, name: true },
          },
        },
      })

      if (!businessUser) {
        console.log('[LOGIN] Business user not found:', { phone, email })
        return NextResponse.json(
          { error: 'المستخدم غير موجود أو الحساب معطل' },
          { status: 401 }
        )
      }

      if (businessUser.password !== password) {
        console.log('[LOGIN] Wrong password for business user:', businessUser.name)
        return NextResponse.json(
          { error: 'كلمة المرور غير صحيحة' },
          { status: 401 }
        )
      }

      // Create JWT token for business sub-user
      const token = await createSessionToken({
        userId: businessUser.id,
        role: 'business',
        name: businessUser.name,
      })

      const responseJson = {
        success: true,
        user: {
          id: businessUser.id,
          name: businessUser.name,
          phone: businessUser.phone,
          email: businessUser.email,
          role: 'business',
          businessId: businessUser.businessId,
          businessName: businessUser.business.name,
          businessRole: businessUser.role,
          permissions: businessUser.permissions,
        },
      }

      const response = NextResponse.json(responseJson)
      setSessionCookie(response, token)

      console.log('[LOGIN] Business user success:', { id: businessUser.id, role: businessUser.role, name: businessUser.name })
      return response
    }

    // Regular owner login (existing logic)
    if (!phone) {
      return NextResponse.json(
        { error: 'رقم الجوال مطلوب' },
        { status: 400 }
      )
    }

    const user = await db.user.findFirst({
      where: { phone: phone },
      select: {
        id: true,
        name: true,
        phone: true,
        password: true,
        role: true,
        avatarUrl: true,
      }
    })

    if (!user) {
      console.log('[LOGIN] User not found:', phone)
      return NextResponse.json(
        { error: 'رقم الجوال أو كلمة المرور غير صحيحة' },
        { status: 401 }
      )
    }

    if (user.password !== password) {
      console.log('[LOGIN] Wrong password for:', phone)
      return NextResponse.json(
        { error: 'رقم الجوال أو كلمة المرور غير صحيحة' },
        { status: 401 }
      )
    }

    // إنشاء JWT token
    const token = await createSessionToken({
      userId: user.id,
      role: user.role,
      name: user.name || '',
    })

    // إنشاء الاستجابة وضبط الكوكي عليها مباشرة
    const responseJson: Record<string, unknown> = {
      success: true,
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        role: user.role,
        avatarUrl: user.avatarUrl,
      }
    }

    // If business user, include the business ID
    if (user.role === 'business') {
      const business = await db.business.findFirst({
        where: { ownerId: user.id },
        select: { id: true, name: true }
      })
      if (business) {
        (responseJson.user as Record<string, unknown>).businessId = business.id
        ;(responseJson.user as Record<string, unknown>).businessName = business.name
      }
    }

    const response = NextResponse.json(responseJson)
    setSessionCookie(response, token)

    console.log('[LOGIN] Success:', { id: user.id, role: user.role, name: user.name })
    return response

  } catch (error: any) {
    console.error('[LOGIN] Error:', error?.message || error)

    // Return more helpful error message
    const errorMsg = (error?.message || '') + ' ' + (error?.code || '')
    let userMessage = 'حدث خطأ في الخادم'

    if (errorMsg.includes('does not exist') || errorMsg.includes('relation') || errorMsg.includes('table') || errorMsg.includes('P2021')) {
      userMessage = 'جداول قاعدة البيانات غير موجودة بعد. يرجى تشغيل npx prisma db push أولاً أو إعداد قاعدة البيانات من /api/setup'
    } else if (errorMsg.includes('connect') || errorMsg.includes('ECONNREFUSED') || errorMsg.includes('timeout') || errorMsg.includes('P1001') || errorMsg.includes('P1002')) {
      userMessage = 'فشل الاتصال بقاعدة البيانات. تأكد من إعداد DATABASE_URL بشكل صحيح في Vercel Environment Variables'
    } else if (errorMsg.includes('P1003') || errorMsg.includes('database') && errorMsg.includes('not found')) {
      userMessage = 'قاعدة البيانات غير موجودة. تحقق من رابط DATABASE_URL'
    } else if (errorMsg.includes('authentication') || errorMsg.includes('password') || errorMsg.includes('P1000')) {
      userMessage = 'فشل المصادقة على قاعدة البيانات. تحقق من كلمة السر في DATABASE_URL'
    } else if (errorMsg.includes('env') || errorMsg.includes('DATABASE_URL') || errorMsg.includes('undefined')) {
      userMessage = 'متغيرات البيئة غير مضبوطة. أضف DATABASE_URL و DIRECT_URL و JWT_SECRET في إعدادات Vercel'
    }

    return NextResponse.json(
      { error: userMessage, debug: process.env.NODE_ENV === 'development' ? errorMsg.trim() : undefined },
      { status: 500 }
    )
  }
}
