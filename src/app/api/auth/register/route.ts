import { NextResponse } from 'next/server'
import bcrypt from 'bcryptjs'
import { db } from '@/lib/db'
import { createSessionToken, setSessionCookie } from '@/lib/auth'
import { z } from 'zod'

const registerSchema = z.object({
  name: z.string().min(2, 'الاسم يجب أن يكون حرفين على الأقل'),
  email: z.string().email('بريد إلكتروني غير صالح'),
  password: z.string().min(6, 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
  phone: z.string().optional(),
  role: z.enum(['client', 'craftsman', 'business', 'admin']).default('client'),
  categoryId: z.number().int().positive().optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  businessName: z.string().optional(),
  businessDescription: z.string().optional(),
})

export async function POST(request: Request) {
  try {
    const body = await request.json()
    const validationResult = registerSchema.safeParse(body)

    if (!validationResult.success) {
      console.error('❌ فشل التحقق من البيانات:', validationResult.error.flatten())
      return NextResponse.json(
        { error: 'بيانات غير صالحة', details: validationResult.error.flatten().fieldErrors },
        { status: 400 }
      )
    }

    const { name, email, password, phone, role, categoryId, latitude, longitude, businessName, businessDescription } = validationResult.data

    // التحقق من الحرفي
    if (role === 'craftsman') {
      if (!categoryId) return NextResponse.json({ error: 'يجب على الحرفي اختيار التخصص المهني' }, { status: 400 })
      if (!phone) return NextResponse.json({ error: 'رقم الهاتف مطلوب للحرفي' }, { status: 400 })
      if (latitude === undefined || longitude === undefined) {
        return NextResponse.json({ error: 'الموقع الجغرافي مطلوب للحرفي' }, { status: 400 })
      }
      const categoryExists = await db.category.findUnique({ where: { id: categoryId } })
      if (!categoryExists) return NextResponse.json({ error: 'التصنيف المهني غير موجود' }, { status: 404 })
    }

    // التحقق من المحل
    if (role === 'business') {
      if (!businessName) return NextResponse.json({ error: 'يجب إدخال اسم المحل' }, { status: 400 })
    }

    const existingUser = await db.user.findUnique({ where: { email } })
    if (existingUser) {
      return NextResponse.json({ error: 'البريد الإلكتروني مستخدم بالفعل' }, { status: 409 })
    }

    const hashedPassword = await bcrypt.hash(password, 10)

    // ✅ إنشاء المستخدم (categoryId يُحفظ هنا حسب المخطط الحالي)
    const user = await db.user.create({
      data: {
        name,
        email,
        password: hashedPassword,
        role,
        phone: phone || null,
        categoryId: (role === 'craftsman' || role === 'business') ? categoryId : null,
        latitude: role === 'craftsman' ? latitude : null,
        longitude: role === 'craftsman' ? longitude : null,
        verification_status: role === 'craftsman' ? 'pending' : 'approved',
        is_available: role === 'craftsman' ? false : true,
      },
    })

    if (role === 'craftsman') {
      await db.craftsmanIDocument.create({
        data: { craftsmanId: user.id, status: 'pending' },
      })
    }

    // ✅ إنشاء سجل المحل (بدون categoryId لأنه غير موجود في نموذج Business حسب المخطط الحالي)
    if (role === 'business' && businessName) {
      await db.business.create({
        data: {
          ownerId: user.id,
          name: businessName,
          description: businessDescription || null,
          phone: phone || null,
          email: email,
        },
      })
    }

    const token = await createSessionToken({
      userId: user.id,
      role: user.role,
      name: user.name,
    })

    const response = NextResponse.json(
      {
        success: true,
        message: 'تم إنشاء الحساب بنجاح',
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
          categoryId: user.categoryId,
          verification_status: user.verification_status,
        },
        requiresDocuments: role === 'craftsman',
      },
      { status: 201 }
    )

    setSessionCookie(response, token)
    return response
  } catch (error: any) {
    console.error('❌ Register error:', error)
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم', details: error.message },
      { status: 500 }
    )
  }
}
