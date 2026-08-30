'use client'

import { useState, useEffect, useMemo } from 'react'
import {
  FileText,
  Plus,
  Filter,
  Loader2,
  Receipt,
  ShoppingCart,
  Eye,
  Trash2,
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
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'

interface InvoiceItem {
  id: number
  description: string | null
  quantity: number
  unitPrice: number
  total: number
  product?: { id: number; name: string } | null
}

interface SalesInvoice {
  id: number
  invoiceNumber: string
  clientName: string | null
  total: number
  status: string
  paidAmount: number
  createdAt: string
  items?: InvoiceItem[]
  notes?: string | null
}

interface PurchaseInvoice {
  id: number
  invoiceNumber: string
  supplierName: string | null
  total: number
  status: string
  paidAmount: number
  createdAt: string
  items?: InvoiceItem[]
  notes?: string | null
}

export function InvoicesTab() {
  const { t, lang, dir } = useLanguage()
  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'

  const [salesInvoices, setSalesInvoices] = useState<SalesInvoice[]>([])
  const [purchaseInvoices, setPurchaseInvoices] = useState<PurchaseInvoice[]>([])
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [dialogOpen, setDialogOpen] = useState(false)
  const [viewDialogOpen, setViewDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [invoiceType, setInvoiceType] = useState<'sales' | 'purchase'>('sales')
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [viewingInvoice, setViewingInvoice] = useState<SalesInvoice | PurchaseInvoice | null>(null)
  const [deletingInvoice, setDeletingInvoice] = useState<{ id: number; type: 'sales' | 'purchase' } | null>(null)
  const [form, setForm] = useState({
    clientName: '',
    supplierName: '',
    itemDescription: '',
    itemQuantity: '1',
    itemPrice: '',
    notes: '',
  })

  const businessId = getBusinessId()

  const invoiceStatusMap = useMemo(() => ({
    draft: { label: t('sales_status_draft'), color: 'bg-gray-100 text-gray-700' },
    unpaid: { label: t('sales_status_unpaid'), color: 'bg-red-100 text-red-700' },
    partial: { label: t('sales_status_partial'), color: 'bg-yellow-100 text-yellow-700' },
    paid: { label: t('sales_status_paid'), color: 'bg-green-100 text-green-700' },
    cancelled: { label: t('sales_status_cancelled'), color: 'bg-gray-100 text-gray-700' },
  }), [t])

  useEffect(() => {
    async function fetchInvoices() {
      setLoading(true)
      try {
        const [salesRes, purchaseRes] = await Promise.all([
          fetch(`/api/invoices/sales?businessId=${businessId}`),
          fetch(`/api/invoices/purchase?businessId=${businessId}`),
        ])
        if (salesRes.ok) {
          const data = await salesRes.json()
          if (Array.isArray(data) && data.length > 0) setSalesInvoices(data)
        }
        if (purchaseRes.ok) {
          const data = await purchaseRes.json()
          if (Array.isArray(data) && data.length > 0) setPurchaseInvoices(data)
        }
      } catch {
        // Keep sample data
      } finally {
        setLoading(false)
      }
    }
    fetchInvoices()
  }, [businessId])

  const getStatusBadge = (status: string) => {
    const s = invoiceStatusMap[status] || { label: status, color: 'bg-gray-100 text-gray-700' }
    return (
      <Badge variant="secondary" className={`text-xs ${s.color}`}>
        {s.label}
      </Badge>
    )
  }

  const openCreateDialog = (type: 'sales' | 'purchase') => {
    setInvoiceType(type)
    setForm({ clientName: '', supplierName: '', itemDescription: '', itemQuantity: '1', itemPrice: '', notes: '' })
    setDialogOpen(true)
  }

  const handleCreateInvoice = async () => {
    setSaving(true)
    try {
      const url = invoiceType === 'sales' ? '/api/invoices/sales' : '/api/invoices/purchase'
      const payload = invoiceType === 'sales'
        ? {
            businessId,
            clientName: form.clientName,
            items: [{ description: form.itemDescription, quantity: parseInt(form.itemQuantity) || 1, unitPrice: parseFloat(form.itemPrice) || 0 }],
            notes: form.notes,
          }
        : {
            businessId,
            supplierName: form.supplierName,
            items: [{ description: form.itemDescription, quantity: parseInt(form.itemQuantity) || 1, unitPrice: parseFloat(form.itemPrice) || 0 }],
            notes: form.notes,
          }

      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      if (res.ok) {
        const saved = await res.json()
        if (invoiceType === 'sales') {
          setSalesInvoices((prev) => [saved, ...prev])
        } else {
          setPurchaseInvoices((prev) => [saved, ...prev])
        }
        setDialogOpen(false)
        toast.success(invoiceType === 'sales' ? t('invoices_created_sales') : t('invoices_created_purchase'))
      } else {
        const err = await res.json()
        toast.error(err.error || t('invoices_create_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  const handleViewInvoice = (invoice: SalesInvoice | PurchaseInvoice, type: 'sales' | 'purchase') => {
    setInvoiceType(type)
    setViewingInvoice(invoice)
    setViewDialogOpen(true)
  }

  const confirmDelete = (id: number, type: 'sales' | 'purchase') => {
    setDeletingInvoice({ id, type })
    setDeleteDialogOpen(true)
  }

  const handleDelete = async () => {
    if (!deletingInvoice) return
    try {
      if (deletingInvoice.type === 'sales') {
        setSalesInvoices((prev) => prev.filter((i) => i.id !== deletingInvoice.id))
      } else {
        setPurchaseInvoices((prev) => prev.filter((i) => i.id !== deletingInvoice.id))
      }
      toast.success(t('invoices_deleted'))
    } catch {
      toast.error(t('invoices_delete_failed'))
    } finally {
      setDeleteDialogOpen(false)
      setDeletingInvoice(null)
    }
  }

  const filteredSales = statusFilter === 'all' ? (salesInvoices || []) : (salesInvoices || []).filter((i) => i.status === statusFilter)
  const filteredPurchase = statusFilter === 'all' ? (purchaseInvoices || []) : (purchaseInvoices || []).filter((i) => i.status === statusFilter)

  const totalSales = salesInvoices.reduce((sum, i) => sum + i.total, 0)
  const totalPurchases = purchaseInvoices.reduce((sum, i) => sum + i.total, 0)

  return (
    <div className="space-y-6" dir={dir}>
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('invoices_title')}</h2>
          <p className="text-muted-foreground">{t('invoices_manage_desc')}</p>
        </div>
        <div className="flex items-center gap-3">
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-40">
              <Filter className="ml-2 h-4 w-4" />
              <SelectValue placeholder={t('invoices_filter_status')} />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t('all')}</SelectItem>
              <SelectItem value="draft">{t('sales_status_draft')}</SelectItem>
              <SelectItem value="unpaid">{t('sales_status_unpaid')}</SelectItem>
              <SelectItem value="partial">{t('sales_status_partial')}</SelectItem>
              <SelectItem value="paid">{t('sales_status_paid')}</SelectItem>
              <SelectItem value="cancelled">{t('sales_status_cancelled')}</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-2 gap-4">
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-100">
              <Receipt className="h-6 w-6 text-emerald-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('invoices_total_sales')}</p>
              <p className="text-2xl font-bold text-emerald-700">{totalSales.toLocaleString(locale)} <span className="text-sm font-normal">{t('currency')}</span></p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-orange-100">
              <ShoppingCart className="h-6 w-6 text-orange-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('invoices_total_purchases')}</p>
              <p className="text-2xl font-bold text-orange-700">{totalPurchases.toLocaleString(locale)} <span className="text-sm font-normal">{t('currency')}</span></p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Invoices Tabs */}
      <Tabs defaultValue="sales" dir={dir}>
        <div className="flex items-center justify-between">
          <TabsList>
            <TabsTrigger value="sales" className="gap-2">
              <Receipt className="h-4 w-4" />
              {t('invoices_sales_invoices')} ({salesInvoices.length})
            </TabsTrigger>
            <TabsTrigger value="purchase" className="gap-2">
              <ShoppingCart className="h-4 w-4" />
              {t('invoices_purchase_invoices')} ({purchaseInvoices.length})
            </TabsTrigger>
          </TabsList>
        </div>

        <TabsContent value="sales" className="mt-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle className="text-base">{t('invoices_sales_invoices')}</CardTitle>
              <Button
                onClick={() => openCreateDialog('sales')}
                className="gap-2 bg-emerald-600 hover:bg-emerald-700"
                size="sm"
              >
                <Plus className="h-4 w-4" />
                {t('invoices_new_sales')}
              </Button>
            </CardHeader>
            <CardContent className="p-0">
              {loading ? (
                <div className="flex items-center justify-center py-12">
                  <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
                </div>
              ) : filteredSales.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
                  <Receipt className="h-12 w-12 mb-3 opacity-30" />
                  <p>{t('invoices_no_sales')}</p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead className="text-right">{t('sales_invoice_number')}</TableHead>
                        <TableHead className="text-right">{t('sales_client')}</TableHead>
                        <TableHead className="text-right">{t('sales_total')}</TableHead>
                        <TableHead className="text-right">{t('sales_paid')}</TableHead>
                        <TableHead className="text-right">{t('status')}</TableHead>
                        <TableHead className="text-right">{t('date')}</TableHead>
                        <TableHead className="text-right">{t('actions')}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {filteredSales.map((inv) => (
                        <TableRow key={inv.id} className="cursor-pointer">
                          <TableCell className="font-medium">{inv.invoiceNumber}</TableCell>
                          <TableCell>{inv.clientName || '—'}</TableCell>
                          <TableCell className="font-medium">{inv.total.toLocaleString(locale)} {t('currency')}</TableCell>
                          <TableCell>{inv.paidAmount.toLocaleString(locale)} {t('currency')}</TableCell>
                          <TableCell>{getStatusBadge(inv.status)}</TableCell>
                          <TableCell className="text-xs text-muted-foreground">
                            {new Date(inv.createdAt).toLocaleDateString(locale)}
                          </TableCell>
                          <TableCell>
                            <div className="flex items-center gap-1">
                              <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={() => handleViewInvoice(inv, 'sales')}>
                                <Eye className="h-3.5 w-3.5" />
                              </Button>
                              <Button variant="ghost" size="sm" className="h-7 w-7 p-0 text-red-600 hover:text-red-700 hover:bg-red-50" onClick={() => confirmDelete(inv.id, 'sales')}>
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
        </TabsContent>

        <TabsContent value="purchase" className="mt-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle className="text-base">{t('invoices_purchase_invoices')}</CardTitle>
              <Button
                onClick={() => openCreateDialog('purchase')}
                className="gap-2 bg-orange-600 hover:bg-orange-700"
                size="sm"
              >
                <Plus className="h-4 w-4" />
                {t('invoices_new_purchase')}
              </Button>
            </CardHeader>
            <CardContent className="p-0">
              {filteredPurchase.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
                  <ShoppingCart className="h-12 w-12 mb-3 opacity-30" />
                  <p>{t('invoices_no_purchase')}</p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead className="text-right">{t('sales_invoice_number')}</TableHead>
                        <TableHead className="text-right">{t('purchase_supplier')}</TableHead>
                        <TableHead className="text-right">{t('sales_total')}</TableHead>
                        <TableHead className="text-right">{t('sales_paid')}</TableHead>
                        <TableHead className="text-right">{t('status')}</TableHead>
                        <TableHead className="text-right">{t('date')}</TableHead>
                        <TableHead className="text-right">{t('actions')}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {filteredPurchase.map((inv) => (
                        <TableRow key={inv.id} className="cursor-pointer">
                          <TableCell className="font-medium">{inv.invoiceNumber}</TableCell>
                          <TableCell>{inv.supplierName || '—'}</TableCell>
                          <TableCell className="font-medium">{inv.total.toLocaleString(locale)} {t('currency')}</TableCell>
                          <TableCell>{inv.paidAmount.toLocaleString(locale)} {t('currency')}</TableCell>
                          <TableCell>{getStatusBadge(inv.status)}</TableCell>
                          <TableCell className="text-xs text-muted-foreground">
                            {new Date(inv.createdAt).toLocaleDateString(locale)}
                          </TableCell>
                          <TableCell>
                            <div className="flex items-center gap-1">
                              <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={() => handleViewInvoice(inv, 'purchase')}>
                                <Eye className="h-3.5 w-3.5" />
                              </Button>
                              <Button variant="ghost" size="sm" className="h-7 w-7 p-0 text-red-600 hover:text-red-700 hover:bg-red-50" onClick={() => confirmDelete(inv.id, 'purchase')}>
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
        </TabsContent>
      </Tabs>

      {/* Create Invoice Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-md" dir={dir}>
          <DialogHeader>
            <DialogTitle>
              {invoiceType === 'sales' ? t('invoices_new_sales_invoice') : t('invoices_new_purchase_invoice')}
            </DialogTitle>
            <DialogDescription>
              {t('invoices_enter_data')}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            {invoiceType === 'sales' ? (
              <div className="space-y-2">
                <Label>{t('invoices_client_name')}</Label>
                <Input
                  value={form.clientName}
                  onChange={(e) => setForm({ ...form, clientName: e.target.value })}
                  placeholder={t('invoices_client_name_placeholder')}
                />
              </div>
            ) : (
              <div className="space-y-2">
                <Label>{t('invoices_supplier_name')}</Label>
                <Input
                  value={form.supplierName}
                  onChange={(e) => setForm({ ...form, supplierName: e.target.value })}
                  placeholder={t('invoices_supplier_name_placeholder')}
                />
              </div>
            )}
            <div className="space-y-2">
              <Label>{t('invoices_item_description')}</Label>
              <Input
                value={form.itemDescription}
                onChange={(e) => setForm({ ...form, itemDescription: e.target.value })}
                placeholder={t('invoices_item_description_placeholder')}
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('invoices_quantity')}</Label>
                <Input
                  type="number"
                  value={form.itemQuantity}
                  onChange={(e) => setForm({ ...form, itemQuantity: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label>{t('invoices_unit_price')}</Label>
                <Input
                  type="number"
                  value={form.itemPrice}
                  onChange={(e) => setForm({ ...form, itemPrice: e.target.value })}
                />
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('notes')}</Label>
              <Input
                value={form.notes}
                onChange={(e) => setForm({ ...form, notes: e.target.value })}
                placeholder={t('invoices_notes_optional')}
              />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setDialogOpen(false)}>{t('cancel')}</Button>
            <Button
              onClick={handleCreateInvoice}
              className={invoiceType === 'sales' ? 'bg-emerald-600 hover:bg-emerald-700' : 'bg-orange-600 hover:bg-orange-700'}
              disabled={saving || !form.itemPrice}
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {t('invoices_create_invoice')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* View Invoice Dialog */}
      <Dialog open={viewDialogOpen} onOpenChange={setViewDialogOpen}>
        <DialogContent className="max-w-lg" dir={dir}>
          <DialogHeader>
            <DialogTitle>
              {viewingInvoice?.invoiceNumber}
            </DialogTitle>
            <DialogDescription>
              {invoiceType === 'sales' ? t('invoices_view_details') : t('invoices_view_purchase_details')}
            </DialogDescription>
          </DialogHeader>
          {viewingInvoice && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-xs text-muted-foreground">{invoiceType === 'sales' ? t('sales_client') : t('purchase_supplier')}</p>
                  <p className="font-medium">{(invoiceType === 'sales' ? (viewingInvoice as SalesInvoice).clientName : (viewingInvoice as PurchaseInvoice).supplierName) || '—'}</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">{t('status')}</p>
                  {getStatusBadge(viewingInvoice.status)}
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">{t('sales_total')}</p>
                  <p className="font-bold text-emerald-700">{viewingInvoice.total.toLocaleString(locale)} {t('currency')}</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">{t('sales_paid')}</p>
                  <p className="font-medium">{viewingInvoice.paidAmount.toLocaleString(locale)} {t('currency')}</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">{t('sales_remaining')}</p>
                  <p className="font-bold text-red-600">{(viewingInvoice.total - viewingInvoice.paidAmount).toLocaleString(locale)} {t('currency')}</p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">{t('date')}</p>
                  <p className="font-medium">{new Date(viewingInvoice.createdAt).toLocaleDateString(locale)}</p>
                </div>
              </div>
              {viewingInvoice.items && viewingInvoice.items.length > 0 && (
                <div>
                  <p className="text-sm font-medium mb-2">{t('invoices_items')}</p>
                  <div className="border rounded-lg overflow-hidden">
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead className="text-right text-xs">{t('invoices_item_description_col')}</TableHead>
                          <TableHead className="text-right text-xs">{t('invoices_quantity_col')}</TableHead>
                          <TableHead className="text-right text-xs">{t('invoices_price_col')}</TableHead>
                          <TableHead className="text-right text-xs">{t('invoices_total_col')}</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {viewingInvoice.items.map((item) => (
                          <TableRow key={item.id}>
                            <TableCell className="text-sm">{item.description || '—'}</TableCell>
                            <TableCell className="text-sm">{item.quantity}</TableCell>
                            <TableCell className="text-sm">{item.unitPrice}</TableCell>
                            <TableCell className="text-sm font-medium">{item.total}</TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                </div>
              )}
              {viewingInvoice.notes && (
                <div>
                  <p className="text-xs text-muted-foreground">{t('notes')}</p>
                  <p className="text-sm">{viewingInvoice.notes}</p>
                </div>
              )}
            </div>
          )}
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent dir={dir}>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('invoices_delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('invoices_delete_irreversible')}
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
