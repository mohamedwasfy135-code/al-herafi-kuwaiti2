#!/bin/bash
# ============================================================
# سكريبت إكمال دورة حياة الطلب - منصة سناعي
# يشمل: إتمام العمل + الدفع + التقييم
# ============================================================

set -e

echo "🚀 بدء تنفيذ دورة حياة الطلب الكاملة..."
echo "=========================================="

# ═══════════════════════════════════════════════════════════════
# 1️⃣ API إتمام العمل (للحرفي)
# ═══════════════════════════════════════════════════════════════
echo "📝 إنشاء API إتمام العمل..."
mkdir -p src/app/api/craftsman/complete-work

cat << 'EOF' > src/app/api/craftsman/complete-work/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح - يجب تسجيل الدخول كحرفي' }, { status: 401 });
    }

    const body = await request.json();
    const { requestId, finalPrice, workNotes, materialsUsed } = body;

    if (!requestId) {
      return NextResponse.json({ error: 'رقم الطلب مطلوب' }, { status: 400 });
    }

    // جلب الطلب والتحقق من ملكيته
    const req = await db.request.findUnique({
      where: { id: requestId },
      include: { client: true }
    });

    if (!req) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 });
    }

    if (req.craftsmanId !== session.userId) {
      return NextResponse.json({ error: 'هذا الطلب ليس مسنداً لك' }, { status: 403 });
    }

    if (req.status === 'completed' || req.status === 'paid') {
      return NextResponse.json({ error: 'الطلب مكتمل بالفعل' }, { status: 400 });
    }

    // تحديث الطلب
    const updatedRequest = await db.request.update({
      where: { id: requestId },
      data: {
        status: 'completed',
        finalPrice: finalPrice ? parseFloat(finalPrice) : null,
        description: workNotes ? `${req.description}\n\n📝 ملاحظات الحرفي: ${workNotes}` : req.description,
        updatedAt: new Date(),
      },
    });

    // إرسال إشعار للعميل
    await db.notification.create({
      data: {
        userId: req.clientId,
        title: '✅ تم إتمام العمل',
        body: `قام الحرفي بإتمام العمل على طلبك رقم #${requestId}.${finalPrice ? ` التكلفة النهائية: ${finalPrice} د.ك` : ''} يرجى الدفع لتأكيد الطلب.`,
        type: 'work_completed',
      },
    });

    console.log(`✅ [Complete Work] تم إتمام الطلب #${requestId} بواسطة الحرفي ${session.userId}`);

    return NextResponse.json({
      success: true,
      message: 'تم إتمام العمل بنجاح! تم إشعار العميل.',
      request: updatedRequest
    }, { status: 200 });

  } catch (error: any) {
    console.error('❌ خطأ في إتمام العمل:', error);
    return NextResponse.json({ error: error.message || 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
EOF

echo "✅ تم إنشاء API إتمام العمل"

# ═══════════════════════════════════════════════════════════════
# 2️⃣ API تأكيد الدفع (للعميل)
# ═══════════════════════════════════════════════════════════════
echo "📝 إنشاء API تأكيد الدفع..."
mkdir -p src/app/api/payments/confirm

cat << 'EOF' > src/app/api/payments/confirm/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { getSessionFromRequest } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'client') {
      return NextResponse.json({ error: 'غير مصرح - يجب تسجيل الدخول كعميل' }, { status: 401 });
    }

    const body = await request.json();
    const { requestId, paymentMethod } = body;

    if (!requestId) {
      return NextResponse.json({ error: 'رقم الطلب مطلوب' }, { status: 400 });
    }

    const req = await db.request.findUnique({
      where: { id: requestId },
      include: { craftsman: true }
    });

    if (!req) {
      return NextResponse.json({ error: 'الطلب غير موجود' }, { status: 404 });
    }

    if (req.clientId !== session.userId) {
      return NextResponse.json({ error: 'هذا الطلب ليس لك' }, { status: 403 });
    }

    if (req.status !== 'completed') {
      return NextResponse.json({ error: 'لا يمكن الدفع إلا بعد إتمام العمل' }, { status: 400 });
    }

    // تحديث حالة الطلب إلى مدفوع
    await db.request.update({
      where: { id: requestId },
      data: {
        status: 'paid',
        updatedAt: new Date(),
      },
    });

    // إرسال إشعار للحرفي
    if (req.craftsmanId) {
      await db.notification.create({
        data: {
          userId: req.craftsmanId,
          title: '💰 تم استلام الدفع',
          body: `قام العميل بدفع قيمة طلبك رقم #${requestId}. يمكنك الآن سحب الأرباح.`,
          type: 'payment_received',
        },
      });
    }

    // إرسال إشعار للعميل
    await db.notification.create({
      data: {
        userId: session.userId,
        title: '✅ تم تأكيد الدفع',
        body: `تم الدفع بنجاح لطلب رقم #${requestId}. شكراً لاستخدامك منصة سناعي.`,
        type: 'payment_confirmed',
      },
    });

    console.log(`✅ [Payment] تم تأكيد الدفع للطلب #${requestId}`);

    return NextResponse.json({
      success: true,
      message: 'تم تأكيد الدفع بنجاح!',
    }, { status: 200 });

  } catch (error: any) {
    console.error('❌ خطأ في تأكيد الدفع:', error);
    return NextResponse.json({ error: error.message || 'حدث خطأ في الخادم' }, { status: 500 });
  }
}
EOF

