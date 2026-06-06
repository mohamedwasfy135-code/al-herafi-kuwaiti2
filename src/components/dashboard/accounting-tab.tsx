'use client'

import { useState, useEffect, useMemo } from 'react'
import {
  Calculator,
  Plus,
  TrendingUp,
  TrendingDown,
  DollarSign,
  ArrowUpDown,
  Loader2,
  CreditCard,
  Banknote,
  FileCheck,
  BookOpen,
} from 'lucide-react'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart'
import { Bar, BarChart, XAxis, YAxis, CartesianGrid } from 'recharts'
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'
import Link from 'next/link'

interface Transaction {
  id: number
  businessId: string
  type: string
  amount: number
  description: string | null
  category: string | null
  transactionDate: string | null
  createdAt: string
}

// Sample transactions are generated inside the component with i18n
function getSampleTransactions(t: (key: any) => string): Transaction[] {
  const now = new Date()
  const day = 86400000
  return [
    { id: 1, businessId: '1', type: 'income', amount: 500, description: `${t('accounting_sample_invoice_payment')} #SI-00001`, category: t('accounting_cat_sales'), transactionDate: now.toISOString(), createdAt: now.toISOString() },
    { id: 2, businessId: '1', type: 'expense', amount: 150, description: t('accounting_sample_purchase_materials'), category: t('accounting_cat_materials'), transactionDate: now.toISOString(), createdAt: now.toISOString() },
    { id: 3, businessId: '1', type: 'income', amount: 280, description: `${t('accounting_sample_invoice_payment')} #SI-00002`, category: t('accounting_cat_sales'), transactionDate: new Date(now.getTime() - day).toISOString(), createdAt: new Date(now.getTime() - day).toISOString() },
    { id: 4, businessId: '1', type: 'purchase', amount: 350, description: `${t('accounting_sample_invoice_payment')} #PI-00001`, category: t('type_purchase_cat'), transactionDate: new Date(now.getTime() - day).toISOString(), createdAt: new Date(now.getTime() - day).toISOString() },
    { id: 5, businessId: '1', type: 'expense', amount: 80, description: t('accounting_sample_rent'), category: t('accounting_cat_rent'), transactionDate: new Date(now.getTime() - 2 * day).toISOString(), createdAt: new Date(now.getTime() - 2 * day).toISOString() },
    { id: 6, businessId: '1', type: 'commission', amount: 25, description: t('accounting_sample_commission'), category: t('type_commission'), transactionDate: new Date(now.getTime() - 2 * day).toISOString(), createdAt: new Date(now.getTime() - 2 * day).toISOString() },
    { id: 7, businessId: '1', type: 'income', amount: 520, description: `${t('accounting_sample_invoice_payment')} #SI-00003`, category: t('accounting_cat_sales'), transactionDate: new Date(now.getTime() - 3 * day).toISOString(), createdAt: new Date(now.getTime() - 3 * day).toISOString() },
    { id: 8, businessId: '1', type: 'transfer', amount: 200, description: t('accounting_sample_bank_transfer'), category: t('accounting_cat_transfers'), transactionDate: new Date(now.getTime() - 4 * day).toISOString(), createdAt: new Date(now.getTime() - 4 * day).toISOString() },
  ]
}

