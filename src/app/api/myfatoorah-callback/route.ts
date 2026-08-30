import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    
    // طباعة كل شيء تصل إليه من ماي فاتورة للتأكد 100%
    console.log('📥 [Callback] جميع البيانات المستلمة من ماي فاتورة:');
    searchParams.forEach((value, key) => {
      console.log(`   -> ${key}: "${value}"`);
    });

    // ماي فاتورة ترسل عادة الرقم الطويل (InvoiceId) داخل معامل اسمه paymentId أو InvoiceId
    const incomingId = searchParams.get('paymentId') || searchParams.get('InvoiceId') || searchParams.get('id');
    const status = searchParams.get('status');

    console.log(`\n🔍 الرقم المستهدف للبحث: "${incomingId}"`);
    console.log(`🔍 الحالة المستلمة: "${status}"`);

    if (!incomingId) {
      console.error('❌ لم يتم استلام أي معرف للفاتورة من ماي فاتورة');
      return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
    }

    // البحث الذكي: نبحث عن هذا الرقم في حقل invoiceId أولاً، ثم paymentId
    console.log('\n🔎 جاري البحث في قاعدة البيانات...');
    const transaction = await db.paymentTransaction.findFirst({
      where: {
        OR: [
          { invoiceId: String(incomingId) },
          { paymentId: String(incomingId) }
        ]
      },
      include: { request: true }
    });

    if (!transaction) {
      console.error(`❌ فشل البحث! لم يتم العثور على معاملة بالرقم: "${incomingId}"`);
      
      // للمساعدة في التصحيح، نعرض آخر 3 معاملات محفوظة
      const recentTx = await db.paymentTransaction.findMany({
        orderBy: { createdAt: 'desc' },
        take: 3,
        select: { id: true, invoiceId: true, paymentId: true, requestId: true }
      });
      console.log('📋 آخر 3 معاملات في قاعدة البيانات:');
      recentTx.forEach(tx => {
        console.log(`   - ID: ${tx.id} | invoiceId: "${tx.invoiceId}" | paymentId: "${tx.paymentId}"`);
      });

      return NextResponse.redirect(new URL('/dashboard/client?msg=transaction_not_found', request.url));
    }

    console.log('\n✅ تم العثور على المعاملة بنجاح!');
    console.log(`   - معرف المعاملة: ${transaction.id}`);
    console.log(`   - نوع الدفع: ${transaction.type}`);
    console.log(`   - رقم الطلب: ${transaction.requestId}`);

    // تحديث الحالة إذا كان الدفع ناجحاً ولم يتم الدفع مسبقاً
    if (status?.toLowerCase() === 'success' && transaction.status !== 'paid') {
      const updateData: any = { paymentStatus: 'paid' };
      
      if (transaction.type === 'visit_fee') {
        updateData.visitFeePaid = true;
        updateData.status = 'in_progress';
      } else if (transaction.type === 'final_payment') {
        updateData.status = 'paid';
      }

      await db.$transaction([
        db.request.update({
          where: { id: transaction.requestId },
          data: updateData
        }),
        db.paymentTransaction.update({
          where: { id: transaction.id },
          data: { 
            status: 'paid', 
            paidAt: new Date(),
            updatedAt: new Date() 
          }
        })
      ]);

      console.log('🎉 تم تحديث حالة الطلب والمعاملة إلى "مدفوع" بنجاح!');
    }

    const msg = status?.toLowerCase() === 'success' 
      ? (transaction.type === 'visit_fee' ? 'visit_fee_paid' : 'final_payment_paid')
      : 'payment_failed';
      
    return NextResponse.redirect(new URL(`/dashboard/client?msg=${msg}`, request.url));

  } catch (error: any) {
    console.error('💥 خطأ فادح وغير متوقع في Callback:', error);
    return NextResponse.redirect(new URL('/dashboard/client?msg=callback_error', request.url));
  }
}
