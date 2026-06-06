'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
// simplified - no shadcn Button dependency

const menuItems = [
  { href: '/craftsman/dashboard', label: 'الرئيسية', icon: '🏠' },
  { href: '/craftsman/requests', label: 'الطلبات الواردة', icon: '📋' },
  { href: '/craftsman/my-services', label: 'خدماتي', icon: '🔧' },
  { href: '/craftsman/earnings', label: 'أرباحي', icon: '💰' },
  { href: '/craftsman/offers', label: 'عروض الأسعار', icon: '📝' },
  { href: '/craftsman/reviews', label: 'التقييمات', icon: '⭐' },
  { href: '/craftsman/chats', label: 'المحادثات', icon: '💬' },
  { href: '/craftsman/profile', label: 'حسابي', icon: '👤' },
]

export default function CraftsmanLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const pathname = usePathname()
  const router = useRouter()
  const [user, setUser] = useState<{ name: string; role: string } | null>(null)
  const [sidebarOpen, setSidebarOpen] = useState(false)

  useEffect(() => {
    const saved = localStorage.getItem('sana3i_user')
    if (saved) {
      const userData = JSON.parse(saved)
      if (userData.role !== 'craftsman') {
        router.push('/')
        return
      }
      queueMicrotask(() => setUser(userData))
    } else {
      router.push('/login')
    }
  }, [router])

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' })
    localStorage.removeItem('sana3i_user')
    router.push('/')
  }

  if (!user) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <p className="text-gray-500">جاري التحميل...</p>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50 flex" dir="rtl">
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40 md:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      <aside
        className={`
          fixed md:static inset-y-0 right-0 z-50
          w-64 bg-white border-l shadow-sm
          transform transition-transform md:transform-none
          ${sidebarOpen ? 'translate-x-0' : 'translate-x-full md:translate-x-0'}
        `}
      >
        <div className="flex flex-col h-full">
          <div className="p-4 border-b">
            <Link href="/craftsman/dashboard" className="flex items-center gap-2 font-bold text-lg">
              <span className="text-2xl">🔧</span>
              <span>الحرفي الكويتي</span>
            </Link>
            <p className="text-xs text-gray-400 mt-1">لوحة تحكم الحرفي</p>
          </div>

          <nav className="flex-1 p-3 space-y-1">
            {menuItems.map((item) => {
              const isActive = pathname === item.href
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={() => setSidebarOpen(false)}
                  className={`
                    flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition
                    ${isActive
                      ? 'bg-blue-50 text-blue-700 font-medium'
                      : 'text-gray-600 hover:bg-gray-100'
                    }
                  `}
                >
                  <span className="text-lg">{item.icon}</span>
                  <span>{item.label}</span>
                </Link>
              )
            })}
          </nav>

          <div className="p-3 border-t">
            <button
              className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-red-600 hover:text-red-700 hover:bg-red-50 transition"
              onClick={handleLogout}
            >
              <span>🚪</span>
              <span>تسجيل الخروج</span>
            </button>
          </div>
        </div>
      </aside>

      <div className="flex-1 flex flex-col min-h-screen">
        <header className="bg-white border-b px-4 h-14 flex items-center justify-between">
          <button
            className="md:hidden text-gray-600"
            onClick={() => setSidebarOpen(true)}
          >
            ☰
          </button>
          <p className="text-sm text-gray-500">
            مرحباً، <span className="font-medium text-gray-900">{user.name}</span>
          </p>
        </header>

        <main className="flex-1 p-4 md:p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
