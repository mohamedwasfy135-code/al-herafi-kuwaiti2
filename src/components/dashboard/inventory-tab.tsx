'use client'

import { useState, useEffect, useCallback, useMemo } from 'react'
import {
  Plus,
  ArrowDownToLine,
  ArrowUpFromLine,
  ArrowLeftRight,
  SlidersHorizontal,
  RotateCcw,
  Package,
  Search,
  Loader2,
  AlertTriangle,
  ClipboardCheck,
  Save,
  Calculator,
  FileText,
  ShoppingCart,
  Truck,
  History,
  Trash2,
  Info,
  Calendar,
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
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from '@/components/ui/tabs'
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

// ─── Types ───────────────────────────────────────────────────────

interface Movement {
  id: number
  productId: number
  warehouseId: number | null
  movementType: string
  quantity: number
  notes: string | null
  createdAt: string
  product: { id: number; name: string; unit: string | null }
  warehouse: { id: number; name: string } | null
}

interface Product {
  id: number
  name: string
  stockQuantity: number
  price: number
  costPrice: number
  unit?: string | null
}

interface Warehouse {
  id: number
  name: string
}

interface WarehouseProductItem {
  productId: number
  warehouseId: number
  warehouseQuantity: number
}

interface SalesInvoice {
  id: number
  invoiceNumber: string
  clientName: string | null
  total: number
  createdAt: string
  items: SalesInvoiceItem[]
}

interface SalesInvoiceItem {
  id: number
  productId: number | null
  quantity: number
  unitPrice: number
  total: number
  description?: string | null
}

interface PurchaseInvoice {
  id: number
  invoiceNumber: string
  supplierName: string | null
  total: number
  createdAt: string
  items: PurchaseInvoiceItem[]
}

interface PurchaseInvoiceItem {
  id: number
  productId: number | null
  quantity: number
  unitPrice: number
  total: number
  description?: string | null
}

interface SalesReturn {
  id: number
  returnNumber: string
  clientName: string | null
  originalInvoiceId: number
  originalInvoice: { id: number; invoiceNumber: string }
  total: number
  reason: string | null
  createdAt: string
}

interface PurchaseReturn {
  id: number
  returnNumber: string
  supplierName: string | null
  originalInvoiceId: number
  originalInvoice: { id: number; invoiceNumber: string }
  total: number
  reason: string | null
  createdAt: string
}

/** Unified movement row for product movement tab */
interface ProductMovementRow {
  date: string
  type: string
  typeLabel: string
  reference: string
  quantity: number
  quantityEffect: 'in' | 'out' | 'neutral'
  runningBalance: number
}

// ─── Component ───────────────────────────────────────────────────

export function InventoryTab() {
  // ── Shared State ──
  const { t, lang, dir } = useLanguage()
  const locale = lang === 'ar' ? 'ar-KW' : 'en-US'
  const [movements, setMovements] = useState<Movement[]>([])
  const [products, setProducts] = useState<Product[]>([])
  const [warehouses, setWarehouses] = useState<Warehouse[]>([])
  const [loading, setLoading] = useState(false)
  const businessId = getBusinessId()

  // ── Add Movement Dialog ──
  const [dialogOpen, setDialogOpen] = useState(false)
  const [saving, setSaving] = useState(false)
  const [form, setForm] = useState({
    productId: '',
    warehouseId: '',
    movementType: 'in',
    quantity: '',
    notes: '',
  })

  // ── Filters ──
  const [filterProduct, setFilterProduct] = useState<string>('all')
  const [filterWarehouse, setFilterWarehouse] = useState<string>('all')
  const [filterType, setFilterType] = useState<string>('all')

  // ── Stocktake Dialog ──
  const [stocktakeOpen, setStocktakeOpen] = useState(false)
  const [stocktakeItems, setStocktakeItems] = useState<
    { productId: number; productName: string; bookStock: number; countedStock: string; difference: number }[]
  >([])
  const [stocktakeSaving, setStocktakeSaving] = useState(false)
  const [stocktakeCalculated, setStocktakeCalculated] = useState(false)
  const [stocktakeWarehouseId, setStocktakeWarehouseId] = useState<string>('all')
  const [stocktakeDate, setStocktakeDate] = useState<string>(new Date().toISOString().split('T')[0])
  const [stocktakeWarningOpen, setStocktakeWarningOpen] = useState(false)
  const [stocktakeUncountedOpen, setStocktakeUncountedOpen] = useState(false)
  const [stocktakeApplied, setStocktakeApplied] = useState(false)
  const [deleteEmptyOpen, setDeleteEmptyOpen] = useState(false)
  const [warehouseProductsData, setWarehouseProductsData] = useState<WarehouseProductItem[]>([])
  const [deletingEmpty, setDeletingEmpty] = useState(false)

  // ── Product Movement Tab ──
  const [selectedProductId, setSelectedProductId] = useState<string>('')
  const [salesInvoices, setSalesInvoices] = useState<SalesInvoice[]>([])
  const [purchaseInvoices, setPurchaseInvoices] = useState<PurchaseInvoice[]>([])
  const [salesReturns, setSalesReturns] = useState<SalesReturn[]>([])
  const [purchaseReturns, setPurchaseReturns] = useState<PurchaseReturn[]>([])
  const [productMovements, setProductMovements] = useState<Movement[]>([])
  const [movementLoading, setMovementLoading] = useState(false)
  const [invoicesLoaded, setInvoicesLoaded] = useState(false)

  // ── Movement type map with i18n ──
  const movementTypeMap = useMemo(() => ({
    in: { label: t('inventory_stock_in'), color: 'bg-emerald-100 text-emerald-700', icon: ArrowDownToLine },
    out: { label: t('inventory_stock_out'), color: 'bg-red-100 text-red-700', icon: ArrowUpFromLine },
    transfer: { label: t('inventory_stock_transfer'), color: 'bg-sky-100 text-sky-700', icon: ArrowLeftRight },
    adjustment: { label: t('inventory_stock_adjustment'), color: 'bg-amber-100 text-amber-700', icon: SlidersHorizontal },
    return: { label: t('inventory_stock_return'), color: 'bg-violet-100 text-violet-700', icon: RotateCcw },
  }), [t])

  // ── Data Fetching ──
  const fetchData = useCallback(async () => {
    setLoading(true)
    try {
      const [movRes, prodRes, whRes] = await Promise.all([
        fetch(`/api/inventory?businessId=${businessId}`),
        fetch(`/api/products?businessId=${businessId}`),
        fetch(`/api/warehouses?businessId=${businessId}`),
      ])
      if (movRes.ok) {
        const data = await movRes.json()
        setMovements(data)
      }
      if (prodRes.ok) {
        const data = await prodRes.json()
        setProducts(data)
      }
      if (whRes.ok) {
        const data = await whRes.json()
        setWarehouses(data)
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

  // ── Fetch invoices for product movement tab (lazy) ──
  const fetchInvoices = useCallback(async () => {
    if (invoicesLoaded) return
    setMovementLoading(true)
    try {
      const [salesRes, purchaseRes, salesRetRes, purchaseRetRes] = await Promise.all([
        fetch(`/api/invoices/sales?businessId=${businessId}`),
        fetch(`/api/invoices/purchase?businessId=${businessId}`),
        fetch(`/api/invoices/sales-returns?businessId=${businessId}`),
        fetch(`/api/invoices/purchase-returns?businessId=${businessId}`),
      ])
      if (salesRes.ok) {
        const data = await salesRes.json()
        setSalesInvoices(data)
      }
      if (purchaseRes.ok) {
        const data = await purchaseRes.json()
        setPurchaseInvoices(data)
      }
      if (salesRetRes.ok) {
        const data = await salesRetRes.json()
        setSalesReturns(data)
      }
      if (purchaseRetRes.ok) {
        const data = await purchaseRetRes.json()
        setPurchaseReturns(data)
      }
      setInvoicesLoaded(true)
    } catch {
      // silent
    } finally {
      setMovementLoading(false)
    }
  }, [businessId, invoicesLoaded])

  // ── Fetch product-specific movements ──
  useEffect(() => {
    if (!selectedProductId) {
      setProductMovements([])
      return
    }
    const fetchProductMovements = async () => {
      setMovementLoading(true)
      try {
        const res = await fetch(
          `/api/inventory?businessId=${businessId}&productId=${selectedProductId}`
        )
        if (res.ok) {
          const data = await res.json()
          setProductMovements(data)
        }
      } catch {
        // silent
      } finally {
        setMovementLoading(false)
      }
    }
    fetchProductMovements()
  }, [selectedProductId, businessId])

  // Trigger invoice loading when product movement tab might be used
  useEffect(() => {
    if (selectedProductId) {
      fetchInvoices()
    }
  }, [selectedProductId, fetchInvoices])

  // ── Derived: Filtered Movements ──
  const filteredMovements = movements.filter((m) => {
    if (filterProduct !== 'all' && String(m.productId) !== filterProduct) return false
    if (filterWarehouse !== 'all' && String(m.warehouseId) !== filterWarehouse) return false
    if (filterType !== 'all' && m.movementType !== filterType) return false
    return true
  })

  // ── Derived: Summary ──
  const totalItems = products.reduce((s, p) => s + p.stockQuantity, 0)
  const lowStockCount = products.filter((p) => p.stockQuantity <= 5).length
  const totalValue = products.reduce((s, p) => s + p.stockQuantity * p.costPrice, 0)

  // ── Product Movement: Build unified movement rows ──
  const productMovementRows: ProductMovementRow[] = useMemo(() => {
    if (!selectedProductId) return []

    const pid = parseInt(selectedProductId)
    const rows: ProductMovementRow[] = []

    // Purchase invoice items (stock IN)
    purchaseInvoices.forEach((inv) => {
      inv.items.forEach((item) => {
        if (item.productId === pid) {
          rows.push({
            date: inv.createdAt,
            type: 'purchase',
            typeLabel: t('inventory_stock_in'),
            reference: inv.invoiceNumber,
            quantity: item.quantity,
            quantityEffect: 'in',
            runningBalance: 0,
          })
        }
      })
    })

    // Sales invoice items (stock OUT)
    salesInvoices.forEach((inv) => {
      inv.items.forEach((item) => {
        if (item.productId === pid) {
          rows.push({
            date: inv.createdAt,
            type: 'sale',
            typeLabel: t('inventory_stock_out'),
            reference: inv.invoiceNumber,
            quantity: item.quantity,
            quantityEffect: 'out',
            runningBalance: 0,
          })
        }
      })
    })

    // Sales returns (stock IN - returned from customer)
    salesReturns.forEach((ret) => {
      const origInvoice = salesInvoices.find((si) => si.id === ret.originalInvoiceId)
      if (origInvoice) {
        const hasProduct = origInvoice.items.some((item) => item.productId === pid)
        if (hasProduct) {
          const productItems = origInvoice.items.filter((item) => item.productId === pid)
          const totalQty = productItems.reduce((s, i) => s + i.quantity, 0)
          const proportion = origInvoice.total > 0 ? ret.total / origInvoice.total : 0
          const returnQty = Math.round(totalQty * proportion)
          if (returnQty > 0) {
            rows.push({
              date: ret.createdAt,
              type: 'sales_return',
              typeLabel: t('type_sales_return'),
              reference: ret.returnNumber,
              quantity: returnQty,
              quantityEffect: 'in',
              runningBalance: 0,
            })
          }
        }
      }
    })

    // Purchase returns (stock OUT - returned to supplier)
    purchaseReturns.forEach((ret) => {
      const origInvoice = purchaseInvoices.find((pi) => pi.id === ret.originalInvoiceId)
      if (origInvoice) {
        const hasProduct = origInvoice.items.some((item) => item.productId === pid)
        if (hasProduct) {
          const productItems = origInvoice.items.filter((item) => item.productId === pid)
          const totalQty = productItems.reduce((s, i) => s + i.quantity, 0)
          const proportion = origInvoice.total > 0 ? ret.total / origInvoice.total : 0
          const returnQty = Math.round(totalQty * proportion)
          if (returnQty > 0) {
            rows.push({
              date: ret.createdAt,
              type: 'purchase_return',
              typeLabel: t('type_purchase_return'),
              reference: ret.returnNumber,
              quantity: returnQty,
              quantityEffect: 'out',
              runningBalance: 0,
            })
          }
        }
      }
    })

    // Inventory movements (adjustments, transfers, etc.)
    productMovements.forEach((mov) => {
      rows.push({
        date: mov.createdAt,
        type: mov.movementType,
        typeLabel: movementTypeMap[mov.movementType]?.label || mov.movementType,
        reference: mov.notes || t('inventory_adjustment_label'),
        quantity: mov.quantity,
        quantityEffect:
          mov.movementType === 'in' || mov.movementType === 'return'
            ? 'in'
            : mov.movementType === 'out'
            ? 'out'
            : 'neutral',
        runningBalance: 0,
      })
    })

    // Sort by date ascending for running balance
    rows.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())

    // Calculate running balance
    let balance = 0
    rows.forEach((row) => {
      if (row.quantityEffect === 'in') {
        balance += row.quantity
      } else if (row.quantityEffect === 'out') {
        balance -= row.quantity
      } else {
        balance = row.quantity
      }
      row.runningBalance = balance
    })

    return rows
  }, [selectedProductId, purchaseInvoices, salesInvoices, salesReturns, purchaseReturns, productMovements, movementTypeMap, t])

  // ── Handlers ──

  const handleSubmit = async () => {
    if (!form.productId || !form.movementType || !form.quantity) {
      toast.error(t('inventory_product_required'))
      return
    }
    setSaving(true)
    try {
      const res = await fetch('/api/inventory', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          productId: parseInt(form.productId),
          warehouseId: form.warehouseId && form.warehouseId !== 'none' ? parseInt(form.warehouseId) : null,
          movementType: form.movementType,
          quantity: form.quantity,
          notes: form.notes || null,
        }),
      })

      if (res.ok) {
        toast.success(t('inventory_movement_registered'))
        setDialogOpen(false)
        setForm({ productId: '', warehouseId: '', movementType: 'in', quantity: '', notes: '' })
        fetchData()
      } else {
        const err = await res.json()
        toast.error(err.error || t('inventory_movement_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  // ── Stocktake Handlers ──

  const fetchWarehouseProducts = useCallback(async () => {
    try {
      const res = await fetch(`/api/warehouse-products?businessId=${businessId}`)
      if (res.ok) {
        const data = await res.json()
        setWarehouseProductsData(data)
      }
    } catch {
      // silent
    }
  }, [businessId])

  const openStocktake = async () => {
    setStocktakeWarehouseId('all')
    setStocktakeDate(new Date().toISOString().split('T')[0])
    setStocktakeApplied(false)

    // Fetch warehouse products data for filtering
    await fetchWarehouseProducts()

    const items = products.map((p) => ({
      productId: p.id,
      productName: p.name,
      bookStock: p.stockQuantity,
      countedStock: '',
      difference: 0,
    }))
    setStocktakeItems(items)
    setStocktakeCalculated(false)
    setStocktakeOpen(true)
  }

  const getFilteredStocktakeItems = useMemo(() => {
    if (stocktakeWarehouseId === 'all') return stocktakeItems
    const warehouseProductIds = warehouseProductsData
      .filter((wp) => String(wp.warehouseId) === stocktakeWarehouseId)
      .map((wp) => wp.productId)
    return stocktakeItems.filter((item) => warehouseProductIds.includes(item.productId))
  }, [stocktakeItems, stocktakeWarehouseId, warehouseProductsData])

  const handleCountedStockChange = (productId: number, value: string) => {
    setStocktakeItems((prev) =>
      prev.map((item) =>
        item.productId === productId
          ? { ...item, countedStock: value }
          : item
      )
    )
    setStocktakeCalculated(false)
  }

  const calculateStocktake = () => {
    setStocktakeItems((prev) =>
      prev.map((item) => ({
        ...item,
        difference:
          item.countedStock !== '' ? parseInt(item.countedStock) - item.bookStock : 0,
      }))
    )
    setStocktakeCalculated(true)
    toast.success(t('inventory_differences_calculated'))
  }

  const handleApplyStocktake = () => {
    // First: check for uncounted items
    const uncountedItems = getFilteredStocktakeItems.filter((item) => item.countedStock === '')
    if (uncountedItems.length > 0) {
      setStocktakeUncountedOpen(true)
    } else {
      // No uncounted items, show main warning
      setStocktakeWarningOpen(true)
    }
  }

  const handleUncountedProceed = () => {
    setStocktakeUncountedOpen(false)
    setStocktakeWarningOpen(true)
  }

  const handleWarningConfirm = async () => {
    setStocktakeWarningOpen(false)
    await executeStocktake()
  }

  const executeStocktake = async () => {
    const changedItems = stocktakeItems.filter(
      (item) => item.countedStock !== '' && item.difference !== 0
    )

    if (changedItems.length === 0) {
      toast.info(t('inventory_no_differences'))
      return
    }

    setStocktakeSaving(true)
    let successCount = 0
    let failCount = 0

    for (const item of changedItems) {
      try {
        // Update product stock quantity
        const res = await fetch(`/api/products/${item.productId}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            stockQuantity: parseInt(item.countedStock),
          }),
        })
        if (res.ok) {
          // Create inventory movement record with stocktake date
          try {
            await fetch('/api/inventory', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                businessId,
                productId: item.productId,
                movementType: 'adjustment',
                quantity: Math.abs(item.difference),
                notes: `${t('inventory_stocktake_title')} - ${t('inventory_stocktake_date')}: ${stocktakeDate}`,
              }),
            })
          } catch {
            // Movement logging is optional
          }
          successCount++
        } else {
          failCount++
        }
      } catch {
        failCount++
      }
    }

    setStocktakeSaving(false)

    if (failCount === 0) {
      toast.success(t('inventory_stocktake_applied').replace('{count}', String(successCount)))
      setStocktakeApplied(true)
      fetchData()
    } else {
      toast.error(t('inventory_stocktake_partial').replace('{success}', String(successCount)).replace('{fail}', String(failCount)))
      setStocktakeApplied(true)
      fetchData()
    }
  }

  // ── Delete Empty Materials ──
  const emptyProducts = useMemo(() => products.filter((p) => p.stockQuantity === 0), [products])

  const handleDeleteEmptyMaterials = async () => {
    setDeletingEmpty(true)
    let successCount = 0
    let failCount = 0

    for (const product of emptyProducts) {
      try {
        const res = await fetch(`/api/products/${product.id}`, {
          method: 'DELETE',
        })
        if (res.ok) {
          successCount++
        } else {
          failCount++
        }
      } catch {
        failCount++
      }
    }

    setDeletingEmpty(false)
    setDeleteEmptyOpen(false)

    if (failCount === 0 && successCount > 0) {
      toast.success(t('inventory_empty_deleted'))
      fetchData()
    } else if (successCount > 0) {
      toast.success(t('inventory_empty_deleted'))
      fetchData()
    }
  }

  // ── Movement type icon helper ──
  const getMovementTypeBadge = (type: string, typeLabel: string) => {
    const typeInfo = movementTypeMap[type as keyof typeof movementTypeMap]
    if (typeInfo) {
      const Icon = typeInfo.icon
      return (
        <div className="flex items-center gap-2">
          <Icon className="h-4 w-4" />
          <Badge variant="secondary" className={`text-xs ${typeInfo.color}`}>
            {typeInfo.label}
          </Badge>
        </div>
      )
    }
    // Custom types from product movement tab
    const customColors: Record<string, string> = {
      purchase: 'bg-emerald-100 text-emerald-700',
      sale: 'bg-red-100 text-red-700',
      sales_return: 'bg-violet-100 text-violet-700',
      purchase_return: 'bg-orange-100 text-orange-700',
    }
    const customIcons: Record<string, React.ElementType> = {
      purchase: Truck,
      sale: ShoppingCart,
      sales_return: RotateCcw,
      purchase_return: RotateCcw,
    }
    const Icon = customIcons[type] || FileText
    const color = customColors[type] || 'bg-gray-100 text-gray-700'
    return (
      <div className="flex items-center gap-2">
        <Icon className="h-4 w-4" />
        <Badge variant="secondary" className={`text-xs ${color}`}>
          {typeLabel}
        </Badge>
      </div>
    )
  }

  // ── Render ──

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('inventory_title')}</h2>
          <p className="text-muted-foreground">{t('inventory_tracking_desc')}</p>
        </div>
        <div className="flex gap-2 flex-wrap">
          <Button
            onClick={openStocktake}
            variant="outline"
            className="gap-2 border-amber-300 text-amber-700 hover:bg-amber-50"
          >
            <ClipboardCheck className="h-4 w-4" />
            {t('inventory_stocktake')}
          </Button>
          <Button
            onClick={() => setDialogOpen(true)}
            className="gap-2 bg-emerald-600 hover:bg-emerald-700"
          >
            <Plus className="h-4 w-4" />
            {t('inventory_new_movement')}
          </Button>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-100">
              <Package className="h-6 w-6 text-emerald-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('inventory_total_stock')}</p>
              <p className="text-2xl font-bold">{totalItems.toLocaleString(locale)}</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-red-100">
              <AlertTriangle className="h-6 w-6 text-red-600" />
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('inventory_low_stock_count')}</p>
              <p className="text-2xl font-bold text-red-700">{lowStockCount}</p>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-amber-100">
              <span className="text-lg font-bold text-amber-600">{t('currency')}</span>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">{t('inventory_stock_value')}</p>
              <p className="text-2xl font-bold">{totalValue.toLocaleString(locale)}</p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Main Tabs: Movements + Product Movement */}
      <Tabs defaultValue="movements" dir={dir} className="w-full">
        <TabsList className="w-full sm:w-auto">
          <TabsTrigger value="movements" className="gap-1.5">
            <ArrowLeftRight className="h-4 w-4" />
            {t('inventory_movements')}
          </TabsTrigger>
          <TabsTrigger value="product-movement" className="gap-1.5">
            <History className="h-4 w-4" />
            {t('inventory_product_movements')}
          </TabsTrigger>
        </TabsList>

        {/* ── Tab 1: Inventory Movements ── */}
        <TabsContent value="movements" className="space-y-4">
          {/* Filters */}
          <Card>
            <CardContent className="p-4">
              <div className="flex flex-wrap gap-3">
                <Select value={filterProduct} onValueChange={setFilterProduct}>
                  <SelectTrigger className="w-44">
                    <SelectValue placeholder={t('inventory_stock_filter_product')} />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">{t('inventory_all_products')}</SelectItem>
                    {products.map((p) => (
                      <SelectItem key={p.id} value={String(p.id)}>
                        {p.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <Select value={filterWarehouse} onValueChange={setFilterWarehouse}>
                  <SelectTrigger className="w-44">
                    <SelectValue placeholder={t('inventory_stock_filter_warehouse')} />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">{t('inventory_all_warehouses')}</SelectItem>
                    {warehouses.map((w) => (
                      <SelectItem key={w.id} value={String(w.id)}>
                        {w.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <Select value={filterType} onValueChange={setFilterType}>
                  <SelectTrigger className="w-36">
                    <SelectValue placeholder={t('inventory_stock_filter_type')} />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">{t('inventory_all_types')}</SelectItem>
                    <SelectItem value="in">{t('inventory_stock_in')}</SelectItem>
                    <SelectItem value="out">{t('inventory_stock_out')}</SelectItem>
                    <SelectItem value="transfer">{t('inventory_stock_transfer')}</SelectItem>
                    <SelectItem value="adjustment">{t('inventory_stock_adjustment')}</SelectItem>
                    <SelectItem value="return">{t('inventory_stock_return')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </CardContent>
          </Card>

          {/* Movements Table */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base">{t('inventory_movements')}</CardTitle>
              <CardDescription>{t('inventory_movements_log')}</CardDescription>
            </CardHeader>
            <CardContent className="p-0">
              {loading ? (
                <div className="flex items-center justify-center py-12">
                  <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
                </div>
              ) : filteredMovements.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
                  <ArrowLeftRight className="h-12 w-12 mb-3 opacity-30" />
                  <p>{t('inventory_no_movements_msg')}</p>
                </div>
              ) : (
                <div className="overflow-x-auto max-h-96 overflow-y-auto">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead className="text-right">{t('inventory_movement_type')}</TableHead>
                        <TableHead className="text-right">{t('inventory_product_name')}</TableHead>
                        <TableHead className="text-right">{t('inventory_warehouse_optional')}</TableHead>
                        <TableHead className="text-right">{t('inventory_quantity_label')}</TableHead>
                        <TableHead className="text-right">{t('inventory_notes_label')}</TableHead>
                        <TableHead className="text-right">{t('date')}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {filteredMovements.map((mov) => {
                        const typeInfo = movementTypeMap[mov.movementType as keyof typeof movementTypeMap] || {
                          label: mov.movementType,
                          color: 'bg-gray-100 text-gray-700',
                          icon: ArrowLeftRight,
                        }
                        const Icon = typeInfo.icon
                        return (
                          <TableRow key={mov.id}>
                            <TableCell>
                              <div className="flex items-center gap-2">
                                <Icon className="h-4 w-4" />
                                <Badge variant="secondary" className={`text-xs ${typeInfo.color}`}>
                                  {typeInfo.label}
                                </Badge>
                              </div>
                            </TableCell>
                            <TableCell className="font-medium text-sm">{mov.product.name}</TableCell>
                            <TableCell className="text-sm text-muted-foreground">
                              {mov.warehouse?.name || '—'}
                            </TableCell>
                            <TableCell
                              className={`font-medium ${
                                mov.movementType === 'in' || mov.movementType === 'return'
                                  ? 'text-emerald-700'
                                  : mov.movementType === 'out'
                                  ? 'text-red-700'
                                  : ''
                              }`}
                            >
                              {(mov.movementType === 'in' || mov.movementType === 'return')
                                ? '+'
                                : mov.movementType === 'out'
                                ? '-'
                                : ''}
                              {mov.quantity} {mov.product.unit || ''}
                            </TableCell>
                            <TableCell className="text-sm text-muted-foreground">
                              {mov.notes || '—'}
                            </TableCell>
                            <TableCell className="text-xs text-muted-foreground">
                              {new Date(mov.createdAt).toLocaleDateString(locale)}
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
        </TabsContent>

        {/* ── Tab 2: Product Movement ── */}
        <TabsContent value="product-movement" className="space-y-4">
          <Card>
            <CardContent className="p-4">
              <div className="flex flex-col sm:flex-row gap-3 items-start sm:items-center">
                <Label className="whitespace-nowrap text-sm font-medium">{t('inventory_select_product_label')}</Label>
                <Select
                  value={selectedProductId}
                  onValueChange={(val) => setSelectedProductId(val)}
                >
                  <SelectTrigger className="w-full sm:w-64">
                    <Search className="h-4 w-4 ml-2 text-muted-foreground" />
                    <SelectValue placeholder={t('inventory_select_product_movement')} />
                  </SelectTrigger>
                  <SelectContent>
                    {products.map((p) => (
                      <SelectItem key={p.id} value={String(p.id)}>
                        {p.name} ({t('inventory_stock_label')} {p.stockQuantity})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </CardContent>
          </Card>

          {!selectedProductId ? (
            <Card>
              <CardContent className="py-16">
                <div className="flex flex-col items-center justify-center text-muted-foreground">
                  <History className="h-16 w-16 mb-4 opacity-20" />
                  <p className="text-lg font-medium">{t('inventory_select_product_movement_msg')}</p>
                  <p className="text-sm mt-1">
                    {t('inventory_product_movement_hint')}
                  </p>
                </div>
              </CardContent>
            </Card>
          ) : movementLoading && productMovementRows.length === 0 ? (
            <Card>
              <CardContent className="py-12">
                <div className="flex items-center justify-center">
                  <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
                </div>
              </CardContent>
            </Card>
          ) : productMovementRows.length === 0 ? (
            <Card>
              <CardContent className="py-12">
                <div className="flex flex-col items-center justify-center text-muted-foreground">
                  <FileText className="h-12 w-12 mb-3 opacity-30" />
                  <p>{t('inventory_no_product_movements')}</p>
                </div>
              </CardContent>
            </Card>
          ) : (
            <Card>
              <CardHeader>
                <CardTitle className="text-base flex items-center gap-2">
                  <History className="h-5 w-5 text-emerald-600" />
                  {t('inventory_product_movement_title')}: {products.find((p) => String(p.id) === selectedProductId)?.name}
                </CardTitle>
                <CardDescription>
                  {t('inventory_movement_all_desc')}
                </CardDescription>
              </CardHeader>
              <CardContent className="p-0">
                <div className="overflow-x-auto max-h-[500px] overflow-y-auto">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead className="text-right">#</TableHead>
                        <TableHead className="text-right">{t('date')}</TableHead>
                        <TableHead className="text-right">{t('inventory_movement_type')}</TableHead>
                        <TableHead className="text-right">{t('ledger_reference')}</TableHead>
                        <TableHead className="text-right">{t('inventory_quantity_label')}</TableHead>
                        <TableHead className="text-right">{t('inventory_running_balance')}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {productMovementRows.map((row, idx) => (
                        <TableRow key={idx}>
                          <TableCell className="text-xs text-muted-foreground">
                            {idx + 1}
                          </TableCell>
                          <TableCell className="text-xs text-muted-foreground whitespace-nowrap">
                            {new Date(row.date).toLocaleDateString(locale, {
                              year: 'numeric',
                              month: 'short',
                              day: 'numeric',
                            })}
                          </TableCell>
                          <TableCell>
                            {getMovementTypeBadge(row.type, row.typeLabel)}
                          </TableCell>
                          <TableCell className="text-sm font-medium">
                            {row.reference}
                          </TableCell>
                          <TableCell
                            className={`font-medium ${
                              row.quantityEffect === 'in'
                                ? 'text-emerald-700'
                                : row.quantityEffect === 'out'
                                ? 'text-red-700'
                                : 'text-amber-700'
                            }`}
                          >
                            {row.quantityEffect === 'in' ? '+' : row.quantityEffect === 'out' ? '-' : ''}
                            {row.quantity}
                          </TableCell>
                          <TableCell className="font-bold text-sm">
                            <Badge
                              variant="outline"
                              className={`font-mono ${
                                row.runningBalance > 0
                                  ? 'border-emerald-300 text-emerald-700'
                                  : row.runningBalance < 0
                                  ? 'border-red-300 text-red-700'
                                  : 'border-gray-300 text-gray-700'
                              }`}
                            >
                              {row.runningBalance}
                            </Badge>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>
      </Tabs>

      {/* ── Add Movement Dialog ── */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-md" dir={dir}>
          <DialogHeader>
            <DialogTitle>{t('inventory_new_movement_title')}</DialogTitle>
            <DialogDescription>{t('inventory_new_movement_desc')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label>{t('inventory_product_name')} *</Label>
              <Select
                value={form.productId}
                onValueChange={(val) => setForm({ ...form, productId: val })}
              >
                <SelectTrigger>
                  <SelectValue placeholder={t('inventory_select_product_placeholder')} />
                </SelectTrigger>
                <SelectContent>
                  {products.map((p) => (
                    <SelectItem key={p.id} value={String(p.id)}>
                      {p.name} ({t('inventory_stock_label')} {p.stockQuantity})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>{t('inventory_movement_type')} *</Label>
              <Select
                value={form.movementType}
                onValueChange={(val) => setForm({ ...form, movementType: val })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="in">{t('inventory_movement_in')}</SelectItem>
                  <SelectItem value="out">{t('inventory_movement_out')}</SelectItem>
                  <SelectItem value="transfer">{t('inventory_movement_transfer')}</SelectItem>
                  <SelectItem value="adjustment">{t('inventory_movement_adjustment')}</SelectItem>
                  <SelectItem value="return">{t('inventory_movement_return')}</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>{t('inventory_quantity_label')} *</Label>
                <Input
                  type="number"
                  value={form.quantity}
                  onChange={(e) => setForm({ ...form, quantity: e.target.value })}
                  placeholder="0"
                />
              </div>
              <div className="space-y-2">
                <Label>{t('inventory_warehouse_optional')}</Label>
                <Select
                  value={form.warehouseId}
                  onValueChange={(val) => setForm({ ...form, warehouseId: val })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder={t('inventory_warehouse_optional')} />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none">{t('inventory_no_warehouse')}</SelectItem>
                    {warehouses.map((w) => (
                      <SelectItem key={w.id} value={String(w.id)}>
                        {w.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('inventory_notes_label')}</Label>
              <Input
                value={form.notes}
                onChange={(e) => setForm({ ...form, notes: e.target.value })}
                placeholder={t('inventory_additional_notes')}
              />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setDialogOpen(false)}>
              {t('cancel')}
            </Button>
            <Button
              onClick={handleSubmit}
              className="bg-emerald-600 hover:bg-emerald-700"
              disabled={saving || !form.productId || !form.quantity}
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {t('inventory_register_movement')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ── Stocktake Dialog ── */}
      <Dialog open={stocktakeOpen} onOpenChange={setStocktakeOpen}>
        <DialogContent className="max-w-4xl max-h-[90vh]" dir={dir}>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <ClipboardCheck className="h-5 w-5 text-amber-600" />
              {t('inventory_stocktake_title')}
            </DialogTitle>
            <DialogDescription>
              {t('inventory_stocktake_desc')}
            </DialogDescription>
          </DialogHeader>

          {/* Warehouse & Date Selectors */}
          <div className="flex flex-wrap gap-3 items-end">
            <div className="space-y-1.5 flex-1 min-w-[180px]">
              <Label className="text-sm font-medium">{t('inventory_stocktake_warehouse')}</Label>
              <Select value={stocktakeWarehouseId} onValueChange={setStocktakeWarehouseId}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">{t('inventory_stocktake_all_warehouses')}</SelectItem>
                  {warehouses.map((w) => (
                    <SelectItem key={w.id} value={String(w.id)}>
                      {w.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5 flex-1 min-w-[180px]">
              <Label className="text-sm font-medium">{t('inventory_stocktake_date')}</Label>
              <div className="relative">
                <Calendar className="absolute start-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  type="date"
                  className="ps-9"
                  value={stocktakeDate}
                  onChange={(e) => setStocktakeDate(e.target.value)}
                />
              </div>
            </div>
          </div>

          <div className="overflow-x-auto max-h-[45vh] overflow-y-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="text-right">#</TableHead>
                  <TableHead className="text-right">{t('inventory_product_name')}</TableHead>
                  <TableHead className="text-center">{t('inventory_book_stock')}</TableHead>
                  <TableHead className="text-center">{t('inventory_counted_stock')}</TableHead>
                  <TableHead className="text-center">{t('inventory_difference')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {getFilteredStocktakeItems.map((item, idx) => (
                  <TableRow key={item.productId}>
                    <TableCell className="text-xs text-muted-foreground">{idx + 1}</TableCell>
                    <TableCell className="font-medium text-sm">{item.productName}</TableCell>
                    <TableCell className="text-center font-mono">{item.bookStock}</TableCell>
                    <TableCell className="text-center">
                      <Input
                        type="number"
                        className="w-24 text-center mx-auto"
                        value={item.countedStock}
                        onChange={(e) =>
                          handleCountedStockChange(item.productId, e.target.value)
                        }
                        placeholder="0"
                      />
                    </TableCell>
                    <TableCell className="text-center">
                      {item.countedStock === '' ? (
                        <span className="text-muted-foreground">—</span>
                      ) : (
                        <span
                          className={`font-bold font-mono ${
                            item.difference === 0
                              ? 'text-emerald-600'
                              : item.difference > 0
                              ? 'text-sky-600'
                              : 'text-red-600'
                          }`}
                        >
                          {item.difference > 0 ? '+' : ''}
                          {item.difference}
                        </span>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
                {getFilteredStocktakeItems.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={5} className="text-center py-8 text-muted-foreground">
                      {t('no_data')}
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>

          {/* Summary */}
          {stocktakeCalculated && (
            <div className="flex flex-wrap gap-4 mt-2 p-3 bg-muted/50 rounded-lg text-sm">
              <div>
                <span className="text-muted-foreground">{t('inventory_all_products')}: </span>
                <span className="font-bold">{getFilteredStocktakeItems.length}</span>
              </div>
              <div>
                <span className="text-muted-foreground">{t('inventory_apply_stocktake')}: </span>
                <span className="font-bold text-emerald-600">
                  {getFilteredStocktakeItems.filter((i) => i.countedStock !== '' && i.difference === 0).length}
                </span>
              </div>
              <div>
                <span className="text-muted-foreground">{t('inventory_difference')}: </span>
                <span className="font-bold text-red-600">
                  {getFilteredStocktakeItems.filter((i) => i.countedStock !== '' && i.difference !== 0).length}
                </span>
              </div>
              <div>
                <span className="text-muted-foreground">{t('inventory_stocktake')}: </span>
                <span className="font-bold text-amber-600">
                  {getFilteredStocktakeItems.filter((i) => i.countedStock === '').length}
                </span>
              </div>
            </div>
          )}

          {/* Post-apply info messages */}
          {stocktakeApplied && (
            <div className="space-y-2 mt-2">
              <div className="flex items-start gap-2 p-3 bg-sky-50 dark:bg-sky-950/30 rounded-lg text-sm text-sky-700 dark:text-sky-300">
                <Info className="h-4 w-4 mt-0.5 shrink-0" />
                <span>{t('inventory_stocktake_applied_info')}</span>
              </div>
              <div className="flex items-start gap-2 p-3 bg-amber-50 dark:bg-amber-950/30 rounded-lg text-sm text-amber-700 dark:text-amber-300">
                <Info className="h-4 w-4 mt-0.5 shrink-0" />
                <span>{t('inventory_stocktake_new_year')}</span>
              </div>
            </div>
          )}

          <DialogFooter className="gap-2 flex-wrap">
            <Button variant="outline" onClick={() => setStocktakeOpen(false)}>
              {t('cancel')}
            </Button>
            {stocktakeApplied && emptyProducts.length > 0 && (
              <Button
                variant="destructive"
                className="gap-2"
                onClick={() => setDeleteEmptyOpen(true)}
              >
                <Trash2 className="h-4 w-4" />
                {t('inventory_delete_empty_materials')} ({emptyProducts.length})
              </Button>
            )}
            <Button
              variant="secondary"
              onClick={calculateStocktake}
              className="gap-2"
            >
              <Calculator className="h-4 w-4" />
              {t('inventory_calculate')}
            </Button>
            <Button
              onClick={handleApplyStocktake}
              className="gap-2 bg-amber-600 hover:bg-amber-700"
              disabled={stocktakeSaving || !stocktakeCalculated}
            >
              {stocktakeSaving ? (
                <Loader2 className="h-4 w-4 animate-spin ml-2" />
              ) : (
                <Save className="h-4 w-4" />
              )}
              {t('inventory_apply_stocktake')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ── Stocktake Warning Dialog ── */}
      <AlertDialog open={stocktakeWarningOpen} onOpenChange={setStocktakeWarningOpen}>
        <AlertDialogContent dir={dir}>
          <AlertDialogHeader>
            <AlertDialogTitle className="flex items-center gap-2 text-red-700">
              <AlertTriangle className="h-5 w-5" />
              {t('inventory_stocktake_warning_title')}
            </AlertDialogTitle>
            <AlertDialogDescription>
              {t('inventory_stocktake_warning_message')}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('cancel')}</AlertDialogCancel>
            <AlertDialogAction onClick={handleWarningConfirm} className="bg-amber-600 hover:bg-amber-700">
              {t('confirm')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* ── Uncounted Items Warning Dialog ── */}
      <AlertDialog open={stocktakeUncountedOpen} onOpenChange={setStocktakeUncountedOpen}>
        <AlertDialogContent dir={dir} className="max-w-lg">
          <AlertDialogHeader>
            <AlertDialogTitle className="flex items-center gap-2 text-amber-700">
              <AlertTriangle className="h-5 w-5" />
              {t('inventory_stocktake_warning_title')}
            </AlertDialogTitle>
            <AlertDialogDescription asChild>
              <div className="space-y-2">
                <p>{t('inventory_stocktake_uncounted_warning')}</p>
                <div className="max-h-40 overflow-y-auto rounded-md border p-2 bg-muted/30">
                  {getFilteredStocktakeItems
                    .filter((item) => item.countedStock === '')
                    .map((item) => (
                      <div key={item.productId} className="flex justify-between py-1 text-sm">
                        <span className="font-medium">{item.productName}</span>
                        <span className="text-muted-foreground">
                          {t('inventory_book_stock')}: {item.bookStock}
                        </span>
                      </div>
                    ))}
                </div>
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('cancel')}</AlertDialogCancel>
            <AlertDialogAction onClick={handleUncountedProceed} className="bg-amber-600 hover:bg-amber-700">
              {t('confirm')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* ── Delete Empty Materials Dialog ── */}
      <AlertDialog open={deleteEmptyOpen} onOpenChange={setDeleteEmptyOpen}>
        <AlertDialogContent dir={dir} className="max-w-lg">
          <AlertDialogHeader>
            <AlertDialogTitle className="flex items-center gap-2 text-red-700">
              <Trash2 className="h-5 w-5" />
              {t('inventory_delete_empty_materials')}
            </AlertDialogTitle>
            <AlertDialogDescription asChild>
              <div className="space-y-2">
                <p>{t('inventory_delete_empty_confirm')}</p>
                <div className="flex items-center gap-2 text-sm">
                  <Badge variant="secondary" className="bg-red-100 text-red-700">
                    {t('inventory_empty_products_count')}: {emptyProducts.length}
                  </Badge>
                </div>
                {emptyProducts.length > 0 && (
                  <div className="max-h-40 overflow-y-auto rounded-md border p-2 bg-muted/30">
                    {emptyProducts.map((p) => (
                      <div key={p.id} className="flex justify-between py-1 text-sm">
                        <span className="font-medium">{p.name}</span>
                        <span className="text-red-600 font-mono">0</span>
                      </div>
                    ))}
                  </div>
                )}
                {emptyProducts.length === 0 && (
                  <p className="text-muted-foreground text-sm">{t('inventory_no_empty_products')}</p>
                )}
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('cancel')}</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteEmptyMaterials}
              disabled={deletingEmpty || emptyProducts.length === 0}
              className="bg-red-600 hover:bg-red-700"
            >
              {deletingEmpty ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
              {t('delete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
