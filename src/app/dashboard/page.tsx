'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import {
  LayoutDashboard,
  ShoppingBag,
  MessageCircle,
  User,
  LogOut,
  Search,
  Star,
  Wrench,
  Sparkles,
  Loader2,
} from 'lucide-react'

interface UserData {
  id: string
  name: string
  phone: string
  role: string
}

interface Category {
  id: number
  name: string
  icon: string
  _count?: { services: number }
}

interface Service {
  id: number
  title: string
  description: string | null
  price: number
  craftsman?: { name: string; rating: number } | null
  category?: { name: string } | null
}

const defaultCategories = [
  { name: 'سباكة', icon: '🔧' },
  { name: 'كهرباء', icon: '⚡' },
  { name: 'نجارة', icon: '🪚' },
  { name: 'تكييف', icon: '❄️' },
  { name: 'دهان', icon: '🎨' },
  { name: 'صيانة', icon: '🔧' },
]

const defaultShopCategories = [
  { name: 'كهرباء', icon: '💡' },
  { name: 'أدوات صحية', icon: '🚿' },
  { name: 'تكييف', icon: '🌬️' },
  { name: 'أصباغ', icon: '🖌️' },
  { name: 'مواد بناء', icon: '🧱' },
  { name: 'تشطيب وديكورات', icon: '🛋️' },
  { name: 'مقاولات بناء', icon: '🏗️' },
  { name: 'شركات', icon: '🏢' },
  { name: 'مقاولين', icon: '👷' },
  { name: 'استشاريين', icon: '📐' },
]

const defaultServices = [
  { title: 'سباكة - تركيب حنفية', price: 5 },
  { title: 'كهرباء - إصلاح مفتاح', price: 8 },
  { title: 'نجارة - تجديد باب', price: 10 },
  { title: 'تكييف - صيانة سنوية', price: 7 },
]

