'use client'
import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'

export default function ClientDashboard() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState('browse')
  
  const [serviceCategories, setServiceCategories] = useState<any[]>([])
  const [businessCategories, setBusinessCategories] = useState<any[]>([])
  const [requests, setRequests] = useState<any[]>([])
  const [notifications, setNotifications] = useState<any[]>([])
  const [loadingRequests, setLoadingRequests] = useState(false)
  const [msg, setMsg] = useState('')
  const [chats, setChats] = useState<any[]>([])
  const [loadingChats, setLoadingChats] = useState(false)

  useEffect(() => {
    const successMsg = searchParams.get('msg')
    if (successMsg === 'visit_fee_paid') setMsg('✅ تم دفع دفعة الزيارة بنجاح!')
    else if (successMsg === 'final_payment_paid') setMsg('✅ تم الدفع النهائي بنجاح! شكراً لك!')
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
    if (!user) return
    fetch('/api/categories?type=service').then(r => r.json()).then(d => setServiceCategories(d.categories || [])).catch(() => {})
    fetch('/api/categories?type=business').then(r => r.json()).then(d => setBusinessCategories(d.categories || [])).catch(() => {})
  }, [user])

  useEffect(() => {
    if (!user) return
    if (activeTab === 'requests') {
      setLoadingRequests(true)
      fetch(`/api/requests?clientId=${user.id}`)
        .then(r => r.json())
        .then(data => { setRequests(data.requests || []); setLoadingRequests(false) })
        .catch(() => setLoadingRequests(false))
    }
    if (activeTab === 'notifications') {
      fetch('/api/notifications').then(r => r.json()).then(data => setNotifications(data.notifications || [])).catch(() => {})
    }
    if (activeTab === 'chats') {
      setLoadingChats(true)
      fetch('/api/chats', { credentials: 'include' })
        .then(r => r.json())
        .then(data => {
          const raw = data.chats || data.data || []
          const formatted = raw.map((c: any) => {
            const other = c.participant1?.id === user.id ? c.participant2 : c.participant1
            return { ...c, otherUser: c.otherUser || other }
          })
          setChats(formatted)
          setLoadingChats(false)
        })
        .catch(() => setLoadingChats(false))
    }
  }, [user, activeTab])

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' })
    localStorage.removeItem('sana3i_user')
    router.push('/login')
  }

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

  const handleFinalPayment = async (requestId: number) => {
    if (!confirm('هل تريد الانتقال لصفحة الدفع النهائي؟')) return
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
    } catch (error) { setMsg(' حدث خطأ') }
  }

  const handlePriceAction = async (requestId: number, action: 'approve' | 'reject') => {
    if (action === 'approve' && !confirm('هل توافق على السعر المقترح؟')) return
    if (action === 'reject' && !confirm('هل ترفض السعر المقترح؟')) return
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






  const getIcon = (name: string) => {
    const map: Record<string, string> = { 
      'wrench': '🔧', 'zap': '⚡', 'snowflake': '❄️', 'grid': '',
      'shield': '🛡️', 'video': '📹', 'wifi': '📶', 'cpu': '💻',
      'sparkles': '✨', 'paint-bucket': '🎨', 'truck': '🚚',
      'tree': '', 'store': '🏪', 'hammer': '🔨', 'anvil': '️',
      'appliance': '', 'bug': '🐛'
    };
    return map[name] || '🔧';
  };

  const getStatusBadge = (status: string) => {
    const statuses: Record<string, { label: string; color: string }> = {
      pending: { label: 'قيد الانتظار', color: 'bg-yellow-100 text-yellow-800' },
      accepted: { label: 'تم القبول', color: 'bg-indigo-100 text-indigo-800' },
      pending_payment: { label: 'بانتظار دفعة الزيارة', color: 'bg-orange-100 text-orange-800' },
      pending_approval: { label: 'بانتظار الموافقة على السعر', color: 'bg-purple-100 text-purple-800' },
      in_progress: { label: 'الحرفي يعمل', color: 'bg-blue-100 text-blue-800' },
      completed: { label: 'مكتمل - بانتظار الدفع', color: 'bg-orange-100 text-orange-800' },
      paid: { label: 'مدفوع', color: 'bg-green-100 text-green-800' },
    }
    const s = statuses[status] || statuses.pending
    return <span className={`px-3 py-1.5 rounded-full text-xs font-semibold ${s.color}`}>{s.label}</span>
  }

  
  const handleStartChat = async (craftsmanId: string, requestId: number) => {
    if (!user) return;
    try {
      const res = await fetch('/api/chat/conversations', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ craftsmanId, requestId })
      });
      const data = await res.json();
      if (data.success && data.conversation) {
        window.location.href = `/chat?conversationId=${data.conversation.id}`;
      } else {
        alert(data.error || 'فشل بدء المحادثة');
      }
    } catch (error) {
      console.error('Error starting chat:', error);
      alert('حدث خطأ في الاتصال');
    }
  }

  if (loading) return <div className="p-8 text-center text-gray-500">جاري التحميل...</div>; <div className="min-h-screen flex items-center justify-center bg-gray-50">جاري التحميل...</div>

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm p-4 sticky top-0 z-50">
        <div className="max-w-6xl mx-auto">
          <div className="flex flex-col md:flex-row justify-between items-center gap-4">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-blue-700 font-bold text-xl">
                {user?.name?.charAt(0) || 'ع'}
              </div>
              <div>
                <h1 className="text-xl font-bold text-gray-900">مرحباً، {user?.name || 'عميل'}</h1>
                <p className="text-sm text-gray-500">لوحة تحكم العميل</p>
              </div>
            </div>
            
            <div className="flex gap-2 bg-gray-100 p-1 rounded-lg">
              <button onClick={() => setActiveTab('browse')} className={`px-4 py-2 rounded-md text-sm font-semibold transition ${activeTab === 'browse' ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-600'}`}>🔍 تصفح</button>
              <button onClick={() => setActiveTab('requests')} className={`px-4 py-2 rounded-md text-sm font-semibold transition ${activeTab === 'requests' ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-600'}`}>📦 طلباتي {requests.length > 0 && `(${requests.length})`}</button>
              <button onClick={() => setActiveTab('notifications')} className={`px-4 py-2 rounded-md text-sm font-semibold transition ${activeTab === 'notifications' ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-600'}`}>🔔 الإشعارات {notifications.length > 0 && `(${notifications.length})`}</button>
              <button onClick={() => setActiveTab('chats')} className={`px-4 py-2 rounded-md text-sm font-semibold transition ${activeTab === 'chats' ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-600'}`}>💬 المحادثات {chats.length > 0 && `(${chats.length})`}</button>
            </div>

            <button onClick={handleLogout} className="text-sm text-red-600 font-semibold hover:bg-red-50 px-3 py-2 rounded-lg">تسجيل الخروج</button>
          </div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto p-6">
        {msg && <div className={`p-4 rounded-lg mb-6 font-bold ${msg.includes('✅') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>{msg}</div>}

        {activeTab === 'browse' && (
          <div className="space-y-12">
            <section>
              <h2 className="text-2xl font-bold text-gray-900 mb-6 border-r-4 border-blue-600 pr-3">اطلب خدمة حرفي</h2>
              <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-4">
                {serviceCategories.map((cat: any) => (
                  <Link key={cat.id} href={`/create-request?categoryId=${cat.id}&type=service`} className="bg-white p-6 rounded-xl shadow-sm hover:shadow-lg transition text-center border">
                    <div className="text-4xl mb-3">{getIcon(cat.icon)}</div>
                    <h3 className="font-bold text-gray-800 text-sm">{cat.name}</h3>
                  </Link>
                ))}
              </div>
            </section>
            <section>
              <h2 className="text-2xl font-bold text-gray-900 mb-6 border-r-4 border-green-600 pr-3">تسوق من المحلات</h2>
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
                {businessCategories.map((cat: any) => (
                  <Link key={cat.id} href={`/shops?category=${cat.id}`} className="bg-white p-6 rounded-xl shadow-sm hover:shadow-lg transition text-center border">
                    <div className="text-4xl mb-3">{getIcon(cat.icon)}</div>
                    <h3 className="font-bold text-gray-800 text-sm">{cat.name}</h3>
                  </Link>
                ))}
              </div>
            </section>
          </div>
        )}

        {activeTab === 'requests' && (
          <div className="bg-white rounded-xl shadow-sm p-6">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-bold text-gray-900">طلباتي</h2>
              <Link href="/create-request" className="bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 text-sm">+ طلب جديد</Link>
            </div>
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
                        <div className="text-3xl">{getIcon(req.category?.icon)}</div>
                        <div>
                          <h3 className="font-bold text-gray-900">{req.category?.name || 'خدمة'}</h3>
                          <p className="text-sm text-gray-500">رقم الطلب: #{req.id}</p>
                        </div>
                      </div>
                      {getStatusBadge(req.status)}
                    </div>
                    <p className="text-gray-700 mb-3">{req.description}</p>
                    
                    {req.craftsman && (
                      <div className="mt-3 p-3 bg-blue-50 rounded-lg flex justify-between items-center gap-3">
                        <p className="text-sm text-blue-800"><span className="font-semibold">الحرفي:</span> {req.craftsman.name} {req.craftsman.phone && `| 📞 ${req.craftsman.phone}`}</p>
                        <button 
                          onClick={() => handleStartChat(req.craftsman.id, req.id)}
                          className="bg-blue-600 text-white text-xs px-4 py-2 rounded-lg hover:bg-blue-700 transition flex items-center gap-1 font-bold whitespace-nowrap"
                        >
                          💬 محادثة
                        </button>
                      </div>
                    )}

                    {req.proposedPrice != null && (
                      <div className="mt-3 p-4 bg-purple-50 rounded-lg border-2 border-purple-200">
                        <p className="text-lg text-purple-900 font-bold mb-1">💰 السعر المقترح: {req.proposedPrice} د.ك</p>
                        <p className="text-sm text-purple-700">المتبقي بعد خصم دفعة الزيارة (3 د.ك): <span className="font-bold">{req.remainingAmount?.toFixed(3)} د.ك</span></p>
                      </div>
                    )}

                    {req.visitFeePaid && <div className="mt-3 p-3 bg-green-50 rounded-lg border border-green-200"><p className="text-sm text-green-800 font-bold">✅ تم دفع دفعة الزيارة: 3 د.ك</p></div>}
                    
                    {req.finalPrice && <div className="mt-3 p-3 bg-indigo-50 rounded-lg border border-indigo-200"><p className="text-sm text-indigo-800 font-bold">💰 التكلفة النهائية للعمل: {req.finalPrice} د.ك</p></div>}

                    <div className="mt-4 flex gap-2 flex-wrap">
                      {req.status === 'pending_approval' && req.proposedPrice != null && (
                        <>
                          <button onClick={() => handlePriceAction(req.id, 'approve')} className="flex-1 bg-green-600 text-white py-3 rounded-lg font-bold hover:bg-green-700 transition">✅ الموافقة على السعر</button>
                          <button onClick={() => handlePriceAction(req.id, 'reject')} className="flex-1 bg-red-600 text-white py-3 rounded-lg font-bold hover:bg-red-700 transition">❌ رفض السعر</button>
                        </>
                      )}
                      
                      {req.status === 'pending_payment' && (
                        <button onClick={() => handlePayVisitFee(req.id)} className="w-full bg-orange-600 text-white py-3 rounded-lg font-bold hover:bg-orange-700 transition">💳 دفع دفعة الزيارة (3 د.ك)</button>
                      )}

                      {req.status === 'completed' && req.remainingAmount > 0 && (
                        <button onClick={() => handleFinalPayment(req.id)} className="w-full bg-green-600 text-white py-3 rounded-lg font-bold hover:bg-green-700 transition shadow-md">
                          💳 الدفع النهائي ({req.remainingAmount?.toFixed(3)} د.ك)
                        </button>
                      )}

                      {req.status === 'paid' && (
                        <div className="w-full p-3 bg-green-50 rounded-lg border border-green-200 text-center">
                          <p className="text-sm text-green-800 font-bold">✅ تم الدفع بالكامل. شكراً لك!</p>
                        </div>
                      )}

                      {req.status === 'accepted' && (req.proposedPrice == null) && (
                        <div className="w-full p-3 bg-indigo-50 rounded-lg border border-indigo-200 text-center">
                          <p className="text-sm text-indigo-800 font-bold"> الحرفي سيقترح السعر قريباً...</p>
                        </div>
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
        {activeTab === 'chats' && (
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-2xl font-bold text-gray-900 mb-6">المحادثات</h2>
            {loadingChats ? (
              <div className="text-center py-12"><div className="animate-spin text-4xl mb-4">⏳</div><p className="text-gray-600">جاري التحميل...</p></div>
            ) : chats.length === 0 ? (
              <div className="text-center py-12"><div className="text-6xl mb-4">💬</div><h3 className="text-xl font-bold text-gray-900 mb-2">لا توجد محادثات بعد</h3></div>
            ) : (
              <div className="space-y-3">
                {chats.map((chat: any) => (
                  <div
                    key={chat.id}
                    onClick={() => window.location.href = `/chat?conversationId=${chat.id}`}
                    className="border border-gray-200 rounded-lg p-4 hover:shadow-md hover:bg-gray-50 transition cursor-pointer flex justify-between items-center gap-3"
                  >
                    <div>
                      <h3 className="font-bold text-gray-900">{chat.otherUser?.name || 'محادثة'}</h3>
                      {chat.lastMessage && <p className="text-sm text-gray-500 truncate max-w-xs">{chat.lastMessage}</p>}
                    </div>
                    <span className="text-blue-600 text-sm font-semibold whitespace-nowrap">فتح ←</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </main>
    </div>
  )
}
