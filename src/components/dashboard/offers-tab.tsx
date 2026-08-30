'use client'

import { useState, useEffect } from 'react'
import {
  Tag,
  Plus,
  Percent,
  Clock,
  Trash2,
  Loader2,
  Pencil,
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
import { toast } from 'sonner'
import { getBusinessId } from '@/lib/shop-utils'
import { useLanguage } from '@/lib/language-context'

interface Offer {
  id: number
  title: string
  description: string | null
  discountPercentage: number | null
  originalPrice: number | null
  offerPrice: number | null
  isActive: boolean
  startDate: string | null
  endDate: string | null
}

const sampleOffers: Offer[] = [
  { id: 1, title: 'عرض صيانة التكييف', description: 'خصم على صيانة جميع أنواع المكيفات', discountPercentage: 20, originalPrice: 65, offerPrice: 52, isActive: true, startDate: new Date().toISOString(), endDate: new Date(Date.now() + 30 * 86400000).toISOString() },
  { id: 2, title: 'عرض السباكة الشامل', description: 'فحص شامل + إصلاح التسريبات', discountPercentage: 15, originalPrice: 80, offerPrice: 68, isActive: true, startDate: new Date().toISOString(), endDate: new Date(Date.now() + 15 * 86400000).toISOString() },
  { id: 3, title: 'دهان غرفة مجاناً', description: 'اشترِ دهان ٣ غرف واحصل على الرابعة مجاناً', discountPercentage: 25, originalPrice: 400, offerPrice: 300, isActive: true, startDate: new Date(Date.now() - 7 * 86400000).toISOString(), endDate: new Date(Date.now() + 23 * 86400000).toISOString() },
  { id: 4, title: 'عرض الكهرباء السريع', description: 'إصلاح أعطال الكهرباء بخصم خاص', discountPercentage: 10, originalPrice: 50, offerPrice: 45, isActive: false, startDate: null, endDate: null },
  { id: 5, title: 'تنظيف ما بعد البناء', description: 'خدمة تنظيف شاملة بعد العزل والبناء', discountPercentage: 30, originalPrice: 120, offerPrice: 84, isActive: true, startDate: new Date().toISOString(), endDate: new Date(Date.now() + 45 * 86400000).toISOString() },
  { id: 6, title: 'صيانة سباكة دورية', description: 'فحص دوري كل ٦ أشهر بأسعار مخفضة', discountPercentage: 20, originalPrice: 40, offerPrice: 32, isActive: false, startDate: null, endDate: null },
]

const emptyForm = {
  title: '',
  description: '',
  discountPercentage: '',
  originalPrice: '',
  offerPrice: '',
  endDate: '',
}

export function OffersTab() {
  const { t, lang, dir } = useLanguage()
  const [offers, setOffers] = useState<Offer[]>(sampleOffers)
  const [dialogOpen, setDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [editingOffer, setEditingOffer] = useState<Offer | null>(null)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [form, setForm] = useState(emptyForm)

  const businessId = getBusinessId()

  useEffect(() => {
    async function fetchOffers() {
      setLoading(true)
      try {
        const res = await fetch(`/api/offers?businessId=${businessId}`)
        if (res.ok) {
          const data = await res.json()
          if (data.length > 0) setOffers(data)
        }
      } catch {
        // Keep sample data
      } finally {
        setLoading(false)
      }
    }
    fetchOffers()
  }, [businessId])

  const activeOffers = offers.filter((o) => o.isActive)
  const inactiveOffers = offers.filter((o) => !o.isActive)

  const openCreate = () => {
    setEditingOffer(null)
    setForm(emptyForm)
    setDialogOpen(true)
  }

  const openEdit = (offer: Offer) => {
    setEditingOffer(offer)
    setForm({
      title: offer.title,
      description: offer.description || '',
      discountPercentage: offer.discountPercentage?.toString() || '',
      originalPrice: offer.originalPrice?.toString() || '',
      offerPrice: offer.offerPrice?.toString() || '',
      endDate: offer.endDate ? new Date(offer.endDate).toISOString().split('T')[0] : '',
    })
    setDialogOpen(true)
  }

  const handleSubmit = async () => {
    setSaving(true)
    try {
      if (editingOffer) {
        // Update offer
        const res = await fetch(`/api/offers/${editingOffer.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            title: form.title,
            description: form.description,
            discountPercentage: form.discountPercentage ? parseFloat(form.discountPercentage) : null,
            originalPrice: form.originalPrice ? parseFloat(form.originalPrice) : null,
            offerPrice: form.offerPrice ? parseFloat(form.offerPrice) : null,
            endDate: form.endDate || null,
          }),
        })
        if (res.ok) {
          const saved = await res.json()
          setOffers((prev) => prev.map((o) => o.id === saved.id ? saved : o))
          toast.success('تم تحديث العرض بنجاح')
        } else {
          toast.error('فشل تحديث العرض')
        }
      } else {
        // Create offer
        const res = await fetch('/api/offers', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            businessId,
            title: form.title,
            description: form.description,
            discountPercentage: form.discountPercentage ? parseFloat(form.discountPercentage) : null,
            originalPrice: form.originalPrice ? parseFloat(form.originalPrice) : null,
            offerPrice: form.offerPrice ? parseFloat(form.offerPrice) : null,
            endDate: form.endDate || null,
          }),
        })
        if (res.ok) {
          const saved = await res.json()
          setOffers((prev) => [saved, ...prev])
          toast.success('تم إنشاء العرض بنجاح')
        } else {
          const err = await res.json()
          toast.error(err.error || 'فشل إنشاء العرض')
        }
      }
      setDialogOpen(false)
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  const toggleOffer = async (offer: Offer) => {
    try {
      const res = await fetch(`/api/offers/${offer.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isActive: !offer.isActive }),
      })
      if (res.ok) {
        const saved = await res.json()
        setOffers((prev) => prev.map((o) => o.id === saved.id ? saved : o))
        toast.success(offer.isActive ? 'تم إيقاف العرض' : 'تم تفعيل العرض')
      } else {
        // Fallback to local
        setOffers((prev) =>
          prev.map((o) => (o.id === offer.id ? { ...o, isActive: !o.isActive } : o))
        )
        toast.success(offer.isActive ? 'تم إيقاف العرض' : 'تم تفعيل العرض')
      }
    } catch {
      setOffers((prev) =>
        prev.map((o) => (o.id === offer.id ? { ...o, isActive: !o.isActive } : o))
      )
      toast.success(offer.isActive ? 'تم إيقاف العرض' : 'تم تفعيل العرض')
    }
  }

  const confirmDelete = (id: number) => {
    setDeletingId(id)
    setDeleteDialogOpen(true)
  }

  const handleDelete = async () => {
    if (!deletingId) return
    try {
      const res = await fetch(`/api/offers/${deletingId}`, { method: 'DELETE' })
      if (res.ok) {
        setOffers((prev) => prev.filter((o) => o.id !== deletingId))
        toast.success(t('offers_delete_success'))
      } else {
        toast.error(t('offers_delete_failed'))
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
          <h2 className="text-2xl font-bold tracking-tight">العروض</h2>
          <p className="text-muted-foreground">إدارة العروض والتخفيضات</p>
        </div>
        <Button
          onClick={openCreate}
          className="gap-2 bg-emerald-600 hover:bg-emerald-700"
        >
          <Plus className="h-4 w-4" />
          عرض جديد
        </Button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-emerald-700">{offers.length}</p>
            <p className="text-xs text-muted-foreground">إجمالي العروض</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-green-700">{activeOffers.length}</p>
            <p className="text-xs text-muted-foreground">عروض نشطة</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-gray-700">{inactiveOffers.length}</p>
            <p className="text-xs text-muted-foreground">عروض غير نشطة</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-amber-700">
              {offers.filter((o) => o.discountPercentage).length > 0
                ? Math.max(...offers.filter((o) => o.discountPercentage).map((o) => o.discountPercentage!))
                : 0}%
            </p>
            <p className="text-xs text-muted-foreground">أعلى خصم</p>
          </CardContent>
        </Card>
      </div>

      {/* Active Offers */}
      <div>
        <h3 className="text-lg font-semibold mb-3">العروض النشطة</h3>
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
          </div>
        ) : activeOffers.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
            <Tag className="h-12 w-12 mb-3 opacity-30" />
            <p>لا توجد عروض نشطة</p>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {activeOffers.map((offer) => (
              <Card key={offer.id} className="relative overflow-hidden">
                {offer.discountPercentage && (
                  <div className="absolute top-3 left-3">
                    <Badge className="bg-red-500 text-white gap-1">
                      <Percent className="h-3 w-3" />
                      {offer.discountPercentage}% خصم
                    </Badge>
                  </div>
                )}
                <div className="flex h-28 items-center justify-center bg-gradient-to-br from-emerald-50 to-emerald-100">
                  <Tag className="h-10 w-10 text-emerald-300" />
                </div>
                <CardContent className="p-4 space-y-3">
                  <h3 className="font-semibold">{offer.title}</h3>
                  {offer.description && (
                    <p className="text-sm text-muted-foreground line-clamp-2">
                      {offer.description}
                    </p>
                  )}
                  <div className="flex items-center gap-3">
                    {offer.originalPrice && (
                      <span className="text-sm text-muted-foreground line-through">
                        {offer.originalPrice} {t('currency')}
                      </span>
                    )}
                    {offer.offerPrice && (
                      <span className="text-lg font-bold text-emerald-700">
                        {offer.offerPrice} {t('currency')}
                      </span>
                    )}
                  </div>
                  {offer.endDate && (
                    <div className="flex items-center gap-1 text-xs text-muted-foreground">
                      <Clock className="h-3 w-3" />
                      ينتهي: {new Date(offer.endDate).toLocaleDateString('ar-KW')}
                    </div>
                  )}
                  <div className="flex gap-2 pt-1">
                    <Button variant="outline" size="sm" className="flex-1 text-xs h-8 gap-1" onClick={() => openEdit(offer)}>
                      <Pencil className="h-3 w-3" />
                      تعديل
                    </Button>
                    <Button variant="outline" size="sm" className="flex-1 text-xs h-8" onClick={() => toggleOffer(offer)}>
                      إيقاف
                    </Button>
                    <Button variant="outline" size="sm" className="text-xs h-8 text-red-600 hover:bg-red-50" onClick={() => confirmDelete(offer.id)}>
                      <Trash2 className="h-3 w-3" />
                    </Button>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>

      {/* Inactive Offers */}
      {inactiveOffers.length > 0 && (
        <div>
          <h3 className="text-lg font-semibold mb-3 text-muted-foreground">العروض غير النشطة</h3>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {inactiveOffers.map((offer) => (
              <Card key={offer.id} className="relative overflow-hidden opacity-60">
                <div className="flex h-20 items-center justify-center bg-gray-50">
                  <Tag className="h-8 w-8 text-gray-700" />
                </div>
                <CardContent className="p-4 space-y-2">
                  <h3 className="font-semibold text-muted-foreground">{offer.title}</h3>
                  <div className="flex gap-2">
                    <Button variant="outline" size="sm" className="flex-1 text-xs h-8 gap-1" onClick={() => openEdit(offer)}>
                      <Pencil className="h-3 w-3" />
                      تعديل
                    </Button>
                    <Button variant="outline" size="sm" className="flex-1 text-xs h-8" onClick={() => toggleOffer(offer)}>
                      تفعيل
                    </Button>
                    <Button variant="outline" size="sm" className="text-xs h-8 text-red-600 hover:bg-red-50" onClick={() => confirmDelete(offer.id)}>
                      <Trash2 className="h-3 w-3" />
                    </Button>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      )}

      {/* Create/Edit Offer Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-md" dir="rtl">
          <DialogHeader>
            <DialogTitle>{editingOffer ? 'تعديل العرض' : 'إنشاء عرض جديد'}</DialogTitle>
            <DialogDescription>{editingOffer ? 'قم بتعديل بيانات العرض' : 'أدخل بيانات العرض'}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label>عنوان العرض *</Label>
              <Input
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                placeholder="مثال: عرض صيفي"
              />
            </div>
            <div className="space-y-2">
              <Label>الوصف</Label>
              <Input
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                placeholder="وصف العرض"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>نسبة الخصم %</Label>
                <Input
                  type="number"
                  value={form.discountPercentage}
                  onChange={(e) => setForm({ ...form, discountPercentage: e.target.value })}
                  placeholder="0"
                />
              </div>
              <div className="space-y-2">
                <Label>السعر بعد الخصم</Label>
                <Input
                  type="number"
                  value={form.offerPrice}
                  onChange={(e) => setForm({ ...form, offerPrice: e.target.value })}
                  placeholder="0"
                />
              </div>
            </div>
            <div className="space-y-2">
              <Label>السعر الأصلي</Label>
              <Input
                type="number"
                value={form.originalPrice}
                onChange={(e) => setForm({ ...form, originalPrice: e.target.value })}
                placeholder="0"
              />
            </div>
            <div className="space-y-2">
              <Label>تاريخ الانتهاء</Label>
              <Input
                type="date"
                value={form.endDate}
                onChange={(e) => setForm({ ...form, endDate: e.target.value })}
              />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setDialogOpen(false)}>{t('cancel')}</Button>
            <Button
              onClick={handleSubmit}
              className="bg-emerald-600 hover:bg-emerald-700"
              disabled={saving || !form.title}
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin ml-2" /> : null}
              {editingOffer ? 'حفظ التعديلات' : 'إنشاء العرض'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent dir="rtl">
          <AlertDialogHeader>
            <AlertDialogTitle>{t('offers_delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('offers_delete_confirm_msg')}
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
