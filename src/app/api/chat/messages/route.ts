import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

// GET: جلب رسائل محادثة معينة
export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { searchParams } = new URL(request.url);
    const conversationId = searchParams.get('conversationId');

    if (!conversationId) {
      return NextResponse.json({ error: 'معرف المحادثة مطلوب' }, { status: 400 });
    }

    // التحقق من أن المستخدم طرف في المحادثة (أمان صارم)
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
      return NextResponse.json({ error: 'المحادثة غير موجودة أو غير مصرح بالوصول إليها' }, { status: 404 });
    }

    // جلب الرسائل مع ترقيم الصفحات
    const messages = await db.message.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'asc' },
      take: 100,
      include: {
        sender: { select: { id: true, name: true, avatarUrl: true } }
      }
    });

    // تحديث حالة القراءة للرسائل المرسلة من الطرف الآخر
    await db.message.updateMany({
      where: {
        conversationId,
        senderId: { not: session.userId },
        isRead: false
      },
      data: { isRead: true }
    });

    return NextResponse.json({ success: true, messages });
  } catch (error: any) {
    console.error('GET chat/messages error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}

// POST: إرسال رسالة جديدة
export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { conversationId, text } = await request.json();

    if (!conversationId || !text || text.trim().length === 0) {
      return NextResponse.json({ error: 'بيانات غير صالحة' }, { status: 400 });
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
      return NextResponse.json({ error: 'المحادثة غير موجودة أو غير مصرح بالوصول إليها' }, { status: 404 });
    }

    // إنشاء الرسالة
    const message = await db.message.create({
      data: {
        conversationId,
        senderId: session.userId,
        text: text.trim().slice(0, 2000) // حد أقصى 2000 حرف
      },
      include: {
        sender: { select: { id: true, name: true, avatarUrl: true } }
      }
    });

    // تحديث آخر رسالة في المحادثة
    await db.conversation.update({
      where: { id: conversationId },
      data: {
        lastMessage: text.trim().slice(0, 100),
        lastMessageAt: new Date()
      }
    });

    return NextResponse.json({ success: true, message });
  } catch (error: any) {
    console.error('POST chat/messages error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
