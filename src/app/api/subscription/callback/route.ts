import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const invoiceId = searchParams.get('paymentId') || searchParams.get('id');
    const status = searchParams.get('status');

    console.log('📥 [Subscription Callback] استلام إشعار:', { invoiceId, status });

    if (!invoiceId) {
      return NextResponse.redirect(new URL('/craftsman/dashboard?msg=callback_error', request.url));
    }

    // البحث عن سجل الدفع المعلق
    const payment = await db.subscriptionPayment.findFirst({
      where: {
        OR: [
          { invoiceId: String(invoiceId) },
          { paymentId: String(invoiceId) }
        ],
        status: 'pending'
      },
      include: { user: true }
    });

    if (!payment) {
      console.error(`❌ لم يتم العثور على دفعة معلقة للمعرف: ${invoiceId}`);
      return NextResponse.redirect(new URL('/craftsman/dashboard?msg=transaction_not_found', request.url));
    }

    if (status?.toLowerCase() === 'success') {
      // ✅ تحديث حالة الدفع
      await db.subscriptionPayment.update({
        where: { id: payment.id },
        data: { status: 'paid' }
      });

      // ✅ تمديد اشتراك الحرفي لمدة شهر من تاريخ الدفع (أو من تاريخ النهاية الحالي إذا كان نشطاً)
      const baseDate = payment.user.subscriptionStatus === 'active' && payment.user.subscriptionExpiryDate 
        ? new Date(payment.user.subscriptionExpiryDate) 
        : new Date();
      
      const newExpiryDate = new Date(baseDate);
      newExpiryDate.setMonth(newExpiryDate.getMonth() + 1);

      await db.user.update({
        where: { id: payment.userId },
        data: {
          subscriptionStatus: 'active',
          subscriptionExpiryDate: newExpiryDate
        }
      });

      console.log(`✅ تم تجديد اشتراك الحرفي ${payment.userId} حتى ${newExpiryDate.toLocaleDateString('ar-KW')}`);
      
      return NextResponse.redirect(new URL('/craftsman/dashboard?msg=subscription_renewed', request.url));
    } else {
      // فشل الدفع
      await db.subscriptionPayment.update({
        where: { id: payment.id },
        data: { status: 'failed' }
      });
      return NextResponse.redirect(new URL('/craftsman/dashboard?msg=payment_failed', request.url));
    }

  } catch (error: any) {
    console.error('💥 خطأ فادح في Subscription Callback:', error);
    return NextResponse.redirect(new URL('/craftsman/dashboard?msg=callback_error', request.url));
  }
}
