import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

// GET /api/notifications/daily-report?businessId=X&date=YYYY-MM-DD
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const businessId = searchParams.get('businessId')
    const dateStr = searchParams.get('date') || new Date().toISOString().split('T')[0]

    if (!businessId) {
      return NextResponse.json({ error: 'businessId is required' }, { status: 400 })
    }

    const dateStart = new Date(dateStr + 'T00:00:00.000Z')
    const dateEnd = new Date(dateStr + 'T23:59:59.999Z')

    // Fetch business info
    const business = await db.business.findUnique({
      where: { id: businessId },
      select: { name: true, nameEn: true },
    })

    // Sales data
    const salesInvoices = await db.salesInvoice.findMany({
      where: {
        businessId,
        createdAt: { gte: dateStart, lte: dateEnd },
      },
      select: { total: true, paidAmount: true, status: true },
    })

    const totalSales = salesInvoices.reduce((sum, inv) => sum + inv.total, 0)
    const totalPaid = salesInvoices.reduce((sum, inv) => sum + inv.paidAmount, 0)
    const newInvoicesCount = salesInvoices.length
    const unpaidInvoices = salesInvoices.filter(inv => inv.status !== 'paid' && inv.status !== 'cancelled').length

    // Purchase data
    const purchaseInvoices = await db.purchaseInvoice.findMany({
      where: {
        businessId,
        createdAt: { gte: dateStart, lte: dateEnd },
      },
      select: { total: true, paidAmount: true },
    })

    const totalPurchases = purchaseInvoices.reduce((sum, inv) => sum + inv.total, 0)

    // Expenses
    const expenses = await db.expense.findMany({
      where: {
        businessId,
        expenseDate: { gte: dateStart, lte: dateEnd },
      },
      select: { amount: true, category: true },
    })

    const totalExpenses = expenses.reduce((sum, exp) => sum + exp.amount, 0)

    // Bonds
    const bonds = await db.bond.findMany({
      where: {
        businessId,
        issuedDate: { gte: dateStart, lte: dateEnd },
      },
      select: { bondType: true, amount: true },
    })

    const receiptBondsTotal = bonds.filter(b => b.bondType === 'receipt').reduce((sum, b) => sum + b.amount, 0)
    const paymentBondsTotal = bonds.filter(b => b.bondType === 'payment').reduce((sum, b) => sum + b.amount, 0)

    // Low stock alerts
    const lowStockProducts = await db.product.findMany({
      where: {
        businessId,
        isActive: true,
        trackStock: true,
        stockQuantity: { lte: 5 },
      },
      select: { name: true, stockQuantity: true, lowStockThreshold: true },
      take: 5,
    })

    // Net cash flow
    const netCashFlow = receiptBondsTotal - paymentBondsTotal + totalPaid - totalExpenses

    const report = {
      businessName: business?.name || business?.nameEn || 'المحل',
      date: dateStr,
      sales: {
        total: totalSales,
        paid: totalPaid,
        remaining: totalSales - totalPaid,
        invoiceCount: newInvoicesCount,
        unpaidCount: unpaidInvoices,
      },
      purchases: {
        total: totalPurchases,
      },
      expenses: {
        total: totalExpenses,
        byCategory: expenses.reduce((acc, exp) => {
          const cat = exp.category || 'أخرى'
          acc[cat] = (acc[cat] || 0) + exp.amount
          return acc
        }, {} as Record<string, number>),
      },
      bonds: {
        receiptTotal: receiptBondsTotal,
        paymentTotal: paymentBondsTotal,
        net: receiptBondsTotal - paymentBondsTotal,
      },
      netCashFlow,
      lowStockAlerts: lowStockProducts,
    }

    // Generate WhatsApp message text (Arabic formatted)
    const waMessage = `📊 *تقرير يومي - ${report.businessName}*
📅 التاريخ: ${dateStr}

💰 *المبيعات:*
├ الإجمالي: ${totalSales.toFixed(3)} د.ك
├ المدفوع: ${totalPaid.toFixed(3)} د.ك
├ المتبقي: ${(totalSales - totalPaid).toFixed(3)} د.ك
└ عدد الفواتير: ${newInvoicesCount}

🛒 *المشتريات:* ${totalPurchases.toFixed(3)} د.ك

💸 *المصروفات:* ${totalExpenses.toFixed(3)} د.ك

🏦 *السندات:*
├ قبض: ${receiptBondsTotal.toFixed(3)} د.ك
├ صرف: ${paymentBondsTotal.toFixed(3)} د.ك
└ صافي: ${(receiptBondsTotal - paymentBondsTotal).toFixed(3)} د.ك

💵 *صافي التدفق النقدي:* ${netCashFlow.toFixed(3)} د.ك
${lowStockProducts.length > 0 ? `\n⚠️ *تنبيهات المخزون:* ${lowStockProducts.length} منتج منخفض المخزون` : ''}

---
تقرير من الحرفي الكويتي 🇰🇼`

    return NextResponse.json({ report, waMessage })
  } catch (error) {
    console.error('Error generating daily report:', error)
    return NextResponse.json({ error: 'Failed to generate daily report' }, { status: 500 })
  }
}
