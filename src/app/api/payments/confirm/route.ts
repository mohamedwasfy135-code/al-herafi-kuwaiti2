import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'client') {
      return NextResponse.json({ error: 'غير مصرح - يجب تسجيل الدخول كعميل' }, { status: 401 });
    }

    const body = await request.json();
    const { requestId, paymentMethod } = body;

    if (!requestId) {
      return NextResponse.json({ error: 'رقم الطلب مطلوب' }, { status: 400 });
    }

    const req = await db.request.findUnique({
      where: { id: requestId },
      include: { craftsman: true }
    });

    if (!req) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 });
    }

    if (req.clientId !== session.userId) {
      return NextResponse.json({ error: 'هذا الطلب ليس لك' }, { status: 403 });
    }

    if (req.status !== 'completed') {
      return NextResponse.json({ error: 'لا يمكن الدفع إلا بعد إتمام العمل' }, { status: 400 });
    }

    // تحديث حالة الطلب إلى مدفوع
    await db.request.update({
      where: { id: requestId },
      data: {
        status: 'paid',
        updatedAt: new Date(),
      },
    });

    // إرسال إشعار للحرفي
    if (req.craftsmanId) {
      await db.notification.create({
        data: {
          userId: req.craftsmanId,
          title: '💰 تم استلام الدفع',
          body: `قام العميل بدفع قيمة طلبك رقم #${requestId}. يمكنك الآن سحب الأرباح.`,
          type: 'payment_received',
        },
      });
    }

    // إرسال إشعار للعميل
    await db.notification.create({
      data: {
        userId: session.userId,
        title: '✅ تم تأكيد الدفع',
        body: `تم الدفع بنجاح لطلب رقم #${requestId}. شكراً لاستخدامك منصة سناعي.`,
        type: 'payment_confirmed',
      },
    });

    console.log(`✅ [Payment] تم تأكيد الدفع للطلب #${requestId}`);

    return NextResponse.json({
      success: true,
      message: 'تم تأكيد الدفع بنجاح!',
    }, { status: 200 });

  } catch (error: any) {
    console.error('❌ خطأ في تأكيد الدفع:', error);
    return NextResponse.json({ error: error.message || 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
