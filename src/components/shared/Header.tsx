'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'

type UserData = {
  id: string
  name: string
  role: string
}

export default function Header() {
  const router = useRouter()
  const [user, setUser] = useState<UserData | null>(null)
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    queueMicrotask(() => setMounted(true))
    try {
      const saved = localStorage.getItem('sana3i_user')
      if (saved) {
        const userData = JSON.parse(saved)
        queueMicrotask(() => setUser(userData))
      }
    } catch (e) {
      // ignore
    }
  }, [])

  const handleLogout = async () => {
    try {
      await fetch('/api/auth/logout', { method: 'POST' })
    } catch (e) {
      // ignore
    }
    localStorage.removeItem('sana3i_user')
    setUser(null)
    router.push('/')
  }

  return (
    <header className="sticky top-0 z-50 bg-white border-b shadow-sm" dir="rtl">
      <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between gap-4">
        {/* الشعار */}
        <Link href="/" className="flex items-center gap-2 font-bold text-lg">
          <span className="text-2xl">🔧</span>
          <span>الحرفي الكويتي</span>
        </Link>

        {/* البحث */}
        <div className="flex-1 max-w-md hidden md:block">
          <input
            type="text"
            placeholder="ابحث عن خدمة أو محل..."
            className="w-full h-9 px-3 rounded-md border border-gray-200 bg-transparent text-sm outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100"
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                const value = (e.target as HTMLInputElement).value
                if (value) router.push(`/services?search=${value}`)
              }
            }}
          />
        </div>

        {/* أزرار المستخدم */}
        <div className="flex items-center gap-3">
          {mounted && user ? (
            <>
              <Link
                href={
                  user.role === 'craftsman' ? '/craftsman/dashboard' :
                  user.role === 'business' ? '/shop/dashboard' :
                  '/my-orders'
                }
                className="text-sm text-gray-600 hover:text-gray-900"
              >
                مرحباً، {user.name}
              </Link>
              <button
                onClick={handleLogout}
                className="text-sm px-3 py-1.5 rounded-md border border-gray-200 hover:bg-gray-50 transition"
              >
                خروج
              </button>
            </>
          ) : (
            <Link
              href="/login"
              className="text-sm font-medium px-5 py-2 rounded-lg bg-blue-600 text-white hover:bg-blue-700 transition"
            >
              تسجيل الدخول
            </Link>
          )}
        </div>
      </div>
    </header>
  )
}
