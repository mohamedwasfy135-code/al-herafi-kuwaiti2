'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useLanguage } from '@/hooks/useLanguage'

export default function AdminDashboard() {
  const router = useRouter()
  const { language, t, changeLanguage, isRTL } = useLanguage()
  
  const [admin, setAdmin] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState('overview')
  const [stats, setStats] = useState<any>(null)
  const [users, setUsers] = useState<any[]>([])
  const [requests, setRequests] = useState<any[]>([])
  const [payouts, setPayouts] = useState<any[]>([])
  const [craftsmen, setCraftsmen] = useState<any[]>([])
  const [assignModal, setAssignModal] = useState<any>(null)
  const [selectedCraftsman, setSelectedCraftsman] = useState('')
  const [reassignModal, setReassignModal] = useState<any>(null)
  const [msg, setMsg] = useState('')
  const [changeRequests, setChangeRequests] = useState<any[]>([])
  const [earnings, setEarnings] = useState<any[]>([])
  const [financials, setFinancials] = useState<any>(null)
  const [pendingDocs, setPendingDocs] = useState<any[]>([])
  const [pendingRefunds, setPendingRefunds] = useState<any[]>([])
  const [interventionRequests, setInterventionRequests] = useState<any[]>([])

  useEffect(() => {
    async function checkSession() {
      try {
        const res = await fetch('/api/me')
        if (!res.ok) { router.push('/login'); return }
        const data = await res.json()
        if (data.user.role !== 'admin') { router.push('/'); return }
        setAdmin(data.user)
        loadAll()
      } catch (error) {
        console.error('Session check error:', error)
        router.push('/login')
      } finally {
        setLoading(false)
      }
    }
    checkSession()
  }, [router])

  // ✅ تحديث تلقائي كل 30 ثانية بدون الحاجة لريفرش يدوي
  useEffect(() => {
    if (!admin) return
    const interval = setInterval(() => {
      loadAll()
    }, 30000)
    return () => clearInterval(interval)
  }, [admin])

  const loadAll = async () => {
    try {
      const [
        statsRes, usersRes, reqRes, payoutRes, changeReqRes, earningsRes, financialsRes,
        docsRes, refundsRes, interventionRes
      ] = await Promise.all([
        fetch('/api/admin/stats').catch(() => null),
        fetch('/api/admin/users').catch(() => null),
        fetch('/api/admin/requests').catch(() => null),
        fetch('/api/admin/payouts').catch(() => null),
        fetch('/api/admin/change-requests').catch(() => null),
        fetch('/api/earnings').catch(() => null),
        fetch('/api/admin/financials').catch(() => null),
        fetch('/api/admin/documents').catch(() => null),
        fetch('/api/admin/refund-requests').catch(() => null),
        fetch('/api/admin/intervention-requests').catch(() => null),
      ])

      const statsData = statsRes?.ok ? await statsRes.json() : {}
      const usersData = usersRes?.ok ? await usersRes.json() : { users: [] }
      const reqData = reqRes?.ok ? await reqRes.json() : { requests: [] }
      const payoutData = payoutRes?.ok ? await payoutRes.json() : { payouts: [] }
      const changeReqData = changeReqRes?.ok ? await changeReqRes.json() : { requests: [] }
      const earningsData = earningsRes?.ok ? await earningsRes.json() : { earnings: [] }
      const financialsData = financialsRes?.ok ? await financialsRes.json() : null
      const docsData = docsRes?.ok ? await docsRes.json() : { documents: [] }
      const refundsData = refundsRes?.ok ? await refundsRes.json() : { refunds: [] }
      const interventionData = interventionRes?.ok ? await interventionRes.json() : { requests: [] }

      setStats(statsData)
      setUsers(usersData.users || [])
      setRequests(reqData.requests || [])
      setPayouts(payoutData.payouts || [])
      setChangeRequests(changeReqData.requests || [])
      setEarnings(earningsData.earnings || earningsData.data || [])
      setFinancials(financialsData?.summary || null)
      setPendingDocs(docsData.documents || [])
      setPendingRefunds(refundsData.refunds || [])
      setInterventionRequests(interventionData.requests || [])
      setCraftsmen((usersData.users || []).filter((x: any) => x.role === 'craftsman' && x.verification_status === 'approved'))
    } catch (err) {
      console.error('LoadAll error:', err)
      setMsg('حدث خطأ في تحميل البيانات')
    }
  }

  const updateUserStatus = async (userId: string, field: string, value: string) => {
    try {
      await fetch('/api/admin/users', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ userId, field, value }) })
      await loadAll()
      setMsg('✅ تم التحديث')
      setTimeout(() => setMsg(''), 3000)
    } catch (err) { console.error(err) }
  }

  const assignRequest = async () => {
    if (!assignModal || !selectedCraftsman) return
    try {
      await fetch('/api/admin/requests', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ requestId: assignModal.id, craftsmanId: selectedCraftsman, status: 'accepted' }) })
      setAssignModal(null)
      setSelectedCraftsman('')
      await loadAll()
      setMsg('✅ تم إسناد الطلب')
      setTimeout(() => setMsg(''), 3000)
    } catch (err) { console.error(err) }
  }

  const reassignRequest = async () => {
    if (!reassignModal || !selectedCraftsman) {
      setMsg("❌ يرجى اختيار حرفي جديد")
      setTimeout(() => setMsg(""), 3000)
      return
    }
    try {
      const res = await fetch('/api/admin/reassign-request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId: reassignModal.id, newCraftsmanId: selectedCraftsman, oldCraftsmanId: reassignModal.craftsmanId })
      })
      if (res.ok) {
        setMsg('✅ تم إعادة الإسناد وإرسال الإشعارات')
        setReassignModal(null)
        setSelectedCraftsman('')
        await loadAll()
      } else {
        setMsg('❌ فشل إعادة الإسناد')
      }
      setTimeout(() => setMsg(''), 3000)
    } catch (err) { console.error(err) }
  }

  const updatePayout = async (payoutId: string, status: string) => {
    try {
      const res = await fetch('/api/admin/payouts', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ payoutId, status }) })
      if (res.ok) {
        setMsg(status === 'approved' ? '✅ تمت الموافقة على طلب السحب' : '❌ تم رفض طلب السحب')
      } else {
        setMsg('❌ حدث خطأ أثناء تحديث طلب السحب')
      }
      await loadAll()
      setTimeout(() => setMsg(''), 3000)
    } catch (err) { console.error(err) }
  }

  const handleChangeRequest = async (requestId: number, action: 'approve' | 'reject') => {
    try {
      const res = await fetch('/api/admin/change-requests', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId, action })
      })
      if (res.ok) {
        setMsg(action === 'approve' ? '✅ تمت الموافقة على تغيير الحرفة' : ' تم رفض طلب تغيير الحرفة')
        await loadAll()
      } else {
        setMsg('❌ حدث خطأ')
      }
      setTimeout(() => setMsg(''), 3000)
    } catch (err) { console.error(err) }
  }

  const handleDocumentAction = async (documentId: number, action: 'approve' | 'reject') => {
    try {
      const res = await fetch('/api/admin/documents', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ documentId, action, adminId: admin?.id })
      })
      if (res.ok) {
        setMsg(action === 'approve' ? '✅ تم اعتماد المستندات' : '❌ تم رفض المستندات')
        await loadAll()
      } else {
        setMsg('❌ حدث خطأ')
      }
      setTimeout(() => setMsg(''), 3000)
    } catch (err) { console.error(err) }
  }

  const handleRefundAction = async (refundId: number, action: 'approve' | 'reject', adminNotes?: string) => {
    try {
      const res = await fetch('/api/admin/refund-requests', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refundId, action, adminNotes })
      })
      if (res.ok) {
        setMsg(action === 'approve' ? '✅ تمت الموافقة على الاسترداد' : '❌ تم رفض الاسترداد')
        await loadAll()
      } else {
        setMsg('❌ حدث خطأ')
      }
      setTimeout(() => setMsg(''), 3000)
    } catch (err) { console.error(err) }
  }

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' })
    router.push('/login')
  }

  if (loading) return <div className="p-8 text-center text-gray-900 text-xl font-bold">{t('common.loading')}</div>
  if (!admin) return <div className="p-8 text-center text-gray-900 text-xl font-bold">{t('auth.login')}</div>

  const menuItems = [
    { key: 'overview', label: t('admin.overview'), icon: '📊' },
    { key: 'users', label: t('admin.users'), icon: '👥' },
    { key: 'requests', label: t('admin.requests'), icon: '📋' },
    { key: 'payouts', label: isRTL ? 'طلبات السحب' : 'Payouts', icon: '🏧' },
    { key: 'earnings', label: t('admin.earnings'), icon: '💰' },
    { key: 'reports', label: t('admin.reports'), icon: '📈' },
    { key: 'changeRequests', label: t('admin.changeRequests'), icon: '🔄' },
    { key: 'documents', label: t('admin.documents'), icon: '📄' },
    { key: 'refunds', label: t('admin.refunds'), icon: '💵' },
    { key: 'interventions', label: t('admin.interventions'), icon: '🛠️' },
  ]

  const statusColor = (status: string) => {
    switch (status) {
      case 'paid': return 'bg-green-100 text-green-800'
      case 'completed': return 'bg-blue-100 text-blue-800'
      case 'in_progress': return 'bg-indigo-100 text-indigo-800'
      case 'accepted': return 'bg-purple-100 text-purple-800'
      case 'pending': return 'bg-yellow-100 text-yellow-800'
      case 'cancelled': return 'bg-red-100 text-red-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const paymentBadge = (r: any) => {
    if (r.paymentStatus === 'paid') {
      return <span className="px-3 py-1.5 rounded-full text-xs font-bold bg-green-100 text-green-800">{isRTL ? 'مدفوع بالكامل' : 'Fully Paid'}</span>
    }
    if (r.visitFeePaid) {
      return <span className="px-3 py-1.5 rounded-full text-xs font-bold bg-yellow-100 text-yellow-800">{isRTL ? 'دفعة الزيارة فقط' : 'Visit Fee Only'}</span>
    }
    return <span className="px-3 py-1.5 rounded-full text-xs font-bold bg-red-100 text-red-800">{isRTL ? 'غير مدفوع' : 'Unpaid'}</span>
  }

  return (
    <div dir={isRTL ? 'rtl' : 'ltr'} className="min-h-screen flex bg-gray-100">
      {/* القائمة الجانبية */}
      <aside className="w-64 bg-gray-900 text-white p-4 flex flex-col shadow-xl">
        <div className="flex justify-between items-center mb-8 pb-4 border-b border-gray-700">
          <h2 className="text-xl font-bold text-white">{t('admin.dashboard')}</h2>
          <button 
            onClick={() => changeLanguage(language === 'ar' ? 'en' : 'ar')} 
            className="text-xs bg-blue-600 hover:bg-blue-700 px-3 py-1.5 rounded-lg font-bold transition"
          >
            {language === 'ar' ? 'EN' : 'ع'}
          </button>
        </div>
        
        <nav className="space-y-2 flex-1 overflow-y-auto">
          {menuItems.map(item => (
            <button 
              key={item.key} 
              onClick={() => setTab(item.key)}
              className={`w-full text-right px-4 py-3 rounded-lg text-sm font-bold transition-all duration-200 flex items-center gap-2 ${
                tab === item.key 
                  ? 'bg-blue-600 text-white shadow-lg' 
                  : 'text-white hover:bg-gray-800'
              }`}
            >
              <span>{item.icon}</span>
              <span>{item.label}</span>
              {item.key === 'payouts' && payouts.filter((p: any) => p.status === 'pending').length > 0 && (
                <span className="mr-auto bg-red-500 text-white text-xs rounded-full px-2 py-0.5">
                  {payouts.filter((p: any) => p.status === 'pending').length}
                </span>
              )}
            </button>
          ))}
        </nav>
        
        <button 
          onClick={handleLogout} 
          className="mt-6 text-sm text-red-400 hover:text-red-300 hover:underline text-right font-bold transition"
        >
          {t('common.logout')}
        </button>
      </aside>

      {/* المحتوى الرئيسي */}
      <main className="flex-1 p-8 overflow-y-auto">
        <div className="max-w-7xl mx-auto">
          <h1 className="text-3xl font-bold text-gray-900 mb-8">
            {t('common.welcome')}, {admin.name}
          </h1>
          
          {msg && (
            <div className={`p-4 rounded-lg mb-6 font-bold ${
              msg.includes('✅') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
            }`}>
              {msg}
            </div>
          )}

          {/* نظرة عامة */}
          {tab === 'overview' && stats && (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <div className="bg-white rounded-xl shadow-lg p-6 border border-gray-200">
                <p className="text-gray-600 text-sm font-bold mb-2">{t('admin.stats.users')}</p>
                <p className="text-3xl font-bold text-gray-900">{stats.users}</p>
              </div>
              <div className="bg-white rounded-xl shadow-lg p-6 border border-gray-200">
                <p className="text-gray-600 text-sm font-bold mb-2">{t('admin.stats.requests')}</p>
                <p className="text-3xl font-bold text-gray-900">{stats.requests}</p>
              </div>
              <div className="bg-white rounded-xl shadow-lg p-6 border border-gray-200">
                <p className="text-gray-600 text-sm font-bold mb-2">{t('admin.stats.revenue')}</p>
                <p className="text-3xl font-bold text-green-600">{stats.revenue} {isRTL ? 'د.ك' : 'KWD'}</p>
              </div>
              <div className="bg-white rounded-xl shadow-lg p-6 border border-gray-200">
                <p className="text-gray-600 text-sm font-bold mb-2">{t('admin.stats.pendingCraftsmen')}</p>
                <p className="text-3xl font-bold text-red-600">{stats.pendingCraftsmen}</p>
              </div>
            </div>
          )}

          {/* المستخدمون */}
          {tab === 'users' && (
            <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
              <div className="p-6 border-b border-gray-200 bg-gray-50">
                <h2 className="text-2xl font-bold text-gray-900">{t('admin.users')}</h2>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-100">
                    <tr>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('auth.name')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('auth.email')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('auth.role')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('common.status')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('common.actions')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {users.length === 0 ? (
                      <tr><td colSpan={5} className="p-8 text-center text-gray-500 font-bold">{t('common.noData')}</td></tr>
                    ) : (
                      users.map((u: any) => (
                        <tr key={u.id} className="border-b border-gray-100 hover:bg-gray-50">
                          <td className="p-4 text-gray-900 font-medium">{u.name}</td>
                          <td className="p-4 text-gray-700">{u.email}</td>
                          <td className="p-4 text-gray-700">{t(`roles.${u.role}`) || u.role}</td>
                          <td className="p-4">
                            <span className={`px-3 py-1.5 rounded-full text-xs font-bold ${
                              u.verification_status === 'approved' ? 'bg-green-100 text-green-800' :
                              u.verification_status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                              u.verification_status === 'banned' ? 'bg-red-100 text-red-800' :
                              'bg-gray-100 text-gray-800'
                            }`}>
                              {u.verification_status === 'banned' ? (isRTL ? 'موقوف' : 'Banned') : (u.verification_status || t('status.pending'))}
                            </span>
                          </td>
                          <td className="p-4 flex gap-2 flex-wrap">
                            {u.role === 'craftsman' && u.verification_status !== 'approved' && u.verification_status !== 'banned' && (
                              <button 
                                onClick={() => updateUserStatus(u.id, 'verification_status', 'approved')} 
                                className="text-xs font-bold bg-green-600 hover:bg-green-700 text-white px-3 py-2 rounded-lg transition"
                              >
                                {t('admin.table.approve')}
                              </button>
                            )}
                            {u.role !== 'admin' && u.verification_status !== 'banned' && (
                              <button 
                                onClick={() => { if (confirm(isRTL ? 'هل أنت متأكد من إيقاف هذا الحساب؟' : 'Are you sure you want to ban this account?')) updateUserStatus(u.id, 'verification_status', 'banned') }} 
                                className="text-xs font-bold bg-red-600 hover:bg-red-700 text-white px-3 py-2 rounded-lg transition"
                              >
                                {isRTL ? 'إيقاف الحساب' : 'Ban Account'}
                              </button>
                            )}
                            {u.verification_status === 'banned' && (
                              <button 
                                onClick={() => updateUserStatus(u.id, 'verification_status', 'approved')} 
                                className="text-xs font-bold bg-gray-600 hover:bg-gray-700 text-white px-3 py-2 rounded-lg transition"
                              >
                                {isRTL ? 'إعادة التفعيل' : 'Reactivate'}
                              </button>
                            )}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* الطلبات */}
          {tab === 'requests' && (
            <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
              <div className="p-6 border-b border-gray-200 bg-gray-50 flex justify-between items-center">
                <h2 className="text-2xl font-bold text-gray-900">{t('admin.requests')}</h2>
                <span className="text-xs text-gray-500 font-bold">{isRTL ? 'يتحدث تلقائياً كل 30 ثانية' : 'Auto-refreshes every 30s'}</span>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-100">
                    <tr>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.service')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.client')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.craftsman')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('common.status')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{isRTL ? 'حالة الدفع' : 'Payment'}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('common.actions')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {requests.length === 0 ? (
                      <tr><td colSpan={6} className="p-8 text-center text-gray-500 font-bold">{t('common.noData')}</td></tr>
                    ) : (
                      requests.map((r: any) => (
                        <tr key={r.id} className="border-b border-gray-100 hover:bg-gray-50">
                          <td className="p-4 text-gray-900 font-medium">{r.serviceType || r.category?.name || '—'}</td>
                          <td className="p-4 text-gray-700">{r.client?.name || '—'}</td>
                          <td className="p-4 text-gray-700">{r.craftsman?.name || '—'}</td>
                          <td className="p-4">
                            <span className={`px-3 py-1.5 rounded-full text-xs font-bold ${statusColor(r.status)}`}>
                              {t(`status.${r.status}`) || r.status}
                            </span>
                          </td>
                          <td className="p-4">{paymentBadge(r)}</td>
                          <td className="p-4 flex gap-2 flex-wrap">
                            {!r.craftsman && (
                              <button 
                                onClick={() => { setAssignModal(r); setSelectedCraftsman('') }} 
                                className="text-xs font-bold bg-purple-600 hover:bg-purple-700 text-white px-3 py-2 rounded-lg transition"
                              >
                                {t('admin.table.manualAssign')}
                              </button>
                            )}
                            {r.craftsman && (r.status === 'pending' || r.status === 'accepted') && (
                              <button 
                                onClick={() => { setReassignModal(r); setSelectedCraftsman('') }} 
                                className="text-xs font-bold bg-orange-600 hover:bg-orange-700 text-white px-3 py-2 rounded-lg transition"
                              >
                                {t('admin.table.reassign')}
                              </button>
                            )}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* طلبات السحب (Payouts) */}
          {tab === 'payouts' && (
            <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
              <div className="p-6 border-b border-gray-200 bg-gray-50">
                <h2 className="text-2xl font-bold text-gray-900">{isRTL ? 'طلبات سحب الأرباح' : 'Payout Requests'}</h2>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-100">
                    <tr>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.craftsman')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.phone')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{isRTL ? 'المبلغ' : 'Amount'}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('common.status')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('common.actions')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {payouts.length === 0 ? (
                      <tr><td colSpan={5} className="p-8 text-center text-gray-500 font-bold">{t('common.noData')}</td></tr>
                    ) : (
                      payouts.map((p: any) => (
                        <tr key={p.id} className="border-b border-gray-100 hover:bg-gray-50">
                          <td className="p-4 text-gray-900 font-medium">{p.craftsman?.name || '—'}</td>
                          <td className="p-4 text-gray-700">{p.craftsman?.phone || '—'}</td>
                          <td className="p-4 text-green-700 font-bold">{p.amount} {isRTL ? 'د.ك' : 'KWD'}</td>
                          <td className="p-4">
                            <span className={`px-3 py-1.5 rounded-full text-xs font-bold ${
                              p.status === 'approved' || p.status === 'completed' ? 'bg-green-100 text-green-800' :
                              p.status === 'rejected' ? 'bg-red-100 text-red-800' :
                              'bg-yellow-100 text-yellow-800'
                            }`}>
                              {p.status}
                            </span>
                          </td>
                          <td className="p-4 flex gap-2">
                            {p.status === 'pending' && (
                              <>
                                <button onClick={() => updatePayout(p.id, 'approved')} className="text-xs font-bold bg-green-600 hover:bg-green-700 text-white px-3 py-2 rounded-lg transition">
                                  {t('admin.table.approve')}
                                </button>
                                <button onClick={() => updatePayout(p.id, 'rejected')} className="text-xs font-bold bg-red-600 hover:bg-red-700 text-white px-3 py-2 rounded-lg transition">
                                  {t('admin.table.reject')}
                                </button>
                              </>
                            )}
                            {p.status === 'approved' && (
                              <button onClick={() => updatePayout(p.id, 'completed')} className="text-xs font-bold bg-blue-600 hover:bg-blue-700 text-white px-3 py-2 rounded-lg transition">
                                {isRTL ? 'تأكيد التحويل' : 'Mark Transferred'}
                              </button>
                            )}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* الأرباح */}
          {tab === 'earnings' && (
            <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
              <div className="p-6 border-b border-gray-200 bg-gray-50 flex justify-between items-center">
                <h2 className="text-2xl font-bold text-gray-900">{t('admin.earnings')}</h2>
              </div>
              <div className="p-6">
                {financials ? (
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                    <div className="bg-emerald-50 rounded-lg p-4 border border-emerald-200">
                      <p className="text-emerald-700 text-sm font-bold">إجمالي أرباح المنصة (10%)</p>
                      <p className="text-2xl font-bold text-emerald-900 mt-2">
                        {financials.totalPlatformFee.toFixed(3)} د.ك
                      </p>
                    </div>
                    <div className="bg-blue-50 rounded-lg p-4 border border-blue-200">
                      <p className="text-blue-700 text-sm font-bold">إجمالي مستحقات الحرفيين (90%)</p>
                      <p className="text-2xl font-bold text-blue-900 mt-2">
                        {financials.totalCraftsmanEarnings.toFixed(3)} د.ك
                      </p>
                    </div>
                    <div className="bg-amber-50 rounded-lg p-4 border border-amber-200">
                      <p className="text-amber-700 text-sm font-bold">طلبات السحب المعلقة</p>
                      <p className="text-2xl font-bold text-amber-900 mt-2">
                        {financials.totalPendingPayouts.toFixed(3)} د.ك
                      </p>
                    </div>
                  </div>
                ) : (
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                    <div className="bg-green-50 rounded-lg p-4 border border-green-200">
                      <p className="text-green-700 text-sm font-bold">{isRTL ? 'إجمالي الأرباح' : 'Total Earnings'}</p>
                      <p className="text-2xl font-bold text-green-900 mt-2">
                        {earnings.reduce((sum: number, e: any) => sum + (parseFloat(e.amount) || 0), 0).toFixed(2)} {isRTL ? 'د.ك' : 'KWD'}
                      </p>
                    </div>
                    <div className="bg-blue-50 rounded-lg p-4 border border-blue-200">
                      <p className="text-blue-700 text-sm font-bold">{isRTL ? 'عدد العمليات' : 'Total Transactions'}</p>
                      <p className="text-2xl font-bold text-blue-900 mt-2">{earnings.length}</p>
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* تقارير ذكية */}
          {tab === 'reports' && (
            <div className="bg-white rounded-xl shadow-lg p-8 border border-gray-200 text-center">
              <p className="text-gray-600 font-bold text-lg">{t('admin.reports')} - {isRTL ? 'قيد التطوير' : 'Coming Soon'}</p>
            </div>
          )}

          {/* طلبات تغيير الحرفة */}
          {tab === 'changeRequests' && (
            <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
              <div className="p-6 border-b border-gray-200 bg-gray-50">
                <h2 className="text-2xl font-bold text-gray-900">{t('admin.changeRequests')}</h2>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-100">
                    <tr>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.craftsman')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.phone')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.currentProfession')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.newProfession')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.reason')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('common.actions')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {changeRequests.length === 0 ? (
                      <tr><td colSpan={6} className="p-8 text-center text-gray-500 font-bold">{t('common.noData')}</td></tr>
                    ) : (
                      changeRequests.map((req: any) => (
                        <tr key={req.id} className="border-b border-gray-100 hover:bg-gray-50">
                          <td className="p-4 text-gray-900 font-medium">{req.craftsman_name}</td>
                          <td className="p-4 text-gray-700">{req.phone}</td>
                          <td className="p-4 text-gray-700">{req.old_category_name || '—'}</td>
                          <td className="p-4 text-gray-700">{req.new_category_name}</td>
                          <td className="p-4 text-gray-700 max-w-xs truncate">{req.reason}</td>
                          <td className="p-4 flex gap-2">
                            <button onClick={() => handleChangeRequest(req.id, 'approve')} className="text-xs font-bold bg-green-600 hover:bg-green-700 text-white px-3 py-2 rounded-lg transition">
                              {t('admin.table.approve')}
                            </button>
                            <button onClick={() => handleChangeRequest(req.id, 'reject')} className="text-xs font-bold bg-red-600 hover:bg-red-700 text-white px-3 py-2 rounded-lg transition">
                              {t('admin.table.reject')}
                            </button>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* اعتماد المستندات */}
          {tab === 'documents' && (
            <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
              <div className="p-6 border-b border-gray-200 bg-gray-50">
                <h2 className="text-2xl font-bold text-gray-900">{t('admin.documents')}</h2>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-100">
                    <tr>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.craftsman')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.phone')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.civilId')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.bankAccount')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('common.actions')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {pendingDocs.length === 0 ? (
                      <tr><td colSpan={5} className="p-8 text-center text-gray-500 font-bold">{t('common.noData')}</td></tr>
                    ) : (
                      pendingDocs.map((doc: any) => (
                        <tr key={doc.id} className="border-b border-gray-100 hover:bg-gray-50">
                          <td className="p-4 text-gray-900 font-medium">{doc.craftsman?.name}</td>
                          <td className="p-4 text-gray-700">{doc.craftsman?.phone}</td>
                          <td className="p-4 text-gray-700">
                            {doc.civilIdUrl ? <a href={doc.civilIdUrl} target="_blank" className="text-blue-600 hover:underline font-bold">{isRTL ? 'عرض' : 'View'}</a> : '—'}
                          </td>
                          <td className="p-4 text-gray-700">
                            {doc.bankAccountPhotoUrl ? <a href={doc.bankAccountPhotoUrl} target="_blank" className="text-blue-600 hover:underline font-bold">{isRTL ? 'عرض' : 'View'}</a> : '—'}
                          </td>
                          <td className="p-4 flex gap-2">
                            <button onClick={() => handleDocumentAction(doc.id, 'approve')} className="text-xs font-bold bg-green-600 hover:bg-green-700 text-white px-3 py-2 rounded-lg transition">
                              {t('admin.table.approve')}
                            </button>
                            <button onClick={() => handleDocumentAction(doc.id, 'reject')} className="text-xs font-bold bg-red-600 hover:bg-red-700 text-white px-3 py-2 rounded-lg transition">
                              {t('admin.table.reject')}
                            </button>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* طلبات الاسترداد */}
          {tab === 'refunds' && (
            <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
              <div className="p-6 border-b border-gray-200 bg-gray-50">
                <h2 className="text-2xl font-bold text-gray-900">{t('admin.refunds')}</h2>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-100">
                    <tr>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.client')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.service')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.amount')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.reason')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('common.actions')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {pendingRefunds.length === 0 ? (
                      <tr><td colSpan={5} className="p-8 text-center text-gray-500 font-bold">{t('common.noData')}</td></tr>
                    ) : (
                      pendingRefunds.map((ref: any) => (
                        <tr key={ref.id} className="border-b border-gray-100 hover:bg-gray-50">
                          <td className="p-4 text-gray-900 font-medium">{ref.client_name}</td>
                          <td className="p-4 text-gray-700">{ref.service_type || ref.request_id}</td>
                          <td className="p-4 text-red-600 font-bold">{ref.amount} {isRTL ? 'د.ك' : 'KWD'}</td>
                          <td className="p-4 text-gray-700 max-w-xs truncate">{ref.reason || '—'}</td>
                          <td className="p-4 flex gap-2">
                            <button onClick={() => handleRefundAction(ref.id, 'approve')} className="text-xs font-bold bg-green-600 hover:bg-green-700 text-white px-3 py-2 rounded-lg transition">
                              {t('admin.table.approve')}
                            </button>
                            <button onClick={() => handleRefundAction(ref.id, 'reject')} className="text-xs font-bold bg-red-600 hover:bg-red-700 text-white px-3 py-2 rounded-lg transition">
                              {t('admin.table.reject')}
                            </button>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* تدخلات الأدمن */}
          {tab === 'interventions' && (
            <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
              <div className="p-6 border-b border-gray-200 bg-gray-50">
                <h2 className="text-2xl font-bold text-gray-900">{t('admin.interventions')}</h2>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-100">
                    <tr>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.client')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.service')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('admin.table.reason')}</th>
                      <th className="p-4 text-right font-bold text-gray-900 border-b">{t('common.actions')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {interventionRequests.length === 0 ? (
                      <tr><td colSpan={4} className="p-8 text-center text-gray-500 font-bold">{t('common.noData')}</td></tr>
                    ) : (
                      interventionRequests.map((req: any) => (
                        <tr key={req.id} className="border-b border-gray-100 hover:bg-gray-50">
                          <td className="p-4 text-gray-900 font-medium">{req.client_name}</td>
                          <td className="p-4 text-gray-700">{req.service_type}</td>
                          <td className="p-4 text-gray-700">{req.intervention_reason || (isRTL ? 'رفض العميل كل العروض' : 'Client rejected all offers')}</td>
                          <td className="p-4">
                            <button 
                              onClick={() => { setAssignModal(req); setSelectedCraftsman('') }} 
                              className="text-xs font-bold bg-purple-600 hover:bg-purple-700 text-white px-3 py-2 rounded-lg transition"
                            >
                              {t('admin.table.manualAssign')}
                            </button>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      </main>

      {/* Modal الإسناد اليدوي */}
      {assignModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full mx-4">
            <h3 className="text-xl font-bold text-gray-900 mb-4">{t('admin.table.manualAssign')}</h3>
            <p className="text-sm text-gray-600 mb-4">{t('admin.table.service')}: {assignModal.serviceType || assignModal.service_type || t('admin.table.service')}</p>
            <select 
              value={selectedCraftsman} 
              onChange={e => setSelectedCraftsman(e.target.value)} 
              className="w-full border border-gray-300 rounded-lg px-4 py-3 mb-4 font-bold focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="">{isRTL ? 'اختر حرفي' : 'Select Craftsman'}</option>
              {craftsmen.map((c: any) => (
                <option key={c.id} value={c.id}>{c.name} - {c.phone}</option>
              ))}
            </select>
            <div className="flex gap-3">
              <button 
                onClick={assignRequest} 
                disabled={!selectedCraftsman} 
                className="flex-1 bg-purple-600 hover:bg-purple-700 disabled:bg-gray-300 disabled:cursor-not-allowed text-white py-3 rounded-lg font-bold transition"
              >
                {t('common.confirm')}
              </button>
              <button 
                onClick={() => setAssignModal(null)} 
                className="px-6 py-3 bg-gray-100 hover:bg-gray-200 rounded-lg font-bold text-gray-700 transition"
              >
                {t('common.cancel')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal إعادة الإسناد */}
      {reassignModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full mx-4">
            <h3 className="text-xl font-bold text-gray-900 mb-4">{t('admin.table.reassign')}</h3>
            <p className="text-sm text-gray-600 mb-4">
              {t('admin.table.service')}: {reassignModal.serviceType || reassignModal.service_type || t('admin.table.service')}
            </p>
            <select 
              value={selectedCraftsman} 
              onChange={e => setSelectedCraftsman(e.target.value)} 
              className="w-full border border-gray-300 rounded-lg px-4 py-3 mb-4 font-bold focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="">{isRTL ? 'اختر حرفي جديد' : 'Select New Craftsman'}</option>
              {craftsmen.filter(c => c.id !== reassignModal.craftsmanId).map((c: any) => (
                <option key={c.id} value={c.id}>{c.name} - {c.phone}</option>
              ))}
            </select>
            <div className="flex gap-3">
              <button 
                onClick={reassignRequest} 
                disabled={!selectedCraftsman} 
                className="flex-1 bg-orange-600 hover:bg-orange-700 disabled:bg-gray-300 disabled:cursor-not-allowed text-white py-3 rounded-lg font-bold transition"
              >
                {t('common.confirm')}
              </button>
              <button 
                onClick={() => setReassignModal(null)} 
                className="px-6 py-3 bg-gray-100 hover:bg-gray-200 rounded-lg font-bold text-gray-700 transition"
              >
                {t('common.cancel')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
