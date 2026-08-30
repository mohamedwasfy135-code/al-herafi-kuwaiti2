import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    
    // ماي فاتورة ترجع InvoiceId و PaymentId، نستخدم كلاهما للبحث
    const invoiceId = searchParams.get('paymentId') || searchParams.get('id');
    const paymentIdParam = searchParams.get('paymentId');
    const status = searchParams.get('status');

    console.log('📥 [Callback] استلام إشعار:', { invoiceId, paymentIdParam, status });

    if (!invoiceId) {
      console.error('❌ معرف الفاتورة مفقود من الرابط');
      return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
    }

    // ✅ البحث باستخدام invoiceId أولاً (لأنه الأكثر دقة وثباتاً)
    let transaction = await db.paymentTransaction.findFirst({
      where: { 
        OR: [
          { paymentId: invoiceId },
          { invoiceId: invoiceId } // حقل مخصص لربط الفاتورة بالمعاملة
        ]
      },
      include: { request: true }
    });

    // إذا لم نجد، نحاول البحث بأي PaymentId آخر مرسل
    if (!transaction && paymentIdParam && paymentIdParam !== invoiceId) {
      transaction = await db.paymentTransaction.findFirst({
        where: { paymentId: paymentIdParam },
        include: { request: true }
      });
    }

    if (!transaction) {
      console.error(` لم يتم العثور على معاملة للفاتورة: ${invoiceId}`);
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

      // تحديث حالة الطلب والمعاملة في عملية واحدة آمنة
      await db.$transaction([
        db.request.update({
          where: { id: transaction.request.id },
          data: updateData
        }),
        db.paymentTransaction.update({
          where: { id: transaction.id },
          data: { status: 'paid', updatedAt: new Date() }
        })
      ]);

      console.log('✅ تم تحديث الحالة بنجاح:', updateData);
    }

    const msg = status === 'success' 
      ? (transaction.type === 'visit_fee' ? 'visit_fee_paid' : 'final_payment_paid')
      : 'payment_failed';
      
    return NextResponse.redirect(new URL(`/dashboard/client?msg=${msg}`, request.url));

  } catch (error: any) {
    console.error('💥 خطأ فادح في Callback:', error);
    return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
  }
}
