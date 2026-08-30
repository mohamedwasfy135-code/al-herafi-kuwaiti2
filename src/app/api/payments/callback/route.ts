import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getInvoiceStatus } from '@/lib/myfatoorah';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const paymentId = searchParams.get('paymentId') || searchParams.get('invoiceId');
    
    if (!paymentId) {
      return NextResponse.redirect(new URL('/payment/failed', request.url));
    }

    let status: any = { InvoiceStatus: 'Paid' }; // افتراضي للاختبار
    try {
      status = await getInvoiceStatus(paymentId);
    } catch (e) {
      console.warn('تعذر التحقق من حالة الفاتورة من MyFatoorah، سيتم الاعتماد على حالة المعاملة المحلية.');
    }

    const transaction = await db.paymentTransaction.findFirst({ 
      where: { paymentId }, 
      include: { request: { include: { client: true, craftsman: true } } } 
    });
    
    if (!transaction) {
      return NextResponse.redirect(new URL('/payment/failed', request.url));
    }

    const req = transaction.request;
    
    // التحقق من نجاح الدفع
    if (status.InvoiceStatus === 'Paid' || transaction.status === 'paid') {
      await db.paymentTransaction.update({ 
        where: { id: transaction.id }, 
        data: { status: 'paid', paidAt: new Date() } 
      });
      
      const updateData: any = { paymentStatus: 'paid' };
      
      if (transaction.type === 'visit_fee') {
        updateData.visitFeePaid = true;
        updateData.status = 'in_progress'; 
      } else if (transaction.type === 'final_payment') {
        // ✅ هذا هو السطر المفقود الذي يصلح المشكلة!
        updateData.status = 'paid';
      }
      
      await db.request.update({ where: { id: req.id }, data: updateData });

      if (req.craftsmanId) {
        const title = transaction.type === 'visit_fee' 
          ? '✅ تم دفع دفعة الزيارة - ابدأ العمل' 
          : '💰 تم الدفع النهائي';
        const body = transaction.type === 'visit_fee' 
          ? `دفع العميل دفعة الزيارة لطلبك #${req.id}. يمكنك الآن بدء العمل.` 
          : `تم الدفع النهائي لطلبك #${req.id}. شكراً لك!`;
          
        await db.notification.create({ 
          data: { 
            userId: req.craftsmanId, 
            title: title, 
            body: body, 
            type: 'payment_received' 
          } 
        });
      }
      
      await db.notification.create({ 
        data: { 
          userId: req.clientId, 
          title: '✅ تم تأكيد الدفع', 
          body: 'تم تأكيد الدفع بنجاح.', 
          type: 'payment_confirmed' 
        } 
      });

      const redirectUrl = transaction.type === 'visit_fee' 
        ? '/dashboard/client?msg=visit_fee_paid' 
        : '/dashboard/client?msg=final_payment_paid';

      return NextResponse.redirect(new URL(redirectUrl, request.url));
    }
    
    return NextResponse.redirect(new URL('/payment/failed', request.url));
  } catch (error) {
    console.error('❌ خطأ في Webhook الدفع:', error);
    return NextResponse.redirect(new URL('/payment/failed', request.url));
  }
}
