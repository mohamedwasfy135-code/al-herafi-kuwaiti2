'use client'

import { useState, useEffect, useCallback, useMemo } from 'react'
import {
  Plus,
  Banknote,
  Loader2,
  CheckCircle2,
  Clock,
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

interface SalaryRecord {
  id: number
  employeeId: number
  month: number
  year: number
  basicSalary: number
  allowances: number
  deductions: number
  netSalary: number
  status: string
  paidDate: string | null
  notes: string | null
  accountId: number | null
  employee: { id: number; name: string; position: string | null; department: string | null }
  account: { id: number; name: string; code: string } | null
}

interface Account {
  id: number
  code: string
  name: string
}

export function SalariesTab() {
  const { t, lang, dir } = useLanguage()
  const [salaries, setSalaries] = useState<SalaryRecord[]>([])
  const [accounts, setAccounts] = useState<Account[]>([])
  const [selectedMonth, setSelectedMonth] = useState(String(new Date().getMonth() + 1))
  const [selectedYear, setSelectedYear] = useState(String(new Date().getFullYear()))
  const [editDialogOpen, setEditDialogOpen] = useState(false)
  const [payDialogOpen, setPayDialogOpen] = useState(false)
  const [editingSalary, setEditingSalary] = useState<SalaryRecord | null>(null)
  const [payingSalary, setPayingSalary] = useState<SalaryRecord | null>(null)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [generating, setGenerating] = useState(false)
  const [editForm, setEditForm] = useState({ allowances: '', deductions: '', notes: '' })
  const [payForm, setPayForm] = useState({ accountId: '' })

  const businessId = getBusinessId()

  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'

  const formatCurrency = (amount: number) => amount.toLocaleString(locale, { minimumFractionDigits: 3, maximumFractionDigits: 3 })

  const monthNames = useMemo(() => [
    t('salaries_month_jan'), t('salaries_month_feb'), t('salaries_month_mar'),
    t('salaries_month_apr'), t('salaries_month_may'), t('salaries_month_jun'),
    t('salaries_month_jul'), t('salaries_month_aug'), t('salaries_month_sep'),
    t('salaries_month_oct'), t('salaries_month_nov'), t('salaries_month_dec'),
  ], [t])

  const fetchSalaries = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`/api/salaries?businessId=${businessId}&month=${selectedMonth}&year=${selectedYear}`)
      if (res.ok) {
        const data = await res.json()
        setSalaries(data)
      }
    } catch {
      // Keep empty
    } finally {
      setLoading(false)
    }
  }, [businessId, selectedMonth, selectedYear])

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
    fetchSalaries()
  }, [fetchSalaries])

  useEffect(() => {
    fetchAccounts()
  }, [fetchAccounts])

  const handleGenerate = async () => {
    setGenerating(true)
    try {
      const res = await fetch('/api/salaries', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          action: 'generate',
          month: parseInt(selectedMonth),
          year: parseInt(selectedYear),
        }),
      })
      if (res.ok) {
        toast.success(t('salaries_generate_success'))
        fetchSalaries()
      } else {
        const err = await res.json()
        toast.error(err.error || t('salaries_generate_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setGenerating(false)
    }
  }

  const openEdit = (salary: SalaryRecord) => {
    setEditingSalary(salary)
    setEditForm({
      allowances: String(salary.allowances),
      deductions: String(salary.deductions),
      notes: salary.notes || '',
    })
    setEditDialogOpen(true)
  }

  const handleEdit = async () => {
    if (!editingSalary) return
    setSaving(true)
    try {
      const allowances = parseFloat(editForm.allowances) || 0
      const deductions = parseFloat(editForm.deductions) || 0
      const netSalary = editingSalary.basicSalary + allowances - deductions

      const res = await fetch(`/api/salaries/${editingSalary.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          allowances,
          deductions,
          netSalary,
          notes: editForm.notes || null,
        }),
      })
      if (res.ok) {
        toast.success(t('salaries_update_success'))
        setEditDialogOpen(false)
        fetchSalaries()
      } else {
        toast.error(t('salaries_update_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  const openPay = (salary: SalaryRecord) => {
    setPayingSalary(salary)
    setPayForm({ accountId: salary.accountId ? String(salary.accountId) : '' })
    setPayDialogOpen(true)
  }

  const handlePay = async () => {
    if (!payingSalary || !payForm.accountId) {
      toast.error(t('salaries_select_account_required'))
      return
    }
    setSaving(true)
    try {
      const res = await fetch(`/api/salaries/${payingSalary.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          status: 'paid',
          accountId: parseInt(payForm.accountId),
          paidDate: new Date().toISOString(),
        }),
      })
      if (res.ok) {
        toast.success(t('salaries_pay_success'))
        setPayDialogOpen(false)
        fetchSalaries()
      } else {
        toast.error(t('salaries_pay_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  const totalNet = salaries.reduce((s, sal) => s + sal.netSalary, 0)
  const totalPaid = salaries.filter((s) => s.status === 'paid').reduce((sum, s) => sum + s.netSalary, 0)
  const totalPending = salaries.filter((s) => s.status === 'pending').reduce((sum, s) => sum + s.netSalary, 0)

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('salaries_title')}</h2>
          <p className="text-muted-foreground">{t('salaries_subtitle')}</p>
        </div>
        <div className="flex items-center gap-3">
          <Select value={selectedMonth} onValueChange={setSelectedMonth}>
            <SelectTrigger className="w-32">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {monthNames.map((m, i) => (
                <SelectItem key={i} value={String(i + 1)}>{m}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Select value={selectedYear} onValueChange={setSelectedYear}>
            <SelectTrigger className="w-24">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {[2024, 2025, 2026].map((y) => (
                <SelectItem key={y} value={String(y)}>{y}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button onClick={handleGenerate} disabled={generating} className="gap-2 bg-emerald-600 hover:bg-emerald-700">
            {generating ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
            {t('salaries_generate')}
          </Button>
        </div>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-violet-100">
              <Banknote className="h-6 w-6 text-violet-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('salaries_total')}</p>
              <p className="text-2xl font-bold">{formatCurrency(totalNet)} <span className="text-sm font-normal">{t('currency')}</span></p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-100">
              <CheckCircle2 className="h-6 w-6 text-emerald-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('salaries_paid')}</p>
              <p className="text-2xl font-bold text-emerald-700">{formatCurrency(totalPaid)} <span className="text-sm font-normal">{t('currency')}</span></p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-amber-100">
              <Clock className="h-6 w-6 text-amber-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('salaries_pending')}</p>
              <p className="text-2xl font-bold text-amber-700">{formatCurrency(totalPending)} <span className="text-sm font-normal">{t('currency')}</span></p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Salaries Table */}
      <Card>
        <CardContent className="p-0">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            </div>
          ) : salaries.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <Banknote className="h-12 w-12 mb-3 opacity-30" />
              <p>{t('salaries_no_salaries')}</p>
              <Button variant="outline" size="sm" className="mt-3 gap-2" onClick={handleGenerate}>
                <Plus className="h-4 w-4" />
                {t('salaries_generate')}
              </Button>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-right">{t('salaries_employee')}</TableHead>
                    <TableHead className="text-right">{t('employees_position')}</TableHead>
                    <TableHead className="text-right">{t('salaries_basic')}</TableHead>
                    <TableHead className="text-right">{t('salaries_allowances')}</TableHead>
                    <TableHead className="text-right">{t('salaries_deductions')}</TableHead>
                    <TableHead className="text-right">{t('salaries_net')}</TableHead>
                    <TableHead className="text-right">{t('status')}</TableHead>
                    <TableHead className="text-right">{t('actions')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {salaries.map((sal) => (
                    <TableRow key={sal.id}>
                      <TableCell className="font-medium">{sal.employee.name}</TableCell>
                      <TableCell className="text-sm text-muted-foreground">{sal.employee.position || '—'}</TableCell>
                      <TableCell>{formatCurrency(sal.basicSalary)} {t('currency')}</TableCell>
                      <TableCell className="text-emerald-700">{sal.allowances > 0 ? `+${formatCurrency(sal.allowances)}` : '0'} {t('currency')}</TableCell>
                      <TableCell className="text-red-700">{sal.deductions > 0 ? `-${formatCurrency(sal.deductions)}` : '0'} {t('currency')}</TableCell>
                      <TableCell className="font-bold">{formatCurrency(sal.netSalary)} {t('currency')}</TableCell>
                      <TableCell>
                        <Badge variant={sal.status === 'paid' ? 'default' : 'secondary'} className={sal.status === 'paid' ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700'}>
                          {sal.status === 'paid' ? t('salaries_paid') : t('salaries_pending')}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <div className="flex gap-1">
                          {sal.status === 'pending' && (
                            <>
                              <Button variant="outline" size="sm" className="h-7 text-xs gap-1" onClick={() => openEdit(sal)}>
                                {t('edit')}
                              </Button>
                              <Button variant="outline" size="sm" className="h-7 text-xs gap-1 border-emerald-300 text-emerald-700 hover:bg-emerald-50" onClick={() => openPay(sal)}>
                                {t('salaries_pay')}
                              </Button>
                            </>
                          )}
                          {sal.status === 'paid' && sal.account && (
                            <span className="text-xs text-muted-foreground">{sal.account.name}</span>
                          )}
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

      {/* Edit Salary Dialog */}
      <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
        <DialogContent className="max-w-md" dir={dir}>
          <DialogHeader>
            <DialogTitle>{t('salaries_edit_title')} - {editingSalary?.employee.name}</DialogTitle>
            <DialogDescription>{t('salaries_edit_desc')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="p-3 bg-gray-50 rounded-lg">
              <p className="text-sm text-muted-foreground">{t('salaries_basic')}</p>
              <p className="text-lg font-bold">{editingSalary ? formatCurrency(editingSalary.basicSalary) : '0'} {t('currency')}</p>
            </div>
            <div className="space-y-2">
              <Label>{t('salaries_allowances')}</Label>
              <Input type="number" value={editForm.allowances} onChange={(e) => setEditForm({ ...editForm, allowances: e.target.value })} placeholder="0" />
            </div>
            <div className="space-y-2">
              <Label>{t('salaries_deductions')}</Label>
              <Input type="number" value={editForm.deductions} onChange={(e) => setEditForm({ ...editForm, deductions: e.target.value })} placeholder="0" />
            </div>
            <div className="p-3 bg-emerald-50 rounded-lg">
              <p className="text-sm text-muted-foreground">{t('salaries_net')}</p>
              <p className="text-lg font-bold text-emerald-700">
                {formatCurrency((editingSalary?.basicSalary || 0) + (parseFloat(editForm.allowances) || 0) - (parseFloat(editForm.deductions) || 0))} {t('currency')}
              </p>
            </div>
            <div className="space-y-2">
              <Label>{t('notes')}</Label>
              <Input value={editForm.notes} onChange={(e) => setEditForm({ ...editForm, notes: e.target.value })} placeholder={t('notes')} />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setEditDialogOpen(false)}>{t('cancel')}</Button>
            <Button onClick={handleEdit} className="bg-emerald-600 hover:bg-emerald-700" disabled={saving}>
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {t('save')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Pay Salary Dialog */}
      <Dialog open={payDialogOpen} onOpenChange={setPayDialogOpen}>
        <DialogContent className="max-w-md" dir={dir}>
          <DialogHeader>
            <DialogTitle>{t('salaries_pay_title')} - {payingSalary?.employee.name}</DialogTitle>
            <DialogDescription>{t('salaries_pay_desc')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="p-3 bg-gray-50 rounded-lg">
              <p className="text-sm text-muted-foreground">{t('salaries_net')}</p>
              <p className="text-lg font-bold">{payingSalary ? formatCurrency(payingSalary.netSalary) : '0'} {t('currency')}</p>
            </div>
            <div className="space-y-2">
              <Label>{t('salaries_pay_account')} *</Label>
              <Select value={payForm.accountId} onValueChange={(val) => setPayForm({ ...payForm, accountId: val })}>
                <SelectTrigger>
                  <SelectValue placeholder={t('salaries_select_account_placeholder')} />
                </SelectTrigger>
                <SelectContent>
                  {accounts.map((a) => (
                    <SelectItem key={a.id} value={String(a.id)}>{a.code} - {a.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setPayDialogOpen(false)}>{t('cancel')}</Button>
            <Button onClick={handlePay} className="bg-emerald-600 hover:bg-emerald-700" disabled={saving || !payForm.accountId}>
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {t('salaries_pay_btn')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
