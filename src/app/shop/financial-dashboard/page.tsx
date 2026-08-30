'use client'

import { useState, useEffect, useCallback } from 'react'
import { useLanguage } from '@/lib/language-context'
import { getBusinessId } from '@/lib/shop-utils'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import {
  TrendingUp,
  TrendingDown,
  DollarSign,
  Wallet,
  ArrowUpRight,
  ArrowDownRight,
  BarChart3,
  PieChart as PieChartIcon,
  Loader2,
} from 'lucide-react'
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Line,
  ComposedChart,
} from 'recharts'

interface SalesInvoice {
  id: number
  total: number
  paidAmount: number
  status: string
  createdAt: string
  clientName?: string
  clientId?: number
  items: { productId?: number; productName?: string; quantity: number; total: number }[]
}

interface PurchaseInvoice {
  id: number
  total: number
  paidAmount: number
  status: string
  createdAt: string
  supplierName?: string
}

interface Bond {
  id: number
  bondType: string
  amount: number
  createdAt: string
  partyName?: string
}

interface Salary {
  id: number
  netSalary: number
  status: string
}

interface Rent {
  id: number
  amount: number
  isActive: boolean
}

interface Account {
  id: number
  accountType: string
  currentBalance: number
}

const PIE_COLORS = ['#ef4444', '#f97316', '#eab308', '#22c55e', '#06b6d4', '#8b5cf6']

