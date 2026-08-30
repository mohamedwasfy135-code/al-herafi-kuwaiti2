import { NextResponse } from 'next/server'
import bcrypt from 'bcryptjs'
import { db } from '@/lib/db'
import { createSessionToken } from '@/lib/auth'

export async function POST(request: Request) {
  try {
    console.log('🔵 [LOGIN] بدء معالجة طلب تسجيل الدخول')
    
    const body = await request.json()
    console.log('🔵 [LOGIN] البيانات المستلمة:', { email: body.email, passwordExists: !!body.password })

    const { email, password } = body

    if (!email || !password) {
      console.log('🔴 [LOGIN] بيانات ناقصة')
      return NextResponse.json({ error: 'البريد الإلكتروني وكلمة المرور مطلوبة' }, { status: 400 })
    }

    console.log('🔵 [LOGIN] البحث عن المستخدم في قاعدة البيانات...')
    const user = await db.user.findUnique({ where: { email } })
    
    if (!user) {
      console.log('🔴 [LOGIN] المستخدم غير موجود')
      return NextResponse.json({ error: 'البريد الإلكتروني أو كلمة المرور غير صحيحة' }, { status: 401 })
    }

    console.log('🔵 [LOGIN] التحقق من كلمة المرور...')
    const isPasswordValid = await bcrypt.compare(password, user.password)
    if (!isPasswordValid) {
      console.log('🔴 [LOGIN] كلمة المرور غير صحيحة')
      return NextResponse.json({ error: 'البريد الإلكتروني أو كلمة المرور غير صحيحة' }, { status: 401 })
    }

    console.log('🔵 [LOGIN] إنشاء توكن الجلسة...')
    const token = await createSessionToken({
      userId: user.id,
      email: user.email,
      role: user.role,
      name: user.name,
    })

    console.log('🔵 [LOGIN] إعداد الاستجابة مع الكوكي...')
    const response = NextResponse.json({
      success: true,
      message: 'تم تسجيل الدخول بنجاح',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    })

    // الطريقة الآمنة والمعتمدة في Next.js لتعيين الكوكي
    response.cookies.set('sana3i_session', token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: 60 * 60 * 24 * 7, // 7 أيام
      path: '/',
    })

    console.log('🟢 [LOGIN] تم تسجيل الدخول بنجاح')
    return response

  } catch (error: any) {
    console.error('🔴 [LOGIN ERROR] خطأ فادح:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم: ' + error.message }, { status: 500 })
  }
}
