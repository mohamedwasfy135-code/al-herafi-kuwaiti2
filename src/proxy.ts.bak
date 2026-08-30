import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'
import { jwtVerify } from 'jose'

const secretKey = process.env.JWT_SECRET || 'sana3i-kw-super-secret-key-2024'
const key = new TextEncoder().encode(secretKey)

const publicPages = ['/', '/services', '/shops', '/login', '/register']

const clientPages = ['/my-orders', '/my-chats', '/my-reviews', '/profile', '/cart', '/checkout']

const craftsmanPages = ['/craftsman/dashboard', '/craftsman/requests', '/craftsman/my-services', '/craftsman/earnings', '/craftsman/offers', '/craftsman/reviews', '/craftsman/chats', '/craftsman/profile']

const shopPages = ['/shop/dashboard', '/shop/invoices', '/shop/bonds', '/shop/accounting', '/shop/products', '/shop/clients', '/shop/offers', '/shop/settings',
  '/shop/sales-invoices', '/shop/purchase-invoices', '/shop/sales-returns', '/shop/purchase-returns',
  '/shop/inventory', '/shop/warehouses', '/shop/categories', '/shop/suppliers',
  '/shop/chart-of-accounts', '/shop/employees', '/shop/salaries', '/shop/rents',
  '/shop/petty-cash', '/shop/cost-centers',
]

async function getSessionFromRequest(request: NextRequest) {
  const token = request.cookies.get('sana3i_session')?.value
  if (!token) return null

  try {
    const { payload } = await jwtVerify(token, key)
    return payload as { userId: string; role: string; name: string }
  } catch {
    return null
  }
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl
  const session = await getSessionFromRequest(request)

  // صفحة دخول المحل
  if (pathname === '/shop/login') {
    if (session && session.role === 'business') {
      return NextResponse.redirect(new URL('/shop/dashboard', request.url))
    }
    return NextResponse.next()
  }

  // صفحة تسجيل الدخول العامة
  if (pathname === '/login' || pathname === '/register') {
    if (session) {
      if (session.role === 'craftsman') {
        return NextResponse.redirect(new URL('/craftsman/dashboard', request.url))
      }
      if (session.role === 'business') {
        return NextResponse.redirect(new URL('/shop/dashboard', request.url))
      }
      return NextResponse.redirect(new URL('/', request.url))
    }
    return NextResponse.next()
  }

  // الصفحات العامة
  if (publicPages.some(page => pathname === page)) {
    return NextResponse.next()
  }

  // ملفات ثابتة وAPI
  if (pathname.startsWith('/_next') || pathname.startsWith('/api') || pathname.includes('.')) {
    return NextResponse.next()
  }

  // الصفحات المحمية
  if (!session) {
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('callbackUrl', pathname)
    return NextResponse.redirect(loginUrl)
  }

  // التحقق من الدور
  if (craftsmanPages.some(page => pathname.startsWith(page)) && session.role !== 'craftsman') {
    return NextResponse.redirect(new URL('/', request.url))
  }

  if (shopPages.some(page => pathname.startsWith(page)) && session.role !== 'business') {
    return NextResponse.redirect(new URL('/shop/login', request.url))
  }

  if (clientPages.some(page => pathname.startsWith(page)) && session.role !== 'client') {
    return NextResponse.redirect(new URL('/', request.url))
  }

  return NextResponse.next()
}

export const config = {
  matcher: [
    '/((?!api|_next/static|_next/image|favicon.ico|.*\.zip).*)',
  ],
}
