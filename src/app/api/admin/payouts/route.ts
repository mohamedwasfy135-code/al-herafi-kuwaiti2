import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { requireAdmin } from '@/lib/admin-auth';

export async function GET(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) return authResult;

    const payouts = await prisma.payoutRequest.findMany({
      include: {
        craftsman: { select: { name: true, phone: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return NextResponse.json({ success: true, payouts });
  } catch (error: any) {
    console.error('GET payouts error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}

export async function PUT(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) return authResult;

    const { payoutId, status } = await request.json();
    if (!payoutId || !['pending', 'approved', 'rejected', 'completed'].includes(status)) {
      return NextResponse.json({ error: 'بيانات غير صالحة' }, { status: 400 });
    }

    const payout = await prisma.payoutRequest.update({
      where: { id: payoutId },
      data: { status },
    });

    return NextResponse.json({ success: true, payout });
  } catch (error: any) {
    console.error('PUT payouts error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
