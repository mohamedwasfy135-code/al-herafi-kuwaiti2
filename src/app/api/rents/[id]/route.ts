import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function PUT(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params
    const body = await request.json()
    const { propertyOwner, propertyDesc, amount, dueDay, startDate, endDate, accountId, notes, isActive, action } = body

    // Handle "pay" action for rent payment with accounting integration
    if (action === 'pay') {
      const rent = await db.rent.findUnique({
        where: { id: parseInt(id) },
        include: {
          account: { select: { id: true, name: true, code: true } },
        },
      })

      if (!rent) {
        return NextResponse.json({ error: 'عقد الإيجار غير موجود' }, { status: 404 })
      }

      if (!rent.accountId) {
        return NextResponse.json({ error: 'لا يوجد حساب مرتبط بعقد الإيجار' }, { status: 400 })
      }

      const rentAmount = rent.amount

      // Wrap in transaction for atomicity
      await db.$transaction(async (tx) => {
        // Create BusinessTransaction for rent expense
        await tx.businessTransaction.create({
          data: {
            businessId: rent.businessId,
            type: 'expense',
            amount: rentAmount,
            description: `إيجار ${rent.propertyDesc || 'عقار'} - ${rent.propertyOwner}${rent.account ? ` | حساب: ${rent.account.name}` : ''}`,
            category: 'rent',
            referenceType: 'rent',
            referenceId: rent.id,
            debitAccountId: rent.accountId!,
            transactionDate: new Date(),
          },
        })

        // Update account currentBalance (decrease)
        await tx.account.update({
          where: { id: rent.accountId! },
          data: { currentBalance: { decrement: rentAmount } },
        })

        // Update BusinessSummary - increase totalExpenses
        const existingSummary = await tx.businessSummary.findFirst({
          where: { businessId: rent.businessId },
        })

        if (existingSummary) {
          const newTotalExpenses = existingSummary.totalExpenses + rentAmount
          await tx.businessSummary.update({
            where: { id: existingSummary.id },
            data: {
              totalExpenses: newTotalExpenses,
              netProfit: existingSummary.totalIncome - newTotalExpenses,
              transactionCount: existingSummary.transactionCount + 1,
              lastUpdated: new Date(),
            },
          })
        } else {
          await tx.businessSummary.create({
            data: {
              businessId: rent.businessId,
              totalIncome: 0,
              totalExpenses: rentAmount,
              totalPurchases: 0,
              netProfit: -rentAmount,
              transactionCount: 1,
            },
          })
        }
      })

      return NextResponse.json({ success: true, message: 'تم صرف الإيجار وتحديث الحسابات' })
    }

    // Default: update rent contract details
    const rent = await db.rent.update({
      where: { id: parseInt(id) },
      data: {
        ...(propertyOwner !== undefined && { propertyOwner }),
        ...(propertyDesc !== undefined && { propertyDesc }),
        ...(amount !== undefined && { amount: parseFloat(String(amount)) }),
        ...(dueDay !== undefined && { dueDay: parseInt(String(dueDay)) }),
        ...(startDate !== undefined && { startDate: startDate ? new Date(startDate) : null }),
        ...(endDate !== undefined && { endDate: endDate ? new Date(endDate) : null }),
        ...(accountId !== undefined && { accountId: accountId ? parseInt(accountId) : null }),
        ...(notes !== undefined && { notes }),
        ...(isActive !== undefined && { isActive }),
      },
      include: {
        account: { select: { id: true, name: true, code: true } },
      },
    })

    return NextResponse.json(rent)
  } catch (error) {
    console.error('[RENT] PUT error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params
    await db.rent.delete({ where: { id: parseInt(id) } })
    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('[RENT] DELETE error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
