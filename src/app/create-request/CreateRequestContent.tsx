'use client'

import { useState, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'

export default function CreateRequestContent() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const serviceId = searchParams.get('serviceId') || ''
  const categoryId = searchParams.get('categoryId') || ''
  const searchQuery = searchParams.get('search') || ''
  const [user, setUser] = useState<any>(null)
  const [service, setService] = useState<any>(null)
  const [categoryName, setCategoryName] = useState<string>('')
  const [details, setDetails] = useState('')
  const [governorate, setGovernorate] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    const stored = localStorage.getItem('sana3i_user')
    if (stored) {
      setUser(JSON.parse(stored))
    } else {
      router.push(`/login?redirect=/create-request${serviceId ? `?serviceId=${serviceId}` : categoryId ? `?categoryId=${categoryId}` : ''}`)
    }
  }, [router, serviceId, categoryId])

  useEffect(() => {
    if (serviceId) {
      fetch(`/api/services/${serviceId}`)
        .then(r => r.json())
        .then(d => setService(d.service || d))
        .catch(() => setError('فشل تحميل بيانات الخدمة'))
    } else if (categoryId) {
      fetch('/api/categories')
        .then(r => r.json())
        .then(d => {
          const cats = d.categories || d || []
          const cat = cats.find((c: any) => c.id == categoryId)
          if (cat) setCategoryName(cat.name)
        })
        .catch(() => {})
    }
  }, [serviceId, categoryId])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!user || !details.trim()) {
      setError('يرجى كتابة وصف للخدمة المطلوبة')
      return
    }
    setLoading(true)
    setError('')
    try {
      const res = await fetch('/api/requests/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          clientId: user.id,
          serviceId: serviceId ? parseInt(serviceId) : undefined,
          categoryId: categoryId ? parseInt(categoryId) : undefined,
          details: details,
          price: service?.price || 0,
          governorate: governorate || undefined,
        }),
      })
      const data = await res.json()
      if (res.ok) {
        alert(data.message || 'تم إرسال طلبك بنجاح')
        router.push('/')
      } else {
        setError(data.error || 'فشل إنشاء الطلب')
      }
    } catch {
      setError('تعذر الاتصال بالخادم')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 p-4 md:p-6">
      <div className="max-w-xl mx-auto bg-white rounded-2xl shadow p-6 mt-10">
        <h1 className="text-2xl font-bold mb-6">طلب خدمة</h1>
        {categoryName && !serviceId && (
          <div className="mb-4 p-3 bg-blue-50 rounded-lg">
            <p className="font-semibold">الفئة: {categoryName}</p>
          </div>
        )}
        {searchQuery && (
          <div className="mb-4 p-3 bg-blue-50 rounded-lg">
            <p className="font-semibold">بحث: {searchQuery}</p>
          </div>
        )}
        {service && (
          <div className="mb-4 p-3 bg-gray-50 rounded-lg">
            <p className="font-semibold">{service.title}</p>
            {service.description && <p className="text-sm text-gray-600">{service.description}</p>}
            <p className="text-blue-600 font-bold mt-1">
              {service.price > 0 ? `${service.price} د.ك` : 'السعر: سيتم تحديده لاحقاً'}
            </p>
          </div>
        )}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">وصف الخدمة المطلوبة *</label>
            <textarea
              value={details}
              onChange={e => setDetails(e.target.value)}
              placeholder="اشرح ما تحتاجه بالتفصيل..."
              rows={4}
              className="w-full border border-gray-300 rounded-lg px-3 py-2"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">المحافظة (اختياري)</label>
            <select
              value={governorate}
              onChange={e => setGovernorate(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2"
            >
              <option value="">كل المحافظات</option>
              <option value="العاصمة">العاصمة</option>
              <option value="حولي">حولي</option>
              <option value="الفروانية">الفروانية</option>
              <option value="الجهراء">الجهراء</option>
              <option value="الأحمدي">الأحمدي</option>
              <option value="مبارك الكبير">مبارك الكبير</option>
            </select>
          </div>
          {error && <div className="bg-red-50 text-red-700 p-3 rounded-lg text-sm">{error}</div>}
          <button
            type="submit"
            disabled={loading}
            className="w-full bg-blue-600 text-white py-3 rounded-lg hover:bg-blue-700 transition font-bold disabled:opacity-50"
          >
            {loading ? 'جارٍ إرسال الطلب...' : 'تأكيد الطلب'}
          </button>
        </form>
      </div>
    </div>
  )
}
