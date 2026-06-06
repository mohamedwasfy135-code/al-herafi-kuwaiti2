'use client'

import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import {
  Plus,
  RotateCcw,
  Eye,
  Trash2,
  Loader2,
  ChevronLeft,
  ChevronRight,
  ArrowRight,
  Store,
  Phone,
  MapPin,
  Printer,
  Banknote,
  Pencil,
  ImagePlus,
} from 'lucide-react'
import {
  Card,
  CardContent,
} from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Separator } from '@/components/ui/separator'
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
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'

// ─── Interfaces ───────────────────────────────────────────────

interface LineItem {
  productCode: string
  productId: string
  description: string
  quantity: string
  unitPrice: string
  discount: string
  total: number
}

interface SalesReturn {
  id: number
  originalInvoiceId: number
  returnNumber: string
  clientName: string | null
  total: number
  reason: string | null
  status: string
  createdAt: string
  originalInvoice: { id: number; invoiceNumber: string; clientName: string | null }
  items?: ReturnItem[]
  business?: {
    id: string
    name: string
    phone?: string | null
    address?: string | null
    logoUrl?: string | null
  }
}

interface ReturnItem {
  id: number
  productId: number | null
  description: string | null
  quantity: number
  unitPrice: number
  discountAmount: number
  total: number
  product?: { id: number; name: string; sku?: string | null } | null
}

interface SalesInvoice {
  id: number
  invoiceNumber: string
  clientName: string | null
  total: number
  items?: InvoiceItemForReturn[]
}

interface InvoiceItemForReturn {
  id: number
  productId: number | null
  description: string | null
  quantity: number
  unitPrice: number
  discountAmount: number
  total: number
  product?: { id: number; name: string; sku?: string | null } | null
}

interface Product {
  id: number
  name: string
  sku?: string | null
  price: number
  stockQuantity: number
}

interface BusinessProfile {
  id: string
  name: string
  phone?: string | null
  address?: string | null
  logoUrl?: string | null
  email?: string | null
  invoiceFooterText?: string | null
}

// ─── Status Map ───────────────────────────────────────────────

// statusMap moved inside component with i18n

const emptyLineItem = (): LineItem => ({
  productCode: '',
  productId: '',
  description: '',
  quantity: '',
  unitPrice: '',
  discount: '0',
  total: 0,
})

// ─── Main Component ───────────────────────────────────────────

