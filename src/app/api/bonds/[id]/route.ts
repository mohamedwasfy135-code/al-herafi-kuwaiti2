import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'
import { logAudit } from '@/lib/audit'

// DELETE /api/bonds/[id] - حذف سند
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const bond = await db.bond.findFirst({
      where: { id: parseInt(id), businessId },
    })

    if (!bond) {
      return NextResponse.json({ error: 'السند غير موجود' }, { status: 404 })
    }

    await db.bond.delete({ where: { id: parseInt(id) } })

    await logAudit({
      businessId,
      action: 'DELETE',
      entity: 'Bond',
      entityId: bond.id,
      changes: { before: { bondNumber: bond.bondNumber, bondType: bond.bondType, amount: bond.amount, partyName: bond.partyName } },
    })

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('[BONDS] DELETE error:', error)
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    )
  }
}
