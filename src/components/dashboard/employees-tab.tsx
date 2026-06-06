'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  Plus,
  Users,
  Pencil,
  Trash2,
  Search,
  Loader2,
  Phone,
  Mail,
  Briefcase,
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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Switch } from '@/components/ui/switch'
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'

interface Employee {
  id: number
  name: string
  nameEn: string | null
  phone: string | null
  email: string | null
  nationalId: string | null
  position: string | null
  department: string | null
  salary: number
  joinDate: string | null
  leaveDate: string | null
  bankName: string | null
  bankIban: string | null
  address: string | null
  notes: string | null
  isActive: boolean
}

const defaultForm = {
  name: '',
  nameEn: '',
  phone: '',
  email: '',
  nationalId: '',
  position: '',
  department: '',
  salary: '',
  joinDate: '',
  bankName: '',
  bankIban: '',
  address: '',
  notes: '',
}

export function EmployeesTab() {
  const { t, lang, dir } = useLanguage()
  const [employees, setEmployees] = useState<Employee[]>([])
  const [search, setSearch] = useState('')
  const [dialogOpen, setDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [editingEmployee, setEditingEmployee] = useState<Employee | null>(null)
  const [form, setForm] = useState(defaultForm)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)

  const businessId = getBusinessId()
  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'
  const formatCurrency = (amount: number) => amount.toLocaleString(locale, { minimumFractionDigits: 3, maximumFractionDigits: 3 })
  const formatDate = (dateStr?: string | null) => { if (!dateStr) return '—'; return new Date(dateStr).toLocaleDateString(locale) }

  const fetchEmployees = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`/api/employees?businessId=${businessId}`)
      if (res.ok) {
        const data = await res.json()
        setEmployees(data)
      }
    } catch {
      // Keep empty
    } finally {
      setLoading(false)
    }
  }, [businessId])

  useEffect(() => {
    fetchEmployees()
  }, [fetchEmployees])

  const filteredEmployees = employees.filter(
    (e) =>
      e.name.includes(search) ||
      (e.position && e.position.includes(search)) ||
      (e.department && e.department.includes(search))
  )

  const openCreate = () => {
    setEditingEmployee(null)
    setForm(defaultForm)
    setDialogOpen(true)
  }

  const openEdit = (employee: Employee) => {
    setEditingEmployee(employee)
    setForm({
      name: employee.name,
      nameEn: employee.nameEn || '',
      phone: employee.phone || '',
      email: employee.email || '',
      nationalId: employee.nationalId || '',
      position: employee.position || '',
      department: employee.department || '',
      salary: String(employee.salary),
      joinDate: employee.joinDate ? new Date(employee.joinDate).toISOString().split('T')[0] : '',
      bankName: employee.bankName || '',
      bankIban: employee.bankIban || '',
      address: employee.address || '',
      notes: employee.notes || '',
    })
    setDialogOpen(true)
  }

  const handleSubmit = async () => {
    if (!form.name) {
      toast.error(t('employees_name_required_msg'))
      return
    }
    setSaving(true)
    try {
      const url = editingEmployee
        ? `/api/employees/${editingEmployee.id}`
        : '/api/employees'
      const method = editingEmployee ? 'PUT' : 'POST'

      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          name: form.name,
          nameEn: form.nameEn || null,
          phone: form.phone || null,
          email: form.email || null,
          nationalId: form.nationalId || null,
          position: form.position || null,
          department: form.department || null,
          salary: parseFloat(form.salary) || 0,
          joinDate: form.joinDate || null,
          bankName: form.bankName || null,
          bankIban: form.bankIban || null,
          address: form.address || null,
          notes: form.notes || null,
        }),
      })

      if (res.ok) {
        toast.success(editingEmployee ? t('employees_update_success') : t('employees_add_success'))
        setDialogOpen(false)
        fetchEmployees()
      } else {
        const err = await res.json()
        toast.error(err.error || t('employees_save_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  const toggleActive = async (employee: Employee) => {
    try {
      const res = await fetch(`/api/employees/${employee.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isActive: !employee.isActive }),
      })
      if (res.ok) {
        toast.success(employee.isActive ? t('employees_deactivated') : t('employees_activated'))
        fetchEmployees()
      }
    } catch {
      toast.error(t('error'))
    }
  }

  const confirmDelete = (id: number) => {
    setDeletingId(id)
    setDeleteDialogOpen(true)
  }

  const handleDelete = async () => {
    if (!deletingId) return
    try {
      const res = await fetch(`/api/employees/${deletingId}`, { method: 'DELETE' })
      if (res.ok) {
        toast.success(t('employees_delete_success'))
        fetchEmployees()
      } else {
        toast.error(t('employees_delete_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setDeleteDialogOpen(false)
      setDeletingId(null)
    }
  }

  const totalSalary = employees.filter((e) => e.isActive).reduce((s, e) => s + e.salary, 0)

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('employees_title')}</h2>
          <p className="text-muted-foreground">{t('employees_subtitle')}</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="relative">
            <Search className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input placeholder={t('employees_search_placeholder')} value={search} onChange={(e) => setSearch(e.target.value)} className="w-48 pr-9 sm:w-64" />
          </div>
          <Button onClick={openCreate} className="gap-2 bg-emerald-600 hover:bg-emerald-700">
            <Plus className="h-4 w-4" />
            {t('employees_add')}
          </Button>
        </div>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-violet-100">
              <Users className="h-6 w-6 text-violet-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('employees_total')}</p>
              <p className="text-2xl font-bold">{employees.length}</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-100">
              <Users className="h-6 w-6 text-emerald-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('employees_active_count')}</p>
              <p className="text-2xl font-bold">{employees.filter((e) => e.isActive).length}</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-amber-100">
              <span className="text-lg font-bold text-amber-600">{t('currency')}</span>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('employees_total_salaries')}</p>
              <p className="text-2xl font-bold">{formatCurrency(totalSalary)}</p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Employees Table */}
      <Card>
        <CardContent className="p-0">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            </div>
          ) : filteredEmployees.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <Users className="h-12 w-12 mb-3 opacity-30" />
              <p>{t('employees_no_employees')}</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-right">{t('employees_name')}</TableHead>
                    <TableHead className="text-right">{t('employees_position')}</TableHead>
                    <TableHead className="text-right">{t('employees_department')}</TableHead>
                    <TableHead className="text-right">{t('employees_phone')}</TableHead>
                    <TableHead className="text-right">{t('employees_salary')}</TableHead>
                    <TableHead className="text-right">{t('employees_hire_date')}</TableHead>
                    <TableHead className="text-right">{t('status')}</TableHead>
                    <TableHead className="text-right">{t('actions')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredEmployees.map((emp) => (
                    <TableRow key={emp.id}>
                      <TableCell className="font-medium">{emp.name}</TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1 text-sm">
                          <Briefcase className="h-3.5 w-3.5 text-muted-foreground" />
                          {emp.position || '—'}
                        </div>
                      </TableCell>
                      <TableCell className="text-sm">{emp.department || '—'}</TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1 text-sm">
                          <Phone className="h-3.5 w-3.5 text-muted-foreground" />
                          {emp.phone || '—'}
                        </div>
                      </TableCell>
                      <TableCell className="font-medium">{formatCurrency(emp.salary)} {t('currency')}</TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {formatDate(emp.joinDate)}
                      </TableCell>
                      <TableCell>
                        <Switch checked={emp.isActive} onCheckedChange={() => toggleActive(emp)} />
                      </TableCell>
                      <TableCell>
                        <div className="flex gap-1">
                          <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={() => openEdit(emp)}>
                            <Pencil className="h-3.5 w-3.5" />
                          </Button>
                          <Button variant="ghost" size="sm" className="h-7 w-7 p-0 text-red-600 hover:text-red-700 hover:bg-red-50" onClick={() => confirmDelete(emp.id)}>
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
        <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto" dir={dir}>
          <DialogHeader>
            <DialogTitle>{editingEmployee ? t('employees_edit') : t('employees_add_new')}</DialogTitle>
            <DialogDescription>{t('employees_enter_data')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('employees_name')} *</Label>
                <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder={t('employees_name_placeholder')} />
              </div>
              <div className="space-y-2">
                <Label>{t('employees_position')}</Label>
                <Input value={form.position} onChange={(e) => setForm({ ...form, position: e.target.value })} placeholder={t('employees_position_placeholder')} />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('employees_department')}</Label>
                <Input value={form.department} onChange={(e) => setForm({ ...form, department: e.target.value })} placeholder={t('employees_department_placeholder')} />
              </div>
              <div className="space-y-2">
                <Label>{t('employees_salary')} *</Label>
                <Input type="number" value={form.salary} onChange={(e) => setForm({ ...form, salary: e.target.value })} placeholder="0" />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('employees_phone')}</Label>
                <Input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder={t('employees_phone_placeholder')} />
              </div>
              <div className="space-y-2">
                <Label>{t('email')}</Label>
                <Input value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="email@example.com" />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('employees_hire_date')}</Label>
                <Input type="date" value={form.joinDate} onChange={(e) => setForm({ ...form, joinDate: e.target.value })} />
              </div>
              <div className="space-y-2">
                <Label>{t('employees_national_id')}</Label>
                <Input value={form.nationalId} onChange={(e) => setForm({ ...form, nationalId: e.target.value })} placeholder={t('employees_national_id')} />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('employees_bank_name')}</Label>
                <Input value={form.bankName} onChange={(e) => setForm({ ...form, bankName: e.target.value })} placeholder={t('employees_bank_name')} />
              </div>
              <div className="space-y-2">
                <Label>IBAN</Label>
                <Input value={form.bankIban} onChange={(e) => setForm({ ...form, bankIban: e.target.value })} placeholder="IBAN" />
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('address')}</Label>
              <Input value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} placeholder={t('address')} />
            </div>
            <div className="space-y-2">
              <Label>{t('notes')}</Label>
              <Input value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} placeholder={t('notes')} />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setDialogOpen(false)}>{t('cancel')}</Button>
            <Button onClick={handleSubmit} className="bg-emerald-600 hover:bg-emerald-700" disabled={saving || !form.name}>
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {editingEmployee ? t('save_changes') : t('employees_add_btn')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent dir={dir}>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('employees_delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>{t('employees_delete_confirm')}</AlertDialogDescription>
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
