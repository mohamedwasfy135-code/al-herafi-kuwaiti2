'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function CraftsmanBidding() {
  const router = useRouter()
  const [requests, setRequests] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [showBidModal, setShowBidModal] = useState<any>(null)
  const [bidAmount, setBidAmount] = useState('')
  const [bidNotes, setBidNotes] = useState('')
  const [msg, setMsg] = useState('')

  useEffect(() => {
    const user = JSON.parse(localStorage.getItem('sana3i_user') || '{}')
    if (!user.id || user.role !== 'craftsman') {
      router.push('/login')
      return
    }
    fetchRequests(user.id)
  }, [router])

  const fetchRequests = async (craftsmanId: string) => {
    try {
      const res = await fetch(`/api/craftsman/bidding-requests?craftsmanId=${craftsmanId}`)
      const data = await res.json()
      console.log('📦 البيانات المستقبلة:', data.requests)
      setRequests(data.requests || [])
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const submitBid = async (requestId: number) => {
    if (!bidAmount || parseFloat(bidAmount) <= 0) {
      setMsg('يرجى إدخال سعر صحيح')
      return
    }
    const user = JSON.parse(localStorage.getItem('sana3i_user') || '{}')
    try {
      const res = await fetch('/api/craftsman/submit-bid', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          requestId,
          craftsmanId: user.id,
          amount: parseFloat(bidAmount),
          notes: bidNotes
        })
      })
      const data = await res.json()
      if (res.ok) {
        setMsg('✅ تم إرسال عرض السعر بنجاح')
        setShowBidModal(null)
        setBidAmount('')
        setBidNotes('')
        fetchRequests(user.id)
      } else {
        setMsg(`❌ ${data.error}`)
      }
    } catch (err) {
      setMsg('حدث خطأ')
    }
    setTimeout(() => setMsg(''), 3000)
  }

  if (loading) return <div className="p-8 text-center">جار التحميل...</div>

  return (
    <div dir="rtl" className="max-w-4xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">طلبات التسعير المستلمة</h1>
      {msg && <div className="bg-green-100 text-green-700 p-3 rounded mb-4">{msg}</div>}
      {requests.length === 0 ? (
        <div className="bg-white rounded-xl shadow p-12 text-center text-gray-700">
          لا توجد طلبات تسعير حالياً
        </div>
      ) : (
        <div className="space-y-4">
          {requests.map((req) => (
            <div key={req.assignment_id} className="bg-white rounded-xl shadow p-6 border-r-4 border-blue-500">
              <div className="flex justify-between items-start">
                <div>
                  <p className="font-bold text-lg">{req.service_type}</p>
                  <p className="text-gray-600 mt-1">{req.description}</p>
                  <p className="text-sm text-gray-700 mt-2">العميل: {req.client_name} - {req.client_phone}</p>
                  <p className="text-xs text-red-500 mt-1">تنتهي المهلة: {new Date(req.expires_at).toLocaleString('ar')}</p>
                </div>
                {/* الزر يظهر دائماً بغض النظر عن وجود عرض سابق */}
                <button
                  onClick={() => setShowBidModal(req)}
                  className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg"
                >
                  {req.my_bid_amount ? `تعديل العرض (${req.my_bid_amount} د.ك)` : 'تقديم عرض سعر'}
                </button>
              </div>
              <div className="mt-3 text-sm text-gray-700">
                عدد العروض المقدمة: {req.total_bids || 0}
              </div>
            </div>
          ))}
        </div>
      )}

      {showBidModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl shadow-xl p-6 max-w-md w-full mx-4">
            <h3 className="text-lg font-bold mb-4">تقديم عرض سعر</h3>
            <p className="text-sm text-gray-700 mb-2">الطلب: {showBidModal.service_type}</p>
            <label className="block text-sm font-bold mb-1">السعر (د.ك)</label>
            <input
              type="number"
              value={bidAmount}
              onChange={(e) => setBidAmount(e.target.value)}
              className="w-full border rounded-lg px-3 py-2 mb-4"
              placeholder="مثال: 25"
            />
            <label className="block text-sm font-bold mb-1">ملاحظات (اختياري)</label>
            <textarea
              value={bidNotes}
              onChange={(e) => setBidNotes(e.target.value)}
              className="w-full border rounded-lg px-3 py-2 mb-4"
              rows={3}
              placeholder="أضف تفاصيل عن الخدمة..."
            />
            <div className="flex gap-2">
              <button onClick={() => submitBid(showBidModal.request_id)} className="flex-1 bg-green-600 text-white py-2 rounded-lg">
                إرسال العرض
              </button>
              <button onClick={() => setShowBidModal(null)} className="px-4 py-2 bg-gray-100 rounded-lg">
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
