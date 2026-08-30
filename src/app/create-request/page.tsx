'use client'

import { useState, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'

// بيانات محافظات ومدن الكويت
const kuwaitLocations: Record<string, string[]> = {
  'العاصمة': ['الكويت', 'الشرق', 'المطبة', 'القبلة', 'دسمان', 'بنيد القار', 'الدوحة', 'المرقاب'],
  'حولي': ['حولي', 'السالمية', 'الجابرية', 'بيان', 'مشرف', 'رميثية', 'سلوى', 'ميدان حولي'],
  'الفروانية': ['الفروانية', 'خيطان', 'جليب الشيوخ', 'الرقعي', 'الأندلس', 'الفردوس', 'اشبيلية', 'العارضية'],
  'الأحمدي': ['الأحمدي', 'الفنطاس', 'الفنيطيس', 'المنقف', 'ضاحية فهد الأحمد', 'صباح السالم', 'أبو حليفة', 'الرقة', 'هدية', 'المسيلة', 'القرين', 'المهبولة', 'الظهر', 'الوفرة', 'العدان', 'فحيحيل', 'الزور', 'ميناء الأحمدي', 'صباح الأحمد', 'علي صباح السالم'],
  'الجهراء': ['الجهراء', 'العيون', 'العبدلي', 'تيماء', 'النسيم', 'القصر', 'الصليبية', 'كبد', 'النويصيب', 'أمغرة', 'الواحة'],
  'مبارك الكبير': ['مبارك الكبير', 'صباح السالم', 'القصور', 'المسيلة', 'الفنيطيس', 'ضاحية جابر العلي']
};

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
        if (userData.role !== 'client') { router.push('/login'); return }
        setUser(userData)
      } else { router.push('/login') }
    } catch (e) { console.error(e); router.push('/login') }
    finally { setLoading(false) }
  }, [router])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    if (!user?.id) { setError('يرجى تسجيل الدخول أولاً'); router.push('/login'); return }
    if (!description.trim() || !address.trim()) { setError('يرجى ملء جميع الحقول المطلوبة'); return }

    setSubmitting(true)
    try {
      const res = await fetch('/api/requests', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ clientId: user.id, categoryId: categoryId ? parseInt(categoryId) : null, type, description: description.trim(), address: address.trim(), governorate: governorate.trim() || null, city: city.trim() || null }),
      })
      const data = await res.json()
      if (res.ok && data.success) { alert('تم إنشاء الطلب بنجاح!'); router.push('/dashboard/client?tab=requests') }
      else { setError(data.error || 'فشل إنشاء الطلب') }
    } catch (err) { setError('حدث خطأ في الاتصال') }
    finally { setSubmitting(false) }
  }

  if (loading) return <div className="min-h-screen flex items-center justify-center">جاري التحميل...</div>

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-2xl mx-auto bg-white rounded-xl shadow-sm p-8">
        <h1 className="text-2xl font-bold mb-6">إنشاء طلب جديد</h1>
        {error && <div className="mb-4 p-3 bg-red-100 text-red-800 rounded-lg">{error}</div>}
        <form onSubmit={handleSubmit} className="space-y-4">
          <textarea value={description} onChange={e => setDescription(e.target.value)} placeholder="وصف الخدمة..." rows={4} required className="w-full p-3 border rounded-lg" />
          <input value={address} onChange={e => setAddress(e.target.value)} placeholder="العنوان بالتفصيل..." required className="w-full p-3 border rounded-lg" />
          <div className="grid grid-cols-2 gap-4">
            <select value={governorate} onChange={e => { setGovernorate(e.target.value); setCity('') }} className="w-full p-3 border rounded-lg bg-white" required>
              <option value="">اختر المحافظة</option>
              {Object.keys(kuwaitLocations).map((gov) => (
                <option key={gov} value={gov}>{gov}</option>
              ))}
            </select>
            <select value={city} onChange={e => setCity(e.target.value)} className="w-full p-3 border rounded-lg bg-white disabled:bg-gray-100" disabled={!governorate} required>
              <option value="">اختر المنطقة</option>
              {governorate && kuwaitLocations[governorate].map((c) => (
                <option key={c} value={c}>{c}</option>
              ))}
            </select>
          </div>
          <button type="submit" disabled={submitting} className="w-full bg-blue-600 text-white py-3 rounded-lg font-bold disabled:bg-gray-400">
            {submitting ? 'جاري الإرسال...' : 'إرسال الطلب'}
          </button>
        </form>
      </div>
    </div>
  )
}
