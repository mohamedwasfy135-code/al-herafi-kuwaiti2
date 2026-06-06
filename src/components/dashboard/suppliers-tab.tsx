'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import {
  Plus,
  Truck,
  Pencil,
  Trash2,
  Search,
  Loader2,
  Phone,
  Mail,
  User,
  CreditCard,
  FileText,
  CalendarDays,
  Receipt,
  Banknote,
  Filter,
  X,
} from 'lucide-react'
import {
  Card,
  CardContent,
} from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { ScrollArea } from '@/components/ui/scroll-area'
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'

/* ─── Types ─── */
interface Supplier {
  id: number
  name: string
  nameEn: string | null
  phone: string | null
  email: string | null
  address: string | null
  contactPerson: string | null
  contactPhone: string | null
  balance: number
  paymentTerms: string | null
  taxNumber: string | null
  notes: string | null
  isActive: boolean
  _count?: { purchaseInvoices: number; products: number }
}

interface PurchaseInvoice {
  id: number
  invoiceNumber: string
  supplierId: number | null
  supplierName: string | null
  supplierPhone: string | null
  subtotal: number
  taxAmount: number
  total: number
  status: string
  paidAmount: number
  dueDate: string | null
  notes: string | null
  issuedAt: string | null
  createdAt: string
}

interface Bond {
  id: number
  bondNumber: string
  bondType: string
  amount: number
  accountId: number | null
  partyName: string | null
  partyType: string | null
  description: string | null
  referenceType: string | null
  referenceId: number | null
  issuedDate: string | null
  createdAt: string
  account?: { id: number; code: string; name: string } | null
}

type StatementRow =
  | { kind: 'invoice'; date: string; ref: string; details: string; debit: number; credit: number }
  | { kind: 'bond'; date: string; ref: string; details: string; debit: number; credit: number }

const defaultForm = {
  name: '',
  nameEn: '',
  phone: '',
  email: '',
  address: '',
  contactPerson: '',
  contactPhone: '',
  balance: '',
  paymentTerms: '',
  taxNumber: '',
  notes: '',
}

