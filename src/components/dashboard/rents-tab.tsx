'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  Plus,
  Home,
  Pencil,
  Trash2,
  Loader2,
  DollarSign,
  Calendar,
  User,
  Building,
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
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'

interface RentRecord {
  id: number
  propertyOwner: string | null
  propertyDesc: string | null
  amount: number
  dueDay: number
  startDate: string | null
  endDate: string | null
  accountId: number | null
  notes: string | null
  isActive: boolean
  account: { id: number; name: string; code: string } | null
}

interface Account {
  id: number
  code: string
  name: string
}

const defaultForm = {
  propertyOwner: '',
  propertyDesc: '',
  amount: '',
  dueDay: '1',
  startDate: '',
  endDate: '',
  accountId: 'none',
  notes: '',
}

export function RentsTab() {
  const { t, lang, dir } = useLanguage()
  const [rents, setRents] = useState<RentRecord[]>([])
  const [accounts, setAccounts] = useState<Account[]>([])
  const [dialogOpen, setDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [editingRent, setEditingRent] = useState<RentRecord | null>(null)
  const [form, setForm] = useState(defaultForm)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [payingId, setPayingId] = useState<number | null>(null)

  const businessId = getBusinessId()
  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'
  const formatCurrency = (amount: number) => amount.toLocaleString(locale, { minimumFractionDigits: 3, maximumFractionDigits: 3 })
  const formatDate = (dateStr?: string | null) => { if (!dateStr) return '—'; return new Date(dateStr).toLocaleDateString(locale) }

  const fetchRents = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`/api/rents?businessId=${businessId}`)
      if (res.ok) {
        const data = await res.json()
        setRents(data)
      }
    } catch {
      // Keep empty
    } finally {
      setLoading(false)
    }
  }, [businessId])

  const fetchAccounts = useCallback(async () => {
    try {
      const res = await fetch(`/api/accounts?businessId=${businessId}`)
      if (res.ok) {
        const data = await res.json()
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
    } catch {
      // Keep empty
    }
  }, [businessId])

  useEffect(() => {
    fetchRents()
  }, [fetchRents])

  useEffect(() => {
    fetchAccounts()
  }, [fetchAccounts])

  const openCreate = () => {
    setEditingRent(null)
    setForm(defaultForm)
    setDialogOpen(true)
  }

  const openEdit = (rent: RentRecord) => {
    setEditingRent(rent)
    setForm({
      propertyOwner: rent.propertyOwner || '',
      propertyDesc: rent.propertyDesc || '',
      amount: String(rent.amount),
      dueDay: String(rent.dueDay),
      startDate: rent.startDate ? new Date(rent.startDate).toISOString().split('T')[0] : '',
      endDate: rent.endDate ? new Date(rent.endDate).toISOString().split('T')[0] : '',
      accountId: rent.accountId ? String(rent.accountId) : 'none',
      notes: rent.notes || '',
    })
    setDialogOpen(true)
  }

  const handleSubmit = async () => {
    if (!form.propertyOwner || !form.amount) {
      toast.error(t('rents_owner_required'))
      return
    }
    setSaving(true)
    try {
      const url = editingRent ? `/api/rents/${editingRent.id}` : '/api/rents'
      const method = editingRent ? 'PUT' : 'POST'

      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          propertyOwner: form.propertyOwner,
          propertyDesc: form.propertyDesc || null,
          amount: parseFloat(form.amount) || 0,
          dueDay: parseInt(form.dueDay) || 1,
          startDate: form.startDate || null,
          endDate: form.endDate || null,
          accountId: form.accountId !== 'none' ? parseInt(form.accountId) : null,
          notes: form.notes || null,
        }),
      })

      if (res.ok) {
        toast.success(editingRent ? t('rents_update_success') : t('rents_add_success'))
        setDialogOpen(false)
        fetchRents()
      } else {
        const err = await res.json()
        toast.error(err.error || t('rents_save_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  const handlePayRent = async (rent: RentRecord) => {
    if (!rent.accountId) {
      toast.error(t('rents_no_account_linked'))
      return
    }
    setPayingId(rent.id)
    try {
      const res = await fetch('/api/bonds', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          bondNumber: `RENT-${Date.now()}`,
          bondType: 'payment',
          amount: rent.amount,
          partyName: rent.propertyOwner,
          description: `${t('type_rent')} ${rent.propertyDesc || ''} - ${new Date().toLocaleDateString(locale)}`,
          accountId: rent.accountId,
          issuedDate: new Date().toISOString(),
        }),
      })
      if (res.ok) {
        toast.success(t('rents_bond_created'))
      } else {
        toast.error(t('rents_bond_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setPayingId(null)
    }
  }

  const confirmDelete = (id: number) => {
    setDeletingId(id)
    setDeleteDialogOpen(true)
  }

  const handleDelete = async () => {
    if (!deletingId) return
    try {
      const res = await fetch(`/api/rents/${deletingId}`, { method: 'DELETE' })
      if (res.ok) {
        toast.success(t('rents_delete_success'))
        fetchRents()
      } else {
        toast.error(t('rents_delete_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setDeleteDialogOpen(false)
      setDeletingId(null)
    }
  }

  const totalRent = rents.filter((r) => r.isActive).reduce((s, r) => s + r.amount, 0)

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('rents_title')}</h2>
          <p className="text-muted-foreground">{t('rents_subtitle')}</p>
        </div>
        <Button onClick={openCreate} className="gap-2 bg-emerald-600 hover:bg-emerald-700">
          <Plus className="h-4 w-4" />
          {t('rents_add_contract')}
        </Button>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-violet-100">
              <Building className="h-6 w-6 text-violet-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('rents_active_contracts')}</p>
              <p className="text-2xl font-bold">{rents.filter((r) => r.isActive).length}</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-red-100">
              <DollarSign className="h-6 w-6 text-red-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('rents_total_monthly')}</p>
              <p className="text-2xl font-bold text-red-700">{formatCurrency(totalRent)} <span className="text-sm font-normal">{t('currency')}</span></p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Rents Table */}
      <Card>
        <CardContent className="p-0">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            </div>
          ) : rents.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <Home className="h-12 w-12 mb-3 opacity-30" />
              <p>{t('rents_no_contracts')}</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-right">{t('rents_owner')}</TableHead>
                    <TableHead className="text-right">{t('description')}</TableHead>
                    <TableHead className="text-right">{t('rents_amount')}</TableHead>
                    <TableHead className="text-right">{t('rents_due_day')}</TableHead>
                    <TableHead className="text-right">{t('rents_account')}</TableHead>
                    <TableHead className="text-right">{t('rents_period')}</TableHead>
                    <TableHead className="text-right">{t('actions')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rents.map((rent) => (
                    <TableRow key={rent.id}>
                      <TableCell className="font-medium">
                        <div className="flex items-center gap-1">
                          <User className="h-3.5 w-3.5 text-muted-foreground" />
                          {rent.propertyOwner || '—'}
                        </div>
                      </TableCell>
                      <TableCell className="text-sm">{rent.propertyDesc || '—'}</TableCell>
                      <TableCell className="font-medium">{formatCurrency(rent.amount)} {t('currency')}</TableCell>
                      <TableCell>
                        <Badge variant="outline">{t('day')} {rent.dueDay}</Badge>
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {rent.account ? `${rent.account.code} - ${rent.account.name}` : '—'}
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {formatDate(rent.startDate)} - {formatDate(rent.endDate)}
                      </TableCell>
                      <TableCell>
                        <div className="flex gap-1">
                          {rent.isActive && (
                            <Button
                              variant="outline" size="sm" className="h-7 text-xs gap-1 border-emerald-300 text-emerald-700 hover:bg-emerald-50"
                              onClick={() => handlePayRent(rent)}
                              disabled={payingId === rent.id}
                            >
                              {payingId === rent.id ? <Loader2 className="h-3 w-3 animate-spin" /> : <DollarSign className="h-3 w-3" />}
                              {t('rents_pay')}
                            </Button>
                          )}
                          <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={() => openEdit(rent)}>
                            <Pencil className="h-3.5 w-3.5" />
                          </Button>
                          <Button variant="ghost" size="sm" className="h-7 w-7 p-0 text-red-600 hover:text-red-700 hover:bg-red-50" onClick={() => confirmDelete(rent.id)}>
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

      {/* Create/Edit Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-md" dir={dir}>
          <DialogHeader>
            <DialogTitle>{editingRent ? t('rents_edit') : t('rents_add_new')}</DialogTitle>
            <DialogDescription>{t('rents_enter_data')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('rents_owner')} *</Label>
                <Input value={form.propertyOwner} onChange={(e) => setForm({ ...form, propertyOwner: e.target.value })} placeholder={t('rents_owner_placeholder')} />
              </div>
              <div className="space-y-2">
                <Label>{t('rents_amount')} *</Label>
                <Input type="number" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} placeholder="0" />
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('rents_property_desc')}</Label>
              <Input value={form.propertyDesc} onChange={(e) => setForm({ ...form, propertyDesc: e.target.value })} placeholder={t('rents_property_desc')} />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('rents_due_day')}</Label>
                <Select value={form.dueDay} onValueChange={(val) => setForm({ ...form, dueDay: val })}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {Array.from({ length: 28 }, (_, i) => i + 1).map((d) => (
                      <SelectItem key={d} value={String(d)}>{t('day')} {d}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>{t('rents_pay_account')}</Label>
                <Select value={form.accountId} onValueChange={(val) => setForm({ ...form, accountId: val })}>
                  <SelectTrigger>
                    <SelectValue placeholder={t('select_account')} />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none">{t('no_account')}</SelectItem>
                    {accounts.map((a) => (
                      <SelectItem key={a.id} value={String(a.id)}>{a.code} - {a.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('rents_start_date')}</Label>
                <Input type="date" value={form.startDate} onChange={(e) => setForm({ ...form, startDate: e.target.value })} />
              </div>
              <div className="space-y-2">
                <Label>{t('rents_end_date')}</Label>
                <Input type="date" value={form.endDate} onChange={(e) => setForm({ ...form, endDate: e.target.value })} />
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('notes')}</Label>
              <Input value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} placeholder={t('notes')} />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setDialogOpen(false)}>{t('cancel')}</Button>
            <Button onClick={handleSubmit} className="bg-emerald-600 hover:bg-emerald-700" disabled={saving || !form.propertyOwner || !form.amount}>
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {editingRent ? t('save_changes') : t('rents_add_contract_btn')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent dir={dir}>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('rents_delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>{t('rents_delete_confirm')}</AlertDialogDescription>
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
