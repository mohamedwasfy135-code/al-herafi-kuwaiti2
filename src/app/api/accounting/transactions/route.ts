import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    const type = searchParams.get('type') || ''
    const category = searchParams.get('category') || ''

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const where: Record<string, unknown> = { businessId }

    if (type) {
      where.type = type
    }

    if (category) {
      where.category = category
    }

    const transactions = await db.businessTransaction.findMany({
      where,
      include: {
        debitAccount: {
          select: { id: true, code: true, name: true },
        },
        creditAccount: {
          select: { id: true, code: true, name: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json(transactions)
  } catch (error) {
    console.error('Error fetching transactions:', error)
    return NextResponse.json(
      { error: 'Failed to fetch transactions' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      type,
      amount,
      description,
      category,
      referenceType,
      referenceId,
      debitAccountId,
      creditAccountId,
      transactionDate,
      tags,
    } = body

    if (!rawBusinessId) {
      return NextResponse.json(
        { error: 'businessId, type, and amount are required' },
        { status: 400 }
      )
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    if (!type || !amount) {
      return NextResponse.json(
        { error: 'businessId, type, and amount are required' },
        { status: 400 }
      )
    }

    const transaction = await db.businessTransaction.create({
      data: {
        businessId,
        type,
        amount: parseFloat(String(amount)),
        description,
        category,
        referenceType,
        referenceId: referenceId ? parseInt(String(referenceId)) : null,
        debitAccountId: debitAccountId ? parseInt(String(debitAccountId)) : null,
        creditAccountId: creditAccountId ? parseInt(String(creditAccountId)) : null,
        transactionDate: transactionDate ? new Date(transactionDate) : new Date(),
        tags,
      },
    })

    return NextResponse.json(transaction, { status: 201 })
  } catch (error) {
    console.error('Error creating transaction:', error)
    return NextResponse.json(
      { error: 'Failed to create transaction' },
      { status: 500 }
    )
  }
}
