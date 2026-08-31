import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSessionFromRequest } from '@/lib/auth';

export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const payouts = await prisma.payoutRequest.findMany({
      where: { craftsmanId: session.userId },
      orderBy: { createdAt: 'desc' },
    });

    return NextResponse.json({ success: true, payouts });
  } catch (error: any) {
    console.error('GET payout-request error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { amount } = await request.json();
    const requestedAmount = parseFloat(amount);

    if (!requestedAmount || requestedAmount <= 0) {
      return NextResponse.json({ error: 'المبلغ غير صالح' }, { status: 400 });
    }

    // ✅ إعادة حساب الرصيد المتاح على السيرفر (ما نثق بأي رقم يجي من الواجهة)
    const completedRequests = await prisma.request.findMany({
      where: {
        craftsmanId: session.userId,
        status: { in: ['completed', 'paid'] },
      },
      select: { finalPrice: true, agreedPrice: true, craftsmanEarnings: true },
    });
    // ✅ استخدام craftsmanEarnings إن وُجد، وإلا حساب 90% احتياطياً
    const totalEarnings = completedRequests.reduce(
      (sum, r) => sum + (r.craftsmanEarnings || ((r.finalPrice || r.agreedPrice || 0) * 0.90)), 0
    );

    const existingPayouts = await prisma.payoutRequest.findMany({
      where: {
        craftsmanId: session.userId,
        status: { in: ['pending', 'approved', 'completed'] },
      },
    });
    const alreadyRequested = existingPayouts.reduce((sum, p) => sum + (p.amount || 0), 0);
    const availableBalance = Math.max(totalEarnings - alreadyRequested, 0);

    if (requestedAmount > availableBalance) {
      return NextResponse.json({
        error: `المبلغ المطلوب أكبر من رصيدك المتاح (${availableBalance.toFixed(3)} د.ك)`
      }, { status: 400 });
    }

    const payout = await prisma.payoutRequest.create({
      data: {
        craftsmanId: session.userId,
        amount: requestedAmount,
        status: 'pending',
      },
    });

    return NextResponse.json({ success: true, payout });
  } catch (error: any) {
    console.error('POST payout-request error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
