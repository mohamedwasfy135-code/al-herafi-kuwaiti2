'use client'

import { Suspense, useState, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'

function RequestForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const categoryId = searchParams.get('categoryId')
  
  const [clientId, setClientId] = useState('')
  const [serviceType, setServiceType] = useState('')
  const [description, setDescription] = useState('')
  const [estimatedPrice, setEstimatedPrice] = useState('')
  const [governorate, setGovernorate] = useState('')
  const [city, setCity] = useState('')
  const [address, setAddress] = useState('')
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState('')

  useEffect(() => {
    const user = JSON.parse(localStorage.getItem('sana3i_user') || '{}')
    if (!user.id || user.role !== 'client') {
      router.push('/login')
    } else {
      setClientId(user.id)
    }
  }, [router])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!clientId || !serviceType || !description) {
      setMsg('يرجى ملء جميع الحقول المطلوبة')
      return
    }
    setLoading(true)
    try {
      const res = await fetch('/api/requests', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          clientId,
          serviceType,
          description,
          estimatedPrice: estimatedPrice ? parseFloat(estimatedPrice) : 0,
          governorate,
          city,
          address,
          serviceCategoryId: categoryId ? parseInt(categoryId) : null
        })
      })
      const data = await res.json()
      if (res.ok) {
        setMsg('✅ تم إنشاء الطلب بنجاح، جارٍ الإسناد الذكي...')
        setTimeout(() => {
          router.push('/dashboard/client')
        }, 2000)
      } else {
        setMsg(`❌ فشل إنشاء الطلب: ${data.error}`)
      }
    } catch (err) {
      setMsg('حدث خطأ في الاتصال')
    } finally {
      setLoading(false)
    }
    setTimeout(() => setMsg(''), 4000)
  }

  return (
    <div dir="rtl" className="max-w-2xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">طلب خدمة جديدة</h1>
      {msg && <div className="bg-blue-100 text-blue-700 p-3 rounded mb-4">{msg}</div>}
      <form onSubmit={handleSubmit} className="bg-white rounded-xl shadow p-6 space-y-4">
        <div>
          <label className="block font-bold mb-1">نوع الخدمة *</label>
          <input type="text" value={serviceType} onChange={(e) => setServiceType(e.target.value)} className="w-full border rounded px-3 py-2" required />
        </div>
        <div>
          <label className="block font-bold mb-1">وصف الخدمة *</label>
          <textarea value={description} onChange={(e) => setDescription(e.target.value)} className="w-full border rounded px-3 py-2" rows={4} required />
        </div>
        <div>
          <label className="block font-bold mb-1">السعر المقترح (د.ك) - اختياري</label>
          <input type="number" value={estimatedPrice} onChange={(e) => setEstimatedPrice(e.target.value)} className="w-full border rounded px-3 py-2" />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block font-bold mb-1">المحافظة</label>
            <input type="text" value={governorate} onChange={(e) => setGovernorate(e.target.value)} className="w-full border rounded px-3 py-2" />
          </div>
          <div>
            <label className="block font-bold mb-1">المدينة</label>
            <input type="text" value={city} onChange={(e) => setCity(e.target.value)} className="w-full border rounded px-3 py-2" />
          </div>
        </div>
        <div>
          <label className="block font-bold mb-1">العنوان التفصيلي</label>
          <input type="text" value={address} onChange={(e) => setAddress(e.target.value)} className="w-full border rounded px-3 py-2" />
        </div>
        <button type="submit" disabled={loading} className="w-full bg-blue-600 text-white py-2 rounded-lg disabled:opacity-50">
          {loading ? 'جاري الإرسال...' : 'إرسال الطلب'}
        </button>
      </form>
    </div>
  )
}

export default function NewClientRequest() {
  return (
    <Suspense fallback={<div className="p-8 text-center">جاري التحميل...</div>}>
      <RequestForm />
    </Suspense>
  )
}
