'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { toast } from 'sonner'
import { Store, Users, Phone, Mail, Lock, Eye, EyeOff, Languages, Database, Loader2, AlertTriangle, CheckCircle2 } from 'lucide-react'
import { useLanguage } from '@/lib/language-context'

type LoginMode = 'owner' | 'business_user'
type SetupStatus = 'checking' | 'needs_setup' | 'setting_up' | 'ready' | 'error' | 'db_error'

export default function ShopLoginPage() {
  const { t, lang, setLang, dir } = useLanguage()
  const [loading, setLoading] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')
  const [loginMode, setLoginMode] = useState<LoginMode>('owner')
  const [showPassword, setShowPassword] = useState(false)
  const [form, setForm] = useState({
    phone: '',
    email: '',
    password: '',
  })

  // Database setup state
  const [setupStatus, setSetupStatus] = useState<SetupStatus>('checking')
  const [setupError, setSetupError] = useState('')
  const [setupResult, setSetupResult] = useState<any>(null)

  // Check database status on mount
  useEffect(() => {
    checkDatabase()
  }, [])

  const checkDatabase = async () => {
    try {
      const res = await fetch('/api/setup')
      const data = await res.json()
      if (data.connected) {
        if (data.needsSetup) {
          setSetupStatus('needs_setup')
        } else {
          setSetupStatus('ready')
        }
      } else {
        setSetupStatus('db_error')
        setSetupError(data.error || 'فشل الاتصال بقاعدة البيانات')
      }
    } catch {
      setSetupStatus('error')
      setSetupError('فشل الاتصال بالخادم')
    }
  }

  const handleSetup = async () => {
    setSetupStatus('setting_up')
    setSetupError('')
    try {
      const res = await fetch('/api/setup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'full' }),
      })
      const data = await res.json()

      if (data.success) {
        setSetupStatus('ready')
        setSetupResult(data)
        toast.success(lang === 'ar' ? 'تم إعداد قاعدة البيانات بنجاح!' : 'Database setup complete!')

        // Auto-fill demo credentials
        setForm(prev => ({
          ...prev,
          phone: data.loginInfo?.phone || '57654321',
          password: data.loginInfo?.password || '123456',
        }))
      } else {
        setSetupStatus('error')
        setSetupError(data.hint || data.error || 'فشل الإعداد')
        if (data.details) {
          setSetupError(prev => prev + ': ' + data.details)
        }
      }
    } catch {
      setSetupStatus('error')
      setSetupError('فشل الاتصال بالخادم أثناء الإعداد')
    }
  }

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMsg('')

    if (loginMode === 'owner') {
      if (!form.phone || !form.password) {
        setErrorMsg('رقم الجوال وكلمة المرور مطلوبان')
        return
      }
    } else {
      if ((!form.phone && !form.email) || !form.password) {
        setErrorMsg('رقم الجوال أو البريد الإلكتروني وكلمة المرور مطلوبان')
        return
      }
    }

    setLoading(true)
    try {
      const payload: Record<string, string> = {
        password: form.password,
        loginType: loginMode,
      }

      if (loginMode === 'owner') {
        payload.phone = form.phone
      } else {
        if (form.phone) payload.phone = form.phone
        if (form.email) payload.email = form.email
      }

      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      const data = await res.json()

      if (!res.ok) {
        // If server error, suggest checking setup
        if (res.status === 500) {
          setErrorMsg(lang === 'ar'
            ? 'خطأ في الخادم - تأكد من إعداد قاعدة البيانات أولاً'
            : 'Server error - make sure to setup the database first'
          )
          setSetupStatus('needs_setup')
        } else {
          setErrorMsg(data.error || 'حدث خطأ')
        }
        toast.error(data.error || 'حدث خطأ')
        return
      }

      if (data.user.role !== 'business') {
        setErrorMsg('هذه الصفحة لملاك المحلات فقط')
        toast.error('هذه الصفحة لملاك المحلات فقط')
        return
      }

      localStorage.setItem('sana3i_user', JSON.stringify(data.user))
      toast.success('مرحباً ' + data.user.name)

      window.location.href = '/shop/dashboard'

    } catch (err) {
      console.error('[SHOP LOGIN] Error:', err)
      setErrorMsg('حدث خطأ في الاتصال بالخادم')
      toast.error('حدث خطأ في الاتصال بالخادم')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gray-900 flex items-center justify-center p-4" dir={dir}>
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="text-5xl mb-4">🏪</div>
          <h1 className="text-2xl font-bold text-white">{t('login_shop_login')}</h1>
          <p className="text-gray-600 mt-2">{t('app_subtitle')}</p>
        </div>

        <div className="bg-white rounded-2xl p-6">
          {/* رسالة الخطأ */}
          {errorMsg && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl text-center">
              <p className="text-sm text-red-600 font-medium">{errorMsg}</p>
            </div>
          )}

          {/* Database Setup Banner */}
          {setupStatus === 'checking' && (
            <div className="mb-4 p-3 bg-sky-50 border border-sky-200 rounded-xl flex items-center gap-2">
              <Loader2 className="h-4 w-4 animate-spin text-sky-500" />
              <p className="text-sm text-sky-700">{lang === 'ar' ? 'جاري فحص قاعدة البيانات...' : 'Checking database...'}</p>
            </div>
          )}

          {setupStatus === 'needs_setup' && (
            <div className="mb-4 p-4 bg-amber-50 border border-amber-200 rounded-xl">
              <div className="flex items-center gap-2 mb-2">
                <Database className="h-5 w-5 text-amber-600" />
                <p className="text-sm font-bold text-amber-800">{lang === 'ar' ? 'إعداد قاعدة البيانات مطلوب' : 'Database Setup Required'}</p>
              </div>
              <p className="text-xs text-amber-700 mb-3">
                {lang === 'ar'
                  ? 'قاعدة البيانات فارغة. اضغط الزر أدناه لإنشاء المستخدم التجريبي وجميع البيانات اللازمة.'
                  : 'The database is empty. Click the button below to create the demo user and all required data.'}
              </p>
              <button
                onClick={handleSetup}
                className="w-full h-10 rounded-lg bg-amber-600 hover:bg-amber-700 text-white text-sm font-bold transition flex items-center justify-center gap-2"
              >
                <Database className="h-4 w-4" />
                {lang === 'ar' ? 'إعداد قاعدة البيانات' : 'Setup Database'}
              </button>
            </div>
          )}

          {setupStatus === 'setting_up' && (
            <div className="mb-4 p-4 bg-sky-50 border border-sky-200 rounded-xl flex items-center gap-2">
              <Loader2 className="h-5 w-5 animate-spin text-sky-500" />
              <p className="text-sm text-sky-700 font-medium">{lang === 'ar' ? 'جاري إعداد قاعدة البيانات وإنشاء البيانات التجريبية...' : 'Setting up database and creating demo data...'}</p>
            </div>
          )}

          {setupStatus === 'ready' && setupResult && (
            <div className="mb-4 p-3 bg-emerald-50 border border-emerald-200 rounded-xl flex items-center gap-2">
              <CheckCircle2 className="h-4 w-4 text-emerald-600 shrink-0" />
              <p className="text-sm text-emerald-700">{lang === 'ar' ? 'قاعدة البيانات جاهزة! بيانات الدخول: 57654321 / 123456' : 'Database ready! Login: 57654321 / 123456'}</p>
            </div>
          )}

          {(setupStatus === 'error' || setupStatus === 'db_error') && (
            <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-xl">
              <div className="flex items-center gap-2 mb-2">
                <AlertTriangle className="h-5 w-5 text-red-600" />
                <p className="text-sm font-bold text-red-800">{lang === 'ar' ? 'خطأ في الاتصال بقاعدة البيانات' : 'Database Connection Error'}</p>
              </div>
              <p className="text-xs text-red-700 mb-2">{setupError}</p>
              <p className="text-xs text-red-600 mb-3">
                {lang === 'ar'
                  ? 'تأكد من تعيين DATABASE_URL و DIRECT_URL في متغيرات البيئة على Vercel، ثم شغّل: npx prisma db push'
                  : 'Make sure DATABASE_URL and DIRECT_URL are set in Vercel environment variables, then run: npx prisma db push'}
              </p>
              <button
                onClick={checkDatabase}
                className="text-xs text-red-700 underline hover:text-red-900 transition"
              >
                {lang === 'ar' ? 'إعادة الفحص' : 'Retry Check'}
              </button>
            </div>
          )}

          {/* Login Mode Toggle */}
          <div className="flex gap-2 mb-6 p-1 bg-gray-100 rounded-xl">
            <button
              type="button"
              onClick={() => { setLoginMode('owner'); setErrorMsg('') }}
              className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg text-sm font-medium transition ${
                loginMode === 'owner'
                  ? 'bg-emerald-600 text-white shadow-sm'
                  : 'text-gray-700 hover:text-gray-700'
              }`}
            >
              <Store className="h-4 w-4" />
              {t('role_owner')}
            </button>
            <button
              type="button"
              onClick={() => { setLoginMode('business_user'); setErrorMsg('') }}
              className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg text-sm font-medium transition ${
                loginMode === 'business_user'
                  ? 'bg-violet-600 text-white shadow-sm'
                  : 'text-gray-700 hover:text-gray-700'
              }`}
            >
              <Users className="h-4 w-4" />
              {lang === 'ar' ? 'موظف / بائع' : 'Employee / Seller'}
            </button>
          </div>

          <form onSubmit={handleLogin} className="space-y-4">
            {loginMode === 'owner' ? (
              /* Owner Login - Phone */
              <div>
                <label className="text-sm font-medium mb-1 block">{t('login_phone')}</label>
                <div className="relative">
                  <Phone className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-600" />
                  <input
                    type="tel"
                    placeholder="5XXXXXXXX"
                    className="w-full h-11 pr-10 pl-4 rounded-xl border border-gray-200 text-sm outline-none focus:border-emerald-400 focus:ring-2 focus:ring-emerald-100 transition"
                    value={form.phone}
                    onChange={(e) => { setForm(prev => ({ ...prev, phone: e.target.value })); setErrorMsg('') }}
                    dir="ltr"
                    autoComplete="tel"
                  />
                </div>
              </div>
            ) : (
              /* Business User Login - Phone or Email */
              <>
                <div>
                  <label className="text-sm font-medium mb-1 block">{t('login_phone')}</label>
                  <div className="relative">
                    <Phone className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-600" />
                    <input
                      type="tel"
                      placeholder="5XXXXXXXX"
                      className="w-full h-11 pr-10 pl-4 rounded-xl border border-gray-200 text-sm outline-none focus:border-violet-400 focus:ring-2 focus:ring-violet-100 transition"
                      value={form.phone}
                      onChange={(e) => { setForm(prev => ({ ...prev, phone: e.target.value })); setErrorMsg('') }}
                      dir="ltr"
                      autoComplete="tel"
                    />
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <div className="flex-1 h-px bg-gray-200" />
                  <span className="text-xs text-gray-600">{lang === 'ar' ? 'أو' : 'or'}</span>
                  <div className="flex-1 h-px bg-gray-200" />
                </div>
                <div>
                  <label className="text-sm font-medium mb-1 block">{t('login_email')}</label>
                  <div className="relative">
                    <Mail className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-600" />
                    <input
                      type="email"
                      placeholder="email@example.com"
                      className="w-full h-11 pr-10 pl-4 rounded-xl border border-gray-200 text-sm outline-none focus:border-violet-400 focus:ring-2 focus:ring-violet-100 transition"
                      value={form.email}
                      onChange={(e) => { setForm(prev => ({ ...prev, email: e.target.value })); setErrorMsg('') }}
                      dir="ltr"
                      autoComplete="email"
                    />
                  </div>
                </div>
              </>
            )}

            <div>
              <label className="text-sm font-medium mb-1 block">{t('login_password')}</label>
              <div className="relative">
                <Lock className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-600" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  placeholder="••••••"
                  className="w-full h-11 pr-10 pl-10 rounded-xl border border-gray-200 text-sm outline-none focus:border-emerald-400 focus:ring-2 focus:ring-emerald-100 transition"
                  value={form.password}
                  onChange={(e) => { setForm(prev => ({ ...prev, password: e.target.value })); setErrorMsg('') }}
                  dir="ltr"
                  autoComplete="current-password"
                />
                <button
                  type="button"
                  className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-600 hover:text-gray-600"
                  onClick={() => setShowPassword(!showPassword)}
                >
                  {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              className={`w-full h-12 rounded-xl text-white font-bold transition disabled:opacity-50 disabled:cursor-not-allowed ${
                loginMode === 'owner'
                  ? 'bg-emerald-600 hover:bg-emerald-700'
                  : 'bg-violet-600 hover:bg-violet-700'
              }`}
              disabled={loading}
            >
              {loading ? t('login_loading') : loginMode === 'owner' ? t('login_button') : t('login_button')}
            </button>
          </form>

          <div className="mt-4 text-center">
            <Link href="/" className="text-sm text-gray-700 hover:text-gray-700 transition">
            {t('login_back_home')}
            </Link>
          </div>

          <div className="mt-3 bg-amber-50 border border-amber-200 rounded-xl p-3 text-center">
            {loginMode === 'owner' ? (
              <p className="text-xs text-amber-700">{lang === 'ar' ? 'بيانات تجريبية: 57654321 / 123456' : 'Demo: 57654321 / 123456'}</p>
            ) : (
              <p className="text-xs text-amber-700">{lang === 'ar' ? 'قم بإنشاء مستخدمين من صفحة الإعدادات بعد الدخول كمالك' : 'Create users from Settings after logging in as owner'}</p>
            )}
          </div>
        </div>

        <div className="mt-4 text-center">
          <button
            onClick={() => setLang(lang === 'ar' ? 'en' : 'ar')}
            className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-medium border border-gray-600 text-gray-600 hover:text-white hover:border-gray-400 transition"
          >
            <Languages className="h-4 w-4" />
            {lang === 'ar' ? 'English' : 'العربية'}
          </button>
        </div>

        <div className="mt-6 grid grid-cols-3 gap-3 text-center">
          <div className="bg-gray-800 rounded-lg p-3">
            <p className="text-xl mb-1">📄</p>
            <p className="text-xs text-gray-600">{t('nav_invoices')}</p>
          </div>
          <div className="bg-gray-800 rounded-lg p-3">
            <p className="text-xl mb-1">📑</p>
            <p className="text-xs text-gray-600">{t('nav_bonds')}</p>
          </div>
          <div className="bg-gray-800 rounded-lg p-3">
            <p className="text-xl mb-1">📊</p>
            <p className="text-xs text-gray-600">{t('nav_accounting')}</p>
          </div>
        </div>
      </div>
    </div>
  )
}
