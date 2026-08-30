import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    
    // ماي فاتورة ترسل عادة paymentId (وهو رقم الفاتورة InvoiceId) و status
    const mfPaymentId = searchParams.get('paymentId');
    const status = searchParams.get('status');

    console.log('📥 [Callback] استلام إشعار من ماي فاتورة:', { mfPaymentId, status });

    if (!mfPaymentId) {
      console.error('❌ معرف الفاتورة (paymentId) مفقود من الرابط');
      return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
    }

    // البحث عن المعاملة باستخدام الحقلين المحتملين (كـ String لضمان التطابق)
    const transaction = await db.paymentTransaction.findFirst({
      where: {
        OR: [
          { invoiceId: String(mfPaymentId) },
          { paymentId: String(mfPaymentId) }
        ]
      },
      include: { request: true }
    });

    if (!transaction) {
      console.error(`❌ لم يتم العثور على معاملة تطابق المعرف: ${mfPaymentId}`);
      return NextResponse.redirect(new URL('/dashboard/client?msg=transaction_not_found', request.url));
    }

    console.log('✅ تم العثور على المعاملة:', { 
      id: transaction.id, 
      type: transaction.type, 
      currentStatus: transaction.status,
      requestId: transaction.requestId
    });

    // تحديث الحالة فقط إذا كانت ناجحة ولم تكن مدفوعة مسبقاً
    if (status?.toLowerCase() === 'success' && transaction.status !== 'paid') {
      const updateData: any = { paymentStatus: 'paid' };
      
      if (transaction.type === 'visit_fee') {
        updateData.visitFeePaid = true;
        updateData.status = 'in_progress';
      } else if (transaction.type === 'final_payment') {
        updateData.status = 'paid';
      }

      await db.$transaction([
        db.request.update({
          where: { id: transaction.requestId },
          data: updateData
        }),
        db.paymentTransaction.update({
          where: { id: transaction.id },
          data: { 
            status: 'paid', 
            paidAt: new Date(), // تحديث الحقل الجديد
            updatedAt: new Date() 
          }
        })
      ]);

      console.log('✅ تم تحديث حالة الطلب والمعاملة بنجاح:', updateData);
    }

    const msg = status?.toLowerCase() === 'success' 
      ? (transaction.type === 'visit_fee' ? 'visit_fee_paid' : 'final_payment_paid')
      : 'payment_failed';
      
    return NextResponse.redirect(new URL(`/dashboard/client?msg=${msg}`, request.url));

  } catch (error: any) {
    console.error('💥 خطأ فادح في Callback:', error);
    return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
  }
}
