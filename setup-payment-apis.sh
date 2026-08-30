#!/bin/bash
set -e
echo "🚀 بدء إعداد APIs نظام الدفع وتحديث الواجهات..."

# 1️⃣ مكتبة MyFatoorah
echo "📝 إنشاء مكتبة MyFatoorah..."
mkdir -p src/lib
cat << 'EOF' > src/lib/myfatoorah.ts
const API_URL = process.env.MYFATOORAH_API_URL || 'https://apitest.myfatoorah.com';
const API_TOKEN = process.env.MYFATOORAH_TOKEN || '';
const CALLBACK_URL = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';

export const VISIT_FEE = 3; // دفعة الزيارة الثابتة

export interface InvoiceRequest {
  InvoiceValue: number;
  CustomerName?: string;
  CustomerMobile?: string;
  CustomerEmail?: string;
  CallBackUrl?: string;
  ErrorUrl?: string;
  InvoiceItems?: { ItemName: string; Quantity: number; UnitPrice: number }[];
}

export async function createInvoice(data: InvoiceRequest) {
  if (!API_TOKEN) {
    console.log('⚠️ MyFatoorah Token غير موجود - وضع الاختبار');
    return {
      InvoiceId: Math.floor(Math.random() * 1000000),
      PaymentURL: `${CALLBACK_URL}/api/payments/callback?paymentId=test&invoiceId=test`,
      InvoiceStatus: 'Created',
    };
  }

  const response = await fetch(`${API_URL}/v2/InitiateSession`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${API_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      InvoiceValue: data.InvoiceValue,
      CurrencyIso: 'KWD',
      CustomerName: data.CustomerName || 'عميل سناعي',
      CustomerMobile: data.CustomerMobile || '',
      CustomerEmail: data.CustomerEmail || '',
      NotificationOption: 'LNK',
      CallBackUrl: data.CallBackUrl || `${CALLBACK_URL}/api/payments/callback`,
      ErrorUrl: data.ErrorUrl || `${CALLBACK_URL}/payment/failed`,
      Language: 'ar',
      InvoiceItems: data.InvoiceItems || [{ ItemName: 'دفعة زيارة', Quantity: 1, UnitPrice: data.InvoiceValue }],
    }),
  });

  if (!response.ok) throw new Error(`MyFatoorah Error: ${await response.text()}`);
  const result = await response.json();
  return {
    InvoiceId: result.data?.InvoiceId || result.InvoiceId,
    PaymentURL: result.data?.PaymentURL || result.PaymentURL,
    InvoiceStatus: 'Created',
  };
}

export async function getInvoiceStatus(invoiceId: string | number) {
  if (!API_TOKEN || invoiceId === 'test') return { InvoiceStatus: 'Paid', InvoiceValue: 0, PaidValue: 0 };
  const response = await fetch(`${API_URL}/v2/GetInvoiceStatus?invoiceId=${invoiceId}`, {
    headers: { 'Authorization': `Bearer ${API_TOKEN}` },
  });
  if (!response.ok) throw new Error('MyFatoorah Status Error');
  const result = await response.json();
  return result.data || result;
}
EOF

