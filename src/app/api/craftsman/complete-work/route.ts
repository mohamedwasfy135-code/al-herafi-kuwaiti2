import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح - يجب تسجيل الدخول كحرفي' }, { status: 401 });
    }

    const body = await request.json();
    const { requestId, finalPrice, workNotes, materialsUsed } = body;

    if (!requestId) {
      return NextResponse.json({ error: 'رقم الطلب مطلوب' }, { status: 400 });
    }

    // جلب الطلب والتحقق من ملكيته
    const req = await db.request.findUnique({
      where: { id: requestId },
      include: { client: true }
    });

    if (!req) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 });
    }

    if (req.craftsmanId !== session.userId) {
      return NextResponse.json({ error: 'هذا الطلب ليس مسنداً لك' }, { status: 403 });
    }

    if (req.status === 'completed' || req.status === 'paid') {
      return NextResponse.json({ error: 'الطلب مكتمل بالفعل' }, { status: 400 });
    }

    // تحديث الطلب
    const updatedRequest = await db.request.update({
      where: { id: requestId },
      data: {
        status: 'completed',
        finalPrice: finalPrice ? parseFloat(finalPrice) : null,
        description: workNotes ? `${req.description}\n\n📝 ملاحظات الحرفي: ${workNotes}` : req.description,
        updatedAt: new Date(),
      },
    });

    // إرسال إشعار للعميل
    await db.notification.create({
      data: {
        userId: req.clientId,
        title: '✅ تم إتمام العمل',
        body: `قام الحرفي بإتمام العمل على طلبك رقم #${requestId}.${finalPrice ? ` التكلفة النهائية: ${finalPrice} د.ك` : ''} يرجى الدفع لتأكيد الطلب.`,
        type: 'work_completed',
      },
    });

    console.log(`✅ [Complete Work] تم إتمام الطلب #${requestId} بواسطة الحرفي ${session.userId}`);

    return NextResponse.json({
      success: true,
      message: 'تم إتمام العمل بنجاح! تم إشعار العميل.',
      request: updatedRequest
    }, { status: 200 });

  } catch (error: any) {
    console.error('❌ خطأ في إتمام العمل:', error);
    return NextResponse.json({ error: error.message || 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
