'use client'

import { useParams } from 'next/navigation'
import { useState, useEffect } from 'react'

export default function ServiceDetailPage() {
  const params = useParams()
  const serviceId = params.id
  const [service, setService] = useState<any>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch(`/api/services/${serviceId}`)
      .then(r => r.json())
      .then(data => setService(data.service || data))
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [serviceId])

  // ✅ استخدام window.location.href مباشرة لضمان التنقل
  const handleRequestService = () => {
    const stored = localStorage.getItem('sana3i_user')
    if (!stored) {
      sessionStorage.setItem('redirectAfterLogin', window.location.pathname)
      window.location.href = `/login?redirect=${encodeURIComponent(window.location.pathname)}`
    } else {
      window.location.href = `/create-request?serviceId=${serviceId}`
    }
  }

  if (loading) return <div className="p-8 text-center">جارٍ تحميل الخدمة...</div>
  if (!service) return <div className="p-8 text-center">الخدمة غير موجودة</div>

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-2xl mx-auto bg-white rounded-2xl shadow p-6">
        <h1 className="text-2xl font-bold mb-4">{service.title}</h1>
        {service.description && <p className="text-gray-600 mb-4">{service.description}</p>}
        <div className="flex items-center justify-between mb-6">
          <span className="text-2xl font-bold text-blue-600">{service.price} د.ك</span>
          <span className="text-sm text-gray-700">مقدم من: {service.craftsman?.name || 'حرفي'}</span>
        </div>
        <button onClick={handleRequestService} className="w-full bg-green-600 text-white py-3 rounded-lg hover:bg-green-700 transition font-bold">اطلب الخدمة</button>
        <button onClick={() => window.location.href = '/services'} className="w-full mt-3 bg-gray-100 text-gray-700 py-3 rounded-lg hover:bg-gray-200 transition">العودة للخدمات</button>
      </div>
    </div>
  )
}