export default function ClientDashboard() {
  const router = useRouter()
  const [user, setUser] = useState<UserData | null>(null)
  const [activeTab, setActiveTab] = useState<'home' | 'orders' | 'profile'>('home')
  const [categories, setCategories] = useState<Category[]>([])
  const [shopCategories, setShopCategories] = useState<any[]>([])
  const [services, setServices] = useState<Service[]>([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')

  useEffect(() => {
    const stored = localStorage.getItem('sana3i_user')
    if (!stored) {
      router.push('/login')
      return
    }
    const parsed = JSON.parse(stored) as UserData
    setUser(parsed)

    Promise.all([
      fetch('/api/categories').then(r => r.json()),
      fetch('/api/services?limit=8').then(r => r.json()),
    ])
      .then(([catData, servData]) => {
        let allCats = catData.categories || catData || []
        if (!Array.isArray(allCats)) allCats = []
        setCategories(allCats.filter((c: any) => !c.type || c.type === 'worker'))
        setShopCategories(allCats.filter((c: any) =>
          ['shop', 'contractor', 'company', 'consultant'].includes(c.type || '')
        ))
        setServices(servData.data || servData.services || [])
      })
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [])

  const handleLogout = () => {
    localStorage.removeItem('sana3i_user')
    router.push('/login')
  }

  const filteredServices = searchQuery
    ? services.filter(
        s =>
          s.title?.includes(searchQuery) ||
          s.description?.includes(searchQuery) ||
          s.craftsman?.name?.includes(searchQuery)
      )
    : services

  const getCategoryIcon = (name: string) => {
    const icons: Record<string, string> = {
      سباكة: '🔧', كهرباء: '⚡', تكييف: '❄️',
      دهان: '🎨', نجارة: '🪚', صيانة: '🛠️',
    }
    return icons[name] || '🔧'
  }

  return (
    <div dir="rtl" className="min-h-screen bg-gradient-to-br from-slate-50 to-blue-50 flex">
      <aside className="hidden md:flex md:flex-col md:w-64 bg-white border-l border-gray-200 shadow-xl shadow-gray-200/50 relative z-20">
        <div className="p-6 border-b border-gray-100">
          <h1 className="text-2xl font-extrabold bg-gradient-to-r from-blue-600 to-emerald-500 bg-clip-text text-transparent">
            الحرفي
          </h1>
          <p className="text-sm text-gray-700 mt-1">لوحة العميل</p>
        </div>

        <nav className="flex-1 px-4 py-4 space-y-1">
          {[
            { id: 'home', label: 'الرئيسية', icon: LayoutDashboard },
            { id: 'orders', label: 'طلباتي', icon: ShoppingBag },
            { id: 'profile', label: 'حسابي', icon: User },
          ].map(tab => {
            const Icon = tab.icon
            const isActive = activeTab === tab.id
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as any)}
                className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200 ${
                  isActive
                    ? 'bg-blue-50 text-blue-700 shadow-sm'
                    : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                }`}
              >
                <Icon className="h-5 w-5" />
                <span>{tab.label}</span>
                {isActive && <span className="mr-auto h-2 w-2 rounded-full bg-blue-600" />}
              </button>
            )
          })}
          <a
            href="/chat"
            className="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-gray-600 hover:bg-gray-50 hover:text-gray-900 transition-all duration-200"
          >
            <MessageCircle className="h-5 w-5" />
            <span>المحادثات</span>
          </a>
        </nav>

        <div className="p-4 border-t border-gray-100">
          {user && (
            <div className="flex items-center gap-3 mb-3">
              <div className="h-10 w-10 rounded-full bg-gradient-to-br from-blue-500 to-emerald-500 flex items-center justify-center text-white font-bold shadow-md">
                {user.name?.charAt(0) || 'ع'}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-gray-900 truncate">{user.name}</p>
                <p className="text-xs text-gray-700 truncate">{user.phone}</p>
              </div>
            </div>
          )}
          <button
            onClick={handleLogout}
            className="flex items-center gap-2 w-full px-3 py-2 text-sm text-red-500 hover:bg-red-50 rounded-lg transition"
          >
            <LogOut className="h-4 w-4" />
            تسجيل الخروج
          </button>
        </div>
      </aside>

      <div className="flex-1 flex flex-col min-h-screen">
        <header className="bg-white/80 backdrop-blur-md border-b border-gray-200 px-4 md:px-8 py-3 flex items-center justify-between sticky top-0 z-10">
          <div>
            <h2 className="text-lg md:text-2xl font-bold text-gray-800">
              {activeTab === 'home' && `مرحباً، ${user?.name || 'عميل'}`}
              {activeTab === 'orders' && 'طلباتي'}
              {activeTab === 'profile' && 'حسابي'}
            </h2>
            <p className="text-xs md:text-sm text-gray-700">
              {activeTab === 'home' && 'تصفح الخدمات والمحلات'}
              {activeTab === 'orders' && 'متابعة طلباتك'}
              {activeTab === 'profile' && 'معلومات الحساب'}
            </p>
          </div>
        </header>

        <main className="flex-1 p-4 md:p-8 overflow-y-auto">
          {activeTab === 'home' && (
            <>
              <div className="relative mb-8 max-w-xl">
                <Search className="absolute right-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-600" />
                <input
                  type="text"
                  placeholder="ابحث عن خدمة أو محل..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pr-10 pl-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-blue-500 transition bg-white"
                />
              </div>

              {loading ? (
                <div className="flex items-center justify-center h-64">
                  <Loader2 className="h-10 w-10 animate-spin text-blue-600" />
                </div>
              ) : (
                <div className="max-w-7xl mx-auto space-y-10">
                  {/* الخدمات الحرفية */}
                  <section>
                    <h2 className="text-2xl font-bold mb-6">الخدمات الحرفية</h2>
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3">
                      {(categories.length > 0 ? categories : defaultCategories).map((cat, i) => (
                        <Link
                          key={cat.id || i}
                          href={`/services?category=${cat.id || encodeURIComponent(cat.name)}`}
                          className="flex flex-col items-center gap-2 p-4 bg-white rounded-xl border hover:shadow-md hover:border-blue-300 transition"
                        >
                          <span className="text-3xl">{cat.icon || '📂'}</span>
                          <span className="text-sm font-medium text-center">{cat.name}</span>
                        </Link>
                      ))}
                    </div>
                  </section>

                  {/* المحلات والشركات */}
                  <section>
                    <h2 className="text-2xl font-bold mb-6">المحلات والشركات</h2>
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3">
                      {(shopCategories.length > 0 ? shopCategories : defaultShopCategories).map((cat, i) => (
                        <Link
                          key={cat.id || i}
                          href={`/business?category=${cat.id || encodeURIComponent(cat.name)}`}
                          className="flex flex-col items-center gap-2 p-4 bg-white rounded-xl border hover:shadow-md hover:border-blue-300 transition"
                        >
                          <span className="text-3xl">{cat.icon || '📂'}</span>
                          <span className="text-sm font-medium text-center">{cat.name}</span>
                        </Link>
                      ))}
                    </div>
                  </section>

                  {/* الخدمات المميزة */}
                  <section className="bg-gray-50 -mx-4 md:-mx-8 px-4 md:px-8 py-10">
                    <div className="flex items-center justify-between mb-6">
                      <h2 className="text-2xl font-bold">الخدمات المميزة</h2>
                      <Link href="/services" className="text-blue-600 hover:underline text-sm">
                        عرض الكل ←
                      </Link>
                    </div>
                    <div className="grid sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                      {(filteredServices.length > 0 ? filteredServices : defaultServices).map((item, i) => {
                        if (typeof item === 'object' && 'id' in item) {
                          const service = item as Service
                          return (
                            <div
                              key={service.id}
                              className="bg-white rounded-xl border p-4 cursor-pointer hover:shadow-lg transition"
                              onClick={() => router.push(`/service/${service.id}`)}
                            >
                              <div className="h-32 bg-gray-200 rounded-lg mb-3 flex items-center justify-center text-4xl">
                                {getCategoryIcon(service.category?.name || '')}
                              </div>
                              <h3 className="font-semibold mb-1">{service.title}</h3>
                              <p className="text-sm text-gray-700 mb-2 line-clamp-2">{service.description}</p>
                              <div className="flex items-center justify-between">
                                <span className="text-blue-600 font-bold">{service.price} د.ك</span>
                                <span className="text-sm text-gray-600">
                                  ⭐ {service.craftsman?.rating || 'جديد'}
                                </span>
                              </div>
                            </div>
                          )
                        } else {
                          const s = item as any
                          return (
                            <div
                              key={i}
                              className="bg-white rounded-xl border p-4 cursor-pointer hover:shadow-lg transition"
                              onClick={() => router.push(`/services?search=${encodeURIComponent(s.title)}`)}
                            >
                              <div className="h-32 bg-gray-200 rounded-lg mb-3 flex items-center justify-center text-4xl">
                                🔧
                              </div>
                              <h3 className="font-semibold mb-1">{s.title}</h3>
                              <div className="flex items-center justify-between mt-2">
                                <span className="text-blue-600 font-bold">{s.price} د.ك</span>
                              </div>
                            </div>
                          )
                        }
                      })}
                    </div>
                  </section>
                </div>
              )}
            </>
          )}

          {activeTab === 'orders' && (
            <div className="max-w-4xl mx-auto">
              <p className="text-gray-700 text-center py-12">قائمة الطلبات ستظهر هنا قريباً</p>
            </div>
          )}

          {activeTab === 'profile' && user && (
            <div className="max-w-md mx-auto bg-white rounded-xl shadow p-6">
              <div className="flex items-center gap-4 mb-6">
                <div className="h-16 w-16 rounded-full bg-gradient-to-br from-blue-500 to-emerald-500 flex items-center justify-center text-white text-2xl font-bold">
                  {user.name.charAt(0)}
                </div>
                <div>
                  <h3 className="text-xl font-bold">{user.name}</h3>
                  <p className="text-gray-700">{user.phone}</p>
                  <p className="text-sm text-gray-600">عميل</p>
                </div>
              </div>
              <button
                onClick={handleLogout}
                className="w-full py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition"
              >
                تسجيل الخروج
              </button>
            </div>
          )}
        </main>

        <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-white/90 backdrop-blur-md border-t border-gray-200 flex justify-around py-2 z-20">
          {[
            { id: 'home', label: 'الرئيسية', icon: LayoutDashboard },
            { id: 'orders', label: 'الطلبات', icon: ShoppingBag },
            { id: 'chat', label: 'محادثات', icon: MessageCircle, href: '/chat' },
            { id: 'profile', label: 'حسابي', icon: User },
          ].map(tab => {
            const isActive = activeTab === tab.id
            const Comp = tab.href ? 'a' : 'button'
            return (
              <Comp
                key={tab.id}
                href={tab.href || undefined}
                onClick={() => !tab.href && setActiveTab(tab.id as any)}
                className={`flex flex-col items-center gap-1 p-1 rounded-lg ${
                  isActive ? 'text-blue-600' : 'text-gray-600 hover:text-gray-600'
                }`}
              >
                <tab.icon className="h-5 w-5" />
                <span className="text-[10px] font-medium">{tab.label}</span>
              </Comp>
            )
          })}
        </nav>
      </div>
    </div>
  )
}