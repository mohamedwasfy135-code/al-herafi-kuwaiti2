'use client'

import { useState, useEffect, useMemo, useCallback } from 'react'
import {
  FileCheck,
  Plus,
  ArrowDownToLine,
  ArrowUpFromLine,
  Search,
  Loader2,
  Banknote,
  Calendar,
  User,
  Trash2,
  CreditCard,
  Landmark,
  Wallet,
  Filter,
  Check,
  ChevronsUpDown,
  Users,
  Truck,
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
import { Textarea } from '@/components/ui/textarea'
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
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command'
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover'
import { cn } from '@/lib/utils'
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'

// ─── Types ───────────────────────────────────────────────────────

interface Account {
  id: number
  code: string
  name: string
}

interface Client {
  id: number
  name: string
  phone?: string | null
  email?: string | null
  balance?: number
  user?: { id: string; name: string; phone?: string; email?: string } | null
}

interface Supplier {
  id: number
  name: string
  nameEn?: string | null
  phone?: string | null
  balance?: number
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
  paymentMethod: string | null
  issuedDate: string | null
  createdAt: string
  account?: Account | null
}

type AccountOption = {
  value: string
  label: string
  type: 'account' | 'client' | 'supplier'
  id: number
  code?: string
}

// ─── Sample Data ─────────────────────────────────────────────────

const sampleReceiptBonds: Bond[] = [
  {
    id: 1,
    bondNumber: 'RB-00001',
    bondType: 'receipt',
    amount: 500,
    accountId: null,
    partyName: 'أحمد محمد',
    partyType: 'client',
    description: 'دفعة فاتورة #SI-00001',
    referenceType: null,
    referenceId: null,
    paymentMethod: 'cash',
    issuedDate: new Date().toISOString(),
    createdAt: new Date().toISOString(),
  },
  {
    id: 2,
    bondNumber: 'RB-00002',
    bondType: 'receipt',
    amount: 280,
    accountId: null,
    partyName: 'فاطمة حسن',
    partyType: 'client',
    description: 'دفعة نقدية',
    referenceType: null,
    referenceId: null,
    paymentMethod: 'cash',
    issuedDate: new Date(Date.now() - 86400000).toISOString(),
    createdAt: new Date(Date.now() - 86400000).toISOString(),
  },
  {
    id: 3,
    bondNumber: 'RB-00003',
    bondType: 'receipt',
    amount: 150,
    accountId: null,
    partyName: 'محمد عبدالله',
    partyType: null,
    description: 'دفعة جزئية',
    referenceType: null,
    referenceId: null,
    paymentMethod: 'knet',
    issuedDate: new Date(Date.now() - 172800000).toISOString(),
    createdAt: new Date(Date.now() - 172800000).toISOString(),
  },
]

const samplePaymentBonds: Bond[] = [
  {
    id: 4,
    bondNumber: 'PB-00001',
    bondType: 'payment',
    amount: 350,
    accountId: null,
    partyName: 'شركة الأنابيب الكويتية',
    partyType: 'supplier',
    description: 'دفعة مورد #PI-00001',
    referenceType: null,
    referenceId: null,
    paymentMethod: 'bank',
    issuedDate: new Date().toISOString(),
    createdAt: new Date().toISOString(),
  },
  {
    id: 5,
    bondNumber: 'PB-00002',
    bondType: 'payment',
    amount: 80,
    accountId: null,
    partyName: 'صاحب العقار',
    partyType: null,
    description: 'إيجار المحل - يونيو',
    referenceType: null,
    referenceId: null,
    paymentMethod: 'cash',
    issuedDate: new Date(Date.now() - 86400000).toISOString(),
    createdAt: new Date(Date.now() - 86400000).toISOString(),
  },
  {
    id: 6,
    bondNumber: 'PB-00003',
    bondType: 'payment',
    amount: 200,
    accountId: null,
    partyName: 'مؤسسة الكابلات',
    partyType: 'supplier',
    description: 'دفعة مورد',
    referenceType: null,
    referenceId: null,
    paymentMethod: 'knet',
    issuedDate: new Date(Date.now() - 259200000).toISOString(),
    createdAt: new Date(Date.now() - 259200000).toISOString(),
  },
]

// ─── Component ───────────────────────────────────────────────────

export function BondsTab() {
  const { t, lang, dir } = useLanguage()

  const [receiptBonds, setReceiptBonds] = useState<Bond[]>(sampleReceiptBonds)
  const [paymentBonds, setPaymentBonds] = useState<Bond[]>(samplePaymentBonds)
  const [accounts, setAccounts] = useState<Account[]>([])
  const [clients, setClients] = useState<Client[]>([])
  const [suppliers, setSuppliers] = useState<Supplier[]>([])
  const [search, setSearch] = useState('')
  const [accountTypeFilter, setAccountTypeFilter] = useState<string>('all')
  const [dialogOpen, setDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingBond, setDeletingBond] = useState<Bond | null>(null)
  const [bondType, setBondType] = useState<'receipt' | 'payment'>('receipt')
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [accountPopoverOpen, setAccountPopoverOpen] = useState(false)
  const [partyPopoverOpen, setPartyPopoverOpen] = useState(false)
  const [form, setForm] = useState({
    amount: '',
    partyName: '',
    description: '',
    reason: '',
    accountId: '',
    accountType: '' as 'account' | 'client' | 'supplier' | '',
    referenceId: '',
    issuedDate: '',
    paymentMethod: '' as 'cash' | 'bank' | 'knet' | '',
  })

  const businessId = getBusinessId()

  // ─── Maps (inside component for i18n) ────────────────────────

  const paymentMethodMap = useMemo(() => ({
    cash: { label: t('bonds_cash'), color: 'bg-amber-100 text-amber-700', icon: Wallet },
    bank: { label: t('bonds_bank'), color: 'bg-sky-100 text-sky-700', icon: Landmark },
    knet: { label: t('bonds_knet'), color: 'bg-purple-100 text-purple-700', icon: CreditCard },
  }), [t])

  const partyTypeMap = useMemo(() => ({
    client: { label: t('bonds_client_prefix'), color: 'bg-teal-100 text-teal-700', icon: Users },
    supplier: { label: t('bonds_supplier_prefix'), color: 'bg-orange-100 text-orange-700', icon: Truck },
    account: { label: t('bonds_account'), color: 'bg-slate-100 text-slate-700', icon: BookOpen },
  }), [t])

  const getPartyTypeInfo = useCallback((bond: Bond) => {
    if (bond.partyType && partyTypeMap[bond.partyType as keyof typeof partyTypeMap]) {
      return partyTypeMap[bond.partyType as keyof typeof partyTypeMap]
    }
    if (bond.accountId) {
      return partyTypeMap.account
    }
    return null
  }, [partyTypeMap])

  // ─── Build combined account options ──────────────────────────

  const accountOptions = useMemo<AccountOption[]>(() => {
    const opts: AccountOption[] = []

    for (const a of accounts) {
      opts.push({
        value: `account-${a.id}`,
        label: `${a.code} - ${a.name}`,
        type: 'account',
        id: a.id,
        code: a.code,
      })
    }

    for (const c of clients) {
      opts.push({
        value: `client-${c.id}`,
        label: `${t('bonds_client_prefix')} - ${c.name}`,
        type: 'client',
        id: c.id,
      })
    }

    for (const s of suppliers) {
      opts.push({
        value: `supplier-${s.id}`,
        label: `${t('bonds_supplier_prefix')} - ${s.name}`,
        type: 'supplier',
        id: s.id,
      })
    }

    return opts
  }, [accounts, clients, suppliers, t])

  // ─── Party names for autocomplete ───────────────────────────

  const partyNames = useMemo(() => {
    const names = new Set<string>()
    for (const c of clients) names.add(c.name)
    for (const s of suppliers) names.add(s.name)
    return Array.from(names).sort()
  }, [clients, suppliers])

  const filteredPartyNames = useMemo(() => {
    if (!form.partyName || form.partyName.length < 1) return []
    return partyNames.filter((n) => n.includes(form.partyName)).slice(0, 8)
  }, [form.partyName, partyNames])

  // ─── Fetch data ─────────────────────────────────────────────

  const fetchData = useCallback(async () => {
    setLoading(true)
    try {
      const [bondsRes, accountsRes, clientsRes, suppliersRes] =
        await Promise.all([
          fetch(`/api/bonds?businessId=${businessId}`),
          fetch(`/api/accounts?businessId=${businessId}`),
          fetch(`/api/clients?businessId=${businessId}`),
          fetch(`/api/suppliers?businessId=${businessId}`),
        ])

      if (bondsRes.ok) {
        const data = await bondsRes.json()
        if (data.length > 0) {
          setReceiptBonds(data.filter((b: Bond) => b.bondType === 'receipt'))
          setPaymentBonds(data.filter((b: Bond) => b.bondType === 'payment'))
        }
      }

      if (accountsRes.ok) {
        const data = await accountsRes.json()
        const flat: Account[] = []
        const flatten = (accts: any[]) => {
          for (const a of accts) {
            flat.push({ id: a.id, code: a.code, name: a.name })
            if (a.children) flatten(a.children)
          }
        }
        flatten(data)
        setAccounts(flat)
      }

      if (clientsRes.ok) {
        const data = await clientsRes.json()
        if (Array.isArray(data)) setClients(data)
      }

      if (suppliersRes.ok) {
        const data = await suppliersRes.json()
        if (Array.isArray(data)) setSuppliers(data)
      }
    } catch {
      // Keep sample data
    } finally {
      setLoading(false)
    }
  }, [businessId])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  // ─── Selected account label ─────────────────────────────────

  const selectedAccountLabel = useMemo(() => {
    if (!form.accountId) return ''
    const opt = accountOptions.find((o) => o.value === form.accountId)
    return opt?.label || ''
  }, [form.accountId, accountOptions])

  // ─── Dialog open ────────────────────────────────────────────

  const openCreateDialog = (type: 'receipt' | 'payment') => {
    setBondType(type)
    setForm({
      amount: '',
      partyName: '',
      description: '',
      reason: '',
      accountId: '',
      accountType: '',
      referenceId: '',
      issuedDate: new Date().toISOString().split('T')[0],
      paymentMethod: '',
    })
    setDialogOpen(true)
  }

  // ─── Handle account selection ───────────────────────────────

  const handleAccountSelect = (value: string) => {
    const opt = accountOptions.find((o) => o.value === value)
    if (opt) {
      setForm((prev) => ({
        ...prev,
        accountId: value,
        accountType: opt.type,
        referenceId: String(opt.id),
        // Auto-fill party name if client or supplier
        partyName:
          opt.type === 'client'
            ? clients.find((c) => c.id === opt.id)?.name || prev.partyName
            : opt.type === 'supplier'
              ? suppliers.find((s) => s.id === opt.id)?.name || prev.partyName
              : prev.partyName,
      }))
    }
    setAccountPopoverOpen(false)
  }

  // ─── Create bond ────────────────────────────────────────────

  const handleCreateBond = async () => {
    if (!form.amount || parseFloat(form.amount) <= 0) {
      toast.error(t('bonds_enter_valid_amount'))
      return
    }
    if (!form.reason.trim()) {
      toast.error(t('bonds_enter_reason'))
      return
    }

    setSaving(true)
    try {
      const bondNumber =
        bondType === 'receipt'
          ? `RB-${String(receiptBonds.length + 1).padStart(5, '0')}`
          : `PB-${String(paymentBonds.length + 1).padStart(5, '0')}`

      // Determine accountId for DB (only chart-of-accounts IDs)
      let dbAccountId: number | null = null
      if (form.accountType === 'account' && form.referenceId) {
        dbAccountId = parseInt(form.referenceId)
      }

      // Determine partyType
      let partyType: string | null = null
      if (form.accountType === 'client') partyType = 'client'
      else if (form.accountType === 'supplier') partyType = 'supplier'

      const description = form.reason
        ? `${form.reason}${form.description ? ' - ' + form.description : ''}`
        : form.description

      const res = await fetch('/api/bonds', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          bondNumber,
          bondType,
          amount: parseFloat(form.amount) || 0,
          partyName: form.partyName,
          partyType,
          description,
          accountId: dbAccountId,
          referenceType: form.accountType || null,
          referenceId: form.referenceId ? parseInt(form.referenceId) : null,
          paymentMethod: form.paymentMethod || null,
          issuedDate: form.issuedDate || new Date().toISOString(),
        }),
      })

      if (res.ok) {
        const saved = await res.json()
        if (bondType === 'receipt') {
          setReceiptBonds((prev) => [saved, ...prev])
        } else {
          setPaymentBonds((prev) => [saved, ...prev])
        }
        toast.success(
          bondType === 'receipt'
            ? t('bonds_receipt_created')
            : t('bonds_payment_created')
        )
      } else {
        // Fallback to local
        const acct =
          form.accountType === 'account' && form.referenceId
            ? accounts.find((a) => String(a.id) === form.referenceId)
            : null
        const newBond: Bond = {
          id: Date.now(),
          bondNumber,
          bondType,
          amount: parseFloat(form.amount) || 0,
          accountId: dbAccountId,
          partyName: form.partyName || null,
          partyType,
          description,
          referenceType: form.accountType || null,
          referenceId: form.referenceId ? parseInt(form.referenceId) : null,
          paymentMethod: form.paymentMethod || null,
          issuedDate: form.issuedDate || new Date().toISOString(),
          createdAt: new Date().toISOString(),
          account: acct
            ? { id: acct.id, code: acct.code, name: acct.name }
            : null,
        }
        if (bondType === 'receipt') {
          setReceiptBonds((prev) => [newBond, ...prev])
        } else {
          setPaymentBonds((prev) => [newBond, ...prev])
        }
        toast.success(
          bondType === 'receipt'
            ? t('bonds_receipt_created')
            : t('bonds_payment_created')
        )
      }
      setDialogOpen(false)
    } catch {
      toast.error(t('bonds_connection_error'))
    } finally {
      setSaving(false)
    }
  }

  // ─── Delete bond ────────────────────────────────────────────

  const confirmDelete = (bond: Bond) => {
    setDeletingBond(bond)
    setDeleteDialogOpen(true)
  }

  const handleDelete = async () => {
    if (!deletingBond) return
    try {
      // Try API delete first
      try {
        const res = await fetch(
          `/api/bonds/${deletingBond.id}?businessId=${businessId}`,
          { method: 'DELETE' }
        )
        if (res.ok) {
          toast.success(t('bonds_deleted'))
        }
      } catch {
        // API delete failed, do local delete
      }

      // Always update local state
      if (deletingBond.bondType === 'receipt') {
        setReceiptBonds((prev) => prev.filter((b) => b.id !== deletingBond.id))
      } else {
        setPaymentBonds((prev) => prev.filter((b) => b.id !== deletingBond.id))
      }
      toast.success(t('bonds_deleted'))
    } catch {
      toast.error(t('bonds_delete_failed'))
    } finally {
      setDeleteDialogOpen(false)
      setDeletingBond(null)
    }
  }

  // ─── Stats ──────────────────────────────────────────────────

  const totalReceipts = receiptBonds.reduce((sum, b) => sum + b.amount, 0)
  const totalPayments = paymentBonds.reduce((sum, b) => sum + b.amount, 0)
  const netBond = totalReceipts - totalPayments

  // ─── Locale for formatting ──────────────────────────────────

  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'

  // ─── Filter ─────────────────────────────────────────────────

  const filterBonds = (bonds: Bond[]) => {
    return bonds.filter((b) => {
      // Account type filter
      if (accountTypeFilter !== 'all') {
        if (accountTypeFilter === 'account' && !b.accountId) return false
        if (
          accountTypeFilter === 'client' &&
          b.partyType !== 'client' &&
          !(
            b.referenceType === 'client' ||
            (b.partyName && clients.some((c) => c.name === b.partyName))
          )
        )
          return false
        if (
          accountTypeFilter === 'supplier' &&
          b.partyType !== 'supplier' &&
          !(
            b.referenceType === 'supplier' ||
            (b.partyName && suppliers.some((s) => s.name === b.partyName))
          )
        )
          return false
      }

      // Search filter across all fields
      if (!search) return true
      const s = search.toLowerCase()
      const paymentLabel =
        b.paymentMethod && paymentMethodMap[b.paymentMethod as keyof typeof paymentMethodMap]
          ? paymentMethodMap[b.paymentMethod as keyof typeof paymentMethodMap].label
          : ''
      const partyLabel =
        b.partyType && partyTypeMap[b.partyType as keyof typeof partyTypeMap]
          ? partyTypeMap[b.partyType as keyof typeof partyTypeMap].label
          : ''
      return (
        b.bondNumber.toLowerCase().includes(s) ||
        (b.partyName && b.partyName.includes(s)) ||
        (b.description && b.description.includes(s)) ||
        String(b.amount).includes(s) ||
        paymentLabel.includes(s) ||
        partyLabel.includes(s) ||
        (b.account?.name && b.account.name.includes(s)) ||
        (b.account?.code && b.account.code.includes(s))
      )
    })
  }

  // ─── Render bond table ──────────────────────────────────────

  const renderBondTable = (bonds: Bond[], type: 'receipt' | 'payment') => (
    <div className="overflow-x-auto">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="text-right">{t('bonds_number')}</TableHead>
            <TableHead className="text-right">{t('bonds_party_label')}</TableHead>
            <TableHead className="text-right">{t('bonds_party_type')}</TableHead>
            <TableHead className="text-right">{t('bonds_amount_label')}</TableHead>
            <TableHead className="text-right">{t('bonds_payment_method')}</TableHead>
            <TableHead className="text-right">{t('bonds_account')}</TableHead>
            <TableHead className="text-right">{t('description')}</TableHead>
            <TableHead className="text-right">{t('bonds_date')}</TableHead>
            <TableHead className="text-right">{t('actions')}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {bonds.map((bond) => {
            const pTypeInfo = getPartyTypeInfo(bond)
            const pmInfo = bond.paymentMethod
              ? paymentMethodMap[bond.paymentMethod as keyof typeof paymentMethodMap]
              : null

            return (
              <TableRow key={bond.id} className="cursor-pointer">
                <TableCell className="font-medium whitespace-nowrap">
                  {bond.bondNumber}
                </TableCell>
                <TableCell>
                  <div className="flex items-center gap-1.5">
                    <User className="h-3.5 w-3.5 text-muted-foreground shrink-0" />
                    <span className="truncate max-w-[120px]">
                      {bond.partyName || '—'}
                    </span>
                  </div>
                </TableCell>
                <TableCell>
                  {pTypeInfo ? (
                    <Badge
                      variant="secondary"
                      className={cn('gap-1 text-xs', pTypeInfo.color)}
                    >
                      <pTypeInfo.icon className="h-3 w-3" />
                      {pTypeInfo.label}
                    </Badge>
                  ) : (
                    <span className="text-muted-foreground text-xs">—</span>
                  )}
                </TableCell>
                <TableCell
                  className={`font-medium whitespace-nowrap ${type === 'receipt' ? 'text-emerald-700' : 'text-red-700'}`}
                >
                  {type === 'receipt' ? '+' : '-'}
                  {bond.amount.toLocaleString(locale)} {t('currency')}
                </TableCell>
                <TableCell>
                  {pmInfo ? (
                    <Badge
                      variant="secondary"
                      className={cn('gap-1 text-xs', pmInfo.color)}
                    >
                      <pmInfo.icon className="h-3 w-3" />
                      {pmInfo.label}
                    </Badge>
                  ) : (
                    <span className="text-muted-foreground text-xs">—</span>
                  )}
                </TableCell>
                <TableCell className="text-sm text-muted-foreground whitespace-nowrap">
                  {bond.account
                    ? `${bond.account.code} - ${bond.account.name}`
                    : '—'}
                </TableCell>
                <TableCell className="text-sm text-muted-foreground max-w-[160px] truncate">
                  {bond.description || '—'}
                </TableCell>
                <TableCell className="text-xs text-muted-foreground whitespace-nowrap">
                  <div className="flex items-center gap-1">
                    <Calendar className="h-3 w-3 shrink-0" />
                    {new Date(
                      bond.issuedDate || bond.createdAt
                    ).toLocaleDateString(locale)}
                  </div>
                </TableCell>
                <TableCell>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-7 w-7 p-0 text-red-600 hover:text-red-700 hover:bg-red-50"
                    onClick={() => confirmDelete(bond)}
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </Button>
                </TableCell>
              </TableRow>
            )
          })}
        </TableBody>
      </Table>
    </div>
  )

  // ─── Render ─────────────────────────────────────────────────

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('bonds_title')}</h2>
          <p className="text-muted-foreground">{t('bonds_manage_desc')}</p>
        </div>
        <div className="flex items-center gap-3 flex-wrap">
          {/* Account Type Filter */}
          <Select
            value={accountTypeFilter}
            onValueChange={setAccountTypeFilter}
          >
            <SelectTrigger className="w-[140px] h-9">
              <Filter className="h-4 w-4 ml-1 text-muted-foreground" />
              <SelectValue placeholder={t('bonds_account_type')} />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t('all')}</SelectItem>
              <SelectItem value="account">{t('bonds_accounts_only')}</SelectItem>
              <SelectItem value="client">{t('bonds_clients_only')}</SelectItem>
              <SelectItem value="supplier">{t('bonds_suppliers_only')}</SelectItem>
            </SelectContent>
          </Select>

          {/* Search */}
          <div className="relative">
            <Search className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder={t('bonds_search_placeholder')}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-48 pr-9 sm:w-64 h-9"
            />
          </div>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-100">
              <ArrowDownToLine className="h-6 w-6 text-emerald-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('bonds_receipt_bonds')}</p>
              <p className="text-2xl font-bold text-emerald-700">
                {totalReceipts.toLocaleString(locale)}{' '}
                <span className="text-sm font-normal">{t('currency')}</span>
              </p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-red-100">
              <ArrowUpFromLine className="h-6 w-6 text-red-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('bonds_payment_bonds')}</p>
              <p className="text-2xl font-bold text-red-700">
                {totalPayments.toLocaleString(locale)}{' '}
                <span className="text-sm font-normal">{t('currency')}</span>
              </p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div
              className={`flex h-12 w-12 items-center justify-center rounded-xl ${netBond >= 0 ? 'bg-emerald-100' : 'bg-red-100'}`}
            >
              <Banknote
                className={`h-6 w-6 ${netBond >= 0 ? 'text-emerald-600' : 'text-red-600'}`}
              />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('bonds_net_bonds')}</p>
              <p
                className={`text-2xl font-bold ${netBond >= 0 ? 'text-emerald-700' : 'text-red-700'}`}
              >
                {netBond.toLocaleString(locale)}{' '}
                <span className="text-sm font-normal">{t('currency')}</span>
              </p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Bonds Tabs */}
      <Tabs defaultValue="receipt" dir={dir}>
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <TabsList>
            <TabsTrigger value="receipt" className="gap-2">
              <ArrowDownToLine className="h-4 w-4" />
              {t('bonds_receipt_bonds')} ({receiptBonds.length})
            </TabsTrigger>
            <TabsTrigger value="payment" className="gap-2">
              <ArrowUpFromLine className="h-4 w-4" />
              {t('bonds_payment_bonds')} ({paymentBonds.length})
            </TabsTrigger>
          </TabsList>
          <div className="flex gap-2">
            <Button
              onClick={() => openCreateDialog('receipt')}
              className="gap-2 bg-emerald-600 hover:bg-emerald-700"
              size="sm"
            >
              <ArrowDownToLine className="h-4 w-4" />
              {t('bonds_receipt')}
            </Button>
            <Button
              onClick={() => openCreateDialog('payment')}
              className="gap-2 bg-red-600 hover:bg-red-700"
              size="sm"
            >
              <ArrowUpFromLine className="h-4 w-4" />
              {t('bonds_payment')}
            </Button>
          </div>
        </div>

        <TabsContent value="receipt" className="mt-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">{t('bonds_receipt_bonds')}</CardTitle>
              <CardDescription>{t('bonds_receipt_record')}</CardDescription>
            </CardHeader>
            <CardContent className="p-0">
              {loading ? (
                <div className="flex items-center justify-center py-12">
                  <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
                </div>
              ) : filterBonds(receiptBonds).length === 0 ? (
                <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
                  <ArrowDownToLine className="h-12 w-12 mb-3 opacity-30" />
                  <p>{t('bonds_no_bonds')}</p>
                </div>
              ) : (
                renderBondTable(filterBonds(receiptBonds), 'receipt')
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="payment" className="mt-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">{t('bonds_payment_bonds')}</CardTitle>
              <CardDescription>{t('bonds_payment_record')}</CardDescription>
            </CardHeader>
            <CardContent className="p-0">
              {filterBonds(paymentBonds).length === 0 ? (
                <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
                  <ArrowUpFromLine className="h-12 w-12 mb-3 opacity-30" />
                  <p>{t('bonds_no_bonds')}</p>
                </div>
              ) : (
                renderBondTable(filterBonds(paymentBonds), 'payment')
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* ─── Create Bond Dialog ──────────────────────────────── */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-lg" dir={dir}>
          <DialogHeader>
            <DialogTitle>
              {bondType === 'receipt' ? t('bonds_new_receipt') : t('bonds_new_payment')}
            </DialogTitle>
            <DialogDescription>{t('bonds_enter_data')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            {/* Amount */}
            <div className="space-y-2">
              <Label>
                {t('bonds_amount_label')} <span className="text-red-500">*</span>
              </Label>
              <div className="relative">
                <Input
                  type="number"
                  value={form.amount}
                  onChange={(e) =>
                    setForm({ ...form, amount: e.target.value })
                  }
                  placeholder="0"
                  className="pl-16"
                />
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm text-muted-foreground">
                  {t('currency')}
                </span>
              </div>
            </div>

            {/* Party Name with autocomplete */}
            <div className="space-y-2">
              <Label>{t('bonds_party_name')}</Label>
              <Popover open={partyPopoverOpen} onOpenChange={setPartyPopoverOpen}>
                <PopoverTrigger asChild>
                  <div className="relative">
                    <Input
                      value={form.partyName}
                      onChange={(e) => {
                        setForm({ ...form, partyName: e.target.value })
                        if (e.target.value.length >= 1) {
                          setPartyPopoverOpen(true)
                        }
                      }}
                      placeholder={
                        bondType === 'receipt'
                          ? t('bonds_payer_name')
                          : t('bonds_beneficiary_name')
                      }
                      onFocus={() => {
                        if (form.partyName.length >= 1) setPartyPopoverOpen(true)
                      }}
                    />
                  </div>
                </PopoverTrigger>
                <PopoverContent
                  className="p-0 w-[var(--radix-popover-trigger-width)]"
                  align="start"
                >
                  <Command>
                    <CommandList>
                      <CommandEmpty>{t('no_results')}</CommandEmpty>
                      <CommandGroup>
                        {filteredPartyNames.map((name) => (
                          <CommandItem
                            key={name}
                            value={name}
                            onSelect={() => {
                              setForm({ ...form, partyName: name })
                              setPartyPopoverOpen(false)
                            }}
                          >
                            <Check
                              className={cn(
                                'h-4 w-4 ml-2',
                                form.partyName === name
                                  ? 'opacity-100'
                                  : 'opacity-0'
                              )}
                            />
                            {name}
                          </CommandItem>
                        ))}
                      </CommandGroup>
                    </CommandList>
                  </Command>
                </PopoverContent>
              </Popover>
            </div>

            {/* Reason */}
            <div className="space-y-2">
              <Label>
                {t('bonds_reason')} <span className="text-red-500">*</span>
              </Label>
              <Input
                value={form.reason}
                onChange={(e) => setForm({ ...form, reason: e.target.value })}
                placeholder={t('bonds_reason_placeholder')}
              />
            </div>

            {/* Account - Grouped Combobox */}
            <div className="space-y-2">
              <Label>{t('bonds_account')}</Label>
              <Popover
                open={accountPopoverOpen}
                onOpenChange={setAccountPopoverOpen}
              >
                <PopoverTrigger asChild>
                  <Button
                    variant="outline"
                    role="combobox"
                    aria-expanded={accountPopoverOpen}
                    className="w-full justify-between font-normal"
                  >
                    {selectedAccountLabel || t('bonds_select_account')}
                    <ChevronsUpDown className="h-4 w-4 shrink-0 opacity-50" />
                  </Button>
                </PopoverTrigger>
                <PopoverContent
                  className="p-0 w-[var(--radix-popover-trigger-width)]"
                  align="start"
                >
                  <Command>
                    <CommandInput placeholder={t('bonds_search_accounts')} />
                    <CommandList className="max-h-64">
                      <CommandEmpty>{t('no_results')}</CommandEmpty>

                      {/* Chart of Accounts */}
                      <CommandGroup heading={t('bonds_main_accounts')}>
                        {accounts.map((a) => (
                          <CommandItem
                            key={`account-${a.id}`}
                            value={`account-${a.id} ${a.code} ${a.name}`}
                            onSelect={() =>
                              handleAccountSelect(`account-${a.id}`)
                            }
                          >
                            <BookOpen className="h-4 w-4 ml-2 text-slate-500 shrink-0" />
                            <span className="truncate">
                              {a.code} - {a.name}
                            </span>
                            <Check
                              className={cn(
                                'h-4 w-4 mr-auto',
                                form.accountId === `account-${a.id}`
                                  ? 'opacity-100'
                                  : 'opacity-0'
                              )}
                            />
                          </CommandItem>
                        ))}
                        {accounts.length === 0 && (
                          <p className="px-2 py-1.5 text-xs text-muted-foreground">
                            {t('bonds_no_accounts')}
                          </p>
                        )}
                      </CommandGroup>

                      {/* Clients */}
                      <CommandGroup heading={t('nav_clients')}>
                        {clients.map((c) => (
                          <CommandItem
                            key={`client-${c.id}`}
                            value={`client-${c.id} ${t('bonds_client_prefix')} ${c.name}`}
                            onSelect={() =>
                              handleAccountSelect(`client-${c.id}`)
                            }
                          >
                            <Users className="h-4 w-4 ml-2 text-teal-500 shrink-0" />
                            <span className="truncate">{t('bonds_client_prefix')} - {c.name}</span>
                            <Check
                              className={cn(
                                'h-4 w-4 mr-auto',
                                form.accountId === `client-${c.id}`
                                  ? 'opacity-100'
                                  : 'opacity-0'
                              )}
                            />
                          </CommandItem>
                        ))}
                        {clients.length === 0 && (
                          <p className="px-2 py-1.5 text-xs text-muted-foreground">
                            {t('bonds_no_clients')}
                          </p>
                        )}
                      </CommandGroup>

                      {/* Suppliers */}
                      <CommandGroup heading={t('nav_suppliers')}>
                        {suppliers.map((s) => (
                          <CommandItem
                            key={`supplier-${s.id}`}
                            value={`supplier-${s.id} ${t('bonds_supplier_prefix')} ${s.name}`}
                            onSelect={() =>
                              handleAccountSelect(`supplier-${s.id}`)
                            }
                          >
                            <Truck className="h-4 w-4 ml-2 text-orange-500 shrink-0" />
                            <span className="truncate">{t('bonds_supplier_prefix')} - {s.name}</span>
                            <Check
                              className={cn(
                                'h-4 w-4 mr-auto',
                                form.accountId === `supplier-${s.id}`
                                  ? 'opacity-100'
                                  : 'opacity-0'
                              )}
                            />
                          </CommandItem>
                        ))}
                        {suppliers.length === 0 && (
                          <p className="px-2 py-1.5 text-xs text-muted-foreground">
                            {t('bonds_no_suppliers')}
                          </p>
                        )}
                      </CommandGroup>
                    </CommandList>
                  </Command>
                </PopoverContent>
              </Popover>
            </div>

            {/* Payment Method */}
            <div className="space-y-2">
              <Label>{t('bonds_payment_method')}</Label>
              <div className="grid grid-cols-3 gap-2">
                {(
                  Object.entries(paymentMethodMap) as [
                    string,
                    { label: string; color: string; icon: React.ElementType },
                  ][]
                ).map(([key, { label, icon: Icon }]) => (
                  <Button
                    key={key}
                    type="button"
                    variant={form.paymentMethod === key ? 'default' : 'outline'}
                    className={cn(
                      'gap-2 h-10 text-sm',
                      form.paymentMethod === key && 'bg-primary text-primary-foreground'
                    )}
                    onClick={() =>
                      setForm({
                        ...form,
                        paymentMethod:
                          form.paymentMethod === key
                            ? ''
                            : (key as 'cash' | 'bank' | 'knet'),
                      })
                    }
                  >
                    {Icon && <Icon className="h-4 w-4" />}
                    {label}
                  </Button>
                ))}
              </div>
            </div>

            {/* Additional Description */}
            <div className="space-y-2">
              <Label>{t('bonds_additional_desc')}</Label>
              <Textarea
                value={form.description}
                onChange={(e) =>
                  setForm({ ...form, description: e.target.value })
                }
                placeholder={t('bonds_desc_placeholder')}
                rows={2}
              />
            </div>

            {/* Bond Date */}
            <div className="space-y-2">
              <Label>{t('bonds_date')}</Label>
              <Input
                type="date"
                value={form.issuedDate}
                onChange={(e) =>
                  setForm({ ...form, issuedDate: e.target.value })
                }
              />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setDialogOpen(false)}>
              {t('cancel')}
            </Button>
            <Button
              onClick={handleCreateBond}
              className={
                bondType === 'receipt'
                  ? 'bg-emerald-600 hover:bg-emerald-700'
                  : 'bg-red-600 hover:bg-red-700'
              }
              disabled={saving || !form.amount || !form.reason.trim()}
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {t('bonds_create_bond')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Delete Confirmation ─────────────────────────────── */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent dir={dir}>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('bonds_delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('bonds_delete_confirm')} {t('bonds_delete_irreversible')}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('cancel')}</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              className="bg-red-600 hover:bg-red-700"
            >
              {t('delete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
