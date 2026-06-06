import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'
import { logAudit } from '@/lib/audit'

// GET /api/bonds - جلب قائمة السندات
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    const bondType = searchParams.get('bondType')

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const where: Record<string, unknown> = { businessId }
    if (bondType) {
      where.bondType = bondType
    }

    const bonds = await db.bond.findMany({
      where,
      include: {
        account: { select: { id: true, code: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    })

    return NextResponse.json(bonds)
  } catch (error) {
    console.error('[BONDS] GET error:', error)
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    )
  }
}

// POST /api/bonds - إنشاء سند جديد
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      bondNumber,
      bondType,
      amount,
      partyName,
      partyType,
      description,
      accountId,
      referenceType,
      referenceId,
      paymentMethod,
      issuedDate,
    } = body

    if (!bondType || !amount) {
      return NextResponse.json(
        { error: 'نوع السند والمبلغ مطلوبان' },
        { status: 400 }
      )
    }

    if (!['receipt', 'payment'].includes(bondType)) {
      return NextResponse.json(
        { error: 'نوع السند غير صحيح' },
        { status: 400 }
      )
    }

    if (!rawBusinessId) {
      return NextResponse.json(
        { error: 'businessId مطلوب' },
        { status: 400 }
      )
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const parsedAmount = parseFloat(amount) || 0
    const resolvedAccountId = accountId ? parseInt(accountId) : null

    // Wrap in transaction for atomicity
    const bond = await db.$transaction(async (tx) => {
      const createdBond = await tx.bond.create({
        data: {
          businessId,
          bondNumber: bondNumber || `${bondType === 'receipt' ? 'RB' : 'PB'}-${Date.now()}`,
          bondType,
          amount: parsedAmount,
          partyName: partyName || null,
          partyType: partyType || null,
          description: description || null,
          accountId: resolvedAccountId,
          referenceType: referenceType || null,
          referenceId: referenceId ? parseInt(referenceId) : null,
          paymentMethod: paymentMethod || null,
          issuedDate: issuedDate ? new Date(issuedDate) : new Date(),
        },
      })

      // If bond has an accountId, update account and create BusinessTransaction
      if (resolvedAccountId) {
        if (bondType === 'receipt') {
          // Receipt bond (سند قبض): INCREASE account balance
          await tx.account.update({
            where: { id: resolvedAccountId },
            data: { currentBalance: { increment: parsedAmount } },
          })

          // Create BusinessTransaction for income
          await tx.businessTransaction.create({
            data: {
              businessId,
              type: 'income',
              amount: parsedAmount,
              description: `سند قبض رقم ${createdBond.bondNumber}${partyName ? ` - ${partyName}` : ''}`,
              category: 'bond_receipt',
              referenceType: 'bond',
              referenceId: createdBond.id,
              creditAccountId: resolvedAccountId,
              transactionDate: createdBond.issuedDate || new Date(),
            },
          })

          // Update BusinessSummary - increase totalIncome
          const existingSummary = await tx.businessSummary.findFirst({
            where: { businessId },
          })

          if (existingSummary) {
            const newTotalIncome = existingSummary.totalIncome + parsedAmount
            await tx.businessSummary.update({
              where: { id: existingSummary.id },
              data: {
                totalIncome: newTotalIncome,
                netProfit: newTotalIncome - existingSummary.totalExpenses,
                transactionCount: existingSummary.transactionCount + 1,
                lastUpdated: new Date(),
              },
            })
          } else {
            await tx.businessSummary.create({
              data: {
                businessId,
                totalIncome: parsedAmount,
                totalExpenses: 0,
                totalPurchases: 0,
                netProfit: parsedAmount,
                transactionCount: 1,
              },
            })
          }
        } else if (bondType === 'payment') {
          // Payment bond (سند صرف): DECREASE account balance
          await tx.account.update({
            where: { id: resolvedAccountId },
            data: { currentBalance: { decrement: parsedAmount } },
          })

          // Create BusinessTransaction for expense
          await tx.businessTransaction.create({
            data: {
              businessId,
              type: 'expense',
              amount: parsedAmount,
              description: `سند صرف رقم ${createdBond.bondNumber}${partyName ? ` - ${partyName}` : ''}`,
              category: 'bond_payment',
              referenceType: 'bond',
              referenceId: createdBond.id,
              debitAccountId: resolvedAccountId,
              transactionDate: createdBond.issuedDate || new Date(),
            },
          })

          // Update BusinessSummary - increase totalExpenses
          const existingSummary = await tx.businessSummary.findFirst({
            where: { businessId },
          })

          if (existingSummary) {
            const newTotalExpenses = existingSummary.totalExpenses + parsedAmount
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
                totalExpenses: parsedAmount,
                totalPurchases: 0,
                netProfit: -parsedAmount,
                transactionCount: 1,
              },
            })
          }
        }
      }

      return createdBond
    })

    await logAudit({
      businessId,
      action: 'CREATE',
      entity: 'Bond',
      entityId: bond.id,
      changes: { after: { bondNumber: bond.bondNumber, bondType: bond.bondType, amount: bond.amount, partyName: bond.partyName } },
    })

    return NextResponse.json(bond, { status: 201 })
  } catch (error) {
    console.error('[BONDS] POST error:', error)
    return NextResponse.json(
      { error: 'حدث خطأ في الخادم' },
      { status: 500 }
    )
  }
}
