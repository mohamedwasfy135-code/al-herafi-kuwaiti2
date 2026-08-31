import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const payments = await db.subscriptionPayment.findMany({
      where: { userId: session.userId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        amount: true,
        status: true,
        startDate: true,
        endDate: true,
        createdAt: true,
      }
    });

    return NextResponse.json({ success: true, payments });
  } catch (error: any) {
    console.error('GET subscription/history error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
