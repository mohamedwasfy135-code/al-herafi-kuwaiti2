'use client'
import { useState, useEffect } from 'react'
import Link from 'next/link'
import * as LucideIcons from 'lucide-react'

// دالة تحويل النص إلى أيقونة حقيقية
const ServiceIcon = ({ name }: { name?: string }) => {
  if (!name) return <span className="text-4xl">🛠️</span>
  // إذا كان إيموجي اعرضه مباشرة
  if (/[^\x00-\x7F]/.test(name)) return <span className="text-4xl">{name}</span>
  
  // تحويل الاسم إلى مكون Lucide (مثال: snowflake -> Snowflake)
  const formattedName = name.charAt(0).toUpperCase() + name.slice(1)
  const IconComponent = (LucideIcons as any)[formattedName]
  
  if (IconComponent) {
    return <IconComponent className="w-12 h-12 text-blue-600" strokeWidth={1.5} />
  }
  return <span className="text-4xl"></span>
}

export default function HomePage() {
  const [serviceCategories, setServiceCategories] = useState<any[]>([])
  const [businessCategories, setBusinessCategories] = useState<any[]>([])

  useEffect(() => {
    fetch('/api/categories?type=service').then(r => r.json()).then(d => setServiceCategories(d.categories || [])).catch(() => {})
    fetch('/api/categories?type=business').then(r => r.json()).then(d => setBusinessCategories(d.categories || [])).catch(() => {})
  }, [])

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 font-sans">
      {/* Header */}
      <header className="bg-white shadow-sm sticky top-0 z-50 border-b border-gray-100">
        <div className="max-w-7xl mx-auto px-4 py-4 flex justify-between items-center">
          <h1 className="text-xl font-bold text-gray-900">الحرفي الكويتي</h1>
          <div className="flex gap-3">
            <Link href="/login" className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-blue-600 transition-colors">تسجيل الدخول</Link>
            <Link href="/register" className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors shadow-sm">إنشاء حساب</Link>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-8">
        {/* Hero */}
        <div className="text-center mb-12 py-8">
          <h2 className="text-3xl font-bold text-gray-900 mb-3">منصة الحرفي الكويتي</h2>
          <p className="text-lg text-gray-600">اطلب خدمات الحرفيين أو تسوق من المحلات بسهولة وأمان</p>
        </div>

        {/* Services Grid - التنسيق الجديد */}
        <section className="mb-16">
          <div className="flex items-center gap-3 mb-8">
            <h2 className="text-2xl font-bold text-gray-900">خدمات الحرفيين</h2>
            <div className="h-8 w-1 bg-blue-600 rounded-full"></div>
          </div>
          
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
            {serviceCategories.length === 0 ? (
              <div className="col-span-full text-center py-12 bg-white rounded-2xl border border-dashed border-gray-300">
                <p className="text-gray-500">جاري تحميل الخدمات...</p>
              </div>
            ) : (
              serviceCategories.map((cat: any) => (
                <Link 
                  key={cat.id} 
                  href={`/create-request?categoryId=${cat.id}&type=service`} 
                  className="group bg-white p-6 rounded-2xl border border-blue-100 hover:border-blue-300 hover:shadow-md transition-all duration-300 flex flex-col items-center justify-center gap-4 min-h-[180px]"
                >
                  {/* دائرة الأيقونة الملونة */}
                  <div className="w-16 h-16 rounded-full bg-blue-50 flex items-center justify-center group-hover:bg-blue-100 transition-colors">
                    <ServiceIcon name={cat.icon} />
                  </div>
                  <h3 className="font-semibold text-gray-800 text-center text-sm leading-tight">{cat.name}</h3>
                </Link>
              ))
            )}
          </div>
        </section>

        {/* Shops Grid */}
        <section>
          <div className="flex items-center gap-3 mb-8">
            <h2 className="text-2xl font-bold text-gray-900">المحلات التجارية</h2>
            <div className="h-8 w-1 bg-green-600 rounded-full"></div>
          </div>
          
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
            {businessCategories.length === 0 ? (
              <div className="col-span-full text-center py-12 bg-white rounded-2xl border border-dashed border-gray-300">
                <p className="text-gray-500">جاري تحميل المحلات...</p>
              </div>
            ) : (
              businessCategories.map((cat: any) => (
                <Link 
                  key={cat.id} 
                  href={`/shops?category=${cat.id}`} 
                  className="group bg-white p-6 rounded-2xl border border-green-100 hover:border-green-300 hover:shadow-md transition-all duration-300 flex flex-col items-center justify-center gap-4 min-h-[180px]"
                >
                  <div className="w-16 h-16 rounded-full bg-green-50 flex items-center justify-center group-hover:bg-green-100 transition-colors">
                    <ServiceIcon name={cat.icon} />
                  </div>
                  <h3 className="font-semibold text-gray-800 text-center text-sm leading-tight">{cat.name}</h3>
                </Link>
              ))
            )}
          </div>
        </section>
      </main>

      <footer className="bg-white border-t border-gray-200 py-8 mt-16">
        <div className="max-w-7xl mx-auto px-4 text-center">
          <p className="text-gray-500 text-sm">© 2026 منصة الحرفي الكويتي - جميع الحقوق محفوظة</p>
        </div>
      </footer>
    </div>
  )
}
