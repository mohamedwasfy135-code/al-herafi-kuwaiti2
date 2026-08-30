import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { getSessionFromRequest } from '@/lib/auth'

export async function GET(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request)
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 })
    }

    // جلب جميع الطلبات التي تم إسنادها لهذا الحرفي (بما في ذلك حالات الدفع الجديدة)
    const requests = await db.request.findMany({
      where: {
        craftsmanId: session.userId,
        status: {
          in: ['accepted', 'pending_approval', 'pending_payment', 'in_progress', 'completed', 'paid']
        }
      },
      include: {
        client: {
          select: { name: true, phone: true }
        },
        category: {
          select: { name: true, icon: true }
        }
      },
      orderBy: { updatedAt: 'desc' },
      take: 50,
    })

    console.log('✅ [My Requests] عدد طلبات الحرفي:', requests.length)

    return NextResponse.json({
      success: true,
      requests,
    })

  } catch (error: any) {
    console.error('❌ Fetch my requests error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
