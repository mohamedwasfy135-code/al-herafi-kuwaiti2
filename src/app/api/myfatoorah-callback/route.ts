import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getInvoiceStatus } from '@/lib/myfatoorah';

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const incomingId = searchParams.get('paymentId') || searchParams.get('Id') || searchParams.get('InvoiceId');

  if (!incomingId) {
    console.error('❌ [Callback] لم يصل أي معرف من ماي فاتورة');
    return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
  }

  try {
    let statusData;
    try {
      statusData = await getInvoiceStatus(incomingId, 'PaymentId');
    } catch {
      statusData = await getInvoiceStatus(incomingId, 'InvoiceId');
    }

    const isPaid = statusData?.InvoiceStatus === 'Paid';
    const invoiceIdFromMF = String(statusData?.InvoiceId || incomingId);
    const paymentIdFromMF = statusData?.InvoiceTransactions?.[0]?.PaymentId
      ? String(statusData.InvoiceTransactions[0].PaymentId)
      : incomingId;


    // ✅ فحص ما إذا كانت المعاملة تخص اشتراك حرفي
    const subscriptionPayment = await db.subscriptionPayment.findFirst({
      where: {
        OR: [
          { invoiceId: invoiceIdFromMF },
          { paymentId: paymentIdFromMF }
        ],
        status: 'pending'
      },
      include: { user: true }
    });

    if (subscriptionPayment) {
      console.log(' [MyFatoorah Callback] معاملة اشتراك حرفي:', subscriptionPayment.id);
      
      await db.subscriptionPayment.update({
        where: { id: subscriptionPayment.id },
        data: { 
          status: isPaid ? 'paid' : 'failed',
          invoiceId: invoiceIdFromMF,
          paymentId: paymentIdFromMF
        }
      });

      if (isPaid) {
        const baseDate = subscriptionPayment.user.subscriptionStatus === 'active' && subscriptionPayment.user.subscriptionExpiryDate 
          ? new Date(subscriptionPayment.user.subscriptionExpiryDate) 
          : new Date();
        
        const newExpiryDate = new Date(baseDate);
        newExpiryDate.setMonth(newExpiryDate.getMonth() + 1);

        await db.user.update({
          where: { id: subscriptionPayment.userId },
          data: {
            subscriptionStatus: 'active',
            subscriptionExpiryDate: newExpiryDate
          }
        });

        console.log(`✅ تم تجديد اشتراك الحرفي ${subscriptionPayment.userId} حتى ${newExpiryDate.toLocaleDateString('ar-KW')}`);
        return NextResponse.redirect(new URL('/craftsman/dashboard?msg=subscription_renewed', request.url));
      } else {
        return NextResponse.redirect(new URL('/craftsman/dashboard?msg=payment_failed', request.url));
      }
    }

    const transaction = await db.paymentTransaction.findFirst({
      where: {
        OR: [
          { invoiceId: String(incomingId) },      // بحث بـ ID القادم من الرابط مباشرة
          { paymentId: String(incomingId) },       // بحث بـ ID القادم من الرابط في حقل paymentId
          { invoiceId: invoiceIdFromMF },          // بحث بـ InvoiceId المستخرج من استجابة MF
          { paymentId: paymentIdFromMF }           // بحث بـ PaymentId المستخرج من استجابة MF
        ]
      },
      include: { request: true } // جلب الطلب المرتبط لتجنب Query إضافية لاحقاً
    });

    if (!transaction) {
      console.error('❌ [Callback] معاملة غير موجودة:', { 
        incomingId, 
        invoiceIdFromMF, 
        paymentIdFromMF,
        urlParams: Object.fromEntries(request.nextUrl.searchParams)
      });
      return NextResponse.redirect(new URL('/dashboard/client?msg=transaction_not_found', request.url));
    }

    // منع التكرار: إذا كانت مدفوعة مسبقاً
    if (transaction.status === 'paid') {
      console.log('ℹ️ [Callback] المعاملة مدفوعة مسبقاً');
      return NextResponse.redirect(new URL(`/dashboard/client?msg=${transaction.type === 'visit_fee' ? 'visit_fee_paid' : 'final_payment_paid'}`, request.url));
    }

    if (isPaid) {
      try {
        await db.$transaction(async (tx) => {
          // 1. تحديث المعاملة بالIDs الصحيحة
          await tx.paymentTransaction.update({
            where: { id: transaction.id },
            data: { 
              status: 'paid', 
              paidAt: new Date(),
              paymentId: paymentIdFromMF,
              invoiceId: invoiceIdFromMF
            }
          });

          // 2. تحديث حالة الطلب
          const updateData: any = {};
          if (transaction.type === 'visit_fee') {
            updateData.visitFeePaid = true;
            updateData.status = 'in_progress';
          } else if (transaction.type === 'final_payment') {
            updateData.status = 'paid';
            updateData.paidAt = new Date();
          }

          if (Object.keys(updateData).length > 0 && transaction.requestId) {
            await tx.request.update({
              where: { id: transaction.requestId },
              data: updateData
            });
          }

          // 3. إنشاء إشعار للعميل
          if (transaction.request?.clientId) {
            await tx.notification.create({
              data: {
                userId: transaction.request.clientId,
                title: '✅ تم تأكيد الدفع',
                body: transaction.type === 'visit_fee' 
                  ? 'تم دفع دفعة الزيارة بنجاح' 
                  : 'تم الدفع النهائي بنجاح',
                type: 'payment_confirmed',
              }
            });
          }
        });

        console.log(`🎉 [Callback] تم تحديث الطلب #${transaction.requestId} بنجاح`);
        const msg = transaction.type === 'visit_fee' ? 'visit_fee_paid' : 'final_payment_paid';
        return NextResponse.redirect(new URL(`/dashboard/client?msg=${msg}`, request.url));
        
      } catch (updateError: any) {
        console.error('💥 [Callback] فشل التحديث:', updateError.message);
        return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
      }
    }
    const msg = isPaid
      ? (transaction.type === 'visit_fee' ? 'visit_fee_paid' : 'final_payment_paid')
      : 'payment_pending';

    return NextResponse.redirect(new URL(`/dashboard/client?msg=${msg}`, request.url));

  } catch (error: any) {
    console.error('💥 [Callback] خطأ فادح:', error.message);
    return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
  }
}
