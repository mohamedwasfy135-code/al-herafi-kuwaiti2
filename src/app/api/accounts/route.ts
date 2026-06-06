import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    const accountType = searchParams.get('accountType')

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const where: Record<string, unknown> = { businessId }
    if (accountType) where.accountType = accountType

    const accounts = await db.account.findMany({
      where,
      include: {
        children: {
          include: {
            children: {
              include: {
                _count: { select: { debitTransactions: true, creditTransactions: true, bonds: true } },
              },
            },
            _count: { select: { debitTransactions: true, creditTransactions: true, bonds: true } },
          },
        },
        _count: { select: { debitTransactions: true, creditTransactions: true, bonds: true } },
      },
      orderBy: { code: 'asc' },
    })

    // Only return root accounts (parentId is null)
    const rootAccounts = accounts.filter((a) => !a.parentId)

    return NextResponse.json(rootAccounts)
  } catch (error) {
    console.error('[ACCOUNTS] GET error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      code,
      name,
      nameEn,
      accountType,
      parentId,
      currentBalance,
      openingBalance,
      description,
    } = body

    if (!code || !name || !accountType) {
      return NextResponse.json(
        { error: 'رمز الحساب والاسم والنوع مطلوبون' },
        { status: 400 }
      )
    }

    const validTypes = ['asset', 'liability', 'equity', 'revenue', 'expense']
    if (!validTypes.includes(accountType)) {
      return NextResponse.json({ error: 'نوع الحساب غير صحيح' }, { status: 400 })
    }

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const account = await db.account.create({
      data: {
        businessId,
        code,
        name,
        nameEn: nameEn || null,
        accountType,
        parentId: parentId ? parseInt(parentId) : null,
        currentBalance: parseFloat(String(currentBalance || 0)),
        openingBalance: parseFloat(String(openingBalance || 0)),
        description: description || null,
      },
    })

    return NextResponse.json(account, { status: 201 })
  } catch (error) {
    console.error('[ACCOUNTS] POST error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
