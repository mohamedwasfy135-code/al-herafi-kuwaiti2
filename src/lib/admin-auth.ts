import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth, getSessionFromRequest, SessionData } from './auth';

/**
 * دالة للتحقق من أن الطلب قادم من أدمن مسجل دخول
 * تدعم طريقتين:
 * 1. Bearer token في Authorization header (للـ APIs الخارجية)
 * 2. Session cookie (للواجهة الأمامية)
 */
export async function requireAdmin(request: NextRequest): Promise<SessionData | NextResponse> {
  try {
    let user: SessionData | null = null;

    // الطريقة 1: Bearer token
    const authHeader = request.headers.get('authorization');
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      user = await verifyAuth(token);
    }

    // الطريقة 2: Session cookie
    if (!user) {
      user = await getSessionFromRequest(request);
    }

    // التحقق من وجود المستخدم
    if (!user) {
      return NextResponse.json(
        { error: 'غير مصرح - يجب تسجيل الدخول' },
        { status: 401 }
      );
    }

    // التحقق من أن المستخدم أدمن
    if (user.role !== 'admin') {
      return NextResponse.json(
        { error: 'غير مصرح - فقط الأدمن يمكنهم الوصول' },
        { status: 403 }
      );
    }

    return user;
  } catch (error) {
    console.error('خطأ في requireAdmin:', error);
    return NextResponse.json(
      { error: 'حدث خطأ في التحقق من الهوية' },
      { status: 500 }
    );
  }
}
