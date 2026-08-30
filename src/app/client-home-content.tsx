'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useLanguage } from '@/hooks/useLanguage'

// ═══════════════════════════════════════════════════════════════
// 1. مكون الصفحة الرئيسية للعميل المسجل (ClientHomePage)
// ═══════════════════════════════════════════════════════════════

export default function ClientHomePage() {
  const { language, t, changeLanguage, isRTL } = useLanguage()
  const [user, setUser] = useState<any>(null)

  useEffect(() => {
    const stored = localStorage.getItem('sana3i_user')
    if (stored) setUser(JSON.parse(stored))
  }, [])

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' })
    localStorage.removeItem('sana3i_user')
    window.location.href = '/'
  }

  return (
    <div dir={isRTL ? 'rtl' : 'ltr'} className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <header className="bg-white shadow-sm p-4 flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900">{isRTL ? 'الحرفي الكويتي' : 'Kuwaiti Craftsman'}</h1>
        <div className="flex gap-3 items-center">
          <button
            onClick={() => changeLanguage(language === 'ar' ? 'en' : 'ar')}
            className="text-sm bg-blue-600 text-white px-3 py-1.5 rounded-lg font-semibold hover:bg-blue-700 transition"
          >
            {language === 'ar' ? 'English' : 'العربية'}
          </button>
          {user ? (
            <button onClick={handleLogout} className="text-sm text-red-600 font-semibold hover:underline">
              {t('common.logout')}
            </button>
          ) : (
            <Link href="/login" className="text-sm bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 transition">
              {t('auth.login')}
            </Link>
          )}
        </div>
      </header>

      <main className="max-w-6xl mx-auto p-8">
        <div className="text-center py-16">
          <h2 className="text-5xl font-bold text-gray-900 mb-6">
            {isRTL ? 'منصة الحرفيين الأولى في الكويت' : 'The First Craftsman Platform in Kuwait'}
          </h2>
          <p className="text-xl text-gray-600 mb-8 font-semibold">
            {isRTL ? 'نوصلك بأفضل الحرفيين المحترفين في منطقتك' : 'We connect you with the best professional craftsmen in your area'}
          </p>
          <div className="flex gap-4 justify-center">
            <Link href="/register" className="bg-blue-600 text-white px-8 py-3 rounded-lg font-bold text-lg hover:bg-blue-700 transition shadow-lg">
              {t('auth.register')}
            </Link>
            <Link href="/services" className="bg-white text-blue-600 px-8 py-3 rounded-lg font-bold text-lg hover:bg-gray-50 transition shadow-lg border-2 border-blue-600">
              {isRTL ? 'تصفح الخدمات' : 'Browse Services'}
            </Link>
          </div>
        </div>

        <div className="grid md:grid-cols-3 gap-6 mt-16">
          <div className="bg-white p-6 rounded-xl shadow-lg">
            <div className="text-4xl mb-4">🔧</div>
            <h3 className="text-xl font-bold text-gray-900 mb-2">
              {isRTL ? 'حرفيون محترفون' : 'Professional Craftsmen'}
            </h3>
            <p className="text-gray-600 font-semibold">
              {isRTL ? 'نخبة من الحرفيين المعتمدين وذوي الخبرة' : 'Elite of certified and experienced craftsmen'}
            </p>
          </div>
          <div className="bg-white p-6 rounded-xl shadow-lg">
            <div className="text-4xl mb-4">⚡</div>
            <h3 className="text-xl font-bold text-gray-900 mb-2">
              {isRTL ? 'سرعة في الاستجابة' : 'Fast Response'}
            </h3>
            <p className="text-gray-600 font-semibold">
              {isRTL ? 'نضمن لك وصول الحرفي في أسرع وقت' : 'We guarantee the craftsman arrives in the fastest time'}
            </p>
          </div>
          <div className="bg-white p-6 rounded-xl shadow-lg">
            <div className="text-4xl mb-4">🛡️</div>
            <h3 className="text-xl font-bold text-gray-900 mb-2">
              {isRTL ? 'ضمان الجودة' : 'Quality Guarantee'}
            </h3>
            <p className="text-gray-600 font-semibold">
              {isRTL ? 'نظام تقييم ومراجعة لضمان أفضل خدمة' : 'Rating and review system to ensure the best service'}
            </p>
          </div>
        </div>
      </main>
    </div>
  )
}

