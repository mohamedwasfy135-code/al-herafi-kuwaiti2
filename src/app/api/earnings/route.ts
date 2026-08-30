import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSessionFromRequest } from '@/lib/auth';

export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    // جلب الأرباح من BusinessTransaction (إذا كان هناك نظام أعمال مرتبط)
    // أو من الطلبات المكتملة
    const completedRequests = await prisma.request.findMany({
      where: {
        craftsmanId: session.userId,
        status: 'done',
      },
      select: {
        id: true,
        finalPrice: true,
        agreedPrice: true,
        serviceType: true,
        updatedAt: true,
      },
      orderBy: { updatedAt: 'desc' },
    });

    // تحويل البيانات إلى صيغة الأرباح
    const earnings = completedRequests.map(req => ({
      id: req.id,
      amount: req.finalPrice || req.agreedPrice || 0,
      description: req.serviceType || 'خدمة مكتملة',
      createdAt: req.updatedAt,
    }));

    return NextResponse.json({ success: true, earnings });
  } catch (error: any) {
    console.error('GET earnings error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