export function SuppliersTab() {
  const { t, lang, dir } = useLanguage()
  /* ─── State ─── */
  const [suppliers, setSuppliers] = useState<Supplier[]>([])
  const [search, setSearch] = useState('')
  const [searchOpen, setSearchOpen] = useState(false)
  const [dialogOpen, setDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [editingSupplier, setEditingSupplier] = useState<Supplier | null>(null)
  const [form, setForm] = useState(defaultForm)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)

  // Account statement
  const [statementSupplier, setStatementSupplier] = useState<Supplier | null>(null)
  const [statementOpen, setStatementOpen] = useState(false)
  const [statementLoading, setStatementLoading] = useState(false)
  const [statementRows, setStatementRows] = useState<StatementRow[]>([])
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')

  const businessId = getBusinessId()
  const searchRef = useRef<HTMLDivElement>(null)
  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'
  const formatCurrency = (amount: number) => amount.toLocaleString(locale, { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  const formatDate = (d: string) => new Date(d).toLocaleDateString(locale, { year: 'numeric', month: 'short', day: 'numeric' })

  /* ─── Fetch suppliers ─── */
  const fetchSuppliers = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`/api/suppliers?businessId=${businessId}`)
      if (res.ok) {
        const data = await res.json()
        setSuppliers(data)
      }
    } catch {
      // keep empty
    } finally {
      setLoading(false)
    }
  }, [businessId])

  useEffect(() => {
    fetchSuppliers()
  }, [fetchSuppliers])

  /* ─── Close search dropdown on outside click ─── */
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) {
        setSearchOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  /* ─── Derived ─── */
  const filteredSuppliers = suppliers.filter(
    (s) =>
      s.name.includes(search) ||
      (s.phone && s.phone.includes(search)) ||
      (s.contactPerson && s.contactPerson.includes(search))
  )

  const totalBalance = suppliers.reduce((s, sup) => s + sup.balance, 0)

  const searchResults = search.trim()
    ? suppliers.filter(
        (s) =>
          s.name.includes(search) ||
          (s.phone && s.phone.includes(search)) ||
          (s.contactPerson && s.contactPerson.includes(search))
      )
    : []

  /* ─── Account statement logic ─── */
  const openStatement = async (supplier: Supplier) => {
    setStatementSupplier(supplier)
    setStatementOpen(true)
    setSearchOpen(false)
    setSearch('')
    setDateFrom('')
    setDateTo('')
    await loadStatement(supplier, '', '')
  }

  const loadStatement = async (supplier: Supplier, from: string, to: string) => {
    setStatementLoading(true)
    try {
      const [invRes, bondRes] = await Promise.all([
        fetch(`/api/invoices/purchase?businessId=${businessId}`),
        fetch(`/api/bonds?businessId=${businessId}`),
      ])

      const allInvoices: PurchaseInvoice[] = invRes.ok ? await invRes.json() : []
      const allBonds: Bond[] = bondRes.ok ? await bondRes.json() : []

      // Filter purchase invoices for this supplier
      let supplierInvoices = allInvoices.filter(
        (inv) =>
          inv.supplierId === supplier.id ||
          (inv.supplierName && inv.supplierName === supplier.name)
      )

      // Filter bonds: payment bonds to this supplier (payments we made)
      let supplierBonds = allBonds.filter(
        (b) =>
          b.bondType === 'payment' &&
          (b.partyName === supplier.name || b.partyName === supplier.phone)
      )

      // Date filtering
      if (from) {
        const fromDate = new Date(from)
        supplierInvoices = supplierInvoices.filter(
          (inv) => new Date(inv.createdAt) >= fromDate
        )
        supplierBonds = supplierBonds.filter(
          (b) => new Date(b.issuedDate || b.createdAt) >= fromDate
        )
      }
      if (to) {
        const toDate = new Date(to)
        toDate.setHours(23, 59, 59, 999)
        supplierInvoices = supplierInvoices.filter(
          (inv) => new Date(inv.createdAt) <= toDate
        )
        supplierBonds = supplierBonds.filter(
          (b) => new Date(b.issuedDate || b.createdAt) <= toDate
        )
      }

      // Build unified rows
      const rows: StatementRow[] = []

      for (const inv of supplierInvoices) {
        rows.push({
          kind: 'invoice',
          date: inv.createdAt,
          ref: inv.invoiceNumber,
          details: `${t('suppliers_purchase_invoice')}${inv.status === 'paid' ? ` (${t('sales_status_paid')})` : inv.status === 'partial' ? ` (${t('sales_status_partial')})` : ''}`,
          debit: inv.total, // amount we owe
          credit: inv.paidAmount || 0, // amount we paid
        })
      }

      for (const b of supplierBonds) {
        rows.push({
          kind: 'bond',
          date: b.issuedDate || b.createdAt,
          ref: b.bondNumber,
          details: b.description || t('suppliers_payment_bond'),
          debit: 0,
          credit: b.amount, // payment we made to supplier
        })
      }

      // Sort by date ascending
      rows.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())

      setStatementRows(rows)
    } catch {
      toast.error(t('suppliers_statement_failed'))
    } finally {
      setStatementLoading(false)
    }
  }

  const handleFilterStatement = () => {
    if (statementSupplier) {
      loadStatement(statementSupplier, dateFrom, dateTo)
    }
  }

  const clearDateFilter = () => {
    setDateFrom('')
    setDateTo('')
    if (statementSupplier) {
      loadStatement(statementSupplier, '', '')
    }
  }

  // Compute running balance & summary
  const statementSummary = statementRows.reduce(
    (acc, row) => {
      acc.totalDebit += row.debit
      acc.totalCredit += row.credit
      return acc
    },
    { totalDebit: 0, totalCredit: 0 }
  )
  const currentBalance = statementSummary.totalDebit - statementSummary.totalCredit

  // Build running balance array
  const runningBalances: number[] = []
  let runBal = 0
  for (const row of statementRows) {
    runBal += row.debit - row.credit
    runningBalances.push(runBal)
  }

  /* ─── CRUD handlers ─── */
  const openCreate = () => {
    setEditingSupplier(null)
    setForm(defaultForm)
    setDialogOpen(true)
  }

  const openEdit = (supplier: Supplier) => {
    setEditingSupplier(supplier)
    setForm({
      name: supplier.name,
      nameEn: supplier.nameEn || '',
      phone: supplier.phone || '',
      email: supplier.email || '',
      address: supplier.address || '',
      contactPerson: supplier.contactPerson || '',
      contactPhone: supplier.contactPhone || '',
      balance: String(supplier.balance),
      paymentTerms: supplier.paymentTerms || '',
      taxNumber: supplier.taxNumber || '',
      notes: supplier.notes || '',
    })
    setDialogOpen(true)
  }

  const handleSubmit = async () => {
    if (!form.name) {
      toast.error(t('suppliers_name_required_msg'))
      return
    }
    setSaving(true)
    try {
      const url = editingSupplier
        ? `/api/suppliers/${editingSupplier.id}`
        : '/api/suppliers'
      const method = editingSupplier ? 'PUT' : 'POST'

      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          name: form.name,
          nameEn: form.nameEn || null,
          phone: form.phone || null,
          email: form.email || null,
          address: form.address || null,
          contactPerson: form.contactPerson || null,
          contactPhone: form.contactPhone || null,
          balance: form.balance || 0,
          paymentTerms: form.paymentTerms || null,
          taxNumber: form.taxNumber || null,
          notes: form.notes || null,
        }),
      })

      if (res.ok) {
        toast.success(editingSupplier ? t('suppliers_update_success') : t('suppliers_add_success'))
        setDialogOpen(false)
        fetchSuppliers()
      } else {
        const err = await res.json()
        toast.error(err.error || t('suppliers_save_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  const confirmDelete = (id: number) => {
    setDeletingId(id)
    setDeleteDialogOpen(true)
  }

  const handleDelete = async () => {
    if (!deletingId) return
    try {
      const res = await fetch(`/api/suppliers/${deletingId}`, { method: 'DELETE' })
      if (res.ok) {
        toast.success(t('suppliers_delete_success'))
        fetchSuppliers()
      } else {
        toast.error(t('suppliers_delete_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setDeleteDialogOpen(false)
      setDeletingId(null)
    }
  }

  /* ─── Helpers ─── */
  const fmtDate = (d: string) =>
    formatDate(d)

  const fmtMoney = (n: number) => formatCurrency(n)

  /* ─── Render ─── */
  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('suppliers_title')}</h2>
          <p className="text-muted-foreground">{t('suppliers_subtitle')}</p>
        </div>
        <div className="flex items-center gap-3">
          {/* Search with dropdown */}
          <div className="relative" ref={searchRef}>
            <Search className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder={t('suppliers_search_placeholder')}
              value={search}
              onChange={(e) => {
                setSearch(e.target.value)
                setSearchOpen(true)
              }}
              onFocus={() => search.trim() && setSearchOpen(true)}
              className="w-48 pr-9 sm:w-64"
            />
            {searchOpen && searchResults.length > 0 && (
              <div className="absolute top-full mt-1 right-0 z-50 w-72 rounded-lg border bg-popover shadow-lg">
                <ScrollArea className="max-h-64">
                  <div className="p-1">
                    {searchResults.map((s) => (
                      <button
                        key={s.id}
                        className="flex w-full items-center gap-3 rounded-md px-3 py-2 text-right hover:bg-accent transition-colors"
                        onClick={() => openStatement(s)}
                      >
                        <Avatar className="h-8 w-8 shrink-0">
                          <AvatarFallback className="bg-violet-100 text-violet-700 text-xs">
                            {s.name.charAt(0)}
                          </AvatarFallback>
                        </Avatar>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium truncate">{s.name}</p>
                          <div className="flex items-center gap-2 text-xs text-muted-foreground">
                            {s.phone && <span>{s.phone}</span>}
                            <Badge
                              variant={s.balance > 0 ? 'destructive' : 'secondary'}
                              className="text-[10px] px-1.5 py-0"
                            >
                              {s.balance > 0 ? `${s.balance.toLocaleString(locale)} ${t('currency')}` : t('no_balance')}
                            </Badge>
                          </div>
                        </div>
                        <FileText className="h-4 w-4 text-muted-foreground shrink-0" />
                      </button>
                    ))}
                  </div>
                </ScrollArea>
              </div>
            )}
          </div>
          <Button
            onClick={openCreate}
            className="gap-2 bg-emerald-600 hover:bg-emerald-700"
          >
            <Plus className="h-4 w-4" />{t('suppliers_add')}</Button>
        </div>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-violet-100">
              <Truck className="h-6 w-6 text-violet-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('suppliers_count')}</p>
              <p className="text-2xl font-bold">{suppliers.length}</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-red-100">
              <CreditCard className="h-6 w-6 text-red-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('suppliers_total_due')}</p>
              <p className="text-2xl font-bold text-red-700">
                {totalBalance.toLocaleString(locale)} <span className="text-sm font-normal">{t('currency')}</span>
              </p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Suppliers Table */}
      <Card>
        <CardContent className="p-0">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            </div>
          ) : filteredSuppliers.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <Truck className="h-12 w-12 mb-3 opacity-30" />
              <p>{t('suppliers_no_suppliers')}</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-right">{t('suppliers_name')}</TableHead>
                    <TableHead className="text-right">{t('suppliers_phone')}</TableHead>
                    <TableHead className="text-right">{t('suppliers_contact_person')}</TableHead>
                    <TableHead className="text-right">{t('suppliers_dues')}</TableHead>
                    <TableHead className="text-right">{t('status')}</TableHead>
                    <TableHead className="text-right">{t('actions')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredSuppliers.map((sup) => (
                    <TableRow key={sup.id}>
                      <TableCell>
                        <div className="flex items-center gap-2">
                          <Avatar className="h-8 w-8">
                            <AvatarFallback className="bg-violet-100 text-violet-700 text-xs">
                              {sup.name.charAt(0)}
                            </AvatarFallback>
                          </Avatar>
                          <div>
                            <p className="text-sm font-medium">{sup.name}</p>
                            {sup.nameEn && (
                              <p className="text-xs text-muted-foreground">{sup.nameEn}</p>
                            )}
                          </div>
                        </div>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1 text-sm">
                          <Phone className="h-3.5 w-3.5 text-muted-foreground" />
                          {sup.phone || '—'}
                        </div>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1 text-sm">
                          <User className="h-3.5 w-3.5 text-muted-foreground" />
                          {sup.contactPerson || '—'}
                        </div>
                      </TableCell>
                      <TableCell>
                        <span className={`font-medium ${sup.balance > 0 ? 'text-red-700' : 'text-emerald-700'}`}>
                          {sup.balance.toLocaleString(locale)} {t('currency')}
                        </span>
                      </TableCell>
                      <TableCell>
                        <Badge
                          variant={sup.isActive ? 'default' : 'secondary'}
                          className={sup.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-600'}
                        >
                          {sup.isActive ? t('employees_active_yes') : t('employees_active_no')}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1">
                          <Button
                            variant="ghost"
                            size="sm"
                            className="h-7 gap-1 px-2 text-violet-700 hover:text-violet-800 hover:bg-violet-50"
                            onClick={() => openStatement(sup)}
                            title={t('suppliers_account_statement')}
                          >
                            <FileText className="h-3.5 w-3.5" />
                            <span className="text-xs hidden sm:inline">{t('suppliers_account_statement')}</span>
                          </Button>
                          <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={() => openEdit(sup)}>
                            <Pencil className="h-3.5 w-3.5" />
                          </Button>
                          <Button
                            variant="ghost" size="sm" className="h-7 w-7 p-0 text-red-600 hover:text-red-700 hover:bg-red-50"
                            onClick={() => confirmDelete(sup.id)}
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* ═══════════════════════════════════════════════════════════ */}
      {/* Account Statement Dialog */}
      {/* ═══════════════════════════════════════════════════════════ */}
      <Dialog open={statementOpen} onOpenChange={setStatementOpen}>
        <DialogContent className="max-w-4xl max-h-[90vh]" dir={dir}>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-lg">
              <FileText className="h-5 w-5 text-violet-600" />
              {t('suppliers_statement_title')}
            </DialogTitle>
            <DialogDescription>
              {t('suppliers_statement_desc')}
            </DialogDescription>
          </DialogHeader>

          {statementLoading ? (
            <div className="flex items-center justify-center py-16">
              <Loader2 className="h-8 w-8 animate-spin text-violet-600" />
            </div>
          ) : statementSupplier ? (
            <div className="space-y-4">
              {/* Supplier info header */}
              <div className="rounded-lg border bg-gradient-to-l from-violet-50 to-white p-4">
                <div className="grid grid-cols-2 gap-x-6 gap-y-3 sm:grid-cols-3">
                  <div>
                    <p className="text-xs text-muted-foreground">{t('suppliers_name')}</p>
                    <p className="font-semibold text-sm">{statementSupplier.name}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">{t('suppliers_phone')}</p>
                    <p className="text-sm">{statementSupplier.phone || '—'}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">{t('suppliers_address')}</p>
                    <p className="text-sm">{statementSupplier.address || '—'}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">{t('suppliers_contact_person')}</p>
                    <p className="text-sm">{statementSupplier.contactPerson || '—'}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">{t('suppliers_total_purchases')}</p>
                    <p className="font-semibold text-sm text-sky-700">{fmtMoney(statementSummary.totalDebit)} {t('currency')}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">{t('suppliers_total_paid')}</p>
                    <p className="font-semibold text-sm text-emerald-700">{fmtMoney(statementSummary.totalCredit)} {t('currency')}</p>
                  </div>
                </div>
              </div>

              {/* Date range filter */}
              <div className="flex flex-wrap items-end gap-3 rounded-lg border p-3 bg-muted/30">
                <div className="flex items-center gap-1.5 text-sm text-muted-foreground">
                  <Filter className="h-4 w-4" />
                  <span>{t('suppliers_filter_by_date')}</span>
                </div>
                <div className="flex items-center gap-2">
                  <Label className="text-xs whitespace-nowrap">{t('from')}</Label>
                  <Input
                    type="date"
                    value={dateFrom}
                    onChange={(e) => setDateFrom(e.target.value)}
                    className="h-8 w-36 text-xs"
                  />
                </div>
                <div className="flex items-center gap-2">
                  <Label className="text-xs whitespace-nowrap">{t('to')}</Label>
                  <Input
                    type="date"
                    value={dateTo}
                    onChange={(e) => setDateTo(e.target.value)}
                    className="h-8 w-36 text-xs"
                  />
                </div>
                <Button size="sm" className="h-8 gap-1 bg-violet-600 hover:bg-violet-700" onClick={handleFilterStatement}>
                  <CalendarDays className="h-3.5 w-3.5" />
                  {t('apply')}
                </Button>
                {(dateFrom || dateTo) && (
                  <Button size="sm" variant="outline" className="h-8 gap-1" onClick={clearDateFilter}>
                    <X className="h-3.5 w-3.5" />
                    {t('cancel')}
                  </Button>
                )}
              </div>

              {/* Transactions table */}
              <div className="rounded-lg border overflow-hidden">
                <ScrollArea className="max-h-96">
                  <Table>
                    <TableHeader>
                      <TableRow className="bg-muted/50">
                        <TableHead className="text-right text-xs">#</TableHead>
                        <TableHead className="text-right text-xs">{t('date')}</TableHead>
                        <TableHead className="text-right text-xs">{t('suppliers_reference')}</TableHead>
                        <TableHead className="text-right text-xs">{t('suppliers_statement')}</TableHead>
                        <TableHead className="text-right text-xs">{t('suppliers_debit_owed')}</TableHead>
                        <TableHead className="text-right text-xs">{t('suppliers_credit_paid')}</TableHead>
                        <TableHead className="text-right text-xs">{t('suppliers_running_balance')}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {statementRows.length === 0 ? (
                        <TableRow>
                          <TableCell colSpan={7} className="h-24 text-center text-muted-foreground">
                            {t('suppliers_no_transactions_period')}
                          </TableCell>
                        </TableRow>
                      ) : (
                        statementRows.map((row, i) => (
                          <TableRow key={i} className={row.kind === 'bond' ? 'bg-emerald-50/50' : ''}>
                            <TableCell className="text-xs text-muted-foreground">{i + 1}</TableCell>
                            <TableCell className="text-xs whitespace-nowrap">{fmtDate(row.date)}</TableCell>
                            <TableCell>
                              <div className="flex items-center gap-1.5">
                                {row.kind === 'invoice' ? (
                                  <Receipt className="h-3.5 w-3.5 text-sky-600" />
                                ) : (
                                  <Banknote className="h-3.5 w-3.5 text-emerald-600" />
                                )}
                                <span className="text-xs font-medium">{row.ref}</span>
                              </div>
                            </TableCell>
                            <TableCell className="text-xs">{row.details}</TableCell>
                            <TableCell className="text-xs font-medium text-red-700">
                              {row.debit > 0 ? fmtMoney(row.debit) : '—'}
                            </TableCell>
                            <TableCell className="text-xs font-medium text-emerald-700">
                              {row.credit > 0 ? fmtMoney(row.credit) : '—'}
                            </TableCell>
                            <TableCell>
                              <Badge
                                variant={runningBalances[i] > 0 ? 'destructive' : runningBalances[i] < 0 ? 'secondary' : 'outline'}
                                className="text-[10px] px-1.5 py-0"
                              >
                                {fmtMoney(Math.abs(runningBalances[i]))}
                                {runningBalances[i] > 0 ? t('type_debit_marker').replace(/[()]/g, '') : runningBalances[i] < 0 ? t('ledger_credit').charAt(0) : ''}
                              </Badge>
                            </TableCell>
                          </TableRow>
                        ))
                      )}
                    </TableBody>
                  </Table>
                </ScrollArea>
              </div>

              {/* Summary footer */}
              <div className="rounded-lg border bg-muted/30 p-4">
                <div className="grid grid-cols-3 gap-4 text-center">
                  <div>
                    <p className="text-xs text-muted-foreground mb-1">{t('suppliers_total_debit_purchases')}</p>
                    <p className="text-lg font-bold text-red-700">{fmtMoney(statementSummary.totalDebit)} <span className="text-xs font-normal">{t('currency')}</span></p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground mb-1">{t('suppliers_total_credit_paid')}</p>
                    <p className="text-lg font-bold text-emerald-700">{fmtMoney(statementSummary.totalCredit)} <span className="text-xs font-normal">{t('currency')}</span></p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground mb-1">{t('suppliers_current_balance_label')}</p>
                    <p className={`text-lg font-bold ${currentBalance > 0 ? 'text-red-700' : 'text-emerald-700'}`}>
                      {fmtMoney(Math.abs(currentBalance))} <span className="text-xs font-normal">{t('currency')}</span>
                      <span className="text-xs block">
                        {currentBalance > 0 ? t('suppliers_balance_debit') : currentBalance < 0 ? t('suppliers_balance_credit') : t('suppliers_balance_settled')}
                      </span>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          ) : null}
        </DialogContent>
      </Dialog>

      {/* Create/Edit Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-lg" dir="rtl">
          <DialogHeader>
            <DialogTitle>{editingSupplier ? t('suppliers_edit') : t('suppliers_add_new')}</DialogTitle>
            <DialogDescription>{t('suppliers_enter_data')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('suppliers_name')} *</Label>
                <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder={t('suppliers_name_placeholder')} />
              </div>
              <div className="space-y-2">
                <Label>{t('suppliers_name_en')}</Label>
                <Input value={form.nameEn} onChange={(e) => setForm({ ...form, nameEn: e.target.value })} placeholder="Supplier name" />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('suppliers_phone')}</Label>
                <Input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder={t('suppliers_phone')} />
              </div>
              <div className="space-y-2">
                <Label>{t('suppliers_email')}</Label>
                <Input value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="email@example.com" />
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('suppliers_address')}</Label>
              <Input value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} placeholder={t('suppliers_address')} />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('suppliers_contact_person')}</Label>
                <Input value={form.contactPerson} onChange={(e) => setForm({ ...form, contactPerson: e.target.value })} placeholder={t('suppliers_contact_person_placeholder')} />
              </div>
              <div className="space-y-2">
                <Label>{t('suppliers_contact_phone')}</Label>
                <Input value={form.contactPhone} onChange={(e) => setForm({ ...form, contactPhone: e.target.value })} placeholder={t('suppliers_contact_phone')} />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('suppliers_balance_owed')}</Label>
                <Input type="number" value={form.balance} onChange={(e) => setForm({ ...form, balance: e.target.value })} placeholder="0" />
              </div>
              <div className="space-y-2">
                <Label>{t('suppliers_payment_terms')}</Label>
                <Input value={form.paymentTerms} onChange={(e) => setForm({ ...form, paymentTerms: e.target.value })} placeholder={t('suppliers_payment_terms_placeholder')} />
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('suppliers_notes_label')}</Label>
              <Input value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} placeholder={t('suppliers_additional_notes')} />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setDialogOpen(false)}>{t('cancel')}</Button>
            <Button onClick={handleSubmit} className="bg-emerald-600 hover:bg-emerald-700" disabled={saving || !form.name}>
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {editingSupplier ? t('save_changes') : t('suppliers_add')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent dir="rtl">
          <AlertDialogHeader>
            <AlertDialogTitle>{t('suppliers_delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>{t('suppliers_delete_confirm')}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('cancel')}</AlertDialogCancel>
            <AlertDialogAction onClick={handleDelete} className="bg-red-600 hover:bg-red-700">{t('delete')}</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
