'use client'

import { useState, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { toast } from 'sonner'
import { useLanguage } from '@/lib/language-context'
import { Languages } from 'lucide-react'

function LoginForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const { t, lang, setLang, dir } = useLanguage()
  const callbackUrl = searchParams.get('callbackUrl') || ''

  const [mode, setMode] = useState<'login' | 'register'>('login')
  const [loading, setLoading] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')

  const [form, setForm] = useState({
    name: '',
    phone: '',
    password: '',
    role: 'client',
  })

  const updateField = (field: string, value: string) => {
    setForm(prev => ({ ...prev, [field]: value }))
    setErrorMsg('') // مسح الخطأ عند الكتابة
  }

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMsg('')

    if (!form.phone || !form.password) {
      setErrorMsg('رقم الجوال وكلمة المرور مطلوبان')
      return
    }

    setLoading(true)
    try {
      console.log('[LOGIN PAGE] Sending login request...', { phone: form.phone })

      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: form.phone, password: form.password }),
      })

      const data = await res.json()
      console.log('[LOGIN PAGE] Response:', { ok: res.ok, data })

      if (!res.ok) {
        setErrorMsg(data.error || 'Invalid credentials')
        toast.error(data.error || 'Invalid credentials')
        return
      }

      // حفظ بيانات المستخدم في localStorage
      localStorage.setItem('sana3i_user', JSON.stringify(data.user))
      toast.success(`${t('welcome')} ${data.user.name}`)

      // التوجيه حسب الدور
      let redirectUrl = '/'
      if (data.user.role === 'craftsman') {
        redirectUrl = '/craftsman/dashboard'
      } else if (data.user.role === 'business') {
        redirectUrl = '/shop/dashboard'
      } else if (callbackUrl) {
        redirectUrl = callbackUrl
      }

      console.log('[LOGIN PAGE] Redirecting to:', redirectUrl)

      // استخدام window.location للتوجيه الموثوق
      window.location.href = redirectUrl

    } catch (err) {
      console.error('[LOGIN PAGE] Error:', err)
      setErrorMsg('Connection error')
      toast.error('Connection error')
    } finally {
      setLoading(false)
    }
  }

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMsg('')

    if (!form.name || !form.phone || !form.password) {
      setErrorMsg('جميع الحقول مطلوبة')
      return
    }

    setLoading(true)
    try {
      console.log('[REGISTER PAGE] Sending register request...', { phone: form.phone, role: form.role })

      const res = await fetch('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      })

      const data = await res.json()
      console.log('[REGISTER PAGE] Response:', { ok: res.ok, data })

      if (!res.ok) {
        setErrorMsg(data.error || 'Account creation failed')
        toast.error(data.error || 'Account creation failed')
        return
      }

      localStorage.setItem('sana3i_user', JSON.stringify(data.user))
      toast.success(`Welcome ${data.user.name}`)

      // التوجيه حسب الدور
      let redirectUrl = '/'
      if (data.user.role === 'craftsman') {
        redirectUrl = '/craftsman/dashboard'
      } else if (callbackUrl) {
        redirectUrl = callbackUrl
      }

      console.log('[REGISTER PAGE] Redirecting to:', redirectUrl)
      window.location.href = redirectUrl

    } catch (err) {
      console.error('[REGISTER PAGE] Error:', err)
      setErrorMsg('Connection error')
      toast.error('Connection error')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div dir={dir} className="min-h-screen bg-gradient-to-b from-blue-600 to-blue-800 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* شعار */}
        <div className="text-center mb-8">
          <div className="text-6xl mb-3">🔧</div>
          <h1 className="text-3xl font-bold text-white">{t('app_name')}</h1>
          <p className="text-blue-200 mt-1">{t('platform_subtitle')}</p>
        </div>

        {/* بطاقة الدخول */}
        <div className="bg-white rounded-2xl shadow-2xl p-6">
          <h2 className="text-xl font-bold text-center mb-5">
            {mode === 'login' ? t('login_title') : t('login_register_title')}
          </h2>

          {/* رسالة الخطأ */}
          {errorMsg && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl text-center">
              <p className="text-sm text-red-600 font-medium">{errorMsg}</p>
            </div>
          )}

          <form onSubmit={mode === 'login' ? handleLogin : handleRegister} className="space-y-4">
            {/* الاسم - فقط في التسجيل */}
            {mode === 'register' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">{t('login_name')}</label>
                <input
                  type="text"
                  placeholder={lang === 'ar' ? 'أدخل اسمك' : 'Enter your name'}
                  className="w-full h-11 px-4 rounded-xl border border-gray-200 text-sm outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100 transition"
                  value={form.name}
                  onChange={(e) => updateField('name', e.target.value)}
                />
              </div>
            )}

            {/* رقم الجوال */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">{t('login_phone')}</label>
              <input
                type="tel"
                placeholder="5XXXXXXXX"
                className="w-full h-11 px-4 rounded-xl border border-gray-200 text-sm outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100 transition"
                value={form.phone}
                onChange={(e) => updateField('phone', e.target.value)}
                dir="ltr"
                autoComplete="tel"
              />
            </div>

            {/* كلمة المرور */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">{t('login_password')}</label>
              <input
                type="password"
                placeholder="••••••"
                className="w-full h-11 px-4 rounded-xl border border-gray-200 text-sm outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100 transition"
                value={form.password}
                onChange={(e) => updateField('password', e.target.value)}
                dir="ltr"
                autoComplete="current-password"
              />
            </div>

            {/* نوع الحساب - فقط في التسجيل */}
            {mode === 'register' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">{t('login_account_type')}</label>
                <div className="flex gap-3">
                  <button
                    type="button"
                    className={`flex-1 h-11 rounded-xl text-sm font-medium transition ${
                      form.role === 'client'
                        ? 'bg-blue-600 text-white shadow-md'
                        : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                    }`}
                    onClick={() => updateField('role', 'client')}
                  >
                    {t('login_client')}
                  </button>
                  <button
                    type="button"
                    className={`flex-1 h-11 rounded-xl text-sm font-medium transition ${
                      form.role === 'craftsman'
                        ? 'bg-blue-600 text-white shadow-md'
                        : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                    }`}
                    onClick={() => updateField('role', 'craftsman')}
                  >
                    {t('login_craftsman')}
                  </button>
                </div>
              </div>
            )}

            {/* زر الإرسال */}
            <button
              type="submit"
              className="w-full h-12 rounded-xl bg-blue-600 text-white font-bold text-base hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
              disabled={loading}
            >
              {loading ? t('login_loading') : mode === 'login' ? t('login_button') : t('login_register_button')}
            </button>
          </form>

          {/* تبديل وضع الدخول/التسجيل */}
          <div className="mt-5 text-center text-sm">
            {mode === 'login' ? (
              <span className="text-gray-500">
                {t('login_no_account')}{' '}
                <button
                  className="text-blue-600 hover:underline font-bold"
                  onClick={() => { setMode('register'); setErrorMsg('') }}
                >
                  {t('login_register_title')}
                </button>
              </span>
            ) : (
              <span className="text-gray-500">
                {t('login_has_account')}{' '}
                <button
                  className="text-blue-600 hover:underline font-bold"
                  onClick={() => { setMode('login'); setErrorMsg('') }}
                >
                  {t('login_title')}
                </button>
              </span>
            )}
          </div>

          {/* Language Switcher */}
          <div className="mt-4 flex justify-center">
            <button
              onClick={() => setLang(lang === 'ar' ? 'en' : 'ar')}
              className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-medium border border-gray-300 text-gray-600 hover:bg-gray-100 hover:text-gray-800 transition"
            >
              <Languages className="h-4 w-4" />
              {lang === 'ar' ? 'English' : 'العربية'}
            </button>
          </div>

          {/* بيانات تجريبية */}
          <div className="mt-4 bg-amber-50 border border-amber-200 rounded-xl p-3 text-center">
            <p className="text-xs text-amber-700 font-bold mb-1">{t('login_demo_data')}</p>
            <p className="text-xs text-amber-600">{t('login_demo_client')}</p>
            <p className="text-xs text-amber-600">{t('login_demo_craftsman')}</p>
          </div>
        </div>

        {/* رابط العودة */}
        <div className="mt-6 text-center">
          <Link href="/" className="text-blue-200 hover:text-white transition text-sm">
            {t('login_back_home')}
          </Link>
        </div>

        {/* رابط دخول المحل */}
        <div className="mt-3 text-center">
          <Link href="/shop/login" className="text-blue-300 hover:text-white transition text-sm">
            {t('login_shop_login')}
          </Link>
        </div>
      </div>
    </div>
  )
}

export default function LoginPage() {
  return (
    <Suspense fallback={
      <div dir="rtl" className="min-h-screen bg-gradient-to-b from-blue-600 to-blue-800 flex items-center justify-center">
        <p className="text-white text-lg">Loading...</p>
      </div>
    }>
      <LoginForm />
    </Suspense>
  )
}
