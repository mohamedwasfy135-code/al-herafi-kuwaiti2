import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getInvoiceStatus } from '@/lib/myfatoorah';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const requestId = searchParams.get('requestId');
    const paymentId = searchParams.get('paymentId');

    if (!requestId || !paymentId) {
      return NextResponse.json({ error: 'بيانات ناقصة' }, { status: 400 });
    }

    console.log('🔍 [Check Status] فحص حالة الدفع:', { requestId, paymentId });

    // التحقق من حالة الفاتورة من ماي فاتورة
    const invoiceStatus = await getInvoiceStatus(paymentId);
    console.log('📊 حالة الفاتورة من ماي فاتورة:', invoiceStatus);

    if (invoiceStatus.InvoiceStatus === 'Paid') {
      // تحديث حالة الطلب
      const req = await db.request.findUnique({
        where: { id: parseInt(requestId) },
        include: { client: true }
      });

      if (!req) {
        return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 });
      }

      // البحث عن معاملة الدفع
      const transaction = await db.paymentTransaction.findFirst({
        where: { paymentId, requestId: parseInt(requestId) }
      });

      if (transaction && transaction.status !== 'paid') {
        // تحديث معاملة الدفع
        await db.paymentTransaction.update({
          where: { id: transaction.id },
          data: { status: 'paid', paidAt: new Date() }
        });

        // تحديث حالة الطلب
        const updateData: any = { paymentStatus: 'paid' };
        
        if (transaction.type === 'visit_fee') {
          updateData.visitFeePaid = true;
          updateData.status = 'in_progress';
        } else if (transaction.type === 'final_payment') {
          updateData.status = 'paid';
        }

        await db.request.update({
          where: { id: parseInt(requestId) },
          data: updateData
        });

        console.log('✅ تم تحديث حالة الطلب إلى:', updateData.status);

        // إنشاء إشعار
        if (req.clientId) {
          await db.notification.create({
            data: {
              userId: req.clientId,
              title: '✅ تم تأكيد الدفع',
              body: transaction.type === 'visit_fee' 
                ? 'تم دفع دفعة الزيارة بنجاح' 
                : 'تم الدفع النهائي بنجاح',
              type: 'payment_confirmed'
            }
          });
        }
      }

      return NextResponse.json({ 
        success: true, 
        status: 'paid',
        message: 'تم تأكيد الدفع بنجاح'
      });
    } else {
      return NextResponse.json({ 
        success: false, 
        status: invoiceStatus.InvoiceStatus,
        message: 'الدفع لم يكتمل بعد'
      });
    }
  } catch (error: any) {
    console.error('❌ خطأ في فحص حالة الدفع:', error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
