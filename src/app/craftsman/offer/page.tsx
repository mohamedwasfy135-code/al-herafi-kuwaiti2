'use client'

import { Suspense, useState, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'

function OfferForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const requestId = searchParams.get('requestId')

  const [price, setPrice] = useState('')
  const [notes, setNotes] = useState('')
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState('')
  const [requestInfo, setRequestInfo] = useState<any>(null)
  const [craftsmanId, setCraftsmanId] = useState('')

  useEffect(() => {
    const user = JSON.parse(localStorage.getItem('sana3i_user') || '{}')
    if (user.id && user.role === 'craftsman') {
      setCraftsmanId(user.id)
    } else {
      router.push('/login')
      return
    }

    if (requestId) {
      fetch(`/api/requests/${requestId}`)
        .then(res => res.json())
        .then(data => setRequestInfo(data.request || data))
        .catch(() => {})
    }
  }, [requestId, router])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const numPrice = parseFloat(price)
    if (isNaN(numPrice) || numPrice <= 0) {
      setMsg('يرجى إدخال سعر صحيح أكبر من صفر')
      return
    }
    if (!craftsmanId) {
      setMsg('لم يتم التعرف على الحرفي')
      return
    }
    setLoading(true)
    try {
      const res = await fetch('/api/craftsman-offer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          requestId,
          price: numPrice,
          notes,
          craftsmanId
        })
      })
      if (res.ok) {
        setMsg('✅ تم إرسال عرض السعر بنجاح')
        setTimeout(() => router.push('/craftsman/dashboard'), 1500)
      } else {
        const err = await res.json()
        setMsg(`❌ فشل الإرسال: ${err.error || ''}`)
      }
    } catch {
      setMsg('تعذر الاتصال بالخادم')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div dir="rtl" className="max-w-2xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">تقديم عرض سعر</h1>
      {msg && <div className="bg-blue-100 text-blue-700 p-3 rounded mb-4">{msg}</div>}
      {requestInfo && (
        <div className="bg-white rounded-xl p-4 mb-4 shadow-sm border">
          <h3 className="font-bold">{requestInfo.service_type || 'طلب'}</h3>
          {requestInfo.description && <p className="text-sm text-gray-700">{requestInfo.description}</p>}
          <p className="text-xs text-gray-600 mt-1">العميل: {requestInfo.client_name || 'غير معروف'}</p>
        </div>
      )}
      <form onSubmit={handleSubmit} className="bg-white rounded-xl shadow p-6 space-y-4">
        <div>
          <label className="block font-bold mb-1">السعر المقترح (د.ك) *</label>
          <input
            type="text"
            inputMode="decimal"
            value={price}
            onChange={e => setPrice(e.target.value)}
            placeholder="مثال: 25.5"
            className="w-full border rounded px-3 py-2"
            required
          />
        </div>
        <div>
          <label className="block font-bold mb-1">ملاحظات (اختياري)</label>
          <textarea value={notes} onChange={e => setNotes(e.target.value)} rows={3} className="w-full border rounded px-3 py-2" />
        </div>
        <button type="submit" disabled={loading} className="w-full bg-yellow-600 text-white py-2 rounded-lg disabled:opacity-50">
          {loading ? 'جاري الإرسال...' : 'إرسال العرض'}
        </button>
      </form>
    </div>
  )
}

export default function OfferPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center">جاري التحميل...</div>}>
      <OfferForm />
    </Suspense>
  )
}
