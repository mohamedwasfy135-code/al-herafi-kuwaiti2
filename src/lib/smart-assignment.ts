import { prisma } from './prisma';

// ═══════════════════════════════════════════════════════════════
// خوارزمية الإسناد الذكي - الحرفي الأعلى تقييماً ضمن 40 كم
// ═══════════════════════════════════════════════════════════════

const MAX_DISTANCE_KM = 40;
const ASSIGNMENT_EXPIRY_MINUTES = 5;

/**
 * حساب المسافة بين نقطتين جغرافيتين باستخدام معادلة Haversine
 * @returns المسافة بالكيلومترات
 */
function calculateDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // نصف قطر الأرض بالكيلومترات
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg: number): number {
  return deg * (Math.PI / 180);
}

/**
 * بدء عملية الإسناد الذكي لطلب
 * @param requestId رقم الطلب المراد إسناد
 * @returns نتيجة الإسناد (الحرفي المختار أو حالة الفشل)
 */
export async function startSmartAssignment(requestId: number) {
  try {
    // 1. جلب بيانات الطلب مع موقع العميل
    const request = await prisma.request.findUnique({
      where: { id: requestId },
      include: {
        client: {
          select: {
            id: true,
            latitude: true,
            longitude: true,
          },
        },
        assignments: {
          select: {
            craftsmanId: true,
            status: true,
          },
        },
      },
    });

    if (!request) {
      throw new Error('الطلب غير موجود');
    }

    if (request.status !== 'pending' && request.status !== 'craftsman_rejected') {
      throw new Error('حالة الطلب لا تسمح بالإسناد');
    }

    if (!request.client.latitude || !request.client.longitude) {
      throw new Error('موقع العميل غير متوفر');
    }

    if (!request.categoryId) {
      throw new Error('التصنيف غير محدد للطلب');
    }

    const clientLat = request.client.latitude;
    const clientLon = request.client.longitude;

    // 2. جلب الحرفيين المرشحين (نفس التصنيف، متاحين، لم يتم رفضهم سابقاً)
    const rejectedCraftsmanIds = request.assignments
      .filter(a => a.status === 'rejected' || a.status === 'expired')
      .map(a => a.craftsmanId);

    const candidateCraftsmen = await prisma.user.findMany({
      where: {
        role: 'craftsman',
        categoryId: request.categoryId,
        is_available: true,
        verification_status: 'approved',
        id: {
          notIn: rejectedCraftsmanIds,
        },
        latitude: { not: null },
        longitude: { not: null },
      },
      select: {
        id: true,
        name: true,
        rating: true,
        total_ratings: true,
        latitude: true,
        longitude: true,
      },
    });

    if (candidateCraftsmen.length === 0) {
      // لا يوجد حرفيون متاحون
      await prisma.request.update({
        where: { id: requestId },
        data: {
          requiresAdminAssignment: true,
          status: 'pending_admin_assignment',
        },
      });
      return {
        success: false,
        reason: 'no_available_craftsmen',
        message: 'لا يوجد حرفيون متاحون لهذا التصنيف',
      };
    }

    // 3. حساب المسافة وتصفية الحرفيين ضمن 40 كم
    const craftsmenWithDistance = candidateCraftsmen
      .map(craftsman => ({
        ...craftsman,
        distance: calculateDistance(
          clientLat,
          clientLon,
          craftsman.latitude!,
          craftsman.longitude!
        ),
      }))
      .filter(c => c.distance <= MAX_DISTANCE_KM);

    if (craftsmenWithDistance.length === 0) {
      await prisma.request.update({
        where: { id: requestId },
        data: {
          requiresAdminAssignment: true,
          status: 'pending_admin_assignment',
        },
      });
      return {
        success: false,
        reason: 'no_craftsmen_in_range',
        message: 'لا يوجد حرفيون ضمن نطاق 40 كم',
      };
    }

    // 4. الترتيب: الأعلى تقييماً أولاً، ثم الأقرب (كسر التعادل)
    craftsmenWithDistance.sort((a, b) => {
      // أولاً: حسب التقييم تنازلياً
      if (b.rating !== a.rating) {
        return b.rating - a.rating;
      }
      // ثانياً: إذا تساوى التقييم، حسب المسافة تصاعدياً (الأقرب أولاً)
      return a.distance - b.distance;
    });

    const selectedCraftsman = craftsmenWithDistance[0];

    // 5. إنشاء سجل الإسناد
    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + ASSIGNMENT_EXPIRY_MINUTES);

    const assignment = await prisma.requestAssignment.create({
      data: {
        requestId,
        craftsmanId: selectedCraftsman.id,
        status: 'pending',
        expiresAt,
      },
    });

    // 6. تحديث الطلب
    await prisma.request.update({
      where: { id: requestId },
      data: {
        currentAssignmentId: assignment.id,
        assignmentAttempts: {
          increment: 1,
        },
        status: 'pending_craftsman_acceptance',
      },
    });

    // 7. إرسال إشعار للحرفي (يمكن إضافة خدمة الإشعارات لاحقاً)
    // await sendCraftsmanNotification(selectedCraftsman.id, requestId);

    return {
      success: true,
      assignment: {
        id: assignment.id,
        craftsmanId: selectedCraftsman.id,
        craftsmanName: selectedCraftsman.name,
        craftsmanRating: selectedCraftsman.rating,
        distance: selectedCraftsman.distance.toFixed(2),
        expiresAt: assignment.expiresAt,
      },
    };
  } catch (error) {
    console.error('خطأ في الإسناد الذكي:', error);
    throw error;
  }
}

/**
 * معالجة الإسنادات المنتهية الصلاحية
 * يُستدعى من Cron Job كل دقيقة
 */
