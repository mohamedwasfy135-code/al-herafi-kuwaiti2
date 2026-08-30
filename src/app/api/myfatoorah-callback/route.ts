import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const paymentId = searchParams.get('paymentId') || searchParams.get('id');
    const status = searchParams.get('status');

    console.log('📥 [Callback] استلام إشعار:', { paymentId, status });

    if (!paymentId) {
      console.error('❌ PaymentId مفقود من الرابط');
      return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
    }

    // البحث عن المعاملة باستخدام paymentId
    const transaction = await db.paymentTransaction.findFirst({
      where: { paymentId },
      include: { request: true }
    });

    if (!transaction) {
      console.error(`❌ لم يتم العثور على معاملة بـ paymentId: ${paymentId}`);
      // توجيه العميل للوحة التحكم مع رسالة خطأ واضحة
      return NextResponse.redirect(new URL('/dashboard/client?msg=transaction_not_found', request.url));
    }

    console.log('✅ تم العثور على المعاملة:', { 
      id: transaction.id, 
      type: transaction.type, 
      currentStatus: transaction.status 
    });

    // تحديث الحالة فقط إذا كانت ناجحة ولم تكن مدفوعة مسبقاً
    if (status === 'success' && transaction.status !== 'paid') {
      const updateData: any = { paymentStatus: 'paid' };
      
      if (transaction.type === 'visit_fee') {
        updateData.visitFeePaid = true;
        updateData.status = 'in_progress';
      } else if (transaction.type === 'final_payment') {
        updateData.status = 'paid';
      }

      // تحديث حالة الطلب
      await db.request.update({
        where: { id: transaction.request.id },
        data: updateData
      });

      // تحديث حالة المعاملة
      await db.paymentTransaction.update({
        where: { id: transaction.id },
        data: { status: 'paid', updatedAt: new Date() }
      });

      console.log('✅ تم تحديث الحالة بنجاح:', updateData);
    } else {
      console.warn('⚠️ الدفع ليس ناجحاً أو المعاملة مدفوعة مسبقاً:', { status, dbStatus: transaction.status });
    }

    // التوجيه لصفحة العميل مع الرسالة المناسبة
    const msg = status === 'success' 
      ? (transaction.type === 'visit_fee' ? 'visit_fee_paid' : 'final_payment_paid')
      : 'payment_failed';
      
    return NextResponse.redirect(new URL(`/dashboard/client?msg=${msg}`, request.url));

  } catch (error: any) {
    console.error('💥 خطأ فادح في Callback:', error);
    // في حالة الخطأ الفادح، نوجه العميل للوحة التحكم مع رسالة خطأ
    return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
  }
}
