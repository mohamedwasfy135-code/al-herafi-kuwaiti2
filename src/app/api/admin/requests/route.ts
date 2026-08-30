import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { requireAdmin } from '@/lib/admin-auth';

export async function GET(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) return authResult;

    const requests = await prisma.request.findMany({
      include: {
        client: {
          select: { name: true, phone: true, email: true },
        },
        craftsman: {
          select: { name: true, phone: true, rating: true },
        },
        category: {
          select: { name: true, icon: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    return NextResponse.json({ success: true, requests });
  } catch (error: any) {
    console.error('GET requests error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
