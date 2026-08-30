'use client'

import { useState, useEffect } from 'react'

export default function RequestsTab({ userId }: { userId: string }) {
  const [requests, setRequests] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch(`/api/requests?clientId=${userId}`)
      .then(r => r.json())
      .then(data => setRequests(data.requests || data.data || []))
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [userId])

  if (loading) return <div className="p-4 text-center">جارٍ تحميل طلباتك...</div>

  if (requests.length === 0) {
    return (
      <div className="bg-white rounded-xl p-6 text-center text-gray-700">
        <h2 className="text-lg font-bold mb-2">طلباتي</h2>
        <p>لا توجد طلبات بعد. تصفح الخدمات واطلب ما يناسبك.</p>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <h2 className="text-lg font-bold">طلباتي</h2>
      {requests.map((req: any) => (
        <div key={req.id} className="bg-white rounded-xl border p-4 shadow-sm">
          <div className="flex justify-between items-start">
            <div>
              <h3 className="font-semibold">{req.service_type || req.title}</h3>
              {req.details && <p className="text-sm text-gray-700 mt-1">{req.details}</p>}
              <p className="text-xs text-gray-600 mt-2">
                {req.status === 'pending' ? '⏳ قيد الانتظار' : req.status}
              </p>
            </div>
            <span className="text-blue-600 font-bold">{req.price} د.ك</span>
          </div>
        </div>
      ))}
    </div>
  )
}
