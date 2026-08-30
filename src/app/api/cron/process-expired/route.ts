import { NextResponse } from 'next/server';
import { processExpiredAssignments } from '@/lib/smart-assignment';

/**
 * POST /api/cron/process-expired
 * معالجة الإسنادات المنتهية الصلاحية
 * يُستدعى من Cron Job كل دقيقة
 * يتطلب: Cron Secret للتأكد من أن الطلب من النظام
 */
export async function POST(request: Request) {
  try {
    // التحقق من أن الطلب من Cron Job
    const authHeader = request.headers.get('authorization');
    const cronSecret = process.env.CRON_SECRET;
    
    if (!cronSecret || authHeader !== `Bearer ${cronSecret}`) {
      return NextResponse.json(
        { error: 'غير مصرح' },
        { status: 401 }
      );
    }

    // معالجة الإسنادات المنتهية
    const results = await processExpiredAssignments();

    return NextResponse.json({
      success: true,
      message: 'تم معالجة الإسنادات المنتهية',
      results,
    });
  } catch (error) {
    console.error('خطأ في /api/cron/process-expired:', error);
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    );
  }
}

/**
 * GET /api/cron/process-expired
 * اختبار الـ Cron Job (اختياري)
 */
export async function GET(request: Request) {
  try {
    const authHeader = request.headers.get('authorization');
    const cronSecret = process.env.CRON_SECRET;
    
    if (!cronSecret || authHeader !== `Bearer ${cronSecret}`) {
      return NextResponse.json(
        { error: 'غير مصرح' },
        { status: 401 }
      );
    }

    const results = await processExpiredAssignments();

    return NextResponse.json({
      success: true,
      message: 'تم معالجة الإسنادات المنتهية',
      results,
    });
  } catch (error) {
    console.error('خطأ في GET /api/cron/process-expired:', error);
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    );
  }
}
