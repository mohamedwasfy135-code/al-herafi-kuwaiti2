import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'
import { logAudit } from '@/lib/audit'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const rents = await db.rent.findMany({
      where: { businessId },
      include: {
        account: { select: { id: true, name: true, code: true } },
      },
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json(rents)
  } catch (error) {
    console.error('[RENTS] GET error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      propertyOwner,
      propertyDesc,
      amount,
      dueDay,
      startDate,
      endDate,
      accountId,
      notes,
      action,
      rentId,
      paymentMethod,
    } = body

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    // Handle "pay" action for rent payment with accounting integration
    if (action === 'pay' && rentId) {
      const rent = await db.rent.findUnique({
        where: { id: parseInt(String(rentId)) },
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
      const resolvedPaymentMethod = paymentMethod || 'cash'

      // Wrap in transaction for atomicity
      await db.$transaction(async (tx) => {
        // Create BusinessTransaction for rent expense
        await tx.businessTransaction.create({
          data: {
            businessId,
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
          where: { businessId },
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
              businessId,
              totalIncome: 0,
              totalExpenses: rentAmount,
              totalPurchases: 0,
              netProfit: -rentAmount,
              transactionCount: 1,
            },
          })
        }

        // Update rent with payment method and payment date
        await tx.rent.update({
          where: { id: rent.id },
          data: {
            paymentMethod: resolvedPaymentMethod,
            paymentDate: new Date(),
          },
        })
      })

      // Log audit
      await logAudit({
        businessId,
        action: 'PAY',
        entity: 'Rent',
        entityId: rent.id,
        changes: { before: { paymentMethod: rent.paymentMethod }, after: { paymentMethod: resolvedPaymentMethod, paymentDate: new Date().toISOString() } }
      })

      return NextResponse.json({ success: true, message: 'تم صرف الإيجار وتحديث الحسابات' })
    }

    // Default: create a new rent contract
    if (!propertyOwner || !amount) {
      return NextResponse.json(
        { error: 'صاحب العقار والمبلغ مطلوبان' },
        { status: 400 }
      )
    }

    const rent = await db.rent.create({
      data: {
        businessId,
        propertyOwner,
        propertyDesc: propertyDesc || null,
        amount: parseFloat(String(amount)),
        dueDay: parseInt(String(dueDay || 1)),
        startDate: startDate ? new Date(startDate) : null,
        endDate: endDate ? new Date(endDate) : null,
        accountId: accountId ? parseInt(accountId) : null,
        notes: notes || null,
        paymentMethod: paymentMethod || null,
      },
      include: {
        account: { select: { id: true, name: true, code: true } },
      },
    })

    return NextResponse.json(rent, { status: 201 })
  } catch (error) {
    console.error('[RENTS] POST error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
