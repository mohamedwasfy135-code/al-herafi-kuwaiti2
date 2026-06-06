import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')

    if (!rawBusinessId) {
      // Return sample data if no businessId provided
      return NextResponse.json({
        totalRevenue: 0,
        activeRequests: 0,
        totalProducts: 0,
        totalClients: 0,
        recentRequests: [],
        revenueByMonth: [],
      })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    // Fetch stats in parallel
    const [
      incomeResult,
      activeRequestsCount,
      productsCount,
      clientsCount,
      recentRequests,
      transactions,
    ] = await Promise.all([
      db.businessTransaction.aggregate({
        where: { businessId, type: 'income' },
        _sum: { amount: true },
      }),
      db.request.count({
        where: {
          businessId,
          status: { in: ['pending', 'accepted', 'in_progress'] },
        },
      }),
      db.product.count({
        where: { businessId, isActive: true },
      }),
      db.businessClient.count({
        where: { businessId },
      }),
      db.request.findMany({
        where: { businessId },
        include: {
          client: {
            select: { id: true, name: true, phone: true },
          },
          craftsman: {
            select: { id: true, name: true },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
      db.businessTransaction.findMany({
        where: {
          businessId,
          transactionDate: {
            gte: new Date(new Date().getFullYear(), 0, 1),
          },
        },
        select: {
          type: true,
          amount: true,
          transactionDate: true,
        },
      }),
    ])

    // Calculate revenue by month
    const revenueByMonth: { month: string; revenue: number; expenses: number }[] = []
    const monthNames = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ]

    for (let i = 0; i < 12; i++) {
      const monthStart = new Date(new Date().getFullYear(), i, 1)
      const monthEnd = new Date(new Date().getFullYear(), i + 1, 1)

      const monthTransactions = transactions.filter((t) => {
        const date = t.transactionDate || new Date()
        return date >= monthStart && date < monthEnd
      })

      const revenue = monthTransactions
        .filter((t) => t.type === 'income')
        .reduce((sum, t) => sum + t.amount, 0)

      const expenses = monthTransactions
        .filter((t) => t.type === 'expense' || t.type === 'purchase')
        .reduce((sum, t) => sum + t.amount, 0)

      revenueByMonth.push({
        month: monthNames[i],
        revenue,
        expenses,
      })
    }

    return NextResponse.json({
      totalRevenue: incomeResult._sum.amount || 0,
      activeRequests: activeRequestsCount,
      totalProducts: productsCount,
      totalClients: clientsCount,
      recentRequests,
      revenueByMonth,
    })
  } catch (error) {
    console.error('Error fetching dashboard stats:', error)
    return NextResponse.json(
      { error: 'Failed to fetch dashboard stats' },
      { status: 500 }
    )
  }
}
