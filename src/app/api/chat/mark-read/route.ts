import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { conversationId } = await request.json();

    if (!conversationId) {
      return NextResponse.json({ error: 'معرف المحادثة مطلوب' }, { status: 400 });
    }

    // التحقق من أن المستخدم طرف في المحادثة
    const conversation = await db.conversation.findFirst({
      where: {
        id: conversationId,
        OR: [
          { clientId: session.userId },
          { craftsmanId: session.userId }
        ]
      }
    });

    if (!conversation) {
      return NextResponse.json({ error: 'المحادثة غير موجودة' }, { status: 404 });
    }

    // تحديث جميع الرسائل غير المقروءة من الطرف الآخر
    await db.message.updateMany({
      where: {
        conversationId,
        senderId: { not: session.userId },
        isRead: false
      },
      data: { isRead: true }
    });

    return NextResponse.json({ success: true });
  } catch (error: any) {
    console.error('POST chat/mark-read error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
