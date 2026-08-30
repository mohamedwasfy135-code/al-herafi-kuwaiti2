import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { requireAdmin } from '@/lib/admin-auth';

export async function POST(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) return authResult;
    const admin = authResult;

    const { requestId, newCraftsmanId, oldCraftsmanId } = await request.json();
    if (!requestId || !newCraftsmanId) {
      return NextResponse.json({ error: 'requestId و newCraftsmanId مطلوبان' }, { status: 400 });
    }

    // حذف الإسنادات السابقة
    await prisma.requestAssignment.deleteMany({
      where: { requestId },
    });

    // إنشاء إسناد جديد
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000);
    const assignment = await prisma.requestAssignment.create({
      data: {
        requestId,
        craftsmanId: newCraftsmanId,
        status: 'pending',
        expiresAt,
      },
    });

    // تحديث الطلب
    await prisma.request.update({
      where: { id: requestId },
      data: {
        craftsmanId: newCraftsmanId,
        status: 'bidding',
        currentAssignmentId: assignment.id,
      },
    });

    // إشعار الحرفي الجديد
    await prisma.notification.create({
      data: {
        userId: newCraftsmanId,
        title: '📢 طلب تسعير جديد',
        body: `تم إسناد طلب رقم ${requestId} إليك للتسعير`,
        type: 'bid_request',
      },
    });

    // إشعار الحرفي القديم (إذا كان موجوداً)
    if (oldCraftsmanId) {
      await prisma.notification.create({
        data: {
          userId: oldCraftsmanId,
          title: '⚠️ تم سحب الطلب',
          body: `تم إعادة إسناد الطلب رقم ${requestId} إلى حرفي آخر`,
          type: 'reassign',
        },
      });
    }

    // تسجيل في AuditLog
    await prisma.auditLog.create({
      data: {
        businessId: 'system',
        userId: admin.userId,
        action: 'reassign_request',
        entity: 'Request',
        entityId: requestId,
        changes: { oldCraftsmanId, newCraftsmanId, assignmentId: assignment.id },
      },
    });

    return NextResponse.json({ success: true, message: 'تم إعادة الإسناد بنجاح' });
  } catch (error: any) {
    console.error('Reassign error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
