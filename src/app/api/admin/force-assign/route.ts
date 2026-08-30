import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { requireAdmin } from '@/lib/admin-auth';

export async function POST(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) return authResult;
    const admin = authResult;

    const { requestId, craftsmanId } = await request.json();
    if (!requestId || !craftsmanId) {
      return NextResponse.json({ error: 'requestId و craftsmanId مطلوبان' }, { status: 400 });
    }

    // حذف الإسنادات السابقة
    await prisma.requestAssignment.deleteMany({
      where: { requestId },
    });

    // إنشاء إسناد جديد
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000); // 30 دقيقة
    const assignment = await prisma.requestAssignment.create({
      data: {
        requestId,
        craftsmanId,
        status: 'pending',
        expiresAt,
      },
    });

    // تحديث الطلب
    await prisma.request.update({
      where: { id: requestId },
      data: {
        craftsmanId,
        status: 'bidding',
        currentAssignmentId: assignment.id,
      },
    });

    // إشعار الحرفي
    await prisma.notification.create({
      data: {
        userId: craftsmanId,
        title: '📢 طلب تسعير جديد',
        body: `تم إسناد طلب رقم ${requestId} إليك للتسعير`,
        type: 'bid_request',
      },
    });

    // تسجيل في AuditLog
    await prisma.auditLog.create({
      data: {
        businessId: 'system',
        userId: admin.userId,
        action: 'force_assign',
        entity: 'Request',
        entityId: requestId,
        changes: { craftsmanId, assignmentId: assignment.id },
      },
    });

    return NextResponse.json({ success: true, assignmentId: assignment.id });
  } catch (error: any) {
    console.error('Force assign error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
