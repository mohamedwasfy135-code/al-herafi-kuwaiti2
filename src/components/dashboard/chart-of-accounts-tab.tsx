'use client'

import { useState, useEffect, useCallback, useMemo } from 'react'
import {
  Plus,
  BookOpen,
  Pencil,
  Trash2,
  ChevronDown,
  ChevronLeft,
  Loader2,
  RefreshCw,
  Landmark,
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'

interface Account {
  id: number
  code: string
  name: string
  nameEn: string | null
  accountType: string
  parentId: number | null
  currentBalance: number
  openingBalance: number
  isActive: boolean
  description: string | null
  children?: Account[]
  _count?: { debitTransactions: number; creditTransactions: number }
}

const defaultForm = {
  code: '',
  name: '',
  nameEn: '',
  accountType: 'asset',
  parentId: 'none',
  currentBalance: '',
  openingBalance: '',
  description: '',
}

export function ChartOfAccountsTab() {
  const { t, lang, dir } = useLanguage()

  const accountTypeMap = useMemo(() => ({
    asset: { label: t('account_asset'), color: 'bg-emerald-100 text-emerald-700' },
    liability: { label: t('account_liability'), color: 'bg-red-100 text-red-700' },
    equity: { label: t('account_equity'), color: 'bg-violet-100 text-violet-700' },
    revenue: { label: t('account_revenue'), color: 'bg-sky-100 text-sky-700' },
    expense: { label: t('account_expense'), color: 'bg-amber-100 text-amber-700' },
  }), [t])
  const [accounts, setAccounts] = useState<Account[]>([])
  const [expandedIds, setExpandedIds] = useState<Set<number>>(new Set())
  const [dialogOpen, setDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [deleteError, setDeleteError] = useState<string | null>(null)
  const [editingAccount, setEditingAccount] = useState<Account | null>(null)
  const [form, setForm] = useState(defaultForm)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [initializing, setInitializing] = useState(false)

  const businessId = getBusinessId()
  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'
  const formatCurrency = (amount: number) => amount.toLocaleString(locale, { minimumFractionDigits: 3, maximumFractionDigits: 3 })

  const fetchAccounts = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`/api/accounts?businessId=${businessId}`)
      if (res.ok) {
        const data = await res.json()
        setAccounts(data)
        setExpandedIds(new Set(data.map((a: Account) => a.id)))
      }
    } catch {
      // Keep empty
    } finally {
      setLoading(false)
    }
  }, [businessId])

  useEffect(() => {
    fetchAccounts()
  }, [fetchAccounts])

  const toggleExpand = (id: number) => {
    setExpandedIds((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const openCreate = (parentId?: number) => {
    setEditingAccount(null)
    setForm({ ...defaultForm, parentId: parentId ? String(parentId) : 'none' })
    setDialogOpen(true)
  }

  const openEdit = (account: Account) => {
    setEditingAccount(account)
    setForm({
      code: account.code,
      name: account.name,
      nameEn: account.nameEn || '',
      accountType: account.accountType,
      parentId: account.parentId ? String(account.parentId) : 'none',
      currentBalance: String(account.currentBalance),
      openingBalance: String(account.openingBalance),
      description: account.description || '',
    })
    setDialogOpen(true)
  }

  const handleInitialize = async () => {
    setInitializing(true)
    try {
      const res = await fetch('/api/accounts/initialize', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ businessId }),
      })
      const data = await res.json()
      if (res.ok) {
        toast.success(data.message || t('coa_initialize_success'))
        fetchAccounts()
      } else {
        toast.info(data.message || t('coa_already_exists'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setInitializing(false)
    }
  }

  const handleSubmit = async () => {
    if (!form.code || !form.name || !form.accountType) {
      toast.error(t('coa_code_name_type_required'))
      return
    }
    setSaving(true)
    try {
      const url = editingAccount
        ? `/api/accounts/${editingAccount.id}`
        : '/api/accounts'
      const method = editingAccount ? 'PUT' : 'POST'

      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          code: form.code,
          name: form.name,
          nameEn: form.nameEn || null,
          accountType: form.accountType,
          parentId: form.parentId !== 'none' ? parseInt(form.parentId) : null,
          currentBalance: form.currentBalance || 0,
          openingBalance: form.openingBalance || 0,
          description: form.description || null,
        }),
      })

      if (res.ok) {
        toast.success(editingAccount ? t('coa_update_success') : t('coa_add_success'))
        setDialogOpen(false)
        fetchAccounts()
      } else {
        const err = await res.json()
        toast.error(err.error || t('coa_save_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  const confirmDelete = (id: number) => {
    setDeletingId(id)
    setDeleteError(null)
    setDeleteDialogOpen(true)
  }

  const handleDelete = async () => {
    if (!deletingId) return
    try {
      const res = await fetch(`/api/accounts/${deletingId}`, { method: 'DELETE' })
      if (res.ok) {
        toast.success(t('coa_delete_success'))
        fetchAccounts()
        setDeleteDialogOpen(false)
        setDeletingId(null)
        setDeleteError(null)
      } else {
        const err = await res.json()
        if (res.status === 400) {
          setDeleteError(err.error || t('coa_cannot_delete'))
        } else {
          toast.error(err.error || t('coa_delete_failed'))
          setDeleteDialogOpen(false)
          setDeletingId(null)
        }
      }
    } catch {
      toast.error(t('error_connection'))
      setDeleteDialogOpen(false)
      setDeletingId(null)
    }
  }

  // Flatten accounts for parent dropdown
  const flatAccounts: { id: number; name: string; code: string }[] = []
  const flatten = (accts: Account[], prefix: string = '') => {
    for (const a of accts) {
      flatAccounts.push({ id: a.id, name: prefix + a.name, code: a.code })
      if (a.children) flatten(a.children, prefix + a.name + ' / ')
    }
  }
  flatten(accounts)

  // Calculate totals by type
  const totalsByType: Record<string, number> = {}
  const calcTotals = (accts: Account[]) => {
    for (const a of accts) {
      if (!totalsByType[a.accountType]) totalsByType[a.accountType] = 0
      totalsByType[a.accountType] += a.currentBalance
      if (a.children) calcTotals(a.children)
    }
  }
  calcTotals(accounts)

  const renderAccount = (account: Account, depth: number = 0) => {
    const hasChildren = account.children && account.children.length > 0
    const isExpanded = expandedIds.has(account.id)
    const typeInfo = accountTypeMap[account.accountType] || { label: account.accountType, color: 'bg-gray-100 text-gray-700' }

    return (
      <div key={account.id}>
        <div
          className={`flex items-center gap-2 py-2.5 px-3 rounded-lg hover:bg-gray-50 transition-colors ${
            depth > 0 ? 'mr-8' : ''
          }`}
        >
          <button onClick={() => hasChildren && toggleExpand(account.id)} className="flex items-center">
            {hasChildren ? (
              isExpanded ? <ChevronDown className="h-4 w-4 text-muted-foreground" /> : <ChevronLeft className="h-4 w-4 text-muted-foreground" />
            ) : (
              <span className="w-4" />
            )}
          </button>
          <span className="text-xs font-mono text-muted-foreground w-12 shrink-0">{account.code}</span>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <span className="font-medium text-sm truncate">{account.name}</span>
              <Badge variant="secondary" className={`text-[10px] ${typeInfo.color}`}>
                {typeInfo.label}
              </Badge>
              {!account.isActive && (
                <Badge variant="outline" className="text-[10px] text-red-600">{t('employees_active_no')}</Badge>
              )}
            </div>
          </div>
          <span className="text-sm font-medium ml-4">
            {formatCurrency(account.currentBalance)} <span className="text-xs text-muted-foreground">{t('currency')}</span>
          </span>
          <div className="flex items-center gap-1">
            <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={() => openCreate(account.id)}>
              <Plus className="h-3.5 w-3.5" />
            </Button>
            <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={() => openEdit(account)}>
              <Pencil className="h-3.5 w-3.5" />
            </Button>
            <Button variant="ghost" size="sm" className="h-7 w-7 p-0 text-red-600 hover:text-red-700 hover:bg-red-50" onClick={() => confirmDelete(account.id)}>
              <Trash2 className="h-3.5 w-3.5" />
            </Button>
          </div>
        </div>
        {hasChildren && isExpanded && (
          <div>
            {account.children!.map((child) => renderAccount(child, depth + 1))}
          </div>
        )}
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('coa_title')}</h2>
          <p className="text-muted-foreground">{t('coa_subtitle')}</p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            onClick={handleInitialize}
            disabled={initializing}
            className="gap-2"
          >
            {initializing ? <Loader2 className="h-4 w-4 animate-spin" /> : <RefreshCw className="h-4 w-4" />}
            {t('coa_initialize_default')}
          </Button>
          <Button onClick={() => openCreate()} className="gap-2 bg-emerald-600 hover:bg-emerald-700">
            <Plus className="h-4 w-4" />
            {t('coa_add_account')}
          </Button>
        </div>
      </div>

      {/* Account Type Totals */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-5">
        {Object.entries(accountTypeMap).map(([type, info]) => (
          <Card key={type}>
            <CardContent className="p-4">
              <Badge variant="secondary" className={`text-xs mb-2 ${info.color}`}>{info.label}</Badge>
              <p className="text-lg font-bold">
                {formatCurrency(totalsByType[type] || 0)} <span className="text-xs font-normal text-muted-foreground">{t('currency')}</span>
              </p>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Accounts Tree */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base flex items-center gap-2">
            <BookOpen className="h-5 w-5 text-emerald-600" />
            {t('coa_account_tree')}
          </CardTitle>
          <CardDescription>{t('coa_expand_hint')}</CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            </div>
          ) : accounts.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <Landmark className="h-12 w-12 mb-3 opacity-30" />
              <p>{t('coa_no_accounts')}</p>
              <Button variant="outline" size="sm" className="mt-3 gap-2" onClick={handleInitialize}>
                <RefreshCw className="h-4 w-4" />
                {t('coa_initialize_default_btn')}
              </Button>
            </div>
          ) : (
            <div className="space-y-1">{accounts.map((acct) => renderAccount(acct))}</div>
          )}
        </CardContent>
      </Card>

      {/* Create/Edit Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-md" dir={dir}>
          <DialogHeader>
            <DialogTitle>{editingAccount ? t('coa_edit_account') : t('coa_add_new')}</DialogTitle>
            <DialogDescription>{t('coa_enter_data')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('coa_code_required')} *</Label>
                <Input value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value })} placeholder="1000" />
              </div>
              <div className="space-y-2">
                <Label>{t('coa_name_required')} *</Label>
                <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder={t('coa_name_required')} />
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('coa_type_required')} *</Label>
              <Select value={form.accountType} onValueChange={(val) => setForm({ ...form, accountType: val })}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="asset">{t('account_asset')}</SelectItem>
                  <SelectItem value="liability">{t('account_liability')}</SelectItem>
                  <SelectItem value="equity">{t('account_equity')}</SelectItem>
                  <SelectItem value="revenue">{t('account_revenue')}</SelectItem>
                  <SelectItem value="expense">{t('account_expense')}</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>{t('coa_parent_account')}</Label>
              <Select value={form.parentId} onValueChange={(val) => setForm({ ...form, parentId: val })}>
                <SelectTrigger>
                  <SelectValue placeholder={t('coa_root_account')} />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">{t('coa_root_no_parent')}</SelectItem>
                  {flatAccounts.filter((a) => a.id !== editingAccount?.id).map((a) => (
                    <SelectItem key={a.id} value={String(a.id)}>{a.code} - {a.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('coa_opening_balance')}</Label>
                <Input type="number" value={form.openingBalance} onChange={(e) => setForm({ ...form, openingBalance: e.target.value })} placeholder="0" />
              </div>
              <div className="space-y-2">
                <Label>{t('coa_current_balance')}</Label>
                <Input type="number" value={form.currentBalance} onChange={(e) => setForm({ ...form, currentBalance: e.target.value })} placeholder="0" />
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('description')}</Label>
              <Input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder={t('coa_description_placeholder')} />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setDialogOpen(false)}>{t('cancel')}</Button>
            <Button onClick={handleSubmit} className="bg-emerald-600 hover:bg-emerald-700" disabled={saving || !form.code || !form.name}>
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {editingAccount ? t('save_changes') : t('coa_add_btn')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={(open) => {
        setDeleteDialogOpen(open)
        if (!open) {
          setDeletingId(null)
          setDeleteError(null)
        }
      }}>
        <AlertDialogContent dir={dir}>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('coa_delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>
              {deleteError ? (
                <span className="text-red-600 font-medium">{deleteError}</span>
              ) : (
                t('coa_delete_subaccounts')
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('cancel')}</AlertDialogCancel>
            {!deleteError && (
              <AlertDialogAction onClick={handleDelete} className="bg-red-600 hover:bg-red-700">{t('delete')}</AlertDialogAction>
            )}
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
