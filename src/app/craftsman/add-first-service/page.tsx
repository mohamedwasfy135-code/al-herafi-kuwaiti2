'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function AddFirstServicePage() {
  const router = useRouter()
  const [user, setUser] = useState<any>(null)
  const [categories, setCategories] = useState<any[]>([])
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [price, setPrice] = useState('')
  const [categoryId, setCategoryId] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    const stored = localStorage.getItem('sana3i_user')
    if (stored) {
      const parsed = JSON.parse(stored)
      if (parsed.role !== 'craftsman') { router.push('/'); return }
      setUser(parsed)
    } else { router.push('/login'); return }

    fetch('/api/categories')
      .then(r => r.json())
      .then(d => setCategories(d.categories || d || []))
      .catch(() => {})
  }, [router])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const priceNum = parseFloat(price)
    if (!title || isNaN(priceNum) || !categoryId || !user?.id) {
      setError('يرجى ملء جميع الحقول المطلوبة بشكل صحيح')
      return
    }
    setLoading(true)
    setError('')
    try {
      const res = await fetch('/api/services', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          craftsmanId: user.id,
          title,
          description,
          price: priceNum,
          categoryId: parseInt(categoryId),
          isActive: true,
        }),
      })
      if (res.ok) {
        router.push('/craftsman/dashboard')
      } else {
        const data = await res.json()
        setError(data.error || 'فشل إضافة الخدمة')
      }
    } catch {
      setError('تعذر الاتصال بالخادم')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-xl mx-auto bg-white rounded-2xl shadow p-6 mt-10">
        <h1 className="text-2xl font-bold mb-6 text-center">أضف خدمة جديدة</h1>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">الفئة *</label>
            <select value={categoryId} onChange={e => setCategoryId(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2" required>
              <option value="">اختر فئة</option>
              {categories.map((cat: any) => (
                <option key={cat.id} value={cat.id}>{cat.icon} {cat.name}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">عنوان الخدمة *</label>
            <input type="text" value={title} onChange={e => setTitle(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2" placeholder="مثال: تصليح مكيفات" required />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">الوصف</label>
            <input type="text" value={description} onChange={e => setDescription(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2" placeholder="وصف مختصر للخدمة" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">السعر (د.ك) *</label>
            <input
              type="text"
              inputMode="numeric"
              value={price}
              onChange={e => setPrice(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2"
              placeholder="مثال: 20"
              required
            />
          </div>
          {error && <div className="bg-red-50 text-red-700 p-3 rounded-lg text-sm">{error}</div>}
          <button type="submit" disabled={loading}
            className="w-full bg-blue-600 text-white py-2 rounded-lg hover:bg-blue-700 transition disabled:opacity-50">
            {loading ? 'جارٍ الحفظ...' : 'حفظ الخدمة'}
          </button>
        </form>
        <button
          onClick={() => router.push('/craftsman/dashboard')}
          className="w-full mt-3 bg-gray-100 text-gray-700 py-2 rounded-lg hover:bg-gray-200 transition"
        >
          إلغاء والعودة
        </button>
      </div>
    </div>
  )
}
