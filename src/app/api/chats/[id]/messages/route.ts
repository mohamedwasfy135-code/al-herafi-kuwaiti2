import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

// GET: جلب الرسائل
export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) return NextResponse.json({ error: 'غير مصرح', messages: [] }, { status: 401 });

    const conversationId = params.id;

    // تحقق أمني صارم: هل المستخدم طرف في هذه المحادثة؟
    const conv = await db.conversation.findFirst({
      where: { id: conversationId, OR: [{ clientId: session.userId }, { craftsmanId: session.userId }] }
    });

    if (!conv) return NextResponse.json({ error: 'غير مصرح', messages: [] }, { status: 403 });

    const messages = await db.message.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'asc' },
      include: { sender: { select: { id: true, name: true } } }
    });

    // تنسيق البيانات لتتوافق مع الواجهة القديمة (content بدلاً من text)
    const formattedMessages = messages.map(msg => ({
      id: msg.id,
      content: msg.text,
      senderId: msg.senderId,
      createdAt: msg.createdAt
    }));

    // تحديث حالة القراءة
    await db.message.updateMany({
      where: { conversationId, senderId: { not: session.userId }, isRead: false },
      data: { isRead: true }
    });

    return NextResponse.json({ success: true, messages: formattedMessages });
  } catch (error: any) {
    console.error('GET /api/chats/[id]/messages error:', error);
    return NextResponse.json({ error: 'حدث خطأ', messages: [] }, { status: 500 });
  }
}

// POST: إرسال رسالة
export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });

    const { content } = await request.json();
    if (!content || content.trim().length === 0) {
      return NextResponse.json({ error: 'الرسالة فارغة' }, { status: 400 });
    }

    const conversationId = params.id;

    // تحقق أمني صارم
    const conv = await db.conversation.findFirst({
      where: { id: conversationId, OR: [{ clientId: session.userId }, { craftsmanId: session.userId }] }
    });

    if (!conv) return NextResponse.json({ error: 'غير مصرح' }, { status: 403 });

    console.log('📥 [Chat API] محاولة إرسال رسالة:', { 
      conversationId, 
      userId: session.userId, 
      contentLength: content?.length 
    });

    if (!session.userId) {
      return NextResponse.json({ error: 'غير مصرح: معرف المستخدم مفقود' }, { status: 401 });
    }

    // الطريقة المباشرة والأكثر موثوقية في Prisma عند وجود المعرفات
    const newMessage = await db.message.create({
      data: {
        conversationId: conversationId,
        senderId: session.userId,
        text: content.trim().slice(0, 2000) // حماية من الرسائل الضخمة
      },
      include: { 
        sender: { select: { id: true, name: true } } 
      }
    });

    // تحديث آخر رسالة في المحادثة
    await db.conversation.update({
      where: { id: conversationId },
      data: { lastMessage: content.trim().slice(0, 100), lastMessageAt: new Date() }
    });

    return NextResponse.json({ 
      success: true, 
      message: {
        id: newMessage.id,
        content: newMessage.text,
        senderId: newMessage.senderId,
        createdAt: newMessage.createdAt
      }
    });
  } catch (error: any) {
    console.error('POST /api/chats/[id]/messages error:', error);
    return NextResponse.json({ error: 'حدث خطأ' }, { status: 500 });
  }
}
