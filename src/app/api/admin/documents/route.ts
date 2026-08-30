import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { requireAdmin } from '@/lib/admin-auth';

export async function GET(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) return authResult;

    const documents = await prisma.craftsmanIDocument.findMany({
      where: { status: 'pending' },
      include: {
        craftsman: { select: { name: true, phone: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return NextResponse.json({ success: true, documents });
  } catch (error: any) {
    console.error('GET documents error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}

export async function PUT(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) return authResult;
    const admin = authResult;

    const { documentId, action } = await request.json();
    if (!documentId || !['approve', 'reject'].includes(action)) {
      return NextResponse.json({ error: 'بيانات أو إجراء غير صالح' }, { status: 400 });
    }

    const newStatus = action === 'approve' ? 'approved' : 'rejected';

    const doc = await prisma.craftsmanIDocument.update({
      where: { id: documentId },
      data: {
        status: newStatus,
        reviewedBy: admin.userId,
        reviewedAt: new Date(),
      },
      include: { craftsman: { select: { id: true, name: true } } },
    });

    await prisma.notification.create({
      data: {
        userId: doc.craftsman.id,
        title: action === 'approve' ? '✅ تم اعتماد مستنداتك' : '❌ تم رفض مستنداتك',
        body: action === 'approve' ? 'يمكنك الآن استقبال الطلبات' : 'يرجى إعادة رفع المستندات الصحيحة',
        type: 'document_verification',
      },
    });

    return NextResponse.json({ success: true, document: doc });
  } catch (error: any) {
    console.error('PUT documents error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
