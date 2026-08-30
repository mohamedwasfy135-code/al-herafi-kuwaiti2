'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function ProfilePage() {
  const router = useRouter()
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState('')

  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [governorate, setGovernorate] = useState('')
  const [city, setCity] = useState('')

  useEffect(() => {
    const stored = localStorage.getItem('sana3i_user')
    if (stored) {
      const parsed = JSON.parse(stored)
      setUser(parsed)
      setName(parsed.name || '')
      setEmail(parsed.email || '')
      setPhone(parsed.phone || '')
      setGovernorate(parsed.governorate || '')
      setCity(parsed.city || '')
    } else {
      router.push('/login')
    }
    setLoading(false)
  }, [router])

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!name || !phone) {
      setMessage('الاسم ورقم الهاتف مطلوبان')
      return
    }
    setSaving(true)
    setMessage('')
    try {
      const res = await fetch(`/api/users/${user.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, email, phone, governorate, city }),
      })
      if (res.ok) {
        setMessage('تم تحديث الملف الشخصي بنجاح')
        const updated = { ...user, name, email, phone, governorate, city }
        localStorage.setItem('sana3i_user', JSON.stringify(updated))
        setUser(updated)
      } else {
        const data = await res.json()
        setMessage(data.error || 'فشل التحديث')
      }
    } catch {
      setMessage('تعذر الاتصال بالخادم')
    } finally {
      setSaving(false)
    }
  }

  const handleLogout = () => {
    localStorage.removeItem('sana3i_user')
    router.push('/login')
  }

  if (loading) return <div className="p-8 text-center">تحميل...</div>

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 p-4 md:p-6">
      <div className="max-w-xl mx-auto bg-white rounded-2xl shadow p-6 mt-10">
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-2xl font-bold">الملف الشخصي</h1>
          <button onClick={() => router.push('/')} className="text-blue-600 hover:underline text-sm">
            ← العودة للرئيسية
          </button>
        </div>

        <form onSubmit={handleSave} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">الاسم *</label>
            <input type="text" value={name} onChange={e => setName(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2" required />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">البريد الإلكتروني</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">رقم الهاتف *</label>
            <input type="text" value={phone} onChange={e => setPhone(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2" required />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">المحافظة</label>
            <input type="text" value={governorate} onChange={e => setGovernorate(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">المدينة</label>
            <input type="text" value={city} onChange={e => setCity(e.target.value)}
              className="w-full border border-gray-300 rounded-lg px-3 py-2" />
          </div>

          {message && (
            <div className={`text-sm p-3 rounded-lg ${message.includes('نجاح') ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
              {message}
            </div>
          )}

          <div className="flex gap-3">
            <button type="submit" disabled={saving}
              className="flex-1 bg-blue-600 text-white py-2 rounded-lg hover:bg-blue-700 transition disabled:opacity-50">
              {saving ? 'جاري الحفظ...' : 'حفظ التعديلات'}
            </button>
            <button type="button" onClick={handleLogout}
              className="px-4 py-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition">
              تسجيل الخروج
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
