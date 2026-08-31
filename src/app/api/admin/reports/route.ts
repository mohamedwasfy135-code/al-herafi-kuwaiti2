import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { requireAdmin } from '@/lib/admin-auth';

export async function GET(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) return authResult;

    const { searchParams } = new URL(request.url);
    const days = parseInt(searchParams.get('days') || '30');
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    // 1. التقارير المالية
    const [platformFees, craftsmanEarnings, subscriptionRevenue] = await Promise.all([
      prisma.request.aggregate({
        where: { status: { in: ['completed', 'paid'] }, createdAt: { gte: startDate } },
        _sum: { platformFee: true }
      }),
      prisma.request.aggregate({
        where: { status: { in: ['completed', 'paid'] }, createdAt: { gte: startDate } },
        _sum: { craftsmanEarnings: true }
      }),
      prisma.subscriptionPayment.aggregate({
        where: { status: 'paid', createdAt: { gte: startDate } },
        _sum: { amount: true }
      })
    ]);

    // 2. تقارير الطلبات (حسب الحالة والمدينة)
    const requestsByStatus = await prisma.request.groupBy({
      by: ['status'],
      _count: { id: true },
      where: { createdAt: { gte: startDate } }
    });

    const requestsByCity = await prisma.request.groupBy({
      by: ['city', 'governorate'],
      _count: { id: true },
      where: { createdAt: { gte: startDate }, city: { not: null } },
      orderBy: { _count: { id: 'desc' } },
      take: 5
    });

    // 3. تقارير الأداء (أفضل الحرفيين)
    const topCraftsmen = await prisma.user.findMany({
      where: { 
        role: 'craftsman', 
        craftsmanRequests: { some: { status: { in: ['completed', 'paid'] }, createdAt: { gte: startDate } } } 
      },
      select: {
        id: true,
        name: true,
        rating: true,
        _count: {
          select: {
            craftsmanRequests: {
              where: { status: { in: ['completed', 'paid'] }, createdAt: { gte: startDate } }
            }
          }
        }
      },
      orderBy: {
        craftsmanRequests: {
          _count: 'desc'
        }
      },
      take: 5
    });

    // 4. تقارير المستخدمين والاشتراكات
    const [activeCraftsmen, expiredCraftsmen, totalClients] = await Promise.all([
      prisma.user.count({ where: { role: 'craftsman', subscriptionStatus: 'active' } }),
      prisma.user.count({ where: { role: 'craftsman', subscriptionStatus: { in: ['expired', 'inactive'] } } }),
      prisma.user.count({ where: { role: 'client' } })
    ]);

    return NextResponse.json({
      success: true,
      data: {
        financials: {
          platformFees: platformFees._sum.platformFee || 0,
          craftsmanEarnings: craftsmanEarnings._sum.craftsmanEarnings || 0,
          subscriptionRevenue: subscriptionRevenue._sum.amount || 0,
          totalRevenue: (platformFees._sum.platformFee || 0) + (subscriptionRevenue._sum.amount || 0)
        },
        requests: {
          byStatus: requestsByStatus,
          byCity: requestsByCity
        },
        performance: {
          topCraftsmen: topCraftsmen.map(c => ({
            name: c.name,
            rating: c.rating,
            completedRequests: c._count.craftsmanRequests
          }))
        },
        users: {
          activeCraftsmen,
          expiredCraftsmen,
          totalClients
        }
      }
    });
  } catch (error: any) {
    console.error('GET admin/reports error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
