import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getInvoiceStatus } from '@/lib/myfatoorah';

// دالة موحدة للتعامل مع GET و POST لضمان عدم فشل الاستدعاء
async function handleCallback(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const incomingId = searchParams.get('paymentId') || searchParams.get('InvoiceId') || searchParams.get('id');

    if (!incomingId) {
      console.error('❌ [Subscription Callback] لم يصل أي معرف من ماي فاتورة');
      return NextResponse.redirect(new URL('/craftsman/dashboard?msg=callback_error', request.url));
    }

    console.log('📥 [Subscription Callback] استلام إشعار:', { incomingId });

    const payment = await db.subscriptionPayment.findFirst({
      where: {
        OR: [
          { invoiceId: String(incomingId) },
          { paymentId: String(incomingId) }
        ],
        status: 'pending'
      },
      include: { user: true }
    });

    if (!payment) {
      console.error(`❌ لم يتم العثور على دفعة معلقة للمعرف: ${incomingId}`);
      return NextResponse.redirect(new URL('/craftsman/dashboard?msg=transaction_not_found', request.url));
    }

    let statusData;
    try {
      statusData = await getInvoiceStatus(incomingId, 'PaymentId');
    } catch {
      try {
        statusData = await getInvoiceStatus(incomingId, 'InvoiceId');
      } catch (e) {
        console.error('فشل التحقق من حالة الفاتورة:', e);
      }
    }

    const isPaid = statusData?.InvoiceStatus === 'Paid';
    const verifiedInvoiceId = String(statusData?.InvoiceId || incomingId);
    const verifiedPaymentId = statusData?.InvoiceTransactions?.[0]?.PaymentId 
      ? String(statusData.InvoiceTransactions[0].PaymentId) 
      : incomingId;

    if (isPaid) {
      await db.subscriptionPayment.update({
        where: { id: payment.id },
        data: { 
          status: 'paid',
          invoiceId: verifiedInvoiceId,
          paymentId: verifiedPaymentId
        }
      });

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

      console.log(`✅ تم تجديد اشتراك الحرفي ${payment.userId} بنجاح حتى ${newExpiryDate.toLocaleDateString('ar-KW')}`);
      return NextResponse.redirect(new URL('/craftsman/dashboard?msg=subscription_renewed', request.url));
      
    } else {
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

export async function GET(request: NextRequest) {
  return handleCallback(request);
}

export async function POST(request: NextRequest) {
  return handleCallback(request);
}
