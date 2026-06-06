'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  Plus,
  Warehouse,
  Pencil,
  Trash2,
  Search,
  Loader2,
  MapPin,
  User,
  Package,
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
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'

interface WarehouseItem {
  id: number
  name: string
  nameEn: string | null
  code: string | null
  address: string | null
  managerName: string | null
  managerPhone: string | null
  isActive: boolean
  productCount: number
  totalStockValue: number
}

const defaultForm = {
  name: '',
  nameEn: '',
  code: '',
  address: '',
  managerName: '',
  managerPhone: '',
}

export function WarehousesTab() {
  const { t, lang, dir } = useLanguage()
  const [warehouses, setWarehouses] = useState<WarehouseItem[]>([])
  const [search, setSearch] = useState('')
  const [dialogOpen, setDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [editingWarehouse, setEditingWarehouse] = useState<WarehouseItem | null>(null)
  const [form, setForm] = useState(defaultForm)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)

  const businessId = getBusinessId()
  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'
  const formatCurrency = (amount: number) => amount.toLocaleString(locale, { minimumFractionDigits: 3, maximumFractionDigits: 3 })

  const fetchWarehouses = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`/api/warehouses?businessId=${businessId}`)
      if (res.ok) {
        const data = await res.json()
        setWarehouses(data)
      }
    } catch {
      // Keep empty
    } finally {
      setLoading(false)
    }
  }, [businessId])

  useEffect(() => {
    fetchWarehouses()
  }, [fetchWarehouses])

  const filteredWarehouses = warehouses.filter(
    (w) =>
      w.name.includes(search) ||
      (w.code && w.code.includes(search)) ||
      (w.address && w.address.includes(search))
  )

  const openCreate = () => {
    setEditingWarehouse(null)
    setForm(defaultForm)
    setDialogOpen(true)
  }

  const openEdit = (warehouse: WarehouseItem) => {
    setEditingWarehouse(warehouse)
    setForm({
      name: warehouse.name,
      nameEn: warehouse.nameEn || '',
      code: warehouse.code || '',
      address: warehouse.address || '',
      managerName: warehouse.managerName || '',
      managerPhone: warehouse.managerPhone || '',
    })
    setDialogOpen(true)
  }

  const handleSubmit = async () => {
    if (!form.name) {
      toast.error(t('warehouses_name_required_msg'))
      return
    }
    setSaving(true)
    try {
      const url = editingWarehouse
        ? `/api/warehouses/${editingWarehouse.id}`
        : '/api/warehouses'
      const method = editingWarehouse ? 'PUT' : 'POST'

      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          name: form.name,
          nameEn: form.nameEn || null,
          code: form.code || null,
          address: form.address || null,
          managerName: form.managerName || null,
          managerPhone: form.managerPhone || null,
        }),
      })

      if (res.ok) {
        toast.success(editingWarehouse ? t('warehouses_update_success') : t('warehouses_add_success'))
        setDialogOpen(false)
        fetchWarehouses()
      } else {
        const err = await res.json()
        toast.error(err.error || t('warehouses_save_failed'))
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
      const res = await fetch(`/api/warehouses/${deletingId}`, { method: 'DELETE' })
      if (res.ok) {
        toast.success(t('warehouses_delete_success'))
        fetchWarehouses()
      } else {
        toast.error(t('warehouses_delete_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setDeleteDialogOpen(false)
      setDeletingId(null)
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('warehouses_title')}</h2>
          <p className="text-muted-foreground">{t('warehouses_subtitle')}</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="relative">
            <Search className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder={t('warehouses_search_placeholder')}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-48 pr-9 sm:w-64"
            />
          </div>
          <Button
            onClick={openCreate}
            className="gap-2 bg-emerald-600 hover:bg-emerald-700"
          >
            <Plus className="h-4 w-4" />{t('warehouses_add')}</Button>
        </div>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-100">
              <Warehouse className="h-6 w-6 text-emerald-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('warehouses_count')}</p>
              <p className="text-2xl font-bold">{warehouses.length}</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-violet-100">
              <Package className="h-6 w-6 text-violet-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('warehouses_total_products')}</p>
              <p className="text-2xl font-bold">
                {warehouses.reduce((s, w) => s + w.productCount, 0)}
              </p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-amber-100">
              <span className="text-lg font-bold text-amber-600">{t('currency')}</span>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('warehouses_total_stock_value')}</p>
              <p className="text-2xl font-bold">
                {warehouses.reduce((s, w) => s + w.totalStockValue, 0).toLocaleString('ar-KW')}
              </p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Warehouses Table */}
      <Card>
        <CardContent className="p-0">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            </div>
          ) : filteredWarehouses.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <Warehouse className="h-12 w-12 mb-3 opacity-30" />
              <p>{t('warehouses_no_warehouses_msg')}</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-right">{t('warehouses_name')}</TableHead>
                    <TableHead className="text-right">{t('warehouses_code')}</TableHead>
                    <TableHead className="text-right">{t('warehouses_location')}</TableHead>
                    <TableHead className="text-right">{t('warehouses_manager')}</TableHead>
                    <TableHead className="text-right">{t('warehouses_product_count')}</TableHead>
                    <TableHead className="text-right">{t('warehouses_stock_value')}</TableHead>
                    <TableHead className="text-right">{t('status')}</TableHead>
                    <TableHead className="text-right">{t('actions')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredWarehouses.map((wh) => (
                    <TableRow key={wh.id}>
                      <TableCell className="font-medium">{wh.name}</TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {wh.code || '—'}
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1 text-sm">
                          <MapPin className="h-3.5 w-3.5 text-muted-foreground" />
                          {wh.address || '—'}
                        </div>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1 text-sm">
                          <User className="h-3.5 w-3.5 text-muted-foreground" />
                          {wh.managerName || '—'}
                        </div>
                      </TableCell>
                      <TableCell>
                        <Badge variant="secondary">{wh.productCount}</Badge>
                      </TableCell>
                      <TableCell className="font-medium">
                        {formatCurrency(wh.totalStockValue)} {t('currency')}
                      </TableCell>
                      <TableCell>
                        <Badge
                          variant={wh.isActive ? 'default' : 'secondary'}
                          className={wh.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-600'}
                        >
                          {wh.isActive ? t('employees_active_yes') : t('employees_active_no')}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <div className="flex gap-1">
                          <Button
                            variant="ghost"
                            size="sm"
                            className="h-7 w-7 p-0"
                            onClick={() => openEdit(wh)}
                          >
                            <Pencil className="h-3.5 w-3.5" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="sm"
                            className="h-7 w-7 p-0 text-red-600 hover:text-red-700 hover:bg-red-50"
                            onClick={() => confirmDelete(wh.id)}
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

      {/* Create/Edit Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-md" dir={dir}>
          <DialogHeader>
            <DialogTitle>
              {editingWarehouse ? t('warehouses_edit') : t('warehouses_add_new')}
            </DialogTitle>
            <DialogDescription>
              {editingWarehouse
                ? t('warehouses_edit_data')
                : t('warehouses_enter_data')}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('warehouses_name')} *</Label>
                <Input
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  placeholder={t('warehouses_name_placeholder')}
                />
              </div>
              <div className="space-y-2">
                <Label>{t('warehouses_code')}</Label>
                <Input
                  value={form.code}
                  onChange={(e) => setForm({ ...form, code: e.target.value })}
                  placeholder="WH-001"
                />
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('warehouses_location')}</Label>
              <Input
                value={form.address}
                onChange={(e) => setForm({ ...form, address: e.target.value })}
                placeholder={t('warehouses_address_placeholder')}
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('warehouses_manager_name')}</Label>
                <Input
                  value={form.managerName}
                  onChange={(e) => setForm({ ...form, managerName: e.target.value })}
                  placeholder={t('warehouses_manager_name')}
                />
              </div>
              <div className="space-y-2">
                <Label>{t('warehouses_manager_phone')}</Label>
                <Input
                  value={form.managerPhone}
                  onChange={(e) => setForm({ ...form, managerPhone: e.target.value })}
                  placeholder={t('warehouses_manager_phone')}
                />
              </div>
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
              {editingWarehouse ? t('save_changes') : t('warehouses_add')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent dir="rtl">
          <AlertDialogHeader>
            <AlertDialogTitle>{t('warehouses_delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('warehouses_delete_irreversible')}
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