export function AccountingTab() {
  const { t, lang, dir } = useLanguage()

  const typeMap = useMemo(() => ({
    income: { label: t('type_income'), color: 'bg-emerald-100 text-emerald-700', icon: TrendingUp },
    expense: { label: t('type_expense'), color: 'bg-red-100 text-red-700', icon: TrendingDown },
    purchase: { label: t('type_purchase_cat'), color: 'bg-orange-100 text-orange-700', icon: CreditCard },
    commission: { label: t('type_commission'), color: 'bg-violet-100 text-violet-700', icon: Banknote },
    transfer: { label: t('type_transfer'), color: 'bg-sky-100 text-sky-700', icon: ArrowUpDown },
  }), [t])

  const revenueData = useMemo(() => [
    { month: t('salaries_month_jan'), revenue: 4200, expenses: 2800 },
    { month: t('salaries_month_feb'), revenue: 5100, expenses: 3200 },
    { month: t('salaries_month_mar'), revenue: 4800, expenses: 2900 },
    { month: t('salaries_month_apr'), revenue: 6200, expenses: 3500 },
    { month: t('salaries_month_may'), revenue: 5800, expenses: 3100 },
    { month: t('salaries_month_jun'), revenue: 7100, expenses: 3800 },
  ], [t])

  const chartConfig = useMemo(() => ({
    revenue: { label: t('chart_revenue'), color: '#10b981' },
    expenses: { label: t('chart_expenses'), color: '#ef4444' },
  }), [t])

  const [transactions, setTransactions] = useState<Transaction[]>(() => getSampleTransactions(t))
  const [typeFilter, setTypeFilter] = useState<string>('all')
  const [dialogOpen, setDialogOpen] = useState(false)
  const [dialogType, setDialogType] = useState<'income' | 'expense' | 'bond'>('income')
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [form, setForm] = useState({
    type: 'income' as string,
    amount: '',
    description: '',
    category: '',
  })

  const businessId = getBusinessId()
  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'
  const formatCurrency = (amount: number) => amount.toLocaleString(locale, { minimumFractionDigits: 3, maximumFractionDigits: 3 })

  useEffect(() => {
    async function fetchTransactions() {
      setLoading(true)
      try {
        const params = new URLSearchParams()
        params.set('businessId', businessId)
        if (typeFilter !== 'all') params.set('type', typeFilter)
        const res = await fetch(`/api/accounting/transactions?${params.toString()}`)
        if (res.ok) {
          const data = await res.json()
          if (data.length > 0) setTransactions(data)
        }
      } catch {
        // Keep sample data
      } finally {
        setLoading(false)
      }
    }
    fetchTransactions()
  }, [businessId, typeFilter])

  const totalIncome = transactions.filter((tx) => tx.type === 'income').reduce((sum, tx) => sum + tx.amount, 0)
  const totalExpenses = transactions.filter((tx) => tx.type === 'expense' || tx.type === 'purchase').reduce((sum, tx) => sum + tx.amount, 0)
  const netProfit = totalIncome - totalExpenses

  const filteredTransactions =
    typeFilter === 'all' ? transactions : transactions.filter((tx) => tx.type === typeFilter)

  const openQuickAdd = (type: 'income' | 'expense' | 'bond') => {
    setDialogType(type)
    setForm({ type, amount: '', description: '', category: '' })
    setDialogOpen(true)
  }

  const handleAddTransaction = async () => {
    setSaving(true)
    try {
      const res = await fetch('/api/accounting/transactions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          type: dialogType === 'bond' ? 'transfer' : dialogType,
          amount: parseFloat(form.amount) || 0,
          description: form.description,
          category: form.category,
        }),
      })

      if (res.ok) {
        const saved = await res.json()
        setTransactions((prev) => [saved, ...prev])
        setDialogOpen(false)
        toast.success(dialogType === 'income' ? t('accounting_income_added') : dialogType === 'expense' ? t('accounting_expense_added') : t('accounting_bond_added'))
      } else {
        toast.error(t('accounting_add_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('nav_accounting')}</h2>
          <p className="text-muted-foreground">{t('accounting_subtitle')}</p>
        </div>
        <div className="flex items-center gap-2">
          <Link href="/shop/chart-of-accounts">
            <Button variant="outline" className="gap-1.5" size="sm">
              <BookOpen className="h-4 w-4" />
              {t('nav_chart_of_accounts')}
            </Button>
          </Link>
          <Button
            onClick={() => openQuickAdd('income')}
            variant="outline"
            className="gap-1.5 border-emerald-300 text-emerald-700 hover:bg-emerald-50"
            size="sm"
          >
            <TrendingUp className="h-4 w-4" />{t('accounting_income')}</Button>
          <Button
            onClick={() => openQuickAdd('expense')}
            variant="outline"
            className="gap-1.5 border-red-300 text-red-700 hover:bg-red-50"
            size="sm"
          >
            <TrendingDown className="h-4 w-4" />{t('accounting_expense_btn')}</Button>
          <Button
            onClick={() => openQuickAdd('bond')}
            variant="outline"
            className="gap-1.5 border-sky-300 text-sky-700 hover:bg-sky-50"
            size="sm"
          >
            <FileCheck className="h-4 w-4" />{t('accounting_bond')}</Button>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-100">
              <TrendingUp className="h-6 w-6 text-emerald-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('dashboard_total_revenue')}</p>
              <p className="text-2xl font-bold text-emerald-700">
                {totalIncome.toLocaleString(locale)} <span className="text-sm font-normal">{t('currency')}</span>
              </p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-red-100">
              <TrendingDown className="h-6 w-6 text-red-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('dashboard_total_expenses')}</p>
              <p className="text-2xl font-bold text-red-700">
                {totalExpenses.toLocaleString(locale)} <span className="text-sm font-normal">{t('currency')}</span>
              </p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className={`flex h-12 w-12 items-center justify-center rounded-xl ${netProfit >= 0 ? 'bg-emerald-100' : 'bg-red-100'}`}>
              <DollarSign className={`h-6 w-6 ${netProfit >= 0 ? 'text-emerald-600' : 'text-red-600'}`} />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('dashboard_net_profit')}</p>
              <p className={`text-2xl font-bold ${netProfit >= 0 ? 'text-emerald-700' : 'text-red-700'}`}>
                {netProfit.toLocaleString(locale)} <span className="text-sm font-normal">{t('currency')}</span>
              </p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Chart */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">{t('accounting_vs_expenses')}</CardTitle>
          <CardDescription>{t('accounting_monthly_performance')}</CardDescription>
        </CardHeader>
        <CardContent>
          <ChartContainer config={chartConfig} className="h-[240px] w-full">
            <BarChart data={revenueData}>
              <CartesianGrid strokeDasharray="3 3" vertical={false} />
              <XAxis dataKey="month" tickLine={false} axisLine={false} fontSize={12} />
              <YAxis tickLine={false} axisLine={false} fontSize={12} tickFormatter={(val) => `${val / 1000}${lang === 'ar' ? 'ك' : 'K'}`} />
              <ChartTooltip content={<ChartTooltipContent />} />
              <Bar dataKey="revenue" fill="#10b981" radius={[4, 4, 0, 0]} name={t('chart_revenue')} />
              <Bar dataKey="expenses" fill="#ef4444" radius={[4, 4, 0, 0]} name={t('chart_expenses')} />
            </BarChart>
          </ChartContainer>
        </CardContent>
      </Card>

      {/* Transactions List */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle className="text-base">{t('accounting_transactions_list')}</CardTitle>
            <CardDescription>{t('accounting_all_records')}</CardDescription>
          </div>
          <Select value={typeFilter} onValueChange={setTypeFilter}>
            <SelectTrigger className="w-40">
              <SelectValue placeholder={t('accounting_type_filter')} />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t('all')}</SelectItem>
              <SelectItem value="income">{t('type_income')}</SelectItem>
              <SelectItem value="expense">{t('type_expense')}</SelectItem>
              <SelectItem value="purchase">{t('type_purchase_cat')}</SelectItem>
              <SelectItem value="commission">{t('type_commission')}</SelectItem>
              <SelectItem value="transfer">{t('type_transfer')}</SelectItem>
            </SelectContent>
          </Select>
        </CardHeader>
        <CardContent className="p-0">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            </div>
          ) : filteredTransactions.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <Calculator className="h-12 w-12 mb-3 opacity-30" />
              <p>{t('accounting_no_transactions')}</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-right">{t('type')}</TableHead>
                    <TableHead className="text-right">{t('description')}</TableHead>
                    <TableHead className="text-right">{t('amount')}</TableHead>
                    <TableHead className="text-right">{t('accounting_category')}</TableHead>
                    <TableHead className="text-right">{t('date')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredTransactions.map((tx) => {
                    const typeInfo = typeMap[tx.type] || { label: tx.type, color: 'bg-gray-100 text-gray-700', icon: Calculator }
                    const Icon = typeInfo.icon
                    return (
                      <TableRow key={tx.id}>
                        <TableCell>
                          <div className="flex items-center gap-2">
                            <Icon className="h-4 w-4" />
                            <Badge variant="secondary" className={`text-xs ${typeInfo.color}`}>
                              {typeInfo.label}
                            </Badge>
                          </div>
                        </TableCell>
                        <TableCell className="text-sm">{tx.description || '—'}</TableCell>
                        <TableCell className={`font-medium ${tx.type === 'income' ? 'text-emerald-700' : 'text-red-700'}`}>
                          {tx.type === 'income' ? '+' : '-'}{tx.amount.toLocaleString(locale)} {t('currency')}
                        </TableCell>
                        <TableCell>
                          <Badge variant="outline" className="text-xs">
                            {tx.category || '—'}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-xs text-muted-foreground">
                          {new Date(tx.transactionDate || tx.createdAt).toLocaleDateString(locale)}
                        </TableCell>
                      </TableRow>
                    )
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Quick Add Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-md" dir={dir}>
          <DialogHeader>
            <DialogTitle>
              {dialogType === 'income' ? t('accounting_add_income') : dialogType === 'expense' ? t('accounting_add_expense') : t('accounting_add_bond')}
            </DialogTitle>
            <DialogDescription>{t('accounting_enter_data')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label>{t('amount')} *</Label>
              <Input
                type="number"
                value={form.amount}
                onChange={(e) => setForm({ ...form, amount: e.target.value })}
                placeholder="0"
              />
            </div>
            <div className="space-y-2">
              <Label>{t('description')}</Label>
              <Input
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                placeholder={t('accounting_description_placeholder')}
              />
            </div>
            <div className="space-y-2">
              <Label>{t('accounting_category')}</Label>
              <Select
                value={form.category}
                onValueChange={(val) => setForm({ ...form, category: val })}
              >
                <SelectTrigger>
                  <SelectValue placeholder={t('accounting_select_category')} />
                </SelectTrigger>
                <SelectContent>
                  {dialogType === 'income' && (
                    <>
                      <SelectItem value="sales">{t('accounting_cat_sales')}</SelectItem>
                      <SelectItem value="services">{t('accounting_cat_services')}</SelectItem>
                      <SelectItem value="other">{t('accounting_cat_other')}</SelectItem>
                    </>
                  )}
                  {dialogType === 'expense' && (
                    <>
                      <SelectItem value="materials">{t('accounting_cat_materials')}</SelectItem>
                      <SelectItem value="rent">{t('accounting_cat_rent')}</SelectItem>
                      <SelectItem value="salaries">{t('accounting_cat_salaries')}</SelectItem>
                      <SelectItem value="transport">{t('accounting_cat_transport')}</SelectItem>
                      <SelectItem value="other">{t('accounting_cat_other')}</SelectItem>
                    </>
                  )}
                  {dialogType === 'bond' && (
                    <>
                      <SelectItem value="transfers">{t('accounting_cat_transfers')}</SelectItem>
                      <SelectItem value="receipt">{t('bonds_receipt')}</SelectItem>
                      <SelectItem value="payment">{t('bonds_payment')}</SelectItem>
                    </>
                  )}
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setDialogOpen(false)}>{t('cancel')}</Button>
            <Button
              onClick={handleAddTransaction}
              className={
                dialogType === 'income'
                  ? 'bg-emerald-600 hover:bg-emerald-700'
                  : dialogType === 'expense'
                  ? 'bg-red-600 hover:bg-red-700'
                  : 'bg-sky-600 hover:bg-sky-700'
              }
              disabled={saving || !form.amount}
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {t('add')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
