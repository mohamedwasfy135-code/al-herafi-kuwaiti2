import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { requireAdmin } from '@/lib/admin-auth';

export async function GET(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) {
      return authResult;
    }

    const [usersCount, requestsCount, pendingCraftsmenCount] = await Promise.all([
      prisma.user.count(),
      prisma.request.count(),
      prisma.user.count({
        where: {
          role: 'craftsman',
          verification_status: 'pending',
        },
      }),
    ]);

    const revenueResult = await prisma.businessTransaction.aggregate({
      where: {
        type: 'income',
      },
      _sum: {
        amount: true,
      },
    });

    const totalRevenue = revenueResult._sum.amount || 0;

    return NextResponse.json({
      success: true,
      stats: {
        users: usersCount,
        requests: requestsCount,
        revenue: totalRevenue,
        pendingCraftsmen: pendingCraftsmenCount,
      },
    });
  } catch (error: any) {
    console.error('خطأ في /api/admin/stats:', error);
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    );
  }
}
