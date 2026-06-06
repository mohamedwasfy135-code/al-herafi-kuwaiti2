import { NextResponse } from 'next/server'
import { db } from '@/lib/db'

/**
 * GET /api/health - فحص حالة الاتصال بقاعدة البيانات والمتغيرات
 */
export async function GET() {
  const result: Record<string, unknown> = {
    timestamp: new Date().toISOString(),
    env: {
      hasDatabaseUrl: !!process.env.DATABASE_URL,
      hasDirectUrl: !!process.env.DIRECT_URL,
      hasJwtSecret: !!process.env.JWT_SECRET,
      nodeEnv: process.env.NODE_ENV,
    },
  }

  try {
    // Test database connection
    await db.$queryRaw`SELECT 1`
    result.database = { connected: true }

    // Check if tables exist
    const userCount = await db.user.count()
    const businessCount = await db.business.count()
    result.database.hasData = userCount > 0 || businessCount > 0
    result.database.userCount = userCount
    result.database.businessCount = businessCount
  } catch (error: any) {
    result.database = {
      connected: false,
      error: error?.message || 'Unknown error',
      code: error?.code || '',
    }
  }

  const isHealthy = result.database.connected as boolean

  return NextResponse.json(result, {
    status: isHealthy ? 200 : 503,
  })
}
