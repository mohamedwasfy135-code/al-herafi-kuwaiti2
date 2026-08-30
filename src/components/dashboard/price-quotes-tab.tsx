'use client'

import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import {
  Plus,
  FileCheck,
  Eye,
  Trash2,
  Loader2,
  Filter,
  ChevronLeft,
  ChevronRight,
  ArrowRight,
  Search,
  Store,
  Phone,
  MapPin,
  X,
  Printer,
  Calendar,
  Pencil,
  ArrowRightLeft,
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

interface PriceQuote {
  id: number
  quoteNumber: string
  clientId: number | null
  clientName: string | null
  clientPhone: string | null
  total: number
  subtotal: number
  discountAmount: number
  taxAmount: number
  status: string
  validUntil: string | null
  notes: string | null
  convertedToInvoiceId: number | null
  convertedToInvoice?: { id: number; invoiceNumber: string } | null
  createdAt: string
  items?: QuoteItem[]
  business?: {
    id: string
    name: string
    phone?: string | null
    address?: string | null
    logoUrl?: string | null
  }
}

interface QuoteItem {
  id: number
  productId: number | null
  description: string | null
  quantity: number
  unitPrice: number
  discountAmount: number
  total: number
  product?: { id: number; name: string; sku?: string | null } | null
}

interface Client {
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

// ─── Helpers ──────────────────────────────────────────────────

const emptyLineItem = (): LineItem => ({
  productCode: '',
  productId: '',
  description: '',
  quantity: '',
  unitPrice: '',
  discount: '',
  total: 0,
})

// ─── Main Component ───────────────────────────────────────────

export function PriceQuotesTab() {
  const { t, lang, dir } = useLanguage()
  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'
  const router = useRouter()
  const [quotes, setQuotes] = useState<PriceQuote[]>([])
  const [clients, setClients] = useState<Client[]>([])
  const [products, setProducts] = useState<Product[]>([])
  const [business, setBusiness] = useState<BusinessProfile | null>(null)
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [viewMode, setViewMode] = useState<'list' | 'create' | 'view'>('list')
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [viewingQuote, setViewingQuote] = useState<PriceQuote | null>(null)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [converting, setConverting] = useState(false)

  // Quote navigation
  const [currentQuoteIndex, setCurrentQuoteIndex] = useState(0)

  // Form state
  const [form, setForm] = useState({
    clientId: '',
    clientName: '',
    clientPhone: '',
    notes: '',
    validUntil: '',
  })

  // Client search
  const [clientSearch, setClientSearch] = useState('')
  const [clientDropdownOpen, setClientDropdownOpen] = useState(false)
  const clientSearchRef = useRef<HTMLDivElement>(null)

  // Product search per line item
  const [productSearchIndex, setProductSearchIndex] = useState<number | null>(null)
  const [productSearchTerm, setProductSearchTerm] = useState('')
  const [highlightedProductIdx, setHighlightedProductIdx] = useState(-1)
  const productSearchRef = useRef<HTMLDivElement>(null)

  // 10 default rows
  const [lineItems, setLineItems] = useState<LineItem[]>(
    Array(10).fill(null).map(() => emptyLineItem())
  )

  const businessId = getBusinessId()

  // Status map with i18n
  const statusMap = useMemo(() => ({
    draft: { label: t('quote_status_draft'), color: 'bg-gray-100 text-gray-700' },
    sent: { label: t('quote_status_sent'), color: 'bg-sky-100 text-sky-700' },
    accepted: { label: t('quote_status_accepted'), color: 'bg-emerald-100 text-emerald-700' },
    declined: { label: t('quote_status_declined'), color: 'bg-red-100 text-red-700' },
    converted: { label: t('quote_status_converted'), color: 'bg-teal-100 text-teal-700' },
  }), [t])

  // ─── Fetch Data ───────────────────────────────────────────

  const fetchData = useCallback(async () => {
    setLoading(true)
    try {
      const [qRes, cliRes, prodRes, bizRes] = await Promise.all([
        fetch(`/api/price-quotes?businessId=${businessId}`),
        fetch(`/api/clients?businessId=${businessId}`),
        fetch(`/api/products?businessId=${businessId}`),
        fetch(`/api/business/profile?businessId=${businessId}`),
      ])
      if (qRes.ok) {
        const data = await qRes.json()
        if (Array.isArray(data) && data.length > 0) setQuotes(data)
      }
      if (cliRes.ok) {
        const data = await cliRes.json()
        if (Array.isArray(data)) setClients(data)
      }
      if (prodRes.ok) {
        const data = await prodRes.json()
        if (Array.isArray(data)) setProducts(data.map((p: Record<string, unknown>) => ({
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

  // ─── Close dropdowns on outside click ─────────────────────

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (clientSearchRef.current && !clientSearchRef.current.contains(e.target as Node)) {
        setClientDropdownOpen(false)
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

  const filteredQuotes =
    statusFilter === 'all'
    ? (quotes || [])
    : (quotes || []).filter((q) => q.status === statusFilter)

  const subtotal = lineItems.reduce((sum, item) => sum + item.total, 0)
  const totalDiscount = lineItems.reduce(
    (sum, item) => sum + (parseFloat(item.discount) || 0),
    0
  )
  const grandTotal = subtotal

  // ─── Client search ────────────────────────────────────────

    const filteredClients = (clients || []).filter((c) =>
    c.name.includes(clientSearch) ||
    (c.phone && c.phone.includes(clientSearch))
  )

  const selectClient = (client: Client) => {
    setForm({
      ...form,
      clientId: String(client.id),
      clientName: client.name,
      clientPhone: client.phone || '',
    })
    setClientSearch('')
    setClientDropdownOpen(false)
  }

  const clearClient = () => {
    setForm({ ...form, clientId: '', clientName: '', clientPhone: '' })
    setClientSearch('')
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

    const filteredProducts = (products || []).filter(
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
      if (currentFieldIndex < fieldOrder.length - 1) {
        const nextField = fieldOrder[currentFieldIndex + 1]
        const el = document.getElementById(`pq-item-${rowIndex}-${nextField}`)
        el?.focus()
      } else if (rowIndex < lineItems.length - 1) {
        const el = document.getElementById(`pq-item-${rowIndex + 1}-description`)
        el?.focus()
      }
    } else if (e.key === 'ArrowDown' && rowIndex < lineItems.length - 1) {
      e.preventDefault()
      const el = document.getElementById(`pq-item-${rowIndex + 1}-${field}`)
      el?.focus()
    } else if (e.key === 'ArrowUp' && rowIndex > 0) {
      e.preventDefault()
      const el = document.getElementById(`pq-item-${rowIndex - 1}-${field}`)
      el?.focus()
    }
  }

  // ─── Quote navigation ───────────────────────────────────

  const navigateQuote = (direction: 'prev' | 'next') => {
    let newIndex = currentQuoteIndex
    if (direction === 'prev' && currentQuoteIndex > 0) {
      newIndex = currentQuoteIndex - 1
    } else if (direction === 'next' && currentQuoteIndex < quotes.length - 1) {
      newIndex = currentQuoteIndex + 1
    }
    setCurrentQuoteIndex(newIndex)
    const q = quotes[newIndex]
    if (q) {
      setViewingQuote(q)
    }
  }

  const openViewForQuote = (q: PriceQuote) => {
    const index = quotes.findIndex((i) => i.id === q.id)
    setCurrentQuoteIndex(index >= 0 ? index : 0)
    setViewingQuote(q)
    setViewMode('view')
  }

  // ─── Create Quote ────────────────────────────────────────

  const openCreate = () => {
    setForm({ clientId: '', clientName: '', clientPhone: '', notes: '', validUntil: '' })
    setClientSearch('')
    setLineItems(Array(10).fill(null).map(() => emptyLineItem()))
    setViewMode('create')
  }

  // ─── New from current quote ────────────────────────────

  const openNewFromCurrent = (quote: PriceQuote) => {
    setForm({
      clientId: quote.clientId ? String(quote.clientId) : '',
      clientName: quote.clientName || '',
      clientPhone: quote.clientPhone || '',
      notes: '',
      validUntil: '',
    })
    setClientSearch('')
    if (quote.items && quote.items.length > 0) {
      const items = quote.items.map((item) => ({
        productCode: item.product?.sku || (item.productId ? String(item.productId) : ''),
        productId: item.productId ? String(item.productId) : '',
        description: item.description || item.product?.name || '',
        quantity: String(item.quantity),
        unitPrice: String(item.unitPrice),
        discount: String(item.discountAmount),
        total: item.total,
      }))
      while (items.length < 10) items.push(emptyLineItem())
      setLineItems(items)
    } else {
      setLineItems(Array(10).fill(null).map(() => emptyLineItem()))
    }
    setViewMode('create')
  }

  // ─── Save Quote ─────────────────────────────────────────

  const handleSave = async () => {
    const validItems = lineItems.filter(
      (item) => item.unitPrice && parseFloat(item.unitPrice) > 0
    )
    if (validItems.length === 0) {
      toast.error(t('add_at_least_one_item'))
      return
    }

    const items = validItems.map((item) => ({
      productId: item.productId ? parseInt(item.productId) : null,
      description: item.description,
      quantity: parseFloat(item.quantity) || 1,
      unitPrice: parseFloat(item.unitPrice) || 0,
      discountAmount: parseFloat(item.discount) || 0,
      total: item.total,
    }))

    setSaving(true)
    try {
      const res = await fetch('/api/price-quotes', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          clientId: form.clientId ? parseInt(form.clientId) : null,
          clientName: form.clientName || undefined,
          clientPhone: form.clientPhone || undefined,
          items,
          discountAmount: totalDiscount,
          notes: form.notes || null,
          validUntil: form.validUntil || null,
        }),
      })

      if (res.ok) {
        const saved = await res.json()
        setQuotes((prev) => [saved, ...prev])
        setViewMode('list')
        toast.success(t('quote_created'))
      } else {
        const err = await res.json()
        toast.error(err.error || t('quote_create_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  // ─── Delete Quote ───────────────────────────────────────

  const confirmDelete = (id: number) => {
    setDeletingId(id)
    setDeleteDialogOpen(true)
  }

  const handleDelete = async () => {
    if (!deletingId) return
    try {
      await fetch(`/api/price-quotes/${deletingId}`, { method: 'DELETE' })
      setQuotes((prev) => prev.filter((q) => q.id !== deletingId))
      toast.success(t('quote_deleted'))
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setDeleteDialogOpen(false)
      setDeletingId(null)
    }
  }

  // ─── Convert to Invoice ────────────────────────────────

  const handleConvertToInvoice = async (quote: PriceQuote) => {
    setConverting(true)
    try {
      const res = await fetch(`/api/price-quotes/${quote.id}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'convert' }),
      })

      if (res.ok) {
        const invoice = await res.json()
        // Update local quote state
        setQuotes((prev) =>
          prev.map((q) =>
            q.id === quote.id
              ? { ...q, status: 'converted', convertedToInvoiceId: invoice.id, convertedToInvoice: { id: invoice.id, invoiceNumber: invoice.invoiceNumber } }
              : q
          )
        )
        toast.success(t('quote_converted_message'))
        // Redirect to sales invoices
        router.push('/shop/sales-invoices')
      } else {
        const err = await res.json()
        toast.error(err.error || t('error_connection'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setConverting(false)
    }
  }

  // ─── Update Quote Status ──────────────────────────────

  const updateQuoteStatus = async (quoteId: number, newStatus: string) => {
    try {
      const res = await fetch(`/api/price-quotes/${quoteId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: newStatus }),
      })
      if (res.ok) {
        setQuotes((prev) =>
          prev.map((q) => (q.id === quoteId ? { ...q, status: newStatus } : q))
        )
        if (viewingQuote?.id === quoteId) {
          setViewingQuote((prev) => prev ? { ...prev, status: newStatus } : prev)
        }
        toast.success(t('success'))
      }
    } catch {
      toast.error(t('error_connection'))
    }
  }

  // ─── Shared top bar ───────────────────────────────────

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

  // ─── Render: VIEW MODE ──────────────────────────────────

  if (viewMode === 'view' && viewingQuote) {
    const quote = viewingQuote

    return (
      <div className="h-full flex flex-col" dir={dir}>
        {renderTopBar(
          <Button variant="ghost" onClick={() => setViewMode('list')} className="gap-2 text-emerald-700 hover:text-emerald-900 hover:bg-emerald-50">
            <ArrowRight className="h-4 w-4" />
            {t('back')}
          </Button>,

          <>
            <Button
              variant="outline"
              size="icon"
              className="h-8 w-8 border-emerald-200 hover:bg-emerald-50"
              onClick={() => navigateQuote('prev')}
              disabled={currentQuoteIndex <= 0}
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
            <span className="text-sm font-medium text-muted-foreground min-w-[80px] text-center">
              {currentQuoteIndex + 1} / {quotes.length}
            </span>
            <Button
              variant="outline"
              size="icon"
              className="h-8 w-8 border-emerald-200 hover:bg-emerald-50"
              onClick={() => navigateQuote('next')}
              disabled={currentQuoteIndex >= quotes.length - 1}
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
          </>,

          <>
            {quote.status !== 'converted' && (
              <Button
                className="gap-2 bg-emerald-600 hover:bg-emerald-700"
                onClick={() => handleConvertToInvoice(quote)}
                disabled={converting}
              >
                {converting ? <Loader2 className="h-4 w-4 animate-spin" /> : <ArrowRightLeft className="h-4 w-4" />}
                {t('quote_convert_to_invoice')}
              </Button>
            )}
            {quote.status !== 'converted' && (
              <Button
                className="gap-2 bg-sky-600 hover:bg-sky-700"
                onClick={() => openNewFromCurrent(quote)}
              >
                <Plus className="h-4 w-4" />
                {t('quote_new_from_this')}
              </Button>
            )}
            <Button
              className="gap-2 bg-teal-600 hover:bg-teal-700"
              onClick={openCreate}
            >
              <Plus className="h-4 w-4" />
              {t('quote_new')}
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

        <div className="flex-1 overflow-y-auto p-6 lg:p-8">
          <div className="print-area max-w-7xl mx-auto bg-white border rounded-xl shadow-sm p-6 lg:p-8 space-y-6">
            {/* Header */}
            <div className="flex justify-between items-start">
              <div className="flex items-center gap-4">
                <div className="h-20 w-20 rounded-xl bg-teal-100 flex items-center justify-center">
                  {business?.logoUrl ? (
                    <img src={business.logoUrl} alt="Logo" className="h-20 w-20 rounded-xl object-cover" />
                  ) : (
                    <Store className="h-10 w-10 text-teal-600" />
                  )}
                </div>
                <div>
                  <h2 className="text-xl font-bold">{business?.name || t('the_shop')}</h2>
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
                <p className="text-2xl font-bold text-teal-700">{t('quote_label')}</p>
                <p className="text-sm text-muted-foreground">{quote.quoteNumber}</p>
                <p className="text-sm text-muted-foreground">{new Date(quote.createdAt).toLocaleDateString(locale)}</p>
                {quote.validUntil && (
                <p className="text-sm text-muted-foreground flex items-center gap-1 mt-1">
                    <Calendar className="h-3.5 w-3.5" />
                    {t('quote_valid_until')}: {new Date(quote.validUntil).toLocaleDateString(locale)}
                  </p>
                )}
              </div>
            </div>

            <Separator />

            {/* Client info */}
            <div className="bg-gray-50 rounded-lg p-4">
              <p className="text-sm font-medium text-muted-foreground mb-1">{t('sales_client')}</p>
              <p className="font-bold">{quote.clientName || '—'}</p>
              {quote.clientPhone && (
                <p className="text-sm text-muted-foreground">{quote.clientPhone}</p>
              )}
            </div>

            {/* Items table */}
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
                {quote.items?.map((item, idx) => (
                  <TableRow key={item.id}>
                    <TableCell className="text-center text-sm">{idx + 1}</TableCell>
                    <TableCell className="font-semibold text-sm">
                      {item.description || item.product?.name || '—'}
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
                  <span>{quote.subtotal.toLocaleString(locale)} {t('currency')}</span>
                </div>
                {quote.discountAmount > 0 && (
                  <div className="flex justify-between text-sm text-red-600">
                    <span>{t('sales_discount')}</span>
                    <span>- {quote.discountAmount.toLocaleString(locale)} {t('currency')}</span>
                  </div>
                )}
                {quote.taxAmount > 0 && (
                  <div className="flex justify-between text-sm">
                    <span>{t('tax')}</span>
                    <span>{quote.taxAmount.toLocaleString(locale)} {t('currency')}</span>
                  </div>
                )}
                <Separator />
                <div className="flex justify-between font-bold text-lg">
                  <span>{t('sales_grand_total')}</span>
                  <span className="text-teal-700">{quote.total.toLocaleString(locale)} {t('currency')}</span>
                </div>
              </div>
            </div>
           {/* Quote distinction banner */}
            <div className="bg-teal-50 border border-teal-200 rounded-lg p-3 text-center">
              <p className="text-sm font-medium text-teal-700">
                هذا عرض سعر وليس فاتورة - الأسعار قابلة للتغيير
              </p>
            </div>

            {/* Status */}   
            <div className="flex items-center gap-3">
              <span className="text-sm text-muted-foreground">{t('invoice_status')}:</span>
              <Badge variant="secondary" className={`text-xs ${(statusMap[quote.status] || statusMap.draft).color}`}>
                {(statusMap[quote.status] || statusMap.draft).label}
              </Badge>
              {quote.status !== 'converted' && (
                <Select
                  value={quote.status}
                  onValueChange={(val) => updateQuoteStatus(quote.id, val)}
                >
                  <SelectTrigger className="w-32 h-8 text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="draft">{t('quote_status_draft')}</SelectItem>
                    <SelectItem value="sent">{t('quote_status_sent')}</SelectItem>
                    <SelectItem value="accepted">{t('quote_status_accepted')}</SelectItem>
                    <SelectItem value="declined">{t('quote_status_declined')}</SelectItem>
                  </SelectContent>
                </Select>
              )}
              {quote.status === 'converted' && quote.convertedToInvoice && (
                <Button
                  variant="link"
                  className="text-teal-600 p-0 h-auto"
                  onClick={() => router.push('/shop/sales-invoices')}
                >
                  {t('quote_view_invoice')}: {quote.convertedToInvoice.invoiceNumber}
                </Button>
              )}
            </div>

            <Separator />

            {/* Footer */}
            <div className="text-center space-y-2 text-xs text-muted-foreground">
              {quote.notes && (
                <p className="text-sm"><strong>{t('notes')}:</strong> {quote.notes}</p>
              )}
              {business?.invoiceFooterText && (
                <p>{business.invoiceFooterText}</p>
              )}
            </div>
          </div>
        </div>
      </div>
    )
  }

  // ─── Render: CREATE MODE ────────────────────────────────

  if (viewMode === 'create') {
    return (
      <div className="h-full flex flex-col" dir={dir}>
        {renderTopBar(
          <Button variant="ghost" onClick={() => setViewMode('list')} className="gap-2 text-emerald-700 hover:text-emerald-900 hover:bg-emerald-50">
            <ArrowRight className="h-4 w-4" />
            {t('back')}
          </Button>,
          <h2 className="text-lg font-bold">{t('quote_new')}</h2>,
          <Button
            className="gap-2 bg-teal-600 hover:bg-teal-700 min-w-[120px]"
            onClick={handleSave}
            disabled={saving}
          >
            {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
            {t('save')}
          </Button>
        )}

        <div className="flex-1 overflow-y-auto p-4 lg:p-6">
          <div className="max-w-5xl mx-auto space-y-4">
            {/* Client section */}
            <Card>
              <CardContent className="p-4">
                <h3 className="font-bold mb-3 text-sm">{t('sales_client')}</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div className="relative" ref={clientSearchRef}>
                    <Label className="text-xs mb-1">{t('search')}</Label>
                    <div className="flex gap-2">
                      <Input
                        value={form.clientName || clientSearch}
                        onChange={(e) => {
                          setClientSearch(e.target.value)
                          setClientDropdownOpen(true)
                          if (!form.clientId) {
                            setForm({ ...form, clientName: e.target.value })
                          }
                        }}
                        onFocus={() => setClientDropdownOpen(true)}
                        placeholder={t('sales_client')}
                      />
                      {form.clientName && (
                        <Button variant="ghost" size="icon" className="h-8 w-8 shrink-0" onClick={clearClient}>
                          <X className="h-4 w-4" />
                        </Button>
                      )}
                    </div>
                    {clientDropdownOpen && filteredClients.length > 0 && (
                      <div className="absolute z-50 mt-1 w-full bg-white border rounded-lg shadow-lg max-h-48 overflow-y-auto">
                        {filteredClients.map((c) => (
                          <button
                            key={c.id}
                            className="w-full text-right px-3 py-2 hover:bg-emerald-50 text-sm"
                            onClick={() => selectClient(c)}
                          >
                            <span className="font-medium">{c.name}</span>
                            {c.phone && <span className="text-muted-foreground ms-2">{c.phone}</span>}
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                  <div>
                    <Label className="text-xs mb-1">{t('phone')}</Label>
                    <Input
                      value={form.clientPhone}
                      onChange={(e) => setForm({ ...form, clientPhone: e.target.value })}
                      placeholder={t('phone')}
                    />
                  </div>
                </div>
                {/* Valid until and notes */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mt-3">
                  <div>
                    <Label className="text-xs mb-1 flex items-center gap-1">
                      <Calendar className="h-3.5 w-3.5" />
                      {t('quote_valid_until')}
                    </Label>
                    <Input
                      type="date"
                      value={form.validUntil}
                      onChange={(e) => setForm({ ...form, validUntil: e.target.value })}
                    />
                  </div>
                  <div>
                    <Label className="text-xs mb-1">{t('notes')}</Label>
                    <Input
                      value={form.notes}
                      onChange={(e) => setForm({ ...form, notes: e.target.value })}
                      placeholder={t('notes')}
                    />
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Line items */}
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between mb-3">
                  <h3 className="font-bold text-sm">{t('items')}</h3>
                  <Button variant="outline" size="sm" onClick={addLineItem} className="gap-1">
                    <Plus className="h-3.5 w-3.5" />
                    {t('add')}
                  </Button>
                </div>
                <div className="overflow-x-auto">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead className="text-right w-24">{t('sales_item_code')}</TableHead>
                        <TableHead className="text-right min-w-[180px]">{t('sales_item_name')}</TableHead>
                        <TableHead className="text-right w-20">{t('sales_quantity')}</TableHead>
                        <TableHead className="text-right w-24">{t('sales_unit_price')}</TableHead>
                        <TableHead className="text-right w-20">{t('sales_discount')}</TableHead>
                        <TableHead className="text-right w-24">{t('sales_grand_total')}</TableHead>
                        <TableHead className="w-10"></TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {lineItems.map((item, idx) => (
                        <TableRow key={idx}>
                          <TableCell>
                            <Input
                              value={item.productCode}
                              onChange={(e) => updateLineItem(idx, 'productCode', e.target.value)}
                              onFocus={() => {
                                setProductSearchIndex(idx)
                                setProductSearchTerm('')
                              }}
                              className="h-8 text-xs"
                              placeholder={t('sales_item_code')}
                            />
                          </TableCell>
                          <TableCell className="relative">
                            <Input
                              id={`pq-item-${idx}-description`}
                              value={item.description}
                              onChange={(e) => updateLineItem(idx, 'description', e.target.value)}
                              onKeyDown={(e) => handleItemKeyDown(e, idx, 'description')}
                              onFocus={() => {
                                setProductSearchIndex(idx)
                                setProductSearchTerm('')
                              }}
                              className="h-8 text-xs"
                              placeholder={t('sales_item_name')}
                            />
                            {productSearchIndex === idx && (
                              <div ref={productSearchRef} className="absolute z-50 mt-1 w-full bg-white border rounded-lg shadow-lg max-h-48 overflow-y-auto">
                                <div className="px-3 py-2 border-b">
                                  <Input
                                    value={productSearchTerm}
                                    onChange={(e) => setProductSearchTerm(e.target.value)}
                                    placeholder={t('products_search')}
                                    className="h-7 text-xs"
                                    autoFocus
                                  />
                                </div>
                                {filteredProducts.slice(0, 10).map((p, pIdx) => (
                                  <button
                                    key={p.id}
                                    className={`w-full text-right px-3 py-2 hover:bg-teal-50 text-xs ${highlightedProductIdx === pIdx ? 'bg-teal-50' : ''}`}
                                    onClick={() => selectProduct(p, idx)}
                                    onMouseEnter={() => setHighlightedProductIdx(pIdx)}
                                  >
                                    <span className="font-medium">{p.name}</span>
                                    <span className="text-muted-foreground ms-2">{p.sku || p.id}</span>
                                    <span className="ms-2 text-teal-600">{p.price} {t('currency')}</span>
                                  </button>
                                ))}
                              </div>
                            )}
                          </TableCell>
                          <TableCell>
                            <Input
                              id={`pq-item-${idx}-quantity`}
                              type="text"
                              inputMode="decimal"
                              value={item.quantity}
                              onChange={(e) => updateLineItem(idx, 'quantity', e.target.value)}
                              onKeyDown={(e) => handleItemKeyDown(e, idx, 'quantity')}
                              className="h-8 text-xs text-center [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                            />
                          </TableCell>
                          <TableCell>
                            <Input
                              id={`pq-item-${idx}-unitPrice`}
                              type="text"
                              inputMode="decimal"
                              value={item.unitPrice}
                              onChange={(e) => updateLineItem(idx, 'unitPrice', e.target.value)}
                              onKeyDown={(e) => handleItemKeyDown(e, idx, 'unitPrice')}
                              className="h-8 text-xs text-center [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                            />
                          </TableCell>
                          <TableCell>
                            <Input
                              id={`pq-item-${idx}-discount`}
                              type="text"
                              inputMode="decimal"
                              value={item.discount}
                              onChange={(e) => updateLineItem(idx, 'discount', e.target.value)}
                              onKeyDown={(e) => handleItemKeyDown(e, idx, 'discount')}
                              className="h-8 text-xs text-center [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                            />
                          </TableCell>
                          <TableCell className="text-center font-medium text-sm">
                            {item.total.toLocaleString(locale)}
                          </TableCell>
                          <TableCell>
                            {lineItems.length > 1 && (
                              <Button variant="ghost" size="icon" className="h-6 w-6 text-red-400 hover:text-red-600" onClick={() => removeLineItem(idx)}>
                                <X className="h-3.5 w-3.5" />
                              </Button>
                            )}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>

                {/* Totals */}
                <div className="flex justify-end mt-4">
                  <div className="w-72 space-y-1">
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">{t('sales_subtotal')}</span>
                      <span>{subtotal.toLocaleString(locale)} {t('currency')}</span>
                    </div>
                    <div className="flex justify-between font-bold text-lg">
                      <span>{t('sales_grand_total')}</span>
                      <span className="text-teal-700">{grandTotal.toLocaleString(locale)} {t('currency')}</span>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    )
  }

  // ─── Render: LIST MODE ─────────────────────────────────

  return (
    <div className="space-y-4" dir={dir}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold flex items-center gap-2">
            <FileCheck className="h-5 w-5 text-teal-600" />
            {t('nav_price_quotes')}
          </h2>
          <p className="text-sm text-muted-foreground">{t('quote_subtitle')}</p>
        </div>
        <Button className="gap-2 bg-teal-600 hover:bg-teal-700" onClick={openCreate}>
          <Plus className="h-4 w-4" />
          {t('quote_new')}
        </Button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-teal-700">{quotes.length}</p>
            <p className="text-xs text-muted-foreground">{t('quote_total_quotes')}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-gray-700">{quotes.filter((q) => q.status === 'draft').length}</p>
            <p className="text-xs text-muted-foreground">{t('quote_status_draft')}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-emerald-700">{quotes.filter((q) => q.status === 'accepted').length}</p>
            <p className="text-xs text-muted-foreground">{t('quote_status_accepted')}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-teal-700">{quotes.filter((q) => q.status === 'converted').length}</p>
            <p className="text-xs text-muted-foreground">{t('quote_status_converted')}</p>
          </CardContent>
        </Card>
      </div>

      {/* Filter */}
      <div className="flex items-center gap-2">
        <Filter className="h-4 w-4 text-muted-foreground" />
        <Select value={statusFilter} onValueChange={setStatusFilter}>
          <SelectTrigger className="w-40">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t('all')}</SelectItem>
            <SelectItem value="draft">{t('quote_status_draft')}</SelectItem>
            <SelectItem value="sent">{t('quote_status_sent')}</SelectItem>
            <SelectItem value="accepted">{t('quote_status_accepted')}</SelectItem>
            <SelectItem value="declined">{t('quote_status_declined')}</SelectItem>
            <SelectItem value="converted">{t('quote_status_converted')}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {/* Quotes List */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-teal-600" />
        </div>
      ) : filteredQuotes.length === 0 ? (
        <Card>
          <CardContent className="p-8 text-center">
            <FileCheck className="h-12 w-12 mx-auto text-muted-foreground mb-3" />
            <p className="text-muted-foreground">{t('quote_no_quotes')}</p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-2 max-h-[calc(100vh-380px)] overflow-y-auto">
          {filteredQuotes.map((quote) => (
            <Card
              key={quote.id}
              className="hover:shadow-md transition-shadow cursor-pointer"
              onClick={() => openViewForQuote(quote)}
            >
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="h-10 w-10 rounded-lg bg-teal-100 flex items-center justify-center shrink-0">
                      <FileCheck className="h-5 w-5 text-teal-600" />
                    </div>
                    <div>
                      <p className="font-bold text-sm">{quote.quoteNumber}</p>
                      <p className="text-xs text-muted-foreground">
                        {quote.clientName || '—'}
                        {quote.clientPhone && ` • ${quote.clientPhone}`}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <div className="text-left">
                      <p className="font-bold text-teal-700">{quote.total.toLocaleString(locale)} {t('currency')}</p>
                      <p className="text-xs text-muted-foreground">{new Date(quote.createdAt).toLocaleDateString(locale)}</p>
                    </div>
                    <Badge variant="secondary" className={`text-xs ${(statusMap[quote.status] || statusMap.draft).color}`}>
                      {(statusMap[quote.status] || statusMap.draft).label}
                    </Badge>
                    <div className="flex gap-1" onClick={(e) => e.stopPropagation()}>
                      {quote.status !== 'converted' && (
                        <Button
                          variant="ghost"
                          size="icon"
                          className="h-8 w-8 text-emerald-600 hover:bg-emerald-50"
                          onClick={() => handleConvertToInvoice(quote)}
                          disabled={converting}
                          title={t('quote_convert_to_invoice')}
                        >
                          <ArrowRightLeft className="h-4 w-4" />
                        </Button>
                      )}
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8"
                        onClick={() => openViewForQuote(quote)}
                      >
                        <Eye className="h-4 w-4" />
                      </Button>
                      {quote.status !== 'converted' && (
                        <Button
                          variant="ghost"
                          size="icon"
                          className="h-8 w-8 text-red-500 hover:bg-red-50"
                          onClick={() => confirmDelete(quote.id)}
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      )}
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Delete Dialog */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent dir={dir}>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('delete')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('quote_delete_confirm')}
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
