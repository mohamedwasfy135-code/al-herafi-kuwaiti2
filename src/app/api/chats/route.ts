import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'غير مصرح', chats: [] }, { status: 401 });
    }

    // جلب المحادثات باستخدام الجداول الجديدة الآمنة
    const conversations = await db.conversation.findMany({
      where: {
        OR: [{ clientId: session.userId }, { craftsmanId: session.userId }]
      },
      orderBy: { lastMessageAt: 'desc' },
      include: {
        client: { select: { id: true, name: true } },
        craftsman: { select: { id: true, name: true } },
        messages: { take: 1, orderBy: { createdAt: 'desc' }, select: { text: true, createdAt: true } }
      }
    });

    // تنسيق البيانات لتتوافق تماماً مع ما تتوقعه الواجهة القديمة (participant1, participant2)
    const formattedChats = conversations.map(conv => {
      const lastMsg = conv.messages[0];
      return {
        id: conv.id,
        participant1: conv.client,
        participant2: conv.craftsman,
        lastMessage: lastMsg?.text || '',
        updatedAt: lastMsg?.createdAt || conv.createdAt
      };
    });

    return NextResponse.json({ success: true, chats: formattedChats });
  } catch (error: any) {
    console.error('GET /api/chats error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم', chats: [] }, { status: 500 });
  }
}
