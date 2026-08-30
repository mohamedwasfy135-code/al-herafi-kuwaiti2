import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const paymentId = searchParams.get('paymentId') || searchParams.get('id');
    const status = searchParams.get('status');

    if (!paymentId) {
      return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
    }

    // البحث عن المعاملة وتحديث الحالة
    const transaction = await db.paymentTransaction.findFirst({
      where: { paymentId },
      include: { request: true }
    });

    if (!transaction) {
      return NextResponse.redirect(new URL('/dashboard/client?msg=transaction_not_found', request.url));
    }

    // تحديث حالة الطلب والمعاملة فقط إذا كانت ناجحة
    if (status === 'success' && transaction.status !== 'paid') {
      const updateData: any = { paymentStatus: 'paid' };
      
      if (transaction.type === 'visit_fee') {
        updateData.visitFeePaid = true;
        updateData.status = 'in_progress';
      } else if (transaction.type === 'final_payment') {
        updateData.status = 'paid';
      }

      await db.request.update({
        where: { id: transaction.request.id },
        data: updateData
      });

      await db.paymentTransaction.update({
        where: { id: transaction.id },
        data: { status: 'paid', updatedAt: new Date() }
      });
    }

    // التوجيه لصفحة العميل مع رسالة مناسبة
    const msg = status === 'success' 
      ? (transaction.type === 'visit_fee' ? 'visit_fee_paid' : 'final_payment_paid')
      : 'payment_failed';
      
    return NextResponse.redirect(new URL(`/dashboard/client?msg=${msg}`, request.url));

  } catch (error) {
    console.error('Callback Error:', error);
    return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
  }
}
