import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSessionFromRequest } from '@/lib/auth';

export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    // جلب الحرفي مع تخصصه وموقعه
    const craftsman = await prisma.user.findUnique({
      where: { id: session.userId },
      select: { categoryId: true, latitude: true, longitude: true },
    });

    if (!craftsman || !craftsman.categoryId) {
      return NextResponse.json({ requests: [] });
    }

    // جلب الطلبات المتاحة (نفس التخصص، حالة pending أو bidding، ولم يتم إسنادها لهذا الحرفي)
    const requests = await prisma.request.findMany({
      where: {
        categoryId: craftsman.categoryId,
        status: { in: ['pending', 'bidding'] },
        craftsmanId: null, // لم يتم إسنادها بعد
      },
      include: {
        client: { select: { name: true, phone: true } },
        category: { select: { name: true, icon: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    return NextResponse.json({ success: true, requests });
  } catch (error: any) {
    console.error('GET bidding-requests error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
