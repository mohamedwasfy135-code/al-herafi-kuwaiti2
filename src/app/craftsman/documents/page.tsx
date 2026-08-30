'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function CraftsmanDocuments() {
  const router = useRouter()
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [uploading, setUploading] = useState<string | null>(null)
  const [msg, setMsg] = useState('')
  
  const [formData, setFormData] = useState({
    civilIdUrl: '',
    bankAccountPhotoUrl: '',
    bankName: '',
    bankIban: ''
  })

  useEffect(() => {
    async function fetchData() {
      try {
        const res = await fetch('/api/craftsman/documents')
        if (res.ok) {
          const data = await res.json()
          if (data.document) {
            setFormData({
              civilIdUrl: data.document.civilIdUrl || '',
              bankAccountPhotoUrl: data.document.bankAccountPhotoUrl || '',
              bankName: data.document.bankName || '',
              bankIban: data.document.bankIban || ''
            })
          }
        }
      } catch (err) {
        console.error(err)
      } finally {
        setLoading(false)
      }
    }
    fetchData()
  }, [])

  const handleFileUpload = async (file: File, field: 'civilIdUrl' | 'bankAccountPhotoUrl') => {
    setUploading(field)
    setMsg('')
    
    try {
      const formData = new FormData()
      formData.append('file', file)

      const res = await fetch('/api/upload', {
        method: 'POST',
        body: formData
      })

      const data = await res.json()
      
      if (res.ok && data.success) {
        setFormData(prev => ({ ...prev, [field]: data.url }))
        setMsg('✅ تم رفع الصورة بنجاح')
        setTimeout(() => setMsg(''), 3000)
      } else {
        setMsg('❌ ' + (data.error || 'فشل رفع الصورة'))
      }
    } catch (err) {
      console.error('Upload error:', err)
      setMsg('❌ حدث خطأ في رفع الصورة')
    } finally {
      setUploading(null)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSubmitting(true)
    setMsg('')
    
    console.log('📝 إرسال البيانات:', formData)
    
    try {
      const res = await fetch('/api/craftsman/documents', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
        credentials: 'include' // مهم لإرسال الكوكيز
      })
      
      console.log('📥 حالة الاستجابة:', res.status)
      
      const data = await res.json()
      console.log('📦 البيانات المستلمة:', data)
      
      if (res.ok && data.success) {
        setMsg('✅ ' + data.message)
        setTimeout(() => {
          router.push('/craftsman/dashboard')
        }, 2000)
      } else {
        setMsg('❌ ' + (data.error || 'حدث خطأ') + (data.details ? ': ' + data.details : ''))
      }
    } catch (err) {
      console.error('Submit error:', err)
      setMsg('❌ حدث خطأ في الاتصال بالخادم')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin text-4xl mb-4">⏳</div>
          <p className="text-gray-600">جاري تحميل البيانات...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto p-6 bg-white rounded-xl shadow-lg mt-8" dir="rtl">
      <h2 className="text-2xl font-bold mb-2 text-gray-900">إثبات الهوية والحساب البنكي</h2>
      <p className="text-sm text-gray-600 mb-6">يرجى رفع صور الوثائق المطلوبة</p>
      
      {msg && (
        <div className={`p-4 rounded-lg mb-6 font-bold ${
          msg.includes('✅') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
        }`}>
          {msg}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* رفع البطاقة المدنية */}
        <div>
          <label className="block text-sm font-bold text-gray-700 mb-2">صورة البطاقة المدنية *</label>
          <div className="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center hover:border-blue-500 transition">
            {formData.civilIdUrl ? (
              <div>
                <img src={formData.civilIdUrl} alt="البطاقة المدنية" className="max-h-48 mx-auto rounded-lg mb-3" />
                <input 
                  type="file" 
                  accept="image/*"
                  onChange={e => e.target.files?.[0] && handleFileUpload(e.target.files[0], 'civilIdUrl')}
                  className="hidden"
                  id="civilId"
                />
                <label htmlFor="civilId" className="cursor-pointer text-blue-600 hover:text-blue-700 font-bold">
                  {uploading === 'civilIdUrl' ? 'جاري الرفع...' : 'تغيير الصورة'}
                </label>
              </div>
            ) : (
              <div>
                <div className="text-4xl mb-2">📷</div>
                <input 
                  type="file" 
                  accept="image/*"
                  onChange={e => e.target.files?.[0] && handleFileUpload(e.target.files[0], 'civilIdUrl')}
                  className="hidden"
                  id="civilId"
                  disabled={uploading !== null}
                />
                <label htmlFor="civilId" className="cursor-pointer text-blue-600 hover:text-blue-700 font-bold">
                  {uploading === 'civilIdUrl' ? 'جاري الرفع...' : 'اضغط لرفع صورة البطاقة'}
                </label>
                <p className="text-xs text-gray-500 mt-2">أقصى حجم: 5MB</p>
              </div>
            )}
          </div>
        </div>

        {/* رفع الحساب البنكي */}
        <div>
          <label className="block text-sm font-bold text-gray-700 mb-2">صورة الحساب البنكي</label>
          <div className="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center hover:border-blue-500 transition">
            {formData.bankAccountPhotoUrl ? (
              <div>
                <img src={formData.bankAccountPhotoUrl} alt="الحساب البنكي" className="max-h-48 mx-auto rounded-lg mb-3" />
                <input 
                  type="file" 
                  accept="image/*"
                  onChange={e => e.target.files?.[0] && handleFileUpload(e.target.files[0], 'bankAccountPhotoUrl')}
                  className="hidden"
                  id="bankAccount"
                />
                <label htmlFor="bankAccount" className="cursor-pointer text-blue-600 hover:text-blue-700 font-bold">
                  {uploading === 'bankAccountPhotoUrl' ? 'جاري الرفع...' : 'تغيير الصورة'}
                </label>
              </div>
            ) : (
              <div>
                <div className="text-4xl mb-2">🏦</div>
                <input 
                  type="file" 
                  accept="image/*"
                  onChange={e => e.target.files?.[0] && handleFileUpload(e.target.files[0], 'bankAccountPhotoUrl')}
                  className="hidden"
                  id="bankAccount"
                  disabled={uploading !== null}
                />
                <label htmlFor="bankAccount" className="cursor-pointer text-blue-600 hover:text-blue-700 font-bold">
                  {uploading === 'bankAccountPhotoUrl' ? 'جاري الرفع...' : 'اضغط لرفع صورة الحساب البنكي (اختياري)'}
                </label>
                <p className="text-xs text-gray-500 mt-2">أقصى حجم: 5MB</p>
              </div>
            )}
          </div>
        </div>

        {/* البيانات البنكية */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1">اسم البنك</label>
            <input 
              type="text" 
              value={formData.bankName}
              onChange={e => setFormData({...formData, bankName: e.target.value})}
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
              placeholder="مثال: بنك الكويت الوطني"
            />
          </div>
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1">رقم الآيبان (IBAN)</label>
            <input 
              type="text" 
              value={formData.bankIban}
              onChange={e => setFormData({...formData, bankIban: e.target.value})}
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition"
              placeholder="KW..."
            />
          </div>
        </div>

        <button 
          type="submit" 
          disabled={submitting || !formData.civilIdUrl}
          className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed text-white font-bold py-3 rounded-lg transition mt-4 shadow-md"
        >
          {submitting ? 'جاري الحفظ...' : 'حفظ المستندات'}
        </button>
      </form>
    </div>
  )
}
