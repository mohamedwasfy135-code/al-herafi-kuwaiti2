'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import {
  Users,
  Plus,
  Search,
  Phone,
  Mail,
  MapPin,
  Loader2,
  UserPlus,
  Pencil,
  Trash2,
  FileText,
  CalendarDays,
  ArrowUpDown,
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
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Separator } from '@/components/ui/separator'
import { ScrollArea } from '@/components/ui/scroll-area'
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'

/* ─── Types ─── */
interface Client {
  id: number
  businessId: string
  name: string
  phone: string | null
  email: string | null
  address: string | null
  totalPurchases: number
  totalPaid: number
  balance: number
  notes: string | null
  createdAt: string
}

interface SalesInvoice {
  id: number
  invoiceNumber: string
  clientId: number | null
  clientName: string | null
  clientPhone: string | null
  subtotal: number
  discountAmount: number
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

const emptyForm = { name: '', phone: '', email: '', address: '', notes: '' }

export function ClientsTab() {
  const { t, lang, dir } = useLanguage()
  /* ─── State ─── */
  const [clients, setClients] = useState<Client[]>([])
  const [search, setSearch] = useState('')
  const [searchOpen, setSearchOpen] = useState(false)
  const [dialogOpen, setDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [editingClient, setEditingClient] = useState<Client | null>(null)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [form, setForm] = useState(emptyForm)

  // Account statement
  const [statementClient, setStatementClient] = useState<Client | null>(null)
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

  /* ─── Fetch clients ─── */
  const fetchClients = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`/api/clients?businessId=${businessId}`)
      if (res.ok) {
        const data = await res.json()
        if (data.length > 0) setClients(data)
      }
    } catch {
      // keep existing
    } finally {
      setLoading(false)
    }
  }, [businessId])

  useEffect(() => {
    fetchClients()
  }, [fetchClients])

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
  const filteredClients = clients.filter(
    (c) =>
      c.name.includes(search) ||
      (c.phone && c.phone.includes(search)) ||
      (c.email && c.email.includes(search))
  )

  const totalBalance = clients.reduce((s, c) => s + c.balance, 0)
  const totalPurchases = clients.reduce((s, c) => s + c.totalPurchases, 0)
  const clientsWithBalance = clients.filter((c) => c.balance > 0).length

  const searchResults = search.trim()
    ? clients.filter(
        (c) =>
          c.name.includes(search) ||
          (c.phone && c.phone.includes(search))
      )
    : []

  /* ─── Account statement logic ─── */
  const openStatement = async (client: Client) => {
    setStatementClient(client)
    setStatementOpen(true)
    setSearchOpen(false)
    setSearch('')
    setDateFrom('')
    setDateTo('')
    await loadStatement(client, '', '')
  }

  const loadStatement = async (client: Client, from: string, to: string) => {
    setStatementLoading(true)
    try {
      const [invRes, bondRes] = await Promise.all([
        fetch(`/api/invoices/sales?businessId=${businessId}`),
        fetch(`/api/bonds?businessId=${businessId}`),
      ])

      const allInvoices: SalesInvoice[] = invRes.ok ? await invRes.json() : []
      const allBonds: Bond[] = bondRes.ok ? await bondRes.json() : []

      // Filter invoices for this client (by clientId or by name match)
      let clientInvoices = allInvoices.filter(
        (inv) =>
          inv.clientId === client.id ||
          (inv.clientName && inv.clientName === client.name)
      )

      // Filter bonds: receipt bonds from this client (payments received)
      let clientBonds = allBonds.filter(
        (b) =>
          b.bondType === 'receipt' &&
          (b.partyName === client.name || b.partyName === client.phone)
      )

      // Date filtering
      if (from) {
        const fromDate = new Date(from)
        clientInvoices = clientInvoices.filter(
          (inv) => new Date(inv.createdAt) >= fromDate
        )
        clientBonds = clientBonds.filter(
          (b) => new Date(b.issuedDate || b.createdAt) >= fromDate
        )
      }
      if (to) {
        const toDate = new Date(to)
        toDate.setHours(23, 59, 59, 999)
        clientInvoices = clientInvoices.filter(
          (inv) => new Date(inv.createdAt) <= toDate
        )
        clientBonds = clientBonds.filter(
          (b) => new Date(b.issuedDate || b.createdAt) <= toDate
        )
      }

      // Build unified rows
      const rows: StatementRow[] = []

      for (const inv of clientInvoices) {
        rows.push({
          kind: 'invoice',
          date: inv.createdAt,
          ref: inv.invoiceNumber,
          details: `${t('clients_sales_invoice')}${inv.status === 'paid' ? ` (${t('sales_status_paid')})` : inv.status === 'partial' ? ` (${t('sales_status_partial')})` : ''}`,
          debit: inv.total, // amount client owes
          credit: inv.paidAmount, // amount client paid
        })
      }

      for (const b of clientBonds) {
        rows.push({
          kind: 'bond',
          date: b.issuedDate || b.createdAt,
          ref: b.bondNumber,
          details: b.description || t('clients_receipt_bond'),
          debit: 0,
          credit: b.amount, // payment received from client
        })
      }

      // Sort by date ascending
      rows.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())

      setStatementRows(rows)
    } catch {
      toast.error(t('clients_statement_failed'))
    } finally {
      setStatementLoading(false)
    }
  }

  const handleFilterStatement = () => {
    if (statementClient) {
      loadStatement(statementClient, dateFrom, dateTo)
    }
  }

  const clearDateFilter = () => {
    setDateFrom('')
    setDateTo('')
    if (statementClient) {
      loadStatement(statementClient, '', '')
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
    setEditingClient(null)
    setForm(emptyForm)
    setDialogOpen(true)
  }

  const openEdit = (client: Client) => {
    setEditingClient(client)
    setForm({
      name: client.name,
      phone: client.phone || '',
      email: client.email || '',
      address: client.address || '',
      notes: client.notes || '',
    })
    setDialogOpen(true)
  }

  const handleSubmit = async () => {
    setSaving(true)
    try {
      if (editingClient) {
        setClients((prev) =>
          prev.map((c) => (c.id === editingClient.id ? { ...c, ...form } : c))
        )
        toast.success(t('clients_update_success'))
      } else {
        const res = await fetch('/api/clients', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ businessId, ...form }),
        })
        if (res.ok) {
          const saved = await res.json()
          setClients((prev) => [saved, ...prev])
          toast.success(t('clients_add_success'))
        } else {
          const err = await res.json()
          toast.error(err.error || t('clients_save_failed'))
        }
      }
      setDialogOpen(false)
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
      setClients((prev) => prev.filter((c) => c.id !== deletingId))
      toast.success(t('clients_delete_success'))
    } catch {
      toast.error(t('clients_delete_failed'))
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
          <h2 className="text-2xl font-bold tracking-tight">{t('clients_title')}</h2>
          <p className="text-muted-foreground">{t('clients_subtitle')}</p>
        </div>
        <div className="flex items-center gap-3">
          {/* Search with dropdown */}
          <div className="relative" ref={searchRef}>
            <Search className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder={t('clients_search_placeholder')}
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
                    {searchResults.map((c) => (
                      <button
                        key={c.id}
                        className="flex w-full items-center gap-3 rounded-md px-3 py-2 text-right hover:bg-accent transition-colors"
                        onClick={() => openStatement(c)}
                      >
                        <Avatar className="h-8 w-8 shrink-0">
                          <AvatarFallback className="bg-emerald-100 text-emerald-700 text-xs">
                            {c.name.charAt(0)}
                          </AvatarFallback>
                        </Avatar>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium truncate">{c.name}</p>
                          <div className="flex items-center gap-2 text-xs text-muted-foreground">
                            {c.phone && <span>{c.phone}</span>}
                            <Badge
                              variant={c.balance > 0 ? 'destructive' : 'secondary'}
                              className="text-[10px] px-1.5 py-0"
                            >
                              {c.balance > 0 ? `${c.balance.toLocaleString(locale)} ${t('currency')}` : t('no_balance')}
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
            <UserPlus className="h-4 w-4" />
            {t('clients_add')}
          </Button>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-100">
              <Users className="h-6 w-6 text-emerald-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('clients_total')}</p>
              <p className="text-2xl font-bold">{clients.length}</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-sky-100">
              <Phone className="h-6 w-6 text-sky-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('clients_with_balance')}</p>
              <p className="text-2xl font-bold text-sky-700">{clientsWithBalance}</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-amber-100">
              <Mail className="h-6 w-6 text-amber-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('clients_total_balance_due')}</p>
              <p className="text-2xl font-bold text-amber-700">
                {totalBalance.toLocaleString(locale)} <span className="text-sm font-normal">{t('currency')}</span>
              </p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Clients Table */}
      <Card>
        <CardContent className="p-0">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            </div>
          ) : filteredClients.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <Users className="h-12 w-12 mb-3 opacity-30" />
              <p>{t('clients_no_clients')}</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-right">{t('clients_client_col')}</TableHead>
                    <TableHead className="text-right">{t('clients_phone')}</TableHead>
                    <TableHead className="text-right">{t('clients_area')}</TableHead>
                    <TableHead className="text-right">{t('clients_total_purchases')}</TableHead>
                    <TableHead className="text-right">{t('clients_balance')}</TableHead>
                    <TableHead className="text-right">{t('actions')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredClients.map((client) => (
                    <TableRow key={client.id} className="cursor-pointer">
                      <TableCell>
                        <div className="flex items-center gap-2">
                          <Avatar className="h-8 w-8">
                            <AvatarFallback className="bg-emerald-100 text-emerald-700 text-xs">
                              {client.name.charAt(0)}
                            </AvatarFallback>
                          </Avatar>
                          <div>
                            <p className="text-sm font-medium">{client.name}</p>
                            {client.notes && (
                              <p className="text-xs text-muted-foreground">{client.notes}</p>
                            )}
                          </div>
                        </div>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1.5">
                          <Phone className="h-3.5 w-3.5 text-muted-foreground" />
                          <span className="text-sm">{client.phone || '—'}</span>
                        </div>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1.5">
                          <MapPin className="h-3.5 w-3.5 text-muted-foreground" />
                          <span className="text-sm">{client.address || '—'}</span>
                        </div>
                      </TableCell>
                      <TableCell className="font-medium">
                        {client.totalPurchases.toLocaleString(locale)} {t('currency')}
                      </TableCell>
                      <TableCell>
                        <Badge
                          variant={client.balance > 0 ? 'destructive' : 'secondary'}
                          className="text-xs"
                        >
                          {client.balance > 0 ? `${client.balance.toLocaleString(locale)} ${t('currency')}` : t('no_balance')}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1">
                          <Button
                            variant="ghost"
                            size="sm"
                            className="h-7 gap-1 px-2 text-emerald-700 hover:text-emerald-800 hover:bg-emerald-50"
                            onClick={() => openStatement(client)}
                            title={t('clients_account_statement')}
                          >
                            <FileText className="h-3.5 w-3.5" />
                            <span className="text-xs hidden sm:inline">{t('clients_account_statement')}</span>
                          </Button>
                          <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={() => openEdit(client)}>
                            <Pencil className="h-3.5 w-3.5" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="sm"
                            className="h-7 w-7 p-0 text-red-600 hover:text-red-700 hover:bg-red-50"
                            onClick={() => confirmDelete(client.id)}
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
              <FileText className="h-5 w-5 text-emerald-600" />
              {t('clients_statement_title')}
            </DialogTitle>
            <DialogDescription>
              {t('clients_statement_desc')}
            </DialogDescription>
          </DialogHeader>

          {statementLoading ? (
            <div className="flex items-center justify-center py-16">
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            </div>
          ) : statementClient ? (
            <div className="space-y-4">
              {/* Client info header */}
              <div className="rounded-lg border bg-gradient-to-l from-emerald-50 to-white p-4">
                <div className="grid grid-cols-2 gap-x-6 gap-y-3 sm:grid-cols-3">
                  <div>
                    <p className="text-xs text-muted-foreground">{t('clients_client_name')}</p>
                    <p className="font-semibold text-sm">{statementClient.name}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">{t('clients_phone')}</p>
                    <p className="text-sm">{statementClient.phone || '—'}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">{t('clients_address')}</p>
                    <p className="text-sm">{statementClient.address || '—'}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">{t('clients_total_purchases')}</p>
                    <p className="font-semibold text-sm text-sky-700">{fmtMoney(statementClient.totalPurchases)} {t('currency')}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">{t('clients_total_paid')}</p>
                    <p className="font-semibold text-sm text-emerald-700">{fmtMoney(statementClient.totalPaid)} {t('currency')}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">{t('clients_current_balance')}</p>
                    <p className={`font-bold text-sm ${currentBalance > 0 ? 'text-red-700' : 'text-emerald-700'}`}>
                      {fmtMoney(Math.abs(currentBalance))} {t('currency')} {currentBalance > 0 ? t('clients_balance_debit') : currentBalance < 0 ? t('clients_balance_credit') : ''}
                    </p>
                  </div>
                </div>
              </div>

              {/* Date range filter */}
              <div className="flex flex-wrap items-end gap-3 rounded-lg border p-3 bg-muted/30">
                <div className="flex items-center gap-1.5 text-sm text-muted-foreground">
                  <Filter className="h-4 w-4" />
                  <span>{t('clients_filter_by_date')}</span>
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
                <Button size="sm" className="h-8 gap-1 bg-emerald-600 hover:bg-emerald-700" onClick={handleFilterStatement}>
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
                        <TableHead className="text-right text-xs">{t('clients_reference')}</TableHead>
                        <TableHead className="text-right text-xs">{t('clients_statement')}</TableHead>
                        <TableHead className="text-right text-xs">{t('clients_debit_on')}</TableHead>
                        <TableHead className="text-right text-xs">{t('clients_credit_paid')}</TableHead>
                        <TableHead className="text-right text-xs">{t('clients_running_balance')}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {statementRows.length === 0 ? (
                        <TableRow>
                          <TableCell colSpan={7} className="h-24 text-center text-muted-foreground">
                            {t('clients_no_transactions_period')}
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
                    <p className="text-xs text-muted-foreground mb-1">{t('clients_total_debit_purchases')}</p>
                    <p className="text-lg font-bold text-red-700">{fmtMoney(statementSummary.totalDebit)} <span className="text-xs font-normal">{t('currency')}</span></p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground mb-1">{t('clients_total_credit_paid')}</p>
                    <p className="text-lg font-bold text-emerald-700">{fmtMoney(statementSummary.totalCredit)} <span className="text-xs font-normal">{t('currency')}</span></p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground mb-1">{t('clients_current_balance_label')}</p>
                    <p className={`text-lg font-bold ${currentBalance > 0 ? 'text-red-700' : 'text-emerald-700'}`}>
                      {fmtMoney(Math.abs(currentBalance))} <span className="text-xs font-normal">{t('currency')}</span>
                      <span className="text-xs block">
                        {currentBalance > 0 ? t('clients_balance_debit') : currentBalance < 0 ? t('clients_balance_credit') : t('clients_balance_settled')}
                      </span>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          ) : null}
        </DialogContent>
      </Dialog>

      {/* Add/Edit Client Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-md" dir="rtl">
          <DialogHeader>
            <DialogTitle>{editingClient ? t('clients_edit') : t('clients_add_new')}</DialogTitle>
            <DialogDescription>{t('clients_enter_data')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label>{t('clients_name')} *</Label>
              <Input
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder={t('clients_name_placeholder')}
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('clients_phone')}</Label>
                <Input
                  value={form.phone}
                  onChange={(e) => setForm({ ...form, phone: e.target.value })}
                  placeholder="966XXXXX"
                />
              </div>
              <div className="space-y-2">
                <Label>{t('clients_email')}</Label>
                <Input
                  type="email"
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                  placeholder="email@example.com"
                />
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('clients_address')}</Label>
              <Input
                value={form.address}
                onChange={(e) => setForm({ ...form, address: e.target.value })}
                placeholder={t('clients_address')}
              />
            </div>
            <div className="space-y-2">
              <Label>{t('notes')}</Label>
              <Input
                value={form.notes}
                onChange={(e) => setForm({ ...form, notes: e.target.value })}
                placeholder={t('notes')}
              />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setDialogOpen(false)}>{t('cancel')}</Button>
            <Button
              onClick={handleSubmit}
              className="bg-emerald-600 hover:bg-emerald-700"
              disabled={saving || !form.name}
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {editingClient ? t('save_changes') : t('clients_add')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent dir="rtl">
          <AlertDialogHeader>
            <AlertDialogTitle>{t('clients_delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('clients_delete_irreversible')}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('cancel')}</AlertDialogCancel>
            <AlertDialogAction onClick={handleDelete} className="bg-red-600 hover:bg-red-700">
              {t('delete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
