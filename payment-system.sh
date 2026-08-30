#!/bin/bash
# ============================================================
# نظام الدفع المتكامل - منصة سناعي
# يشمل: دفعة الزيارة + اقتراح السعر + MyFatoorah
# ============================================================

set -e

echo " بدء تنفيذ نظام الدفع المتكامل..."
echo "=========================================="

# ═══════════════════════════════════════════════════════════════
# 1️⃣ تحديث Prisma Schema - إضافة الحقول الجديدة
# ═══════════════════════════════════════════════════════════════
echo "📝 تحديث Prisma Schema..."

# قراءة الـ schema الحالي
CURRENT_SCHEMA=$(cat prisma/schema.prisma)

# التحقق من وجود الحقول الجديدة
if echo "$CURRENT_SCHEMA" | grep -q "visitFee"; then
  echo "⚠️  الحقول موجودة مسبقاً - تخطي التحديث"
else
  # إضافة الحقول الجديدة لـ Request model
  sed -i.bak '/status.*String.*@default("pending")/a\
  visitFee          Float?    @default(3)  // دفعة الزيارة الثابتة\
  visitFeePaid      Boolean   @default(false)  // هل تم دفع دفعة الزيارة؟\
  proposedPrice     Float?    // السعر المقترح من الحرفي\
  agreedPrice       Float?    // السعر المتفق عليه\
  remainingAmount   Float?    // المبلغ المتبقي بعد دفعة الزيارة\
  paymentUrl        String?   // رابط دفع MyFatoorah\
  paymentId         String?   // معرف عملية الدفع في MyFatoorah\
  paymentStatus     String    @default("unpaid")  // unpaid, pending, paid, failed' prisma/schema.prisma
  
  echo "✅ تم إضافة الحقول الجديدة"
fi

# إضافة model جديد لـ PaymentTransaction
if ! echo "$CURRENT_SCHEMA" | grep -q "model PaymentTransaction"; then
  cat << 'SCHEMA_EOF' >> prisma/schema.prisma

model PaymentTransaction {
  id              Int       @id @default(autoincrement())
  requestId       Int
  amount          Float
  type            String    // visit_fee, final_payment
  status          String    // pending, paid, failed, refunded
  paymentId       String?   // MyFatoorah payment ID
  invoiceId       String?   // MyFatoorah invoice ID
  paymentUrl      String?
  paidAt          DateTime?
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt

  request         Request   @relation(fields: [requestId], references: [id])

  @@index([requestId])
  @@index([paymentId])
}
SCHEMA_EOF
  echo "✅ تم إضافة model PaymentTransaction"
fi

# مزامنة قاعدة البيانات
npx prisma db push
npx prisma generate

echo "✅ تم تحديث قاعدة البيانات"

# ══════════════════════════════════════════════════════════════
# 2️ إنشاء ملف إعدادات MyFatoorah
# ═══════════════════════════════════════════════════════════════
echo "📝 إنشاء إعدادات MyFatoorah..."

cat << 'EOF' > src/lib/myfatoorah.ts
/**
 * إعدادات MyFatoorah
 * يجب إضافة هذه المتغيرات في ملف .env
 */

const API_URL = process.env.MYFATOORAH_API_URL || 'https://apitest.myfatoorah.com';
const API_TOKEN = process.env.MYFATOORAH_TOKEN || '';
const CALLBACK_URL = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';

export const VISIT_FEE = 3; // دفعة الزيارة الثابتة بالدينار الكويتي

export interface InvoiceRequest {
  CustomerIdentifier?: string;
  CustomerName?: string;
  DisplayCurrencyIso?: string;
  DisplayCurrencyValue?: number;
  InvoiceValue: number;
  Language?: 'ar' | 'en';
  NotificationOption?: 'LNK' | 'SMS' | 'EMAIL' | 'ALL';
  CustomerEmail?: string;
  CustomerMobile?: string;
  CallBackUrl?: string;
  ErrorUrl?: string;
  InvoiceItems?: InvoiceItem[];
}

export interface InvoiceItem {
  ItemName: string;
  Quantity: number;
  UnitPrice: number;
}

export interface PaymentResult {
  InvoiceId: number;
  PaymentURL: string;
  InvoiceStatus: string;
}

/**
 * إنشاء فاتورة جديدة في MyFatoorah
 */
