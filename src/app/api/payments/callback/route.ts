import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getInvoiceStatus } from '@/lib/myfatoorah';

export async function GET(request: NextRequest) {
  try {
    console.log('📥 [Callback] استلام إشعار دفع من Vercel');
    
    const searchParams = request.nextUrl.searchParams;
    const paymentId = searchParams.get('paymentId') || searchParams.get('id');
    const status = searchParams.get('status') || 'success';
    
    console.log(' PaymentId:', paymentId);
    console.log('📊 Status:', status);
    
    if (!paymentId) {
      console.error('❌ PaymentId غير موجود');
      return NextResponse.redirect(new URL('/payment/failed', request.url));
    }

    // البحث عن معاملة الدفع
    const transaction = await db.paymentTransaction.findFirst({
      where: { paymentId },
      include: { request: true }
    });

    if (!transaction) {
      console.error('❌ معاملة الدفع غير موجودة:', paymentId);
      return NextResponse.redirect(new URL('/payment/failed', request.url));
    }

    const req = transaction.request;
    
    // تحديث حالة المعاملة
    await db.paymentTransaction.update({
      where: { id: transaction.id },
      data: { 
        status: status === 'success' ? 'success' : 'failed',
        updatedAt: new Date()
      }
    });

    if (status === 'success') {
      console.log('✅ [Callback] الدفع ناجح:', paymentId);
      
      let updateData: any = { paymentStatus: 'paid' };
      
      if (transaction.type === 'visit_fee') {
        updateData.visitFeePaid = true;
        updateData.status = 'in_progress';
      } else if (transaction.type === 'final_payment') {
        updateData.status = 'paid';
      }
      
      await db.request.update({
        where: { id: req.id },
        data: updateData
      });
      
      console.log('✅ تم تحديث حالة الطلب إلى:', updateData.status);
      
      // توجيه العميل لصفحة النجاح
      const redirectUrl = transaction.type === 'visit_fee' 
        ? '/dashboard/client?msg=visit_fee_paid' 
        : '/dashboard/client?msg=final_payment_paid';

      return NextResponse.redirect(new URL(redirectUrl, request.url));
    } else {
      console.error('❌ [Callback] الدفع فشل:', paymentId);
      return NextResponse.redirect(new URL('/payment/failed', request.url));
    }
    
  } catch (error: any) {
    console.error('❌ خطأ في Callback:', error);
    return NextResponse.redirect(new URL('/payment/failed', request.url));
  }
}
