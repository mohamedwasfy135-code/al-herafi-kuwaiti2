import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSessionFromRequest } from '@/lib/auth';

export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    // ✅ الحالات الصحيحة الفعلية: completed أو paid (مو 'done')
    const completedRequests = await prisma.request.findMany({
      where: {
        craftsmanId: session.userId,
        status: { in: ['completed', 'paid'] },
      },
      select: {
        id: true,
        finalPrice: true,
        agreedPrice: true,
        platformFee: true,
        craftsmanEarnings: true,
        serviceType: true,
        updatedAt: true,
      },
      orderBy: { updatedAt: 'desc' },
    });

    const earnings = completedRequests.map(req => ({
      id: req.id,
      amount: req.craftsmanEarnings || ((req.finalPrice || req.agreedPrice || 0) * 0.90),
      description: req.serviceType || 'خدمة مكتملة',
      createdAt: req.updatedAt,
    }));

    // ✅ حساب الرصيد المتاح للسحب = إجمالي الأرباح ناقص طلبات السحب (المعلقة/الموافق عليها/المكتملة)
    const totalEarnings = earnings.reduce((sum, e) => sum + (e.amount || 0), 0);

    const payoutRequests = await prisma.payoutRequest.findMany({
      where: {
        craftsmanId: session.userId,
        status: { in: ['pending', 'approved', 'completed'] },
      },
    });
    const alreadyRequested = payoutRequests.reduce((sum, p) => sum + (p.amount || 0), 0);
    const availableBalance = Math.max(totalEarnings - alreadyRequested, 0);

    return NextResponse.json({ success: true, earnings, totalEarnings, availableBalance });
  } catch (error: any) {
    console.error('GET earnings error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
