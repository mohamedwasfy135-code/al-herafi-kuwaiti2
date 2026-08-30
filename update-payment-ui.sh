#!/bin/bash
set -e
echo "🚀 بدء تحديث واجهات نظام الدفع..."

# ═══════════════════════════════════════════════════════════════
# 1️⃣ تحديث واجهة العميل (Client Dashboard)
# ═══════════════════════════════════════════════════════════════
echo "📝 تحديث واجهة العميل..."

cat << 'EOF' > src/app/dashboard/client/page.tsx
'use client'
import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'

export default function ClientDashboard() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState<'requests' | 'notifications' | 'browse'>('requests')
  
  const [requests, setRequests] = useState<any[]>([])
  const [notifications, setNotifications] = useState<any[]>([])
  const [loadingRequests, setLoadingRequests] = useState(false)
  const [reviewModal, setReviewModal] = useState<any>(null)
  const [rating, setRating] = useState(5)
  const [comment, setComment] = useState('')
  const [msg, setMsg] = useState('')

  useEffect(() => {
    const successMsg = searchParams.get('msg')
    if (successMsg === 'visit_fee_paid') setMsg('✅ تم دفع دفعة الزيارة بنجاح! الحرفي سيقترح السعر قريباً.')
    else if (successMsg === 'final_payment_paid') setMsg('✅ تم الدفع النهائي بنجاح! شكراً لاستخدامك المنصة.')
    setTimeout(() => setMsg(''), 5000)
  }, [searchParams])

  useEffect(() => {
    try {
      const stored = localStorage.getItem('sana3i_user')
      if (stored) {
        const userData = JSON.parse(stored)
        if (userData.role !== 'client') { router.push('/login'); return }
        setUser(userData)
      } else { router.push('/login') }
    } catch { router.push('/login') }
    setLoading(false)
  }, [router])

  useEffect(() => {
    if (user && activeTab === 'requests') {
      setLoadingRequests(true)
      fetch(`/api/requests?clientId=${user.id}`)
        .then(r => r.json()).then(data => { setRequests(data.requests || []); setLoadingRequests(false) })
        .catch(() => setLoadingRequests(false))
    }
    if (user && activeTab === 'notifications') {
      fetch('/api/notifications').then(r => r.json()).then(data => setNotifications(data.notifications || [])).catch(() => {})
    }
  }, [user, activeTab])

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' })
    localStorage.removeItem('sana3i_user')
    router.push('/login')
  }

  // دفع دفعة الزيارة
  const handlePayVisitFee = async (requestId: number) => {
    try {
      const res = await fetch('/api/payments/visit-fee', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        window.location.href = data.paymentUrl
      } else {
        setMsg('❌ ' + (data.error || 'فشل إنشاء الفاتورة'))
      }
    } catch (error) { setMsg('❌ حدث خطأ') }
  }

  // الموافقة أو الرفض على السعر
  const handlePriceAction = async (requestId: number, action: 'approve' | 'reject') => {
    if (action === 'approve' && !confirm('هل توافق على السعر المقترح؟\nسيتم خصم دفعة الزيارة من الإجمالي.')) return
    if (action === 'reject' && !confirm('هل ترفض السعر المقترح؟\nسيتم إشعار الحرفي لاقتراح سعر جديد.')) return
    
    try {
      const res = await fetch('/api/payments/approve-price', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId, action })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + data.message)
        setTimeout(() => setMsg(''), 3000)
        fetch(`/api/requests?clientId=${user.id}`).then(r => r.json()).then(data => setRequests(data.requests || []))
      } else {
        setMsg('❌ ' + (data.error || 'فشل العملية'))
      }
    } catch (error) { setMsg('❌ حدث خطأ') }
  }

  // الدفع النهائي
  const handleFinalPayment = async (requestId: number) => {
    if (!confirm('هل تريد الانتقال للدفع النهائي؟')) return
    try {
      const res = await fetch('/api/payments/final', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        window.location.href = data.paymentUrl
      } else {
        setMsg('❌ ' + (data.error || 'فشل إنشاء الفاتورة'))
      }
    } catch (error) { setMsg('❌ حدث خطأ') }
  }

  const handleSubmitReview = async () => {
    if (!reviewModal) return
    try {
      const res = await fetch('/api/reviews', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId: reviewModal.id, ratedId: reviewModal.craftsmanId, stars: rating, comment: comment || null })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ تم إضافة التقييم')
        setReviewModal(null); setRating(5); setComment('')
        setTimeout(() => setMsg(''), 3000)
      } else { setMsg('❌ ' + (data.error || 'فشل التقييم')) }
    } catch (error) { setMsg('❌ حدث خطأ') }
  }

  const getStatusBadge = (status: string) => {
    const statuses: Record<string, { label: string; color: string; icon: string }> = {
      pending: { label: 'قيد الانتظار', color: 'bg-yellow-100 text-yellow-800', icon: '⏳' },
      accepted: { label: 'تم القبول', color: 'bg-indigo-100 text-indigo-800', icon: '✅' },
      pending_payment: { label: 'بانتظار دفعة الزيارة', color: 'bg-orange-100 text-orange-800', icon: '💳' },
      pending_approval: { label: 'بانتظار الموافقة على السعر', color: 'bg-purple-100 text-purple-800', icon: '💰' },
      in_progress: { label: 'الحرفي في الطريق', color: 'bg-blue-100 text-blue-800', icon: '🚗' },
      completed: { label: 'بانتظار الدفع النهائي', color: 'bg-orange-100 text-orange-800', icon: '💵' },
      paid: { label: 'مدفوع', color: 'bg-green-100 text-green-800', icon: '💰' },
    }
    const s = statuses[status] || statuses.pending
    return <span className={`px-3 py-1.5 rounded-full text-xs font-semibold ${s.color}`}>{s.icon} {s.label}</span>
  }

  if (loading) return <div className="min-h-screen flex items-center justify-center bg-gray-50">جاري التحميل...</div>

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm p-4 sticky top-0 z-50">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row justify-between items-center gap-4">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-blue-700 font-bold text-xl">{user?.name?.charAt(0) || 'ع'}</div>
            <div>
              <h1 className="text-xl font-bold text-gray-900">مرحباً، {user?.name}</h1>
              <p className="text-sm text-gray-500">لوحة تحكم العميل</p>
            </div>
          </div>
          <div className="flex gap-2 bg-gray-100 p-1 rounded-lg">
            <button onClick={() => setActiveTab('requests')} className={`px-4 py-2 rounded-md text-sm font-semibold transition ${activeTab === 'requests' ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'}`}>📦 طلباتي</button>
            <button onClick={() => setActiveTab('notifications')} className={`px-4 py-2 rounded-md text-sm font-semibold transition ${activeTab === 'notifications' ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'}`}>🔔 الإشعارات</button>
          </div>
          <button onClick={handleLogout} className="text-sm text-red-600 font-semibold hover:bg-red-50 px-3 py-2 rounded-lg transition">تسجيل الخروج</button>
        </div>
      </header>

      <main className="max-w-6xl mx-auto p-6">
        {msg && <div className={`p-4 rounded-lg mb-6 font-bold ${msg.includes('✅') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>{msg}</div>}

        {activeTab === 'requests' && (
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-2xl font-bold text-gray-900 mb-6">طلباتي</h2>
            {loadingRequests ? (
              <div className="text-center py-12"><div className="animate-spin text-4xl mb-4">⏳</div><p className="text-gray-600">جاري التحميل...</p></div>
            ) : requests.length === 0 ? (
              <div className="text-center py-12"><div className="text-6xl mb-4">📦</div><h3 className="text-xl font-bold text-gray-900 mb-2">لا توجد طلبات</h3></div>
            ) : (
              <div className="space-y-4">
                {requests.map((req: any) => (
                  <div key={req.id} className="border border-gray-200 rounded-lg p-4 hover:shadow-md transition">
                    <div className="flex justify-between items-start mb-3">
                      <div className="flex items-center gap-3">
                        <div className="text-3xl">{req.category?.icon || '🔧'}</div>
                        <div>
                          <h3 className="font-bold text-gray-900">{req.category?.name || 'خدمة'}</h3>
                          <p className="text-sm text-gray-500">رقم الطلب: #{req.id}</p>
                        </div>
                      </div>
                      {getStatusBadge(req.status)}
                    </div>

                    <p className="text-gray-700 mb-3">{req.description}</p>
                    
                    {req.craftsman && (
                      <div className="mt-3 p-3 bg-blue-50 rounded-lg">
                        <p className="text-sm text-blue-800"><span className="font-semibold">الحرفي:</span> {req.craftsman.name} {req.craftsman.phone && `| 📞 ${req.craftsman.phone}`}</p>
                      </div>
                    )}

                    {/* عرض تفاصيل الدفع */}
                    {req.visitFeePaid && <div className="mt-3 p-3 bg-green-50 rounded-lg border border-green-200"><p className="text-sm text-green-800 font-bold">✅ تم دفع دفعة الزيارة: 3 د.ك</p></div>}
                    {req.proposedPrice && (
                      <div className="mt-3 p-3 bg-purple-50 rounded-lg border border-purple-200">
                        <p className="text-sm text-purple-800 font-bold">💰 السعر المقترح: {req.proposedPrice} د.ك</p>
                        <p className="text-sm text-purple-700">المتبقي بعد خصم دفعة الزيارة: {req.remainingAmount?.toFixed(3)} د.ك</p>
                      </div>
                    )}
                    {req.agreedPrice && <div className="mt-3 p-3 bg-indigo-50 rounded-lg border border-indigo-200"><p className="text-sm text-indigo-800 font-bold">🤝 السعر المتفق عليه: {req.agreedPrice} د.ك</p></div>}
                    {req.finalPrice && <div className="mt-3 p-3 bg-green-50 rounded-lg border border-green-200"><p className="text-sm text-green-800 font-bold">💰 التكلفة النهائية: {req.finalPrice} د.ك</p></div>}

                    {/* أزرار الإجراءات */}
                    <div className="mt-4 flex gap-2 flex-wrap">
                      {req.status === 'accepted' && !req.visitFeePaid && (
                        <button onClick={() => handlePayVisitFee(req.id)} className="flex-1 bg-orange-600 text-white py-2 rounded-lg font-semibold hover:bg-orange-700 transition">💳 دفع دفعة الزيارة (3 د.ك)</button>
                      )}
                      {req.status === 'pending_approval' && req.proposedPrice && (
                        <>
                          <button onClick={() => handlePriceAction(req.id, 'approve')} className="flex-1 bg-green-600 text-white py-2 rounded-lg font-semibold hover:bg-green-700 transition">✅ الموافقة على السعر</button>
                          <button onClick={() => handlePriceAction(req.id, 'reject')} className="flex-1 bg-red-600 text-white py-2 rounded-lg font-semibold hover:bg-red-700 transition">❌ رفض السعر</button>
                        </>
                      )}
                      {req.status === 'completed' && req.agreedPrice && (
                        <button onClick={() => handleFinalPayment(req.id)} className="flex-1 bg-green-600 text-white py-2 rounded-lg font-semibold hover:bg-green-700 transition">💳 الدفع النهائي ({req.remainingAmount?.toFixed(3)} د.ك)</button>
                      )}
                      {req.status === 'paid' && req.craftsmanId && (
                        <button onClick={() => setReviewModal(req)} className="flex-1 bg-yellow-500 text-white py-2 rounded-lg font-semibold hover:bg-yellow-600 transition">⭐ تقييم الحرفي</button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {activeTab === 'notifications' && (
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-2xl font-bold text-gray-900 mb-6">الإشعارات</h2>
            {notifications.length === 0 ? <p className="text-center text-gray-500 py-8">لا توجد إشعارات</p> : (
              <div className="space-y-3">
                {notifications.map((notif: any) => (
                  <div key={notif.id} className={`p-4 rounded-lg border ${notif.isRead ? 'bg-gray-50 border-gray-200' : 'bg-blue-50 border-blue-200'}`}>
                    <p className="font-bold text-gray-900">{notif.title}</p>
                    <p className="text-sm text-gray-600 mt-1">{notif.body}</p>
                    <p className="text-xs text-gray-400 mt-2">{new Date(notif.createdAt).toLocaleString('ar-KW')}</p>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </main>

      {reviewModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full">
            <h3 className="text-xl font-bold text-gray-900 mb-4">⭐ تقييم الحرفي</h3>
            <div className="flex gap-2 justify-center mb-4">
              {[1, 2, 3, 4, 5].map((star) => (
                <button key={star} onClick={() => setRating(star)} className={`text-4xl transition ${star <= rating ? 'text-yellow-400' : 'text-gray-300'}`}>★</button>
              ))}
            </div>
            <textarea value={comment} onChange={(e) => setComment(e.target.value)} className="w-full px-4 py-3 border border-gray-300 rounded-lg mb-4" rows={3} placeholder="تعليقك (اختياري)" />
            <div className="flex gap-3">
              <button onClick={handleSubmitReview} className="flex-1 bg-yellow-500 hover:bg-yellow-600 text-white py-3 rounded-lg font-bold transition">إرسال التقييم</button>
              <button onClick={() => { setReviewModal(null); setRating(5); setComment(''); }} className="px-6 py-3 bg-gray-100 hover:bg-gray-200 rounded-lg font-bold text-gray-700 transition">إلغاء</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
EOF

# ═══════════════════════════════════════════════════════════════
# 2️⃣ تحديث واجهة الحرفي (Craftsman Dashboard)
# ═══════════════════════════════════════════════════════════════
echo "📝 تحديث واجهة الحرفي..."

cat << 'EOF' > src/app/craftsman/dashboard/page.tsx
'use client'
import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function CraftsmanDashboard() {
  const router = useRouter()
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState('myRequests')
  
  const [myRequests, setMyRequests] = useState<any[]>([])
  const [proposeModal, setProposeModal] = useState<any>(null)
  const [completeModal, setCompleteModal] = useState<any>(null)
  const [proposedPrice, setProposedPrice] = useState('')
  const [finalPrice, setFinalPrice] = useState('')
  const [workNotes, setWorkNotes] = useState('')
  const [actionLoading, setActionLoading] = useState<number | null>(null)
  const [msg, setMsg] = useState('')

  useEffect(() => {
    async function checkAuth() {
      try {
        const res = await fetch('/api/me')
        if (!res.ok) { router.push('/login'); return }
        const data = await res.json()
        if (data.user.role !== 'craftsman') { router.push('/'); return }
        setUser(data.user)
        setLoading(false)
      } catch { router.push('/login') }
    }
    checkAuth()
  }, [router])

  useEffect(() => { if (user) loadRequests() }, [user])

  const loadRequests = async () => {
    try {
      const res = await fetch('/api/craftsman/requests')
      if (res.ok) {
        const data = await res.json()
        setMyRequests(data.requests || [])
      }
    } catch (error) { console.error(error) }
  }

  const handleProposePrice = async () => {
    if (!proposeModal || !proposedPrice || parseFloat(proposedPrice) < 3) {
      setMsg('❌ السعر يجب أن يكون 3 د.ك أو أكثر')
      return
    }
    setActionLoading(proposeModal.id)
    try {
      const res = await fetch('/api/craftsman/propose-price', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId: proposeModal.id, proposedPrice: parseFloat(proposedPrice) })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ تم اقتراح السعر بنجاح')
        setProposeModal(null); setProposedPrice('')
        setTimeout(() => setMsg(''), 3000)
        loadRequests()
      } else { setMsg('❌ ' + (data.error || 'فشل الاقتراح')) }
    } catch { setMsg('❌ حدث خطأ') }
    finally { setActionLoading(null) }
  }

  const handleCompleteWork = async () => {
    if (!completeModal) return
    setActionLoading(completeModal.id)
    try {
      const res = await fetch('/api/craftsman/complete-work', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId: completeModal.id, finalPrice: finalPrice || null, workNotes: workNotes || null })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + data.message)
        setCompleteModal(null); setFinalPrice(''); setWorkNotes('')
        setTimeout(() => setMsg(''), 3000)
        loadRequests()
      } else { setMsg('❌ ' + (data.error || 'فشل الإتمام')) }
    } catch { setMsg('❌ حدث خطأ') }
    finally { setActionLoading(null) }
  }

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' })
    localStorage.removeItem('sana3i_user')
    router.push('/login')
  }

  if (loading) return <div className="min-h-screen flex items-center justify-center bg-gray-50">جاري التحميل...</div>

  const getStatusBadge = (status: string) => {
    const statuses: Record<string, { label: string; color: string; icon: string }> = {
      accepted: { label: 'مقبول', color: 'bg-yellow-100 text-yellow-800', icon: '✅' },
      pending_payment: { label: 'بانتظار دفعة الزيارة', color: 'bg-orange-100 text-orange-800', icon: '💳' },
      pending_approval: { label: 'بانتظار موافقة العميل', color: 'bg-purple-100 text-purple-800', icon: '💰' },
      in_progress: { label: 'قيد التنفيذ', color: 'bg-blue-100 text-blue-800', icon: '🔨' },
      completed: { label: 'مكتمل', color: 'bg-green-100 text-green-800', icon: '✅' },
      paid: { label: 'مدفوع', color: 'bg-purple-100 text-purple-800', icon: '💰' },
    }
    const s = statuses[status] || { label: status, color: 'bg-gray-100 text-gray-800', icon: '📋' }
    return <span className={`px-3 py-1 rounded-full text-xs font-semibold ${s.color}`}>{s.icon} {s.label}</span>
  }

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 flex">
      <aside className="w-64 bg-white shadow-lg p-4 flex flex-col">
        <div className="flex items-center gap-3 mb-8 pb-4 border-b">
          <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center text-green-700 font-bold text-xl">{user?.name?.charAt(0) || 'ح'}</div>
          <div>
            <h2 className="font-bold text-gray-900">{user?.name}</h2>
            <p className="text-xs text-gray-500">حرفي</p>
          </div>
        </div>
        <nav className="space-y-2 flex-1">
          <button onClick={() => setTab('myRequests')} className={`w-full text-right px-4 py-3 rounded-lg text-sm font-bold transition ${tab === 'myRequests' ? 'bg-green-600 text-white' : 'text-gray-700 hover:bg-gray-100'}`}>✅ طلباتي</button>
        </nav>
        <button onClick={handleLogout} className="mt-6 text-sm text-red-600 font-semibold hover:bg-red-50 px-4 py-2 rounded-lg transition">تسجيل الخروج</button>
      </aside>

      <main className="flex-1 p-8 overflow-y-auto">
        <div className="max-w-4xl mx-auto">
          {msg && <div className={`p-4 rounded-lg mb-6 font-bold ${msg.includes('✅') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>{msg}</div>}

          <h1 className="text-3xl font-bold text-gray-900 mb-8">طلباتي</h1>
          {myRequests.length === 0 ? (
            <div className="bg-white rounded-xl shadow-sm p-12 text-center">
              <div className="text-6xl mb-4">📋</div>
              <h3 className="text-xl font-bold text-gray-900 mb-2">لا توجد طلبات</h3>
            </div>
          ) : (
            <div className="space-y-4">
              {myRequests.map((req: any) => (
                <div key={req.id} className="bg-white border rounded-lg p-4 hover:shadow-md transition">
                  <div className="flex justify-between items-start mb-3">
                    <div className="flex items-center gap-3">
                      <div className="text-3xl">{req.category?.icon || '🔧'}</div>
                      <div>
                        <h3 className="font-bold text-gray-900">{req.category?.name || 'خدمة'}</h3>
                        <p className="text-sm text-gray-500">رقم الطلب: #{req.id}</p>
                      </div>
                    </div>
                    {getStatusBadge(req.status)}
                  </div>
                  <p className="text-gray-700 mb-3">{req.description}</p>
                  <div className="p-3 bg-gray-50 rounded-lg mb-4">
                    <p className="text-sm text-gray-700"><span className="font-semibold">العميل:</span> {req.client?.name} <span className="mr-4">📞 {req.client?.phone}</span></p>
                  </div>

                  {req.visitFeePaid && <div className="p-3 bg-green-50 rounded-lg mb-3 border border-green-200"><p className="text-sm text-green-800 font-bold">✅ تم دفع دفعة الزيارة: 3 د.ك</p></div>}
                  {req.proposedPrice && <div className="p-3 bg-purple-50 rounded-lg mb-3 border border-purple-200"><p className="text-sm text-purple-800 font-bold">💰 السعر المقترح: {req.proposedPrice} د.ك | المتبقي: {req.remainingAmount?.toFixed(3)} د.ك</p></div>}
                  {req.finalPrice && <div className="p-3 bg-green-50 rounded-lg mb-3 border border-green-200"><p className="text-sm text-green-800 font-bold">💰 التكلفة النهائية: {req.finalPrice} د.ك</p></div>}
                  
                  <div className="flex gap-2 flex-wrap">
                    {req.status === 'accepted' && req.visitFeePaid && !req.proposedPrice && (
                      <button onClick={() => setProposeModal(req)} className="flex-1 bg-purple-600 text-white py-2.5 rounded-lg font-semibold hover:bg-purple-700 transition">💰 اقتراح السعر النهائي</button>
                    )}
                    {req.status === 'accepted' && !req.visitFeePaid && (
                      <div className="w-full p-3 bg-orange-50 rounded-lg border border-orange-200 text-center"><p className="text-sm text-orange-800 font-bold">⏳ بانتظار دفع العميل لدفعة الزيارة (3 د.ك)</p></div>
                    )}
                    {req.status === 'pending_approval' && (
                      <div className="w-full p-3 bg-purple-50 rounded-lg border border-purple-200 text-center"><p className="text-sm text-purple-800 font-bold">⏳ بانتظار موافقة العميل على السعر</p></div>
                    )}
                    {req.status === 'in_progress' && (
                      <button onClick={() => setCompleteModal(req)} disabled={actionLoading === req.id} className="w-full bg-green-600 text-white py-2.5 rounded-lg font-semibold hover:bg-green-700 transition disabled:opacity-50">
                        {actionLoading === req.id ? 'جاري...' : '✅ إتمام العمل'}
                      </button>
                    )}
                    {(req.status === 'completed' || req.status === 'paid') && (
                      <div className="w-full p-3 bg-green-50 rounded-lg border border-green-200 text-center"><p className="text-sm text-green-800 font-bold">✅ {req.status === 'paid' ? 'تم الدفع' : 'تم إتمام العمل - بانتظار الدفع'}</p></div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>

      {/* Modal اقتراح السعر */}
      {proposeModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full">
            <h3 className="text-xl font-bold text-gray-900 mb-4">💰 اقتراح السعر النهائي</h3>
            <p className="text-sm text-gray-600 mb-4">طلب رقم: #{proposeModal.id}</p>
            <div className="bg-purple-50 p-4 rounded-lg mb-4 border border-purple-200">
              <p className="text-sm text-purple-800 font-bold">💡 ملاحظة:</p>
              <p className="text-sm text-purple-700">دفعة الزيارة (3 د.ك) تم دفعها مسبقاً وستُخصم من الإجمالي.</p>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">السعر الإجمالي المقترح (د.ك) *</label>
                <input type="number" step="0.001" min="3" value={proposedPrice} onChange={(e) => setProposedPrice(e.target.value)} className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 outline-none" placeholder="مثال: 20.000" />
                {proposedPrice && parseFloat(proposedPrice) >= 3 && <p className="text-sm text-green-600 mt-2">💰 المتبقي على العميل: {(parseFloat(proposedPrice) - 3).toFixed(3)} د.ك</p>}
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={handleProposePrice} disabled={actionLoading === proposeModal.id || !proposedPrice || parseFloat(proposedPrice) < 3} className="flex-1 bg-purple-600 hover:bg-purple-700 text-white py-3 rounded-lg font-bold transition disabled:opacity-50">إرسال الاقتراح</button>
              <button onClick={() => { setProposeModal(null); setProposedPrice(''); }} disabled={actionLoading === proposeModal.id} className="px-6 py-3 bg-gray-100 hover:bg-gray-200 rounded-lg font-bold text-gray-700 transition">إلغاء</button>
            </div>
          </div>
        </div>
      )}

      {/* Modal إتمام العمل */}
      {completeModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full">
            <h3 className="text-xl font-bold text-gray-900 mb-4">✅ إتمام العمل</h3>
            <p className="text-sm text-gray-600 mb-4">طلب رقم: #{completeModal.id}</p>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">التكلفة النهائية (د.ك)</label>
                <input type="number" step="0.01" value={finalPrice} onChange={(e) => setFinalPrice(e.target.value)} className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none" placeholder="مثال: 25.000" />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">ملاحظات العمل</label>
                <textarea value={workNotes} onChange={(e) => setWorkNotes(e.target.value)} className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none resize-none" rows={3} placeholder="ملاحظات..." />
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={handleCompleteWork} disabled={actionLoading === completeModal.id} className="flex-1 bg-blue-600 hover:bg-blue-700 text-white py-3 rounded-lg font-bold transition disabled:opacity-50">تأكيد الإتمام</button>
              <button onClick={() => { setCompleteModal(null); setFinalPrice(''); setWorkNotes(''); }} disabled={actionLoading === completeModal.id} className="px-6 py-3 bg-gray-100 hover:bg-gray-200 rounded-lg font-bold text-gray-700 transition">إلغاء</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
EOF

echo "✅ تم تحديث واجهتي العميل والحرفي بنجاح!"
