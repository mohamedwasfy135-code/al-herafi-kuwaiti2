import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { getSessionFromRequest } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'غير مصرح - يجب تسجيل الدخول' }, { status: 401 });
    }

    if (session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح - يجب أن تكون حرفي' }, { status: 403 });
    }

    let body;
    try {
      body = await request.json();
    } catch (err) {
      return NextResponse.json({ error: 'بيانات غير صالحة' }, { status: 400 });
    }

    const { civilIdUrl, bankAccountPhotoUrl, bankName, bankIban } = body;

    if (!civilIdUrl && !bankAccountPhotoUrl) {
      return NextResponse.json({ 
        error: 'يجب رفع صورة البطاقة المدنية أو الحساب البنكي على الأقل' 
      }, { status: 400 });
    }

    // البحث عن وثيقة موجودة لهذا الحرفي
    const existing = await prisma.craftsmanIDocument.findFirst({
      where: { craftsmanId: session.userId },
    });

    let document;

    if (existing) {
      // تحديث الوثيقة الموجودة
      document = await prisma.craftsmanIDocument.update({
        where: { id: existing.id },
        data: {
          civilIdUrl: civilIdUrl || existing.civilIdUrl,
          bankAccountPhotoUrl: bankAccountPhotoUrl || existing.bankAccountPhotoUrl,
          bankName: bankName || existing.bankName,
          bankIban: bankIban || existing.bankIban,
          status: 'pending',
        },
      });
    } else {
      // إنشاء وثيقة جديدة
      document = await prisma.craftsmanIDocument.create({
        data: {
          craftsmanId: session.userId,
          civilIdUrl: civilIdUrl || null,
          bankAccountPhotoUrl: bankAccountPhotoUrl || null,
          bankName: bankName || null,
          bankIban: bankIban || null,
          status: 'pending',
        },
      });
    }

    return NextResponse.json({ 
      success: true, 
      message: 'تم رفع المستندات بنجاح وهي بانتظار اعتماد الإدارة',
      document
    });

  } catch (error: any) {
    console.error('POST documents error:', error);
    return NextResponse.json({ 
      error: 'حدث خطأ في حفظ البيانات',
      details: error.message 
    }, { status: 500 });
  }
}

export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const document = await prisma.craftsmanIDocument.findFirst({
      where: { craftsmanId: session.userId },
    });

    return NextResponse.json({ success: true, document: document || null });
  } catch (error: any) {
    console.error('GET documents error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