export function SalesReturnsTab() {
  const { t, lang, dir } = useLanguage()
  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'
  const router = useRouter()
  const [returns, setReturns] = useState<SalesReturn[]>([])
  const [invoices, setInvoices] = useState<SalesInvoice[]>([])
  const [products, setProducts] = useState<Product[]>([])
  const [business, setBusiness] = useState<BusinessProfile | null>(null)
  const [viewMode, setViewMode] = useState<'list' | 'create' | 'view'>('list')
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [viewingReturn, setViewingReturn] = useState<SalesReturn | null>(null)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)

  // Return navigation
  const [currentReturnIndex, setCurrentReturnIndex] = useState(0)

  // Form state
  const [form, setForm] = useState({
    originalInvoiceId: '',
    clientName: '',
    reason: '',
  })

  // Product search per line item
  const [productSearchIndex, setProductSearchIndex] = useState<number | null>(null)
  const [productSearchTerm, setProductSearchTerm] = useState('')
  const [highlightedProductIdx, setHighlightedProductIdx] = useState(-1)
  const productSearchRef = useRef<HTMLDivElement>(null)

  // Edit shop info dialog
  const [editShopDialogOpen, setEditShopDialogOpen] = useState(false)
  const [editShopForm, setEditShopForm] = useState({ name: '', phone: '', address: '', logoUrl: '' })
  const [editShopSaving, setEditShopSaving] = useState(false)
  const editLogoInputRef = useRef<HTMLInputElement>(null)

  // 10 default rows
  const [lineItems, setLineItems] = useState<LineItem[]>(
    Array(10).fill(null).map(() => emptyLineItem())
  )

  const businessId = getBusinessId()

  // Status map with i18n
  const statusMap = useMemo(() => ({
    pending: { label: t('returns_status_pending'), color: 'bg-amber-100 text-amber-700' },
    approved: { label: t('returns_status_approved'), color: 'bg-sky-100 text-sky-700' },
    completed: { label: t('returns_status_completed'), color: 'bg-emerald-100 text-emerald-700' },
    refunded: { label: t('returns_status_refunded'), color: 'bg-violet-100 text-violet-700' },
  }), [t])

  // ─── Fetch Data ───────────────────────────────────────────

  const fetchData = useCallback(async () => {
    setLoading(true)
    try {
      const [retRes, invRes, prodRes, bizRes] = await Promise.all([
        fetch(`/api/invoices/sales-returns?businessId=${businessId}`),
        fetch(`/api/invoices/sales?businessId=${businessId}`),
        fetch(`/api/products?businessId=${businessId}`),
        fetch(`/api/business/profile?businessId=${businessId}`),
      ])
      if (retRes.ok) {
        const data = await retRes.json()
        if (data.length > 0) setReturns(data)
      }
      if (invRes.ok) setInvoices(await invRes.json())
      if (prodRes.ok) {
        const data = await prodRes.json()
        setProducts(data.map((p: Record<string, unknown>) => ({
          id: p.id as number,
          name: p.name as string,
          sku: (p.sku as string) || null,
          price: p.price as number,
          stockQuantity: (p.stockQuantity as number) || 0,
        })))
      }
      if (bizRes.ok) {
        const data = await bizRes.json()
        setBusiness(data)
      }
    } catch {
      // Keep empty
    } finally {
      setLoading(false)
    }
  }, [businessId])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  // ─── Close product dropdown on outside click ──────────────

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (productSearchRef.current && !productSearchRef.current.contains(e.target as Node)) {
        setProductSearchIndex(null)
        setProductSearchTerm('')
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // ─── Derived values ───────────────────────────────────────

  const subtotal = lineItems.reduce((sum, item) => sum + item.total, 0)
  const totalDiscount = lineItems.reduce(
    (sum, item) => sum + (parseFloat(item.discount) || 0),
    0
  )
  const grandTotal = subtotal

  // ─── Line items ───────────────────────────────────────────

  const addLineItem = () => {
    setLineItems([...lineItems, emptyLineItem()])
  }

  const removeLineItem = (index: number) => {
    if (lineItems.length > 1) {
      setLineItems(lineItems.filter((_, i) => i !== index))
    }
  }

  const updateLineItem = (
    index: number,
    field: keyof LineItem,
    value: string
  ) => {
    const updated = [...lineItems]
    updated[index] = { ...updated[index], [field]: value }

    // Recalculate total
    const qty = parseFloat(updated[index].quantity) || 0
    const price = parseFloat(updated[index].unitPrice) || 0
    const disc = parseFloat(updated[index].discount) || 0
    updated[index].total = qty * price - disc

    setLineItems(updated)
  }

  const selectProduct = (product: Product, index: number) => {
    const updated = [...lineItems]
    const productCode = product.sku || String(product.id)
    updated[index] = {
      ...updated[index],
      productId: String(product.id),
      productCode: productCode,
      description: `${productCode} - ${product.name}`,
      unitPrice: String(product.price),
      quantity: updated[index].quantity || '1',
      discount: updated[index].discount || '0',
    }
    // Recalculate
    const qty = parseFloat(updated[index].quantity) || 0
    const price = parseFloat(updated[index].unitPrice) || 0
    const disc = parseFloat(updated[index].discount) || 0
    updated[index].total = qty * price - disc

    setLineItems(updated)
    setProductSearchIndex(null)
    setProductSearchTerm('')
    setHighlightedProductIdx(-1)
  }

  const filteredProducts = products.filter(
    (p) =>
      p.name.includes(productSearchTerm) ||
      (p.sku && p.sku.includes(productSearchTerm))
  )

  // ─── Keyboard navigation ──────────────────────────────────
  // Modification #4: fieldOrder starts with 'description' (no 'productCode')
  const handleItemKeyDown = (
    e: React.KeyboardEvent<HTMLInputElement>,
    rowIndex: number,
    field: string
  ) => {
    const fieldOrder = ['description', 'quantity', 'unitPrice', 'discount']
    const currentFieldIndex = fieldOrder.indexOf(field)

    if (e.key === 'Enter') {
      e.preventDefault()
      if (currentFieldIndex < fieldOrder.length - 1) {
        const nextField = fieldOrder[currentFieldIndex + 1]
        const el = document.getElementById(`item-${rowIndex}-${nextField}`)
        el?.focus()
      } else if (rowIndex < lineItems.length - 1) {
        const el = document.getElementById(`item-${rowIndex + 1}-description`)
        el?.focus()
      }
    } else if (e.key === 'ArrowDown' && rowIndex < lineItems.length - 1) {
      e.preventDefault()
      const el = document.getElementById(`item-${rowIndex + 1}-${field}`)
      el?.focus()
    } else if (e.key === 'ArrowUp' && rowIndex > 0) {
      e.preventDefault()
      const el = document.getElementById(`item-${rowIndex - 1}-${field}`)
      el?.focus()
    }
  }

  // ─── Return navigation ───────────────────────────────────

  const navigateReturn = (direction: 'prev' | 'next') => {
    let newIndex = currentReturnIndex
    if (direction === 'prev' && currentReturnIndex > 0) {
      newIndex = currentReturnIndex - 1
    } else if (direction === 'next' && currentReturnIndex < returns.length - 1) {
      newIndex = currentReturnIndex + 1
    }
    setCurrentReturnIndex(newIndex)
    const ret = returns[newIndex]
    if (ret) {
      setViewingReturn(ret)
    }
  }

  const openViewForReturn = (ret: SalesReturn) => {
    const index = returns.findIndex((r) => r.id === ret.id)
    setCurrentReturnIndex(index >= 0 ? index : 0)
    setViewingReturn(ret)
    setViewMode('view')
  }

  // ─── Create Return ───────────────────────────────────────

  const openCreate = () => {
    setForm({ originalInvoiceId: '', clientName: '', reason: '' })
    setLineItems(Array(10).fill(null).map(() => emptyLineItem()))
    setViewMode('create')
  }

  // ─── Edit Shop Info ──────────────────────────────────────

  const openEditShopDialog = () => {
    setEditShopForm({
      name: business?.name || '',
      phone: business?.phone || '',
      address: business?.address || '',
      logoUrl: business?.logoUrl || '',
    })
    setEditShopDialogOpen(true)
  }

  const handleEditShopSave = async () => {
    setEditShopSaving(true)
    try {
      const res = await fetch('/api/business/profile', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          name: editShopForm.name,
          phone: editShopForm.phone,
          address: editShopForm.address,
          logoUrl: editShopForm.logoUrl || null,
        }),
      })
      if (res.ok) {
        const updated = await res.json()
        setBusiness(updated)
        setEditShopDialogOpen(false)
        toast.success(t('shop_update_success'))
      } else {
        toast.error(t('shop_update_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setEditShopSaving(false)
    }
  }

  const handleLogoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      toast.error(t('file_type_not_supported'))
      return
    }
    if (file.size > 500 * 1024) {
      toast.error(t('file_size_exceeds'))
      return
    }
    const reader = new FileReader()
    reader.onload = (ev) => {
      const result = ev.target?.result as string
      setEditShopForm({ ...editShopForm, logoUrl: result })
    }
    reader.readAsDataURL(file)
    e.target.value = ''
  }

  // ─── Save Return ─────────────────────────────────────────

  const handleSaveClick = () => {
    const validItems = lineItems.filter(
      (item) => item.unitPrice && parseFloat(item.unitPrice) > 0
    )
    if (validItems.length === 0 && !form.originalInvoiceId) {
      toast.error(t('select_invoice_and_add_item'))
      return
    }
    if (!form.originalInvoiceId) {
      toast.error(t('select_original_invoice'))
      return
    }
    if (validItems.length === 0) {
      toast.error(t('add_at_least_one_item'))
      return
    }
    handleCreateReturn()
  }

  const handleCreateReturn = async () => {
    setSaving(true)
    try {
      const res = await fetch('/api/invoices/sales-returns', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          originalInvoiceId: parseInt(form.originalInvoiceId),
          clientName: form.clientName || undefined,
          total: grandTotal,
          reason: form.reason || null,
        }),
      })

      if (res.ok) {
        const saved = await res.json()
        setReturns((prev) => [saved, ...prev])
        setViewMode('list')
        toast.success(t('return_created_success'))
      } else {
        const err = await res.json()
        toast.error(err.error || t('return_create_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  // ─── Delete Return ───────────────────────────────────────

  const confirmDelete = (id: number) => {
    setDeletingId(id)
    setDeleteDialogOpen(true)
  }

  const handleDelete = async () => {
    if (!deletingId) return
    try {
      setReturns((prev) => prev.filter((r) => r.id !== deletingId))
      toast.success(t('return_deleted'))
    } finally {
      setDeleteDialogOpen(false)
      setDeletingId(null)
    }
  }

  // ─── Process Return (approve / complete / refund) ─────────

  const handleProcessReturn = async (ret: SalesReturn, newStatus: string) => {
    try {
      // Optimistic update
      setReturns((prev) =>
        prev.map((r) => r.id === ret.id ? { ...r, status: newStatus } : r)
      )
      // Update viewing return if it's the same
      if (viewingReturn?.id === ret.id) {
        setViewingReturn({ ...viewingReturn, status: newStatus })
      }

      // Try server update
      try {
        await fetch(`/api/invoices/sales-returns/${ret.id}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: newStatus }),
        })
      } catch {
        // Local update still applies
      }

      const label = statusMap[newStatus]?.label || newStatus
      toast.success(`${t('return_status_updated')} "${label}"`)
    } catch {
      toast.error(t('return_status_update_failed'))
    }
  }

  // ─── Shared top bar for create/view modes ───────────────
  // Modification #6: top bar has no-print class

  const renderTopBar = (
    rightContent: React.ReactNode,
    centerContent: React.ReactNode,
    leftContent: React.ReactNode
  ) => (
    <div className="no-print sticky top-0 z-10 bg-white border-b shadow-sm px-6 py-3 flex items-center justify-between">
      <div className="flex items-center gap-2">{rightContent}</div>
      <div className="flex items-center gap-3">{centerContent}</div>
      <div className="flex items-center gap-2">{leftContent}</div>
    </div>
  )

  // ─── Edit Shop Info Dialog (shared) ─────────────────────

  const renderEditShopDialog = () => (
    <Dialog open={editShopDialogOpen} onOpenChange={setEditShopDialogOpen}>
      <DialogContent className="max-w-md" dir={dir}>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Store className="h-5 w-5 text-emerald-600" />
            {t('edit_shop_info')}
          </DialogTitle>
          <DialogDescription>
            {t('edit_shop_desc')}
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div className="space-y-2">
            <Label>{t('shop_logo_label')}</Label>
            <div className="flex items-center gap-4">
              <div className="h-16 w-16 rounded-xl bg-emerald-100 flex items-center justify-center overflow-hidden">
                {editShopForm.logoUrl ? (
                  <img src={editShopForm.logoUrl} alt="Logo preview" className="h-16 w-16 rounded-xl object-cover" />
                ) : (
                  <Store className="h-8 w-8 text-emerald-600" />
                )}
              </div>
              <div className="flex flex-col gap-1">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="gap-2"
                  onClick={() => editLogoInputRef.current?.click()}
                >
                  <ImagePlus className="h-4 w-4" />
                  {t('change_logo')}
                </Button>
                <span className="text-xs text-muted-foreground">JPG, PNG, WebP — 500KB max</span>
                <input
                  ref={editLogoInputRef}
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  className="hidden"
                  onChange={handleLogoUpload}
                />
              </div>
            </div>
          </div>
          <div className="space-y-2">
            <Label>{t('shop_name_label')}</Label>
            <Input
              value={editShopForm.name}
              onChange={(e) => setEditShopForm({ ...editShopForm, name: e.target.value })}
              placeholder={t('shop_name_label')}
            />
          </div>
          <div className="space-y-2">
            <Label>{t('shop_phone_label')}</Label>
            <Input
              value={editShopForm.phone}
              onChange={(e) => setEditShopForm({ ...editShopForm, phone: e.target.value })}
              placeholder={t('shop_phone_label')}
            />
          </div>
          <div className="space-y-2">
            <Label>{t('shop_address_label')}</Label>
            <Input
              value={editShopForm.address}
              onChange={(e) => setEditShopForm({ ...editShopForm, address: e.target.value })}
              placeholder={t('shop_address_label')}
            />
          </div>
        </div>
        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={() => setEditShopDialogOpen(false)}>{t('cancel')}</Button>
          <Button onClick={handleEditShopSave} className="bg-emerald-600 hover:bg-emerald-700" disabled={editShopSaving}>
            {editShopSaving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
            {t('save')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )

  // ─── Render: VIEW MODE ──────────────────────────────────

  if (viewMode === 'view' && viewingReturn) {
    const ret = viewingReturn

    return (
      <div className="h-full flex flex-col" dir={dir}>
        {renderTopBar(
          /* Right: Back button */
          <Button variant="ghost" onClick={() => setViewMode('list')} className="gap-2 text-emerald-700 hover:text-emerald-900 hover:bg-emerald-50">
            <ArrowRight className="h-4 w-4" />
            {t('back')}
          </Button>,

          /* Center: Navigation arrows */
          <>
            <Button
              variant="outline"
              size="icon"
              className="h-8 w-8 border-emerald-200 hover:bg-emerald-50"
              onClick={() => navigateReturn('prev')}
              disabled={currentReturnIndex <= 0}
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
            <span className="text-sm font-medium text-muted-foreground min-w-[80px] text-center">
              {currentReturnIndex + 1} / {returns.length}
            </span>
            <Button
              variant="outline"
              size="icon"
              className="h-8 w-8 border-emerald-200 hover:bg-emerald-50"
              onClick={() => navigateReturn('next')}
              disabled={currentReturnIndex >= returns.length - 1}
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
          </>,

          /* Left: Actions — Modification #3: مرتجع جديد before print button */
          <>
            <Button
              className="gap-2 bg-emerald-600 hover:bg-emerald-700"
              onClick={openCreate}
            >
              <Plus className="h-4 w-4" />
              {t('new_return')}
            </Button>
            <Button
              variant="outline"
              className="gap-2 border-emerald-200 hover:bg-emerald-50 text-emerald-700"
              onClick={() => window.print()}
            >
              <Printer className="h-4 w-4" />
              {t('print')}
            </Button>
          </>
        )}

        {/* ─── Return content — Modification #6: print-area class ─── */}
        <div className="flex-1 overflow-y-auto p-6 lg:p-8">
          <div className="print-area max-w-7xl mx-auto bg-white border rounded-xl shadow-sm p-6 lg:p-8 space-y-6">
            {/* Header */}
            <div className="flex justify-between items-start">
              <div className="flex items-center gap-4">
                <div className="h-20 w-20 rounded-xl bg-emerald-100 flex items-center justify-center">
                  {business?.logoUrl ? (
                    <img src={business.logoUrl} alt="Logo" className="h-20 w-20 rounded-xl object-cover" />
                  ) : (
                    <Store className="h-10 w-10 text-emerald-600" />
                  )}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-xl font-bold">{business?.name || t('the_shop')}</h2>
                    <Button variant="ghost" size="icon" className="no-print h-6 w-6 text-emerald-500 hover:text-emerald-700 hover:bg-emerald-50" onClick={openEditShopDialog}>
                      <Pencil className="h-3.5 w-3.5" />
                    </Button>
                  </div>
                  {business?.phone && (
                    <p className="text-sm text-muted-foreground flex items-center gap-1">
                      <Phone className="h-3.5 w-3.5" /> {business.phone}
                    </p>
                  )}
                  {business?.address && (
                    <p className="text-sm text-muted-foreground flex items-center gap-1">
                      <MapPin className="h-3.5 w-3.5" /> {business.address}
                    </p>
                  )}
                </div>
              </div>
              <div className="text-left">
                <p className="text-2xl font-bold text-emerald-700">{t('sales_return_label')}</p>
                <p className="text-sm text-muted-foreground">{ret.returnNumber}</p>
                <p className="text-sm text-muted-foreground">{new Date(ret.createdAt).toLocaleDateString(locale)}</p>
              </div>
            </div>

            <Separator />

            {/* Client & original invoice info */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-sm font-medium text-muted-foreground mb-1">{t('sales_client')}</p>
                <p className="font-bold">{ret.clientName || '—'}</p>
              </div>
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-sm font-medium text-muted-foreground mb-1">{t('original_invoice')}</p>
                <p className="font-bold">{ret.originalInvoice?.invoiceNumber || '—'}</p>
              </div>
            </div>

            {/* Modification #5: Items table with # column, wider اسم المادة, narrower العدد/السعر */}
            <Table>
              <TableHeader>
                <TableRow className="bg-gray-50">
                  <TableHead className="text-right font-bold w-10">#</TableHead>
                  <TableHead className="text-right font-bold min-w-[200px]">{t('sales_item_name')}</TableHead>
                  <TableHead className="text-right font-bold w-12">{t('sales_quantity')}</TableHead>
                  <TableHead className="text-right font-bold w-16">{t('sales_unit_price')}</TableHead>
                  <TableHead className="text-right font-bold w-16">{t('sales_discount')}</TableHead>
                  <TableHead className="text-right font-bold">{t('sales_grand_total')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {ret.items && ret.items.length > 0 ? (
                  ret.items.map((item, idx) => (
                    <TableRow key={item.id}>
                      <TableCell className="text-center text-sm">
                        {item.productId ? (
                          <button
                            onClick={() => router.push(`/shop/products?edit=${item.productId}`)}
                            className="text-blue-600 hover:text-blue-800 hover:underline cursor-pointer font-medium"
                            title={t('open_product_card')}
                          >
                            {idx + 1}
                          </button>
                        ) : (
                          <span className="text-muted-foreground">{idx + 1}</span>
                        )}
                      </TableCell>
                      <TableCell className="font-medium">{item.description || item.product?.name || '—'}</TableCell>
                      <TableCell className="text-center">{item.quantity}</TableCell>
                      <TableCell className="text-center">{item.unitPrice.toLocaleString(locale)}</TableCell>
                      <TableCell className="text-center">{item.discountAmount.toLocaleString(locale)}</TableCell>
                      <TableCell className="font-bold">{item.total.toLocaleString(locale)}</TableCell>
                    </TableRow>
                  ))
                ) : (
                  /* When no items are stored, show a single row with the total */
                  <TableRow>
                    <TableCell className="text-center text-sm">
                      <span className="text-muted-foreground">1</span>
                    </TableCell>
                    <TableCell className="text-muted-foreground">{ret.reason || t('sales_return_label')}</TableCell>
                    <TableCell className="text-center">1</TableCell>
                    <TableCell className="text-center">{ret.total.toLocaleString(locale)}</TableCell>
                    <TableCell className="text-center">0</TableCell>
                    <TableCell className="font-bold">{ret.total.toLocaleString(locale)}</TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>

            {/* Totals */}
            <div className="flex justify-end">
              <div className="w-80 space-y-2">
                <Separator />
                <div className="flex justify-between font-bold text-lg">
                  <span>{t('sales_grand_total')}</span>
                  <span className="text-emerald-700">{ret.total.toLocaleString(locale)} {t('currency')}</span>
                </div>
              </div>
            </div>

            {/* Status */}
            <div className="flex items-center gap-2">
              <span className="text-sm text-muted-foreground">{t('returns_status_label')}:</span>
              <Badge variant="secondary" className={`text-xs ${(statusMap[ret.status] || statusMap.pending).color}`}>
                {(statusMap[ret.status] || statusMap.pending).label}
              </Badge>
            </div>

            {/* Action buttons for unprocessed returns */}
            {ret.status === 'pending' && (
              <div className="no-print flex gap-2">
                <Button
                  className="gap-2 bg-sky-600 hover:bg-sky-700"
                  onClick={() => handleProcessReturn(ret, 'approved')}
                >
                  <RotateCcw className="h-4 w-4" />
                  {t('accept_return')}
                </Button>
              </div>
            )}
            {ret.status === 'approved' && (
              <div className="no-print flex gap-2">
                <Button
                  className="gap-2 bg-emerald-600 hover:bg-emerald-700"
                  onClick={() => handleProcessReturn(ret, 'completed')}
                >
                  <Banknote className="h-4 w-4" />
                  {t('complete_refund')}
                </Button>
              </div>
            )}

            <Separator />

            {/* Footer */}
            <div className="text-center space-y-2 text-xs text-muted-foreground">
              {ret.reason && (
                <p className="text-sm"><strong>{t('return_reason')}:</strong> {ret.reason}</p>
              )}
              <p className="font-medium text-gray-600">
                {business?.invoiceFooterText || t('sales_footer')}
              </p>
            </div>
          </div>
        </div>

        {/* Delete Confirmation */}
        <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
          <AlertDialogContent dir={dir}>
            <AlertDialogHeader>
              <AlertDialogTitle>{t('returns_delete_title')}</AlertDialogTitle>
              <AlertDialogDescription>
                {t('returns_delete_confirm')}
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

        {/* Edit Shop Info Dialog */}
        {renderEditShopDialog()}
      </div>
    )
  }

  // ─── Render: CREATE MODE ────────────────────────────────

  if (viewMode === 'create') {
    return (
      <div className="h-full flex flex-col" dir={dir}>
        {renderTopBar(
          /* Right: Back button */
          <Button variant="ghost" onClick={() => setViewMode('list')} className="gap-2 text-emerald-700 hover:text-emerald-900 hover:bg-emerald-50">
            <ArrowRight className="h-4 w-4" />
            {t('back')}
          </Button>,

          /* Center: Title */
          <span className="text-sm font-medium text-muted-foreground">{t('new_sales_return')}</span>,

          /* Left: Save button */
          <Button
            onClick={handleSaveClick}
            className="gap-2 bg-emerald-600 hover:bg-emerald-700"
            disabled={saving}
          >
            {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
            {t('save_return')}
          </Button>
        )}

        <div className="flex-1 overflow-y-auto p-6 lg:p-8">
          <div className="print-area max-w-7xl mx-auto bg-white border rounded-xl shadow-sm p-6 lg:p-8 space-y-6">
            {/* Header */}
            <div className="flex justify-between items-start">
              <div className="flex items-center gap-4">
                <div className="h-20 w-20 rounded-xl bg-emerald-100 flex items-center justify-center">
                  {business?.logoUrl ? (
                    <img src={business.logoUrl} alt="Logo" className="h-20 w-20 rounded-xl object-cover" />
                  ) : (
                    <Store className="h-10 w-10 text-emerald-600" />
                  )}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-xl font-bold">{business?.name || t('the_shop')}</h2>
                    <Button variant="ghost" size="icon" className="no-print h-6 w-6 text-emerald-500 hover:text-emerald-700 hover:bg-emerald-50" onClick={openEditShopDialog}>
                      <Pencil className="h-3.5 w-3.5" />
                    </Button>
                  </div>
                  {business?.phone && (
                    <p className="text-sm text-muted-foreground flex items-center gap-1">
                      <Phone className="h-3.5 w-3.5" /> {business.phone}
                    </p>
                  )}
                  {business?.address && (
                    <p className="text-sm text-muted-foreground flex items-center gap-1">
                      <MapPin className="h-3.5 w-3.5" /> {business.address}
                    </p>
                  )}
                </div>
              </div>
              <div className="text-left">
                <p className="text-2xl font-bold text-emerald-700">{t('sales_return_label')}</p>
                <p className="text-sm text-muted-foreground">{t('new_return')}</p>
              </div>
            </div>

            <Separator />

            {/* Original invoice selection & client info */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label>{t('original_invoice')} *</Label>
                <Select value={form.originalInvoiceId} onValueChange={(val) => {
                  const inv = invoices.find((i) => String(i.id) === val)
                  setForm({
                    ...form,
                    originalInvoiceId: val,
                    clientName: inv?.clientName || '',
                  })
                }}>
                  <SelectTrigger><SelectValue placeholder={t('select_invoice')} /></SelectTrigger>
                  <SelectContent>
                    {invoices.map((inv) => (
                      <SelectItem key={inv.id} value={String(inv.id)}>
                        {inv.invoiceNumber} - {inv.clientName || t('without_client')} ({inv.total.toLocaleString(locale)} {t('currency')})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>{t('sales_client')}</Label>
                <Input
                  value={form.clientName}
                  onChange={(e) => setForm({ ...form, clientName: e.target.value })}
                  placeholder={t('client_name_placeholder')}
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label>{t('returns_reason_label')}</Label>
              <Textarea
                value={form.reason}
                onChange={(e) => setForm({ ...form, reason: e.target.value })}
                placeholder={t('returns_reason_placeholder')}
                rows={2}
              />
            </div>

            <Separator />

            {/* Modification #4: Items grid with # column instead of كود column */}
            <div className="space-y-3">
              <h3 className="font-bold text-sm">{t('return_items')}</h3>
              <div className="overflow-x-auto border rounded-lg">
                <Table>
                  <TableHeader>
                    <TableRow className="bg-gray-50">
                      <TableHead className="no-print text-right font-bold w-10">#</TableHead>
                      <TableHead className="text-right font-bold min-w-[200px]">{t('sales_item_name')}</TableHead>
                      <TableHead className="text-right font-bold w-14">{t('sales_quantity')}</TableHead>
                      <TableHead className="text-right font-bold w-16">{t('sales_unit_price')}</TableHead>
                      <TableHead className="text-right font-bold w-16">{t('sales_discount')}</TableHead>
                      <TableHead className="text-right font-bold w-20">{t('sales_grand_total')}</TableHead>
                      <TableHead className="no-print w-10"></TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {lineItems.map((item, idx) => (
                      <TableRow key={idx} className="group">
                        {/* # sequential number column, no-print, clickable if productId */}
                        <TableCell className="no-print text-center text-sm">
                          {item.productId ? (
                            <button
                              onClick={() => router.push(`/shop/products?edit=${item.productId}`)}
                              className="text-blue-600 hover:text-blue-800 hover:underline cursor-pointer font-medium"
                              title={t('open_product_card')}
                            >
                              {idx + 1}
                            </button>
                          ) : (
                            <span className="text-muted-foreground">{idx + 1}</span>
                          )}
                        </TableCell>
                        {/* Description field - merged with productCode per modification #4 */}
                        <TableCell className="relative p-1">
                          <Input
                            id={`item-${idx}-description`}
                            value={item.description}
                            onChange={(e) => updateLineItem(idx, 'description', e.target.value)}
                            onKeyDown={(e) => handleItemKeyDown(e, idx, 'description')}
                            onFocus={() => {
                              setProductSearchIndex(idx)
                              setProductSearchTerm('')
                              setHighlightedProductIdx(-1)
                            }}
                            placeholder={t('returns_item_search_placeholder')}
                            className="h-9 border-0 shadow-none focus-visible:ring-1 text-sm"
                          />
                          {/* Product search dropdown */}
                          {productSearchIndex === idx && productSearchTerm !== undefined && (
                            <div
                              ref={productSearchRef}
                              className="absolute left-0 right-0 top-full z-50 mt-1 bg-white border rounded-lg shadow-lg max-h-48 overflow-y-auto"
                            >
                              {filteredProducts.length > 0 ? (
                                filteredProducts.map((product, pIdx) => (
                                  <button
                                    key={product.id}
                                    className={`w-full px-3 py-2 text-right text-sm hover:bg-emerald-50 flex justify-between items-center ${
                                      pIdx === highlightedProductIdx ? 'bg-emerald-50' : ''
                                    }`}
                                    onClick={() => selectProduct(product, idx)}
                                    onMouseEnter={() => setHighlightedProductIdx(pIdx)}
                                  >
                                    <span>{product.name}</span>
                                    <span className="text-xs text-muted-foreground">
                                      {product.sku && `${product.sku} • `}
                                      {product.price.toLocaleString(locale)} {t('currency')}
                                    </span>
                                  </button>
                                ))
                              ) : (
                                <div className="px-3 py-2 text-sm text-muted-foreground text-center">{t('no_results')}</div>
                              )}
                            </div>
                          )}
                        </TableCell>
                        <TableCell className="p-1">
                          <Input
                            id={`item-${idx}-quantity`}
                            value={item.quantity}
                            onChange={(e) => updateLineItem(idx, 'quantity', e.target.value)}
                            onKeyDown={(e) => handleItemKeyDown(e, idx, 'quantity')}
                            placeholder="0"
                            className="h-9 border-0 shadow-none focus-visible:ring-1 text-sm text-center"
                          />
                        </TableCell>
                        <TableCell className="p-1">
                          <Input
                            id={`item-${idx}-unitPrice`}
                            value={item.unitPrice}
                            onChange={(e) => updateLineItem(idx, 'unitPrice', e.target.value)}
                            onKeyDown={(e) => handleItemKeyDown(e, idx, 'unitPrice')}
                            placeholder="0"
                            className="h-9 border-0 shadow-none focus-visible:ring-1 text-sm text-center"
                          />
                        </TableCell>
                        <TableCell className="p-1">
                          <Input
                            id={`item-${idx}-discount`}
                            value={item.discount}
                            onChange={(e) => updateLineItem(idx, 'discount', e.target.value)}
                            onKeyDown={(e) => handleItemKeyDown(e, idx, 'discount')}
                            placeholder="0"
                            className="h-9 border-0 shadow-none focus-visible:ring-1 text-sm text-center"
                          />
                        </TableCell>
                        <TableCell className="p-1 text-center font-medium text-sm">
                          {item.total > 0 ? item.total.toLocaleString(locale) : ''}
                        </TableCell>
                        <TableCell className="no-print p-1">
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-7 w-7 opacity-0 group-hover:opacity-100 text-red-500 hover:text-red-700 hover:bg-red-50"
                            onClick={() => removeLineItem(idx)}
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
              <Button
                variant="outline"
                size="sm"
                className="gap-2 no-print"
                onClick={addLineItem}
              >
                <Plus className="h-4 w-4" />
                {t('returns_add_item')}
              </Button>
            </div>

            {/* Totals */}
            <div className="flex justify-end">
              <div className="w-80 space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">{t('subtotal')}</span>
                  <span>{subtotal.toLocaleString(locale)} {t('currency')}</span>
                </div>
                {totalDiscount > 0 && (
                  <div className="flex justify-between text-sm text-red-600">
                    <span>{t('discount')}</span>
                    <span>- {totalDiscount.toLocaleString(locale)} {t('currency')}</span>
                  </div>
                )}
                <Separator />
                <div className="flex justify-between font-bold text-lg">
                  <span>{t('sales_grand_total')}</span>
                  <span className="text-emerald-700">{grandTotal.toLocaleString(locale)} {t('currency')}</span>
                </div>
              </div>
            </div>

            <Separator />

            {/* Footer */}
            <div className="text-center space-y-2 text-xs text-muted-foreground">
              <p className="font-medium text-gray-600">
                {business?.invoiceFooterText || t('sales_footer')}
              </p>
            </div>
          </div>
        </div>

        {/* Modification #1: Edit Shop Info Dialog in CREATE mode */}
        {renderEditShopDialog()}
      </div>
    )
  }

  // ─── Render: LIST MODE ──────────────────────────────────

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('returns_sales')}</h2>
          <p className="text-muted-foreground">{t('returns_subtitle')}</p>
        </div>
        <Button onClick={openCreate} className="gap-2 bg-emerald-600 hover:bg-emerald-700">
          <Plus className="h-4 w-4" /> {t('returns_new_return')}
        </Button>
      </div>

      <Card>
        <CardContent className="p-0">
          {loading ? (
            <div className="flex items-center justify-center py-12"><Loader2 className="h-8 w-8 animate-spin text-emerald-600" /></div>
          ) : returns.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <RotateCcw className="h-12 w-12 mb-3 opacity-30" /><p>{t('returns_no_returns')}</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-right">{t('returns_return_number')}</TableHead>
                    <TableHead className="text-right">{t('returns_original_invoice')}</TableHead>
                    <TableHead className="text-right">{t('sales_client')}</TableHead>
                    <TableHead className="text-right">{t('amount')}</TableHead>
                    <TableHead className="text-right">{t('returns_reason')}</TableHead>
                    <TableHead className="text-right">{t('status')}</TableHead>
                    <TableHead className="text-right">{t('date')}</TableHead>
                    <TableHead className="text-right">{t('actions')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {returns.map((ret) => (
                    <TableRow key={ret.id}>
                      <TableCell className="font-medium">{ret.returnNumber}</TableCell>
                      <TableCell>{ret.originalInvoice?.invoiceNumber || '—'}</TableCell>
                      <TableCell>{ret.clientName || '—'}</TableCell>
                      <TableCell className="font-medium">{ret.total.toLocaleString(locale)} {t('currency')}</TableCell>
                      <TableCell className="text-sm text-muted-foreground max-w-[150px] truncate">{ret.reason || '—'}</TableCell>
                      <TableCell>
                        <Badge variant="secondary" className={`text-xs ${(statusMap[ret.status] || statusMap.pending).color}`}>
                          {(statusMap[ret.status] || statusMap.pending).label}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">{new Date(ret.createdAt).toLocaleDateString(locale)}</TableCell>
                      {/* Modification #2: Action buttons for unprocessed returns */}
                      <TableCell>
                        <div className="flex items-center gap-1">
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-8 w-8 text-emerald-600 hover:bg-emerald-50"
                            onClick={() => openViewForReturn(ret)}
                          >
                            <Eye className="h-4 w-4" />
                          </Button>
                          {ret.status === 'pending' && (
                            <Button
                              variant="ghost"
                              size="sm"
                              className="h-8 gap-1 text-sky-600 hover:bg-sky-50 text-xs"
                              onClick={() => handleProcessReturn(ret, 'approved')}
                            >
                              <RotateCcw className="h-3.5 w-3.5" />
                              {t('returns_accept')}
                            </Button>
                          )}
                          {ret.status === 'approved' && (
                            <Button
                              variant="ghost"
                              size="sm"
                              className="h-8 gap-1 text-emerald-600 hover:bg-emerald-50 text-xs"
                              onClick={() => handleProcessReturn(ret, 'completed')}
                            >
                              <Banknote className="h-3.5 w-3.5" />
                              {t('returns_refund')}
                            </Button>
                          )}
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-8 w-8 text-red-500 hover:bg-red-50"
                            onClick={() => confirmDelete(ret.id)}
                          >
                            <Trash2 className="h-4 w-4" />
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

      {/* Delete Confirmation */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent dir={dir}>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('returns_delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('returns_delete_confirm')}
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

      {/* Edit Shop Info Dialog */}
      {renderEditShopDialog()}
    </div>
  )
}
