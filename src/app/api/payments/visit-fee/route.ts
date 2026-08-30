import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';
import { createInvoice, VISIT_FEE } from '@/lib/myfatoorah';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'client') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const body = await request.json();
    const { requestId } = body;
    
    if (!requestId) {
      return NextResponse.json({ error: 'رقم الطلب مطلوب' }, { status: 400 });
    }

    const req = await db.request.findUnique({ 
      where: { id: requestId }, 
      include: { client: true, category: true } 
    });
    
    if (!req || req.clientId !== session.userId) {
      return NextResponse.json({ error: 'الطلب غير موجود أو ليس لك' }, { status: 404 });
    }
    
    if (req.visitFeePaid) {
      return NextResponse.json({ error: 'تم دفع دفعة الزيارة مسبقاً' }, { status: 400 });
    }
    
    if (req.status !== 'pending_payment' && req.status !== 'accepted') {
      return NextResponse.json({ error: 'لا يمكن الدفع في هذه المرحلة' }, { status: 400 });
    }

    const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';

    const invoice = await createInvoice({
      InvoiceValue: VISIT_FEE,
      CustomerName: req.client?.name || 'عميل',
      CustomerMobile: req.client?.phone || '',
      CustomerEmail: req.client?.email || '',
      CallBackUrl: `${appUrl}/api/payments/callback`,
      ErrorUrl: `${appUrl}/payment/failed`,
      InvoiceItems: [{ 
        ItemName: `دفعة زيارة - ${req.category?.name || 'خدمة'}`, 
        Quantity: 1, 
        UnitPrice: VISIT_FEE 
      }],
    });

    await db.request.update({ 
      where: { id: requestId }, 
      data: { 
        paymentUrl: invoice.PaymentURL, 
        paymentId: invoice.InvoiceId.toString(), 
        paymentStatus: 'pending', 
        visitFee: VISIT_FEE 
      } 
    });
    
    await db.paymentTransaction.create({ 
      data: { 
        requestId, 
        amount: VISIT_FEE, 
        type: 'visit_fee', 
        status: 'pending', 
        paymentId: invoice.InvoiceId.toString(), 
        paymentUrl: invoice.PaymentURL 
      } 
    });

    return NextResponse.json({ 
      success: true, 
      paymentUrl: invoice.PaymentURL, 
      amount: VISIT_FEE 
    }, { status: 200 });
  } catch (error: any) {
    console.error('❌ خطأ في API دفعة الزيارة:', error);
    return NextResponse.json({ 
      error: error.message || 'حدث خطأ في الخادم',
      details: error.code || ''
    }, { status: 500 });
  }
}
