'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function CraftsmanDocuments() {
  const router = useRouter()
  const [civilUrl, setCivilUrl] = useState('')
  const [bankPhotoUrl, setBankPhotoUrl] = useState('')
  const [bankName, setBankName] = useState('')
  const [bankIban, setBankIban] = useState('')
  const [status, setStatus] = useState('')
  const [msg, setMsg] = useState('')

  useEffect(() => {
    const user = JSON.parse(localStorage.getItem('sana3i_user') || '{}')
    if (!user.id || user.role !== 'craftsman') router.push('/login')
    else loadDocuments(user.id)
  }, [router])

  const loadDocuments = async (craftsmanId: string) => {
    const res = await fetch(`/api/craftsman/documents?craftsmanId=${craftsmanId}`)
    const data = await res.json()
    if (data.documents) {
      setCivilUrl(data.documents.civil_id_url || '')
      setBankPhotoUrl(data.documents.bank_account_photo_url || '')
      setBankName(data.documents.bank_name || '')
      setBankIban(data.documents.bank_iban || '')
      setStatus(data.documents.status || 'pending')
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const user = JSON.parse(localStorage.getItem('sana3i_user') || '{}')
    const res = await fetch('/api/craftsman/documents', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        craftsmanId: user.id,
        civilIdUrl: civilUrl,
        bankPhotoUrl,
        bankName,
        bankIban
      })
    })
    const data = await res.json()
    if (res.ok) {
      setMsg('تم رفع المستندات بنجاح، بانتظار الاعتماد')
      setStatus('pending')
    } else {
      setMsg(data.error)
    }
    setTimeout(() => setMsg(''), 3000)
  }

  return (
    <div dir="rtl" className="max-w-2xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">رفع المستندات للاعتماد</h1>
      {msg && <div className="bg-blue-100 text-blue-700 p-3 rounded mb-4">{msg}</div>}
      {status === 'approved' && <div className="bg-green-100 text-green-700 p-3 rounded mb-4">✅ مستنداتك معتمدة</div>}
      {status === 'rejected' && <div className="bg-red-100 text-red-700 p-3 rounded mb-4">❌ تم رفض المستندات، يرجى إعادة رفعها</div>}
      <form onSubmit={handleSubmit} className="bg-white rounded-xl shadow p-6 space-y-4">
        <div>
          <label className="block font-bold mb-1">رابط صورة البطاقة المدنية</label>
          <input type="url" value={civilUrl} onChange={(e) => setCivilUrl(e.target.value)} className="w-full border rounded px-3 py-2" required />
          <p className="text-xs text-gray-700">ارفع الصورة على خدمة استضافة ثم ضع الرابط هنا</p>
        </div>
        <div>
          <label className="block font-bold mb-1">رابط صورة الحساب البنكي</label>
          <input type="url" value={bankPhotoUrl} onChange={(e) => setBankPhotoUrl(e.target.value)} className="w-full border rounded px-3 py-2" required />
        </div>
        <div>
          <label className="block font-bold mb-1">اسم البنك</label>
          <input type="text" value={bankName} onChange={(e) => setBankName(e.target.value)} className="w-full border rounded px-3 py-2" />
        </div>
        <div>
          <label className="block font-bold mb-1">رقم IBAN</label>
          <input type="text" value={bankIban} onChange={(e) => setBankIban(e.target.value)} className="w-full border rounded px-3 py-2" />
        </div>
        <button type="submit" className="w-full bg-blue-600 text-white py-2 rounded-lg">حفظ ورفع للاعتماد</button>
      </form>
    </div>
  )
}
