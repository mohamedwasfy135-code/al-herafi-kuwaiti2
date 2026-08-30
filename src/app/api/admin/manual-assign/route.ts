import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { verifyAuth } from '@/lib/auth';
import { manualAssign } from '@/lib/smart-assignment';

/**
 * POST /api/admin/manual-assign
 * الإسناد اليدوي من الأدمن
 * يتطلب: مصادقة الأدمن
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

    if (user.role !== 'admin') {
      return NextResponse.json(
        { error: 'غير مصرح - فقط الأدمن يمكنهم الإسناد اليدوي' },
        { status: 403 }
      );
    }

    // 2. جلب البيانات من الـ body
    const body = await request.json();
    const { requestId, craftsmanId } = body;

    if (!requestId || !craftsmanId) {
      return NextResponse.json(
        { error: 'رقم الطلب ورقم الحرفي مطلوبان' },
        { status: 400 }
      );
    }

    // 3. التحقق من وجود الطلب
    const requestExists = await prisma.request.findUnique({
      where: { id: requestId },
      select: { id: true, status: true },
    });

    if (!requestExists) {
      return NextResponse.json(
        { error: 'الطلب غير موجود' },
        { status: 404 }
      );
    }

    // 4. التحقق من وجود الحرفي
    const craftsmanExists = await prisma.user.findUnique({
      where: { id: craftsmanId },
      select: { id: true, role: true, name: true },
    });

    if (!craftsmanExists || craftsmanExists.role !== 'craftsman') {
      return NextResponse.json(
        { error: 'الحرفي غير موجود' },
        { status: 404 }
      );
    }

    // 5. تنفيذ الإسناد اليدوي
    const result = await manualAssign(requestId, craftsmanId, user.id);

    return NextResponse.json({
      success: true,
      message: 'تم الإسناد اليدوي بنجاح',
      assignment: result.assignment,
    });
  } catch (error: any) {
    console.error('خطأ في /api/admin/manual-assign:', error);
    
    if (error.message.includes('غير موجود')) {
      return NextResponse.json(
        { error: error.message },
        { status: 404 }
      );
    }
    
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    );
  }
}
