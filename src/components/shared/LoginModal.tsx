'use client'

import { useState, useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'

type LoginModalProps = {
  callbackUrl?: string
  onSuccess: (user: { id: string; name: string; role: string }) => void
  onClose: () => void
}

export default function LoginModal({ callbackUrl, onSuccess, onClose }: LoginModalProps) {
  const router = useRouter()
  const overlayRef = useRef<HTMLDivElement>(null)

  const [mode, setMode] = useState<'login' | 'register'>('login')
  const [loading, setLoading] = useState(false)
  const [form, setForm] = useState({
    name: '',
    phone: '',
    password: '',
    role: 'client',
  })

  const updateField = (field: string, value: string) => {
    setForm(prev => ({ ...prev, [field]: value }))
  }

  // إغلاق بالضغط على الخلفية
  const handleOverlayClick = (e: React.MouseEvent) => {
    if (e.target === overlayRef.current) {
      onClose()
    }
  }

  // إغلاق بزر Escape
  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handleEsc)
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', handleEsc)
      document.body.style.overflow = ''
    }
  }, [onClose])

  // دالة مساعدة للتوجيه بعد الدخول
  const redirectAfterLogin = (user: { id: string; name: string; role: string }) => {
    if (user.role === 'craftsman') {
      router.push('/craftsman')
    } else if (user.role === 'client') {
      router.push('/dashboard')        // ✅ لوحة العميل الجديدة
    } else if (user.role === 'admin') {
      router.push('/admin')
    } else if (callbackUrl) {
      router.push(callbackUrl)
    } else {
      router.refresh()
    }
  }

  const handleLogin = async () => {
    if (!form.phone || !form.password) {
      toast.error('رقم الجوال وكلمة المرور مطلوبان')
      return
    }

    setLoading(true)
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: form.phone, password: form.password }),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.error || 'حدث خطأ')
        return
      }

      toast.success('مرحباً ' + data.user.name)
      localStorage.setItem('sana3i_user', JSON.stringify(data.user))
      redirectAfterLogin(data.user)
      onSuccess(data.user)

    } catch {
      toast.error('حدث خطأ في الاتصال')
    } finally {
      setLoading(false)
    }
  }

  const handleRegister = async () => {
    if (!form.name || !form.phone || !form.password) {
      toast.error('جميع الحقول مطلوبة')
      return
    }

    setLoading(true)
    try {
      const res = await fetch('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.error || 'حدث خطأ')
        return
      }

      toast.success('أهلاً بك ' + data.user.name)
      localStorage.setItem('sana3i_user', JSON.stringify(data.user))
      redirectAfterLogin(data.user)
      onSuccess(data.user)

    } catch {
      toast.error('حدث خطأ في الاتصال')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div
      ref={overlayRef}
      onClick={handleOverlayClick}
      className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/50"
      dir="rtl"
    >
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 p-6 animate-in zoom-in-95 duration-200">
        {/* عنوان */}
        <div className="flex items-center justify-between mb-5">
          <h2 className="text-xl font-bold">
            {mode === 'login' ? 'تسجيل الدخول' : 'إنشاء حساب جديد'}
          </h2>
          <button
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center rounded-full hover:bg-gray-100 text-gray-600 hover:text-gray-600 transition"
          >
            ✕
          </button>
        </div>

        {/* حقول الإدخال */}
        <div className="space-y-4">
          {mode === 'register' && (
            <div>
              <label className="text-sm font-medium mb-1 block">الاسم</label>
              <input
                type="text"
                placeholder="أدخل اسمك"
                className="w-full h-10 px-3 rounded-lg border border-gray-200 bg-white text-sm outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100"
                value={form.name}
                onChange={(e) => updateField('name', e.target.value)}
              />
            </div>
          )}

          <div>
            <label className="text-sm font-medium mb-1 block">رقم الجوال</label>
            <input
              type="tel"
              placeholder="5XXXXXXXX"
              className="w-full h-10 px-3 rounded-lg border border-gray-200 bg-white text-sm outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100"
              value={form.phone}
              onChange={(e) => updateField('phone', e.target.value)}
              dir="ltr"
            />
          </div>

          <div>
            <label className="text-sm font-medium mb-1 block">كلمة المرور</label>
            <input
              type="password"
              placeholder="••••••"
              className="w-full h-10 px-3 rounded-lg border border-gray-200 bg-white text-sm outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100"
              value={form.password}
              onChange={(e) => updateField('password', e.target.value)}
              dir="ltr"
            />
          </div>

          {mode === 'register' && (
            <div>
              <label className="text-sm font-medium mb-2 block">نوع الحساب</label>
              <div className="flex gap-2">
                <button
                  type="button"
                  className={`flex-1 h-10 rounded-lg text-sm font-medium transition ${
                    form.role === 'client'
                      ? 'bg-blue-600 text-white'
                      : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                  }`}
                  onClick={() => updateField('role', 'client')}
                >
                  عميل
                </button>
                <button
                  type="button"
                  className={`flex-1 h-10 rounded-lg text-sm font-medium transition ${
                    form.role === 'craftsman'
                      ? 'bg-blue-600 text-white'
                      : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                  }`}
                  onClick={() => updateField('role', 'craftsman')}
                >
                  حرفي
                </button>
              </div>
            </div>
          )}

          <button
            className="w-full h-11 rounded-lg bg-blue-600 text-white font-medium hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
            onClick={mode === 'login' ? handleLogin : handleRegister}
            disabled={loading}
          >
            {loading
              ? 'جاري التحميل...'
              : mode === 'login'
                ? 'تسجيل الدخول'
                : 'إنشاء حساب'
            }
          </button>

          <div className="text-center text-sm">
            {mode === 'login' ? (
              <>
                ليس لديك حساب؟{' '}
                <button
                  className="text-blue-600 hover:underline font-medium"
                  onClick={() => setMode('register')}
                >
                  إنشاء حساب جديد
                </button>
              </>
            ) : (
              <>
                لديك حساب؟{' '}
                <button
                  className="text-blue-600 hover:underline font-medium"
                  onClick={() => setMode('login')}
                >
                  تسجيل الدخول
                </button>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}