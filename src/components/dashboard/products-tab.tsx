'use client'

import { useState, useEffect } from 'react'
import {
  Plus,
  Package,
  Pencil,
  Trash2,
  Search,
  Loader2,
  AlertTriangle,
  GitMerge,
  Ban,
} from 'lucide-react'
import {
  Card,
  CardContent,
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

interface ProductCategory {
  id: number
  name: string
}

interface Supplier {
  id: number
  name: string
}

interface Product {
  id: number
  businessId: string
  name: string
  price: number
  costPrice: number
  discountPrice: number | null
  stockQuantity: number
  category: string | null
  categoryId: number | null
  supplierId: number | null
  unit: string | null
  description: string | null
  isActive: boolean
  isFeatured: boolean
}

const sampleProducts: Product[] = [
  { id: 1, businessId: '1', name: 'أنبوب PVC 4 بوصة', price: 3.5, costPrice: 2, discountPrice: null, stockQuantity: 150, category: 'سباكة', categoryId: null, supplierId: null, unit: 'قطعة', description: 'أنبوب PVC عالي الجودة', isActive: true, isFeatured: false },
  { id: 2, businessId: '1', name: 'صنبور كروم', price: 12, costPrice: 7, discountPrice: 10, stockQuantity: 45, category: 'سباكة', categoryId: null, supplierId: null, unit: 'قطعة', description: 'صنبور كروم تركي', isActive: true, isFeatured: true },
  { id: 3, businessId: '1', name: 'كابل كهربائي 2.5mm', price: 8, costPrice: 5, discountPrice: null, stockQuantity: 200, category: 'كهرباء', categoryId: null, supplierId: null, unit: 'متر', description: 'كابل نحاس معتمد', isActive: true, isFeatured: false },
  { id: 4, businessId: '1', name: 'مفتاح كهربائي', price: 2.5, costPrice: 1.2, discountPrice: null, stockQuantity: 3, category: 'كهرباء', categoryId: null, supplierId: null, unit: 'قطعة', description: 'مفتاح أحادي', isActive: true, isFeatured: false },
  { id: 5, businessId: '1', name: 'دهان بلاستيك أبيض', price: 15, costPrice: 9, discountPrice: 13, stockQuantity: 30, category: 'دهان', categoryId: null, supplierId: null, unit: 'جالون', description: 'دهان بلاستيك جوهر', isActive: true, isFeatured: true },
  { id: 6, businessId: '1', name: 'فلتر مكيف سبليت', price: 5, costPrice: 2.5, discountPrice: null, stockQuantity: 80, category: 'تكييف', categoryId: null, supplierId: null, unit: 'قطعة', description: 'فلتر هواء أصلي', isActive: true, isFeatured: false },
  { id: 7, businessId: '1', name: 'خشب زان', price: 25, costPrice: 18, discountPrice: null, stockQuantity: 20, category: 'نجارة', categoryId: null, supplierId: null, unit: 'متر', description: 'خشب زان طبيعي', isActive: true, isFeatured: false },
  { id: 8, businessId: '1', name: 'مادة تنظيف أرضيات', price: 4, costPrice: 2, discountPrice: 3.5, stockQuantity: 60, category: 'تنظيف', categoryId: null, supplierId: null, unit: 'لتر', description: 'مادة تنظيف معطرة', isActive: true, isFeatured: false },
]

const defaultForm = {
  name: '',
  price: '',
  costPrice: '',
  stockQuantity: '',
  category: '',
  categoryId: '',
  supplierId: '',
  unit: 'piece',
  description: '',
}

export function ProductsTab({ initialEditId }: { initialEditId?: string | null } = {}) {
  const { t, lang, dir } = useLanguage()
  const [products, setProducts] = useState<Product[]>(sampleProducts)
  const [productCategories, setProductCategories] = useState<ProductCategory[]>([])
  const [suppliers, setSuppliers] = useState<Supplier[]>([])
  const [search, setSearch] = useState('')
  const [dialogOpen, setDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [deleteError, setDeleteError] = useState<string | null>(null)
  const [editingProduct, setEditingProduct] = useState<Product | null>(null)
  const [form, setForm] = useState(defaultForm)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [deactivating, setDeactivating] = useState(false)

  // Merge state
  const [mergeDialogOpen, setMergeDialogOpen] = useState(false)
  const [mergeSource, setMergeSource] = useState<Product | null>(null)
  const [mergeTargetSearch, setMergeTargetSearch] = useState('')
  const [mergeTargetId, setMergeTargetId] = useState<string>('')
  const [mergeSaving, setMergeSaving] = useState(false)

  const businessId = getBusinessId()

  useEffect(() => {
    async function fetchProducts() {
      setLoading(true)
      try {
        const [prodRes, catRes, supRes] = await Promise.all([
          fetch(`/api/products?businessId=${businessId}`),
          fetch(`/api/product-categories?businessId=${businessId}`),
          fetch(`/api/suppliers?businessId=${businessId}`),
        ])
        if (prodRes.ok) {
          const data = await prodRes.json()
          if (data.length > 0) setProducts(data)
        }
        if (catRes.ok) {
          const data = await catRes.json()
          // Flatten categories
          const flat: ProductCategory[] = []
          const flatten = (cats: any[]) => {
            for (const c of cats) {
              flat.push({ id: c.id, name: c.name })
              if (c.children) flatten(c.children)
            }
          }
          flatten(data)
          setProductCategories(flat)
        }
        if (supRes.ok) {
          const data = await supRes.json()
          setSuppliers(data.map((s: any) => ({ id: s.id, name: s.name })))
        }
      } catch {
        // Keep sample data
      } finally {
        setLoading(false)
      }
    }
    fetchProducts()
  }, [businessId])

  // Open edit dialog if initialEditId is provided (e.g. from URL ?edit=123)
  useEffect(() => {
    if (initialEditId && products.length > 0) {
      const product = products.find((p) => String(p.id) === initialEditId)
      if (product) {
        openEdit(product)
      }
    }
  }, [initialEditId, products])

  const filteredProducts = products.filter(
    (p) =>
      p.name.includes(search) ||
      (p.category && p.category.includes(search))
  )

  const openCreate = () => {
    setEditingProduct(null)
    setForm(defaultForm)
    setDialogOpen(true)
  }

  const openEdit = (product: Product) => {
    setEditingProduct(product)
    setForm({
      name: product.name,
      price: String(product.price),
      costPrice: String(product.costPrice),
      stockQuantity: String(product.stockQuantity),
      category: product.category || '',
      categoryId: product.categoryId ? String(product.categoryId) : '',
      supplierId: product.supplierId ? String(product.supplierId) : '',
      unit: product.unit || 'piece',
      description: product.description || '',
    })
    setDialogOpen(true)
  }

  const handleSubmit = async () => {
    setSaving(true)
    try {
      const url = editingProduct
        ? `/api/products/${editingProduct.id}`
        : '/api/products'
      const method = editingProduct ? 'PUT' : 'POST'

      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          name: form.name,
          price: parseFloat(form.price) || 0,
          costPrice: parseFloat(form.costPrice) || 0,
          stockQuantity: parseInt(form.stockQuantity) || 0,
          category: form.category,
          categoryId: form.categoryId ? parseInt(form.categoryId) : null,
          supplierId: form.supplierId ? parseInt(form.supplierId) : null,
          unit: form.unit,
          description: form.description,
        }),
      })

      if (res.ok) {
        const saved = await res.json()
        if (editingProduct) {
          setProducts((prev) =>
            prev.map((p) => (p.id === saved.id ? saved : p))
          )
          toast.success(t('products_update_success'))
        } else {
          setProducts((prev) => [saved, ...prev])
          toast.success(t('products_add_success'))
        }
        setDialogOpen(false)
      } else {
        const err = await res.json()
        toast.error(err.error || t('products_save_failed'))
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
      const res = await fetch(`/api/products/${deletingId}`, { method: 'DELETE' })
      if (res.ok) {
        setProducts((prev) => prev.filter((p) => p.id !== deletingId))
        toast.success(t('products_delete_success'))
        setDeleteDialogOpen(false)
        setDeletingId(null)
      } else {
        const err = await res.json()
        setDeleteError(err.error || t('products_delete_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    }
  }

  const handleDeactivate = async () => {
    if (!deletingId) return
    setDeactivating(true)
    try {
      const res = await fetch(`/api/products/${deletingId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isActive: false }),
      })
      if (res.ok) {
        const updated = await res.json()
        setProducts((prev) => prev.map((p) => (p.id === updated.id ? updated : p)))
        toast.success(t('products_deactivate_success'))
        setDeleteDialogOpen(false)
        setDeletingId(null)
        setDeleteError(null)
      } else {
        toast.error(t('products_deactivate_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setDeactivating(false)
    }
  }

  // Merge handlers
  const openMerge = (product: Product) => {
    setMergeSource(product)
    setMergeTargetId('')
    setMergeTargetSearch('')
    setMergeDialogOpen(true)
  }

  const mergeTargetProduct = products.find((p) => String(p.id) === mergeTargetId)

  const filteredMergeTargets = products.filter(
    (p) =>
      p.id !== mergeSource?.id &&
      p.isActive &&
      (p.name.includes(mergeTargetSearch) ||
        (p.category && p.category.includes(mergeTargetSearch)))
  )

  const handleMerge = async () => {
    if (!mergeSource || !mergeTargetId) return
    setMergeSaving(true)
    try {
      const res = await fetch('/api/products/merge', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sourceProductId: mergeSource.id,
          targetProductId: parseInt(mergeTargetId),
          businessId,
        }),
      })

      if (res.ok) {
        // Refresh products list
        const prodRes = await fetch(`/api/products?businessId=${businessId}`)
        if (prodRes.ok) {
          const data = await prodRes.json()
          if (data.length > 0) setProducts(data)
        }
        toast.success(t('products_merge_success'))
        setMergeDialogOpen(false)
        setMergeSource(null)
        setMergeTargetId('')
      } else {
        const err = await res.json()
        toast.error(err.error || t('products_merge_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setMergeSaving(false)
    }
  }

  const isLowStock = (qty: number) => qty <= 5

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('products_title')}</h2>
          <p className="text-muted-foreground">{t('nav_inventory_mgmt')}</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="relative">
            <Search className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder={`${t('search')}...`}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-48 pr-9 sm:w-64"
            />
          </div>
          <Button
            onClick={openCreate}
            className="gap-2 bg-emerald-600 hover:bg-emerald-700"
          >
            <Plus className="h-4 w-4" />
            {t('products_new')}
          </Button>
        </div>
      </div>

      {/* Product Grid */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
        </div>
      ) : filteredProducts.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
          <Package className="h-12 w-12 mb-3 opacity-30" />
          <p>{t('no_data')}</p>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {filteredProducts.map((product) => (
            <Card
              key={product.id}
              className={`group relative overflow-hidden transition-shadow hover:shadow-md ${!product.isActive ? 'opacity-60' : ''}`}
            >
              {/* Product Image Placeholder */}
              <div className="flex h-36 items-center justify-center bg-gradient-to-br from-emerald-50 to-emerald-100">
                <Package className="h-12 w-12 text-emerald-300" />
                {product.isFeatured && (
                  <Badge className="absolute top-2 left-2 bg-amber-500 text-white text-[10px]">
                    {t('products_featured')}
                  </Badge>
                )}
                {isLowStock(product.stockQuantity) && product.isActive && (
                  <Badge className="absolute top-2 right-2 bg-red-500 text-white text-[10px] gap-1">
                    <AlertTriangle className="h-3 w-3" />
                    {t('products_low_stock')}
                  </Badge>
                )}
                {!product.isActive && (
                  <Badge className="absolute top-2 right-2 bg-gray-500 text-white text-[10px] gap-1">
                    <Ban className="h-3 w-3" />
                    {t('products_deactivate')}
                  </Badge>
                )}
              </div>
              <CardContent className="p-4">
                <div className="space-y-2">
                  <div className="flex items-start justify-between">
                    <h3 className="font-semibold text-sm line-clamp-1">
                      {product.name}
                    </h3>
                  </div>
                  {product.category && (
                    <Badge variant="outline" className="text-[10px]">
                      {product.category}
                    </Badge>
                  )}
                  <div className="flex items-center justify-between">
                    <div>
                      <span className="text-lg font-bold text-emerald-700">
                        {product.price}
                      </span>
                      <span className="text-xs text-muted-foreground mr-1">
                        {t('currency')}
                      </span>
                      {product.discountPrice && (
                        <span className="text-xs text-muted-foreground line-through mr-1">
                          {product.discountPrice}
                        </span>
                      )}
                    </div>

                  </div>
                  <div className="flex gap-1 pt-1">
                    <Button
                      variant="outline"
                      size="sm"
                      className="flex-1 gap-1 text-xs h-8"
                      onClick={() => openEdit(product)}
                    >
                      <Pencil className="h-3 w-3" />
                      {t('edit')}
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      className="gap-1 text-xs h-8 text-orange-600 hover:text-orange-700 hover:bg-orange-50"
                      onClick={() => openMerge(product)}
                      title={t('products_merge')}
                    >
                      <GitMerge className="h-3 w-3" />
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      className="gap-1 text-xs h-8 text-red-600 hover:text-red-700 hover:bg-red-50"
                      onClick={() => confirmDelete(product.id)}
                    >
                      <Trash2 className="h-3 w-3" />
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Create/Edit Product Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-md" dir={dir}>
          <DialogHeader>
            <DialogTitle>
              {editingProduct ? t('edit') : t('products_new')}
            </DialogTitle>
            <DialogDescription>
              {editingProduct
                ? t('products_edit_desc')
                : t('products_add_desc')}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="name">{t('products_name')} *</Label>
              <Input
                id="name"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder={t('products_name')}
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label htmlFor="price">{t('products_price')} *</Label>
                <Input
                  id="price"
                  type="number"
                  value={form.price}
                  onChange={(e) => setForm({ ...form, price: e.target.value })}
                  placeholder="0"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="costPrice">{t('products_cost_price')}</Label>
                <Input
                  id="costPrice"
                  type="number"
                  value={form.costPrice}
                  onChange={(e) =>
                    setForm({ ...form, costPrice: e.target.value })
                  }
                  placeholder="0"
                />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label htmlFor="stock">{t('products_stock')}</Label>
                <Input
                  id="stock"
                  type="number"
                  value={form.stockQuantity}
                  onChange={(e) =>
                    setForm({ ...form, stockQuantity: e.target.value })
                  }
                  placeholder="0"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="unit">{t('products_unit')}</Label>
                <Select
                  value={form.unit}
                  onValueChange={(val) => setForm({ ...form, unit: val })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="piece">{t('unit_piece')}</SelectItem>
                    <SelectItem value="meter">{t('unit_meter')}</SelectItem>
                    <SelectItem value="kilo">{t('unit_kilo')}</SelectItem>
                    <SelectItem value="liter">{t('unit_liter')}</SelectItem>
                    <SelectItem value="gallon">{t('unit_gallon')}</SelectItem>
                    <SelectItem value="box">{t('unit_box')}</SelectItem>
                    <SelectItem value="roll">{t('unit_roll')}</SelectItem>
                    <SelectItem value="pack">{t('unit_pack')}</SelectItem>
                    <SelectItem value="piece_unit">{t('unit_piece_unit')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="category">{t('products_category')}</Label>
              <Select
                value={form.categoryId}
                onValueChange={(val) => {
                  const cat = productCategories.find((c) => String(c.id) === val)
                  setForm({ ...form, categoryId: val, category: cat?.name || form.category })
                }}
              >
                <SelectTrigger>
                  <SelectValue placeholder={t('products_select_category')} />
                </SelectTrigger>
                <SelectContent>
                  {productCategories.map((cat) => (
                    <SelectItem key={cat.id} value={String(cat.id)}>{cat.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="supplier">{t('products_supplier')}</Label>
              <Select
                value={form.supplierId}
                onValueChange={(val) => setForm({ ...form, supplierId: val })}
              >
                <SelectTrigger>
                  <SelectValue placeholder={t('products_select_supplier')} />
                </SelectTrigger>
                <SelectContent>
                  {suppliers.map((sup) => (
                    <SelectItem key={sup.id} value={String(sup.id)}>{sup.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="desc">{t('products_description')}</Label>
              <Input
                id="desc"
                value={form.description}
                onChange={(e) =>
                  setForm({ ...form, description: e.target.value })
                }
                placeholder={t('products_desc_placeholder')}
              />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button
              variant="outline"
              onClick={() => setDialogOpen(false)}
            >{t('cancel')}</Button>
            <Button
              onClick={handleSubmit}
              className="bg-emerald-600 hover:bg-emerald-700"
              disabled={saving || !form.name || !form.price}
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {editingProduct ? t('save_changes') : t('products_add_btn')}
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
            <AlertDialogTitle>{t('products_delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>
              {deleteError ? (
                <span className="text-red-600 font-medium">{deleteError}</span>
              ) : (
                t('products_delete_irreversible')
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter className="flex-col gap-2 sm:flex-row">
            <AlertDialogCancel>{t('cancel')}</AlertDialogCancel>
            {deleteError && (
              <Button
                onClick={handleDeactivate}
                disabled={deactivating}
                className="bg-amber-600 hover:bg-amber-700 text-white"
              >
                {deactivating ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : <Ban className="h-4 w-4 ml-2" />}
                {t('products_deactivate_instead')}
              </Button>
            )}
            {!deleteError && (
              <AlertDialogAction onClick={handleDelete} className="bg-red-600 hover:bg-red-700">{t('delete')}</AlertDialogAction>
            )}
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Merge Dialog */}
      <Dialog open={mergeDialogOpen} onOpenChange={setMergeDialogOpen}>
        <DialogContent className="max-w-lg" dir={dir}>
          <DialogHeader>
            <DialogTitle>{t('products_merge_title')}</DialogTitle>
            <DialogDescription>{t('products_merge_desc')}</DialogDescription>
          </DialogHeader>
          {mergeSource && (
            <div className="space-y-4">
              {/* Source Product Info */}
              <div className="rounded-lg border p-4 bg-muted/50">
                <Label className="text-xs text-muted-foreground">{t('products_source_product')}</Label>
                <div className="flex items-center justify-between mt-1">
                  <span className="font-semibold">{mergeSource.name}</span>
                  <span className="text-sm text-muted-foreground">
                    {t('products_stock_label')}: {mergeSource.stockQuantity} | {t('products_price')}: {mergeSource.price} {t('currency')}
                  </span>
                </div>
              </div>

              {/* Arrow */}
              <div className="flex justify-center">
                <GitMerge className="h-6 w-6 text-orange-500 rotate-90" />
              </div>

              {/* Target Product Search & Select */}
              <div className="space-y-2">
                <Label>{t('products_target_product')}</Label>
                <Input
                  placeholder={t('products_search_target')}
                  value={mergeTargetSearch}
                  onChange={(e) => setMergeTargetSearch(e.target.value)}
                />
                <Select
                  value={mergeTargetId}
                  onValueChange={setMergeTargetId}
                >
                  <SelectTrigger>
                    <SelectValue placeholder={t('products_select_target')} />
                  </SelectTrigger>
                  <SelectContent>
                    {filteredMergeTargets.map((p) => (
                      <SelectItem key={p.id} value={String(p.id)}>
                        {p.name} - {p.price} {t('currency')} ({t('products_stock_label')}: {p.stockQuantity})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {/* Selected Target Preview */}
              {mergeTargetProduct && (
                <div className="rounded-lg border p-4 bg-emerald-50 border-emerald-200">
                  <Label className="text-xs text-emerald-700">{t('products_selected_target')}</Label>
                  <div className="flex items-center justify-between mt-1">
                    <span className="font-semibold text-emerald-900">{mergeTargetProduct.name}</span>
                    <span className="text-sm text-emerald-700">
                      {t('products_stock_label')}: {mergeTargetProduct.stockQuantity} | {t('products_price')}: {mergeTargetProduct.price} {t('currency')}
                    </span>
                  </div>
                </div>
              )}

              {/* Warning */}
              <div className="rounded-lg border border-red-200 bg-red-50 p-4">
                <div className="flex gap-2">
                  <AlertTriangle className="h-5 w-5 text-red-600 shrink-0 mt-0.5" />
                  <div className="text-sm text-red-800">
                    <p className="font-bold mb-1">{t('products_warning')}</p>
                    <p>
                      {t('products_merge_warning_detail')} &quot;{mergeSource.name}&quot; {t('products_merge_and')} &quot;{mergeTargetProduct?.name || t('products_target_product')}&quot; {t('products_merge_deactivate')} &quot;{mergeSource.name}&quot;. {t('products_merge_irreversible')}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          )}
          <DialogFooter className="gap-2">
            <Button
              variant="outline"
              onClick={() => setMergeDialogOpen(false)}
              disabled={mergeSaving}
            >{t('cancel')}</Button>
            <Button
              onClick={handleMerge}
              disabled={mergeSaving || !mergeTargetId || !mergeSource}
              className="bg-red-600 hover:bg-red-700 text-white"
            >
              {mergeSaving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : <GitMerge className="h-4 w-4 ml-2" />}
              {t('products_merge_btn')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
