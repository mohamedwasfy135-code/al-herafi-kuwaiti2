'use client'

import { useState, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Link from 'next/link'

export default function ShopsContent() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const categoryParam = searchParams.get('category') || ''
  const [businesses, setBusinesses] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let url = '/api/business?limit=20'
    if (categoryParam) url += `&category=${encodeURIComponent(categoryParam)}`
    fetch(url)
      .then(r => r.json())
      .then(data => setBusinesses(data.businesses || data.data || []))
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [categoryParam])

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-6xl mx-auto">
        <div className="flex items-center gap-4 mb-6">
          <button onClick={() => router.push('/')} className="text-blue-600 hover:underline text-sm">← الرئيسية</button>
          <h1 className="text-2xl font-bold">
            {categoryParam ? `محلات ${categoryParam}` : 'جميع المحلات والشركات'}
          </h1>
        </div>

        {loading ? (
          <p>جارٍ التحميل...</p>
        ) : businesses.length === 0 ? (
          <div className="bg-white rounded-xl p-6 text-center text-gray-700">
            <p className="text-lg">لا توجد محلات في هذا القسم حالياً</p>
          </div>
        ) : (
          <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-4">
            {businesses.map((biz: any) => (
              <Link
                key={biz.id}
                href={`/store/${biz.id}`}
                className="bg-white rounded-xl border p-4 hover:shadow-lg transition"
              >
                <div className="flex items-center gap-3">
                  <div className="w-14 h-14 bg-blue-100 rounded-lg flex items-center justify-center text-2xl">
                    {biz.businessType === 'company' ? '🏢' : '🏪'}
                  </div>
                  <div className="flex-1">
                    <h3 className="font-semibold">{biz.name}</h3>
                    <p className="text-sm text-gray-700">{biz.category?.name || biz.category || ''}</p>
                    <span className="text-sm text-yellow-500">⭐ {biz.rating || 'جديد'}</span>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