// ═══════════════════════════════════════════════════════════════
// 2. مكون المحتوى الكامل للزوار (FullHomeContent)
// ═══════════════════════════════════════════════════════════════

interface FullHomeContentProps {
  categories: any[]
  services: any[]
  businesses: any[]
  onRequestService: (serviceId?: number) => void
}

export function FullHomeContent({ categories, services, businesses, onRequestService }: FullHomeContentProps) {
  const { language, isRTL } = useLanguage()

  return (
    <div className="max-w-6xl mx-auto px-4 py-12">
      {/* التصنيفات */}
      {categories.length > 0 && (
        <section className="mb-12">
          <h2 className="text-2xl font-bold text-gray-900 mb-6">
            {isRTL ? 'تصفح حسب التصنيف' : 'Browse by Category'}
          </h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {categories.map((cat: any) => (
              <Link
                key={cat.id}
                href={`/services?category=${cat.id}`}
                className="bg-white p-4 rounded-xl shadow hover:shadow-lg transition text-center"
              >
                <div className="text-3xl mb-2">{cat.icon || '🔧'}</div>
                <h3 className="font-semibold text-gray-800">
                  {language === 'ar' ? cat.name : (cat.nameEn || cat.name)}
                </h3>
              </Link>
            ))}
          </div>
        </section>
      )}

      {/* الخدمات */}
      {services.length > 0 && (
        <section className="mb-12">
          <h2 className="text-2xl font-bold text-gray-900 mb-6">
            {isRTL ? 'أحدث الخدمات' : 'Latest Services'}
          </h2>
          <div className="grid md:grid-cols-3 gap-6">
            {services.map((service: any) => (
              <div key={service.id} className="bg-white rounded-xl shadow-lg overflow-hidden">
                {service.images && (
                  <img src={service.images.split(',')[0]} alt={service.title} className="w-full h-48 object-cover" />
                )}
                <div className="p-4">
                  <h3 className="font-bold text-lg text-gray-900 mb-2">{service.title}</h3>
                  <p className="text-gray-600 text-sm mb-3 line-clamp-2">{service.description}</p>
                  <div className="flex justify-between items-center">
                    <span className="text-blue-600 font-bold">{service.price} {isRTL ? 'د.ك' : 'KWD'}</span>
                    <button
                      onClick={() => onRequestService(service.id)}
                      className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-blue-700 transition"
                    >
                      {isRTL ? 'اطلب الآن' : 'Request Now'}
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* المحلات */}
      {businesses.length > 0 && (
        <section className="mb-12">
          <h2 className="text-2xl font-bold text-gray-900 mb-6">
            {isRTL ? 'المحلات المميزة' : 'Featured Businesses'}
          </h2>
          <div className="grid md:grid-cols-3 gap-6">
            {businesses.map((biz: any) => (
              <Link key={biz.id} href={`/business/${biz.id}`} className="bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition">
                {biz.logoUrl && (
                  <img src={biz.logoUrl} alt={biz.name} className="w-full h-32 object-cover" />
                )}
                <div className="p-4">
                  <h3 className="font-bold text-lg text-gray-900 mb-1">
                    {language === 'ar' ? biz.name : (biz.nameEn || biz.name)}
                  </h3>
                  <p className="text-gray-600 text-sm line-clamp-2">{biz.description}</p>
                </div>
              </Link>
            ))}
          </div>
        </section>
      )}
    </div>
  )
}
