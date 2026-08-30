import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { getSessionFromRequest } from '@/lib/auth'
import { z } from 'zod'

// مخطط التحقق من بيانات التقييم
const reviewSchema = z.object({
  requestId: z.number().int().positive(),
  ratedId: z.string().min(1, 'معرف الحرفي مطلوب'),
  stars: z.number().int().min(1).max(5, 'التقييم يجب أن يكون بين 1 و 5'),
  comment: z.string().max(500, 'التعليق طويل جداً').optional(),
  images: z.string().optional(),
})

// ═══════════════════════════════════════════════════════════════
// POST /api/reviews - إنشاء تقييم جديد
// ═══════════════════════════════════════════════════════════════
export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request)
    if (!session || session.role !== 'client') {
      return NextResponse.json({ error: 'غير مصرح - فقط العملاء يمكنهم التقييم' }, { status: 403 })
    }

    const body = await request.json()
    const validationResult = reviewSchema.safeParse(body)

    if (!validationResult.success) {
      return NextResponse.json(
        { error: 'بيانات غير صالحة', details: validationResult.error.flatten() },
        { status: 400 }
      )
    }

    const { requestId, ratedId, stars, comment, images } = validationResult.data
    const raterId = session.userId

    // 1. التحقق من أن العميل هو صاحب هذا الطلب بالفعل
    const req = await db.request.findUnique({
      where: { id: requestId },
      select: { clientId: true, status: true, craftsmanId: true }
    })

    if (!req) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 })
    }

    if (req.clientId !== raterId) {
      return NextResponse.json({ error: 'غير مصرح - هذا الطلب ليس لك' }, { status: 403 })
    }

    if (req.status !== 'completed' && req.status !== 'cancelled') {
      return NextResponse.json({ error: 'لا يمكن تقييم الطلب إلا بعد اكتماله أو إلغائه' }, { status: 400 })
    }

    if (req.craftsmanId !== ratedId) {
      return NextResponse.json({ error: 'الحرفي المحدد لا ينتمي لهذا الطلب' }, { status: 400 })
    }

    // 2. إنشاء التقييم (قاعدة البيانات ستمنع التكرار بسبب @@unique)
    const review = await db.rating.create({
      data: {
        requestId,
        raterId,
        ratedId,
        ratingType: 'craftsman',
        stars,
        comment: comment || null,
        images: images || null,
      },
    })

    // 3. تحديث متوسط تقييم الحرفي وعدد التقييمات
    const craftsman = await db.user.findUnique({
      where: { id: ratedId },
      select: { rating: true, total_ratings: true }
    })

    if (craftsman) {
      const oldTotal = craftsman.total_ratings || 0
      const oldRating = craftsman.rating || 0
      
      const newTotal = oldTotal + 1
      const newRating = ((oldRating * oldTotal) + stars) / newTotal

      await db.user.update({
        where: { id: ratedId },
        data: {
          total_ratings: newTotal,
          rating: Math.round(newRating * 10) / 10, // تقريب لمنزلة عشرية واحدة
        },
      })
    }

    return NextResponse.json({
      success: true,
      message: 'تم إضافة التقييم بنجاح',
      review,
    }, { status: 201 })

  } catch (error: any) {
    console.error('❌ Review creation error:', error)
    if (error.code === 'P2002') { // Prisma unique constraint violation
      return NextResponse.json({ error: 'لقد قمت بتقييم هذا الطلب مسبقاً' }, { status: 409 })
    }
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

// ═══════════════════════════════════════════════════════════════
// GET /api/reviews?ratedId=xxx - جلب تقييمات حرفي معين
// ═══════════════════════════════════════════════════════════════
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const ratedId = searchParams.get('ratedId')

    if (!ratedId) {
      return NextResponse.json({ error: 'معرف الحرفي (ratedId) مطلوب' }, { status: 400 })
    }

    const reviews = await db.rating.findMany({
      where: { ratedId, ratingType: 'craftsman' },
      include: {
        rater: {
          select: { name: true, avatarUrl: true }
        },
        request: {
          select: { id: true, serviceType: true }
        }
      },
      orderBy: { createdAt: 'desc' },
      take: 50, // آخر 50 تقييم فقط للأداء
    })

    const craftsman = await db.user.findUnique({
      where: { id: ratedId },
      select: { rating: true, total_ratings: true }
    })

    return NextResponse.json({
      success: true,
      craftsmanRating: craftsman?.rating || 0,
      totalReviews: craftsman?.total_ratings || 0,
      reviews,
    })

  } catch (error: any) {
    console.error('❌ Review fetch error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
