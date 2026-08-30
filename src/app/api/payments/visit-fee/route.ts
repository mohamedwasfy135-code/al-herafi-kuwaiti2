import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { createInvoice } from '@/lib/myfatoorah';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { requestId } = body;

    if (!requestId) {
      return NextResponse.json({ error: 'رقم الطلب مطلوب' }, { status: 400 });
    }

    // جلب بيانات الطلب والعميل
    const req = await db.request.findUnique({
      where: { id: parseInt(requestId) },
      include: { client: true }
    });

    if (!req || !req.client) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 });
    }

    // إنشاء الفاتورة في ماي فاتورة
    const invoice = await createInvoice({
      InvoiceValue: 3,
      CustomerName: req.client.name || 'عميل',
      CustomerMobile: req.client.phone || '00000000',
      CustomerEmail: req.client.email || 'test@test.com',
      CallBackUrl: `${process.env.NEXT_PUBLIC_APP_URL || 'https://ah-herafy2.vercel.app'}/api/myfatoorah-callback`,
      ErrorUrl: `${process.env.NEXT_PUBLIC_APP_URL || 'https://ah-herafy2.vercel.app'}/dashboard/client?msg=payment_failed`,
      DisplayCurrencyIso: 'KWD',
      InvoiceItems: [{ ItemName: 'دفعة زيارة', Quantity: 1, UnitPrice: 3 }]
    });

    // ✅ حفظ معاملة الدفع باستخدام الحقول المتاحة فقط في Prisma Schema
    await db.paymentTransaction.create({
      data: {
        paymentId: invoice.PaymentId || 'pending',
        invoiceId: String(invoice.InvoiceId),
        requestId: req.id,
        type: 'visit_fee',
        amount: 3,
        status: 'pending',
        paymentUrl: invoice.PaymentURL // حفظ الرابط هنا بدلاً من metadata
      }
    });

    console.log('✅ تم حفظ معاملة الدفع:', invoice.InvoiceId);

    return NextResponse.json({
      success: true,
      invoiceId: invoice.InvoiceId,
      paymentUrl: invoice.PaymentURL
    });

  } catch (error: any) {
    console.error('❌ خطأ في إنشاء دفعة الزيارة:', error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
