'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  Plus,
  FolderTree,
  Pencil,
  Trash2,
  ChevronDown,
  ChevronLeft,
  Loader2,
  FolderOpen,
  Folder,
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
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'

interface ProductCategory {
  id: number
  name: string
  nameEn: string | null
  parentId: number | null
  icon: string | null
  sortOrder: number
  isActive: boolean
  children?: ProductCategory[]
  _count?: { products: number }
}

const defaultForm = {
  name: '',
  nameEn: '',
  parentId: 'none',
  icon: '📦',
}

const iconOptions = ['📦', '🔧', '⚡', '🏗️', '🎨', '🪚', '❄️', '🧹', '🛠️', '💧', '🔌', '🔩', '🪣', '🏠', '🪜']

export function CategoriesTab() {
  const { t, lang, dir } = useLanguage()
  const [categories, setCategories] = useState<ProductCategory[]>([])
  const [expandedIds, setExpandedIds] = useState<Set<number>>(new Set())
  const [dialogOpen, setDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [editingCategory, setEditingCategory] = useState<ProductCategory | null>(null)
  const [form, setForm] = useState(defaultForm)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)

  const businessId = getBusinessId()

  const fetchCategories = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`/api/product-categories?businessId=${businessId}`)
      if (res.ok) {
        const data = await res.json()
        setCategories(data)
        // Auto-expand root categories
        setExpandedIds(new Set(data.map((c: ProductCategory) => c.id)))
      }
    } catch {
      // Keep empty
    } finally {
      setLoading(false)
    }
  }, [businessId])

  useEffect(() => {
    fetchCategories()
  }, [fetchCategories])

  const toggleExpand = (id: number) => {
    setExpandedIds((prev) => {
      const next = new Set(prev)
      if (next.has(id)) {
        next.delete(id)
      } else {
        next.add(id)
      }
      return next
    })
  }

  const openCreate = (parentId?: number) => {
    setEditingCategory(null)
    setForm({ ...defaultForm, parentId: parentId ? String(parentId) : 'none' })
    setDialogOpen(true)
  }

  const openEdit = (category: ProductCategory) => {
    setEditingCategory(category)
    setForm({
      name: category.name,
      nameEn: category.nameEn || '',
      parentId: category.parentId ? String(category.parentId) : 'none',
      icon: category.icon || '📦',
    })
    setDialogOpen(true)
  }

  const handleSubmit = async () => {
    if (!form.name) {
      toast.error(t('categories_name_required_msg'))
      return
    }
    setSaving(true)
    try {
      const res = await fetch('/api/product-categories', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          name: form.name,
          nameEn: form.nameEn || null,
          parentId: form.parentId !== 'none' ? parseInt(form.parentId) : null,
          icon: form.icon,
        }),
      })

      if (res.ok) {
        toast.success(t('categories_add_success'))
        setDialogOpen(false)
        fetchCategories()
      } else {
        const err = await res.json()
        toast.error(err.error || t('categories_save_failed'))
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
      const res = await fetch(`/api/product-categories?id=${deletingId}`, { method: 'DELETE' })
      if (res.ok) {
        toast.success(t('categories_delete_success'))
        fetchCategories()
      } else {
        toast.error(t('categories_delete_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setDeleteDialogOpen(false)
      setDeletingId(null)
    }
  }

  const renderCategory = (category: ProductCategory, depth: number = 0) => {
    const hasChildren = category.children && category.children.length > 0
    const isExpanded = expandedIds.has(category.id)
    const productCount = category._count?.products || 0

    return (
      <div key={category.id}>
        <div
          className={`flex items-center gap-2 py-2 px-3 rounded-lg hover:bg-gray-50 transition-colors ${
            depth > 0 ? 'mr-8' : ''
          }`}
        >
          <button
            onClick={() => hasChildren && toggleExpand(category.id)}
            className="flex items-center"
          >
            {hasChildren ? (
              isExpanded ? (
                <ChevronDown className="h-4 w-4 text-muted-foreground" />
              ) : (
                <ChevronLeft className="h-4 w-4 text-muted-foreground" />
              )
            ) : (
              <span className="w-4" />
            )}
          </button>
          <span className="text-lg">{category.icon || '📦'}</span>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <span className="font-medium text-sm truncate">{category.name}</span>
              <Badge variant="secondary" className="text-[10px]">
                {productCount} منتج
              </Badge>
              {!category.isActive && (
                <Badge variant="outline" className="text-[10px] text-red-600">
                  {t('employees_active_no')}
                </Badge>
              )}
            </div>
          </div>
          <div className="flex items-center gap-1">
            <Button
              variant="ghost"
              size="sm"
              className="h-7 w-7 p-0"
              onClick={() => openCreate(category.id)}
            >
              <Plus className="h-3.5 w-3.5" />
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="h-7 w-7 p-0"
              onClick={() => openEdit(category)}
            >
              <Pencil className="h-3.5 w-3.5" />
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="h-7 w-7 p-0 text-red-600 hover:text-red-700 hover:bg-red-50"
              onClick={() => confirmDelete(category.id)}
            >
              <Trash2 className="h-3.5 w-3.5" />
            </Button>
          </div>
        </div>
        {hasChildren && isExpanded && (
          <div>
            {category.children!.map((child) => renderCategory(child, depth + 1))}
          </div>
        )}
      </div>
    )
  }

  // Flatten categories for parent dropdown
  const flatCategories: { id: number; name: string }[] = []
  const flatten = (cats: ProductCategory[], prefix: string = '') => {
    for (const c of cats) {
      flatCategories.push({ id: c.id, name: prefix + c.name })
      if (c.children) flatten(c.children, prefix + c.name + ' / ')
    }
  }
  flatten(categories)

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('nav_categories')}</h2>
          <p className="text-muted-foreground">{t('categories_subtitle')}</p>
        </div>
        <Button
          onClick={() => openCreate()}
          className="gap-2 bg-emerald-600 hover:bg-emerald-700"
        >
          <Plus className="h-4 w-4" />{t('categories_add')}</Button>
      </div>

      {/* Categories Tree */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base flex items-center gap-2">
            <FolderTree className="h-5 w-5 text-emerald-600" />
            {t('categories_tree_title')}
          </CardTitle>
          <CardDescription>
            {t('categories_expand_hint')}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
            </div>
          ) : categories.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <FolderOpen className="h-12 w-12 mb-3 opacity-30" />
              <p>{t('categories_no_categories_msg')}</p>
              <Button
                variant="outline"
                size="sm"
                className="mt-3 gap-2"
                onClick={() => openCreate()}
              >
                <Plus className="h-4 w-4" />
                {t('categories_add_first')}
              </Button>
            </div>
          ) : (
            <div className="space-y-1">
              {categories.map((cat) => renderCategory(cat))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Create/Edit Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-md" dir={dir}>
          <DialogHeader>
            <DialogTitle>
              {editingCategory ? t('categories_edit') : t('categories_add_new')}
            </DialogTitle>
            <DialogDescription>
              {editingCategory
                ? t('categories_edit_data')
                : t('categories_enter_data')}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="name">{t('categories_name')} *</Label>
              <Input
                id="name"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder={t('categories_name_placeholder')}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="nameEn">{t('categories_name_en')}</Label>
              <Input
                id="nameEn"
                value={form.nameEn}
                onChange={(e) => setForm({ ...form, nameEn: e.target.value })}
                placeholder="Category name"
              />
            </div>
            <div className="space-y-2">
              <Label>{t('categories_parent')}</Label>
              <Select
                value={form.parentId}
                onValueChange={(val) => setForm({ ...form, parentId: val })}
              >
                <SelectTrigger>
                  <SelectValue placeholder={t('categories_root_category')} />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">{t('categories_root_no_parent')}</SelectItem>
                  {flatCategories
                    .filter((c) => c.id !== editingCategory?.id)
                    .map((c) => (
                      <SelectItem key={c.id} value={String(c.id)}>
                        {c.name}
                      </SelectItem>
                    ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>{t('categories_icon')}</Label>
              <div className="flex flex-wrap gap-2">
                {iconOptions.map((icon, idx) => (
                  <button
                    key={`icon-${idx}`}
                    className={`text-xl p-1.5 rounded-lg border transition-colors ${
                      form.icon === icon
                        ? 'border-emerald-500 bg-emerald-50'
                        : 'border-gray-200 hover:bg-gray-50'
                    }`}
                    onClick={() => setForm({ ...form, icon })}
                    type="button"
                  >
                    {icon}
                  </button>
                ))}
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
              {editingCategory ? t('save_changes') : t('categories_add_btn')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent dir="rtl">
          <AlertDialogHeader>
            <AlertDialogTitle>{t('categories_delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('categories_delete_subcategories')}
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
