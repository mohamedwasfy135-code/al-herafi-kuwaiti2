'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'

type Category = {
  id: number
  name: string
  nameEn: string
  icon: string
  _count?: { services: number }
}

type Service = {
  id: number
  title: string
  description: string
  price: number
  craftsman: { name: string; rating: number }
  category: { name: string }
}

type Business = {
  id: string
  name: string
  businessType: string
  rating: number
  category: { name: string }
}

export default function HomePage() {
  const router = useRouter()
  const [searchQuery, setSearchQuery] = useState('')
  const [categories, setCategories] = useState<Category[]>([])
  const [services, setServices] = useState<Service[]>([])
  const [businesses, setBusinesses] = useState<Business[]>([])

  useEffect(() => {
    fetch('/api/categories')
      .then(res => res.json())
      .then(data => setCategories(data.categories || data || []))
      .catch(() => {})

    fetch('/api/services?limit=8')
      .then(res => res.json())
      .then(data => setServices(data.services || data || []))
      .catch(() => {})

    fetch('/api/business?limit=6')
      .then(res => res.json())
      .then(data => setBusinesses(data.businesses || data || []))
      .catch(() => {})
  }, [])

  const defaultCategories = [
    { name: 'سباكة', icon: '🔨' },
    { name: 'كهرباء', icon: '⚡' },
    { name: 'نجارة', icon: '🪚' },
    { name: 'تكييف', icon: '❄️' },
    { name: 'دهان', icon: '🎨' },
    { name: 'صيانة', icon: '🔧' },
  ]

  const defaultServices = [
    { title: 'سباكة - تركيب حنفية', price: 5 },
    { title: 'كهرباء - إصلاح مفتاح', price: 8 },
    { title: 'نجارة - تجديد باب', price: 10 },
    { title: 'تكييف - صيانة سنوية', price: 7 },
  ]

  const defaultBusinesses = [
    { name: 'محل الأدوات المنزلية', type: 'shop' },
    { name: 'شركة الصيانة العامة', type: 'company' },
    { name: 'مؤسسة البناء الحديث', type: 'company' },
  ]

  return (
    <div dir="rtl">
      {/* بحث رئيسي */}
      <section className="bg-gradient-to-b from-blue-600 to-blue-800 text-white py-16">
        <div className="max-w-4xl mx-auto px-4 text-center">
          <h1 className="text-4xl font-bold mb-3">الحرفي الكويتي</h1>
          <p className="text-blue-100 text-lg mb-8">
            اعثر على أفضل الحرفيين والمحلات في الكويت
          </p>
          <div className="flex gap-2 max-w-lg mx-auto">
            <input
              type="text"
              placeholder="ابحث عن خدمة أو محل أو حرفي..."
              className="flex-1 bg-white text-gray-900 text-lg h-12 px-4 rounded-lg outline-none"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && searchQuery) {
                  router.push(`/services?search=${searchQuery}`)
                }
              }}
            />
            <button
              className="h-12 px-6 bg-yellow-500 hover:bg-yellow-600 text-black font-bold rounded-lg transition"
              onClick={() => {
                if (searchQuery) router.push(`/services?search=${searchQuery}`)
              }}
            >
              بحث
            </button>
          </div>
        </div>
      </section>

      {/* الأقسام */}
      <section className="max-w-7xl mx-auto px-4 py-10">
        <h2 className="text-2xl font-bold mb-6">الأقسام</h2>
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3">
          {categories.length > 0 ? categories.map((cat) => (
            <Link
              key={cat.id}
              href={`/services?category=${cat.id}`}
              className="flex flex-col items-center gap-2 p-4 bg-white rounded-xl border hover:shadow-md hover:border-blue-300 transition"
            >
              <span className="text-3xl">{cat.icon || '📂'}</span>
              <span className="text-sm font-medium text-center">{cat.name}</span>
              {cat._count && (
                <span className="text-xs text-gray-400">{cat._count.services} خدمة</span>
              )}
            </Link>
          )) : defaultCategories.map((cat, i) => (
            <div
              key={i}
              className="flex flex-col items-center gap-2 p-4 bg-white rounded-xl border"
            >
              <span className="text-3xl">{cat.icon}</span>
              <span className="text-sm font-medium">{cat.name}</span>
            </div>
          ))}
        </div>
      </section>

      {/* الخدمات المميزة */}
      <section className="max-w-7xl mx-auto px-4 py-10 bg-gray-50">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-2xl font-bold">الخدمات المميزة</h2>
          <Link href="/services" className="text-blue-600 hover:underline text-sm">
            عرض الكل ←
          </Link>
        </div>
        <div className="grid sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {services.length > 0 ? services.map((service) => (
            <div
              key={service.id}
              className="bg-white rounded-xl border p-4 cursor-pointer hover:shadow-lg transition"
              onClick={() => router.push(`/service/${service.id}`)}
            >
              <div className="h-32 bg-gray-200 rounded-lg mb-3 flex items-center justify-center text-4xl">
                🔧
              </div>
              <h3 className="font-semibold mb-1">{service.title}</h3>
              <p className="text-sm text-gray-500 mb-2 line-clamp-2">
                {service.description}
              </p>
              <div className="flex items-center justify-between">
                <span className="text-blue-600 font-bold">{service.price} د.ك</span>
                <span className="text-sm text-gray-400">
                  ⭐ {service.craftsman?.rating || 'جديد'}
                </span>
              </div>
            </div>
          )) : defaultServices.map((s, i) => (
            <div key={i} className="bg-white rounded-xl border p-4 cursor-pointer hover:shadow-lg transition">
              <div className="h-32 bg-gray-200 rounded-lg mb-3 flex items-center justify-center text-4xl">
                🔧
              </div>
              <h3 className="font-semibold mb-1">{s.title}</h3>
              <div className="flex items-center justify-between mt-2">
                <span className="text-blue-600 font-bold">{s.price} د.ك</span>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* المحلات والشركات */}
      <section className="max-w-7xl mx-auto px-4 py-10">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-2xl font-bold">المحلات والشركات</h2>
          <Link href="/shops" className="text-blue-600 hover:underline text-sm">
            عرض الكل ←
          </Link>
        </div>
        <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-4">
          {businesses.length > 0 ? businesses.map((biz) => (
            <div
              key={biz.id}
              className="bg-white rounded-xl border p-4 cursor-pointer hover:shadow-lg transition"
              onClick={() => router.push(`/shop/${biz.id}`)}
            >
              <div className="flex items-center gap-3">
                <div className="w-14 h-14 bg-blue-100 rounded-lg flex items-center justify-center text-2xl">
                  {biz.businessType === 'company' ? '🏢' : '🏪'}
                </div>
                <div className="flex-1">
                  <h3 className="font-semibold">{biz.name}</h3>
                  <p className="text-sm text-gray-500">{biz.category?.name}</p>
                  <span className="text-sm text-yellow-500">
                    ⭐ {biz.rating || 'جديد'}
                  </span>
                </div>
              </div>
            </div>
          )) : defaultBusinesses.map((b, i) => (
            <div key={i} className="bg-white rounded-xl border p-4 cursor-pointer hover:shadow-lg transition">
              <div className="flex items-center gap-3">
                <div className="w-14 h-14 bg-blue-100 rounded-lg flex items-center justify-center text-2xl">
                  {b.type === 'company' ? '🏢' : '🏪'}
                </div>
                <div>
                  <h3 className="font-semibold">{b.name}</h3>
                  <span className="text-sm text-yellow-500">⭐ جديد</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* كيف تعمل المنصة */}
      <section className="max-w-7xl mx-auto px-4 py-10 bg-gray-50">
        <h2 className="text-2xl font-bold text-center mb-8">كيف تعمل المنصة؟</h2>
        <div className="grid md:grid-cols-3 gap-6">
          <div className="text-center p-6">
            <div className="text-4xl mb-3">🔍</div>
            <h3 className="font-bold text-lg mb-2">ابحث عن خدمة</h3>
            <p className="text-gray-500 text-sm">
              تصفح الأقسام أو ابحث عن الخدمة اللي تحتاجها
            </p>
          </div>
          <div className="text-center p-6">
            <div className="text-4xl mb-3">🔧</div>
            <h3 className="font-bold text-lg mb-2">اختر الحرفي</h3>
            <p className="text-gray-500 text-sm">
              قارن الأسعار والتقييمات واختر الأنسب لك
            </p>
          </div>
          <div className="text-center p-6">
            <div className="text-4xl mb-3">✅</div>
            <h3 className="font-bold text-lg mb-2">احصل على خدمتك</h3>
            <p className="text-gray-500 text-sm">
              الحرفي يوصل لموقعك وينفذ الخدمة باحترافية
            </p>
          </div>
        </div>
      </section>
    </div>
  )
}
