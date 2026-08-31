import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'admin') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    // 1. جلب الطلبات المكتملة والمدفوعة لحساب الإجماليات
    const completedRequests = await db.request.findMany({
      where: {
        status: { in: ['completed', 'paid'] },
      },
      select: {
        id: true,
        finalPrice: true,
        platformFee: true,
        craftsmanEarnings: true,
        craftsman: {
          select: { name: true, phone: true }
        },
        updatedAt: true,
      },
      orderBy: { updatedAt: 'desc' },
      take: 100, // آخر 100 طلب للتفاصيل
    });

    let totalPlatformFee = 0;
    let totalCraftsmanEarnings = 0;

    const detailedEarnings = completedRequests.map(req => {
      // ✅ حساب احتياطي آمن للطلبات القديمة التي لا تملك الحقول الجديدة
      const pFee = req.platformFee ?? (req.finalPrice ? Math.round(req.finalPrice * 0.10 * 1000) / 1000 : 0);
      const cEarn = req.craftsmanEarnings ?? (req.finalPrice ? Math.round((req.finalPrice - pFee) * 1000) / 1000 : 0);
      
      totalPlatformFee += pFee;
      totalCraftsmanEarnings += cEarn;

      return {
        id: req.id,
        finalPrice: req.finalPrice || 0,
        platformFee: pFee,
        craftsmanEarnings: cEarn,
        craftsmanName: req.craftsman?.name || 'غير مسند',
        craftsmanPhone: req.craftsman?.phone || '-',
        completedAt: req.updatedAt,
      };
    });

    // 2. حساب إجمالي طلبات السحب المعلقة
    const pendingPayouts = await db.payoutRequest.findMany({
      where: { status: 'pending' },
      select: { amount: true }
    });
    const totalPendingPayouts = pendingPayouts.reduce((sum, p) => sum + (p.amount || 0), 0);

    return NextResponse.json({
      success: true,
      summary: {
        totalPlatformFee: Math.round(totalPlatformFee * 1000) / 1000,
        totalCraftsmanEarnings: Math.round(totalCraftsmanEarnings * 1000) / 1000,
        totalPendingPayouts: Math.round(totalPendingPayouts * 1000) / 1000,
        totalCompletedRequests: completedRequests.length
      },
      details: detailedEarnings
    });
  } catch (error: any) {
    console.error('GET admin/financials error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
