import { NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const categoriesParam = searchParams.get('categories') // مثال: "سباكة,كهرباء"
    let categories: string[] = []

    if (categoriesParam) {
      categories = categoriesParam.split(',').map(c => c.trim())
    }

    const whereClause: any = {
      craftsmanId: null,
      status: { in: ['pending', 'bidding'] }
    }

    if (categories.length > 0) {
      whereClause.serviceType = { in: categories }
    }

    const openRequests = await prisma.request.findMany({
      where: whereClause,
      orderBy: { createdAt: 'desc' }
    })

    return NextResponse.json({ requests: openRequests })
  } catch (error: any) {
    console.error('Open requests error:', error)
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}
