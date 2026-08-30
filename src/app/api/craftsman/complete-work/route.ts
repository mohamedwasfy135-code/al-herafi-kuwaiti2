import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';
import { VISIT_FEE } from '@/lib/myfatoorah';

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

    // ✅ التكلفة النهائية الفعلية = finalPrice المدخل من الفني (يشمل أي أعمال إضافية)
    // لو ما أدخل شي، نرجع للسعر المتفق عليه سابقاً
    const newFinalPrice = finalPrice ? parseFloat(finalPrice) : (req.agreedPrice || req.proposedPrice || 0);

    // ✅ المتبقي = التكلفة النهائية الفعلية ناقص رسوم الزيارة اللي سبق دفعها
    const visitFeeDeduction = req.visitFeePaid ? VISIT_FEE : 0;
    const newRemainingAmount = Math.max(newFinalPrice - visitFeeDeduction, 0);

    const updatedRequest = await db.request.update({
      where: { id: requestId },
      data: {
        status: 'completed',
        finalPrice: newFinalPrice,
        agreedPrice: newFinalPrice,       // ✅ نحدّث السعر المتفق عليه ليطابق التكلفة الفعلية
        remainingAmount: newRemainingAmount, // ✅ هذا هو الحقل اللي يستخدمه الدفع النهائي
        description: workNotes ? `${req.description}\n\n📝 ملاحظات الحرفي: ${workNotes}` : req.description,
        updatedAt: new Date(),
      },
    });

    await db.notification.create({
      data: {
        userId: req.clientId,
        title: '✅ تم إتمام العمل',
        body: `قام الحرفي بإتمام العمل على طلبك رقم #${requestId}. التكلفة النهائية: ${newFinalPrice} د.ك (المتبقي للدفع: ${newRemainingAmount} د.ك). يرجى الدفع لتأكيد الطلب.`,
        type: 'work_completed',
      },
    });

    console.log(`✅ [Complete Work] تم إتمام الطلب #${requestId} - التكلفة النهائية: ${newFinalPrice}, المتبقي: ${newRemainingAmount}`);

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
