'use client'

import { useState, useEffect, Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import Link from 'next/link'

function BusinessListContent() {
  const searchParams = useSearchParams()
  const categoryId = searchParams.get('category') || ''
  const [businesses, setBusinesses] = useState<any[]>([])

  useEffect(() => {
    const params = new URLSearchParams()
    if (categoryId) params.set('categoryId', categoryId)
    fetch(`/api/business?${params.toString()}`)
      .then(r => r.json())
      .then(data => setBusinesses(data.businesses || data.data || []))
  }, [categoryId])

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-6xl mx-auto">
        <h1 className="text-2xl font-bold mb-6">المحلات والشركات</h1>
        <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-4">
          {businesses.length === 0 ? (
            <p className="text-gray-700">لا توجد محلات في هذا القسم.</p>
          ) : (
            businesses.map((b: any) => (
              <Link
                key={b.id}
                href={`/store/${b.id}`}
                className="bg-white rounded-xl border p-4 hover:shadow-lg transition"
              >
                <h3 className="font-bold">{b.name}</h3>
                <p className="text-sm text-gray-700">{b.category?.name}</p>
                <span className="text-yellow-500">⭐ {b.rating || 'جديد'}</span>
              </Link>
            ))
          )}
        </div>
      </div>
    </div>
  )
}

export default function BusinessListPage() {
  return (
    <Suspense fallback={<div style={{padding: 20}}>جارٍ التحميل...</div>}>
      <BusinessListContent />
    </Suspense>
  )
}
