'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'

export default function CraftsmanDashboard() {
  const [data, setData] = useState({
    revenue: 0,
    activeRequests: 0,
    totalServices: 0,
    rating: 0,
  })

  useEffect(() => {
    fetch('/api/dashboard')
      .then(res => res.json())
      .then(apiData => {
        setData({
          revenue: apiData.revenue || 0,
          activeRequests: apiData.activeRequests || 0,
          totalServices: apiData.totalServices || 0,
          rating: apiData.rating || 0,
        })
      })
      .catch(() => {})
  }, [])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">لوحة تحكم الحرفي</h1>
        <p className="text-gray-500 text-sm">ملخص نشاطك وطلباتك</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-white rounded-xl border p-4 text-center">
          <div className="text-2xl mb-1">💰</div>
          <p className="text-2xl font-bold text-green-600">{data.revenue} د.ك</p>
          <p className="text-xs text-gray-500">إجمالي الأرباح</p>
        </div>
        <div className="bg-white rounded-xl border p-4 text-center">
          <div className="text-2xl mb-1">📋</div>
          <p className="text-2xl font-bold text-blue-600">{data.activeRequests}</p>
          <p className="text-xs text-gray-500">طلبات نشطة</p>
        </div>
        <div className="bg-white rounded-xl border p-4 text-center">
          <div className="text-2xl mb-1">🔧</div>
          <p className="text-2xl font-bold text-purple-600">{data.totalServices}</p>
          <p className="text-xs text-gray-500">خدماتي</p>
        </div>
        <div className="bg-white rounded-xl border p-4 text-center">
          <div className="text-2xl mb-1">⭐</div>
          <p className="text-2xl font-bold text-yellow-600">{data.rating || 'جديد'}</p>
          <p className="text-xs text-gray-500">تقييمي</p>
        </div>
      </div>

      <div className="bg-white rounded-xl border p-6">
        <h3 className="text-lg font-bold mb-4">إجراءات سريعة</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <Link href="/craftsman/my-services"
            className="flex flex-col items-center justify-center h-20 border rounded-lg hover:bg-gray-50 transition">
            <span className="text-xl">➕</span>
            <span className="text-xs">إضافة خدمة</span>
          </Link>
          <Link href="/craftsman/requests"
            className="flex flex-col items-center justify-center h-20 border rounded-lg hover:bg-gray-50 transition">
            <span className="text-xl">📋</span>
            <span className="text-xs">الطلبات</span>
          </Link>
          <Link href="/craftsman/earnings"
            className="flex flex-col items-center justify-center h-20 border rounded-lg hover:bg-gray-50 transition">
            <span className="text-xl">💰</span>
            <span className="text-xs">أرباحي</span>
          </Link>
          <Link href="/craftsman/profile"
            className="flex flex-col items-center justify-center h-20 border rounded-lg hover:bg-gray-50 transition">
            <span className="text-xl">👤</span>
            <span className="text-xs">حسابي</span>
          </Link>
        </div>
      </div>
    </div>
  )
}
