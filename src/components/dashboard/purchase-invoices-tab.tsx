'use client'

import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import {
  Plus,
  Receipt,
  Eye,
  Trash2,
  Loader2,
  Filter,
  ShoppingCart,
  ChevronLeft,
  ChevronRight,
  ArrowRight,
  Search,
  Store,
  Phone,
  MapPin,
  X,
  Printer,
  Banknote,
  CreditCard,
  Wallet,
  Calendar,
  StickyNote,
  PackageCheck,
  DollarSign,
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

interface PurchaseInvoice {
  id: number
  invoiceNumber: string
  supplierId: number | null
  supplierName: string | null
  supplierPhone: string | null
  total: number
  subtotal: number
  discountAmount: number
  taxAmount: number
  paidAmount: number
  status: string
  notes: string | null
  createdAt: string
  items?: InvoiceItem[]
  business?: {
    id: string
    name: string
    phone?: string | null
    address?: string | null
    logoUrl?: string | null
  }
}

interface InvoiceItem {
  id: number
  productId: number | null
  description: string | null
  quantity: number
  unitPrice: number
  discountAmount: number
  total: number
  product?: { id: number; name: string; sku?: string | null } | null
}

interface Supplier {
  id: number
  name: string
  phone?: string | null
  address?: string | null
  balance?: number
}

interface Product {
  id: number
  name: string
  sku?: string | null
  price: number
  costPrice: number
  stockQuantity: number
}

interface BusinessProfile {
  id: string
  name: string
  phone?: string | null
  address?: string | null
  logoUrl?: string | null
  email?: string | null
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

// ─── Payment Dialog Component ─────────────────────────────────

function PaymentDialog({
  open,
  onOpenChange,
  grandTotal,
  initialPaidAmount,
  onSave,
  saving,
  isRemainingPayment,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  grandTotal: number
  initialPaidAmount?: number
  onSave: (data: {
    paidAmount: number
    paymentMethod: string
    paymentDate: string
    status: string
  }) => void
  saving: boolean
  isRemainingPayment?: boolean
}) {
  const { t, lang, dir } = useLanguage()
  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'
  const [paymentMethod, setPaymentMethod] = useState('cash')
  const [paymentDate, setPaymentDate] = useState(
    new Date().toISOString().split('T')[0]
  )
  const [paidAmount, setPaidAmount] = useState('')
  const [lastGrandTotal, setLastGrandTotal] = useState(0)

  // Sync paid amount with grand total when it changes
  if (grandTotal !== lastGrandTotal) {
    setLastGrandTotal(grandTotal)
    setPaidAmount(initialPaidAmount !== undefined ? String(initialPaidAmount) : String(grandTotal))
    setPaymentDate(new Date().toISOString().split('T')[0])
    setPaymentMethod('cash')
  }

  const paid = parseFloat(paidAmount) || 0
  const remaining = grandTotal - paid

  const handleSave = (forceStatus?: string) => {
    const status = forceStatus || (paid >= grandTotal && grandTotal > 0 ? 'paid' : paid > 0 ? 'partial' : 'unpaid')
    onSave({
      paidAmount: paid,
      paymentMethod,
      paymentDate,
      status,
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md" dir={dir}>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Banknote className="h-5 w-5 text-orange-600" />
            {isRemainingPayment ? t('sales_pay_remaining') : t('record_supplier_payment')}
          </DialogTitle>
          <DialogDescription>
            {isRemainingPayment ? t('pay_remaining_balance') : t('specify_supplier_payment')}
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div className="rounded-lg bg-orange-50 border border-orange-200 p-4 text-center">
            <p className="text-sm text-orange-700 mb-1">
              {isRemainingPayment ? t('remaining_amount') : t('total_invoice')}
            </p>
            <p className="text-2xl font-bold text-orange-800">
              {grandTotal.toLocaleString(locale)} <span className="text-sm font-normal">{t('currency')}</span>
            </p>
          </div>

          <div className="space-y-2">
            <Label>{t('sales_payment_method')}</Label>
            <div className="grid grid-cols-3 gap-2">
              {[
                { value: 'bank', label: t('bank'), icon: Banknote },
                { value: 'knet', label: t('knet'), icon: CreditCard },
                { value: 'cash', label: t('cash'), icon: Wallet },
              ].map((method) => (
                <Button
                  key={method.value}
                  type="button"
                  variant={paymentMethod === method.value ? 'default' : 'outline'}
                  className={`gap-2 h-12 ${paymentMethod === method.value ? 'bg-orange-600 hover:bg-orange-700' : ''}`}
                  onClick={() => setPaymentMethod(method.value)}
                >
                  <method.icon className="h-4 w-4" />
                  {method.label}
                </Button>
              ))}
            </div>
          </div>

          <div className="space-y-2">
            <Label className="flex items-center gap-1">
              <Calendar className="h-3.5 w-3.5" />
              {t('sales_payment_date')}
            </Label>
            <Input
              type="date"
              value={paymentDate}
              onChange={(e) => setPaymentDate(e.target.value)}
            />
          </div>

          <div className="space-y-2">
            <Label>{t('sales_paid_amount')}</Label>
            <Input
              type="text"
              inputMode="decimal"
              className="[appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
              value={paidAmount}
              onChange={(e) => setPaidAmount(e.target.value)}
              placeholder="0.000"
            />
            {paid < grandTotal && paid > 0 && (
              <p className="text-xs text-yellow-600">
                {t('sales_remaining')}: {remaining.toLocaleString(locale)} {t('currency')} — {t('will_be_recorded_as_partial')}
              </p>
            )}
            {paid >= grandTotal && grandTotal > 0 && (
              <p className="text-xs text-emerald-600">{t('will_be_recorded_as_paid')}</p>
            )}
          </div>
        </div>
        <DialogFooter className="gap-2 flex-col sm:flex-row">
          <Button
            variant="outline"
            className="text-red-600 border-red-200 hover:bg-red-50"
            onClick={() => handleSave('unpaid')}
            disabled={saving}
          >
            {t('sales_save_pending')}
          </Button>
          <Button
            onClick={() => handleSave()}
            className="bg-orange-600 hover:bg-orange-700 min-w-[120px]"
            disabled={saving}
          >
            {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
            {isRemainingPayment ? t('sales_pay_remaining') : t('sales_save_invoice')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ─── Main Component ───────────────────────────────────────────

export function PurchaseInvoicesTab() {
  const { t, lang, dir } = useLanguage()
  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'
  const router = useRouter()
  const [invoices, setInvoices] = useState<PurchaseInvoice[]>([])
  const [suppliers, setSuppliers] = useState<Supplier[]>([])
  const [products, setProducts] = useState<Product[]>([])
  const [business, setBusiness] = useState<BusinessProfile | null>(null)
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [viewMode, setViewMode] = useState<'list' | 'create' | 'view'>('list')
  const [paymentDialogOpen, setPaymentDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [viewingInvoice, setViewingInvoice] = useState<PurchaseInvoice | null>(null)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)

  // Invoice navigation
  const [currentInvoiceIndex, setCurrentInvoiceIndex] = useState(0)

  // Pay remaining state
  const [payRemainingInvoice, setPayRemainingInvoice] = useState<PurchaseInvoice | null>(null)
  const [payRemainingDialogOpen, setPayRemainingDialogOpen] = useState(false)
  const [payRemainingSaving, setPayRemainingSaving] = useState(false)

  // Form state
  const [form, setForm] = useState({
    supplierId: '',
    supplierName: '',
    supplierPhone: '',
    notes: '',
  })

  // Supplier search
  const [supplierSearch, setSupplierSearch] = useState('')
  const [supplierDropdownOpen, setSupplierDropdownOpen] = useState(false)
  const supplierSearchRef = useRef<HTMLDivElement>(null)

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
    draft: { label: t('sales_status_draft'), color: 'bg-gray-100 text-gray-700' },
    confirmed: { label: t('sales_status_confirmed'), color: 'bg-sky-100 text-sky-700' },
    unpaid: { label: t('sales_status_unpaid'), color: 'bg-red-100 text-red-700' },
    partial: { label: t('sales_status_partial'), color: 'bg-yellow-100 text-yellow-700' },
    paid: { label: t('sales_status_paid'), color: 'bg-emerald-100 text-emerald-700' },
    cancelled: { label: t('sales_status_cancelled'), color: 'bg-gray-100 text-gray-500' },
  }), [t])

  // ─── Fetch Data ───────────────────────────────────────────

  const fetchData = useCallback(async () => {
    setLoading(true)
    try {
      const [invRes, supRes, prodRes, bizRes] = await Promise.all([
        fetch(`/api/invoices/purchase?businessId=${businessId}`),
        fetch(`/api/suppliers?businessId=${businessId}`),
        fetch(`/api/products?businessId=${businessId}`),
        fetch(`/api/business/profile?businessId=${businessId}`),
      ])
      if (invRes.ok) {
        const data = await invRes.json()
        if (data.length > 0) setInvoices(data)
      }
      if (supRes.ok) {
        const data = await supRes.json()
        setSuppliers(data)
      }
      if (prodRes.ok) {
        const data = await prodRes.json()
        setProducts(data.map((p: Record<string, unknown>) => ({
          id: p.id as number,
          name: p.name as string,
          sku: (p.sku as string) || null,
          price: p.price as number,
          costPrice: (p.costPrice as number) || 0,
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

  // ─── Close dropdowns on outside click ─────────────────────

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (supplierSearchRef.current && !supplierSearchRef.current.contains(e.target as Node)) {
        setSupplierDropdownOpen(false)
      }
      if (productSearchRef.current && !productSearchRef.current.contains(e.target as Node)) {
        setProductSearchIndex(null)
        setProductSearchTerm('')
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // ─── Derived values ───────────────────────────────────────

  const filteredInvoices =
    statusFilter === 'all'
      ? invoices
      : invoices.filter((i) => i.status === statusFilter)
  const totalPurchases = invoices.reduce((sum, i) => sum + i.total, 0)

  const subtotal = lineItems.reduce((sum, item) => sum + item.total, 0)
  const totalDiscount = lineItems.reduce(
    (sum, item) => sum + (parseFloat(item.discount) || 0),
    0
  )
  const grandTotal = subtotal

  // ─── Supplier search ──────────────────────────────────────

  const filteredSuppliers = suppliers.filter((s) =>
    s.name.includes(supplierSearch) ||
    (s.phone && s.phone.includes(supplierSearch))
  )

  const selectSupplier = (supplier: Supplier) => {
    setForm({
      ...form,
      supplierId: String(supplier.id),
      supplierName: supplier.name,
      supplierPhone: supplier.phone || '',
    })
    setSupplierSearch('')
    setSupplierDropdownOpen(false)
  }

  const clearSupplier = () => {
    setForm({ ...form, supplierId: '', supplierName: '', supplierPhone: '' })
    setSupplierSearch('')
  }

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

  // Get last purchase price for a product from existing invoices
  const getLastPurchasePrice = (productId: number): number | null => {
    for (const inv of invoices) {
      if (!inv.items) continue
      for (const item of inv.items) {
        if (item.productId === productId && item.unitPrice > 0) {
          return item.unitPrice
        }
      }
    }
    return null
  }

  const selectProduct = (product: Product, index: number) => {
    const updated = [...lineItems]
    // Use last purchase price if available, otherwise use costPrice
    const lastPrice = getLastPurchasePrice(product.id)
    const priceToUse = lastPrice !== null ? lastPrice : product.costPrice
    const productCode = product.sku || String(product.id)
    updated[index] = {
      ...updated[index],
      productId: String(product.id),
      productCode: productCode,
      description: `${productCode} - ${product.name}`,
      unitPrice: String(priceToUse),
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

  const handleItemKeyDown = (
    e: React.KeyboardEvent<HTMLInputElement>,
    rowIndex: number,
    field: string
  ) => {
    const fieldOrder = ['description', 'quantity', 'unitPrice', 'discount']
    const currentFieldIndex = fieldOrder.indexOf(field)

    if (e.key === 'Enter') {
      e.preventDefault()
      // Move to next field
      if (currentFieldIndex < fieldOrder.length - 1) {
        const nextField = fieldOrder[currentFieldIndex + 1]
        const el = document.getElementById(`item-${rowIndex}-${nextField}`)
        el?.focus()
      } else if (rowIndex < lineItems.length - 1) {
        // Move to next row
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

  // ─── Invoice navigation ───────────────────────────────────

  const navigateInvoice = (direction: 'prev' | 'next') => {
    let newIndex = currentInvoiceIndex
    if (direction === 'prev' && currentInvoiceIndex > 0) {
      newIndex = currentInvoiceIndex - 1
    } else if (direction === 'next' && currentInvoiceIndex < invoices.length - 1) {
      newIndex = currentInvoiceIndex + 1
    }
    setCurrentInvoiceIndex(newIndex)
    const inv = invoices[newIndex]
    if (inv) {
      setViewingInvoice(inv)
    }
  }

  const openViewForInvoice = (inv: PurchaseInvoice) => {
    const idx = invoices.findIndex((i) => i.id === inv.id)
    setCurrentInvoiceIndex(idx >= 0 ? idx : 0)
    setViewingInvoice(inv)
    setViewMode('view')
  }

  // ─── Create Invoice ───────────────────────────────────────

  const openCreate = () => {
    setForm({ supplierId: '', supplierName: '', supplierPhone: '', notes: '' })
    setSupplierSearch('')
    setLineItems(Array(10).fill(null).map(() => emptyLineItem()))
    setViewMode('create')
  }

  // ─── New from current invoice ────────────────────────────

  const openNewFromCurrent = (invoice: PurchaseInvoice) => {
    setForm({
      supplierId: invoice.supplierId ? String(invoice.supplierId) : '',
      supplierName: invoice.supplierName || '',
      supplierPhone: invoice.supplierPhone || '',
      notes: '',
    })
    setSupplierSearch('')
    if (invoice.items && invoice.items.length > 0) {
      const items = invoice.items.map((item) => ({
        productCode: item.product?.sku || (item.productId ? String(item.productId) : ''),
        productId: item.productId ? String(item.productId) : '',
        description: item.description || item.product?.name || '',
        quantity: String(item.quantity),
        unitPrice: String(item.unitPrice),
        discount: String(item.discountAmount),
        total: item.total,
      }))
      // Pad to at least 10 rows
      while (items.length < 10) items.push(emptyLineItem())
      setLineItems(items)
    } else {
      setLineItems(Array(10).fill(null).map(() => emptyLineItem()))
    }
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

  const handleSaveClick = () => {
    const validItems = lineItems.filter(
      (item) => item.unitPrice && parseFloat(item.unitPrice) > 0
    )
    if (validItems.length === 0) {
      toast.error(t('add_at_least_one_item'))
      return
    }
    // Open payment dialog
    setPaymentDialogOpen(true)
  }

  const handlePaymentSave = async (paymentData: {
    paidAmount: number
    paymentMethod: string
    paymentDate: string
    status: string
  }) => {
    const items = lineItems
      .filter((item) => item.unitPrice && parseFloat(item.unitPrice) > 0)
      .map((item) => ({
        productId: item.productId ? parseInt(item.productId) : null,
        description: item.description,
        quantity: parseFloat(item.quantity) || 1,
        unitPrice: parseFloat(item.unitPrice) || 0,
        discountAmount: parseFloat(item.discount) || 0,
        total: item.total,
      }))

    setSaving(true)
    try {
      const res = await fetch('/api/invoices/purchase', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          supplierId: form.supplierId ? parseInt(form.supplierId) : null,
          supplierName: form.supplierName || undefined,
          supplierPhone: form.supplierPhone || undefined,
          items,
          discountAmount: totalDiscount,
          notes: form.notes || null,
          paidAmount: paymentData.paidAmount,
          status: paymentData.status,
          paymentMethod: paymentData.paymentMethod,
          paymentDate: paymentData.paymentDate,
        }),
      })

      if (res.ok) {
        const saved = await res.json()
        setInvoices((prev) => [saved, ...prev])
        setPaymentDialogOpen(false)
        setViewMode('list')
        toast.success(t('purchase_invoice_created'))
      } else {
        const err = await res.json()
        toast.error(err.error || t('invoice_create_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  // ─── Delete Invoice ───────────────────────────────────────

  const confirmDelete = (id: number) => {
    setDeletingId(id)
    setDeleteDialogOpen(true)
  }

  const handleDelete = async () => {
    if (!deletingId) return
    try {
      setInvoices((prev) => prev.filter((i) => i.id !== deletingId))
      toast.success(t('invoice_deleted'))
    } finally {
      setDeleteDialogOpen(false)
      setDeletingId(null)
    }
  }

  // ─── Pay Remaining ────────────────────────────────────────

  const openPayRemaining = (invoice: PurchaseInvoice) => {
    setPayRemainingInvoice(invoice)
    setPayRemainingDialogOpen(true)
  }

  const handlePayRemainingSave = async (paymentData: {
    paidAmount: number
    paymentMethod: string
    paymentDate: string
    status: string
  }) => {
    if (!payRemainingInvoice) return
    setPayRemainingSaving(true)
    try {
      // Update the invoice with additional payment
      const remaining = payRemainingInvoice.total - payRemainingInvoice.paidAmount
      const actualPaid = Math.min(paymentData.paidAmount, remaining)
      const finalPaid = payRemainingInvoice.paidAmount + actualPaid
      const newStatus = finalPaid >= payRemainingInvoice.total ? 'paid' : 'partial'

      // Update locally
      setInvoices((prev) =>
        prev.map((inv) =>
          inv.id === payRemainingInvoice.id
            ? { ...inv, paidAmount: finalPaid, status: newStatus }
            : inv
        )
      )

      // Try to update on server
      try {
        await fetch(`/api/invoices/purchase/${payRemainingInvoice.id}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            paidAmount: finalPaid,
            status: newStatus,
            paymentMethod: paymentData.paymentMethod,
            paymentDate: paymentData.paymentDate,
          }),
        })
      } catch {
        // Local update still applies
      }

      toast.success(`${actualPaid.toLocaleString(locale)} ${t('currency')} ${t('payment_success')}`)
      setPayRemainingDialogOpen(false)
      setPayRemainingInvoice(null)
    } finally {
      setPayRemainingSaving(false)
    }
  }

  // ─── Shared top bar for create/view modes ───────────────

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

  // ─── Render: VIEW MODE (content area, not overlay) ──────

  if (viewMode === 'view' && viewingInvoice) {
    const invoice = viewingInvoice
    const remaining = invoice.total - invoice.paidAmount

    return (
      <div className="h-full flex flex-col" dir={dir}>
        {renderTopBar(
          /* Right: Back button */
          <Button variant="ghost" onClick={() => setViewMode('list')} className="gap-2 text-orange-700 hover:text-orange-900 hover:bg-orange-50">
            <ArrowRight className="h-4 w-4" />
            {t('back')}
          </Button>,

          /* Center: Navigation arrows */
          <>
            <Button
              variant="outline"
              size="icon"
              className="h-8 w-8 border-orange-200 hover:bg-orange-50"
              onClick={() => navigateInvoice('prev')}
              disabled={currentInvoiceIndex <= 0}
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
            <span className="text-sm font-medium text-muted-foreground min-w-[80px] text-center">
              {currentInvoiceIndex + 1} / {invoices.length}
            </span>
            <Button
              variant="outline"
              size="icon"
              className="h-8 w-8 border-orange-200 hover:bg-orange-50"
              onClick={() => navigateInvoice('next')}
              disabled={currentInvoiceIndex >= invoices.length - 1}
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
          </>,

          /* Left: Actions */
          <>
            {remaining > 0 && (
              <Button
                className="gap-2 bg-amber-600 hover:bg-amber-700"
                onClick={() => openPayRemaining(invoice)}
              >
                <Banknote className="h-4 w-4" />
                {t('sales_pay_remaining')}
              </Button>
            )}
            <Button
              className="gap-2 bg-sky-600 hover:bg-sky-700"
              onClick={() => openNewFromCurrent(invoice)}
            >
              <Plus className="h-4 w-4" />
              {t('purchase_new_from_this')}
            </Button>
            <Button
              className="gap-2 bg-orange-600 hover:bg-orange-700"
              onClick={openCreate}
            >
              <Plus className="h-4 w-4" />
              {t('purchase_new')}
            </Button>
            <Button
              variant="outline"
              className="gap-2 border-orange-200 hover:bg-orange-50 text-orange-700"
              onClick={() => window.print()}
            >
              <Printer className="h-4 w-4" />
              {t('print')}
            </Button>
          </>
        )}

        {/* ─── Invoice content ─────────────────────────────── */}
        <div className="flex-1 overflow-y-auto p-6 lg:p-8">
          <div className="print-area max-w-7xl mx-auto bg-white border rounded-xl shadow-sm p-6 lg:p-8 space-y-6">
            {/* Header */}
            <div className="flex justify-between items-start">
              <div className="flex items-center gap-4">
                <div className="h-20 w-20 rounded-xl bg-orange-100 flex items-center justify-center">
                  {business?.logoUrl ? (
                    <img src={business.logoUrl} alt="Logo" className="h-20 w-20 rounded-xl object-cover" />
                  ) : (
                    <Store className="h-10 w-10 text-orange-600" />
                  )}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-xl font-bold">{business?.name || t('the_shop')}</h2>
                    <Button variant="ghost" size="icon" className="no-print h-6 w-6 text-orange-500 hover:text-orange-700 hover:bg-orange-50" onClick={openEditShopDialog}>
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
                <p className="text-2xl font-bold text-orange-700">{t('purchase_invoice_label')}</p>
                <p className="text-sm text-muted-foreground">{invoice.invoiceNumber}</p>
                <p className="text-sm text-muted-foreground">{new Date(invoice.createdAt).toLocaleDateString(locale)}</p>
              </div>
            </div>

            <Separator />

            {/* Supplier info */}
            <div className="bg-gray-50 rounded-lg p-4">
              <p className="text-sm font-medium text-muted-foreground mb-1">{t('purchase_supplier')}</p>
              <p className="font-bold">{invoice.supplierName || '—'}</p>
              {invoice.supplierPhone && (
                <p className="text-sm text-muted-foreground">{invoice.supplierPhone}</p>
              )}
            </div>

            {/* Items table */}
            <Table>
              <TableHeader>
                <TableRow className="bg-gray-50">
                  <TableHead className="text-right font-bold w-10 no-print">#</TableHead>
                  <TableHead className="text-right font-bold min-w-[200px]">{t('sales_item_name')}</TableHead>
                  <TableHead className="text-right font-bold w-12">{t('sales_quantity')}</TableHead>
                  <TableHead className="text-right font-bold w-16">{t('sales_unit_price')}</TableHead>
                  <TableHead className="text-right font-bold w-16">{t('sales_discount')}</TableHead>
                  <TableHead className="text-right font-bold">{t('sales_grand_total')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {invoice.items?.map((item, idx) => (
                  <TableRow key={item.id}>
                    <TableCell className="text-center text-sm no-print">
                      {item.productId ? (
                        <button
                          onClick={() => router.push(`/shop/products?open=${item.productId}`)}
                          className="text-blue-600 hover:text-blue-800 hover:underline cursor-pointer font-medium"
                          title={t('open_product_card')}
                        >
                          {idx + 1}
                        </button>
                      ) : (
                        <span className="text-muted-foreground">{idx + 1}</span>
                      )}
                    </TableCell>
                    <TableCell className="font-semibold text-sm">
                      {item.productId ? (
                        <button
                          onClick={() => router.push(`/shop/products?open=${item.productId}`)}
                          className="text-orange-700 hover:text-orange-900 hover:underline cursor-pointer"
                          title={t('open_product_card')}
                        >
                          {item.description || item.product?.name || '—'}
                        </button>
                      ) : (
                        <span>{item.description || item.product?.name || '—'}</span>
                      )}
                    </TableCell>
                    <TableCell className="text-center">{item.quantity}</TableCell>
                    <TableCell className="text-center">{item.unitPrice.toLocaleString(locale)}</TableCell>
                    <TableCell className="text-center">{item.discountAmount.toLocaleString(locale)}</TableCell>
                    <TableCell className="font-bold">{item.total.toLocaleString(locale)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>

            {/* Totals */}
            <div className="flex justify-end">
              <div className="w-80 space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">{t('sales_subtotal')}</span>
                  <span>{invoice.subtotal.toLocaleString(locale)} {t('currency')}</span>
                </div>
                {invoice.discountAmount > 0 && (
                  <div className="flex justify-between text-sm text-red-600">
                    <span>{t('sales_discount')}</span>
                    <span>- {invoice.discountAmount.toLocaleString(locale)} {t('currency')}</span>
                  </div>
                )}
                {invoice.taxAmount > 0 && (
                  <div className="flex justify-between text-sm">
                    <span>{t('tax')}</span>
                    <span>{invoice.taxAmount.toLocaleString(locale)} {t('currency')}</span>
                  </div>
                )}
                <Separator />
                <div className="flex justify-between font-bold text-lg">
                  <span>{t('sales_grand_total')}</span>
                  <span className="text-orange-700">{invoice.total.toLocaleString(locale)} {t('currency')}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">{t('sales_paid')}</span>
                  <span className="text-emerald-600">{invoice.paidAmount.toLocaleString(locale)} {t('currency')}</span>
                </div>
                {remaining > 0 && (
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">{t('sales_remaining')}</span>
                    <span className="text-red-600">{remaining.toLocaleString(locale)} {t('currency')}</span>
                  </div>
                )}
              </div>
            </div>

            {/* Status */}
            <div className="flex items-center gap-2">
              <span className="text-sm text-muted-foreground">{t('invoice_status')}:</span>
              <Badge variant="secondary" className={`text-xs ${(statusMap[invoice.status] || statusMap.draft).color}`}>
                {(statusMap[invoice.status] || statusMap.draft).label}
              </Badge>
            </div>

            <Separator />

            {/* Footer */}
            <div className="text-center space-y-2 text-xs text-muted-foreground">
              {invoice.notes && (
                <p className="text-sm"><strong>{t('notes')}:</strong> {invoice.notes}</p>
              )}
              <p className="font-medium text-gray-600">
                {t('purchase_invoice_footer')}
              </p>
            </div>
          </div>
        </div>

        {/* Payment Dialog */}
        <PaymentDialog
          open={paymentDialogOpen}
          onOpenChange={setPaymentDialogOpen}
          grandTotal={grandTotal}
          onSave={handlePaymentSave}
          saving={saving}
        />

        {/* Pay Remaining Dialog */}
        <PaymentDialog
          open={payRemainingDialogOpen}
          onOpenChange={setPayRemainingDialogOpen}
          grandTotal={payRemainingInvoice ? payRemainingInvoice.total - payRemainingInvoice.paidAmount : 0}
          initialPaidAmount={payRemainingInvoice ? payRemainingInvoice.total - payRemainingInvoice.paidAmount : 0}
          onSave={handlePayRemainingSave}
          saving={payRemainingSaving}
          isRemainingPayment
        />

        {/* Delete Confirmation */}
        <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
          <AlertDialogContent dir={dir}>
            <AlertDialogHeader>
              <AlertDialogTitle>{t('invoice_delete_title')}</AlertDialogTitle>
              <AlertDialogDescription>
                {t('invoice_delete_confirm')}
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
        <Dialog open={editShopDialogOpen} onOpenChange={setEditShopDialogOpen}>
          <DialogContent className="max-w-md" dir={dir}>
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2">
                <Store className="h-5 w-5 text-orange-600" />
                {t('edit_shop_info')}
              </DialogTitle>
              <DialogDescription>
                {t('edit_shop_desc')}
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4">
              <div className="space-y-2">
                <Label>{t('shop_logo')}</Label>
                <div className="flex items-center gap-4">
                  <div className="h-16 w-16 rounded-xl bg-orange-100 flex items-center justify-center overflow-hidden">
                    {editShopForm.logoUrl ? (
                      <img src={editShopForm.logoUrl} alt="Logo preview" className="h-16 w-16 rounded-xl object-cover" />
                    ) : (
                      <Store className="h-8 w-8 text-orange-600" />
                    )}
                  </div>
                  <div className="flex flex-col gap-1">
                    <input
                      ref={editLogoInputRef}
                      type="file"
                      accept="image/jpeg,image/png,image/webp"
                      className="hidden"
                      onChange={handleLogoUpload}
                    />
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      className="gap-1 text-orange-600 border-orange-200 hover:bg-orange-50"
                      onClick={() => editLogoInputRef.current?.click()}
                    >
                      <ImagePlus className="h-3.5 w-3.5" />
                      رفع لوجو
                    </Button>
                    {editShopForm.logoUrl && (
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="text-red-500 hover:text-red-700 hover:bg-red-50 h-7 text-xs"
                        onClick={() => setEditShopForm({ ...editShopForm, logoUrl: '' })}
                      >
                        إزالة اللوجو
                      </Button>
                    )}
                  </div>
                </div>
                <p className="text-xs text-muted-foreground">الحد الأقصى 500 كيلوبايت • JPG, PNG, WebP</p>
              </div>
              <div className="space-y-2">
                <Label>{t('shop_name')}</Label>
                <Input value={editShopForm.name} onChange={(e) => setEditShopForm({ ...editShopForm, name: e.target.value })} placeholder="اسم المحل" />
              </div>
              <div className="space-y-2">
                <Label>رقم الهاتف</Label>
                <Input value={editShopForm.phone} onChange={(e) => setEditShopForm({ ...editShopForm, phone: e.target.value })} placeholder="رقم الهاتف" />
              </div>
              <div className="space-y-2">
                <Label>{t('address')}</Label>
                <Input value={editShopForm.address} onChange={(e) => setEditShopForm({ ...editShopForm, address: e.target.value })} placeholder="العنوان" />
              </div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setEditShopDialogOpen(false)} disabled={editShopSaving}>{t('cancel')}</Button>
              <Button onClick={handleEditShopSave} className="bg-orange-600 hover:bg-orange-700 min-w-[100px]" disabled={editShopSaving}>
                {editShopSaving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
                حفظ
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    )
  }

  // ─── Render: CREATE MODE (content area, not overlay) ────

  if (viewMode === 'create') {
    return (
      <div className="h-full flex flex-col" dir={dir}>
        {renderTopBar(
          /* Right: Back button */
          <Button variant="ghost" onClick={() => setViewMode('list')} className="gap-2 text-orange-700 hover:text-orange-900 hover:bg-orange-50">
            <ArrowRight className="h-4 w-4" />
            رجوع للقائمة
          </Button>,

          /* Center: Title */
          <h2 className="text-lg font-bold flex items-center gap-2">
            <Receipt className="h-5 w-5 text-orange-600" />
            فاتورة شراء جديدة
          </h2>,

          /* Left: Save button */
          <Button
            onClick={handleSaveClick}
            className="gap-2 bg-orange-600 hover:bg-orange-700 min-w-[120px]"
          >
            <Banknote className="h-4 w-4" />
            حفظ والدفع
          </Button>
        )}

        {/* ─── Form content ────────────────────────────────── */}
        <div className="flex-1 overflow-y-auto p-4 lg:p-6 space-y-4">
          {/* ─── Invoice Header (Shop Info + Invoice Number) ──── */}
          <div className="flex justify-between items-start bg-white rounded-xl border shadow-sm p-5">
            <div className="flex items-center gap-4">
              <div className="h-16 w-16 rounded-xl bg-orange-100 flex items-center justify-center">
                {business?.logoUrl ? (
                  <img src={business.logoUrl} alt="Logo" className="h-16 w-16 rounded-xl object-cover" />
                ) : (
                  <Store className="h-8 w-8 text-orange-600" />
                )}
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h3 className="font-bold text-lg">{business?.name || t('the_shop')}</h3>
                  <Button variant="ghost" size="icon" className="h-6 w-6 text-orange-500 hover:text-orange-700 hover:bg-orange-50" onClick={openEditShopDialog}>
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
            <div className="text-left space-y-1">
              <p className="text-lg font-semibold text-orange-700">فاتورة شراء</p>
              <p className="text-sm text-muted-foreground">
                {new Date().toLocaleDateString('ar-KW')}
              </p>
              <p className="text-sm text-muted-foreground">
                رقم الفرع: {businessId?.slice(0, 4) || '—'}
              </p>
            </div>
          </div>

          {/* ─── Supplier Section ───────────────────────────────── */}
          <div className="bg-white rounded-xl border shadow-sm p-5 space-y-3">
            <Label className="text-base font-semibold">بيانات المورد</Label>
            <div className="relative" ref={supplierSearchRef}>
              <div className="flex gap-2">
                <div className="flex-1 relative">
                  <Search className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    className="pr-9 h-12 text-sm"
                    placeholder="ابحث عن مورد بالاسم أو رقم الهاتف..."
                    value={form.supplierName || supplierSearch}
                    onChange={(e) => {
                      setSupplierSearch(e.target.value)
                      setForm({ ...form, supplierId: '', supplierName: '', supplierPhone: '' })
                      setSupplierDropdownOpen(true)
                    }}
                    onFocus={() => {
                      if (!form.supplierId) setSupplierDropdownOpen(true)
                    }}
                  />
                </div>
                {form.supplierId && (
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-12 w-12 shrink-0"
                    onClick={clearSupplier}
                  >
                    <X className="h-4 w-4" />
                  </Button>
                )}
              </div>

              {/* Supplier dropdown */}
              {supplierDropdownOpen && !form.supplierId && filteredSuppliers.length > 0 && (
                <div className="absolute z-50 top-full mt-1 w-full bg-white border rounded-lg shadow-lg max-h-48 overflow-y-auto">
                  {filteredSuppliers.slice(0, 8).map((supplier) => (
                    <button
                      key={supplier.id}
                      className="w-full text-right px-3 py-2 hover:bg-orange-50 flex justify-between items-center border-b last:border-0"
                      onClick={() => selectSupplier(supplier)}
                    >
                      <span className="font-medium text-sm">{supplier.name}</span>
                      <span className="text-xs text-muted-foreground">
                        {supplier.phone || ''}
                      </span>
                    </button>
                  ))}
                </div>
              )}
            </div>

            {/* Selected supplier details */}
            {form.supplierId && (
              <div className="bg-orange-50 border border-orange-200 rounded-lg p-3 flex items-center justify-between">
                <div>
                  <p className="font-medium text-sm">{form.supplierName}</p>
                  {form.supplierPhone && (
                    <p className="text-xs text-muted-foreground flex items-center gap-1">
                      <Phone className="h-3 w-3" /> {form.supplierPhone}
                    </p>
                  )}
                  {suppliers.find((s) => String(s.id) === form.supplierId)?.address && (
                    <p className="text-xs text-muted-foreground flex items-center gap-1">
                      <MapPin className="h-3 w-3" />{' '}
                      {suppliers.find((s) => String(s.id) === form.supplierId)?.address}
                    </p>
                  )}
                </div>
                <Badge variant="secondary" className="bg-orange-100 text-orange-700 text-xs">
                  رصيد: {suppliers.find((s) => String(s.id) === form.supplierId)?.balance?.toLocaleString(locale) || 0} {t('currency')}
                </Badge>
              </div>
            )}

            {/* Manual supplier fields if not selected */}
            {!form.supplierId && form.supplierName === '' && (
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <Label className="text-xs">اسم المورد (يدوي)</Label>
                  <Input
                    className="h-12 text-sm"
                    placeholder="اسم المورد"
                    value={form.supplierName}
                    onChange={(e) => setForm({ ...form, supplierName: e.target.value })}
                  />
                </div>
                <div className="space-y-1">
                  <Label className="text-xs">رقم الهاتف</Label>
                  <Input
                    className="h-12 text-sm"
                    placeholder={t('phone_number')}
                    value={form.supplierPhone}
                    onChange={(e) => setForm({ ...form, supplierPhone: e.target.value })}
                  />
                </div>
              </div>
            )}
          </div>

          {/* ─── Invoice Items Table ──────────────────────────── */}
          <div className="bg-white rounded-xl border shadow-sm p-5 space-y-3">
            <div className="flex items-center justify-between">
              <Label className="text-base font-semibold">بنود الفاتورة</Label>
              <Button
                variant="outline"
                size="sm"
                onClick={addLineItem}
                className="gap-1 text-orange-600 border-orange-200 hover:bg-orange-50"
              >
                <Plus className="h-3.5 w-3.5" /> {t('purchase_add_item')}
              </Button>
            </div>

            {/* ─── Spreadsheet-style items grid ──────────────── */}
            <div className="border-2 border-gray-300 rounded-lg overflow-hidden">
              {/* Header row */}
              <div className="grid grid-cols-[50px_1fr_70px_100px_100px_130px_40px] bg-gray-100 border-b-2 border-gray-300">
                <div className="no-print px-2 py-3 text-center text-sm font-bold border-l-2 border-gray-300">#</div>
                <div className="px-2 py-3 text-center text-sm font-bold border-l-2 border-gray-300">اسم المادة</div>
                <div className="px-2 py-3 text-center text-sm font-bold border-l-2 border-gray-300">العدد</div>
                <div className="px-2 py-3 text-center text-sm font-bold border-l-2 border-gray-300">السعر</div>
                <div className="px-2 py-3 text-center text-sm font-bold border-l-2 border-gray-300">الخصم</div>
                <div className="px-2 py-3 text-center text-sm font-bold border-l-2 border-gray-300">الإجمالي</div>
                <div className="px-2 py-3 text-center text-sm font-bold"></div>
              </div>

              {/* Data rows */}
              {lineItems.map((item, index) => (
                <div
                  key={index}
                  className="grid grid-cols-[50px_1fr_70px_100px_100px_130px_40px] border-b border-gray-200 last:border-b-0 group hover:bg-orange-50/30"
                >
                  {/* Row Number */}
                  <div className="no-print border-l-2 border-gray-300 flex items-center justify-center">
                    {item.productId ? (
                      <button
                        onClick={() => router.push(`/shop/products?edit=${item.productId}`)}
                        className="text-blue-600 hover:text-blue-800 hover:underline cursor-pointer font-medium text-sm"
                        title={t('open_product_card')}
                      >
                        {index + 1}
                      </button>
                    ) : (
                      <span className="text-sm text-muted-foreground">{index + 1}</span>
                    )}
                  </div>

                  {/* Product Name / Search */}
                  <div className="border-l-2 border-gray-300 relative">
                    <div ref={productSearchIndex === index ? productSearchRef : undefined}>
                      <Input
                        id={`item-${index}-description`}
                        className="h-12 text-sm border-0 rounded-none focus-visible:ring-0 focus-visible:ring-offset-0 bg-transparent px-2"
                        value={item.description}
                        onChange={(e) => {
                          updateLineItem(index, 'description', e.target.value)
                          setProductSearchIndex(index)
                          setProductSearchTerm(e.target.value)
                          setHighlightedProductIdx(-1)
                        }}
                        onFocus={() => {
                          setProductSearchIndex(index)
                          setProductSearchTerm(item.description || '')
                        }}
                        onKeyDown={(e) => {
                          const prods = filteredProducts.slice(0, 8)
                          if (e.key === 'ArrowDown') {
                            e.preventDefault()
                            setHighlightedProductIdx(prev =>
                              prev < prods.length - 1 ? prev + 1 : 0
                            )
                          } else if (e.key === 'ArrowUp') {
                            e.preventDefault()
                            setHighlightedProductIdx(prev =>
                              prev > 0 ? prev - 1 : prods.length - 1
                            )
                          } else if (e.key === 'Enter' && highlightedProductIdx >= 0 && highlightedProductIdx < prods.length) {
                            e.preventDefault()
                            selectProduct(prods[highlightedProductIdx], index)
                          } else if (e.key === 'Enter') {
                            handleItemKeyDown(e, index, 'description')
                          } else if (e.key === 'Escape') {
                            setProductSearchIndex(null)
                            setProductSearchTerm('')
                            setHighlightedProductIdx(-1)
                          }
                        }}
                        placeholder="اسم المادة..."
                      />
                      {productSearchIndex === index &&
                        productSearchTerm &&
                        filteredProducts.length > 0 && (
                          <div className="absolute z-50 top-full left-0 right-0 bg-white border-2 border-orange-300 rounded-b-lg shadow-xl max-h-56 overflow-y-auto">
                            {filteredProducts.slice(0, 8).map((product, pIdx) => (
                              <button
                                key={product.id}
                                className={`w-full text-right px-3 py-2.5 flex justify-between items-center border-b last:border-0 transition-colors ${
                                  highlightedProductIdx === pIdx
                                    ? 'bg-orange-100 border-orange-200'
                                    : 'hover:bg-orange-50'
                                }`}
                                onClick={() => selectProduct(product, index)}
                                onMouseEnter={() => setHighlightedProductIdx(pIdx)}
                              >
                                <div className="flex flex-col">
                                  <span className="text-sm font-medium">{product.name}</span>
                                  <span className="text-xs text-muted-foreground flex items-center gap-1">
                                    <PackageCheck className="h-3 w-3" />
                                    المخزون: {product.stockQuantity}
                                  </span>
                                </div>
                                <span className="text-xs font-medium text-orange-700">
                                  {product.costPrice.toLocaleString(locale)} {t('currency')}
                                </span>
                              </button>
                            ))}
                          </div>
                        )}
                    </div>
                  </div>

                  {/* Quantity */}
                  <div className="border-l-2 border-gray-300">
                    <Input
                      id={`item-${index}-quantity`}
                      className="h-12 text-sm text-center border-0 rounded-none focus-visible:ring-0 focus-visible:ring-offset-0 bg-transparent px-1 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                      type="text"
                      inputMode="decimal"
                      value={item.quantity}
                      onChange={(e) =>
                        updateLineItem(index, 'quantity', e.target.value)
                      }
                      onKeyDown={(e) => handleItemKeyDown(e, index, 'quantity')}
                      placeholder="1"
                    />
                  </div>

                  {/* Unit Price */}
                  <div className="border-l-2 border-gray-300">
                    <Input
                      id={`item-${index}-unitPrice`}
                      className="h-12 text-sm text-center border-0 rounded-none focus-visible:ring-0 focus-visible:ring-offset-0 bg-transparent px-1 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                      type="text"
                      inputMode="decimal"
                      value={item.unitPrice}
                      onChange={(e) =>
                        updateLineItem(index, 'unitPrice', e.target.value)
                      }
                      onKeyDown={(e) => handleItemKeyDown(e, index, 'unitPrice')}
                      placeholder="0.000"
                    />
                  </div>

                  {/* Discount */}
                  <div className="border-l-2 border-gray-300">
                    <Input
                      id={`item-${index}-discount`}
                      className="h-12 text-sm text-center border-0 rounded-none focus-visible:ring-0 focus-visible:ring-offset-0 bg-transparent px-1 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                      type="text"
                      inputMode="decimal"
                      value={item.discount}
                      onChange={(e) =>
                        updateLineItem(index, 'discount', e.target.value)
                      }
                      onKeyDown={(e) => handleItemKeyDown(e, index, 'discount')}
                      placeholder="0"
                    />
                  </div>

                  {/* Row Total (read-only, auto-calculated) */}
                  <div className="border-l-2 border-gray-300">
                    <Input
                      className="h-12 text-sm text-center font-bold text-orange-700 border-0 rounded-none focus-visible:ring-0 focus-visible:ring-offset-0 bg-gray-50 px-1"
                      value={item.total > 0 ? item.total.toLocaleString(locale) : '0'}
                      readOnly
                      tabIndex={-1}
                    />
                  </div>

                  {/* Delete */}
                  <div className="flex items-center justify-center">
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-8 w-8 p-0 text-red-400 hover:text-red-600 opacity-0 group-hover:opacity-100 transition-opacity"
                      onClick={() => removeLineItem(index)}
                      disabled={lineItems.length <= 1}
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </Button>
                  </div>
                </div>
              ))}
            </div>

            {/* Totals */}
            <div className="flex justify-end">
              <div className="w-80 space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">{t('sales_subtotal')}</span>
                  <span>{subtotal.toLocaleString(locale)} {t('currency')}</span>
                </div>
                {totalDiscount > 0 && (
                  <div className="flex justify-between text-sm text-red-600">
                    <span>إجمالي الخصم</span>
                    <span>- {totalDiscount.toLocaleString(locale)} {t('currency')}</span>
                  </div>
                )}
                <Separator />
                <div className="flex justify-between font-bold text-lg">
                  <span>{t('sales_grand_total')}</span>
                  <span className="text-orange-700">
                    {grandTotal.toLocaleString(locale)} {t('currency')}
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* ─── Invoice Footer ───────────────────────────────── */}
          <div className="bg-white rounded-xl border shadow-sm p-5 space-y-3">
            <Label className="text-base font-semibold flex items-center gap-1">
              <StickyNote className="h-4 w-4" />
              ملاحظات وإضافات
            </Label>
            <Textarea
              className="text-sm"
              placeholder="ملاحظات الفاتورة..."
              value={form.notes}
              onChange={(e) => setForm({ ...form, notes: e.target.value })}
              rows={2}
            />
            <div className="bg-gray-50 border rounded-lg p-3 text-center space-y-1">
              <p className="text-xs font-medium text-gray-600">
                {t('purchase_invoice_footer')}
              </p>
            </div>
          </div>

          {/* ─── Action Buttons ────────────────────────────────── */}
          <div className="flex justify-end gap-3 pt-4 pb-8 border-t">
            <Button variant="outline" onClick={() => setViewMode('list')} className="min-w-[100px]">
              {t('cancel')}
            </Button>
            <Button
              onClick={handleSaveClick}
              className="bg-orange-600 hover:bg-orange-700 min-w-[160px]"
            >
              <Banknote className="h-4 w-4 ml-2" />
              حفظ والدفع
            </Button>
          </div>
        </div>

        {/* Payment Dialog */}
        <PaymentDialog
          open={paymentDialogOpen}
          onOpenChange={setPaymentDialogOpen}
          grandTotal={grandTotal}
          onSave={handlePaymentSave}
          saving={saving}
        />

        {/* Pay Remaining Dialog */}
        <PaymentDialog
          open={payRemainingDialogOpen}
          onOpenChange={setPayRemainingDialogOpen}
          grandTotal={payRemainingInvoice ? payRemainingInvoice.total - payRemainingInvoice.paidAmount : 0}
          initialPaidAmount={payRemainingInvoice ? payRemainingInvoice.total - payRemainingInvoice.paidAmount : 0}
          onSave={handlePayRemainingSave}
          saving={payRemainingSaving}
          isRemainingPayment
        />

        {/* Delete Confirmation */}
        <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
          <AlertDialogContent dir={dir}>
            <AlertDialogHeader>
              <AlertDialogTitle>{t('invoice_delete_title')}</AlertDialogTitle>
              <AlertDialogDescription>
                {t('invoice_delete_confirm')}
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
        <Dialog open={editShopDialogOpen} onOpenChange={setEditShopDialogOpen}>
          <DialogContent className="max-w-md" dir={dir}>
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2">
                <Store className="h-5 w-5 text-orange-600" />
                {t('edit_shop_info')}
              </DialogTitle>
              <DialogDescription>
                {t('edit_shop_desc')}
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4">
              <div className="space-y-2">
                <Label>{t('shop_logo')}</Label>
                <div className="flex items-center gap-4">
                  <div className="h-16 w-16 rounded-xl bg-orange-100 flex items-center justify-center overflow-hidden">
                    {editShopForm.logoUrl ? (
                      <img src={editShopForm.logoUrl} alt="Logo preview" className="h-16 w-16 rounded-xl object-cover" />
                    ) : (
                      <Store className="h-8 w-8 text-orange-600" />
                    )}
                  </div>
                  <div className="flex flex-col gap-1">
                    <input
                      ref={editLogoInputRef}
                      type="file"
                      accept="image/jpeg,image/png,image/webp"
                      className="hidden"
                      onChange={handleLogoUpload}
                    />
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      className="gap-1 text-orange-600 border-orange-200 hover:bg-orange-50"
                      onClick={() => editLogoInputRef.current?.click()}
                    >
                      <ImagePlus className="h-3.5 w-3.5" />
                      رفع لوجو
                    </Button>
                    {editShopForm.logoUrl && (
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="text-red-500 hover:text-red-700 hover:bg-red-50 h-7 text-xs"
                        onClick={() => setEditShopForm({ ...editShopForm, logoUrl: '' })}
                      >
                        إزالة اللوجو
                      </Button>
                    )}
                  </div>
                </div>
                <p className="text-xs text-muted-foreground">الحد الأقصى 500 كيلوبايت • JPG, PNG, WebP</p>
              </div>
              <div className="space-y-2">
                <Label>{t('shop_name')}</Label>
                <Input value={editShopForm.name} onChange={(e) => setEditShopForm({ ...editShopForm, name: e.target.value })} placeholder="اسم المحل" />
              </div>
              <div className="space-y-2">
                <Label>رقم الهاتف</Label>
                <Input value={editShopForm.phone} onChange={(e) => setEditShopForm({ ...editShopForm, phone: e.target.value })} placeholder="رقم الهاتف" />
              </div>
              <div className="space-y-2">
                <Label>{t('address')}</Label>
                <Input value={editShopForm.address} onChange={(e) => setEditShopForm({ ...editShopForm, address: e.target.value })} placeholder="العنوان" />
              </div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setEditShopDialogOpen(false)} disabled={editShopSaving}>{t('cancel')}</Button>
              <Button onClick={handleEditShopSave} className="bg-orange-600 hover:bg-orange-700 min-w-[100px]" disabled={editShopSaving}>
                {editShopSaving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
                حفظ
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    )
  }

  // ─── Render: LIST MODE (default) ──────────────────────────

  return (
    <div className="space-y-6" dir="rtl">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">فواتير الشراء</h2>
          <p className="text-muted-foreground">إدارة فواتير المشتريات</p>
        </div>
        <div className="flex items-center gap-3">
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-36">
              <Filter className="ml-2 h-4 w-4" />
              <SelectValue placeholder="الحالة" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">الكل</SelectItem>
              <SelectItem value="draft">مسودة</SelectItem>
              <SelectItem value="unpaid">غير مدفوعة</SelectItem>
              <SelectItem value="partial">مدفوعة جزئياً</SelectItem>
              <SelectItem value="paid">مدفوعة</SelectItem>
            </SelectContent>
          </Select>
          <Button onClick={openCreate} className="gap-2 bg-orange-600 hover:bg-orange-700">
            <Plus className="h-4 w-4" />
            فاتورة شراء جديدة
          </Button>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-orange-100">
              <Receipt className="h-6 w-6 text-orange-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">إجمالي المشتريات</p>
              <p className="text-2xl font-bold text-orange-700">
                {totalPurchases.toLocaleString(locale)}{' '}
                <span className="text-sm font-normal">{t('currency')}</span>
              </p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-violet-100">
              <ShoppingCart className="h-6 w-6 text-violet-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">عدد الفواتير</p>
              <p className="text-2xl font-bold">{invoices.length}</p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Invoice Navigation */}
      {invoices.length > 0 && (
        <Card>
          <CardContent className="p-3">
            <div className="flex items-center justify-center gap-4">
              <Button
                variant="outline"
                size="icon"
                className="h-8 w-8"
                onClick={() => navigateInvoice('next')}
                disabled={currentInvoiceIndex >= invoices.length - 1}
              >
                <ChevronRight className="h-4 w-4" />
              </Button>
              <span className="text-sm text-muted-foreground">
                {currentInvoiceIndex + 1} / {invoices.length}
              </span>
              <Button
                variant="outline"
                size="icon"
                className="h-8 w-8"
                onClick={() => navigateInvoice('prev')}
                disabled={currentInvoiceIndex <= 0}
              >
                <ChevronLeft className="h-4 w-4" />
              </Button>
              <Button
                variant="outline"
                size="sm"
                className="gap-1 mr-2"
                onClick={() => openViewForInvoice(invoices[currentInvoiceIndex])}
              >
                <Eye className="h-3.5 w-3.5" />
                عرض {invoices[currentInvoiceIndex]?.invoiceNumber}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Invoices Table */}
      <Card>
        <CardContent className="p-0">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-orange-600" />
            </div>
          ) : filteredInvoices.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <Receipt className="h-12 w-12 mb-3 opacity-30" />
              <p>لا توجد فواتير مشتريات</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-right">رقم الفاتورة</TableHead>
                    <TableHead className="text-right">المورد</TableHead>
                    <TableHead className="text-right">الإجمالي</TableHead>
                    <TableHead className="text-right">المدفوع</TableHead>
                    <TableHead className="text-right">الحالة</TableHead>
                    <TableHead className="text-right">التاريخ</TableHead>
                    <TableHead className="text-right">إجراءات</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredInvoices.map((inv) => {
                    const invRemaining = inv.total - inv.paidAmount
                    return (
                      <TableRow key={inv.id} className="cursor-pointer hover:bg-orange-50/50" onClick={() => openViewForInvoice(inv)}>
                        <TableCell className="font-medium">{inv.invoiceNumber}</TableCell>
                        <TableCell>{inv.supplierName || '—'}</TableCell>
                        <TableCell className="font-medium">
                          {inv.total.toLocaleString(locale)} {t('currency')}
                        </TableCell>
                        <TableCell>{inv.paidAmount.toLocaleString(locale)} {t('currency')}</TableCell>
                        <TableCell>
                          <Badge
                            variant="secondary"
                            className={`text-xs ${(statusMap[inv.status] || statusMap.draft).color}`}
                          >
                            {(statusMap[inv.status] || statusMap.draft).label}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-xs text-muted-foreground">
                          {new Date(inv.createdAt).toLocaleDateString('ar-KW')}
                        </TableCell>
                        <TableCell>
                          <div className="flex gap-1" onClick={(e) => e.stopPropagation()}>
                            <Button
                              variant="ghost"
                              size="sm"
                              className="h-7 w-7 p-0"
                              onClick={() => openViewForInvoice(inv)}
                            >
                              <Eye className="h-3.5 w-3.5" />
                            </Button>
                            {(inv.status === 'unpaid' || (inv.status === 'partial' && invRemaining > 0)) && (
                              <Button
                                variant="ghost"
                                size="sm"
                                className="h-7 px-2 text-orange-600 hover:text-orange-800 hover:bg-orange-50 gap-1"
                                onClick={() => openPayRemaining(inv)}
                                title="سداد المتبقي"
                              >
                                <DollarSign className="h-3.5 w-3.5" />
                                <span className="text-xs">سداد</span>
                              </Button>
                            )}
                            <Button
                              variant="ghost"
                              size="sm"
                              className="h-7 w-7 p-0 text-red-600"
                              onClick={() => confirmDelete(inv.id)}
                            >
                              <Trash2 className="h-3.5 w-3.5" />
                            </Button>
                          </div>
                        </TableCell>
                      </TableRow>
                    )
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Payment Dialog (for new invoices) */}
      <PaymentDialog
        open={paymentDialogOpen}
        onOpenChange={setPaymentDialogOpen}
        grandTotal={grandTotal}
        onSave={handlePaymentSave}
        saving={saving}
      />

      {/* Pay Remaining Dialog */}
      <PaymentDialog
        open={payRemainingDialogOpen}
        onOpenChange={setPayRemainingDialogOpen}
        grandTotal={payRemainingInvoice ? payRemainingInvoice.total - payRemainingInvoice.paidAmount : 0}
        initialPaidAmount={payRemainingInvoice ? payRemainingInvoice.total - payRemainingInvoice.paidAmount : 0}
        onSave={handlePayRemainingSave}
        saving={payRemainingSaving}
        isRemainingPayment
      />

      {/* Delete Confirmation */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent dir="rtl">
          <AlertDialogHeader>
            <AlertDialogTitle>{t('purchase_delete_invoice_title')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('purchase_delete_confirm_msg')}
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
      <Dialog open={editShopDialogOpen} onOpenChange={setEditShopDialogOpen}>
        <DialogContent className="max-w-md" dir="rtl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Store className="h-5 w-5 text-orange-600" />
              تعديل بيانات المحل
            </DialogTitle>
            <DialogDescription>
              تعديل اسم المحل، الهاتف، العنوان، واللوجو
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            {/* Logo upload */}
            <div className="space-y-2">
              <Label>لوجو المحل</Label>
              <div className="flex items-center gap-4">
                <div className="h-16 w-16 rounded-xl bg-orange-100 flex items-center justify-center overflow-hidden">
                  {editShopForm.logoUrl ? (
                    <img src={editShopForm.logoUrl} alt="Logo preview" className="h-16 w-16 rounded-xl object-cover" />
                  ) : (
                    <Store className="h-8 w-8 text-orange-600" />
                  )}
                </div>
                <div className="flex flex-col gap-1">
                  <input
                    ref={editLogoInputRef}
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    className="hidden"
                    onChange={handleLogoUpload}
                  />
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    className="gap-1 text-orange-600 border-orange-200 hover:bg-orange-50"
                    onClick={() => editLogoInputRef.current?.click()}
                  >
                    <ImagePlus className="h-3.5 w-3.5" />
                    رفع لوجو
                  </Button>
                  {editShopForm.logoUrl && (
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="text-red-500 hover:text-red-700 hover:bg-red-50 h-7 text-xs"
                      onClick={() => setEditShopForm({ ...editShopForm, logoUrl: '' })}
                    >
                      إزالة اللوجو
                    </Button>
                  )}
                </div>
              </div>
              <p className="text-xs text-muted-foreground">الحد الأقصى 500 كيلوبايت • JPG, PNG, WebP</p>
            </div>

            <div className="space-y-2">
              <Label>اسم المحل</Label>
              <Input
                value={editShopForm.name}
                onChange={(e) => setEditShopForm({ ...editShopForm, name: e.target.value })}
                placeholder="اسم المحل"
              />
            </div>

            <div className="space-y-2">
              <Label>رقم الهاتف</Label>
              <Input
                value={editShopForm.phone}
                onChange={(e) => setEditShopForm({ ...editShopForm, phone: e.target.value })}
                placeholder="رقم الهاتف"
              />
            </div>

            <div className="space-y-2">
              <Label>العنوان</Label>
              <Input
                value={editShopForm.address}
                onChange={(e) => setEditShopForm({ ...editShopForm, address: e.target.value })}
                placeholder="العنوان"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditShopDialogOpen(false)} disabled={editShopSaving}>
              {t('cancel')}
            </Button>
            <Button onClick={handleEditShopSave} className="bg-orange-600 hover:bg-orange-700 min-w-[100px]" disabled={editShopSaving}>
              {editShopSaving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              حفظ
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
