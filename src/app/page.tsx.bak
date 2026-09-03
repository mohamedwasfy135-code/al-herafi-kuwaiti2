'use client'
import { useState, useEffect } from 'react'
import Link from 'next/link'

export default function HomePage() {
  const [serviceCategories, setServiceCategories] = useState<any[]>([])
  const [businessCategories, setBusinessCategories] = useState<any[]>([])

  useEffect(() => {
    fetch('/api/categories?type=service')
      .then(r => r.json())
      .then(d => setServiceCategories(d.categories || []))
      .catch(() => {})
    
    fetch('/api/categories?type=business')
      .then(r => r.json())
      .then(d => setBusinessCategories(d.categories || []))
      .catch(() => {})
  }, [])

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm sticky top-0 z-50">
        <div className="max-w-6xl mx-auto px-4 py-4 flex justify-between items-center">
          <h1 className="text-2xl font-bold text-gray-900">الحرفي الكويتي</h1>
          <div className="flex gap-4">
            <Link href="/login" className="text-blue-600 font-semibold hover:underline">
              تسجيل الدخول
            </Link>
            <Link href="/register" className="bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700">
              إنشاء حساب
            </Link>
          </div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 py-12">
        {/* Hero Section */}
        <div className="text-center mb-16">
          <h2 className="text-4xl font-bold text-gray-900 mb-4">
            منصة الحرفي الكويتي
          </h2>
          <p className="text-xl text-gray-600 mb-8">
            اطلب خدمات الحرفيين أو تسوق من المحلات بسهولة
          </p>
        </div>

        {/* Services Section */}
        <section className="mb-16">
          <h2 className="text-3xl font-bold text-gray-900 mb-8 border-r-4 border-blue-600 pr-4">
            خدمات الحرفيين
          </h2>
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-6">
            {serviceCategories.length === 0 ? (
              <p className="text-gray-500 col-span-full text-center py-8">جاري تحميل الخدمات...</p>
            ) : (
              serviceCategories.map((cat: any) => (
                <Link 
                  key={cat.id} 
                  href={`/create-request?categoryId=${cat.id}&type=service`}
                  className="bg-white p-6 rounded-xl shadow-sm hover:shadow-lg hover:-translate-y-1 transition-all duration-300 text-center border border-gray-100 group"
                >
                  <div className="text-5xl mb-3 group-hover:scale-110 transition-transform">
                    {cat.icon || ''}
                  </div>
                  <h3 className="font-bold text-gray-800">{cat.name}</h3>
                </Link>
              ))
            )}
          </div>
        </section>

        {/* Shops Section */}
        <section>
          <h2 className="text-3xl font-bold text-gray-900 mb-8 border-r-4 border-green-600 pr-4">
            المحلات
          </h2>
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-6">
            {businessCategories.length === 0 ? (
              <p className="text-gray-500 col-span-full text-center py-8">جاري تحميل المحلات...</p>
            ) : (
              businessCategories.map((cat: any) => (
                <Link 
                  key={cat.id} 
                  href={`/shops?category=${cat.id}`}
                  className="bg-white p-6 rounded-xl shadow-sm hover:shadow-lg hover:-translate-y-1 transition-all duration-300 text-center border border-gray-100 group"
                >
                  <div className="text-5xl mb-3 group-hover:scale-110 transition-transform">
                    {cat.icon || '🏪'}
                  </div>
                  <h3 className="font-bold text-gray-800">{cat.name}</h3>
                </Link>
              ))
            )}
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer className="bg-gray-900 text-white py-8 mt-16">
        <div className="max-w-6xl mx-auto px-4 text-center">
          <p className="text-gray-400">© 2026 الحرفي الكويتي - جميع الحقوق محفوظة</p>
        </div>
      </footer>
    </div>
  )
}
