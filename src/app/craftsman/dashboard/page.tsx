'use client'
import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

export default function CraftsmanDashboard() {
  const router = useRouter()
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState('myRequests')
  
  const [biddingRequests, setBiddingRequests] = useState<any[]>([])
  const [myRequests, setMyRequests] = useState<any[]>([])
  const [earnings, setEarnings] = useState<any[]>([])
  const [documents, setDocuments] = useState<any>(null)
  const [availability, setAvailability] = useState(true)
  const [notifications, setNotifications] = useState<any[]>([])
  const [proposeModal, setProposeModal] = useState<any>(null)
  const [completeModal, setCompleteModal] = useState<any>(null)
  const [proposedPrice, setProposedPrice] = useState('')
  const [finalPrice, setFinalPrice] = useState('')
  const [workNotes, setWorkNotes] = useState('')
  const [actionLoading, setActionLoading] = useState<number | null>(null)
  const [msg, setMsg] = useState('')
  const [payoutRequests, setPayoutRequests] = useState<any[]>([])
  const [availableBalance, setAvailableBalance] = useState(0)
  const [payoutAmount, setPayoutAmount] = useState('')
  const [payoutLoading, setPayoutLoading] = useState(false)
  const [subscriptionPayments, setSubscriptionPayments] = useState<any[]>([])
  const [isRenewing, setIsRenewing] = useState(false)

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

  useEffect(() => { if (user) loadAllData() }, [user])

  const loadAllData = async () => {
    try {
      const biddingRes = await fetch('/api/craftsman/bidding-requests')
      if (biddingRes.ok) {
        const biddingData = await biddingRes.json()
        setBiddingRequests(biddingData.requests || [])
      }

      const myRes = await fetch('/api/craftsman/requests')
      if (myRes.ok) {
        const myData = await myRes.json()
        setMyRequests(myData.requests || [])
      }

      const earningsRes = await fetch('/api/earnings')
      if (earningsRes.ok) {
        const earningsData = await earningsRes.json()
        setEarnings(earningsData.earnings || earningsData.data || [])
        setAvailableBalance(earningsData.availableBalance || 0)
      }

      const payoutRes = await fetch('/api/craftsman/payout-request')
      if (payoutRes.ok) {
        const payoutData = await payoutRes.json()
        setPayoutRequests(payoutData.payouts || [])
      }

      const docsRes = await fetch('/api/craftsman/documents')
      if (docsRes.ok) {
        const docsData = await docsRes.json()
        setDocuments(docsData.document)
      }

      const notifRes = await fetch('/api/notifications')
      if (notifRes.ok) {
        const notifData = await notifRes.json()
        setNotifications(notifData.notifications || [])
      }

      const subRes = await fetch('/api/subscription/history')
      if (subRes.ok) {
        const subData = await subRes.json()
        setSubscriptionPayments(subData.payments || [])
      }
    } catch (error) {
      console.error('Load data error:', error)
    }
  }

  const handleAccept = async (requestId: number) => {
    if (!confirm('هل تريد قبول هذا الطلب؟')) return
    setActionLoading(requestId)
    try {
      const res = await fetch('/api/craftsman/assignment-response', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId, action: 'accept' })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ تم قبول الطلب')
        setTimeout(() => setMsg(''), 3000)
        loadAllData()
      } else {
        setMsg('❌ ' + (data.error || 'فشل قبول الطلب'))
      }
    } catch { setMsg('❌ حدث خطأ') }
    finally { setActionLoading(null) }
  }

  const handleReject = async (requestId: number) => {
    const reason = prompt('سبب الرفض (اختياري):')
    if (reason === null) return
    setActionLoading(requestId)
    try {
      const res = await fetch('/api/craftsman/assignment-response', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId, action: 'reject', rejectionReason: reason })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ تم رفض الطلب')
        setTimeout(() => setMsg(''), 3000)
        loadAllData()
      } else {
        setMsg('❌ ' + (data.error || 'فشل رفض الطلب'))
      }
    } catch { setMsg('❌ حدث خطأ') }
    finally { setActionLoading(null) }
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
        loadAllData()
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
        loadAllData()
      } else { setMsg('❌ ' + (data.error || 'فشل الإتمام')) }
    } catch { setMsg('❌ حدث خطأ') }
    finally { setActionLoading(null) }
  }

  const handlePayoutRequest = async () => {
    const amt = parseFloat(payoutAmount)
    if (!amt || amt <= 0) { setMsg('❌ أدخل مبلغاً صحيحاً'); return }
    if (amt > availableBalance) { setMsg('❌ المبلغ أكبر من رصيدك المتاح'); return }
    setPayoutLoading(true)
    try {
      const res = await fetch('/api/craftsman/payout-request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount: amt })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ تم إرسال طلب السحب، بانتظار موافقة الإدارة')
        setPayoutAmount('')
        loadAllData()
      } else {
        setMsg('❌ ' + (data.error || 'فشل إرسال الطلب'))
      }
    } catch { setMsg('❌ حدث خطأ') }
    finally { setPayoutLoading(false); setTimeout(() => setMsg(''), 4000) }
  }

  const handleRenewSubscription = async () => {
    setIsRenewing(true)
    try {
      const res = await fetch('/api/subscription/create-invoice', { method: 'POST' })
      const data = await res.json()
      if (res.ok && data.success) {
        window.location.href = data.paymentUrl
        setMsg('✅ جاري التوجيه إلى صفحة الدفع الآمنة...')
        setTimeout(() => loadAllData(), 5000) // إعادة التحميل بعد 5 ثواني للتحقق
      } else {
        setMsg('❌ ' + (data.error || 'فشل إنشاء الفاتورة'))
      }
    } catch { setMsg('❌ حدث خطأ في الاتصال') }
    finally { setIsRenewing(false); setTimeout(() => setMsg(''), 4000) }
  }

  const toggleAvailability = async () => {
    try {
      const res = await fetch('/api/craftsman/availability', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isAvailable: !availability })
      })
      if (res.ok) {
        setAvailability(!availability)
        setMsg(availability ? 'أنت الآن غير متاح' : '✅ أنت الآن متاح')
        setTimeout(() => setMsg(''), 3000)
      }
    } catch (error) { console.error(error) }
  }

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' })
    localStorage.removeItem('sana3i_user')
    router.push('/login')
  }

  if (loading) {
    return <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center">
        <div className="animate-spin text-4xl mb-4">⏳</div>
        <p className="text-gray-600">جاري التحميل...</p>
      </div>
    </div>
  }

  const menuItems = [
    { key: 'overview', label: 'نظرة عامة', icon: '' },
    { key: 'bidding', label: 'الطلبات المتاحة', icon: '' },
    { key: 'myRequests', label: 'طلباتي', icon: '✅' },
    { key: 'earnings', label: 'الأرباح', icon: '💰' },
    { key: 'chats', label: 'المحادثات', icon: '💬' },
    { key: 'documents', label: 'الوثائق', icon: '📄' },
    { key: 'availability', label: 'التوفر', icon: '🟢' },
    { key: 'changeProfession', label: 'تغيير المهنة', icon: '🔄' },
    { key: 'subscription', label: 'الاشتراك', icon: '💳' },
  ]

  const getStatusBadge = (status: string) => {
    const statuses: Record<string, { label: string; color: string }> = {
      accepted: { label: 'مقبول', color: 'bg-yellow-100 text-yellow-800' },
      pending_payment: { label: 'بانتظار دفعة الزيارة', color: 'bg-orange-100 text-orange-800' },
      pending_approval: { label: 'بانتظار موافقة العميل', color: 'bg-purple-100 text-purple-800' },
      in_progress: { label: 'قيد التنفيذ', color: 'bg-blue-100 text-blue-800' },
      completed: { label: 'مكتمل', color: 'bg-green-100 text-green-800' },
      paid: { label: 'مدفوع', color: 'bg-purple-100 text-purple-800' },
    }
    const s = statuses[status] || { label: status, color: 'bg-gray-100 text-gray-800' }
    return <span className={`px-3 py-1 rounded-full text-xs font-semibold ${s.color}`}>{s.label}</span>
  }

  const payoutStatusBadge = (status: string) => {
    const map: Record<string, { label: string; color: string }> = {
      pending: { label: 'قيد المراجعة', color: 'bg-yellow-100 text-yellow-800' },
      approved: { label: 'تمت الموافقة', color: 'bg-blue-100 text-blue-800' },
      completed: { label: 'تم التحويل', color: 'bg-green-100 text-green-800' },
      rejected: { label: 'مرفوض', color: 'bg-red-100 text-red-800' },
    }
    const s = map[status] || { label: status, color: 'bg-gray-100 text-gray-800' }
    return <span className={`px-3 py-1 rounded-full text-xs font-semibold ${s.color}`}>{s.label}</span>
  }

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 flex">
      {/* القائمة الجانبية */}
      <aside className="w-64 bg-white shadow-lg p-4 flex flex-col">
        <div className="flex items-center gap-3 mb-8 pb-4 border-b">
          <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center text-green-700 font-bold text-xl">
            {user?.name?.charAt(0) || 'ح'}
          </div>
          <div>
            <h2 className="font-bold text-gray-900">{user?.name}</h2>
            <p className="text-xs text-gray-500">حرفي</p>
          </div>
        </div>
        
        <nav className="space-y-2 flex-1">
          {menuItems.map(item => (
            <button
              key={item.key}
              onClick={() => setTab(item.key)}
              className={`w-full text-right px-4 py-3 rounded-lg text-sm font-bold transition flex items-center gap-2 ${
                tab === item.key ? 'bg-green-600 text-white shadow-md' : 'text-gray-700 hover:bg-gray-100'
              }`}
            >
              <span>{item.icon}</span>
              <span>{item.label}</span>
            </button>
          ))}
        </nav>
        
        <button onClick={handleLogout} className="mt-6 text-sm text-red-600 font-semibold hover:bg-red-50 px-4 py-2 rounded-lg transition">
          تسجيل الخروج
        </button>
      </aside>

      {/* المحتوى الرئيسي */}
      <main className="flex-1 p-8 overflow-y-auto">
        <div className="max-w-6xl mx-auto">
          {(user?.subscriptionStatus !== 'active' && user?.subscriptionStatus !== 'inactive') && (
            <div className="p-4 rounded-lg mb-6 font-bold bg-red-100 text-red-800 border border-red-300 flex justify-between items-center">
              <span>⚠️ اشتراكك منتهي. يرجى تجديد الاشتراك لمواصلة استقبال الطلبات.</span>
              <button onClick={() => setTab('subscription')} className="bg-red-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-red-700 transition">تجديد الآن</button>
            </div>
          )}
          {msg && (
            <div className={`p-4 rounded-lg mb-6 font-bold ${
              msg.includes('✅') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
            }`}>
              {msg}
            </div>
          )}

          {/* نظرة عامة */}
          {tab === 'overview' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">مرحباً، {user?.name}</h1>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                <div className="bg-white rounded-xl shadow-sm p-6 border">
                  <p className="text-gray-600 text-sm font-bold mb-2">طلبات متاحة</p>
                  <p className="text-3xl font-bold text-gray-900">{biddingRequests.length}</p>
                </div>
                <div className="bg-white rounded-xl shadow-sm p-6 border">
                  <p className="text-gray-600 text-sm font-bold mb-2">طلباتي النشطة</p>
                  <p className="text-3xl font-bold text-gray-900">{myRequests.filter(r => r.status !== 'completed' && r.status !== 'paid').length}</p>
                </div>
                <div className="bg-white rounded-xl shadow-sm p-6 border">
                  <p className="text-gray-600 text-sm font-bold mb-2">إجمالي الأرباح</p>
                  <p className="text-3xl font-bold text-green-600">
                    {earnings.reduce((sum: number, e: any) => sum + (parseFloat(e.amount) || 0), 0).toFixed(2)} د.ك
                  </p>
                </div>
                <div className="bg-white rounded-xl shadow-sm p-6 border">
                  <p className="text-gray-600 text-sm font-bold mb-2">حالة التوفر</p>
                  <p className={`text-3xl font-bold ${availability ? 'text-green-600' : 'text-red-600'}`}>
                    {availability ? 'متاح' : 'غير متاح'}
                  </p>
                </div>
              </div>

              <div className="bg-white rounded-xl shadow-sm p-6 border">
                <h2 className="text-xl font-bold text-gray-900 mb-4">آخر الإشعارات</h2>
                {notifications.length === 0 ? (
                  <p className="text-gray-500 text-center py-8">لا توجد إشعارات</p>
                ) : (
                  <div className="space-y-3">
                    {notifications.slice(0, 5).map((notif: any) => (
                      <div key={notif.id} className="p-3 bg-gray-50 rounded-lg">
                        <p className="font-bold text-gray-900">{notif.title}</p>
                        <p className="text-sm text-gray-600">{notif.body}</p>
                        <p className="text-xs text-gray-400 mt-1">{new Date(notif.createdAt).toLocaleString('ar-KW')}</p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* الطلبات المتاحة */}
          {tab === 'bidding' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">الطلبات المتاحة</h1>
              {biddingRequests.length === 0 ? (
                <div className="bg-white rounded-xl shadow-sm p-12 text-center">
                  <div className="text-6xl mb-4"></div>
                  <h3 className="text-xl font-bold text-gray-900 mb-2">لا توجد طلبات متاحة</h3>
                  <p className="text-gray-600">ستظهر هنا الطلبات المناسبة لتخصصك.</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {biddingRequests.map((req: any) => (
                    <div key={req.id} className="bg-white border rounded-lg p-4 hover:shadow-md transition">
                      <div className="flex justify-between items-start mb-3">
                        <div className="flex items-center gap-3">
                          <div className="text-3xl">{req.category?.icon || ''}</div>
                          <div>
                            <h3 className="font-bold text-gray-900">{req.category?.name || 'خدمة'}</h3>
                            <p className="text-sm text-gray-500">رقم الطلب: #{req.id}</p>
                          </div>
                        </div>
                      </div>
                      <p className="text-gray-700 mb-3">{req.description}</p>
                      <div className="flex justify-between items-center text-sm text-gray-500 mb-4">
                        <span>📍 {req.address}</span>
                        <span>{new Date(req.createdAt).toLocaleDateString('ar-KW')}</span>
                      </div>
                      <div className="p-3 bg-gray-50 rounded-lg mb-4">
                        <p className="text-sm text-gray-700">
                          <span className="font-semibold">العميل:</span> {req.client?.name}
                          <span className="mr-4"> {req.client?.phone}</span>
                        </p>
                      </div>
                      <div className="flex gap-2">
                        <button onClick={() => handleAccept(req.id)} disabled={actionLoading === req.id} className="flex-1 bg-green-600 text-white py-2 rounded-lg font-semibold hover:bg-green-700 transition disabled:opacity-50">
                          {actionLoading === req.id ? 'جاري...' : '✅ قبول الطلب'}
                        </button>
                        <button onClick={() => handleReject(req.id)} disabled={actionLoading === req.id} className="flex-1 bg-red-600 text-white py-2 rounded-lg font-semibold hover:bg-red-700 transition disabled:opacity-50">
                          {actionLoading === req.id ? 'جاري...' : '❌ رفض الطلب'}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* طلباتي */}
          {tab === 'myRequests' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">طلباتي</h1>
              {myRequests.length === 0 ? (
                <div className="bg-white rounded-xl shadow-sm p-12 text-center">
                  <div className="text-6xl mb-4">📋</div>
                  <h3 className="text-xl font-bold text-gray-900 mb-2">لا توجد طلبات</h3>
                  <p className="text-gray-600">ستظهر هنا الطلبات التي قبلتها.</p>
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
                      <div className="flex justify-between items-center text-sm text-gray-500 mb-4">
                        <span>📍 {req.address}</span>
                        <span>{new Date(req.createdAt).toLocaleDateString('ar-KW')}</span>
                      </div>
                      <div className="p-3 bg-gray-50 rounded-lg mb-4">
                        <p className="text-sm text-gray-700">
                          <span className="font-semibold">العميل:</span> {req.client?.name}
                          <span className="mr-4">📞 {req.client?.phone}</span>
                        </p>
                      </div>

                      {req.visitFeePaid && <div className="p-3 bg-green-50 rounded-lg mb-3 border border-green-200"><p className="text-sm text-green-800 font-bold">✅ تم دفع دفعة الزيارة: 3 د.ك</p></div>}
                      {req.proposedPrice && <div className="p-3 bg-purple-50 rounded-lg mb-3 border border-purple-200"><p className="text-sm text-purple-800 font-bold">💰 السعر المقترح: {req.proposedPrice} د.ك | المتبقي: {req.remainingAmount?.toFixed(3)} د.ك</p></div>}
                      {req.finalPrice && <div className="p-3 bg-green-50 rounded-lg mb-3 border border-green-200"><p className="text-sm text-green-800 font-bold">💰 التكلفة النهائية: {req.finalPrice} د.ك</p></div>}
                      
                      {req.status === 'accepted' && !req.proposedPrice && (
                        <button onClick={() => setProposeModal(req)} className="w-full bg-purple-600 text-white py-2.5 rounded-lg font-semibold hover:bg-purple-700 transition flex items-center justify-center gap-2">
                          💰 اقتراح السعر النهائي
                        </button>
                      )}

                      {req.status === 'accepted' && req.proposedPrice && (
                        <div className="p-3 bg-purple-50 rounded-lg border border-purple-200 text-center">
                          <p className="text-sm text-purple-800 font-bold">⏳ بانتظار موافقة العميل على السعر</p>
                        </div>
                      )}

                      {req.status === 'pending_payment' && (
                        <div className="p-3 bg-orange-50 rounded-lg border border-orange-200 text-center">
                          <p className="text-sm text-orange-800 font-bold">⏳ بانتظار دفع العميل لدفعة الزيارة (3 د.ك)</p>
                        </div>
                      )}

                      {req.status === 'pending_approval' && (
                        <div className="p-3 bg-purple-50 rounded-lg border border-purple-200 text-center">
                          <p className="text-sm text-purple-800 font-bold">⏳ بانتظار موافقة العميل على السعر</p>
                        </div>
                      )}
                      
                      {req.status === 'in_progress' && (
                        <button onClick={() => setCompleteModal(req)} disabled={actionLoading === req.id} className="w-full bg-green-600 text-white py-2.5 rounded-lg font-semibold hover:bg-green-700 transition disabled:opacity-50 flex items-center justify-center gap-2">
                          {actionLoading === req.id ? 'جاري...' : '✅ إتمام العمل'}
                        </button>
                      )}
                      
                      {(req.status === 'completed' || req.status === 'paid') && (
                        <div className="p-3 bg-green-50 rounded-lg border border-green-200 text-center">
                          <p className="text-sm text-green-800 font-bold">✅ {req.status === 'paid' ? 'تم الدفع' : 'تم إتمام العمل - بانتظار الدفع'}</p>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* الأرباح */}
          {tab === 'earnings' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">الأرباح</h1>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
                <div className="bg-green-50 rounded-xl p-6 border border-green-200">
                  <p className="text-green-700 text-sm font-bold">إجمالي الأرباح</p>
                  <p className="text-3xl font-bold text-green-900 mt-2">
                    {earnings.reduce((sum: number, e: any) => sum + (parseFloat(e.amount) || 0), 0).toFixed(2)} د.ك
                  </p>
                </div>
                <div className="bg-blue-50 rounded-xl p-6 border border-blue-200">
                  <p className="text-blue-700 text-sm font-bold">عدد العمليات</p>
                  <p className="text-3xl font-bold text-blue-900 mt-2">{earnings.length}</p>
                </div>
                <div className="bg-purple-50 rounded-xl p-6 border border-purple-200">
                  <p className="text-purple-700 text-sm font-bold">الرصيد المتاح للسحب</p>
                  <p className="text-3xl font-bold text-purple-900 mt-2">{availableBalance.toFixed(3)} د.ك</p>
                </div>
              </div>

              {/* طلب سحب جديد */}
              <div className="bg-white rounded-xl shadow-sm p-6 border mb-8">
                <h2 className="text-xl font-bold text-gray-900 mb-4">طلب سحب أرباح</h2>
                {availableBalance <= 0 ? (
                  <p className="text-gray-500">ما عندك رصيد متاح للسحب حاليًا.</p>
                ) : (
                  <div className="flex gap-3 items-end flex-wrap">
                    <div className="flex-1 min-w-[200px]">
                      <label className="block text-sm font-bold text-gray-700 mb-2">المبلغ (د.ك)</label>
                      <input
                        type="number"
                        step="0.001"
                        min="0"
                        max={availableBalance}
                        value={payoutAmount}
                        onChange={(e) => setPayoutAmount(e.target.value)}
                        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 outline-none"
                        placeholder={`حتى ${availableBalance.toFixed(3)} د.ك`}
                      />
                    </div>
                    <button
                      onClick={handlePayoutRequest}
                      disabled={payoutLoading || !payoutAmount}
                      className="bg-purple-600 hover:bg-purple-700 text-white px-6 py-3 rounded-lg font-bold transition disabled:opacity-50"
                    >
                      {payoutLoading ? 'جاري الإرسال...' : 'طلب السحب'}
                    </button>
                  </div>
                )}
              </div>

              {/* سجل طلبات السحب */}
              {payoutRequests.length > 0 && (
                <div className="bg-white rounded-xl shadow-sm p-6 border mb-8">
                  <h2 className="text-xl font-bold text-gray-900 mb-4">سجل طلبات السحب</h2>
                  <div className="space-y-3">
                    {payoutRequests.map((p: any) => (
                      <div key={p.id} className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
                        <div>
                          <p className="font-bold text-gray-900">{p.amount} د.ك</p>
                          <p className="text-xs text-gray-500">{new Date(p.createdAt).toLocaleDateString('ar-KW')}</p>
                        </div>
                        {payoutStatusBadge(p.status)}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <div className="bg-white rounded-xl shadow-sm p-6 border">
                <h2 className="text-xl font-bold text-gray-900 mb-4">سجل الأرباح</h2>
                {earnings.length === 0 ? (
                  <p className="text-gray-500 text-center py-8">لا توجد أرباح بعد</p>
                ) : (
                  <div className="space-y-3">
                    {earnings.map((earning: any, idx: number) => (
                      <div key={idx} className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
                        <div>
                          <p className="font-bold text-gray-900">{earning.description || 'ربح'}</p>
                          <p className="text-xs text-gray-500">{new Date(earning.createdAt).toLocaleDateString('ar-KW')}</p>
                        </div>
                        <p className="text-green-600 font-bold text-lg">{earning.amount} د.ك</p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* الاشتراك */}
          {tab === 'subscription' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">إدارة الاشتراك</h1>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
                <div className={`rounded-xl p-6 border ${user?.subscriptionStatus === 'active' ? 'bg-green-50 border-green-200' : 'bg-red-50 border-red-200'}`}>
                  <p className={`text-sm font-bold ${user?.subscriptionStatus === 'active' ? 'text-green-700' : 'text-red-700'}`}>
                    حالة الاشتراك
                  </p>
                  <p className={`text-3xl font-bold mt-2 ${user?.subscriptionStatus === 'active' ? 'text-green-900' : 'text-red-900'}`}>
                    {user?.subscriptionStatus === 'active' ? 'نشط ✅' : 'منتهي ❌'}
                  </p>
                  {user?.subscriptionExpiryDate && (
                    <p className="text-sm text-gray-600 mt-2">
                      ينتهي في: {new Date(user.subscriptionExpiryDate).toLocaleDateString('ar-KW')}
                    </p>
                  )}
                </div>
                <div className="bg-white rounded-xl p-6 border flex flex-col justify-center items-center text-center">
                  <p className="text-gray-700 font-bold mb-4">تجديد الاشتراك الشهري</p>
                  <button 
                    onClick={handleRenewSubscription}
                    disabled={isRenewing}
                    className="bg-purple-600 hover:bg-purple-700 text-white px-8 py-3 rounded-lg font-bold transition disabled:opacity-50 flex items-center gap-2"
                  >
                    {isRenewing ? 'جاري إنشاء الفاتورة...' : '💳 تجديد الاشتراك الآن'}
                  </button>
                </div>
              </div>

              <div className="bg-white rounded-xl shadow-sm p-6 border">
                <h2 className="text-xl font-bold text-gray-900 mb-4">سجل مدفوعات الاشتراك</h2>
                {subscriptionPayments.length === 0 ? (
                  <p className="text-gray-500 text-center py-8">لا توجد مدفوعات سابقة</p>
                ) : (
                  <div className="space-y-3">
                    {subscriptionPayments.map((p: any) => (
                      <div key={p.id} className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
                        <div>
                          <p className="font-bold text-gray-900">{p.amount} د.ك</p>
                          <p className="text-xs text-gray-500">
                            {new Date(p.startDate).toLocaleDateString('ar-KW')} - {new Date(p.endDate).toLocaleDateString('ar-KW')}
                          </p>
                        </div>
                        <span className={`px-3 py-1 rounded-full text-xs font-semibold ${
                          p.status === 'paid' ? 'bg-green-100 text-green-800' : 
                          p.status === 'pending' ? 'bg-yellow-100 text-yellow-800' : 'bg-red-100 text-red-800'
                        }`}>
                          {p.status === 'paid' ? 'مدفوع' : p.status === 'pending' ? 'قيد الانتظار' : 'فشل'}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* المحادثات */}
          {tab === 'chats' && (
            <div className="bg-white rounded-xl shadow-sm border overflow-hidden" style={{ height: '70vh' }}>
              <iframe 
                src="/chat" 
                className="w-full h-full border-0"
                title="نظام المحادثات"
              />
            </div>
          )}

          {/* الوثائق */}
          {tab === 'documents' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">الوثائق</h1>
              <div className="bg-white rounded-xl shadow-sm p-6 border">
                {documents ? (
                  <div>
                    <div className="flex justify-between items-center mb-4">
                      <h2 className="text-xl font-bold text-gray-900">حالة الوثائق</h2>
                      <span className={`px-4 py-2 rounded-full text-sm font-bold ${
                        documents.status === 'approved' ? 'bg-green-100 text-green-800' :
                        documents.status === 'rejected' ? 'bg-red-100 text-red-800' :
                        'bg-yellow-100 text-yellow-800'
                      }`}>
                        {documents.status === 'approved' ? 'معتمدة' :
                         documents.status === 'rejected' ? 'مرفوضة' : 'قيد المراجعة'}
                      </span>
                    </div>
                    <div className="space-y-3">
                      <div className="p-3 bg-gray-50 rounded-lg">
                        <p className="text-sm text-gray-600">البطاقة المدنية</p>
                        <p className="font-bold text-gray-900">
                          {documents.civilIdUrl ? (
                            <a href={documents.civilIdUrl} target="_blank" className="text-blue-600 hover:underline">عرض</a>
                          ) : 'لم يتم الرفع'}
                        </p>
                      </div>
                      <div className="p-3 bg-gray-50 rounded-lg">
                        <p className="text-sm text-gray-600">الحساب البنكي</p>
                        <p className="font-bold text-gray-900">
                          {documents.bankAccountPhotoUrl ? (
                            <a href={documents.bankAccountPhotoUrl} target="_blank" className="text-blue-600 hover:underline">عرض</a>
                          ) : 'لم يتم الرفع'}
                        </p>
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="text-center py-8">
                    <p className="text-gray-600 mb-4">لم تقم برفع الوثائق بعد</p>
                    <Link href="/craftsman/documents" className="inline-block bg-green-600 text-white px-6 py-3 rounded-lg font-bold hover:bg-green-700 transition">
                      رفع الوثائق الآن
                    </Link>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* التوفر */}
          {tab === 'availability' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">حالة التوفر</h1>
              <div className="bg-white rounded-xl shadow-sm p-6 border">
                <div className="flex justify-between items-center mb-6">
                  <div>
                    <h2 className="text-xl font-bold text-gray-900">هل أنت متاح لاستقبال الطلبات؟</h2>
                    <p className="text-gray-600 mt-2">عندما تكون متاحاً، ستظهر لك الطلبات المناسبة</p>
                  </div>
                  <button
                    onClick={toggleAvailability}
                    className={`px-8 py-4 rounded-lg font-bold text-lg transition ${
                      availability ? 'bg-green-600 text-white hover:bg-green-700' : 'bg-red-600 text-white hover:bg-red-700'
                    }`}
                  >
                    {availability ? '🟢 متاح' : '🔴 غير متاح'}
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* تغيير المهنة */}
          {tab === 'changeProfession' && (
            <div className="bg-white rounded-xl shadow-sm p-12 text-center">
              <div className="text-6xl mb-4">🔄</div>
              <h3 className="text-xl font-bold text-gray-900 mb-2">تغيير المهنة</h3>
              <p className="text-gray-600 mb-4">هل تريد تغيير تخصصك؟</p>
              <Link href="/craftsman/change-profession" className="inline-block bg-green-600 text-white px-6 py-3 rounded-lg font-bold hover:bg-green-700 transition">
                طلب تغيير المهنة
              </Link>
            </div>
          )}
        </div>
      </main>

      {/* Modal اقتراح السعر */}
      {proposeModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full">
            <h3 className="text-xl font-bold text-gray-900 mb-4"> اقتراح السعر النهائي</h3>
            <p className="text-sm text-gray-600 mb-4">طلب رقم: #{proposeModal.id}</p>
            <div className="bg-purple-50 p-4 rounded-lg mb-4 border border-purple-200">
              <p className="text-sm text-purple-800 font-bold">💡 ملاحظة:</p>
              <p className="text-sm text-purple-700">دفعة الزيارة (3 د.ك) ستُخصم من الإجمالي بعد موافقة العميل.</p>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">السعر الإجمالي المقترح (د.ك) *</label>
                <input type="number" step="0.001" min="3" value={proposedPrice} onChange={(e) => setProposedPrice(e.target.value)} className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 outline-none" placeholder="مثال: 20.000" />
                {proposedPrice && parseFloat(proposedPrice) >= 3 && <p className="text-sm text-green-600 mt-2">💰 المتبقي على العميل بعد دفعة الزيارة: {(parseFloat(proposedPrice) - 3).toFixed(3)} د.ك</p>}
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
