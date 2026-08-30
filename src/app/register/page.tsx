'use client'
import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { useLanguage } from '@/hooks/useLanguage'

export default function RegisterPage() {
  const router = useRouter()
  const { language, t, changeLanguage, isRTL } = useLanguage()
  const [serviceCategories, setServiceCategories] = useState<any[]>([])
  const [businessCategories, setBusinessCategories] = useState<any[]>([])
  const [loadingCats, setLoadingCats] = useState(true)
  
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    password: '',
    role: 'client',
    phone: '',
    categoryId: '',
    latitude: null as number | null,
    longitude: null as number | null,
    businessName: '',
    businessDescription: '',
  })
  
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [locationLoading, setLocationLoading] = useState(false)

  useEffect(() => {
    fetch('/api/categories?type=service')
      .then(r => r.json())
      .then(data => setServiceCategories(data.categories || []))
      .catch(() => {})

    fetch('/api/categories?type=business')
      .then(r => r.json())
      .then(data => setBusinessCategories(data.categories || []))
      .catch(() => {})

    setLoadingCats(false)
  }, [])

  const handleGetLocation = () => {
    if (!navigator.geolocation) {
      setError('المتصفح لا يدعم تحديد الموقع الجغرافي')
      return
    }
    setLocationLoading(true)
    setError('')
    navigator.geolocation.getCurrentPosition(
      (position) => {
        setFormData(prev => ({
          ...prev,
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
        }))
        setLocationLoading(false)
      },
      (err) => {
        setError('تعذر الحصول على الموقع. يرجى السماح بالوصول للموقع في إعدادات المتصفح.')
        setLocationLoading(false)
      }
    )
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    
    if (formData.role === 'craftsman') {
      if (!formData.categoryId) {
        setError('يجب على الحرفي اختيار التخصص المهني')
        return
      }
      if (!formData.latitude || !formData.longitude) {
        setError('يجب على الحرفي تحديد الموقع الجغرافي')
        return
      }
    }

    if (formData.role === 'business') {
      if (!formData.businessName) {
        setError('يجب إدخال اسم المحل')
        return
      }
      if (!formData.categoryId) {
        setError('يجب على المحل اختيار التصنيف')
        return
      }
    }

    setLoading(true)
    try {
      const payload = {
        name: formData.name,
        email: formData.email,
        password: formData.password,
        role: formData.role,
        phone: formData.phone || undefined,
        categoryId: (formData.role === 'craftsman' || formData.role === 'business') ? parseInt(formData.categoryId) : undefined,
        latitude: formData.role === 'craftsman' ? formData.latitude : undefined,
        longitude: formData.role === 'craftsman' ? formData.longitude : undefined,
        businessName: formData.role === 'business' ? formData.businessName : undefined,
        businessDescription: formData.role === 'business' ? formData.businessDescription : undefined,
      }

      const res = await fetch('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })
      
      // ✅ التحقق الآمن من نوع الاستجابة لتجنب خطأ JSON
      const contentType = res.headers.get('content-type')
      let data
      if (contentType && contentType.includes('application/json')) {
        data = await res.json()
      } else {
        const text = await res.text()
        console.error('❌ الخادم أعاد HTML بدلاً من JSON:', text.substring(0, 200))
        throw new Error('حدث خطأ في الخادم. يرجى مراجعة Terminal للأخطاء.')
      }

      if (!res.ok) {
        throw new Error(data.error || 'حدث خطأ غير متوقع')
      }
      
      if (formData.role === 'craftsman') {
        router.push('/craftsman/dashboard')
      } else if (formData.role === 'business') {
        router.push('/shop/dashboard')
      } else if (formData.role === 'admin') {
        router.push('/admin/dashboard')
      } else {
        router.push('/dashboard/client')
      }
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div dir={isRTL ? 'rtl' : 'ltr'} className="min-h-screen flex items-center justify-center bg-gray-50 p-4">
      <div className="max-w-md w-full bg-white p-8 rounded-xl shadow-lg">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-2xl font-bold text-gray-900">{t('auth.register') || 'إنشاء حساب'}</h1>
          <button onClick={() => changeLanguage(language === 'ar' ? 'en' : 'ar')} className="text-sm bg-blue-600 text-white px-3 py-1.5 rounded-lg font-semibold hover:bg-blue-700 transition">
            {language === 'ar' ? 'English' : 'العربية'}
          </button>
        </div>
        
        {error && <div className="bg-red-100 text-red-700 p-3 rounded mb-4 text-sm font-semibold">{error}</div>}
        
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1">{t('auth.name') || 'الاسم الكامل'}</label>
            <input type="text" value={formData.name} onChange={(e) => setFormData({...formData, name: e.target.value})} className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none" required />
          </div>
          
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1">{t('auth.email') || 'البريد الإلكتروني'}</label>
            <input type="email" value={formData.email} onChange={(e) => setFormData({...formData, email: e.target.value})} className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none" required />
          </div>

          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1">{isRTL ? 'رقم الهاتف' : 'Phone'}</label>
            <input type="tel" value={formData.phone} onChange={(e) => setFormData({...formData, phone: e.target.value})} className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none" required />
          </div>

          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1">{t('auth.password') || 'كلمة المرور'}</label>
            <input type="password" value={formData.password} onChange={(e) => setFormData({...formData, password: e.target.value})} className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none" required />
          </div>

          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1">{t('auth.role') || 'نوع الحساب'}</label>
            <select 
              value={formData.role} 
              onChange={(e) => setFormData({
                ...formData, 
                role: e.target.value, 
                categoryId: '', 
                latitude: null, 
                longitude: null,
                businessName: '',
                businessDescription: '',
              })} 
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
            >
              <option value="client">{t('roles.client') || 'عميل'}</option>
              <option value="craftsman">{t('roles.craftsman') || 'حرفي'}</option>
              <option value="business">{isRTL ? 'محل / شركة' : 'Business / Shop'}</option>
              <option value="admin">{isRTL ? 'مسؤول' : 'Admin'}</option>
            </select>
          </div>

          {formData.role === 'craftsman' && (
            <div className="bg-blue-50 p-4 rounded-lg border border-blue-200 space-y-4">
              <div>
                <label className="block text-sm font-semibold text-blue-800 mb-1">
                  {isRTL ? 'التخصص المهني (إلزامي)' : 'Professional Specialty (Required)'}
                </label>
                <select 
                  value={formData.categoryId} 
                  onChange={(e) => setFormData({...formData, categoryId: e.target.value})} 
                  className="w-full px-4 py-2 border border-blue-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none bg-white"
                  required
                >
                  <option value="">
                    {loadingCats ? (isRTL ? 'جاري التحميل...' : 'Loading...') : (isRTL ? 'اختر التخصص' : 'Select Specialty')}
                  </option>
                  {serviceCategories.map((cat: any) => (
                    <option key={cat.id} value={cat.id}>
                      {cat.icon} {language === 'ar' ? cat.name : (cat.nameEn || cat.name)}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-semibold text-blue-800 mb-1">
                  {isRTL ? 'الموقع الجغرافي (إلزامي)' : 'Geographic Location (Required)'}
                </label>
                <button
                  type="button"
                  onClick={handleGetLocation}
                  disabled={locationLoading}
                  className="w-full flex items-center justify-center gap-2 bg-white border border-blue-300 text-blue-700 px-4 py-2 rounded-lg hover:bg-blue-100 transition disabled:opacity-50"
                >
                  {locationLoading ? (
                    <span>{isRTL ? 'جاري تحديد الموقع...' : 'Getting location...'}</span>
                  ) : formData.latitude ? (
                    <span className="text-green-600 font-semibold">✅ {isRTL ? 'تم تحديد الموقع' : 'Location Set'}</span>
                  ) : (
                    <span>📍 {isRTL ? 'تحديد موقعي الحالي' : 'Get My Current Location'}</span>
                  )}
                </button>
              </div>
            </div>
          )}

          {formData.role === 'business' && (
            <div className="bg-green-50 p-4 rounded-lg border border-green-200 space-y-4">
              <div>
                <label className="block text-sm font-semibold text-green-800 mb-1">
                  {isRTL ? 'تصنيف المحل (إلزامي)' : 'Business Category (Required)'}
                </label>
                <select 
                  value={formData.categoryId} 
                  onChange={(e) => setFormData({...formData, categoryId: e.target.value})} 
                  className="w-full px-4 py-2 border border-green-300 rounded-lg focus:ring-2 focus:ring-green-500 outline-none bg-white"
                  required
                >
                  <option value="">
                    {loadingCats ? (isRTL ? 'جاري التحميل...' : 'Loading...') : (isRTL ? 'اختر التصنيف' : 'Select Category')}
                  </option>
                  {businessCategories.map((cat: any) => (
                    <option key={cat.id} value={cat.id}>
                      {cat.icon} {language === 'ar' ? cat.name : (cat.nameEn || cat.name)}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-semibold text-green-800 mb-1">
                  {isRTL ? 'اسم المحل (إلزامي)' : 'Business Name (Required)'}
                </label>
                <input 
                  type="text" 
                  value={formData.businessName} 
                  onChange={(e) => setFormData({...formData, businessName: e.target.value})} 
                  className="w-full px-4 py-2 border border-green-300 rounded-lg focus:ring-2 focus:ring-green-500 outline-none bg-white"
                  placeholder={isRTL ? 'مثال: محل النجار المحترف' : 'Example: Professional Carpenter Shop'}
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-semibold text-green-800 mb-1">
                  {isRTL ? 'وصف المحل (اختياري)' : 'Business Description (Optional)'}
                </label>
                <textarea 
                  value={formData.businessDescription} 
                  onChange={(e) => setFormData({...formData, businessDescription: e.target.value})} 
                  className="w-full px-4 py-2 border border-green-300 rounded-lg focus:ring-2 focus:ring-green-500 outline-none bg-white"
                  rows={3}
                  placeholder={isRTL ? 'اكتب وصفاً مختصراً عن محلك...' : 'Write a brief description of your business...'}
                />
              </div>
            </div>
          )}

          {formData.role === 'admin' && (
            <div className="bg-yellow-50 p-4 rounded-lg border border-yellow-200">
              <p className="text-sm text-yellow-800 font-semibold">
                {isRTL 
                  ? '⚠️ حساب المسؤول يتطلب موافقة خاصة. سيتم مراجعة طلبك من قبل الإدارة.' 
                  : '⚠️ Admin account requires special approval. Your request will be reviewed by the administration.'}
              </p>
            </div>
          )}

          <button type="submit" disabled={loading || locationLoading} className="w-full bg-blue-600 text-white py-2.5 rounded-lg hover:bg-blue-700 transition disabled:opacity-50 font-semibold">
            {loading ? (isRTL ? 'جاري الإنشاء...' : 'Creating...') : (t('auth.register') || 'إنشاء حساب')}
          </button>
        </form>
        
        <p className="text-center text-sm text-gray-600 mt-6 font-semibold">
          {t('auth.hasAccount') || 'لديك حساب بالفعل؟'}{' '}
          <Link href="/login" className="text-blue-600 hover:underline font-bold">{t('auth.login') || 'تسجيل الدخول'}</Link>
        </p>
      </div>
    </div>
  )
}
