import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

/**
 * POST /api/craftsman/start-work
 * الحرفي يبدأ العمل على الطلب
 * يتطلب: مصادقة الحرفي + الطلب في حالة accepted
 */
export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح - يجب تسجيل الدخول كحرفي' }, { status: 401 });
    }

    const body = await request.json();
    const { requestId } = body;

    if (!requestId) {
      return NextResponse.json({ error: 'رقم الطلب مطلوب' }, { status: 400 });
    }

    // جلب الطلب والتحقق من ملكيته
    const req = await db.request.findUnique({
      where: { id: requestId },
      include: { client: { select: { id: true, name: true, phone: true } } }
    });

    if (!req) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 });
    }

    if (req.craftsmanId !== session.userId) {
      return NextResponse.json({ error: 'هذا الطلب ليس مسنداً لك' }, { status: 403 });
    }

    if (req.status !== 'accepted') {
      return NextResponse.json({ 
        error: 'لا يمكن بدء العمل - الطلب يجب أن يكون في حالة "مقبول"' 
      }, { status: 400 });
    }

    // تحديث حالة الطلب إلى قيد التنفيذ
    await db.request.update({
      where: { id: requestId },
      data: {
        status: 'in_progress',
        updatedAt: new Date(),
      },
    });

    // إرسال إشعار للعميل
    await db.notification.create({
      data: {
        userId: req.clientId,
        title: '🔨 الحرفي في الطريق',
        body: `بدأ الحرفي العمل على طلبك رقم #${requestId}. سيتواصل معك قريباً.`,
        type: 'work_started',
      },
    });

    // إرسال إشعار للحرفي
    await db.notification.create({
      data: {
        userId: session.userId,
        title: '✅ تم بدء العمل',
        body: `بدأت العمل على طلب العميل ${req.client?.name || ''}. بالتوفيق!`,
        type: 'work_started_craftsman',
      },
    });

    console.log(`✅ [Start Work] الحرفي ${session.userId} بدأ العمل على الطلب #${requestId}`);

    return NextResponse.json({
      success: true,
      message: 'تم بدء العمل بنجاح! تم إشعار العميل.',
    }, { status: 200 });

  } catch (error: any) {
    console.error('❌ خطأ في بدء العمل:', error);
    return NextResponse.json({ error: error.message || 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
