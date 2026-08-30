import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { requireAdmin } from '@/lib/admin-auth';

export async function GET(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) return authResult;

    const craftsmen = await prisma.user.findMany({
      where: {
        role: 'craftsman',
        verification_status: 'pending',
      },
      select: {
        id: true,
        name: true,
        phone: true,
        categoryId: true,
        category: { select: { name: true } },
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    return NextResponse.json({ success: true, requests: craftsmen });
  } catch (error: any) {
    console.error('GET change-requests error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}

export async function PUT(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) return authResult;
    const admin = authResult;

    const { craftsmanId, newCategoryId, action } = await request.json();
    if (!craftsmanId || !newCategoryId || !['approve', 'reject'].includes(action)) {
      return NextResponse.json({ error: 'بيانات غير صالحة' }, { status: 400 });
    }

    if (action === 'approve') {
      await prisma.user.update({
        where: { id: craftsmanId },
        data: {
          categoryId: newCategoryId,
          verification_status: 'approved',
        },
      });

      await prisma.service.deleteMany({
        where: { craftsmanId },
      });

      const category = await prisma.category.findUnique({ where: { id: newCategoryId } });
      if (category) {
        await prisma.service.create({
          data: {
            craftsmanId,
            categoryId: newCategoryId,
            title: category.name,
            description: `خدمة في تخصص ${category.name}`,
            price: 0,
            isActive: true,
          },
        });
      }

      await prisma.auditLog.create({
        data: {
          businessId: 'system',
          userId: admin.userId,
          action: 'approve_profession_change',
          entity: 'User',
          changes: { craftsmanId, newCategoryId },
        },
      });
    } else {
      await prisma.user.update({
        where: { id: craftsmanId },
        data: { verification_status: 'rejected' },
      });
    }

    return NextResponse.json({ success: true });
  } catch (error: any) {
    console.error('PUT change-requests error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
