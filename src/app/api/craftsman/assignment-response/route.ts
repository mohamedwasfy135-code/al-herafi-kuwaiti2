import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح - يجب تسجيل الدخول كحرفي' }, { status: 401 });
    }

    const body = await request.json();
    const { requestId, action, rejectionReason } = body;

    if (!requestId || !action) {
      return NextResponse.json({ error: 'رقم الطلب والإجراء مطلوبان' }, { status: 400 });
    }

    if (!['accept', 'reject'].includes(action)) {
      return NextResponse.json({ error: 'الإجراء يجب أن يكون accept أو reject' }, { status: 400 });
    }

    const req = await db.request.findUnique({
      where: { id: requestId },
      include: { client: true }
    });

    if (!req) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 });
    }

    if (req.craftsmanId && req.craftsmanId !== session.userId) {
      return NextResponse.json({ error: 'هذا الطلب مسند لحرفي آخر بالفعل' }, { status: 409 });
    }

    if (req.status === 'completed' || req.status === 'cancelled') {
      return NextResponse.json({ error: 'لا يمكن التعامل مع طلب مكتمل أو ملغي' }, { status: 400 });
    }

    if (action === 'accept') {
      await db.request.update({
        where: { id: requestId },
        data: {
          craftsmanId: session.userId,
          status: 'accepted',
          updatedAt: new Date(),
        },
      });

      const existingAssignment = await db.requestAssignment.findFirst({
        where: { requestId, craftsmanId: session.userId }
      });

      if (existingAssignment) {
        await db.requestAssignment.update({
          where: { id: existingAssignment.id },
          data: {
            status: 'accepted',
            respondedAt: new Date(),
          },
        });
      } else {
        await db.requestAssignment.create({
          data: {
            requestId: requestId,
            craftsmanId: session.userId,
            status: 'accepted',
            respondedAt: new Date(),
            expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
          },
        });
      }

      // ✅ إزالة relatedId من الإشعارات
      await db.notification.create({
        data: {
          userId: req.clientId,
          title: '✅ تم قبول طلبك',
          body: `قام الحرفي بقبول طلبك رقم #${requestId}. سيتم التواصل معك قريباً.`,
          type: 'request_accepted',
        },
      });

      await db.notification.create({
        data: {
          userId: session.userId,
          title: '🎉 تم قبول الطلب',
          body: `قبلت طلب العميل ${req.client?.name || ''}. تواصل معه الآن.`,
          type: 'assignment_accepted',
        },
      });

      return NextResponse.json({ 
        success: true, 
        message: 'تم قبول الطلب بنجاح! تم إشعار العميل.' 
      }, { status: 200 });

    } else {
      const existingAssignment = await db.requestAssignment.findFirst({
        where: { requestId, craftsmanId: session.userId }
      });

      if (existingAssignment) {
        await db.requestAssignment.update({
          where: { id: existingAssignment.id },
          data: {
            status: 'rejected',
            respondedAt: new Date(),
            rejectionReason: rejectionReason || 'رفض من الحرفي',
          },
        });
      } else {
        await db.requestAssignment.create({
          data: {
            requestId: requestId,
            craftsmanId: session.userId,
            status: 'rejected',
            respondedAt: new Date(),
            rejectionReason: rejectionReason || 'رفض من الحرفي',
            expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
          },
        });
      }

      const adminUsers = await db.user.findMany({
        where: { role: 'admin' },
        select: { id: true }
      });

      for (const admin of adminUsers) {
        // ✅ إزالة relatedId من الإشعارات
        await db.notification.create({
          data: {
            userId: admin.id,
            title: '⚠️ طلب يحتاج تدخلاً',
            body: `رفض الحرفي الطلب رقم #${requestId}. السبب: ${rejectionReason || 'غير محدد'}`,
            type: 'admin_intervention',
          },
        });
      }

      return NextResponse.json({ 
        success: true, 
        message: 'تم رفض الطلب وتسجيل السبب. سيتم إشعار الأدمن للتدخل.',
        reassigned: false
      }, { status: 200 });
    }

  } catch (error: any) {
    console.error('❌ خطأ في POST /api/craftsman/assignment-response:', error);
    return NextResponse.json({ error: error.message || 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
