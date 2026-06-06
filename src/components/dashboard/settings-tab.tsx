'use client'

import { useState, useEffect, useRef, useMemo } from 'react'
import {
  Settings,
  Building2,
  Phone,
  Mail,
  Globe,
  MapPin,
  Save,
  CreditCard,
  CheckCircle2,
  Clock,
  Shield,
  Loader2,
  ImagePlus,
  Trash2,
  FileText,
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
import { Separator } from '@/components/ui/separator'
import { Textarea } from '@/components/ui/textarea'
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

interface BusinessProfile {
  id: string
  name: string
  nameEn: string | null
  phone: string | null
  email: string | null
  website: string | null
  businessType: string | null
  governorate: string | null
  city: string | null
  address: string | null
  description: string | null
  logoUrl: string | null
  coverUrl: string | null
  invoiceFooterText: string | null
  isActive: boolean
  subscriptionStatus: string | null
  commissionRate: number | null
}

export function SettingsTab() {
  const { t, lang, dir } = useLanguage()

  const [form, setForm] = useState({
    name: '',
    nameEn: '',
    phone: '',
    email: '',
    website: '',
    businessType: 'shop',
    governorate: '',
    city: '',
    address: '',
    description: '',
    logoUrl: '',
    invoiceFooterText: '',
  })
  const [saving, setSaving] = useState(false)
  const [loading, setLoading] = useState(true)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const businessId = getBusinessId()

  const governorateItems = useMemo(() => [
    { value: 'العاصمة', labelAr: 'العاصمة', labelEn: 'Capital' },
    { value: 'حولي', labelAr: 'حولي', labelEn: 'Hawalli' },
    { value: 'الفروانية', labelAr: 'الفروانية', labelEn: 'Farwaniya' },
    { value: 'مبارك الكبير', labelAr: 'مبارك الكبير', labelEn: 'Mubarak Al-Kabeer' },
    { value: 'الأحمدي', labelAr: 'الأحمدي', labelEn: 'Ahmadi' },
    { value: 'الجهراء', labelAr: 'الجهراء', labelEn: 'Jahra' },
  ], [])

  useEffect(() => {
    async function loadProfile() {
      try {
        const res = await fetch(`/api/business/profile?businessId=${businessId}`)
        if (res.ok) {
          const data: BusinessProfile = await res.json()
          setForm({
            name: data.name || '',
            nameEn: data.nameEn || '',
            phone: data.phone || '',
            email: data.email || '',
            website: data.website || '',
            businessType: data.businessType || 'shop',
            governorate: data.governorate || '',
            city: data.city || '',
            address: data.address || '',
            description: data.description || '',
            logoUrl: data.logoUrl || '',
            invoiceFooterText: data.invoiceFooterText || '',
          })
        } else {
          setForm({
            name: 'الحرفي الكويتي',
            nameEn: 'Sana3i Kuwait',
            phone: '96612345',
            email: 'info@sana3i.com',
            website: 'www.sana3i.com',
            businessType: 'shop',
            governorate: 'العاصمة',
            city: 'العارضية',
            address: 'شارع السديراوي، بناية ١٥',
            description: 'منصة الحرفي الكويتي لخدمات الصيانة والحرف',
            logoUrl: '',
            invoiceFooterText: 'البضاعة المباعة ترد وتستبدل خلال 14 يوم',
          })
        }
      } catch {
        // Use defaults
      } finally {
        setLoading(false)
      }
    }
    loadProfile()
  }, [businessId])

  const handleLogoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      toast.error(t('settings_unsupported_format'))
      return
    }
    if (file.size > 500 * 1024) {
      toast.error(t('settings_image_too_large'))
      return
    }
    const reader = new FileReader()
    reader.onload = (event) => {
      const dataUrl = event.target?.result as string
      setForm((prev) => ({ ...prev, logoUrl: dataUrl }))
      toast.success(t('settings_logo_upload_success'))
    }
    reader.onerror = () => {
      toast.error(t('settings_logo_read_error'))
    }
    reader.readAsDataURL(file)
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  const handleRemoveLogo = () => {
    setForm((prev) => ({ ...prev, logoUrl: '' }))
    toast.success(t('settings_logo_removed'))
  }

  const handleSave = async () => {
    setSaving(true)
    try {
      const res = await fetch('/api/business/profile', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          businessId,
          name: form.name,
          nameEn: form.nameEn,
          phone: form.phone,
          email: form.email,
          website: form.website,
          businessType: form.businessType,
          governorate: form.governorate,
          city: form.city,
          address: form.address,
          description: form.description,
          logoUrl: form.logoUrl || null,
          invoiceFooterText: form.invoiceFooterText || null,
        }),
      })

      if (res.ok) {
        toast.success(t('settings_save_success'))
      } else {
        const err = await res.json()
        toast.error(err.error || t('settings_save_failed'))
      }
    } catch {
      toast.error(t('error_connection'))
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="h-10 w-10 animate-spin text-emerald-600" />
      </div>
    )
  }

  return (
    <div className="space-y-6" dir={dir}>
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">{t('settings_title')}</h2>
          <p className="text-muted-foreground">{t('settings_account_settings')}</p>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        {/* Business Profile Form */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Building2 className="h-5 w-5 text-emerald-600" />
              {t('settings_business_profile')}
            </CardTitle>
            <CardDescription>
              {t('settings_business_info')}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* Logo Upload Section */}
            <div className="space-y-3">
              <Label className="text-base font-medium">{t('settings_logo_upload')}</Label>
              <div className="flex items-center gap-4" dir={dir}>
                {/* Logo Preview */}
                <div className="relative h-20 w-20 rounded-full border-2 border-dashed border-emerald-300 bg-emerald-50 flex items-center justify-center overflow-hidden shrink-0">
                  {form.logoUrl ? (
                    <img
                      src={form.logoUrl}
                      alt={t('settings_logo_alt')}
                      className="h-full w-full object-cover rounded-full"
                    />
                  ) : (
                    <Building2 className="h-8 w-8 text-emerald-400" />
                  )}
                </div>

                {/* Upload/Remove Buttons */}
                <div className="flex flex-col gap-2">
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    onChange={handleLogoUpload}
                    className="hidden"
                  />
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    className="gap-1.5 border-emerald-300 text-emerald-700 hover:bg-emerald-50"
                    onClick={() => fileInputRef.current?.click()}
                  >
                    <ImagePlus className="h-4 w-4" />
                    {t('settings_upload_logo')}
                  </Button>
                  {form.logoUrl && (
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      className="gap-1.5 border-red-300 text-red-600 hover:bg-red-50"
                      onClick={handleRemoveLogo}
                    >
                      <Trash2 className="h-4 w-4" />
                      {t('settings_remove_logo')}
                    </Button>
                  )}
                </div>
              </div>
              <p className="text-xs text-muted-foreground">
                {t('settings_max_size_hint')}
              </p>
            </div>

            <Separator />

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label>{t('settings_name_ar')}</Label>
                <Input
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label>{t('settings_name_en')}</Label>
                <Input
                  value={form.nameEn}
                  onChange={(e) => setForm({ ...form, nameEn: e.target.value })}
                />
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="flex items-center gap-1.5">
                  <Phone className="h-3.5 w-3.5" />
                  {t('settings_phone_number')}
                </Label>
                <Input
                  value={form.phone}
                  onChange={(e) => setForm({ ...form, phone: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label className="flex items-center gap-1.5">
                  <Mail className="h-3.5 w-3.5" />
                  {t('settings_email_label')}
                </Label>
                <Input
                  type="email"
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                />
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="flex items-center gap-1.5">
                  <Globe className="h-3.5 w-3.5" />
                  {t('settings_website')}
                </Label>
                <Input
                  value={form.website}
                  onChange={(e) => setForm({ ...form, website: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label>{t('settings_business_type')}</Label>
                <Select
                  value={form.businessType}
                  onValueChange={(val) => setForm({ ...form, businessType: val })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="shop">{t('settings_type_shop')}</SelectItem>
                    <SelectItem value="company">{t('settings_type_company')}</SelectItem>
                    <SelectItem value="office">{t('settings_type_office')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <Separator />

            <div className="space-y-4">
              <h4 className="font-medium flex items-center gap-1.5">
                <MapPin className="h-4 w-4 text-emerald-600" />
                {t('settings_address')}
              </h4>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label>{t('settings_governorate')}</Label>
                  <Select
                    value={form.governorate}
                    onValueChange={(val) => setForm({ ...form, governorate: val })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder={t('settings_governorate_placeholder')} />
                    </SelectTrigger>
                    <SelectContent>
                      {governorateItems.map((gov) => (
                        <SelectItem key={gov.value} value={gov.value}>
                          {lang === 'ar' ? gov.labelAr : gov.labelEn}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>{t('settings_area')}</Label>
                  <Input
                    value={form.city}
                    onChange={(e) => setForm({ ...form, city: e.target.value })}
                  />
                </div>
              </div>
              <div className="space-y-2">
                <Label>{t('settings_detailed_address')}</Label>
                <Input
                  value={form.address}
                  onChange={(e) => setForm({ ...form, address: e.target.value })}
                />
              </div>
            </div>

            <Separator />

            <div className="space-y-2">
              <Label>{t('settings_business_desc')}</Label>
              <Input
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
              />
            </div>

            <Separator />

            {/* Invoice Footer Text */}
            <div className="space-y-2">
              <Label className="flex items-center gap-1.5">
                <FileText className="h-4 w-4 text-emerald-600" />
                {t('settings_invoice_footer')}
              </Label>
              <Textarea
                dir={dir}
                value={form.invoiceFooterText}
                onChange={(e) => setForm({ ...form, invoiceFooterText: e.target.value })}
                placeholder={t('settings_invoice_footer_placeholder')}
                rows={3}
                className="resize-none"
              />
              <p className="text-xs text-muted-foreground">
                {t('settings_footer_hint')}
              </p>
            </div>

            <div className="flex justify-end">
              <Button
                onClick={handleSave}
                className="gap-2 bg-emerald-600 hover:bg-emerald-700 min-w-32"
                disabled={saving}
              >
                {saving ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <Save className="h-4 w-4" />
                )}
                {t('settings_save_changes')}
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Sidebar: Subscription & Verification */}
        <div className="space-y-6">
          {/* Subscription Status */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base">
                <CreditCard className="h-5 w-5 text-emerald-600" />
                {t('settings_subscription')}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">{t('settings_plan')}</span>
                <Badge className="bg-emerald-600 text-white">{t('settings_free')}</Badge>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">{t('status')}</span>
                <div className="flex items-center gap-1.5">
                  <CheckCircle2 className="h-4 w-4 text-emerald-600" />
                  <span className="text-sm font-medium text-emerald-700">{t('settings_active')}</span>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">{t('settings_expiry_date')}</span>
                <span className="text-sm font-medium">{t('settings_undefined')}</span>
              </div>
              <Separator />
              <div className="space-y-2">
                <p className="text-sm font-medium">{t('settings_upgrade_plan')}</p>
                <div className="space-y-2">
                  {[
                    { name: t('settings_basic_plan'), price: t('settings_basic_price'), features: [t('settings_basic_features_50_products'), t('settings_basic_features_100_clients'), t('settings_basic_features_limited_invoices')] },
                    { name: t('settings_pro_plan'), price: t('settings_pro_price'), features: [t('settings_pro_features_unlimited_products'), t('settings_pro_features_unlimited_clients'), t('settings_pro_features_unlimited_invoices'), t('settings_pro_features_advanced_reports')] },
                  ].map((plan) => (
                    <div
                      key={plan.name}
                      className="rounded-lg border p-3 hover:border-emerald-300 transition-colors cursor-pointer"
                    >
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-sm font-medium">{plan.name}</span>
                        <span className="text-sm font-bold text-emerald-700">{plan.price}</span>
                      </div>
                      <ul className="text-xs text-muted-foreground space-y-0.5">
                        {plan.features.map((f) => (
                          <li key={f}>• {f}</li>
                        ))}
                      </ul>
                    </div>
                  ))}
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Verification Status */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base">
                <Shield className="h-5 w-5 text-emerald-600" />
                {t('settings_verification')}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">{t('settings_verification_status')}</span>
                <Badge className="bg-emerald-100 text-emerald-700 gap-1">
                  <CheckCircle2 className="h-3 w-3" />
                  {t('settings_verified')}
                </Badge>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">{t('settings_civil_id')}</span>
                <div className="flex items-center gap-1">
                  <CheckCircle2 className="h-4 w-4 text-emerald-600" />
                  <span className="text-sm">{t('settings_uploaded')}</span>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">{t('settings_license')}</span>
                <div className="flex items-center gap-1">
                  <CheckCircle2 className="h-4 w-4 text-emerald-600" />
                  <span className="text-sm">{t('settings_uploaded')}</span>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">{t('settings_last_update')}</span>
                <div className="flex items-center gap-1">
                  <Clock className="h-4 w-4 text-muted-foreground" />
                  <span className="text-xs text-muted-foreground">{t('settings_week_ago')}</span>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
