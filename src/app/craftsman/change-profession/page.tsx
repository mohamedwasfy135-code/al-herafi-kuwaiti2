'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

export default function ChangeProfessionPage() {
  const router = useRouter()
  const [user, setUser] = useState<any>(null)
  const [categories, setCategories] = useState<any[]>([])
  const [selectedCategory, setSelectedCategory] = useState('')
  const [reason, setReason] = useState('')
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')

  useEffect(() => {
    const stored = localStorage.getItem('sana3i_user')
    if (!stored) {
      router.push('/login')
      return
    }
    const parsed = JSON.parse(stored)
    if (parsed.role !== 'craftsman') {
      router.push('/')
      return
    }
    setUser(parsed)

    // تحميل قائمة الفئات
    fetch('/api/categories')
      .then(res => res.json())
      .then(data => setCategories(data.categories || data || []))
      .catch(err => console.error('خطأ في تحميل الفئات:', err))
  }, [router])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedCategory || !reason.trim()) {
      setMessage('يرجى اختيار الحرفة الجديدة وكتابة السبب')
      return
    }
    setLoading(true)
    setMessage('')
    try {
      const res = await fetch('/api/craftsman/change-profession', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          craftsmanId: user.id,
          newCategoryId: parseInt(selectedCategory),
          reason: reason.trim()
        })
      })
      const data = await res.json()
      if (res.ok) {
        setMessage('✅ تم إرسال الطلب إلى الإدارة بنجاح')
        setTimeout(() => router.push('/craftsman/dashboard'), 2000)
      } else {
        setMessage('❌ ' + (data.error || 'حدث خطأ في إرسال الطلب'))
      }
    } catch (err) {
      console.error(err)
      setMessage('❌ تعذر الاتصال بالخادم')
    } finally {
      setLoading(false)
    }
  }

  if (!user) {
    return <div className="min-h-screen flex items-center justify-center">جار التحميل...</div>
  }

  return (
    <div dir="rtl" className="min-h-screen bg-gray-100 p-6">
      <div className="max-w-xl mx-auto">
        <div className="mb-4">
          <Link href="/craftsman/dashboard" className="text-blue-600 text-sm">← العودة إلى لوحة التحكم</Link>
        </div>
        <div className="bg-white rounded-2xl shadow p-6">
          <h1 className="text-2xl font-bold mb-6 text-center">طلب تغيير الحرفة</h1>
          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label className="block text-sm font-medium mb-1">الحرفة الجديدة <span className="text-red-500">*</span></label>
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                className="w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-purple-500"
                required
              >
                <option value="">-- اختر من القائمة --</option>
                {categories.map((cat: any) => (
                  <option key={cat.id} value={cat.id}>
                    {cat.icon} {cat.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">سبب تغيير الحرفة <span className="text-red-500">*</span></label>
              <textarea
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                rows={4}
                className="w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-purple-500"
                placeholder="مثال: أرغب في تغيير تخصصي لأن لدي خبرة أكبر في المجال الجديد..."
                required
              />
            </div>
            {message && (
              <div className={`text-center text-sm p-2 rounded ${message.startsWith('✅') ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                {message}
              </div>
            )}
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-purple-600 text-white py-2 rounded-lg hover:bg-purple-700 transition disabled:opacity-50"
            >
              {loading ? 'جاري الإرسال...' : 'إرسال الطلب'}
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}
