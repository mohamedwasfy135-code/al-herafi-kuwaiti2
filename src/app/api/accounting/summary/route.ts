import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')

    if (!rawBusinessId) {
      return NextResponse.json(
        { error: 'businessId مطلوب' },
        { status: 400 }
      )
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json(
        { totalIncome: 0, totalExpenses: 0, totalPurchases: 0, totalCommission: 0, netProfit: 0, transactionCount: 0, monthlyData: [] },
        { status: 404 }
      )
    }

    // Get or create summary
    let summary = await db.businessSummary.findFirst({
      where: { businessId },
    })

    if (!summary) {
      // Calculate from transactions
      const [incomeResult, expenseResult, purchaseResult, commissionResult, transactionCount] =
        await Promise.all([
          db.businessTransaction.aggregate({
            where: { businessId, type: 'income' },
            _sum: { amount: true },
          }),
          db.businessTransaction.aggregate({
            where: { businessId, type: 'expense' },
            _sum: { amount: true },
          }),
          db.businessTransaction.aggregate({
            where: { businessId, type: 'purchase' },
            _sum: { amount: true },
          }),
          db.businessTransaction.aggregate({
            where: { businessId, type: 'commission' },
            _sum: { amount: true },
          }),
          db.businessTransaction.count({ where: { businessId } }),
        ])

      const totalIncome = incomeResult._sum.amount || 0
      const totalExpenses = expenseResult._sum.amount || 0
      const totalPurchases = purchaseResult._sum.amount || 0
      const totalCommission = commissionResult._sum.amount || 0
      const netProfit = totalIncome - totalExpenses - totalPurchases - totalCommission

      summary = await db.businessSummary.create({
        data: {
          businessId,
          totalIncome,
          totalExpenses,
          totalPurchases,
          totalCommission,
          netProfit,
          transactionCount,
        },
      })
    }

    // Get monthly data
    const monthlyData = await db.businessTransaction.groupBy({
      by: ['type'],
      where: {
        businessId,
        transactionDate: {
          gte: new Date(new Date().getFullYear(), 0, 1),
        },
      },
      _sum: { amount: true },
    })

    return NextResponse.json({
      ...summary,
      monthlyData,
    })
  } catch (error) {
    console.error('Error fetching business summary:', error)
    return NextResponse.json(
      { error: 'Failed to fetch business summary' },
      { status: 500 }
    )
  }
}
