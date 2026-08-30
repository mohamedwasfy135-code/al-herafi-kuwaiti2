'use client'

import { useState, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'

// ✅ هذا السطر يمنع Vercel من محاولة بناء الصفحة مسبقاً (Static Generation)
export const dynamic = 'force-dynamic'

export default function CreateRequestPage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  
  const [description, setDescription] = useState('')
  const [address, setAddress] = useState('')
  const [governorate, setGovernorate] = useState('')
  const [city, setCity] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')

  const categoryId = searchParams.get('categoryId')
  const type = searchParams.get('type') || 'service'

  useEffect(() => {
    try {
      const stored = localStorage.getItem('sana3i_user')
      if (stored) {
        const userData = JSON.parse(stored)
        if (userData.role !== 'client') { 
          router.push('/login')
          return 
        }
        setUser(userData)
      } else { 
        router.push('/login') 
      }
    } catch (e) { 
      console.error('Error parsing user:', e)
      router.push('/login') 
    } finally {
      setLoading(false)
    }
  }, [router])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    if (!user || !user.id) {
      setError(' يرجى تسجيل الدخول أولاً')
      router.push('/login')
      return
    }

    if (!description.trim() || !address.trim()) {
      setError('❌ يرجى ملء وصف الطلب والعنوان')
      return
    }

    setSubmitting(true)

    try {
      const res = await fetch('/api/requests', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          clientId: user.id,
          categoryId: categoryId ? parseInt(categoryId) : null,
          type: type,
          description: description.trim(),
          address: address.trim(),
          governorate: governorate.trim() || null,
          city: city.trim() || null,
        }),
      })

      const data = await res.json()

      if (res.ok && data.success) {
        alert('✅ تم إنشاء الطلب بنجاح!')
        router.push(`/dashboard/client?tab=requests`)
      } else {
        setError('❌ ' + (data.error || 'فشل إنشاء الطلب'))
      }
    } catch (err) {
      setError('حدث خطأ في الاتصال بالخادم')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) {
    return (
      <div dir="rtl" className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">جاري التحميل...</p>
        </div>
      </div>
    )
  }

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-2xl mx-auto bg-white rounded-xl shadow-sm p-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-6">إنشاء طلب جديد</h1>
        
        {error && <div className="mb-4 p-3 bg-red-100 text-red-800 rounded-lg font-semibold">{error}</div>}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">وصف المشكلة أو الخدمة المطلوبة *</label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              rows={4}
              placeholder="مثال: أحتاج إلى فني لإصلاح تسرب مياه في المطبخ..."
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">العنوان بالتفصيل *</label>
            <input
              type="text"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
              placeholder="مثال: حولي، شارع بن خلدون، مبنى 5، شقة 12"
              required
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">المحافظة</label>
              <input
                type="text"
                value={governorate}
                onChange={(e) => setGovernorate(e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                placeholder="مثال: العاصمة"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">المدينة / المنطقة</label>
              <input
                type="text"
                value={city}
                onChange={(e) => setCity(e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                placeholder="مثال: حولي"
              />
            </div>
          </div>

          <div className="flex gap-3 pt-4">
            <button
              type="submit"
              disabled={submitting}
              className="flex-1 bg-blue-600 text-white py-3 rounded-lg font-bold hover:bg-blue-700 transition disabled:bg-gray-400"
            >
              {submitting ? 'جاري الإرسال...' : 'إرسال الطلب'}
            </button>
            <button
              type="button"
              onClick={() => router.back()}
              className="px-6 py-3 border border-gray-300 rounded-lg font-semibold hover:bg-gray-50 transition"
            >
              إلغاء
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
