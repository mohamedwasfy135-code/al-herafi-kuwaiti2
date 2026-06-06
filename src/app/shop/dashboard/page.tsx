'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import {
  TrendingUp,
  TrendingDown,
  DollarSign,
  Package,
  Users,
  FileText,
  FileCheck,
  ArrowLeft,
  Loader2,
} from 'lucide-react'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart'
import { Bar, BarChart, XAxis, YAxis, CartesianGrid } from 'recharts'

interface DashboardData {
  totalRevenue: number
  totalExpenses: number
  netProfit: number
  totalProducts: number
  totalClients: number
  activeInvoices: number
  pendingBonds: number
  revenueByMonth: { month: string; revenue: number; expenses: number }[]
  recentInvoices: any[]
  recentBonds: any[]
}

const chartConfig = {
  revenue: { label: 'Revenue', color: '#10b981' },
  expenses: { label: 'Expenses', color: '#ef4444' },
}

export default function ShopDashboard() {
  const { t, lang, dir } = useLanguage()
  const [data, setData] = useState<DashboardData | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadDashboard() {
      try {
        // Fetch dashboard stats, accounting summary, and counts in parallel
        const businessId = getBusinessId()
        const [dashboardRes, summaryRes, invoicesRes, bondsRes] = await Promise.all([
          fetch(`/api/dashboard?businessId=${businessId}`),
          fetch(`/api/accounting/summary?businessId=${businessId}`),
          fetch(`/api/invoices/sales?businessId=${businessId}&status=unpaid`),
          fetch(`/api/bonds?businessId=${businessId}`),
        ])

        const dashboardData = dashboardRes.ok ? await dashboardRes.json() : {}
        const summaryData = summaryRes.ok ? await summaryRes.json() : {}

        // Get unpaid invoices count
        let activeInvoices = 0
        if (invoicesRes.ok) {
          const invoices = await invoicesRes.json()
          activeInvoices = Array.isArray(invoices) ? invoices.length : 0
        }

        // Get pending bonds count
        let pendingBonds = 0
        if (bondsRes.ok) {
          const bonds = await bondsRes.json()
          pendingBonds = Array.isArray(bonds) ? bonds.filter((b: any) => b.bondType === 'payment').length : 0
        }

        const totalRevenue = dashboardData.totalRevenue || summaryData.totalIncome || 0
        const totalExpenses = (summaryData.totalExpenses || 0) + (summaryData.totalPurchases || 0)

        setData({
          totalRevenue,
          totalExpenses,
          netProfit: totalRevenue - totalExpenses,
          totalProducts: dashboardData.totalProducts || 0,
          totalClients: dashboardData.totalClients || 0,
          activeInvoices,
          pendingBonds,
          revenueByMonth: dashboardData.revenueByMonth || [],
          recentInvoices: [],
          recentBonds: [],
        })
      } catch (err) {
        console.error('Dashboard load error:', err)
        // Set default data
        setData({
          totalRevenue: 0,
          totalExpenses: 0,
          netProfit: 0,
          totalProducts: 0,
          totalClients: 0,
          activeInvoices: 0,
          pendingBonds: 0,
          revenueByMonth: [],
          recentInvoices: [],
          recentBonds: [],
        })
      } finally {
        setLoading(false)
      }
    }
    loadDashboard()
  }, [])

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="h-10 w-10 animate-spin text-emerald-600" />
      </div>
    )
  }

  if (!data) return null

  const statsCards = [
    {
      title: t('dashboard_total_revenue'),
      value: data.totalRevenue,
      suffix: t('currency'),
      icon: TrendingUp,
      color: 'text-emerald-700',
      bgColor: 'bg-emerald-100',
      iconColor: 'text-emerald-600',
    },
    {
      title: t('dashboard_total_expenses'),
      value: data.totalExpenses,
      suffix: t('currency'),
      icon: TrendingDown,
      color: 'text-red-700',
      bgColor: 'bg-red-100',
      iconColor: 'text-red-600',
    },
    {
      title: t('dashboard_net_profit'),
      value: data.netProfit,
      suffix: t('currency'),
      icon: DollarSign,
      color: data.netProfit >= 0 ? 'text-emerald-700' : 'text-red-700',
      bgColor: data.netProfit >= 0 ? 'bg-emerald-100' : 'bg-red-100',
      iconColor: data.netProfit >= 0 ? 'text-emerald-600' : 'text-red-600',
    },
    {
      title: t('dashboard_products'),
      value: data.totalProducts,
      suffix: '',
      icon: Package,
      color: 'text-violet-700',
      bgColor: 'bg-violet-100',
      iconColor: 'text-violet-600',
    },
    {
      title: t('dashboard_clients'),
      value: data.totalClients,
      suffix: '',
      icon: Users,
      color: 'text-blue-700',
      bgColor: 'bg-blue-100',
      iconColor: 'text-blue-600',
    },
    {
      title: t('dashboard_unpaid_invoices'),
      value: data.activeInvoices,
      suffix: '',
      icon: FileText,
      color: 'text-amber-700',
      bgColor: 'bg-amber-100',
      iconColor: 'text-amber-600',
    },
    {
      title: t('dashboard_payment_bonds'),
      value: data.pendingBonds,
      suffix: '',
      icon: FileCheck,
      color: 'text-orange-700',
      bgColor: 'bg-orange-100',
      iconColor: 'text-orange-600',
    },
  ]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold tracking-tight">{t('dashboard_title')}</h1>
        <p className="text-muted-foreground">{t('dashboard_subtitle')}</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-4">
        {statsCards.map((stat) => (
          <Card key={stat.title} className="hover:shadow-sm transition-shadow">
            <CardContent className="p-4">
              <div className="flex items-center gap-3">
                <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-lg ${stat.bgColor}`}>
                  <stat.icon className={`h-5 w-5 ${stat.iconColor}`} />
                </div>
                <div className="min-w-0">
                  <p className="text-xs text-muted-foreground truncate">{stat.title}</p>
                  <p className={`text-lg font-bold ${stat.color}`}>
                    {stat.value.toLocaleString('ar-KW')}
                    {stat.suffix && <span className="text-xs font-normal mr-1">{stat.suffix}</span>}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Revenue Chart */}
      {data.revenueByMonth.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">{t('dashboard_monthly_revenue')}</CardTitle>
            <CardDescription>{t('dashboard_monthly_desc')}</CardDescription>
          </CardHeader>
          <CardContent>
            <ChartContainer config={chartConfig} className="h-[260px] w-full">
              <BarChart data={data.revenueByMonth.filter(m => m.revenue > 0 || m.expenses > 0)}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} />
                <XAxis dataKey="month" tickLine={false} axisLine={false} fontSize={12} />
                <YAxis
                  tickLine={false}
                  axisLine={false}
                  fontSize={12}
                  tickFormatter={(val) => `${val / 1000}ك`}
                />
                <ChartTooltip content={<ChartTooltipContent />} />
                <Bar dataKey="revenue" fill="#10b981" radius={[4, 4, 0, 0]} name={t('chart_revenue')} />
                <Bar dataKey="expenses" fill="#ef4444" radius={[4, 4, 0, 0]} name={t('chart_expenses')} />
              </BarChart>
            </ChartContainer>
          </CardContent>
        </Card>
      )}

      {/* Quick Actions */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">{t('dashboard_quick_actions')}</CardTitle>
          <CardDescription>{t('dashboard_quick_actions_desc')}</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-3">
            {[
              { href: '/shop/invoices', icon: '📄', label: t('dashboard_new_invoice'), desc: t('dashboard_new_invoice_desc') },
              { href: '/shop/bonds', icon: '📑', label: t('dashboard_new_bond'), desc: t('dashboard_new_bond_desc') },
              { href: '/shop/products', icon: '📦', label: t('dashboard_add_product'), desc: t('dashboard_add_product_desc') },
              { href: '/shop/clients', icon: '👥', label: t('dashboard_add_client'), desc: t('dashboard_add_client_desc') },
              { href: '/shop/accounting', icon: '📊', label: t('dashboard_accounting'), desc: t('dashboard_accounting_desc') },
              { href: '/shop/offers', icon: '🏷️', label: t('dashboard_new_offer'), desc: t('dashboard_new_offer_desc') },
            ].map((action) => (
              <Link
                key={action.href + action.label}
                href={action.href}
                className="group flex flex-col items-center justify-center gap-2 rounded-xl border p-4 hover:border-emerald-300 hover:bg-emerald-50/50 transition-all"
              >
                <span className="text-2xl group-hover:scale-110 transition-transform">{action.icon}</span>
                <span className="text-sm font-medium text-center">{action.label}</span>
                <span className="text-[10px] text-muted-foreground text-center">{action.desc}</span>
              </Link>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
