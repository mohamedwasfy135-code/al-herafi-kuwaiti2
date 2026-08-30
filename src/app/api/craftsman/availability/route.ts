import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSessionFromRequest } from '@/lib/auth';

export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const user = await prisma.user.findUnique({
      where: { id: session.userId },
      select: { is_available: true, unavailable_until: true },
    });

    return NextResponse.json({ 
      success: true, 
      isAvailable: user?.is_available ?? true,
      unavailableUntil: user?.unavailable_until 
    });
  } catch (error: any) {
    console.error('GET availability error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { isAvailable } = await request.json();

    await prisma.user.update({
      where: { id: session.userId },
      data: { 
        is_available: isAvailable,
        unavailable_until: isAvailable ? null : undefined,
      },
    });

    return NextResponse.json({ success: true, isAvailable });
  } catch (error: any) {
    console.error('POST availability error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
