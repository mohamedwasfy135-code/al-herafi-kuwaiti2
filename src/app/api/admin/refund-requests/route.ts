import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { requireAdmin } from '@/lib/admin-auth';

export async function GET(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) return authResult;

    const refunds = await prisma.refundRequest.findMany({
      where: { status: 'pending' },
      include: {
        request: {
          select: {
            serviceType: true,
            client: { select: { name: true, phone: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return NextResponse.json({ success: true, refunds });
  } catch (error: any) {
    console.error('GET refund-requests error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}

export async function PUT(request: NextRequest) {
  try {
    const authResult = await requireAdmin(request);
    if (authResult instanceof NextResponse) return authResult;

    const { refundId, action, adminNotes } = await request.json();
    if (!refundId || !['approve', 'reject'].includes(action)) {
      return NextResponse.json({ error: 'بيانات أو إجراء غير صالح' }, { status: 400 });
    }

    const newStatus = action === 'approve' ? 'approved' : 'rejected';

    const refund = await prisma.refundRequest.update({
      where: { id: refundId },
      data: {
        status: newStatus,
        adminNotes: adminNotes || '',
      },
    });

    if (action === 'approve') {
      console.log('موافقة على الاسترداد للمبلغ:', refund.amount);
    }

    return NextResponse.json({ success: true, refund });
  } catch (error: any) {
    console.error('PUT refund-requests error:', error);
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
