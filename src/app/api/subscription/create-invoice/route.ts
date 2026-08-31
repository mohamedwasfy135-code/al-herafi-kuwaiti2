import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';
import { createInvoice } from '@/lib/myfatoorah';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    // ✅ قراءة قيمة الاشتراك من الإعدادات فقط (لمنع التلاعب من الواجهة)
    const setting = await db.appSettings.findUnique({ where: { key: 'subscription_fee' } });
    const subscriptionFee = setting ? parseFloat(setting.value) : 5.0;

    const user = await db.user.findUnique({ 
      where: { id: session.userId },
      select: { name: true, phone: true, email: true }
    });

    if (!user) {
      return NextResponse.json({ error: 'المستخدم غير موجود' }, { status: 404 });
    }

    const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://al-herafi-kuwaiti2.vercel.app';

    // إنشاء الفاتورة عبر ماي فاتورة
    const invoice = await createInvoice({
      InvoiceValue: subscriptionFee,
      CustomerName: user.name || 'حرفي',
      CustomerMobile: user.phone || '00000000',
      CustomerEmail: user.email || 'test@test.com',
      CallBackUrl: `${appUrl}/api/subscription/callback`,
      ErrorUrl: `${appUrl}/craftsman/dashboard?msg=payment_failed`,
      InvoiceItems: [
        {
          ItemName: 'اشتراك شهري - منصة الحرفي',
          Quantity: 1,
          UnitPrice: subscriptionFee,
        }
      ],
    });

    // ✅ حفظ سجل الدفع بحالة pending
    const startDate = new Date();
    const endDate = new Date();
    endDate.setMonth(endDate.getMonth() + 1);

    await db.subscriptionPayment.create({
      data: {
        userId: session.userId,
        amount: subscriptionFee,
        status: 'pending',
        paymentId: invoice.PaymentId || 'pending',
        invoiceId: String(invoice.InvoiceId),
        startDate,
        endDate,
      }
    });

    return NextResponse.json({
      success: true,
      paymentUrl: invoice.PaymentURL,
      invoiceId: invoice.InvoiceId,
      amount: subscriptionFee
    }, { status: 200 });

  } catch (error: any) {
    console.error('❌ خطأ في إنشاء فاتورة الاشتراك:', error);
    return NextResponse.json({ error: 'فشل إنشاء فاتورة الدفع' }, { status: 500 });
  }
}
