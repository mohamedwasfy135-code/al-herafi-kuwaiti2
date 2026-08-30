import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { verifyAuth } from '@/lib/auth';
import { startSmartAssignment } from '@/lib/smart-assignment';

/**
 * POST /api/requests/smart-assign
 * بدء عملية الإسناد الذكي لطلب
 * يتطلب: مصادقة العميل
 */
export async function POST(request: NextRequest) {
  try {
    // 1. التحقق من المصادقة
    const authHeader = request.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json(
        { error: 'غير مصرح - يجب تسجيل الدخول' },
        { status: 401 }
      );
    }

    const token = authHeader.substring(7);
    const user = await verifyAuth(token);

    if (!user) {
      return NextResponse.json(
        { error: 'غير مصرح - توكن غير صالح' },
        { status: 401 }
      );
    }

    if (user.role !== 'client') {
      return NextResponse.json(
        { error: 'غير مصرح - فقط العملاء يمكنهم بدء الإسناد' },
        { status: 403 }
      );
    }

    // 2. جلب بيانات الطلب من الـ body
    const body = await request.json();
    const { requestId } = body;

    if (!requestId) {
      return NextResponse.json(
        { error: 'رقم الطلب مطلوب' },
        { status: 400 }
      );
    }

    // 3. التحقق من ملكية الطلب
    const requestExists = await prisma.request.findUnique({
      where: { id: requestId },
      select: { clientId: true, status: true },
    });

    if (!requestExists) {
      return NextResponse.json(
        { error: 'الطلب غير موجود' },
        { status: 404 }
      );
    }

    if (requestExists.clientId !== user.id) {
      return NextResponse.json(
        { error: 'غير مصرح - هذا الطلب ليس لك' },
        { status: 403 }
      );
    }

    // 4. التحقق من حالة الطلب
    if (requestExists.status !== 'pending' && requestExists.status !== 'craftsman_rejected') {
      return NextResponse.json(
        { error: 'حالة الطلب لا تسمح بالإسناد' },
        { status: 400 }
      );
    }

    // 5. بدء الإسناد الذكي
    const result = await startSmartAssignment(requestId);

    if (!result.success) {
      return NextResponse.json(
        {
          success: false,
          message: result.message,
          reason: result.reason,
        },
        { status: 200 }
      );
    }

    // 6. إرجاع النتيجة
    return NextResponse.json(
      {
        success: true,
        message: 'تم بدء الإسناد الذكي بنجاح',
        assignment: result.assignment,
      },
      { status: 200 }
    );
  } catch (error) {
    console.error('خطأ في /api/requests/smart-assign:', error);
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    );
  }
}