echo "✅ تم إنشاء API تأكيد الدفع"

# ═══════════════════════════════════════════════════════════════
# 3️⃣ تحديث واجهة الحرفي (إضافة زر إتمام العمل)
# ═══════════════════════════════════════════════════════════════
echo "📝 تحديث واجهة الحرفي..."

# إنشاء ملف جديد مع الحفاظ على جميع التبويبات
cat << 'EOF' > src/app/craftsman/dashboard/page.tsx
'use client'
import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

export default function CraftsmanDashboard() {
  const router = useRouter()
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState('overview')
  
  const [biddingRequests, setBiddingRequests] = useState<any[]>([])
  const [myRequests, setMyRequests] = useState<any[]>([])
  const [earnings, setEarnings] = useState<any[]>([])
  const [documents, setDocuments] = useState<any>(null)
  const [availability, setAvailability] = useState(true)
  const [notifications, setNotifications] = useState<any[]>([])
  const [completeModal, setCompleteModal] = useState<any>(null)
  const [finalPrice, setFinalPrice] = useState('')
  const [workNotes, setWorkNotes] = useState('')
  
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
      } catch (error) {
        console.error('Auth check error:', error)
        router.push('/login')
      }
    }
    checkAuth()
  }, [router])

  useEffect(() => {
    if (user) loadAllData()
  }, [user])

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
    } catch (error) {
      console.error('Load data error:', error)
    }
  }

  const handleAccept = async (requestId: number) => {
    if (!confirm('هل تريد قبول هذا الطلب؟')) return
    try {
      const res = await fetch('/api/craftsman/assignment-response', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId, action: 'accept' })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + (data.message || 'تم قبول الطلب'))
        setTimeout(() => setMsg(''), 3000)
        loadAllData()
      } else {
        setMsg('❌ ' + (data.error || 'فشل قبول الطلب'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    }
  }

  const handleReject = async (requestId: number) => {
    const reason = prompt('سبب الرفض (اختياري):')
    if (reason === null) return
    try {
      const res = await fetch('/api/craftsman/assignment-response', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId, action: 'reject', rejectionReason: reason })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + (data.message || 'تم رفض الطلب'))
        setTimeout(() => setMsg(''), 3000)
        loadAllData()
      } else {
        setMsg('❌ ' + (data.error || 'فشل رفض الطلب'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    }
  }

  // ✅ دالة جديدة: إتمام العمل
  const handleCompleteWork = async () => {
    if (!completeModal) return
    try {
      const res = await fetch('/api/craftsman/complete-work', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          requestId: completeModal.id,
          finalPrice: finalPrice || null,
          workNotes: workNotes || null,
        })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + data.message)
        setCompleteModal(null)
        setFinalPrice('')
        setWorkNotes('')
        setTimeout(() => setMsg(''), 3000)
        loadAllData()
      } else {
        setMsg('❌ ' + (data.error || 'فشل إتمام العمل'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    }
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
        setMsg(availability ? '❌ أنت الآن غير متاح' : '✅ أنت الآن متاح')
        setTimeout(() => setMsg(''), 3000)
      }
    } catch (error) {
      console.error(error)
    }
  }

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' })
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
    { key: 'overview', label: 'نظرة عامة', icon: '📊' },
    { key: 'bidding', label: 'الطلبات المتاحة', icon: '📋' },
    { key: 'myRequests', label: 'طلباتي', icon: '✅' },
    { key: 'earnings', label: 'الأرباح', icon: '💰' },
    { key: 'chats', label: 'المحادثات', icon: '💬' },
    { key: 'documents', label: 'الوثائق', icon: '📄' },
    { key: 'availability', label: 'التوفر', icon: '🟢' },
    { key: 'changeProfession', label: 'تغيير المهنة', icon: '🔄' },
  ]

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 flex">
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

      <main className="flex-1 p-8 overflow-y-auto">
        <div className="max-w-6xl mx-auto">
          {msg && (
            <div className={`p-4 rounded-lg mb-6 font-bold ${
              msg.includes('✅') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
            }`}>
              {msg}
            </div>
          )}

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
                  <p className="text-3xl font-bold text-gray-900">{myRequests.length}</p>
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

          {tab === 'bidding' && (
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-8">الطلبات المتاحة</h1>
              {biddingRequests.length === 0 ? (
                <div className="bg-white rounded-xl shadow-sm p-12 text-center">
                  <div className="text-6xl mb-4">📭</div>
                  <h3 className="text-xl font-bold text-gray-900 mb-2">لا توجد طلبات متاحة</h3>
                  <p className="text-gray-600">ستظهر هنا الطلبات المناسبة لتخصصك.</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {biddingRequests.map((req: any) => (
                    <div key={req.id} className="bg-white border rounded-lg p-4 hover:shadow-md transition">
                      <div className="flex justify-between items-start mb-3">
                        <div className="flex items-center gap-3">
                          <div className="text-3xl">{req.category?.icon || '🔧'}</div>
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
                          <span className="mr-4">📞 {req.client?.phone}</span>
                        </p>
                      </div>
                      <div className="flex gap-2">
                        <button onClick={() => handleAccept(req.id)} className="flex-1 bg-green-600 text-white py-2 rounded-lg font-semibold hover:bg-green-700 transition">
                          ✅ قبول الطلب
                        </button>
                        <button onClick={() => handleReject(req.id)} className="flex-1 bg-red-600 text-white py-2 rounded-lg font-semibold hover:bg-red-700 transition">
                          ❌ رفض الطلب
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

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
                        <span className={`px-3 py-1 rounded-full text-xs font-semibold ${
                          req.status === 'paid' ? 'bg-green-100 text-green-800' :
                          req.status === 'completed' ? 'bg-blue-100 text-blue-800' :
                          req.status === 'accepted' ? 'bg-yellow-100 text-yellow-800' :
                          'bg-gray-100 text-gray-800'
                        }`}>
                          {req.status === 'paid' ? '💰 مدفوع' :
                           req.status === 'completed' ? '✅ مكتمل' :
                           req.status === 'accepted' ? '🔨 قيد التنفيذ' : req.status}
                        </span>
                      </div>
                      <p className="text-gray-700 mb-3">{req.description}</p>
                      <div className="flex justify-between items-center text-sm text-gray-500 mb-4">
                        <span>📍 {req.address}</span>
                        <span>{new Date(req.createdAt).toLocaleDateString('ar-KW')}</span>
                      </div>
                      {req.finalPrice && (
                        <div className="p-3 bg-green-50 rounded-lg mb-4 border border-green-200">
                          <p className="text-sm text-green-800 font-bold">💰 التكلفة النهائية: {req.finalPrice} د.ك</p>
                        </div>
                      )}
                      {req.status === 'accepted' && (
                        <button
                          onClick={() => setCompleteModal(req)}
                          className="w-full bg-blue-600 text-white py-2.5 rounded-lg font-semibold hover:bg-blue-700 transition"
                        >
                          ✅ إتمام العمل
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

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
              </div>
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

          {tab === 'chats' && (
            <div className="bg-white rounded-xl shadow-sm p-12 text-center">
              <div className="text-6xl mb-4">💬</div>
              <h3 className="text-xl font-bold text-gray-900 mb-2">المحادثات</h3>
              <p className="text-gray-600 mb-4">تواصل مع العملاء مباشرة</p>
              <Link href="/chat" className="inline-block bg-green-600 text-white px-6 py-3 rounded-lg font-bold hover:bg-green-700 transition">
                فتح المحادثات
              </Link>
            </div>
          )}

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

      {/* ✅ Modal إتمام العمل */}
      {completeModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full">
            <h3 className="text-xl font-bold text-gray-900 mb-4">✅ إتمام العمل</h3>
            <p className="text-sm text-gray-600 mb-4">طلب رقم: #{completeModal.id}</p>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">التكلفة النهائية (د.ك) - اختياري</label>
                <input
                  type="number"
                  step="0.01"
                  value={finalPrice}
                  onChange={(e) => setFinalPrice(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                  placeholder="مثال: 25.000"
                />
              </div>
              
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">ملاحظات العمل - اختياري</label>
                <textarea
                  value={workNotes}
                  onChange={(e) => setWorkNotes(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none resize-none"
                  rows={3}
                  placeholder="اكتب أي ملاحظات عن العمل المنجز..."
                />
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={handleCompleteWork}
                className="flex-1 bg-blue-600 hover:bg-blue-700 text-white py-3 rounded-lg font-bold transition"
              >
                ✅ تأكيد الإتمام
              </button>
              <button
                onClick={() => { setCompleteModal(null); setFinalPrice(''); setWorkNotes(''); }}
                className="px-6 py-3 bg-gray-100 hover:bg-gray-200 rounded-lg font-bold text-gray-700 transition"
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
EOF

echo "✅ تم تحديث واجهة الحرفي"

# ═══════════════════════════════════════════════════════════════
# 4️⃣ تحديث واجهة العميل (إضافة زر الدفع والتقييم)
# ═══════════════════════════════════════════════════════════════
echo "📝 تحديث واجهة العميل..."

cat << 'EOF' > src/app/dashboard/client/page.tsx
'use client'
import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { useLanguage } from '@/hooks/useLanguage'

export default function ClientDashboard() {
  const router = useRouter()
  const { language, isRTL } = useLanguage()
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState<'requests' | 'notifications' | 'browse'>('browse')
  
  const [serviceCategories, setServiceCategories] = useState<any[]>([])
  const [businessCategories, setBusinessCategories] = useState<any[]>([])
  const [requests, setRequests] = useState<any[]>([])
  const [notifications, setNotifications] = useState<any[]>([])
  const [loadingRequests, setLoadingRequests] = useState(false)
  const [reviewModal, setReviewModal] = useState<any>(null)
  const [rating, setRating] = useState(5)
  const [comment, setComment] = useState('')
  const [msg, setMsg] = useState('')

  useEffect(() => {
    try {
      const stored = localStorage.getItem('sana3i_user')
      if (stored) {
        const userData = JSON.parse(stored)
        if (userData.role !== 'client') {
          router.push('/login')
        } else {
          setUser(userData)
        }
      } else {
        router.push('/login')
      }
    } catch {
      router.push('/login')
    }
    setLoading(false)
  }, [router])

  useEffect(() => {
    fetch('/api/categories?type=service').then(r => r.json()).then(d => setServiceCategories(d.categories || [])).catch(() => {})
    fetch('/api/categories?type=business').then(r => r.json()).then(d => setBusinessCategories(d.categories || [])).catch(() => {})
  }, [])

  useEffect(() => {
    if (user && activeTab === 'requests') {
      setLoadingRequests(true)
      fetch(`/api/requests?clientId=${user.id}`)
        .then(r => r.json())
        .then(data => {
          setRequests(data.requests || [])
          setLoadingRequests(false)
        })
        .catch(() => setLoadingRequests(false))
    }
    if (user && activeTab === 'notifications') {
      fetch('/api/notifications')
        .then(r => r.json())
        .then(data => setNotifications(data.notifications || []))
        .catch(() => {})
    }
  }, [user, activeTab])

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' })
    localStorage.removeItem('sana3i_user')
    router.push('/login')
  }

  // ✅ زر الدفع
  const handlePay = async (requestId: number) => {
    if (!confirm('هل تريد تأكيد الدفع لهذا الطلب؟')) return
    try {
      const res = await fetch('/api/payments/confirm', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId, paymentMethod: 'cash' })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + data.message)
        setTimeout(() => setMsg(''), 3000)
        fetch(`/api/requests?clientId=${user.id}`)
          .then(r => r.json())
          .then(data => setRequests(data.requests || []))
      } else {
        setMsg('❌ ' + (data.error || 'فشل الدفع'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    }
  }

  // ✅ زر التقييم
  const handleSubmitReview = async () => {
    if (!reviewModal) return
    try {
      const res = await fetch('/api/reviews', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          requestId: reviewModal.id,
          ratedId: reviewModal.craftsmanId,
          stars: rating,
          comment: comment || null,
        })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        setMsg('✅ ' + (data.message || 'تم إضافة التقييم'))
        setReviewModal(null)
        setRating(5)
        setComment('')
        setTimeout(() => setMsg(''), 3000)
      } else {
        setMsg('❌ ' + (data.error || 'فشل إضافة التقييم'))
      }
    } catch (error) {
      setMsg('❌ حدث خطأ')
    }
  }

  const getStatusBadge = (status: string) => {
    const statuses: Record<string, { label: string, color: string, icon: string }> = {
      pending: { label: 'قيد الانتظار', color: 'bg-yellow-100 text-yellow-800', icon: '⏳' },
      assigned: { label: 'تم الإسناد', color: 'bg-blue-100 text-blue-800', icon: '🔧' },
      accepted: { label: 'قيد التنفيذ', color: 'bg-purple-100 text-purple-800', icon: '🔨' },
      completed: { label: 'بانتظار الدفع', color: 'bg-orange-100 text-orange-800', icon: '💳' },
      paid: { label: 'مدفوع', color: 'bg-green-100 text-green-800', icon: '💰' },
      cancelled: { label: 'ملغي', color: 'bg-red-100 text-red-800', icon: '❌' },
    }
    const s = statuses[status] || statuses.pending
    return <span className={`px-3 py-1 rounded-full text-xs font-semibold ${s.color}`}>{s.icon} {s.label}</span>
  }

  if (loading) return <div className="min-h-screen flex items-center justify-center bg-gray-50">جاري التحميل...</div>

  return (
    <div dir={isRTL ? 'rtl' : 'ltr'} className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm p-4 sticky top-0 z-50">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row justify-between items-center gap-4">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-blue-700 font-bold text-xl">
              {user?.name?.charAt(0) || 'ع'}
            </div>
            <div>
              <h1 className="text-xl font-bold text-gray-900">مرحباً، {user?.name}</h1>
              <p className="text-sm text-gray-500">لوحة تحكم العميل</p>
            </div>
          </div>
          
          <div className="flex gap-2 bg-gray-100 p-1 rounded-lg">
            <button onClick={() => setActiveTab('browse')} className={`px-4 py-2 rounded-md text-sm font-semibold transition ${activeTab === 'browse' ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'}`}>
              🔍 تصفح
            </button>
            <button onClick={() => setActiveTab('requests')} className={`px-4 py-2 rounded-md text-sm font-semibold transition ${activeTab === 'requests' ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'}`}>
              📦 طلباتي {requests.length > 0 && `(${requests.length})`}
            </button>
            <button onClick={() => setActiveTab('notifications')} className={`px-4 py-2 rounded-md text-sm font-semibold transition ${activeTab === 'notifications' ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'}`}>
              🔔 الإشعارات {notifications.length > 0 && `(${notifications.length})`}
            </button>
          </div>

          <button onClick={handleLogout} className="text-sm text-red-600 font-semibold hover:bg-red-50 px-3 py-2 rounded-lg transition">
            تسجيل الخروج
          </button>
        </div>
      </header>

      <main className="max-w-6xl mx-auto p-6">
        {msg && (
          <div className={`p-4 rounded-lg mb-6 font-bold ${msg.includes('✅') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
            {msg}
          </div>
        )}

        {activeTab === 'browse' && (
          <div className="space-y-12">
            <section>
              <h2 className="text-2xl font-bold text-gray-900 mb-6 border-r-4 border-blue-600 pr-3">اطلب خدمة حرفي</h2>
              <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-4">
                {serviceCategories.map((cat: any) => (
                  <Link key={cat.id} href={`/create-request?categoryId=${cat.id}&type=service`} className="bg-white p-6 rounded-xl shadow-sm hover:shadow-lg hover:-translate-y-1 transition-all duration-300 text-center border border-gray-100 group">
                    <div className="text-4xl mb-3 group-hover:scale-110 transition-transform">{cat.icon || '🔧'}</div>
                    <h3 className="font-bold text-gray-800 text-sm">{language === 'ar' ? cat.name : (cat.nameEn || cat.name)}</h3>
                  </Link>
                ))}
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold text-gray-900 mb-6 border-r-4 border-green-600 pr-3">تسوق من المحلات</h2>
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
                {businessCategories.map((cat: any) => (
                  <Link key={cat.id} href={`/shops?category=${cat.id}`} className="bg-white p-6 rounded-xl shadow-sm hover:shadow-lg hover:-translate-y-1 transition-all duration-300 text-center border border-gray-100 group">
                    <div className="text-4xl mb-3 group-hover:scale-110 transition-transform">{cat.icon || '🏪'}</div>
                    <h3 className="font-bold text-gray-800 text-sm">{language === 'ar' ? cat.name : (cat.nameEn || cat.name)}</h3>
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
              <Link href="/create-request" className="bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 transition text-sm">
                + طلب جديد
              </Link>
            </div>

            {loadingRequests ? (
              <div className="text-center py-12">
                <div className="animate-spin text-4xl mb-4">⏳</div>
                <p className="text-gray-600">جاري تحميل الطلبات...</p>
              </div>
            ) : requests.length === 0 ? (
              <div className="text-center py-12">
                <div className="text-6xl mb-4">📦</div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">لا توجد طلبات حالياً</h3>
                <p className="text-gray-600 mb-6">ابدأ بإنشاء طلب جديد.</p>
                <Link href="/create-request" className="bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-700 transition inline-block">إنشاء طلب جديد</Link>
              </div>
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

                    <p className="text-gray-700 mb-3 line-clamp-2">{req.description}</p>

                    <div className="flex justify-between items-center text-sm text-gray-500 pt-3 border-t border-gray-100">
                      <span>📍 {req.address}</span>
                      <span>{new Date(req.createdAt).toLocaleDateString('ar-KW')}</span>
                    </div>

                    {req.craftsman && (
                      <div className="mt-3 p-3 bg-blue-50 rounded-lg">
                        <p className="text-sm text-blue-800">
                          <span className="font-semibold">الحرفي:</span> {req.craftsman.name}
                          {req.craftsman.rating && <span className="mr-2">⭐ {req.craftsman.rating}</span>}
                        </p>
                      </div>
                    )}

                    {req.finalPrice && (
                      <div className="mt-3 p-3 bg-green-50 rounded-lg border border-green-200">
                        <p className="text-sm text-green-800 font-bold">💰 التكلفة النهائية: {req.finalPrice} د.ك</p>
                      </div>
                    )}

                    {/* ✅ أزرار الإجراءات */}
                    <div className="mt-4 flex gap-2">
                      {req.status === 'completed' && (
                        <>
                          <button
                            onClick={() => handlePay(req.id)}
                            className="flex-1 bg-green-600 text-white py-2 rounded-lg font-semibold hover:bg-green-700 transition"
                          >
                            💳 تأكيد الدفع
                          </button>
                        </>
                      )}
                      {req.status === 'paid' && req.craftsmanId && (
                        <button
                          onClick={() => setReviewModal(req)}
                          className="flex-1 bg-yellow-500 text-white py-2 rounded-lg font-semibold hover:bg-yellow-600 transition"
                        >
                          ⭐ تقييم الحرفي
                        </button>
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
            {notifications.length === 0 ? (
              <div className="text-center py-12">
                <div className="text-6xl mb-4">🔔</div>
                <p className="text-gray-600">لا توجد إشعارات</p>
              </div>
            ) : (
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

      {/* ✅ Modal التقييم */}
      {reviewModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full">
            <h3 className="text-xl font-bold text-gray-900 mb-4">⭐ تقييم الحرفي</h3>
            <p className="text-sm text-gray-600 mb-4">طلب رقم: #{reviewModal.id}</p>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">التقييم</label>
                <div className="flex gap-2 justify-center">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <button
                      key={star}
                      onClick={() => setRating(star)}
                      className={`text-4xl transition ${star <= rating ? 'text-yellow-400' : 'text-gray-300'}`}
                    >
                      ★
                    </button>
                  ))}
                </div>
              </div>
              
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">تعليقك (اختياري)</label>
                <textarea
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 outline-none resize-none"
                  rows={3}
                  placeholder="شاركنا رأيك في الخدمة..."
                />
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={handleSubmitReview}
                className="flex-1 bg-yellow-500 hover:bg-yellow-600 text-white py-3 rounded-lg font-bold transition"
              >
                ✅ إرسال التقييم
              </button>
              <button
                onClick={() => { setReviewModal(null); setRating(5); setComment(''); }}
                className="px-6 py-3 bg-gray-100 hover:bg-gray-200 rounded-lg font-bold text-gray-700 transition"
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
EOF

echo "✅ تم تحديث واجهة العميل"

# ═══════════════════════════════════════════════════════════════
# 5️⃣ حفظ التغييرات
# ═══════════════════════════════════════════════════════════════
echo "📦 حفظ التغييرات..."
git add src/app/api/craftsman/complete-work/route.ts \
        src/app/api/payments/confirm/route.ts \
        src/app/craftsman/dashboard/page.tsx \
        src/app/dashboard/client/page.tsx

git commit -m "feat: إكمال دورة حياة الطلب

- إضافة API إتمام العمل (مع التكلفة النهائية والملاحظات)
- إضافة API تأكيد الدفع
- تحديث واجهة الحرفي: زر إتمام العمل في تبويب طلباتي
- تحديث واجهة العميل: زر الدفع وزر التقييم
- إضافة Modal التقييم بالنجوم والتعليق
- إشعارات تلقائية لكل مرحلة"

echo ""
echo "=========================================="
echo "✅ تم التنفيذ بنجاح!"
echo "=========================================="
echo ""
echo "📋 الخطوات التالية:"
echo "1. تأكد من أن الخادم يعمل: npm run dev"
echo "2. جرب التدفق الكامل:"
echo "   - العميل ينشئ طلب"
echo "   - الحرفي يقبل الطلب"
echo "   - الحرفي يضغط 'إتمام العمل' ويحدد التكلفة"
echo "   - العميل يضغط 'تأكيد الدفع'"
echo "   - العميل يقيّم الحرفي"
echo ""
echo "3. بعد التأكد من نجاح كل شيء محلياً:"
echo "   git push origin main"
echo "   vercel deploy --prod"
echo ""
echo "🚀 جاهز للاختبار!"
