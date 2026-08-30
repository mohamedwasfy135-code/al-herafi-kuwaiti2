'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'

export default function Header() {
  const [user, setUser] = useState<any>(null)

  useEffect(() => {
    const stored = localStorage.getItem('sana3i_user')
    if (stored) setUser(JSON.parse(stored))
  }, [])

  const handleLogout = () => {
    localStorage.removeItem('sana3i_user')
    setUser(null)
    window.location.href = '/'
  }

  return (
    <header className="bg-white shadow-sm p-3 flex items-center justify-between sticky top-0 z-30">
      <div className="flex items-center gap-3">
        {user ? (
          <Link href="/profile" className="flex items-center gap-2 hover:underline">
            <span className="bg-blue-100 text-blue-700 w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold">
              {user.name?.charAt(0) || 'م'}
            </span>
            <span className="font-medium text-gray-800">مرحباً، {user.name}</span>
          </Link>
        ) : (
          <Link href="/" className="text-xl font-bold text-gray-800">الحرفي الكويتي</Link>
        )}
      </div>
      <div className="flex items-center gap-2">
        {user ? (
          <button onClick={handleLogout} className="text-sm text-red-600 hover:underline">خروج</button>
        ) : (
          <button
            onClick={() => { window.location.href = '/login' }}
            className="text-sm bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition"
          >
            تسجيل الدخول
          </button>
        )}
      </div>
    </header>
  )
}