export async function processExpiredAssignments() {
  try {
    const now = new Date();

    // جلب الإسنادات المنتهية
    const expiredAssignments = await prisma.requestAssignment.findMany({
      where: {
        status: 'pending',
        expiresAt: {
          lte: now,
        },
      },
      include: {
        request: {
          include: {
            client: true,
          },
        },
      },
    });

    const results = {
      processed: 0,
      reassigned: 0,
      sentToAdmin: 0,
      failed: 0,
    };

    for (const assignment of expiredAssignments) {
      try {
        // 1. تحديث حالة الإسناد إلى منتهي
        await prisma.requestAssignment.update({
          where: { id: assignment.id },
          data: {
            status: 'expired',
            rejectionReason: 'انتهت مهلة الرد',
          },
        });

        // 2. تحديث حالة الطلب
        await prisma.request.update({
          where: { id: assignment.requestId },
          data: {
            status: 'craftsman_rejected',
            currentAssignmentId: null,
          },
        });

        // 3. محاولة إعادة الإسناد
        const reassignResult = await startSmartAssignment(assignment.requestId);

        if (reassignResult.success) {
          results.reassigned++;
        } else {
          results.sentToAdmin++;
        }

        results.processed++;
      } catch (error) {
        console.error(`خطأ في معالجة الإسناد ${assignment.id}:`, error);
        results.failed++;
      }
    }

    return results;
  } catch (error) {
    console.error('خطأ في معالجة الإسنادات المنتهية:', error);
    throw error;
  }
}

/**
 * قبول الحرفي للإسناد
 */
export async function acceptAssignment(assignmentId: number, craftsmanId: string) {
  try {
    const assignment = await prisma.requestAssignment.findUnique({
      where: { id: assignmentId },
      include: {
        request: true,
      },
    });

    if (!assignment) {
      throw new Error('الإسناد غير موجود');
    }

    if (assignment.craftsmanId !== craftsmanId) {
      throw new Error('غير مصرح لك بقبول هذا الإسناد');
    }

    if (assignment.status !== 'pending') {
      throw new Error('الإسناد لم يعد صالحاً');
    }

    if (assignment.expiresAt < new Date()) {
      throw new Error('انتهت مهلة الرد على الإسناد');
    }

    // تحديث الإسناد
    await prisma.requestAssignment.update({
      where: { id: assignmentId },
      data: {
        status: 'accepted',
        respondedAt: new Date(),
      },
    });

    // تحديث الطلب
    await prisma.request.update({
      where: { id: assignment.requestId },
      data: {
        craftsmanId: craftsmanId,
        status: 'accepted',
      },
    });

    return {
      success: true,
      message: 'تم قبول الطلب بنجاح',
    };
  } catch (error) {
    console.error('خطأ في قبول الإسناد:', error);
    throw error;
  }
}

/**
 * رفض الحرفي للإسناد
 */
export async function rejectAssignment(
  assignmentId: number,
  craftsmanId: string,
  reason?: string
) {
  try {
    const assignment = await prisma.requestAssignment.findUnique({
      where: { id: assignmentId },
      include: {
        request: true,
      },
    });

    if (!assignment) {
      throw new Error('الإسناد غير موجود');
    }

    if (assignment.craftsmanId !== craftsmanId) {
      throw new Error('غير مصرح لك برفض هذا الإسناد');
    }

    if (assignment.status !== 'pending') {
      throw new Error('الإسناد لم يعد صالحاً');
    }

    // تحديث الإسناد
    await prisma.requestAssignment.update({
      where: { id: assignmentId },
      data: {
        status: 'rejected',
        respondedAt: new Date(),
        rejectionReason: reason || 'رفض من الحرفي',
      },
    });

    // تحديث حالة الطلب
    await prisma.request.update({
      where: { id: assignment.requestId },
      data: {
        status: 'craftsman_rejected',
        currentAssignmentId: null,
      },
    });

    // محاولة إعادة الإسناد لحرفي آخر
    const reassignResult = await startSmartAssignment(assignment.requestId);

    return {
      success: true,
      message: 'تم رفض الطلب',
      reassigned: reassignResult.success,
    };
  } catch (error) {
    console.error('خطأ في رفض الإسناد:', error);
    throw error;
  }
}

/**
 * الإسناد اليدوي من الأدمن
 */
export async function manualAssign(
  requestId: number,
  craftsmanId: string,
  adminId: string
) {
  try {
    const request = await prisma.request.findUnique({
      where: { id: requestId },
    });

    if (!request) {
      throw new Error('الطلب غير موجود');
    }

    const craftsman = await prisma.user.findUnique({
      where: { id: craftsmanId },
    });

    if (!craftsman || craftsman.role !== 'craftsman') {
      throw new Error('الحرفي غير موجود');
    }

    // إنشاء إسناد مباشر (بدون مهلة زمنية)
    const expiresAt = new Date();
    expiresAt.setFullYear(expiresAt.getFullYear() + 1); // صلاحية طويلة للإسناد اليدوي

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
        currentAssignmentId: assignment.id,
        requiresAdminAssignment: false,
        status: 'pending_craftsman_acceptance',
      },
    });

    // تسجيل في سجل التدقيق
    await prisma.auditLog.create({
      data: {
        businessId: 'system', // يمكن تعديله لاحقاً
        userId: adminId,
        action: 'manual_assignment',
        entity: 'Request',
        entityId: requestId,
        changes: {
          craftsmanId,
          assignmentId: assignment.id,
        },
      },
    });

    return {
      success: true,
      assignment: {
        id: assignment.id,
        craftsmanId,
        craftsmanName: craftsman.name,
      },
    };
  } catch (error) {
    console.error('خطأ في الإسناد اليدوي:', error);
    throw error;
  }
}
