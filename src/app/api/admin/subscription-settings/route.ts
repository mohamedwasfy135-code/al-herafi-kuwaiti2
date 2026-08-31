import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'admin') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const setting = await db.appSettings.findUnique({ where: { key: 'subscription_fee' } });
    const fee = setting ? parseFloat(setting.value) : 5.0;

    const activeCraftsmen = await db.user.count({
      where: { role: 'craftsman', subscriptionStatus: 'active' }
    });
    const expiredCraftsmen = await db.user.count({
      where: { role: 'craftsman', subscriptionStatus: { in: ['expired', 'inactive'] } }
    });
    const totalRevenue = await db.subscriptionPayment.aggregate({
      where: { status: 'paid' },
      _sum: { amount: true }
    });

    return NextResponse.json({
      success: true,
      fee,
      stats: {
        activeCraftsmen,
        expiredCraftsmen,
        totalRevenue: totalRevenue._sum.amount || 0
      }
    });
  } catch (error: any) {
    console.error('GET admin/subscription-settings error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}

export async function PUT(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'admin') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { fee } = await request.json();
    const newFee = parseFloat(fee);

    if (isNaN(newFee) || newFee <= 0) {
      return NextResponse.json({ error: 'قيمة الاشتراك غير صالحة' }, { status: 400 });
    }

    await db.appSettings.upsert({
      where: { key: 'subscription_fee' },
      update: { value: String(newFee) },
      create: { key: 'subscription_fee', value: String(newFee) }
    });

    return NextResponse.json({ success: true, fee: newFee });
  } catch (error: any) {
    console.error('PUT admin/subscription-settings error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
