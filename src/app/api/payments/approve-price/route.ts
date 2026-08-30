import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'client') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const body = await request.json();
    const { requestId, action } = body;
    
    if (!requestId || !action) {
      return NextResponse.json({ error: 'البيانات مطلوبة' }, { status: 400 });
    }

    const req = await db.request.findUnique({ 
      where: { id: requestId }, 
      include: { craftsman: true } 
    });
    
    if (!req || req.clientId !== session.userId || req.status !== 'pending_approval') {
      return NextResponse.json({ error: 'خطأ في البيانات' }, { status: 400 });
    }

    if (action === 'approve') {
      await db.request.update({ 
        where: { id: requestId }, 
        data: { 
          agreedPrice: req.proposedPrice, 
          status: 'pending_payment' 
        } 
      });
      
      if (req.craftsmanId) {
        await db.notification.create({ 
          data: { 
            userId: req.craftsmanId, 
            title: '✅ العميل وافق على السعر', 
            body: `وافق العميل على السعر المقترح (${req.proposedPrice} د.ك) لطلبك #${requestId}. في انتظار دفعة الزيارة لبدء العمل.`, 
            type: 'price_approved' 
          } 
        });
      }
      
      return NextResponse.json({ 
        success: true, 
        message: 'تمت الموافقة على السعر. يرجى دفع دفعة الزيارة (3 د.ك) لبدء العمل.',
        nextStep: 'pay_visit_fee'
      }, { status: 200 });
    } else {
      await db.request.update({ 
        where: { id: requestId }, 
        data: { 
          status: 'accepted', 
          proposedPrice: null, 
          remainingAmount: null 
        } 
      });
      
      if (req.craftsmanId) {
        await db.notification.create({ 
          data: { 
            userId: req.craftsmanId, 
            title: '❌ العميل رفض السعر', 
            body: `رفض العميل السعر المقترح لطلبك #${requestId}. يرجى اقتراح سعر جديد.`, 
            type: 'price_rejected' 
          } 
        });
      }
      
      return NextResponse.json({ 
        success: true, 
        message: 'تم رفض السعر. سيتم إشعار الحرفي لاقتراح سعر جديد.' 
      }, { status: 200 });
    }
  } catch (error: any) {
    console.error('❌ خطأ في API موافقة السعر:', error);
    return NextResponse.json({ 
      error: error.message || 'حدث خطأ في الخادم',
      details: error.code || ''
    }, { status: 500 });
  }
}
