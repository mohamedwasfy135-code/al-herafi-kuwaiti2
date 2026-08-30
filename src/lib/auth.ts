import { SignJWT, jwtVerify } from 'jose'
import { cookies } from 'next/headers'

const secretKey = process.env.JWT_SECRET
if (!secretKey) {
  throw new Error('❌ Missing JWT_SECRET in environment variables')
}

const key = new TextEncoder().encode(secretKey)

export type SessionData = {
  userId: string
  role: string
  name: string
}

export async function createSessionToken(data: SessionData): Promise<string> {
  const token = await new SignJWT(data)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('7d')
    .sign(key)

  return token
}

const cookieOptions = {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax' as const,
  maxAge: 60 * 60 * 24 * 7,
  path: '/',
}

export function setSessionCookie(response: Response, token: string) {
  response.headers.append('Set-Cookie', `sana3i_session=${token}; HttpOnly; ${process.env.NODE_ENV === 'production' ? 'Secure; ' : ''}SameSite=Lax; Max-Age=${cookieOptions.maxAge}; Path=/`)
}

export function clearSessionCookie(response: Response) {
  response.headers.append('Set-Cookie', `sana3i_session=; HttpOnly; ${process.env.NODE_ENV === 'production' ? 'Secure; ' : ''}SameSite=Lax; Max-Age=0; Path=/`)
}

export async function getSession(): Promise<SessionData | null> {
  const cookieStore = await cookies()
  const token = cookieStore.get('sana3i_session')?.value

  if (!token) return null

  try {
    const { payload } = await jwtVerify(token, key)
    return payload as SessionData
  } catch {
    return null
  }
}

export async function getSessionFromRequest(request: Request): Promise<SessionData | null> {
  const token = request.headers.get('cookie')
    ?.split('; ')
    .find(c => c.startsWith('sana3i_session='))
    ?.split('=')[1]

  if (!token) return null

  try {
    const { payload } = await jwtVerify(token, key)
    return payload as SessionData
  } catch {
    return null
  }
}

// ✅ إضافة دالة verifyAuth المفقودة (للتحقق من توكن Bearer في الهيدر)
export async function verifyAuth(token: string): Promise<SessionData | null> {
  try {
    const { payload } = await jwtVerify(token, key)
    return payload as SessionData
  } catch {
    return null
  }
}

export async function createSession(data: SessionData) {
  const token = await createSessionToken(data)
  const cookieStore = await cookies()
  cookieStore.set('sana3i_session', token, cookieOptions)
}
