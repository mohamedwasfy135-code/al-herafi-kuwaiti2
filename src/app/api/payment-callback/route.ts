import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const paymentId = searchParams.get('paymentId') || searchParams.get('id');
    const status = searchParams.get('status') || 'success';
    
    if (!paymentId) {
      return NextResponse.redirect(new URL('/payment/failed', request.url));
    }

    const transaction = await db.paymentTransaction.findFirst({
      where: { paymentId },
      include: { request: true }
    });

    if (!transaction) {
      return NextResponse.redirect(new URL('/payment/failed', request.url));
    }

    if (status === 'success') {
      let updateData: any = { paymentStatus: 'paid' };
      
      if (transaction.type === 'visit_fee') {
        updateData.visitFeePaid = true;
        updateData.status = 'in_progress';
      } else if (transaction.type === 'final_payment') {
        updateData.status = 'paid';
      }
      
      await db.request.update({
        where: { id: transaction.request.id },
        data: updateData
      });

      await db.paymentTransaction.update({
        where: { id: transaction.id },
        data: { status: 'paid', updatedAt: new Date() }
      });
      
      const redirectUrl = transaction.type === 'visit_fee' 
        ? '/dashboard/client?msg=visit_fee_paid' 
        : '/dashboard/client?msg=final_payment_paid';

      return NextResponse.redirect(new URL(redirectUrl, request.url));
    } else {
      return NextResponse.redirect(new URL('/payment/failed', request.url));
    }
  } catch (error) {
    console.error('Callback Error:', error);
    return NextResponse.redirect(new URL('/payment/failed', request.url));
  }
}
