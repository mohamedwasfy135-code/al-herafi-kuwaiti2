'use client'

import { useState, useEffect, useCallback, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'
import { TranslationKey } from '@/lib/i18n'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import {
  BookOpen,
  Landmark,
  Wallet,
  CreditCard,
  ArrowUpDown,
  Calculator,
  TrendingUp,
  TrendingDown,
  Search,
  RefreshCw,
  FileText,
  Receipt,
  CircleDollarSign,
  Building2,
  PiggyBank,
  Scale,
  ArrowDownUp,
  Plus,
  ExternalLink,
  Download,
  Printer,
} from 'lucide-react'
import * as XLSX from 'xlsx'

// ─── Types ───────────────────────────────────────────────────────────────────

interface SalesInvoice {
  id: number
  invoiceNumber: string
  clientName?: string
  total: number
  paidAmount: number
  paymentMethod?: string
  paymentDate?: string
  issuedAt?: string
  createdAt: string
  status: string
  notes?: string
}

interface PurchaseInvoice {
  id: number
  invoiceNumber: string
  supplierName?: string
  total: number
  paidAmount: number
  paymentMethod?: string
  paymentDate?: string
  issuedAt?: string
  createdAt: string
  status: string
  notes?: string
}

interface Bond {
  id: number
  bondNumber: string
  bondType: string
  amount: number
  partyName?: string
  description?: string
  paymentMethod?: string
  issuedDate?: string
  createdAt: string
  account?: { id: number; code: string; name: string }
}

interface SalesReturn {
  id: number
  total: number
  paymentMethod?: string
  paymentDate?: string
  createdAt: string
  status: string
}

interface PurchaseReturn {
  id: number
  total: number
  paymentMethod?: string
  paymentDate?: string
  createdAt: string
  status: string
}

interface Salary {
  id: number
  amount?: number
  netSalary?: number
  basicSalary?: number
  allowances?: number
  deductions?: number
  paymentMethod?: string
  paymentDate?: string
  paidDate?: string
  createdAt: string
  description?: string
  status?: string
  month?: number
  year?: number
  employeeId?: number
  employee?: { id: number; name: string; position?: string; department?: string }
  employeeName?: string
  account?: { id: number; name: string; code: string }
}

interface Rent {
  id: number
  amount: number
  propertyOwner?: string
  propertyDesc?: string
  paymentMethod?: string
  paymentDate?: string
  createdAt: string
  description?: string
  account?: { id: number; name: string; code: string }
}

interface Account {
  id: number
  code: string
  name: string
  type: string
  openingBalance: number
  currentBalance: number
  description?: string
}

interface LedgerEntry {
  id: string
  date: string
  description: string
  referenceNumber: string
  type: 'sales' | 'purchase' | 'bond_receipt' | 'bond_payment' | 'sales_return' | 'purchase_return' | 'salary' | 'rent'
  transactionCategory: 'voucher' | 'invoice' // سند or فاتورة
  debit: number
  credit: number
  paymentMethod: string
  balance: number // running balance
  sourceId: number // ID of the source entity for navigation
  sourcePath: string // navigation path to the source page
}

interface ChannelSummary {
  totalDebit: number
  totalCredit: number
  netBalance: number
  count: number
}

// ─── Payment method config ───────────────────────────────────────────────────

type PaymentChannel = 'bank' | 'cash' | 'knet'

const channelConfig: Record<PaymentChannel, { key: string; labelKey: TranslationKey; icon: React.ElementType; color: string; bgColor: string; borderColor: string; textColor: string; badgeColor: string; headerBg: string }> = {
  bank: {
    key: 'bank',
    labelKey: 'ledger_bank',
    icon: Landmark,
    color: 'sky',
    bgColor: 'bg-sky-50',
    borderColor: 'border-sky-200',
    textColor: 'text-sky-700',
    badgeColor: 'bg-sky-100 text-sky-700 border-sky-200',
    headerBg: 'bg-sky-600',
  },
  cash: {
    key: 'cash',
    labelKey: 'ledger_cash',
    icon: Wallet,
    color: 'amber',
    bgColor: 'bg-amber-50',
    borderColor: 'border-amber-200',
    textColor: 'text-amber-700',
    badgeColor: 'bg-amber-100 text-amber-700 border-amber-200',
    headerBg: 'bg-amber-600',
  },
  knet: {
    key: 'knet',
    labelKey: 'ledger_knet',
    icon: CreditCard,
    color: 'purple',
    bgColor: 'bg-purple-50',
    borderColor: 'border-purple-200',
    textColor: 'text-purple-700',
    badgeColor: 'bg-purple-100 text-purple-700 border-purple-200',
    headerBg: 'bg-purple-600',
  },
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function formatCurrency(amount: number, lang: string = 'ar'): string {
  const locale = lang === 'en' ? 'en-KW' : 'ar-KW'
  return amount.toLocaleString(locale, { minimumFractionDigits: 3, maximumFractionDigits: 3 })
}

function formatDate(dateStr?: string, lang: string = 'ar'): string {
  if (!dateStr) return '—'
  try {
    const d = new Date(dateStr)
    const locale = lang === 'en' ? 'en-KW' : 'ar-KW'
    return d.toLocaleDateString(locale, {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    })
  } catch {
    return '—'
  }
}

function getCategoryForType(type: LedgerEntry['type']): 'voucher' | 'invoice' {
  switch (type) {
    case 'bond_receipt':
    case 'bond_payment':
    case 'salary':
    case 'rent':
      return 'voucher'
    case 'sales':
    case 'purchase':
    case 'sales_return':
    case 'purchase_return':
      return 'invoice'
  }
}

// ─── Component ───────────────────────────────────────────────────────────────

export default function GeneralLedgerPage() {
  const router = useRouter()
  const { t, lang, dir } = useLanguage()
  const [businessId, setBusinessId] = useState<string>('')
  const [loading, setLoading] = useState(true)
  const [salesInvoices, setSalesInvoices] = useState<SalesInvoice[]>([])
  const [purchaseInvoices, setPurchaseInvoices] = useState<PurchaseInvoice[]>([])
  const [bonds, setBonds] = useState<Bond[]>([])
  const [salesReturns, setSalesReturns] = useState<SalesReturn[]>([])
  const [purchaseReturns, setPurchaseReturns] = useState<PurchaseReturn[]>([])
  const [salaries, setSalaries] = useState<Salary[]>([])
  const [rents, setRents] = useState<Rent[]>([])
  const [accounts, setAccounts] = useState<Account[]>([])
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [activeTab, setActiveTab] = useState<string>('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [typeFilter, setTypeFilter] = useState<string>('all')
  const [capitalForm, setCapitalForm] = useState({ accountId: '', amount: '', description: '', type: 'contribution' as 'contribution' | 'withdrawal' })

  // Get businessId on mount
  useEffect(() => {
    const bid = getBusinessId()
    setBusinessId(bid)
  }, [])

  // Fetch data
  const fetchData = useCallback(async () => {
    if (!businessId) return
    setLoading(true)
    try {
      const [salesRes, purchaseRes, bondsRes, salesReturnsRes, purchaseReturnsRes, salariesRes, rentsRes, accountsRes] = await Promise.all([
        fetch(`/api/invoices/sales?businessId=${businessId}`),
        fetch(`/api/invoices/purchase?businessId=${businessId}`),
        fetch(`/api/bonds?businessId=${businessId}`),
        fetch(`/api/invoices/sales-returns?businessId=${businessId}`),
        fetch(`/api/invoices/purchase-returns?businessId=${businessId}`),
        fetch(`/api/salaries?businessId=${businessId}`),
        fetch(`/api/rents?businessId=${businessId}`),
        fetch(`/api/accounts?businessId=${businessId}`),
      ])

      if (salesRes.ok) setSalesInvoices(await salesRes.json())
      if (purchaseRes.ok) setPurchaseInvoices(await purchaseRes.json())
      if (bondsRes.ok) setBonds(await bondsRes.json())
      if (salesReturnsRes.ok) setSalesReturns(await salesReturnsRes.json())
      if (purchaseReturnsRes.ok) setPurchaseReturns(await purchaseReturnsRes.json())
      if (salariesRes.ok) setSalaries(await salariesRes.json())
      if (rentsRes.ok) setRents(await rentsRes.json())
      if (accountsRes.ok) setAccounts(await accountsRes.json())
    } catch (err) {
      console.error('Error fetching ledger data:', err)
    } finally {
      setLoading(false)
    }
  }, [businessId])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  // Helper to resolve payment method, defaulting to 'cash' if missing
  const resolvePaymentMethod = (pm: string | undefined): PaymentChannel => {
    if (pm && channelConfig[pm as PaymentChannel]) return pm as PaymentChannel
    return 'cash'
  }

  // Build ledger entries grouped by payment channel
  const { entriesByChannel, allEntries } = useMemo(() => {
    const byChannel: Record<PaymentChannel, LedgerEntry[]> = {
      bank: [],
      cash: [],
      knet: [],
    }

    // Process sales invoices → credit (دائن) entries
    for (const inv of salesInvoices) {
      const pm = resolvePaymentMethod(inv.paymentMethod)

      const date = inv.paymentDate || inv.issuedAt || inv.createdAt
      byChannel[pm].push({
        id: `sales-${inv.id}`,
        date,
        description: `${t('type_sale')}${inv.clientName ? ` - ${inv.clientName}` : ''}`,
        referenceNumber: inv.invoiceNumber,
        type: 'sales',
        transactionCategory: 'invoice',
        debit: 0,
        credit: inv.paidAmount || 0,
        paymentMethod: pm,
        balance: 0,
        sourceId: inv.id,
        sourcePath: `/shop/sales-invoices?open=${inv.id}`,
      })
    }

    // Process purchase invoices → debit (مدين) entries
    for (const inv of purchaseInvoices) {
      const pm = resolvePaymentMethod(inv.paymentMethod)

      const date = inv.paymentDate || inv.issuedAt || inv.createdAt
      byChannel[pm].push({
        id: `purchase-${inv.id}`,
        date,
        description: `${t('type_purchase')}${inv.supplierName ? ` - ${inv.supplierName}` : ''}`,
        referenceNumber: inv.invoiceNumber,
        type: 'purchase',
        transactionCategory: 'invoice',
        debit: inv.paidAmount || 0,
        credit: 0,
        paymentMethod: pm,
        balance: 0,
        sourceId: inv.id,
        sourcePath: `/shop/purchase-invoices?open=${inv.id}`,
      })
    }

    // Process bonds
    for (const bond of bonds) {
      const pm = resolvePaymentMethod(bond.paymentMethod)

      const date = bond.issuedDate || bond.createdAt
      const isReceipt = bond.bondType === 'receipt'

      byChannel[pm].push({
        id: `bond-${bond.id}`,
        date,
        description: `${isReceipt ? t('type_receipt') : t('type_payment')}${bond.partyName ? ` - ${bond.partyName}` : ''}`,
        referenceNumber: bond.bondNumber,
        type: isReceipt ? 'bond_receipt' : 'bond_payment',
        transactionCategory: 'voucher',
        debit: isReceipt ? 0 : bond.amount,
        credit: isReceipt ? bond.amount : 0,
        paymentMethod: pm,
        balance: 0,
        sourceId: bond.id,
        sourcePath: `/shop/bonds?open=${bond.id}`,
      })
    }

    // Process sales returns → debit entries (reversal of sale)
    for (const sr of salesReturns) {
      const pm = resolvePaymentMethod(sr.paymentMethod)

      const date = sr.paymentDate || sr.createdAt
      byChannel[pm].push({
        id: `sales-return-${sr.id}`,
        date,
        description: t('type_sales_return'),
        referenceNumber: `SR-${sr.id}`,
        type: 'sales_return',
        transactionCategory: 'invoice',
        debit: sr.total || 0,
        credit: 0,
        paymentMethod: pm,
        balance: 0,
        sourceId: sr.id,
        sourcePath: `/shop/sales-returns?open=${sr.id}`,
      })
    }

    // Process purchase returns → credit entries (reversal of purchase)
    for (const pr of purchaseReturns) {
      const pm = resolvePaymentMethod(pr.paymentMethod)

      const date = pr.paymentDate || pr.createdAt
      byChannel[pm].push({
        id: `purchase-return-${pr.id}`,
        date,
        description: t('type_purchase_return'),
        referenceNumber: `PR-${pr.id}`,
        type: 'purchase_return',
        transactionCategory: 'invoice',
        debit: 0,
        credit: pr.total || 0,
        paymentMethod: pm,
        balance: 0,
        sourceId: pr.id,
        sourcePath: `/shop/purchase-returns?open=${pr.id}`,
      })
    }

    // Process salaries → debit entries (expense)
    // Only show PAID salaries
    for (const sal of salaries) {
      if (sal.status !== 'paid') continue

      const pm = resolvePaymentMethod(sal.paymentMethod)

      const date = sal.paymentDate || sal.paidDate || sal.createdAt
      const empName = sal.employee?.name || sal.employeeName
      byChannel[pm].push({
        id: `salary-${sal.id}`,
        date,
        description: `${t('ledger_salary_payment')}${empName ? ` - ${empName}` : ''}`,
        referenceNumber: `SAL-${sal.id}`,
        type: 'salary',
        transactionCategory: 'voucher',
        debit: sal.netSalary || sal.amount || 0,
        credit: 0,
        paymentMethod: pm,
        balance: 0,
        sourceId: sal.id,
        sourcePath: `/shop/salaries?open=${sal.id}`,
      })
    }

    // Process rents → debit entries (expense)
    // Only show PAID rents (those with a paymentDate set)
    for (const r of rents) {
      if (!r.paymentDate) continue

      const pm = resolvePaymentMethod(r.paymentMethod)

      const date = r.paymentDate || r.createdAt
      byChannel[pm].push({
        id: `rent-${r.id}`,
        date,
        description: `${t('ledger_rent_payment')}${r.propertyOwner ? ` - ${t('ledger_property_owner')}: ${r.propertyOwner}` : ''}`,
        referenceNumber: `RNT-${r.id}`,
        type: 'rent',
        transactionCategory: 'voucher',
        debit: r.amount || 0,
        credit: 0,
        paymentMethod: pm,
        balance: 0,
        sourceId: r.id,
        sourcePath: `/shop/rents?open=${r.id}`,
      })
    }

    // Sort each channel by date and calculate running balance
    const sortedEntries: LedgerEntry[] = []
    for (const channel of Object.keys(byChannel) as PaymentChannel[]) {
      byChannel[channel].sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())

      // Apply date filter
      let filtered = byChannel[channel]
      if (dateFrom) {
        const from = new Date(dateFrom)
        filtered = filtered.filter((e) => new Date(e.date) >= from)
      }
      if (dateTo) {
        const to = new Date(dateTo)
        to.setHours(23, 59, 59, 999)
        filtered = filtered.filter((e) => new Date(e.date) <= to)
      }
      byChannel[channel] = filtered

      // Calculate running balance (credit - debit)
      let runningBalance = 0
      for (const entry of byChannel[channel]) {
        runningBalance += entry.credit - entry.debit
        entry.balance = runningBalance
      }

      sortedEntries.push(...byChannel[channel])
    }

    // Sort all entries by date
    sortedEntries.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())

    // Recalculate running balance for all entries combined
    let allRunningBalance = 0
    for (const entry of sortedEntries) {
      allRunningBalance += entry.credit - entry.debit
      // Don't override per-channel balance; use a separate field for all-tab
    }

    return { entriesByChannel: byChannel, allEntries: sortedEntries }
  }, [salesInvoices, purchaseInvoices, bonds, salesReturns, purchaseReturns, salaries, rents, dateFrom, dateTo, t])

  // Apply search & type filter
  const filteredEntriesByChannel = useMemo(() => {
    const result: Record<PaymentChannel, LedgerEntry[]> = { bank: [], cash: [], knet: [] }
    for (const channel of Object.keys(entriesByChannel) as PaymentChannel[]) {
      let entries = entriesByChannel[channel]
      // Apply type filter
      if (typeFilter !== 'all') {
        entries = entries.filter((e) => e.type === typeFilter)
      }
      // Apply search filter
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase()
        entries = entries.filter(
          (e) =>
            e.description.toLowerCase().includes(q) ||
            e.referenceNumber.toLowerCase().includes(q) ||
            String(e.debit).includes(q) ||
            String(e.credit).includes(q)
        )
      }
      result[channel] = entries
    }
    return result
  }, [entriesByChannel, searchQuery, typeFilter])

  const filteredAllEntries = useMemo(() => {
    let entries = allEntries
    // Apply type filter
    if (typeFilter !== 'all') {
      entries = entries.filter((e) => e.type === typeFilter)
    }
    // Apply search filter
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase()
      entries = entries.filter(
        (e) =>
          e.description.toLowerCase().includes(q) ||
          e.referenceNumber.toLowerCase().includes(q) ||
          String(e.debit).includes(q) ||
          String(e.credit).includes(q)
      )
    }
    return entries
  }, [allEntries, searchQuery, typeFilter])

  // Calculate summaries
  const summaries = useMemo(() => {
    const result: Record<PaymentChannel, ChannelSummary> = {
      bank: { totalDebit: 0, totalCredit: 0, netBalance: 0, count: 0 },
      cash: { totalDebit: 0, totalCredit: 0, netBalance: 0, count: 0 },
      knet: { totalDebit: 0, totalCredit: 0, netBalance: 0, count: 0 },
    }
    for (const channel of Object.keys(filteredEntriesByChannel) as PaymentChannel[]) {
      const entries = filteredEntriesByChannel[channel]
      result[channel] = {
        totalDebit: entries.reduce((s, e) => s + e.debit, 0),
        totalCredit: entries.reduce((s, e) => s + e.credit, 0),
        netBalance: entries.reduce((s, e) => s + e.credit - e.debit, 0),
        count: entries.length,
      }
    }
    return result
  }, [filteredEntriesByChannel])

  const grandSummary = useMemo(() => {
    const totalDebit = (summaries.bank.totalDebit + summaries.cash.totalDebit + summaries.knet.totalDebit)
    const totalCredit = (summaries.bank.totalCredit + summaries.cash.totalCredit + summaries.knet.totalCredit)
    return {
      totalDebit,
      totalCredit,
      netBalance: totalCredit - totalDebit,
      count: summaries.bank.count + summaries.cash.count + summaries.knet.count,
    }
  }, [summaries])

  // Account-based summary - using i18n labels
  const accountSummary = useMemo(() => {
    const typeMap: Record<string, { labelKey: TranslationKey; icon: React.ElementType; bgColor: string; borderColor: string; textColor: string; iconBg: string; iconColor: string }> = {
      asset: { labelKey: 'account_asset', icon: Building2, bgColor: 'bg-blue-50', borderColor: 'border-blue-200', textColor: 'text-blue-800', iconBg: 'bg-blue-100', iconColor: 'text-blue-600' },
      liability: { labelKey: 'account_liability', icon: Scale, bgColor: 'bg-red-50', borderColor: 'border-red-200', textColor: 'text-red-800', iconBg: 'bg-red-100', iconColor: 'text-red-600' },
      equity: { labelKey: 'account_equity', icon: PiggyBank, bgColor: 'bg-violet-50', borderColor: 'border-violet-200', textColor: 'text-violet-800', iconBg: 'bg-violet-100', iconColor: 'text-violet-600' },
      revenue: { labelKey: 'account_revenue', icon: TrendingUp, bgColor: 'bg-emerald-50', borderColor: 'border-emerald-200', textColor: 'text-emerald-800', iconBg: 'bg-emerald-100', iconColor: 'text-emerald-600' },
      expense: { labelKey: 'account_expense', icon: TrendingDown, bgColor: 'bg-orange-50', borderColor: 'border-orange-200', textColor: 'text-orange-800', iconBg: 'bg-orange-100', iconColor: 'text-orange-600' },
    }
    const summary: Record<string, { totalBalance: number; count: number }> = {}
    for (const acc of accounts) {
      const accType = acc.type || 'asset'
      if (!summary[accType]) summary[accType] = { totalBalance: 0, count: 0 }
      summary[accType].totalBalance += acc.currentBalance || 0
      summary[accType].count += 1
    }
    return { typeMap, summary }
  }, [accounts])

  const equityAccounts = useMemo(() => accounts.filter((a) => a.type === 'equity'), [accounts])

  // ─── Export handlers ─────────────────────────────────────────────────────────

  const handleExportExcel = useCallback(() => {
    const entries = activeTab === 'all' ? filteredAllEntries : (filteredEntriesByChannel[activeTab as PaymentChannel] || [])

    // Sheet 1: All Transactions with running balance
    let rb = 0
    const transactionsWithBalance = entries.map((entry) => {
      rb += entry.credit - entry.debit
      return {
        [t('date')]: formatDate(entry.date, lang),
        [t('ledger_description_col')]: entry.description,
        [t('ledger_reference')]: entry.referenceNumber,
        [t('ledger_type')]: getTypeBadge(entry.type)?.label || '',
        [t('ledger_transaction_type')]: entry.transactionCategory === 'voucher' ? t('ledger_voucher') : t('ledger_invoice'),
        [t('ledger_debit')]: entry.debit,
        [t('ledger_credit')]: entry.credit,
        [t('ledger_balance')]: rb,
      }
    })

    // Sheet 2: Summary by Channel
    const channelSummaryData = (Object.keys(channelConfig) as PaymentChannel[]).map((channel) => {
      const config = channelConfig[channel]
      const cs = summaries[channel]
      return {
        [t('ledger_payment_channel')]: t(config.labelKey),
        [t('ledger_debit')]: cs.totalDebit,
        [t('ledger_credit')]: cs.totalCredit,
        [t('ledger_balance')]: cs.netBalance,
        [t('ledger_transactions_count')]: cs.count,
      }
    })
    // Add grand total row
    channelSummaryData.push({
      [t('ledger_payment_channel')]: t('ledger_grand_total'),
      [t('ledger_debit')]: grandSummary.totalDebit,
      [t('ledger_credit')]: grandSummary.totalCredit,
      [t('ledger_balance')]: grandSummary.netBalance,
      [t('ledger_transactions_count')]: grandSummary.count,
    })

    // Sheet 3: Account Summary
    const { typeMap: accTypeMap, summary: accSummary } = accountSummary
    const accountSummaryData = Object.keys(accTypeMap).map((type) => {
      const config = accTypeMap[type]
      const data = accSummary[type]
      return {
        [t('ledger_type')]: t(config.labelKey),
        [t('ledger_balance')]: data?.totalBalance || 0,
        [t('ledger_accounts')]: data?.count || 0,
      }
    })

    const wb = XLSX.utils.book_new()

    const ws1 = XLSX.utils.json_to_sheet(transactionsWithBalance)
    // Set column widths
    ws1['!cols'] = [
      { wch: 14 }, { wch: 30 }, { wch: 14 }, { wch: 12 }, { wch: 12 }, { wch: 14 }, { wch: 14 }, { wch: 14 },
    ]
    XLSX.utils.book_append_sheet(wb, ws1, lang === 'ar' ? 'المعاملات' : 'Transactions')

    const ws2 = XLSX.utils.json_to_sheet(channelSummaryData)
    ws2['!cols'] = [
      { wch: 18 }, { wch: 14 }, { wch: 14 }, { wch: 14 }, { wch: 14 },
    ]
    XLSX.utils.book_append_sheet(wb, ws2, lang === 'ar' ? 'ملخص القنوات' : 'Channel Summary')

    if (accountSummaryData.length > 0) {
      const ws3 = XLSX.utils.json_to_sheet(accountSummaryData)
      ws3['!cols'] = [
        { wch: 18 }, { wch: 14 }, { wch: 10 },
      ]
      XLSX.utils.book_append_sheet(wb, ws3, lang === 'ar' ? 'ملخص الحسابات' : 'Account Summary')
    }

    const today = new Date().toISOString().slice(0, 10)
    XLSX.writeFile(wb, `ledger-${today}.xlsx`)
  }, [filteredAllEntries, filteredEntriesByChannel, summaries, grandSummary, accountSummary, activeTab, t, lang])

  const handlePrint = useCallback(() => {
    window.print()
  }, [])

  // ─── Type badge helper using i18n ─────────────────────────────────────────

  const getTypeBadge = (type: LedgerEntry['type']) => {
    switch (type) {
      case 'sales':
        return { label: t('type_sale'), className: 'bg-emerald-100 text-emerald-700 border-emerald-200' }
      case 'purchase':
        return { label: t('type_purchase'), className: 'bg-orange-100 text-orange-700 border-orange-200' }
      case 'bond_receipt':
        return { label: t('type_receipt'), className: 'bg-teal-100 text-teal-700 border-teal-200' }
      case 'bond_payment':
        return { label: t('type_payment'), className: 'bg-rose-100 text-rose-700 border-rose-200' }
      case 'sales_return':
        return { label: t('type_sales_return'), className: 'bg-pink-100 text-pink-700 border-pink-200' }
      case 'purchase_return':
        return { label: t('type_purchase_return'), className: 'bg-cyan-100 text-cyan-700 border-cyan-200' }
      case 'salary':
        return { label: t('type_salary'), className: 'bg-indigo-100 text-indigo-700 border-indigo-200' }
      case 'rent':
        return { label: t('type_rent'), className: 'bg-lime-100 text-lime-700 border-lime-200' }
    }
  }

  // ─── Render helpers ─────────────────────────────────────────────────────────

  const renderSummaryCards = () => (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
      {/* Bank */}
      <Card className="border-sky-200 bg-gradient-to-br from-sky-50 to-white">
        <CardContent className="p-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="p-1.5 rounded-md bg-sky-100">
              <Landmark className="h-4 w-4 text-sky-600" />
            </div>
            <span className="text-sm font-semibold text-sky-700">{t('ledger_bank')}</span>
          </div>
          <p className="text-xl font-bold text-sky-800">
            {formatCurrency(summaries.bank.netBalance, lang)}
            <span className="text-xs font-normal text-sky-500 mr-1">{t('currency')}</span>
          </p>
          <p className="text-xs text-sky-500 mt-1">{summaries.bank.count} {t('ledger_transactions')}</p>
        </CardContent>
      </Card>

      {/* Cash */}
      <Card className="border-amber-200 bg-gradient-to-br from-amber-50 to-white">
        <CardContent className="p-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="p-1.5 rounded-md bg-amber-100">
              <Wallet className="h-4 w-4 text-amber-600" />
            </div>
            <span className="text-sm font-semibold text-amber-700">{t('ledger_cash')}</span>
          </div>
          <p className="text-xl font-bold text-amber-800">
            {formatCurrency(summaries.cash.netBalance, lang)}
            <span className="text-xs font-normal text-amber-500 mr-1">{t('currency')}</span>
          </p>
          <p className="text-xs text-amber-500 mt-1">{summaries.cash.count} {t('ledger_transactions')}</p>
        </CardContent>
      </Card>

      {/* KNet */}
      <Card className="border-purple-200 bg-gradient-to-br from-purple-50 to-white">
        <CardContent className="p-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="p-1.5 rounded-md bg-purple-100">
              <CreditCard className="h-4 w-4 text-purple-600" />
            </div>
            <span className="text-sm font-semibold text-purple-700">{t('ledger_knet')}</span>
          </div>
          <p className="text-xl font-bold text-purple-800">
            {formatCurrency(summaries.knet.netBalance, lang)}
            <span className="text-xs font-normal text-purple-500 mr-1">{t('currency')}</span>
          </p>
          <p className="text-xs text-purple-500 mt-1">{summaries.knet.count} {t('ledger_transactions')}</p>
        </CardContent>
      </Card>

      {/* Grand Total */}
      <Card className="border-emerald-200 bg-gradient-to-br from-emerald-50 to-white">
        <CardContent className="p-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="p-1.5 rounded-md bg-emerald-100">
              <CircleDollarSign className="h-4 w-4 text-emerald-600" />
            </div>
            <span className="text-sm font-semibold text-emerald-700">{t('total')}</span>
          </div>
          <p className="text-xl font-bold text-emerald-800">
            {formatCurrency(grandSummary.netBalance, lang)}
            <span className="text-xs font-normal text-emerald-500 mr-1">{t('currency')}</span>
          </p>
          <p className="text-xs text-emerald-500 mt-1">{grandSummary.count} {t('ledger_transactions')}</p>
        </CardContent>
      </Card>
    </div>
  )

  const renderAccountSummaryCards = () => {
    const { typeMap, summary } = accountSummary
    const types = Object.keys(typeMap)
    if (types.length === 0 || Object.keys(summary).length === 0) return null

    return (
      <div className="mb-6">
        <h3 className="text-sm font-semibold text-gray-600 mb-3 flex items-center gap-2">
          <ArrowDownUp className="h-4 w-4" />
          {t('ledger_account_summary')}
        </h3>
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
          {types.map((type) => {
            const config = typeMap[type]
            const data = summary[type]
            if (!data) return null
            const Icon = config.icon
            return (
              <Card key={type} className={`border ${config.borderColor} ${config.bgColor}`}>
                <CardContent className="p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <div className={`p-1.5 rounded-md ${config.iconBg}`}>
                      <Icon className={`h-4 w-4 ${config.iconColor}`} />
                    </div>
                    <span className={`text-sm font-semibold ${config.textColor}`}>{t(config.labelKey)}</span>
                  </div>
                  <p className={`text-lg font-bold ${config.textColor}`}>
                    {formatCurrency(data.totalBalance, lang)}
                    <span className={`text-xs font-normal ml-1 opacity-70`}>{t('currency')}</span>
                  </p>
                  <p className="text-xs text-gray-500 mt-1">{data.count} {t('ledger_accounts')}</p>
                </CardContent>
              </Card>
            )
          })}
        </div>
      </div>
    )
  }

  const renderLedgerTable = (entries: LedgerEntry[], showChannel = false) => {
    if (entries.length === 0) {
      return (
        <div className="text-center py-16 text-muted-foreground">
          <BookOpen className="h-12 w-12 mx-auto mb-3 opacity-30" />
          <p className="text-lg font-medium">{t('ledger_no_transactions')}</p>
          <p className="text-sm">{t('ledger_no_transactions_desc')}</p>
        </div>
      )
    }

    // Calculate running balance for the displayed entries
    let runningBalance = 0

    return (
      <div className="overflow-x-auto">
        <Table>
          <TableHeader>
            <TableRow className="bg-gray-50 hover:bg-gray-50">
              <TableHead className="text-center font-bold text-gray-600 w-[100px]">{t('date')}</TableHead>
              {showChannel && (
                <TableHead className="text-center font-bold text-gray-600 w-[80px]">{t('ledger_channel')}</TableHead>
              )}
              <TableHead className="text-center font-bold text-gray-600">{t('ledger_description_col')}</TableHead>
              <TableHead className="text-center font-bold text-gray-600 w-[110px]">{t('ledger_reference')}</TableHead>
              <TableHead className="text-center font-bold text-gray-600 w-[60px]">{t('ledger_type')}</TableHead>
              <TableHead className="text-center font-bold text-gray-600 w-[70px]">{t('ledger_transaction_type')}</TableHead>
              <TableHead className="text-center font-bold text-gray-600 w-[120px]">{t('ledger_debit')}</TableHead>
              <TableHead className="text-center font-bold text-gray-600 w-[120px]">{t('ledger_credit')}</TableHead>
              <TableHead className="text-center font-bold text-gray-600 w-[120px]">{t('ledger_balance')}</TableHead>
              <TableHead className="text-center font-bold text-gray-600 w-[60px]">{t('ledger_open')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {entries.map((entry) => {
              runningBalance += entry.credit - entry.debit
              const badge = getTypeBadge(entry.type)
              const categoryLabel = entry.transactionCategory === 'voucher' ? t('ledger_voucher') : t('ledger_invoice')
              const categoryClassName = entry.transactionCategory === 'voucher'
                ? 'bg-gray-100 text-gray-600 border-gray-300'
                : 'bg-blue-50 text-blue-600 border-blue-200'

              return (
                <TableRow key={entry.id} className="hover:bg-gray-50/50 transition-colors">
                  <TableCell className="text-center text-sm whitespace-nowrap">
                    {formatDate(entry.date, lang)}
                  </TableCell>
                  {showChannel && (
                    <TableCell className="text-center">
                      {channelConfig[entry.paymentMethod as PaymentChannel] && (
                        <Badge
                          variant="outline"
                          className={channelConfig[entry.paymentMethod as PaymentChannel].badgeColor}
                        >
                          {t(channelConfig[entry.paymentMethod as PaymentChannel].labelKey)}
                        </Badge>
                      )}
                    </TableCell>
                  )}
                  <TableCell className="text-sm font-medium">{entry.description}</TableCell>
                  <TableCell className="text-center text-sm font-mono">
                    <button
                      type="button"
                      onClick={() => router.push(entry.sourcePath)}
                      className="text-emerald-600 hover:text-emerald-800 hover:underline font-mono cursor-pointer transition-colors"
                      title={t('ledger_open_source')}
                    >
                      {entry.referenceNumber}
                    </button>
                  </TableCell>
                  <TableCell className="text-center">
                    <Badge variant="outline" className={badge.className}>
                      {badge.label}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-center">
                    <Badge variant="outline" className={`text-[10px] ${categoryClassName}`}>
                      {categoryLabel}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-center font-mono text-sm">
                    {entry.debit > 0 ? (
                      <span className="text-rose-600 font-semibold">{formatCurrency(entry.debit, lang)}</span>
                    ) : (
                      <span className="text-gray-300">—</span>
                    )}
                  </TableCell>
                  <TableCell className="text-center font-mono text-sm">
                    {entry.credit > 0 ? (
                      <span className="text-emerald-600 font-semibold">{formatCurrency(entry.credit, lang)}</span>
                    ) : (
                      <span className="text-gray-300">—</span>
                    )}
                  </TableCell>
                  <TableCell className="text-center font-mono text-sm font-semibold">
                    <span className={runningBalance >= 0 ? 'text-emerald-700' : 'text-rose-700'}>
                      {formatCurrency(Math.abs(runningBalance), lang)}
                      {runningBalance < 0 && <span className="text-xs mr-0.5">{t('type_debit_marker')}</span>}
                    </span>
                  </TableCell>
                  <TableCell className="text-center">
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-7 w-7 p-0 text-emerald-600 hover:text-emerald-800 hover:bg-emerald-50"
                      onClick={() => router.push(entry.sourcePath)}
                      title={t('ledger_open_source')}
                    >
                      <ExternalLink className="h-3.5 w-3.5" />
                    </Button>
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      </div>
    )
  }

  const renderChannelSubtotal = (channel: PaymentChannel) => {
    const channelSummary = summaries[channel]
    const config = channelConfig[channel]
    const Icon = config.icon

    return (
      <div className={`rounded-lg border ${config.borderColor} ${config.bgColor} p-4 mt-4`}>
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-2">
            <Icon className={`h-5 w-5 ${config.textColor}`} />
            <span className={`font-bold ${config.textColor}`}>{t('ledger_total_channel')} {t(config.labelKey)}</span>
          </div>
          <div className="flex items-center gap-6 text-sm">
            <div className="text-center">
              <p className="text-muted-foreground text-xs">{t('ledger_debit')}</p>
              <p className="font-bold text-rose-600">{formatCurrency(channelSummary.totalDebit, lang)}</p>
            </div>
            <div className="text-center">
              <p className="text-muted-foreground text-xs">{t('ledger_credit')}</p>
              <p className="font-bold text-emerald-600">{formatCurrency(channelSummary.totalCredit, lang)}</p>
            </div>
            <div className="text-center">
              <p className="text-muted-foreground text-xs">{t('ledger_balance')}</p>
              <p className={`font-bold ${channelSummary.netBalance >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                {formatCurrency(Math.abs(channelSummary.netBalance), lang)}
                {channelSummary.netBalance < 0 && <span className="text-xs mr-0.5">{t('type_debit_marker')}</span>}
              </p>
            </div>
            <div className="text-center">
              <p className="text-muted-foreground text-xs">{t('ledger_transactions_count')}</p>
              <p className="font-bold text-gray-700">{channelSummary.count}</p>
            </div>
          </div>
        </div>
      </div>
    )
  }

  const renderGrandTotal = () => (
    <Card className="border-emerald-300 bg-gradient-to-l from-emerald-50 to-teal-50 mt-6">
      <CardHeader className="pb-3">
        <CardTitle className="flex items-center gap-2 text-emerald-800 text-base">
          <Calculator className="h-5 w-5" />
          {t('ledger_summary')}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow className="bg-emerald-100/60 hover:bg-emerald-100/60">
                <TableHead className="text-center font-bold text-emerald-800">{t('ledger_payment_channel')}</TableHead>
                <TableHead className="text-center font-bold text-emerald-800">{t('ledger_debit')}</TableHead>
                <TableHead className="text-center font-bold text-emerald-800">{t('ledger_credit')}</TableHead>
                <TableHead className="text-center font-bold text-emerald-800">{t('ledger_balance')}</TableHead>
                <TableHead className="text-center font-bold text-emerald-800">{t('ledger_transactions_count')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {(Object.keys(channelConfig) as PaymentChannel[]).map((channel) => {
                const config = channelConfig[channel]
                const channelSummary = summaries[channel]
                const Icon = config.icon

                return (
                  <TableRow key={channel} className="hover:bg-emerald-50/50">
                    <TableCell className="text-center">
                      <div className="flex items-center justify-center gap-2">
                        <Icon className={`h-4 w-4 ${config.textColor}`} />
                        <Badge variant="outline" className={config.badgeColor}>
                          {t(config.labelKey)}
                        </Badge>
                      </div>
                    </TableCell>
                    <TableCell className="text-center font-mono font-semibold text-rose-600">
                      {formatCurrency(channelSummary.totalDebit, lang)}
                    </TableCell>
                    <TableCell className="text-center font-mono font-semibold text-emerald-600">
                      {formatCurrency(channelSummary.totalCredit, lang)}
                    </TableCell>
                    <TableCell className="text-center font-mono font-bold">
                      <span className={channelSummary.netBalance >= 0 ? 'text-emerald-700' : 'text-rose-700'}>
                        {formatCurrency(Math.abs(channelSummary.netBalance), lang)}
                        {channelSummary.netBalance < 0 && <span className="text-xs mr-0.5">{t('type_debit_marker')}</span>}
                      </span>
                    </TableCell>
                    <TableCell className="text-center font-semibold text-gray-700">
                      {channelSummary.count}
                    </TableCell>
                  </TableRow>
                )
              })}
              {/* Grand Total Row */}
              <TableRow className="bg-emerald-100/40 hover:bg-emerald-100/40 font-bold border-t-2 border-emerald-300">
                <TableCell className="text-center">
                  <div className="flex items-center justify-center gap-2">
                    <CircleDollarSign className="h-4 w-4 text-emerald-600" />
                    <span className="text-emerald-800">{t('ledger_grand_total')}</span>
                  </div>
                </TableCell>
                <TableCell className="text-center font-mono text-rose-700">
                  {formatCurrency(grandSummary.totalDebit, lang)}
                </TableCell>
                <TableCell className="text-center font-mono text-emerald-700">
                  {formatCurrency(grandSummary.totalCredit, lang)}
                </TableCell>
                <TableCell className="text-center font-mono">
                  <span className={`text-lg ${grandSummary.netBalance >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                    {formatCurrency(Math.abs(grandSummary.netBalance), lang)}
                    {grandSummary.netBalance < 0 && <span className="text-xs mr-0.5">{t('type_debit_marker')}</span>}
                  </span>
                </TableCell>
                <TableCell className="text-center text-gray-700">{grandSummary.count}</TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </div>
      </CardContent>
    </Card>
  )

  // ─── Main render ───────────────────────────────────────────────────────────

  return (
    <div className="h-full flex flex-col bg-gray-50/50">
      {/* Print-only header */}
      <div className="hidden print:block print-area mb-6 p-6">
        <div className="text-center mb-4">
          <h1 className="text-2xl font-bold">{t('app_name')}</h1>
          <h2 className="text-lg font-semibold text-gray-700 mt-1">{t('ledger_print_title')}</h2>
          {(dateFrom || dateTo) && (
            <p className="text-sm text-gray-500 mt-1">
              {t('ledger_from')}: {dateFrom || '—'} {t('ledger_to')}: {dateTo || '—'}
            </p>
          )}
          <p className="text-xs text-gray-400 mt-1">{new Date().toLocaleDateString(lang === 'en' ? 'en-KW' : 'ar-KW')}</p>
        </div>
      </div>
      {/* Header */}
      <div className="sticky top-0 z-10 bg-white border-b shadow-sm px-4 lg:px-6 py-4 no-print">
        <div className="flex flex-col gap-3">
          {/* Title row */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-emerald-100">
                <BookOpen className="h-6 w-6 text-emerald-700" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-gray-800">{t('ledger_title')}</h1>
                <p className="text-sm text-muted-foreground">{t('ledger_description')}</p>
              </div>
            </div>
            <Button
              variant="outline"
              size="sm"
              onClick={fetchData}
              disabled={loading}
              className="gap-2"
            >
              <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
              {t('refresh')}
            </Button>
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={handleExportExcel}
                disabled={loading || filteredAllEntries.length === 0}
                className="gap-2 text-emerald-700 border-emerald-200 hover:bg-emerald-50"
              >
                <Download className="h-4 w-4" />
                {t('ledger_export_excel')}
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={handlePrint}
                disabled={loading}
                className="gap-2 text-sky-700 border-sky-200 hover:bg-sky-50 print:hidden"
              >
                <Printer className="h-4 w-4" />
                {t('ledger_print')}
              </Button>
            </div>
          </div>

          {/* Filters row */}
          <div className="flex items-center gap-3 flex-wrap">
            <div className="flex items-center gap-2">
              <label className="text-sm font-medium text-gray-600 whitespace-nowrap">{t('ledger_from')}:</label>
              <Input
                type="date"
                value={dateFrom}
                onChange={(e) => setDateFrom(e.target.value)}
                className="w-36 h-8 text-sm"
              />
            </div>
            <div className="flex items-center gap-2">
              <label className="text-sm font-medium text-gray-600 whitespace-nowrap">{t('ledger_to')}:</label>
              <Input
                type="date"
                value={dateTo}
                onChange={(e) => setDateTo(e.target.value)}
                className="w-36 h-8 text-sm"
              />
            </div>
            <Select value={typeFilter} onValueChange={setTypeFilter}>
              <SelectTrigger className="w-36 h-8 text-sm">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">{t('ledger_all')}</SelectItem>
                <SelectItem value="sales">{t('type_sale')}</SelectItem>
                <SelectItem value="purchase">{t('type_purchase')}</SelectItem>
                <SelectItem value="bond_receipt">{t('type_receipt')}</SelectItem>
                <SelectItem value="bond_payment">{t('type_payment')}</SelectItem>
                <SelectItem value="sales_return">{t('type_sales_return')}</SelectItem>
                <SelectItem value="purchase_return">{t('type_purchase_return')}</SelectItem>
                <SelectItem value="salary">{t('type_salary')}</SelectItem>
                <SelectItem value="rent">{t('type_rent')}</SelectItem>
              </SelectContent>
            </Select>
            <div className="relative">
              <Search className="absolute right-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder={`${t('search')}...`}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-44 h-8 text-sm pr-8"
              />
            </div>
            {(dateFrom || dateTo || searchQuery || typeFilter !== 'all') && (
              <Button
                variant="ghost"
                size="sm"
                className="h-8 text-xs"
                onClick={() => {
                  setDateFrom('')
                  setDateTo('')
                  setSearchQuery('')
                  setTypeFilter('all')
                }}
              >
                {t('ledger_clear_filters')}
              </Button>
            )}
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto p-4 lg:p-6 print-area">
        {loading ? (
          <div className="flex items-center justify-center py-16">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600" />
          </div>
        ) : (
          <>
            {renderSummaryCards()}
            {renderAccountSummaryCards()}

            <Card>
              <CardContent className="p-0">
                <Tabs value={activeTab} onValueChange={setActiveTab}>
                  <div className="border-b px-4 pt-4">
                    <TabsList>
                      <TabsTrigger value="all">
                        <ArrowDownUp className="h-4 w-4 mr-2" />
                        {t('ledger_all')}
                      </TabsTrigger>
                      {(Object.keys(channelConfig) as PaymentChannel[]).map((channel) => {
                        const config = channelConfig[channel]
                        const Icon = config.icon
                        return (
                          <TabsTrigger key={channel} value={channel}>
                            <Icon className={`h-4 w-4 mr-2 ${config.textColor}`} />
                            {t(config.labelKey)}
                          </TabsTrigger>
                        )
                      })}
                    </TabsList>
                  </div>

                  {/* All tab */}
                  <TabsContent value="all" className="p-4">
                    {renderLedgerTable(filteredAllEntries, true)}
                  </TabsContent>

                  {/* Channel tabs */}
                  {(Object.keys(channelConfig) as PaymentChannel[]).map((channel) => (
                    <TabsContent key={channel} value={channel} className="p-4">
                      {renderLedgerTable(filteredEntriesByChannel[channel])}
                      {renderChannelSubtotal(channel)}
                    </TabsContent>
                  ))}
                </Tabs>
              </CardContent>
            </Card>

            {renderGrandTotal()}
          </>
        )}
      </div>
    </div>
  )
}