export default function FinancialDashboardPage() {
  const { t, lang, dir } = useLanguage()
  const businessId = getBusinessId()

  const [loading, setLoading] = useState(true)
  const [salesInvoices, setSalesInvoices] = useState<SalesInvoice[]>([])
  const [purchaseInvoices, setPurchaseInvoices] = useState<PurchaseInvoice[]>([])
  const [bonds, setBonds] = useState<Bond[]>([])
  const [salaries, setSalaries] = useState<Salary[]>([])
  const [rents, setRentData] = useState<Rent[]>([])
  const [accounts, setAccounts] = useState<Account[]>([])

  const fetchData = useCallback(async () => {
    setLoading(true)
    try {
      const [salesRes, purchaseRes, bondsRes, salariesRes, rentsRes, accountsRes] = await Promise.all([
        fetch(`/api/invoices/sales?businessId=${businessId}`),
        fetch(`/api/invoices/purchase?businessId=${businessId}`),
        fetch(`/api/bonds?businessId=${businessId}`),
        fetch(`/api/salaries?businessId=${businessId}`),
        fetch(`/api/rents?businessId=${businessId}`),
        fetch(`/api/accounts?businessId=${businessId}`),
      ])

      const [salesData, purchaseData, bondsData, salariesData, rentsData, accountsData] = await Promise.all([
        salesRes.json(),
        purchaseRes.json(),
        bondsRes.json(),
        salariesRes.json(),
        rentsRes.json(),
        accountsRes.json(),
      ])

      setSalesInvoices(salesData.invoices || salesData || [])
      setPurchaseInvoices(purchaseData.invoices || purchaseData || [])
      setBonds(bondsData.bonds || bondsData || [])
      setSalaries(salariesData.salaries || salariesData || [])
      setRentData(rentsData.rents || rentsData || [])
      setAccounts(accountsData.accounts || accountsData || [])
    } catch (error) {
      console.error('Failed to fetch financial data:', error)
    } finally {
      setLoading(false)
    }
  }, [businessId])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  // Calculate KPIs
  const totalRevenue = salesInvoices.reduce((sum, inv) => sum + (inv.total || 0), 0)
  const totalPaidByClients = salesInvoices.reduce((sum, inv) => sum + (inv.paidAmount || 0), 0)

  const totalPurchases = purchaseInvoices.reduce((sum, inv) => sum + (inv.total || 0), 0)
  const totalSalaries = salaries.filter((s) => s.status === 'paid').reduce((sum, s) => sum + (s.netSalary || 0), 0)
  const totalRents = rents.filter((r) => r.isActive).reduce((sum, r) => sum + (r.amount || 0), 0)
  const paymentBonds = bonds.filter((b) => b.bondType === 'payment').reduce((sum, b) => sum + (b.amount || 0), 0)
  const receiptBonds = bonds.filter((b) => b.bondType === 'receipt').reduce((sum, b) => sum + (b.amount || 0), 0)

  const totalExpenses = totalPurchases + totalSalaries + totalRents + paymentBonds
  const netProfit = totalRevenue - totalExpenses
  const cashBalance = accounts.reduce((sum, acc) => sum + (acc.currentBalance || 0), 0)
  const profitMargin = totalRevenue > 0 ? ((netProfit / totalRevenue) * 100) : 0

  // Monthly data for last 12 months
  const getMonthlyData = () => {
    const months: { name: string; revenue: number; expenses: number; profit: number }[] = []
    const now = new Date()
    const monthNames = [
      t('salaries_month_jan'), t('salaries_month_feb'), t('salaries_month_mar'), t('salaries_month_apr'),
      t('salaries_month_may'), t('salaries_month_jun'), t('salaries_month_jul'), t('salaries_month_aug'),
      t('salaries_month_sep'), t('salaries_month_oct'), t('salaries_month_nov'), t('salaries_month_dec'),
    ]

    for (let i = 11; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
      const month = d.getMonth()
      const year = d.getFullYear()
      const monthKey = `${year}-${String(month + 1).padStart(2, '0')}`

      const monthRevenue = salesInvoices
        .filter((inv) => inv.createdAt?.startsWith(monthKey))
        .reduce((sum, inv) => sum + (inv.total || 0), 0)

      const monthPurchases = purchaseInvoices
        .filter((inv) => inv.createdAt?.startsWith(monthKey))
        .reduce((sum, inv) => sum + (inv.total || 0), 0)

      const monthPaymentBonds = bonds
        .filter((b) => b.bondType === 'payment' && b.createdAt?.startsWith(monthKey))
        .reduce((sum, b) => sum + (b.amount || 0), 0)

      const monthExpenses = monthPurchases + monthPaymentBonds

      months.push({
        name: monthNames[month],
        revenue: Math.round(monthRevenue * 100) / 100,
        expenses: Math.round(monthExpenses * 100) / 100,
        profit: Math.round((monthRevenue - monthExpenses) * 100) / 100,
      })
    }
    return months
  }

  // Expense breakdown for pie chart
  const getExpenseBreakdown = () => {
    return [
      { name: t('finance_purchases'), value: totalPurchases },
      { name: t('finance_salaries'), value: totalSalaries },
      { name: t('finance_rents'), value: totalRents },
      { name: t('finance_payment_bonds'), value: paymentBonds },
    ].filter((item) => item.value > 0)
  }

  // Top 5 products by sales
  const getTopProducts = () => {
    const productMap: Record<number, { name: string; quantity: number; revenue: number }> = {}
    salesInvoices.forEach((inv) => {
      const items = (inv as { items?: { productId?: number; description?: string; quantity: number; total: number }[] }).items
      if (items) {
        items.forEach((item) => {
          if (item.productId) {
            if (!productMap[item.productId]) {
              productMap[item.productId] = { name: item.description || `Product #${item.productId}`, quantity: 0, revenue: 0 }
            }
            productMap[item.productId].quantity += item.quantity
            productMap[item.productId].revenue += item.total
          }
        })
      }
    })
    return Object.values(productMap).sort((a, b) => b.revenue - a.revenue).slice(0, 5)
  }

  // Top 5 clients by purchase
  const getTopClients = () => {
    const clientMap: Record<string, { name: string; total: number; invoices: number }> = {}
    salesInvoices.forEach((inv) => {
      if (inv.clientName || inv.clientId) {
        const key = String(inv.clientId || inv.clientName)
        if (!clientMap[key]) {
          clientMap[key] = { name: inv.clientName || `Client #${inv.clientId}`, total: 0, invoices: 0 }
        }
        clientMap[key].total += inv.total
        clientMap[key].invoices += 1
      }
    })
    return Object.values(clientMap).sort((a, b) => b.total - a.total).slice(0, 5)
  }

  // Cash flow data
  const cashFlow = {
    inflows: {
      sales: totalRevenue,
      receiptBonds,
      total: totalRevenue + receiptBonds,
    },
    outflows: {
      purchases: totalPurchases,
      paymentBonds,
      salaries: totalSalaries,
      rents: totalRents,
      total: totalPurchases + paymentBonds + totalSalaries + totalRents,
    },
    net: (totalRevenue + receiptBonds) - (totalPurchases + paymentBonds + totalSalaries + totalRents),
  }

  const monthlyData = getMonthlyData()
  const expenseBreakdown = getExpenseBreakdown()
  const topProducts = getTopProducts()
  const topClients = getTopClients()

  const formatNumber = (num: number) => {
    return new Intl.NumberFormat(lang === 'ar' ? 'ar-KW' : 'en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(num)
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]" dir={dir}>
        <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
        <span className="ms-3 text-gray-700">{t('loading')}</span>
      </div>
    )
  }

  return (
    <div className="space-y-6" dir={dir}>
      <div className="flex items-center gap-3">
        <div className="p-2 bg-emerald-100 rounded-lg">
          <BarChart3 className="h-6 w-6 text-emerald-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{t('finance_title')}</h1>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card className="border-green-200 bg-gradient-to-br from-green-50 to-emerald-50">
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-green-600 font-medium">{t('finance_total_revenue')}</p>
                <p className="text-2xl font-bold text-green-700">{formatNumber(totalRevenue)}</p>
                <p className="text-xs text-green-500">{t('currency')}</p>
              </div>
              <div className="p-3 bg-green-100 rounded-xl">
                <TrendingUp className="h-6 w-6 text-green-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="border-red-200 bg-gradient-to-br from-red-50 to-rose-50">
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-red-600 font-medium">{t('finance_total_expenses')}</p>
                <p className="text-2xl font-bold text-red-700">{formatNumber(totalExpenses)}</p>
                <p className="text-xs text-red-500">{t('currency')}</p>
              </div>
              <div className="p-3 bg-red-100 rounded-xl">
                <TrendingDown className="h-6 w-6 text-red-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="border-emerald-200 bg-gradient-to-br from-emerald-50 to-teal-50">
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-emerald-600 font-medium">{t('finance_net_profit')}</p>
                <p className={`text-2xl font-bold ${netProfit >= 0 ? 'text-emerald-700' : 'text-red-700'}`}>
                  {formatNumber(netProfit)}
                </p>
                <p className="text-xs text-emerald-500">{t('currency')}</p>
              </div>
              <div className="p-3 bg-emerald-100 rounded-xl">
                <DollarSign className="h-6 w-6 text-emerald-600" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="border-purple-200 bg-gradient-to-br from-purple-50 to-violet-50">
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-purple-600 font-medium">{t('finance_cash_balance')}</p>
                <p className="text-2xl font-bold text-purple-700">{formatNumber(cashBalance)}</p>
                <p className="text-xs text-purple-500">{t('currency')}</p>
              </div>
              <div className="p-3 bg-purple-100 rounded-xl">
                <Wallet className="h-6 w-6 text-purple-600" />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Revenue vs Expenses Bar Chart */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <BarChart3 className="h-4 w-4 text-emerald-600" />
              {t('finance_revenue_trend')}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-80">
              <ResponsiveContainer width="100%" height="100%">
                <ComposedChart data={monthlyData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" tick={{ fontSize: 11 }} />
                  <YAxis tick={{ fontSize: 11 }} />
                  <Tooltip
                    formatter={(value: number) => formatNumber(value)}
                    labelStyle={{ fontWeight: 'bold' }}
                  />
                  <Legend />
                  <Bar dataKey="revenue" name={t('chart_revenue')} fill="#22c55e" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="expenses" name={t('chart_expenses')} fill="#ef4444" radius={[4, 4, 0, 0]} />
                  <Line type="monotone" dataKey="profit" name={t('finance_profit')} stroke="#8b5cf6" strokeWidth={2} dot={{ r: 3 }} />
                </ComposedChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Expense Breakdown Pie Chart */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <PieChartIcon className="h-4 w-4 text-amber-600" />
              {t('finance_expense_breakdown')}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-64">
              {expenseBreakdown.length > 0 ? (
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={expenseBreakdown}
                      cx="50%"
                      cy="50%"
                      innerRadius={40}
                      outerRadius={80}
                      paddingAngle={3}
                      dataKey="value"
                      label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                    >
                      {expenseBreakdown.map((_, index) => (
                        <Cell key={`cell-${index}`} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip formatter={(value: number) => formatNumber(value)} />
                  </PieChart>
                </ResponsiveContainer>
              ) : (
                <div className="flex items-center justify-center h-full text-gray-600">
                  {t('no_data')}
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Bottom Section: Top Products, Top Clients, Cash Flow, Profit Margin */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {/* Top 5 Products */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base">{t('finance_top_products')}</CardTitle>
          </CardHeader>
          <CardContent>
            {topProducts.length > 0 ? (
              <div className="space-y-3 max-h-64 overflow-y-auto">
                {topProducts.map((product, idx) => (
                  <div key={idx} className="flex items-center justify-between p-2 bg-gray-50 rounded-lg">
                    <div className="flex items-center gap-2">
                      <Badge variant="secondary" className="w-6 h-6 rounded-full p-0 flex items-center justify-center text-xs">
                        {idx + 1}
                      </Badge>
                      <span className="text-sm font-medium truncate max-w-[100px]">{product.name}</span>
                    </div>
                    <div className="text-end">
                      <p className="text-sm font-bold text-emerald-600">{formatNumber(product.revenue)}</p>
                      <p className="text-xs text-gray-600">{product.quantity} {t('quantity')}</p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-gray-600 text-center py-8">{t('no_data')}</p>
            )}
          </CardContent>
        </Card>

        {/* Top 5 Clients */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base">{t('finance_top_clients')}</CardTitle>
          </CardHeader>
          <CardContent>
            {topClients.length > 0 ? (
              <div className="space-y-3 max-h-64 overflow-y-auto">
                {topClients.map((client, idx) => (
                  <div key={idx} className="flex items-center justify-between p-2 bg-gray-50 rounded-lg">
                    <div className="flex items-center gap-2">
                      <Badge variant="secondary" className="w-6 h-6 rounded-full p-0 flex items-center justify-center text-xs">
                        {idx + 1}
                      </Badge>
                      <span className="text-sm font-medium truncate max-w-[100px]">{client.name}</span>
                    </div>
                    <div className="text-end">
                      <p className="text-sm font-bold text-emerald-600">{formatNumber(client.total)}</p>
                      <p className="text-xs text-gray-600">{client.invoices} {t('items')}</p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-gray-600 text-center py-8">{t('no_data')}</p>
            )}
          </CardContent>
        </Card>

        {/* Cash Flow Summary */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base">{t('finance_cash_flow')}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="space-y-2">
              <p className="text-xs font-medium text-green-600 flex items-center gap-1">
                <ArrowUpRight className="h-3 w-3" />
                {t('finance_inflows')}
              </p>
              <div className="ps-4 space-y-1 text-xs">
                <div className="flex justify-between">
                  <span className="text-gray-700">{t('finance_sales')}</span>
                  <span className="font-medium">{formatNumber(cashFlow.inflows.sales)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-700">{t('finance_receipt_bonds')}</span>
                  <span className="font-medium">{formatNumber(cashFlow.inflows.receiptBonds)}</span>
                </div>
              </div>
            </div>
            <div className="space-y-2">
              <p className="text-xs font-medium text-red-600 flex items-center gap-1">
                <ArrowDownRight className="h-3 w-3" />
                {t('finance_outflows')}
              </p>
              <div className="ps-4 space-y-1 text-xs">
                <div className="flex justify-between">
                  <span className="text-gray-700">{t('finance_purchases')}</span>
                  <span className="font-medium">{formatNumber(cashFlow.outflows.purchases)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-700">{t('finance_payment_bonds')}</span>
                  <span className="font-medium">{formatNumber(cashFlow.outflows.paymentBonds)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-700">{t('finance_salaries')}</span>
                  <span className="font-medium">{formatNumber(cashFlow.outflows.salaries)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-700">{t('finance_rents')}</span>
                  <span className="font-medium">{formatNumber(cashFlow.outflows.rents)}</span>
                </div>
              </div>
            </div>
            <div className="pt-2 border-t flex justify-between items-center">
              <span className="text-sm font-bold">{t('finance_net_flow')}</span>
              <span className={`text-sm font-bold ${cashFlow.net >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
                {formatNumber(cashFlow.net)}
              </span>
            </div>
          </CardContent>
        </Card>

        {/* Profit Margin Gauge */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base">{t('finance_profit_margin')}</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col items-center justify-center">
            <div className="relative w-32 h-32">
              <svg className="w-32 h-32 -rotate-90" viewBox="0 0 120 120">
                <circle cx="60" cy="60" r="50" fill="none" stroke="#e5e7eb" strokeWidth="10" />
                <circle
                  cx="60"
                  cy="60"
                  r="50"
                  fill="none"
                  stroke={profitMargin >= 0 ? '#22c55e' : '#ef4444'}
                  strokeWidth="10"
                  strokeDasharray={`${Math.min(Math.abs(profitMargin), 100) * 3.14} 314`}
                  strokeLinecap="round"
                />
              </svg>
              <div className="absolute inset-0 flex items-center justify-center">
                <span className={`text-2xl font-bold ${profitMargin >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
                  {profitMargin.toFixed(1)}%
                </span>
              </div>
            </div>
            <p className="text-sm text-gray-700 mt-2 text-center">
              {profitMargin >= 0 ? t('finance_positive_profit') : t('finance_loss')}
            </p>
            <div className="mt-3 w-full space-y-1 text-xs">
              <div className="flex justify-between">
                <span className="text-gray-700">{t('chart_revenue')}</span>
                <span className="font-medium">{formatNumber(totalRevenue)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-700">{t('chart_expenses')}</span>
                <span className="font-medium">{formatNumber(totalExpenses)}</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