# 2️⃣ API دفعة الزيارة
echo "📝 إنشاء API دفعة الزيارة..."
mkdir -p src/app/api/payments/visit-fee
cat << 'EOF' > src/app/api/payments/visit-fee/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';
import { createInvoice, VISIT_FEE } from '@/lib/myfatoorah';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'client') return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });

    const { requestId } = await request.json();
    if (!requestId) return NextResponse.json({ error: 'رقم الطلب مطلوب' }, { status: 400 });

    const req = await db.request.findUnique({ where: { id: requestId }, include: { client: true, category: true } });
    if (!req || req.clientId !== session.userId) return NextResponse.json({ error: 'الطلب غير موجود أو ليس لك' }, { status: 404 });
    if (req.visitFeePaid) return NextResponse.json({ error: 'تم دفع دفعة الزيارة مسبقاً' }, { status: 400 });
    if (req.status !== 'accepted') return NextResponse.json({ error: 'يمكن الدفع فقط بعد قبول الحرفي' }, { status: 400 });

    const invoice = await createInvoice({
      InvoiceValue: VISIT_FEE,
      CustomerName: req.client?.name,
      CustomerMobile: req.client?.phone,
      CustomerEmail: req.client?.email,
      CallBackUrl: \`\${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/api/payments/callback\`,
      ErrorUrl: \`\${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/payment/failed\`,
      InvoiceItems: [{ ItemName: \`دفعة زيارة - \${req.category?.name || 'خدمة'}\`, Quantity: 1, UnitPrice: VISIT_FEE }],
    });

    await db.request.update({ where: { id: requestId }, data: { paymentUrl: invoice.PaymentURL, paymentId: invoice.InvoiceId.toString(), paymentStatus: 'pending', visitFee: VISIT_FEE } });
    await db.paymentTransaction.create({ data: { requestId, amount: VISIT_FEE, type: 'visit_fee', status: 'pending', paymentId: invoice.InvoiceId.toString(), paymentUrl: invoice.PaymentURL } });

    return NextResponse.json({ success: true, paymentUrl: invoice.PaymentURL, amount: VISIT_FEE });
  } catch (error: any) {
    return NextResponse.json({ error: error.message || 'حدث خطأ' }, { status: 500 });
  }
}
EOF

# 3️⃣ API Webhook للدفع
echo "📝 إنشاء API Webhook للدفع..."
mkdir -p src/app/api/payments/callback
cat << 'EOF' > src/app/api/payments/callback/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getInvoiceStatus } from '@/lib/myfatoorah';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const paymentId = searchParams.get('paymentId') || searchParams.get('invoiceId');
    if (!paymentId) return NextResponse.redirect(new URL('/payment/failed', request.url));

    const status = await getInvoiceStatus(paymentId);
    const transaction = await db.paymentTransaction.findFirst({ where: { paymentId }, include: { request: { include: { client: true, craftsman: true } } } });
    if (!transaction) return NextResponse.redirect(new URL('/payment/failed', request.url));

    const req = transaction.request;
    if (status.InvoiceStatus === 'Paid' || transaction.type === 'visit_fee') {
      await db.paymentTransaction.update({ where: { id: transaction.id }, data: { status: 'paid', paidAt: new Date() } });
      
      const updateData: any = { paymentStatus: 'paid' };
      if (transaction.type === 'visit_fee') {
        updateData.visitFeePaid = true;
        updateData.status = 'pending_approval';
      }
      await db.request.update({ where: { id: req.id }, data: updateData });

      if (req.craftsmanId) {
        await db.notification.create({ data: { userId: req.craftsmanId, title: transaction.type === 'visit_fee' ? '💰 تم دفع دفعة الزيارة' : '💰 تم الدفع النهائي', body: transaction.type === 'visit_fee' ? \`دفع العميل دفعة الزيارة لطلبك #\${req.id}\` : \`تم الدفع النهائي لطلبك #\${req.id}\`, type: 'payment_received' } });
      }
      await db.notification.create({ data: { userId: req.clientId, title: '✅ تم تأكيد الدفع', body: 'تم تأكيد الدفع بنجاح.', type: 'payment_confirmed' } });

      return NextResponse.redirect(new URL(transaction.type === 'visit_fee' ? '/dashboard/client?msg=visit_fee_paid' : '/dashboard/client?msg=final_payment_paid', request.url));
    }
    return NextResponse.redirect(new URL('/payment/failed', request.url));
  } catch (error) {
    return NextResponse.redirect(new URL('/payment/failed', request.url));
  }
}
EOF

# 4️⃣ API اقتراح السعر
echo "📝 إنشاء API اقتراح السعر..."
mkdir -p src/app/api/craftsman/propose-price
cat << 'EOF' > src/app/api/craftsman/propose-price/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';
import { VISIT_FEE } from '@/lib/myfatoorah';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });

    const { requestId, proposedPrice } = await request.json();
    if (!requestId || !proposedPrice) return NextResponse.json({ error: 'البيانات مطلوبة' }, { status: 400 });
    if (parseFloat(proposedPrice) < VISIT_FEE) return NextResponse.json({ error: \`السعر يجب أن يكون >= \${VISIT_FEE}\` }, { status: 400 });

    const req = await db.request.findUnique({ where: { id: requestId }, include: { client: true } });
    if (!req || req.craftsmanId !== session.userId || !req.visitFeePaid) return NextResponse.json({ error: 'غير مصرح أو لم تدفع دفعة الزيارة' }, { status: 403 });

    const remainingAmount = parseFloat(proposedPrice) - VISIT_FEE;
    await db.request.update({ where: { id: requestId }, data: { proposedPrice: parseFloat(proposedPrice), remainingAmount, status: 'pending_approval' } });
    
    await db.notification.create({ data: { userId: req.clientId, title: '💰 اقتراح سعر جديد', body: \`اقترح الحرفي سعر \${proposedPrice} د.ك. المتبقي بعد خصم دفعة الزيارة: \${remainingAmount.toFixed(3)} د.ك\`, type: 'price_proposed' } });

    return NextResponse.json({ success: true, proposedPrice, remainingAmount });
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
EOF

# 5️⃣ API موافقة العميل على السعر
echo "📝 إنشاء API موافقة العميل..."
mkdir -p src/app/api/payments/approve-price
cat << 'EOF' > src/app/api/payments/approve-price/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'client') return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });

    const { requestId, action } = await request.json();
    const req = await db.request.findUnique({ where: { id: requestId }, include: { craftsman: true } });
    if (!req || req.clientId !== session.userId || req.status !== 'pending_approval') return NextResponse.json({ error: 'خطأ في البيانات' }, { status: 400 });

    if (action === 'approve') {
      await db.request.update({ where: { id: requestId }, data: { agreedPrice: req.proposedPrice, status: 'in_progress' } });
      if (req.craftsmanId) await db.notification.create({ data: { userId: req.craftsmanId, title: '✅ العميل وافق على السعر', body: 'وافق العميل على السعر المقترح. يمكنك بدء العمل.', type: 'price_approved' } });
      return NextResponse.json({ success: true, message: 'تمت الموافقة. الحرفي سيبدأ العمل.' });
    } else {
      await db.request.update({ where: { id: requestId }, data: { status: 'accepted', proposedPrice: null, remainingAmount: null } });
      if (req.craftsmanId) await db.notification.create({ data: { userId: req.craftsmanId, title: '❌ العميل رفض السعر', body: 'يرجى اقتراح سعر جديد.', type: 'price_rejected' } });
      return NextResponse.json({ success: true, message: 'تم الرفض. سيتم إشعار الحرفي.' });
    }
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
EOF

echo "✅ تم إنشاء جميع ملفات API بنجاح!"
echo "📝 ملاحظة: لتحديث الواجهات (Client & Craftsman Dashboard)، يرجى إخباري وسأزودك بالأكواد المحدثة."
