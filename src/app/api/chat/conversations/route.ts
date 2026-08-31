import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

// GET: جلب محادثات المستخدم
export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const conversations = await db.conversation.findMany({
      where: {
        OR: [
          { clientId: session.userId },
          { craftsmanId: session.userId }
        ]
      },
      include: {
        client: { select: { id: true, name: true, avatarUrl: true } },
        craftsman: { select: { id: true, name: true, avatarUrl: true, rating: true } },
        request: { 
          select: { 
            id: true, 
            serviceType: true, 
            governorate: true, 
            city: true 
          } 
        },
        messages: {
          take: 1,
          orderBy: { createdAt: 'desc' },
          select: { text: true, createdAt: true, senderId: true }
        }
      },
      orderBy: { lastMessageAt: 'desc' }
    });

    // حساب عدد الرسائل غير المقروءة لكل محادثة
    const conversationsWithUnread = await Promise.all(
      conversations.map(async (conv) => {
        const unreadCount = await db.message.count({
          where: {
            conversationId: conv.id,
            senderId: { not: session.userId },
            isRead: false
          }
        });

        const otherUser = conv.clientId === session.userId ? conv.craftsman : conv.client;

        return {
          ...conv,
          otherUser,
          unreadCount,
          lastMessage: conv.messages[0] || null
        };
      })
    );

    return NextResponse.json({ success: true, conversations: conversationsWithUnread });
  } catch (error: any) {
    console.error('GET chat/conversations error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}

// POST: إنشاء محادثة جديدة
export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { craftsmanId, requestId } = await request.json();

    if (!craftsmanId) {
      return NextResponse.json({ error: 'بيانات غير صالحة' }, { status: 400 });
    }

    // التحقق من أن المستخدم عميل (فقط العملاء يمكنهم بدء محادثة)
    if (session.role !== 'client') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 403 });
    }

    // التحقق من عدم وجود محادثة سابقة
    const existing = await db.conversation.findFirst({
      where: {
        clientId: session.userId,
        craftsmanId,
        requestId: requestId || null
      }
    });

    if (existing) {
      return NextResponse.json({ success: true, conversation: existing });
    }

    // إنشاء محادثة جديدة
    const conversation = await db.conversation.create({
      data: {
        clientId: session.userId,
        craftsmanId,
        requestId: requestId || null
      },
      include: {
        client: { select: { id: true, name: true, avatarUrl: true } },
        craftsman: { select: { id: true, name: true, avatarUrl: true, rating: true } }
      }
    });

    return NextResponse.json({ success: true, conversation });
  } catch (error: any) {
    console.error('POST chat/conversations error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
