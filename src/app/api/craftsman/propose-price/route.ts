import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const body = await request.json();
    const { requestId, proposedPrice } = body;
    
    if (!requestId || !proposedPrice) {
      return NextResponse.json({ error: 'البيانات مطلوبة' }, { status: 400 });
    }
    
    if (parseFloat(proposedPrice) < 3) {
      return NextResponse.json({ error: 'السعر يجب أن يكون 3 د.ك أو أكثر' }, { status: 400 });
    }

    const req = await db.request.findUnique({ 
      where: { id: requestId }, 
      include: { client: true } 
    });
    
    if (!req || req.craftsmanId !== session.userId) {
      return NextResponse.json({ error: 'الطلب غير موجود أو ليس مسنداً لك' }, { status: 403 });
    }
    
    if (req.status !== 'accepted') {
      return NextResponse.json({ error: 'يمكن اقتراح السعر فقط للطلبات المقبولة' }, { status: 400 });
    }

    const remainingAmount = parseFloat(proposedPrice) - 3;
    
    await db.request.update({ 
      where: { id: requestId }, 
      data: { 
        proposedPrice: parseFloat(proposedPrice), 
        remainingAmount, 
        status: 'pending_approval' 
      } 
    });
    
    await db.notification.create({ 
      data: { 
        userId: req.clientId, 
        title: '💰 اقتراح سعر جديد', 
        body: `اقترح الحرفي سعر ${proposedPrice} د.ك لطلبك #${requestId}. يرجى مراجعة السعر والموافقة عليه.`, 
        type: 'price_proposed' 
      } 
    });

    return NextResponse.json({ 
      success: true, 
      proposedPrice: parseFloat(proposedPrice), 
      remainingAmount 
    }, { status: 200 });
  } catch (error: any) {
    console.error(' خطأ في API اقتراح السعر:', error);
    return NextResponse.json({ 
      error: error.message || 'حدث خطأ في الخادم',
      details: error.code || ''
    }, { status: 500 });
  }
}