export async function createInvoice(data: InvoiceRequest): Promise<PaymentResult> {
  if (!API_TOKEN) {
    // وضع الاختبار - إنشاء فاتورة وهمية
    console.log('⚠️  MyFatoorah Token غير موجود - وضع الاختبار');
    return {
      InvoiceId: Math.floor(Math.random() * 1000000),
      PaymentURL: `${CALLBACK_URL}/api/payments/test-success?amount=${data.InvoiceValue}`,
      InvoiceStatus: 'Created',
    };
  }

  const response = await fetch(`${API_URL}/v2/InitiateSession`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${API_TOKEN}`,
      'Content-Type': 'application/json',
    },
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
      InvoiceItems: data.InvoiceItems || [
        {
          ItemName: 'دفعة زيارة - منصة سناعي',
          Quantity: 1,
          UnitPrice: data.InvoiceValue,
        }
      ],
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`MyFatoorah Error: ${error}`);
  }

  const result = await response.json();
  return {
    InvoiceId: result.data?.InvoiceId || result.InvoiceId,
    PaymentURL: result.data?.PaymentURL || result.PaymentURL,
    InvoiceStatus: 'Created',
  };
}

/**
 * التحقق من حالة الفاتورة
 */
export async function getInvoiceStatus(invoiceId: number): Promise<{
  InvoiceId: number;
  InvoiceStatus: string;
  InvoiceValue: number;
  PaidValue: number;
}> {
  if (!API_TOKEN) {
    return {
      InvoiceId: invoiceId,
      InvoiceStatus: 'Paid',
      InvoiceValue: 0,
      PaidValue: 0,
    };
  }

  const response = await fetch(`${API_URL}/v2/GetInvoiceStatus?invoiceId=${invoiceId}`, {
    headers: {
      'Authorization': `Bearer ${API_TOKEN}`,
    },
  });

  if (!response.ok) {
    throw new Error(`MyFatoorah Status Error: ${response.statusText}`);
  }

  const result = await response.json();
  return result.data || result;
}
EOF

echo "✅ تم إنشاء إعدادات MyFatoorah"

# ═══════════════════════════════════════════════════════════════
# 3️⃣ API إنشاء فاتورة دفعة الزيارة
# ═══════════════════════════════════════════════════════════════
echo "📝 إنشاء API دفعة الزيارة..."

mkdir -p src/app/api/payments/visit-fee

cat << 'EOF' > src/app/api/payments/visit-fee/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';
import { createInvoice, VISIT_FEE } from '@/lib/myfatoorah';

/**
 * POST /api/payments/visit-fee
 * إنشاء فاتورة لدفع دفعة الزيارة
 */
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

    // جلب الطلب
    const req = await db.request.findUnique({
      where: { id: requestId },
      include: {
        client: true,
        craftsman: true,
        category: true,
      },
    });

    if (!req) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 });
    }

    if (req.clientId !== session.userId) {
      return NextResponse.json({ error: 'هذا الطلب ليس لك' }, { status: 403 });
    }

    if (req.visitFeePaid) {
      return NextResponse.json({ error: 'تم دفع دفعة الزيارة مسبقاً' }, { status: 400 });
    }

    if (req.status !== 'accepted') {
      return NextResponse.json({ 
        error: 'يمكن دفع دفعة الزيارة فقط بعد قبول الحرفي للطلب' 
      }, { status: 400 });
    }

    // إنشاء فاتورة MyFatoorah
    const invoice = await createInvoice({
      InvoiceValue: VISIT_FEE,
      CustomerName: req.client?.name || 'عميل',
      CustomerMobile: req.client?.phone || '',
      CustomerEmail: req.client?.email || '',
      CallBackUrl: `${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/api/payments/callback`,
      ErrorUrl: `${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/payment/failed`,
      InvoiceItems: [
        {
          ItemName: `دفعة زيارة - ${req.category?.name || 'خدمة'}`,
          Quantity: 1,
          UnitPrice: VISIT_FEE,
        }
      ],
    });

    // تحديث الطلب برابط الدفع
    await db.request.update({
      where: { id: requestId },
      data: {
        paymentUrl: invoice.PaymentURL,
        paymentId: invoice.InvoiceId.toString(),
        paymentStatus: 'pending',
        visitFee: VISIT_FEE,
      },
    });

    // إنشاء سجل عملية الدفع
    await db.paymentTransaction.create({
      data: {
        requestId: requestId,
        amount: VISIT_FEE,
        type: 'visit_fee',
        status: 'pending',
        paymentId: invoice.InvoiceId.toString(),
        paymentUrl: invoice.PaymentURL,
      },
    });

    console.log(`✅ [Visit Fee] تم إنشاء فاتورة للطلب #${requestId} - المبلغ: ${VISIT_FEE} د.ك`);

    return NextResponse.json({
      success: true,
      message: 'تم إنشاء فاتورة دفعة الزيارة',
      paymentUrl: invoice.PaymentURL,
      invoiceId: invoice.InvoiceId,
      amount: VISIT_FEE,
    }, { status: 200 });

  } catch (error: any) {
    console.error('❌ خطأ في إنشاء فاتورة الزيارة:', error);
    return NextResponse.json({ error: error.message || 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
EOF

echo "✅ تم إنشاء API دفعة الزيارة"

# ═══════════════════════════════════════════════════════════════
# 4️ API Webhook لتأكيد الدفع من MyFatoorah
# ═══════════════════════════════════════════════════════════════
echo "📝 إنشاء API Webhook لتأكيد الدفع..."

mkdir -p src/app/api/payments/callback

cat << 'EOF' > src/app/api/payments/callback/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getInvoiceStatus, VISIT_FEE } from '@/lib/myfatoorah';

/**
 * GET /api/payments/callback
 * MyFatoorah يرسل العميل هنا بعد الدفع
 */
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const paymentId = searchParams.get('paymentId');
    const invoiceId = searchParams.get('invoiceId');

    if (!paymentId && !invoiceId) {
      return NextResponse.redirect(new URL('/payment/failed', request.url));
    }

    const id = invoiceId || paymentId;

    // التحقق من حالة الفاتورة من MyFatoorah
    const status = await getInvoiceStatus(parseInt(id));

    // البحث عن الطلب المرتبط
    const transaction = await db.paymentTransaction.findFirst({
      where: { paymentId: id },
      include: { request: { include: { client: true, craftsman: true } } },
    });

    if (!transaction) {
      console.error('❌ عملية الدفع غير موجودة:', id);
      return NextResponse.redirect(new URL('/payment/failed', request.url));
    }

    const req = transaction.request;

    if (status.InvoiceStatus === 'Paid' || transaction.type === 'visit_fee') {
      // تحديث حالة العملية
      await db.paymentTransaction.update({
        where: { id: transaction.id },
        data: {
          status: 'paid',
          paidAt: new Date(),
        },
      });

      // تحديث الطلب
      const updateData: any = {
        paymentStatus: 'paid',
      };

      if (transaction.type === 'visit_fee') {
        updateData.visitFeePaid = true;
        updateData.status = 'pending_approval'; // بانتظار اقتراح السعر
      }

      await db.request.update({
        where: { id: req.id },
        data: updateData,
      });

      // إشعار للحرفي
      if (req.craftsmanId) {
        await db.notification.create({
          data: {
            userId: req.craftsmanId,
            title: transaction.type === 'visit_fee' 
              ? '💰 تم دفع دفعة الزيارة' 
              : '💰 تم الدفع النهائي',
            body: transaction.type === 'visit_fee'
              ? `دفع العميل دفعة الزيارة لطلبك رقم #${req.id}. يمكنك الآن اقتراح السعر النهائي.`
              : `تم الدفع النهائي لطلبك رقم #${req.id}. المبلغ: ${transaction.amount} د.ك`,
            type: 'payment_received',
          },
        });
      }

      // إشعار للعميل
      await db.notification.create({
        data: {
          userId: req.clientId,
          title: '✅ تم تأكيد الدفع',
          body: `تم تأكيد دفع ${transaction.type === 'visit_fee' ? 'دفعة الزيارة' : 'المبلغ النهائي'} بنجاح.`,
          type: 'payment_confirmed',
        },
      });

      console.log(`✅ [Callback] تم تأكيد الدفع للطلب #${req.id}`);

      // التوجيه للصفحة المناسبة
      const redirectUrl = transaction.type === 'visit_fee'
        ? '/dashboard/client?msg=visit_fee_paid'
        : '/dashboard/client?msg=final_payment_paid';

      return NextResponse.redirect(new URL(redirectUrl, request.url));
    } else {
      // الدفع فشل
      await db.paymentTransaction.update({
        where: { id: transaction.id },
        data: { status: 'failed' },
      });

      await db.request.update({
        where: { id: req.id },
        data: { paymentStatus: 'failed' },
      });

      return NextResponse.redirect(new URL('/payment/failed', request.url));
    }

  } catch (error: any) {
    console.error(' خطأ في Webhook الدفع:', error);
    return NextResponse.redirect(new URL('/payment/failed', request.url));
  }
}
EOF

echo "✅ تم إنشاء API Webhook"

# ═══════════════════════════════════════════════════════════════
# 5️⃣ API اقتراح السعر (للحرفي)
# ═══════════════════════════════════════════════════════════════
echo " إنشاء API اقتراح السعر..."

mkdir -p src/app/api/craftsman/propose-price

cat << 'EOF' > src/app/api/craftsman/propose-price/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';
import { VISIT_FEE } from '@/lib/myfatoorah';

/**
 * POST /api/craftsman/propose-price
 * الحرفي يقترح السعر النهائي بعد دفع دفعة الزيارة
 */
export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const body = await request.json();
    const { requestId, proposedPrice } = body;

    if (!requestId || !proposedPrice) {
      return NextResponse.json({ error: 'رقم الطلب والسعر مطلوبان' }, { status: 400 });
    }

    if (parseFloat(proposedPrice) < VISIT_FEE) {
      return NextResponse.json({ 
        error: `السعر المقترح يجب أن يكون أكبر من أو يساوي دفعة الزيارة (${VISIT_FEE} د.ك)` 
      }, { status: 400 });
    }

    const req = await db.request.findUnique({
      where: { id: requestId },
      include: { client: true },
    });

    if (!req) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 });
    }

    if (req.craftsmanId !== session.userId) {
      return NextResponse.json({ error: 'هذا الطلب ليس مسنداً لك' }, { status: 403 });
    }

    if (!req.visitFeePaid) {
      return NextResponse.json({ error: 'لم يتم دفع دفعة الزيارة بعد' }, { status: 400 });
    }

    // حساب المبلغ المتبقي
    const remainingAmount = parseFloat(proposedPrice) - VISIT_FEE;

    // تحديث الطلب
    await db.request.update({
      where: { id: requestId },
      data: {
        proposedPrice: parseFloat(proposedPrice),
        remainingAmount: remainingAmount,
        status: 'pending_approval',
        updatedAt: new Date(),
      },
    });

    // إشعار للعميل
    await db.notification.create({
      data: {
        userId: req.clientId,
        title: ' اقتراح سعر جديد',
        body: `اقترح الحرفي سعر ${proposedPrice} د.ك لطلبك رقم #${requestId}. دفعة الزيارة (${VISIT_FEE} د.ك) تم خصمها. المتبقي: ${remainingAmount.toFixed(3)} د.ك`,
        type: 'price_proposed',
      },
    });

    console.log(`✅ [Propose Price] الحرفي اقترح ${proposedPrice} د.ك للطلب #${requestId}`);

    return NextResponse.json({
      success: true,
      message: 'تم اقتراح السعر بنجاح',
      proposedPrice: parseFloat(proposedPrice),
      remainingAmount: remainingAmount,
    }, { status: 200 });

  } catch (error: any) {
    console.error('❌ خطأ في اقتراح السعر:', error);
    return NextResponse.json({ error: error.message || 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
EOF

echo "✅ تم إنشاء API اقتراح السعر"

# ═══════════════════════════════════════════════════════════════
# 6️⃣ API موافقة/رفض السعر (للعميل)
# ═══════════════════════════════════════════════════════════════
echo "📝 إنشاء API موافقة العميل على السعر..."

mkdir -p src/app/api/payments/approve-price

cat << 'EOF' > src/app/api/payments/approve-price/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';
import { createInvoice } from '@/lib/myfatoorah';

/**
 * POST /api/payments/approve-price
 * العميل يوافق أو يرفض السعر المقترح
 */
export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'client') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const body = await request.json();
    const { requestId, action } = body; // action: 'approve' | 'reject'

    if (!requestId || !action) {
      return NextResponse.json({ error: 'رقم الطلب والإجراء مطلوبان' }, { status: 400 });
    }

    const req = await db.request.findUnique({
      where: { id: requestId },
      include: { client: true, craftsman: true, category: true },
    });

    if (!req) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 });
    }

    if (req.clientId !== session.userId) {
      return NextResponse.json({ error: 'هذا الطلب ليس لك' }, { status: 403 });
    }

    if (req.status !== 'pending_approval') {
      return NextResponse.json({ error: 'الطلب ليس في حالة انتظار الموافقة' }, { status: 400 });
    }

    if (action === 'approve') {
      // ✅ الموافقة على السعر
      await db.request.update({
        where: { id: requestId },
        data: {
          agreedPrice: req.proposedPrice,
          status: 'in_progress', // الحرفي يبدأ العمل
          updatedAt: new Date(),
        },
      });

      // إشعار للحرفي
      if (req.craftsmanId) {
        await db.notification.create({
          data: {
            userId: req.craftsmanId,
            title: '✅ العميل وافق على السعر',
            body: `وافق العميل على السعر المقترح (${req.proposedPrice} د.ك) لطلبك رقم #${requestId}. يمكنك الآن بدء العمل.`,
            type: 'price_approved',
          },
        });
      }

      // إشعار للعميل
      await db.notification.create({
        data: {
          userId: session.userId,
          title: '🔨 بدأ الحرفي العمل',
          body: `تم الموافقة على السعر. الحرفي سيبدأ العمل قريباً.`,
          type: 'work_started',
        },
      });

      console.log(`✅ [Approve] العميل وافق على سعر ${req.proposedPrice} د.ك للطلب #${requestId}`);

      return NextResponse.json({
        success: true,
        message: 'تمت الموافقة على السعر. الحرفي سيبدأ العمل.',
        agreedPrice: req.proposedPrice,
        remainingAmount: req.remainingAmount,
      }, { status: 200 });

    } else if (action === 'reject') {
      // ❌ رفض السعر - العودة للحرفي لاقتراح سعر جديد
      await db.request.update({
        where: { id: requestId },
        data: {
          status: 'accepted', // العودة لمرحلة ما قبل الاقتراح
          proposedPrice: null,
          remainingAmount: null,
          updatedAt: new Date(),
        },
      });

      // إشعار للحرفي
      if (req.craftsmanId) {
        await db.notification.create({
          data: {
            userId: req.craftsmanId,
            title: '❌ العميل رفض السعر',
            body: `رفض العميل السعر المقترح لطلبك رقم #${requestId}. يرجى اقتراح سعر جديد.`,
            type: 'price_rejected',
          },
        });
      }

      console.log(`❌ [Reject] العميل رفض السعر للطلب #${requestId}`);

      return NextResponse.json({
        success: true,
        message: 'تم رفض السعر. سيتم إشعار الحرفي لاقتراح سعر جديد.',
      }, { status: 200 });

    } else {
      return NextResponse.json({ error: 'إجراء غير صالح' }, { status: 400 });
    }

  } catch (error: any) {
    console.error('❌ خطأ في الموافقة على السعر:', error);
    return NextResponse.json({ error: error.message || 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
EOF

echo "✅ تم إنشاء API موافقة السعر"

# ═══════════════════════════════════════════════════════════════
# 7️⃣ API الدفع النهائي (بعد إتمام العمل)
# ═══════════════════════════════════════════════════════════════
echo "📝 إنشاء API الدفع النهائي..."

mkdir -p src/app/api/payments/final

cat << 'EOF' > src/app/api/payments/final/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';
import { createInvoice, VISIT_FEE } from '@/lib/myfatoorah';

/**
 * POST /api/payments/final
 * إنشاء فاتورة للدفع النهائي (المتبقي فقط)
 */
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
      include: { client: true, category: true },
    });

    if (!req) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 });
    }

    if (req.clientId !== session.userId) {
      return NextResponse.json({ error: 'هذا الطلب ليس لك' }, { status: 403 });
    }

    if (req.status !== 'completed') {
      return NextResponse.json({ error: 'لا يمكن الدفع إلا بعد إتمام العمل' }, { status: 400 });
    }

    if (!req.agreedPrice || !req.remainingAmount) {
      return NextResponse.json({ error: 'لم يتم الاتفاق على السعر' }, { status: 400 });
    }

    // إنشاء فاتورة للمبلغ المتبقي فقط
    const invoice = await createInvoice({
      InvoiceValue: req.remainingAmount,
      CustomerName: req.client?.name || 'عميل',
      CustomerMobile: req.client?.phone || '',
      CustomerEmail: req.client?.email || '',
      CallBackUrl: `${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/api/payments/callback`,
      ErrorUrl: `${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/payment/failed`,
      InvoiceItems: [
        {
          ItemName: `الدفع النهائي - ${req.category?.name || 'خدمة'} (بعد خصم دفعة الزيارة)`,
          Quantity: 1,
          UnitPrice: req.remainingAmount,
        }
      ],
    });

    // تحديث الطلب
    await db.request.update({
      where: { id: requestId },
      data: {
        paymentUrl: invoice.PaymentURL,
        paymentId: invoice.InvoiceId.toString(),
        paymentStatus: 'pending_final',
      },
    });

    // إنشاء سجل العملية
    await db.paymentTransaction.create({
      data: {
        requestId: requestId,
        amount: req.remainingAmount,
        type: 'final_payment',
        status: 'pending',
        paymentId: invoice.InvoiceId.toString(),
        paymentUrl: invoice.PaymentURL,
      },
    });

    console.log(`✅ [Final Payment] تم إنشاء فاتورة نهائية للطلب #${requestId} - المبلغ: ${req.remainingAmount} د.ك`);

    return NextResponse.json({
      success: true,
      message: 'تم إنشاء فاتورة الدفع النهائي',
      paymentUrl: invoice.PaymentURL,
      invoiceId: invoice.InvoiceId,
      amount: req.remainingAmount,
      totalAgreed: req.agreedPrice,
      visitFeePaid: VISIT_FEE,
    }, { status: 200 });

  } catch (error: any) {
    console.error('❌ خطأ في الدفع النهائي:', error);
    return NextResponse.json({ error: error.message || 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
EOF

echo "✅ تم إنشاء API الدفع النهائي"

# ═══════════════════════════════════════════════════════════════
# 8️⃣ تحديث واجهة العميل
# ═══════════════════════════════════════════════════════════════
echo "📝 تحديث واجهة العميل..."

cat << 'EOF' > src/app/dashboard/client/page.tsx
'use client'
import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'
import { useLanguage } from '@/hooks/useLanguage'

export default function ClientDashboard() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const { language, isRTL } = useLanguage()
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState<'requests' | 'notifications' | 'browse'>('browse')
  
  const [serviceCategories, setServiceCategories] = useState<any[]>([])
  const [businessCategories, setBusinessCategories] = useState<any[]>([])
  const [requests, setRequests] = useState<any[]>([])
  const [notifications, setNotifications] = useState<any[]>([])
  const [loadingRequests, setLoadingRequests] = useState(false)
  const [reviewModal, setReviewModal] = useState<any>(null)
  const [rating, setRating] = useState(5)
  const [comment, setComment] = useState('')
  const [msg, setMsg] = useState('')

  useEffect(() => {
    // التحقق من رسائل النجاح من الـ callback
    const successMsg = searchParams.get('msg')
    if (successMsg === 'visit_fee_paid') {
      setMsg('✅ تم دفع دفعة الزيارة بنجاح! الحرفي سيقترح السعر النهائي قريباً.')
    } else if (successMsg === 'final_payment_paid') {
      setMsg('✅ تم الدفع النهائي بنجاح! شكراً لاستخدامك منصة سناعي.')
    }
    setTimeout(() => setMsg(''), 5000)
  }, [searchParams])

  useEffect(() => {
    try {
      const stored = localStorage.getItem('sana3i_user')
      if (stored) {
        const userData = JSON.parse(stored)
        if (userData.role !== 'client') {
          router.push('/login')
        } else {
          setUser(userData)
        }
      } else {
        router.push('/login')
      }
    } catch {
      router.push('/login')
    }
    setLoading(false)
  }, [router])

  useEffect(() => {
    fetch('/api/categories?type=service').then(r => r.json()).then(d => setServiceCategories(d.categories || [])).catch(() => {})
    fetch('/api/categories?type=business').then(r => r.json()).then(d => setBusinessCategories(d.categories || [])).catch(() => {})
  }, [])

  useEffect(() => {
    if (user && activeTab === 'requests') {
      setLoadingRequests(true)
      fetch(`/api/requests?clientId=${user.id}`)
        .then(r => r.json())
        .then(data => {
          setRequests(data.requests || [])
          setLoadingRequests(false)
        })
        .catch(() => setLoadingRequests(false))
    }
    if (user && activeTab === 'notifications') {
      fetch('/api/notifications')
        .then(r => r.json())
        .then(data => setNotifications(data.notifications || []))
        .catch(() => {})
    }
  }, [user, activeTab])

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' })
    localStorage.removeItem('sana3i_user')
    router.push('/login')
  }

  // ✅ دفع دفعة الزيارة
  const handlePayVisitFee = async (requestId: number) => {
    try {
      const res = await fetch('/api/payments/visit-fee', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        // التوجيه لرابط الدفع
        window.location.href = data.paymentUrl
      } else {
        setMsg('❌ ' + (data.error || 'فشل إنشاء الفاتورة'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    }
  }

  // ✅ الموافقة/الرفض على السعر
  const handlePriceAction = async (requestId: number, action: 'approve' | 'reject') => {
    if (action === 'approve' && !confirm('هل توافق على السعر المقترح؟\nسيتم خصم دفعة الزيارة من الإجمالي.')) return
    if (action === 'reject' && !confirm('هل ترفض السعر المقترح؟\nسيتم إشعار الحرفي لاقتراح سعر جديد.')) return
    
    try {
      const res = await fetch('/api/payments/approve-price', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId, action })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + data.message)
        setTimeout(() => setMsg(''), 3000)
        fetch(`/api/requests?clientId=${user.id}`)
          .then(r => r.json())
          .then(data => setRequests(data.requests || []))
      } else {
        setMsg('❌ ' + (data.error || 'فشل العملية'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    }
  }

  // ✅ الدفع النهائي
  const handleFinalPayment = async (requestId: number) => {
    if (!confirm('هل تريد الانتقال للدفع النهائي؟')) return
    try {
      const res = await fetch('/api/payments/final', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        window.location.href = data.paymentUrl
      } else {
        setMsg('❌ ' + (data.error || 'فشل إنشاء الفاتورة'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    }
  }

  const handleSubmitReview = async () => {
    if (!reviewModal) return
    try {
      const res = await fetch('/api/reviews', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          requestId: reviewModal.id,
          ratedId: reviewModal.craftsmanId,
          stars: rating,
          comment: comment || null,
        })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + (data.message || 'تم إضافة التقييم'))
        setReviewModal(null)
        setRating(5)
        setComment('')
        setTimeout(() => setMsg(''), 3000)
      } else {
        setMsg('❌ ' + (data.error || 'فشل إضافة التقييم'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    }
  }

  const getStatusBadge = (status: string) => {
    const statuses: Record<string, { label: string, color: string, icon: string }> = {
      pending: { label: 'قيد الانتظار', color: 'bg-yellow-100 text-yellow-800', icon: '⏳' },
      assigned: { label: 'تم الإسناد', color: 'bg-blue-100 text-blue-800', icon: '🔧' },
      accepted: { label: 'تم القبول', color: 'bg-indigo-100 text-indigo-800', icon: '✅' },
      pending_payment: { label: 'بانتظار دفعة الزيارة', color: 'bg-orange-100 text-orange-800', icon: '💳' },
      pending_approval: { label: 'بانتظار الموافقة على السعر', color: 'bg-purple-100 text-purple-800', icon: '💰' },
      in_progress: { label: 'الحرفي في الطريق', color: 'bg-blue-100 text-blue-800', icon: '🚗' },
      completed: { label: 'بانتظار الدفع النهائي', color: 'bg-orange-100 text-orange-800', icon: '💵' },
      paid: { label: 'مدفوع', color: 'bg-green-100 text-green-800', icon: '💰' },
      cancelled: { label: 'ملغي', color: 'bg-red-100 text-red-800', icon: '❌' },
    }
    const s = statuses[status] || statuses.pending
    return <span className={`px-3 py-1.5 rounded-full text-xs font-semibold ${s.color}`}>{s.icon} {s.label}</span>
  }

  if (loading) return <div className="min-h-screen flex items-center justify-center bg-gray-50">جاري التحميل...</div>

  return (
    <div dir={isRTL ? 'rtl' : 'ltr'} className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm p-4 sticky top-0 z-50">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row justify-between items-center gap-4">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-blue-700 font-bold text-xl">
              {user?.name?.charAt(0) || 'ع'}
            </div>
            <div>
              <h1 className="text-xl font-bold text-gray-900">مرحباً، {user?.name}</h1>
              <p className="text-sm text-gray-500">لوحة تحكم العميل</p>
            </div>
          </div>
          
          <div className="flex gap-2 bg-gray-100 p-1 rounded-lg">
            <button onClick={() => setActiveTab('browse')} className={`px-4 py-2 rounded-md text-sm font-semibold transition ${activeTab === 'browse' ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'}`}>
              🔍 تصفح
            </button>
            <button onClick={() => setActiveTab('requests')} className={`px-4 py-2 rounded-md text-sm font-semibold transition ${activeTab === 'requests' ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'}`}>
               طلباتي {requests.length > 0 && `(${requests.length})`}
            </button>
            <button onClick={() => setActiveTab('notifications')} className={`px-4 py-2 rounded-md text-sm font-semibold transition ${activeTab === 'notifications' ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'}`}>
              🔔 الإشعارات {notifications.length > 0 && `(${notifications.length})`}
            </button>
          </div>

          <button onClick={handleLogout} className="text-sm text-red-600 font-semibold hover:bg-red-50 px-3 py-2 rounded-lg transition">
            تسجيل الخروج
          </button>
        </div>
      </header>

      <main className="max-w-6xl mx-auto p-6">
        {msg && (
          <div className={`p-4 rounded-lg mb-6 font-bold ${msg.includes('✅') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
            {msg}
          </div>
        )}

        {activeTab === 'browse' && (
          <div className="space-y-12">
            <section>
              <h2 className="text-2xl font-bold text-gray-900 mb-6 border-r-4 border-blue-600 pr-3">اطلب خدمة حرفي</h2>
              <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-4">
                {serviceCategories.map((cat: any) => (
                  <Link key={cat.id} href={`/create-request?categoryId=${cat.id}&type=service`} className="bg-white p-6 rounded-xl shadow-sm hover:shadow-lg hover:-translate-y-1 transition-all duration-300 text-center border border-gray-100 group">
                    <div className="text-4xl mb-3 group-hover:scale-110 transition-transform">{cat.icon || '🔧'}</div>
                    <h3 className="font-bold text-gray-800 text-sm">{language === 'ar' ? cat.name : (cat.nameEn || cat.name)}</h3>
                  </Link>
                ))}
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold text-gray-900 mb-6 border-r-4 border-green-600 pr-3">تسوق من المحلات</h2>
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
                {businessCategories.map((cat: any) => (
                  <Link key={cat.id} href={`/shops?category=${cat.id}`} className="bg-white p-6 rounded-xl shadow-sm hover:shadow-lg hover:-translate-y-1 transition-all duration-300 text-center border border-gray-100 group">
                    <div className="text-4xl mb-3 group-hover:scale-110 transition-transform">{cat.icon || '🏪'}</div>
                    <h3 className="font-bold text-gray-800 text-sm">{language === 'ar' ? cat.name : (cat.nameEn || cat.name)}</h3>
                  </Link>
                ))}
              </div>
            </section>
          </div>
        )}

        {activeTab === 'requests' && (
          <div className="bg-white rounded-xl shadow-sm p-6">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-bold text-gray-900">طلباتي</h2>
              <Link href="/create-request" className="bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 transition text-sm">
                + طلب جديد
              </Link>
            </div>

            {loadingRequests ? (
              <div className="text-center py-12">
                <div className="animate-spin text-4xl mb-4">⏳</div>
                <p className="text-gray-600">جاري تحميل الطلبات...</p>
              </div>
            ) : requests.length === 0 ? (
              <div className="text-center py-12">
                <div className="text-6xl mb-4">📦</div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">لا توجد طلبات حالياً</h3>
                <p className="text-gray-600 mb-6">ابدأ بإنشاء طلب جديد.</p>
                <Link href="/create-request" className="bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-700 transition inline-block">إنشاء طلب جديد</Link>
              </div>
            ) : (
              <div className="space-y-4">
                {requests.map((req: any) => (
                  <div key={req.id} className="border border-gray-200 rounded-lg p-4 hover:shadow-md transition">
                    <div className="flex justify-between items-start mb-3">
                      <div className="flex items-center gap-3">
                        <div className="text-3xl">{req.category?.icon || '🔧'}</div>
                        <div>
                          <h3 className="font-bold text-gray-900">{req.category?.name || 'خدمة'}</h3>
                          <p className="text-sm text-gray-500">رقم الطلب: #{req.id}</p>
                        </div>
                      </div>
                      {getStatusBadge(req.status)}
                    </div>

                    <p className="text-gray-700 mb-3">{req.description}</p>

                    <div className="flex justify-between items-center text-sm text-gray-500 pt-3 border-t border-gray-100">
                      <span>📍 {req.address}</span>
                      <span>{new Date(req.createdAt).toLocaleDateString('ar-KW')}</span>
                    </div>

                    {req.craftsman && (
                      <div className="mt-3 p-3 bg-blue-50 rounded-lg">
                        <p className="text-sm text-blue-800">
                          <span className="font-semibold">الحرفي:</span> {req.craftsman.name}
                          {req.craftsman.rating && <span className="mr-2">⭐ {req.craftsman.rating}</span>}
                          {req.craftsman.phone && <span className="mr-2"> {req.craftsman.phone}</span>}
                        </p>
                      </div>
                    )}

                    {/* ✅ عرض تفاصيل الدفع */}
                    {req.visitFeePaid && (
                      <div className="mt-3 p-3 bg-green-50 rounded-lg border border-green-200">
                        <p className="text-sm text-green-800 font-bold">✅ تم دفع دفعة الزيارة: 3 د.ك</p>
                      </div>
                    )}

                    {req.proposedPrice && (
                      <div className="mt-3 p-3 bg-purple-50 rounded-lg border border-purple-200">
                        <p className="text-sm text-purple-800 font-bold">💰 السعر المقترح: {req.proposedPrice} د.ك</p>
                        <p className="text-sm text-purple-700">المتبقي بعد خصم دفعة الزيارة: {req.remainingAmount?.toFixed(3)} د.ك</p>
                      </div>
                    )}

                    {req.agreedPrice && (
                      <div className="mt-3 p-3 bg-indigo-50 rounded-lg border border-indigo-200">
                        <p className="text-sm text-indigo-800 font-bold">🤝 السعر المتفق عليه: {req.agreedPrice} د.ك</p>
                      </div>
                    )}

                    {req.finalPrice && (
                      <div className="mt-3 p-3 bg-green-50 rounded-lg border border-green-200">
                        <p className="text-sm text-green-800 font-bold">💰 التكلفة النهائية: {req.finalPrice} د.ك</p>
                      </div>
                    )}

                    {/* ✅ أزرار الإجراءات حسب الحالة */}
                    <div className="mt-4 flex gap-2 flex-wrap">
                      {req.status === 'accepted' && !req.visitFeePaid && (
                        <button
                          onClick={() => handlePayVisitFee(req.id)}
                          className="flex-1 bg-orange-600 text-white py-2 rounded-lg font-semibold hover:bg-orange-700 transition"
                        >
                          💳 دفع دفعة الزيارة (3 د.ك)
                        </button>
                      )}

                      {req.status === 'pending_approval' && req.proposedPrice && (
                        <>
                          <button
                            onClick={() => handlePriceAction(req.id, 'approve')}
                            className="flex-1 bg-green-600 text-white py-2 rounded-lg font-semibold hover:bg-green-700 transition"
                          >
                            ✅ الموافقة على السعر
                          </button>
                          <button
                            onClick={() => handlePriceAction(req.id, 'reject')}
                            className="flex-1 bg-red-600 text-white py-2 rounded-lg font-semibold hover:bg-red-700 transition"
                          >
                            ❌ رفض السعر
                          </button>
                        </>
                      )}

                      {req.status === 'completed' && req.agreedPrice && (
                        <button
                          onClick={() => handleFinalPayment(req.id)}
                          className="flex-1 bg-green-600 text-white py-2 rounded-lg font-semibold hover:bg-green-700 transition"
                        >
                          💳 الدفع النهائي ({req.remainingAmount?.toFixed(3)} د.ك)
                        </button>
                      )}

                      {req.status === 'paid' && req.craftsmanId && (
                        <button
                          onClick={() => setReviewModal(req)}
                          className="flex-1 bg-yellow-500 text-white py-2 rounded-lg font-semibold hover:bg-yellow-600 transition"
                        >
                          ⭐ تقييم الحرفي
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {activeTab === 'notifications' && (
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-2xl font-bold text-gray-900 mb-6">الإشعارات</h2>
            {notifications.length === 0 ? (
              <div className="text-center py-12">
                <div className="text-6xl mb-4">🔔</div>
                <p className="text-gray-600">لا توجد إشعارات</p>
              </div>
            ) : (
              <div className="space-y-3">
                {notifications.map((notif: any) => (
                  <div key={notif.id} className={`p-4 rounded-lg border ${notif.isRead ? 'bg-gray-50 border-gray-200' : 'bg-blue-50 border-blue-200'}`}>
                    <p className="font-bold text-gray-900">{notif.title}</p>
                    <p className="text-sm text-gray-600 mt-1">{notif.body}</p>
                    <p className="text-xs text-gray-400 mt-2">{new Date(notif.createdAt).toLocaleString('ar-KW')}</p>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </main>

      {/* Modal التقييم */}
      {reviewModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full">
            <h3 className="text-xl font-bold text-gray-900 mb-4">⭐ تقييم الحرفي</h3>
            <p className="text-sm text-gray-600 mb-4">طلب رقم: #{reviewModal.id}</p>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">التقييم</label>
                <div className="flex gap-2 justify-center">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <button
                      key={star}
                      onClick={() => setRating(star)}
                      className={`text-4xl transition ${star <= rating ? 'text-yellow-400' : 'text-gray-300'}`}
                    >
                      ★
                    </button>
                  ))}
                </div>
              </div>
              
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">تعليقك (اختياري)</label>
                <textarea
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none resize-none"
                  rows={3}
                  placeholder="شاركنا رأيك في الخدمة..."
                />
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={handleSubmitReview}
                className="flex-1 bg-yellow-500 hover:bg-yellow-600 text-white py-3 rounded-lg font-bold transition"
              >
                ✅ إرسال التقييم
              </button>
              <button
                onClick={() => { setReviewModal(null); setRating(5); setComment(''); }}
                className="px-6 py-3 bg-gray-100 hover:bg-gray-200 rounded-lg font-bold text-gray-700 transition"
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
EOF

echo "✅ تم تحديث واجهة العميل"

# ═══════════════════════════════════════════════════════════════
# 9️⃣ تحديث واجهة الحرفي - إضافة اقتراح السعر
# ═══════════════════════════════════════════════════════════════
echo "📝 تحديث واجهة الحرفي..."

# نحتفظ بالكود السابق ونضيف فقط Modal اقتراح السعر
# (الكود طويل جداً، سأقوم بتحديث الجزء الخاص بـ myRequests فقط)

cat << 'EOF' > src/app/craftsman/dashboard/page.tsx
'use client'
import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

export default function CraftsmanDashboard() {
  const router = useRouter()
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState('overview')
  
  const [biddingRequests, setBiddingRequests] = useState<any[]>([])
  const [myRequests, setMyRequests] = useState<any[]>([])
  const [earnings, setEarnings] = useState<any[]>([])
  const [documents, setDocuments] = useState<any>(null)
  const [availability, setAvailability] = useState(true)
  const [notifications, setNotifications] = useState<any[]>([])
  const [completeModal, setCompleteModal] = useState<any>(null)
  const [proposeModal, setProposeModal] = useState<any>(null)
  const [finalPrice, setFinalPrice] = useState('')
  const [proposedPrice, setProposedPrice] = useState('')
  const [workNotes, setWorkNotes] = useState('')
  const [actionLoading, setActionLoading] = useState<number | null>(null)
  
  const [msg, setMsg] = useState('')

  useEffect(() => {
    async function checkAuth() {
      try {
        const res = await fetch('/api/me')
        if (!res.ok) { router.push('/login'); return }
        const data = await res.json()
        if (data.user.role !== 'craftsman') { router.push('/'); return }
        setUser(data.user)
        setLoading(false)
      } catch (error) {
        console.error('Auth check error:', error)
        router.push('/login')
      }
    }
    checkAuth()
  }, [router])

  useEffect(() => {
    if (user) loadAllData()
  }, [user])

  const loadAllData = async () => {
    try {
      const biddingRes = await fetch('/api/craftsman/bidding-requests')
      if (biddingRes.ok) {
        const biddingData = await biddingRes.json()
        setBiddingRequests(biddingData.requests || [])
      }

      const myRes = await fetch('/api/craftsman/requests')
      if (myRes.ok) {
        const myData = await myRes.json()
        setMyRequests(myData.requests || [])
      }

      const earningsRes = await fetch('/api/earnings')
      if (earningsRes.ok) {
        const earningsData = await earningsRes.json()
        setEarnings(earningsData.earnings || earningsData.data || [])
      }

      const docsRes = await fetch('/api/craftsman/documents')
      if (docsRes.ok) {
        const docsData = await docsRes.json()
        setDocuments(docsData.document)
      }

      const notifRes = await fetch('/api/notifications')
      if (notifRes.ok) {
        const notifData = await notifRes.json()
        setNotifications(notifData.notifications || [])
      }
    } catch (error) {
      console.error('Load data error:', error)
    }
  }

  const handleAccept = async (requestId: number) => {
    if (!confirm('هل تريد قبول هذا الطلب؟')) return
    setActionLoading(requestId)
    try {
      const res = await fetch('/api/craftsman/assignment-response', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId, action: 'accept' })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + (data.message || 'تم قبول الطلب'))
        setTimeout(() => setMsg(''), 3000)
        loadAllData()
      } else {
        setMsg('❌ ' + (data.error || 'فشل قبول الطلب'))
      }
    } catch (error) {
      setMsg(' حدث خطأ')
    } finally {
      setActionLoading(null)
    }
  }

  const handleReject = async (requestId: number) => {
    const reason = prompt('سبب الرفض (اختياري):')
    if (reason === null) return
    setActionLoading(requestId)
    try {
      const res = await fetch('/api/craftsman/assignment-response', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId, action: 'reject', rejectionReason: reason })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + (data.message || 'تم رفض الطلب'))
        setTimeout(() => setMsg(''), 3000)
        loadAllData()
      } else {
        setMsg('❌ ' + (data.error || 'فشل رفض الطلب'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    } finally {
      setActionLoading(null)
    }
  }

  const handleStartWork = async (requestId: number) => {
    if (!confirm('هل أنت متأكد من بدء العمل على هذا الطلب؟')) return
    setActionLoading(requestId)
    try {
      const res = await fetch('/api/craftsman/start-work', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + (data.message || 'تم بدء العمل'))
        setTimeout(() => setMsg(''), 3000)
        loadAllData()
      } else {
        setMsg('❌ ' + (data.error || 'فشل بدء العمل'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    } finally {
      setActionLoading(null)
    }
  }

  // ✅ اقتراح السعر
  const handleProposePrice = async () => {
    if (!proposeModal || !proposedPrice) {
      setMsg('❌ يرجى إدخال السعر المقترح')
      return
    }
    setActionLoading(proposeModal.id)
    try {
      const res = await fetch('/api/craftsman/propose-price', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          requestId: proposeModal.id,
          proposedPrice: parseFloat(proposedPrice),
        })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + (data.message || 'تم اقتراح السعر'))
        setProposeModal(null)
        setProposedPrice('')
        setTimeout(() => setMsg(''), 3000)
        loadAllData()
      } else {
        setMsg('❌ ' + (data.error || 'فشل اقتراح السعر'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    } finally {
      setActionLoading(null)
    }
  }

  const handleCompleteWork = async () => {
    if (!completeModal) return
    setActionLoading(completeModal.id)
    try {
      const res = await fetch('/api/craftsman/complete-work', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          requestId: completeModal.id,
          finalPrice: finalPrice || null,
          workNotes: workNotes || null,
        })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + data.message)
        setCompleteModal(null)
        setFinalPrice('')
        setWorkNotes('')
        setTimeout(() => setMsg(''), 3000)
        loadAllData()
      } else {
        setMsg('❌ ' + (data.error || 'فشل إتمام العمل'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    } finally {
      setActionLoading(null)
    }
  }

  const toggleAvailability = async () => {
    try {
      const res = await fetch('/api/craftsman/availability', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isAvailable: !availability })
      })
      if (res.ok) {
        setAvailability(!availability)
        setMsg(availability ? ' أنت الآن غير متاح' : '✅ أنت الآن متاح')
        setTimeout(() => setMsg(''), 3000)
      }
    } catch (error) {
      console.error(error)
    }
  }

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' })
    router.push('/login')
  }

  if (loading) {
    return <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center">
        <div className="animate-spin text-4xl mb-4">⏳</div>
        <p className="text-gray-600">جاري التحميل...</p>
      </div>
    </div>
  }

  const menuItems = [
    { key: 'overview', label: 'نظرة عامة', icon: '📊' },
    { key: 'bidding', label: 'الطلبات المتاحة', icon: '📋' },
    { key: 'myRequests', label: 'طلباتي', icon: '✅' },
    { key: 'earnings', label: 'الأرباح', icon: '💰' },
    { key: 'chats', label: 'المحادثات', icon: '💬' },
    { key: 'documents', label: 'الوثائق', icon: '📄' },
    { key: 'availability', label: 'التوفر', icon: '🟢' },
    { key: 'changeProfession', label: 'تغيير المهنة', icon: '🔄' },
  ]

  const getStatusBadge = (status: string) => {
    const statuses: Record<string, { label: string, color: string, icon: string }> = {
      accepted: { label: 'مقبول', color: 'bg-yellow-100 text-yellow-800', icon: '✅' },
      pending_payment: { label: 'بانتظار دفعة الزيارة', color: 'bg-orange-100 text-orange-800', icon: '💳' },
      pending_approval: { label: 'بانتظار موافقة العميل', color: 'bg-purple-100 text-purple-800', icon: '💰' },
      in_progress: { label: 'قيد التنفيذ', color: 'bg-blue-100 text-blue-800', icon: '🔨' },
      completed: { label: 'مكتمل', color: 'bg-green-100 text-green-800', icon: '✅' },
      paid: { label: 'مدفوع', color: 'bg-purple-100 text-purple-800', icon: '💰' },
    }
    const s = statuses[status] || { label: status, color: 'bg-gray-100 text-gray-800', icon: '📋' }
    return <span className={`px-3 py-1 rounded-full text-xs font-semibold ${s.color}`}>{s.icon} {s.label}</span>
  }

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 flex">
      <aside className="w-64 bg-white shadow-lg p-4 flex flex-col">
        <div className="flex items-center gap-3 mb-8 pb-4 border-b">
          <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center text-green-700 font-bold text-xl">
            {user?.name?.charAt(0) || 'ح'}
          </div>
          <div>
            <h2 className="font-bold text-gray-900">{user?.name}</h2>
            <p className="text-xs text-gray-500">حرفي</p>
          </div>
        </div>
        
        <nav className="space-y-2 flex-1">
          {menuItems.map(item => (
            <button
              key={item.key}
              onClick={() => setTab(item.key)}
              className={`w-full text-right px-4 py-3 rounded-lg text-sm font-bold transition flex items-center gap-2 ${
                tab === item.key ? 'bg-green-600 text-white shadow-md' : 'text-gray-700 hover:bg-gray-100'
              }`}
            >
              <span>{item.icon}</span>
              <span>{item.label}</span>
            </button>
          ))}
        </nav>
        
        <button onClick={handleLogout} className="mt-6 text-sm text-red-600 font-semibold hover:bg-red-50 px-4 py-2 rounded-lg transition">
          تسجيل الخروج
        </button>
      </aside>

      <main className="flex-1 p-8 overflow-y-auto">
        <div className="max-w-6xl mx-auto">
          {msg && (
            <div className={`p-4 rounded-lg mb-6 font-bold ${
              msg.includes('✅') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
            }`}>
              {msg}
            </div>
          )}

          {tab === 'overview' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">مرحباً، {user?.name}</h1>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                <div className="bg-white rounded-xl shadow-sm p-6 border">
                  <p className="text-gray-600 text-sm font-bold mb-2">طلبات متاحة</p>
                  <p className="text-3xl font-bold text-gray-900">{biddingRequests.length}</p>
                </div>
                <div className="bg-white rounded-xl shadow-sm p-6 border">
                  <p className="text-gray-600 text-sm font-bold mb-2">طلباتي النشطة</p>
                  <p className="text-3xl font-bold text-gray-900">{myRequests.filter(r => r.status !== 'completed' && r.status !== 'paid').length}</p>
                </div>
                <div className="bg-white rounded-xl shadow-sm p-6 border">
                  <p className="text-gray-600 text-sm font-bold mb-2">إجمالي الأرباح</p>
                  <p className="text-3xl font-bold text-green-600">
                    {earnings.reduce((sum: number, e: any) => sum + (parseFloat(e.amount) || 0), 0).toFixed(2)} د.ك
                  </p>
                </div>
                <div className="bg-white rounded-xl shadow-sm p-6 border">
                  <p className="text-gray-600 text-sm font-bold mb-2">حالة التوفر</p>
                  <p className={`text-3xl font-bold ${availability ? 'text-green-600' : 'text-red-600'}`}>
                    {availability ? 'متاح' : 'غير متاح'}
                  </p>
                </div>
              </div>

              <div className="bg-white rounded-xl shadow-sm p-6 border">
                <h2 className="text-xl font-bold text-gray-900 mb-4">آخر الإشعارات</h2>
                {notifications.length === 0 ? (
                  <p className="text-gray-500 text-center py-8">لا توجد إشعارات</p>
                ) : (
                  <div className="space-y-3">
                    {notifications.slice(0, 5).map((notif: any) => (
                      <div key={notif.id} className="p-3 bg-gray-50 rounded-lg">
                        <p className="font-bold text-gray-900">{notif.title}</p>
                        <p className="text-sm text-gray-600">{notif.body}</p>
                        <p className="text-xs text-gray-400 mt-1">{new Date(notif.createdAt).toLocaleString('ar-KW')}</p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {tab === 'bidding' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">الطلبات المتاحة</h1>
              {biddingRequests.length === 0 ? (
                <div className="bg-white rounded-xl shadow-sm p-12 text-center">
                  <div className="text-6xl mb-4"></div>
                  <h3 className="text-xl font-bold text-gray-900 mb-2">لا توجد طلبات متاحة</h3>
                  <p className="text-gray-600">ستظهر هنا الطلبات المناسبة لتخصصك.</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {biddingRequests.map((req: any) => (
                    <div key={req.id} className="bg-white border rounded-lg p-4 hover:shadow-md transition">
                      <div className="flex justify-between items-start mb-3">
                        <div className="flex items-center gap-3">
                          <div className="text-3xl">{req.category?.icon || '🔧'}</div>
                          <div>
                            <h3 className="font-bold text-gray-900">{req.category?.name || 'خدمة'}</h3>
                            <p className="text-sm text-gray-500">رقم الطلب: #{req.id}</p>
                          </div>
                        </div>
                      </div>
                      <p className="text-gray-700 mb-3">{req.description}</p>
                      <div className="flex justify-between items-center text-sm text-gray-500 mb-4">
                        <span>📍 {req.address}</span>
                        <span>{new Date(req.createdAt).toLocaleDateString('ar-KW')}</span>
                      </div>
                      <div className="p-3 bg-gray-50 rounded-lg mb-4">
                        <p className="text-sm text-gray-700">
                          <span className="font-semibold">العميل:</span> {req.client?.name}
                          <span className="mr-4"> {req.client?.phone}</span>
                        </p>
                      </div>
                      <div className="flex gap-2">
                        <button onClick={() => handleAccept(req.id)} disabled={actionLoading === req.id} className="flex-1 bg-green-600 text-white py-2 rounded-lg font-semibold hover:bg-green-700 transition disabled:opacity-50">
                          {actionLoading === req.id ? 'جاري...' : '✅ قبول الطلب'}
                        </button>
                        <button onClick={() => handleReject(req.id)} disabled={actionLoading === req.id} className="flex-1 bg-red-600 text-white py-2 rounded-lg font-semibold hover:bg-red-700 transition disabled:opacity-50">
                          {actionLoading === req.id ? 'جاري...' : '❌ رفض الطلب'}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {tab === 'myRequests' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">طلباتي</h1>
              {myRequests.length === 0 ? (
                <div className="bg-white rounded-xl shadow-sm p-12 text-center">
                  <div className="text-6xl mb-4"></div>
                  <h3 className="text-xl font-bold text-gray-900 mb-2">لا توجد طلبات</h3>
                  <p className="text-gray-600">ستظهر هنا الطلبات التي قبلتها.</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {myRequests.map((req: any) => (
                    <div key={req.id} className="bg-white border rounded-lg p-4 hover:shadow-md transition">
                      <div className="flex justify-between items-start mb-3">
                        <div className="flex items-center gap-3">
                          <div className="text-3xl">{req.category?.icon || '🔧'}</div>
                          <div>
                            <h3 className="font-bold text-gray-900">{req.category?.name || 'خدمة'}</h3>
                            <p className="text-sm text-gray-500">رقم الطلب: #{req.id}</p>
                          </div>
                        </div>
                        {getStatusBadge(req.status)}
                      </div>
                      <p className="text-gray-700 mb-3">{req.description}</p>
                      <div className="flex justify-between items-center text-sm text-gray-500 mb-4">
                        <span> {req.address}</span>
                        <span>{new Date(req.createdAt).toLocaleDateString('ar-KW')}</span>
                      </div>
                      <div className="p-3 bg-gray-50 rounded-lg mb-4">
                        <p className="text-sm text-gray-700">
                          <span className="font-semibold">العميل:</span> {req.client?.name}
                          <span className="mr-4">📞 {req.client?.phone}</span>
                        </p>
                      </div>

                      {/* ✅ عرض معلومات الدفع */}
                      {req.visitFeePaid && (
                        <div className="p-3 bg-green-50 rounded-lg mb-3 border border-green-200">
                          <p className="text-sm text-green-800 font-bold">✅ تم دفع دفعة الزيارة: 3 د.ك</p>
                        </div>
                      )}

                      {req.proposedPrice && (
                        <div className="p-3 bg-purple-50 rounded-lg mb-3 border border-purple-200">
                          <p className="text-sm text-purple-800 font-bold">💰 السعر المقترح: {req.proposedPrice} د.ك</p>
                          <p className="text-sm text-purple-700">المتبقي: {req.remainingAmount?.toFixed(3)} د.ك</p>
                        </div>
                      )}

                      {req.finalPrice && (
                        <div className="p-3 bg-green-50 rounded-lg mb-3 border border-green-200">
                          <p className="text-sm text-green-800 font-bold">💰 التكلفة النهائية: {req.finalPrice} د.ك</p>
                        </div>
                      )}
                      
                      {/* ✅ أزرار الإجراءات حسب الحالة */}
                      {req.status === 'accepted' && req.visitFeePaid && !req.proposedPrice && (
                        <button
                          onClick={() => setProposeModal(req)}
                          className="w-full bg-purple-600 text-white py-2.5 rounded-lg font-semibold hover:bg-purple-700 transition flex items-center justify-center gap-2"
                        >
                          💰 اقتراح السعر النهائي
                        </button>
                      )}

                      {req.status === 'accepted' && !req.visitFeePaid && (
                        <div className="p-3 bg-orange-50 rounded-lg border border-orange-200 text-center">
                          <p className="text-sm text-orange-800 font-bold">⏳ بانتظار دفع العميل لدفعة الزيارة (3 د.ك)</p>
                        </div>
                      )}

                      {req.status === 'pending_approval' && (
                        <div className="p-3 bg-purple-50 rounded-lg border border-purple-200 text-center">
                          <p className="text-sm text-purple-800 font-bold">⏳ بانتظار موافقة العميل على السعر</p>
                        </div>
                      )}
                      
                      {req.status === 'in_progress' && (
                        <button
                          onClick={() => setCompleteModal(req)}
                          disabled={actionLoading === req.id}
                          className="w-full bg-green-600 text-white py-2.5 rounded-lg font-semibold hover:bg-green-700 transition disabled:opacity-50 flex items-center justify-center gap-2"
                        >
                          {actionLoading === req.id ? 'جاري...' : '✅ إتمام العمل'}
                        </button>
                      )}
                      
                      {(req.status === 'completed' || req.status === 'paid') && (
                        <div className="p-3 bg-green-50 rounded-lg border border-green-200 text-center">
                          <p className="text-sm text-green-800 font-bold">✅ {req.status === 'paid' ? 'تم الدفع' : 'تم إتمام العمل - بانتظار الدفع'}</p>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {tab === 'earnings' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">الأرباح</h1>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
                <div className="bg-green-50 rounded-xl p-6 border border-green-200">
                  <p className="text-green-700 text-sm font-bold">إجمالي الأرباح</p>
                  <p className="text-3xl font-bold text-green-900 mt-2">
                    {earnings.reduce((sum: number, e: any) => sum + (parseFloat(e.amount) || 0), 0).toFixed(2)} د.ك
                  </p>
                </div>
                <div className="bg-blue-50 rounded-xl p-6 border border-blue-200">
                  <p className="text-blue-700 text-sm font-bold">عدد العمليات</p>
                  <p className="text-3xl font-bold text-blue-900 mt-2">{earnings.length}</p>
                </div>
              </div>
              <div className="bg-white rounded-xl shadow-sm p-6 border">
                <h2 className="text-xl font-bold text-gray-900 mb-4">سجل الأرباح</h2>
                {earnings.length === 0 ? (
                  <p className="text-gray-500 text-center py-8">لا توجد أرباح بعد</p>
                ) : (
                  <div className="space-y-3">
                    {earnings.map((earning: any, idx: number) => (
                      <div key={idx} className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
                        <div>
                          <p className="font-bold text-gray-900">{earning.description || 'ربح'}</p>
                          <p className="text-xs text-gray-500">{new Date(earning.createdAt).toLocaleDateString('ar-KW')}</p>
                        </div>
                        <p className="text-green-600 font-bold text-lg">{earning.amount} د.ك</p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {tab === 'chats' && (
            <div className="bg-white rounded-xl shadow-sm p-12 text-center">
              <div className="text-6xl mb-4">💬</div>
              <h3 className="text-xl font-bold text-gray-900 mb-2">المحادثات</h3>
              <p className="text-gray-600 mb-4">تواصل مع العملاء مباشرة</p>
              <Link href="/chat" className="inline-block bg-green-600 text-white px-6 py-3 rounded-lg font-bold hover:bg-green-700 transition">
                فتح المحادثات
              </Link>
            </div>
          )}

          {tab === 'documents' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">الوثائق</h1>
              <div className="bg-white rounded-xl shadow-sm p-6 border">
                {documents ? (
                  <div>
                    <div className="flex justify-between items-center mb-4">
                      <h2 className="text-xl font-bold text-gray-900">حالة الوثائق</h2>
                      <span className={`px-4 py-2 rounded-full text-sm font-bold ${
                        documents.status === 'approved' ? 'bg-green-100 text-green-800' :
                        documents.status === 'rejected' ? 'bg-red-100 text-red-800' :
                        'bg-yellow-100 text-yellow-800'
                      }`}>
                        {documents.status === 'approved' ? 'معتمدة' :
                         documents.status === 'rejected' ? 'مرفوضة' : 'قيد المراجعة'}
                      </span>
                    </div>
                    <div className="space-y-3">
                      <div className="p-3 bg-gray-50 rounded-lg">
                        <p className="text-sm text-gray-600">البطاقة المدنية</p>
                        <p className="font-bold text-gray-900">
                          {documents.civilIdUrl ? (
                            <a href={documents.civilIdUrl} target="_blank" className="text-blue-600 hover:underline">عرض</a>
                          ) : 'لم يتم الرفع'}
                        </p>
                      </div>
                      <div className="p-3 bg-gray-50 rounded-lg">
                        <p className="text-sm text-gray-600">الحساب البنكي</p>
                        <p className="font-bold text-gray-900">
                          {documents.bankAccountPhotoUrl ? (
                            <a href={documents.bankAccountPhotoUrl} target="_blank" className="text-blue-600 hover:underline">عرض</a>
                          ) : 'لم يتم الرفع'}
                        </p>
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="text-center py-8">
                    <p className="text-gray-600 mb-4">لم تقم برفع الوثائق بعد</p>
                    <Link href="/craftsman/documents" className="inline-block bg-green-600 text-white px-6 py-3 rounded-lg font-bold hover:bg-green-700 transition">
                      رفع الوثائق الآن
                    </Link>
                  </div>
                )}
              </div>
            </div>
          )}

          {tab === 'availability' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">حالة التوفر</h1>
              <div className="bg-white rounded-xl shadow-sm p-6 border">
                <div className="flex justify-between items-center mb-6">
                  <div>
                    <h2 className="text-xl font-bold text-gray-900">هل أنت متاح لاستقبال الطلبات؟</h2>
                    <p className="text-gray-600 mt-2">عندما تكون متاحاً، ستظهر لك الطلبات المناسبة</p>
                  </div>
                  <button
                    onClick={toggleAvailability}
                    className={`px-8 py-4 rounded-lg font-bold text-lg transition ${
                      availability ? 'bg-green-600 text-white hover:bg-green-700' : 'bg-red-600 text-white hover:bg-red-700'
                    }`}
                  >
                    {availability ? '🟢 متاح' : '🔴 غير متاح'}
                  </button>
                </div>
              </div>
            </div>
          )}

          {tab === 'changeProfession' && (
            <div className="bg-white rounded-xl shadow-sm p-12 text-center">
              <div className="text-6xl mb-4">🔄</div>
              <h3 className="text-xl font-bold text-gray-900 mb-2">تغيير المهنة</h3>
              <p className="text-gray-600 mb-4">هل تريد تغيير تخصصك؟</p>
              <Link href="/craftsman/change-profession" className="inline-block bg-green-600 text-white px-6 py-3 rounded-lg font-bold hover:bg-green-700 transition">
                طلب تغيير المهنة
              </Link>
            </div>
          )}
        </div>
      </main>

      {/* Modal اقتراح السعر */}
      {proposeModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full">
            <h3 className="text-xl font-bold text-gray-900 mb-4">💰 اقتراح السعر النهائي</h3>
            <p className="text-sm text-gray-600 mb-4">طلب رقم: #{proposeModal.id}</p>
            
            <div className="bg-purple-50 p-4 rounded-lg mb-4 border border-purple-200">
              <p className="text-sm text-purple-800 font-bold">💡 ملاحظة:</p>
              <p className="text-sm text-purple-700">دفعة الزيارة (3 د.ك) تم دفعها مسبقاً وستُخصم من الإجمالي.</p>
              <p className="text-sm text-purple-700 mt-2">مثال: إذا اقترحت 20 د.ك، سيدفع العميل 17 د.ك فقط.</p>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">السعر الإجمالي المقترح (د.ك) *</label>
                <input
                  type="number"
                  step="0.001"
                  min="3"
                  value={proposedPrice}
                  onChange={(e) => setProposedPrice(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 outline-none"
                  placeholder="مثال: 20.000"
                />
                {proposedPrice && parseFloat(proposedPrice) >= 3 && (
                  <p className="text-sm text-green-600 mt-2">
                    💰 المتبقي على العميل: {(parseFloat(proposedPrice) - 3).toFixed(3)} د.ك
                  </p>
                )}
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={handleProposePrice}
                disabled={actionLoading === proposeModal.id || !proposedPrice || parseFloat(proposedPrice) < 3}
                className="flex-1 bg-purple-600 hover:bg-purple-700 text-white py-3 rounded-lg font-bold transition disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {actionLoading === proposeModal.id ? 'جاري...' : '✅ إرسال الاقتراح'}
              </button>
              <button
                onClick={() => { setProposeModal(null); setProposedPrice(''); }}
                disabled={actionLoading === proposeModal.id}
                className="px-6 py-3 bg-gray-100 hover:bg-gray-200 rounded-lg font-bold text-gray-700 transition disabled:opacity-50"
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal إتمام العمل */}
      {completeModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full">
            <h3 className="text-xl font-bold text-gray-900 mb-4">✅ إتمام العمل</h3>
            <p className="text-sm text-gray-600 mb-4">طلب رقم: #{completeModal.id}</p>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">التكلفة النهائية (د.ك) - اختياري</label>
                <input
                  type="number"
                  step="0.01"
                  value={finalPrice}
                  onChange={(e) => setFinalPrice(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                  placeholder="مثال: 25.000"
                />
              </div>
              
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">ملاحظات العمل - اختياري</label>
                <textarea
                  value={workNotes}
                  onChange={(e) => setWorkNotes(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none resize-none"
                  rows={3}
                  placeholder="اكتب أي ملاحظات عن العمل المنجز..."
                />
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={handleCompleteWork}
                disabled={actionLoading === completeModal.id}
                className="flex-1 bg-blue-600 hover:bg-blue-700 text-white py-3 rounded-lg font-bold transition disabled:opacity-50"
              >
                {actionLoading === completeModal.id ? 'جاري...' : '✅ تأكيد الإتمام'}
              </button>
              <button
                onClick={() => { setCompleteModal(null); setFinalPrice(''); setWorkNotes(''); }}
                disabled={actionLoading === completeModal.id}
                className="px-6 py-3 bg-gray-100 hover:bg-gray-200 rounded-lg font-bold text-gray-700 transition disabled:opacity-50"
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
EOF

echo "✅ تم تحديث واجهة الحرفي"

# ═══════════════════════════════════════════════════════════════
# 🔟 إضافة متغيرات البيئة لـ MyFatoorah
# ═══════════════════════════════════════════════════════════════
echo "📝 تحديث ملف .env..."

# إضافة متغيرات MyFatoorah إذا لم تكن موجودة
if ! grep -q "MYFATOORAH_API_URL" .env; then
  cat << 'EOF' >> .env

# ═══════════════════════════════════════════════════════════════
# MyFatoorah Payment Gateway
# ═══════════════════════════════════════════════════════════════
# استخدم رابط الاختبار للتطوير، والرابط الحقيقي للإنتاج
MYFATOORAH_API_URL=https://apitest.myfatoorah.com
# MYFATOORAH_API_URL=https://api.myfatoorah.com

# احصل على التوكن من لوحة تحكم MyFatoorah
MYFATOORAH_TOKEN=

# رابط التطبيق (مهم للـ Callback)
NEXT_PUBLIC_APP_URL=http://localhost:3000
EOF
  echo "✅ تم إضافة متغيرات MyFatoorah إلى .env"
else
  echo "⚠️  متغيرات MyFatoorah موجودة مسبقاً"
fi

# ═══════════════════════════════════════════════════════════════
# 1️⃣1️⃣ حفظ التغييرات
# ═══════════════════════════════════════════════════════════════
echo "📦 حفظ التغييرات..."
git add -A
git commit -m "feat: نظام الدفع المتكامل مع MyFatoorah

- دفعة زيارة ثابتة (3 د.ك) تُدفع عبر MyFatoorah
- اقتراح السعر من الحرفي بعد دفع دفعة الزيارة
- موافقة/رفض العميل على السعر المقترح
- الدفع النهائي للمتبقي فقط
- Webhook تلقائي لتأكيد الدفع
- model PaymentTransaction لتتبع العمليات
- وضع اختبار يعمل بدون مفتاح MyFatoorah
- إشعارات لكل مرحلة من مراحل الدفع"

echo ""
echo "=========================================="
echo "✅ تم التنفيذ بنجاح!"
echo "=========================================="
echo ""
echo "📋 التدفق الجديد الكامل:"
echo "1. العميل ينشئ طلب → pending"
echo "2. الحرفي يقبل → accepted"
echo "3. العميل يدفع دفعة الزيارة (3 د.ك) عبر MyFatoorah → pending_payment"
echo "4. الحرفي يقترح السعر النهائي → pending_approval"
echo "5. العميل يوافق → in_progress (يُخصم 3 د.ك من الإجمالي)"
echo "6. الحرفي يبدأ العمل → in_progress"
echo "7. الحرفي يتمم العمل → completed"
echo "8. العميل يدفع المتبقي عبر MyFatoorah → paid"
echo "9. العميل يقيّم الحرفي"
echo ""
echo "⚙️  لإعداد MyFatoorah:"
echo "1. سجّل في https://myfatoorah.com"
echo "2. احصل على API Token من لوحة التحكم"
echo "3. أضفه في ملف .env: MYFATOORAH_TOKEN=your_token_here"
echo ""
echo " للاختبار المحلي:"
echo "- النظام يعمل في وضع الاختبار بدون مفتاح MyFatoorah"
echo "- سيتم توجيهك لصفحة نجاح وهمية"
echo ""
echo "🚀 جاهز للاختبار!"
