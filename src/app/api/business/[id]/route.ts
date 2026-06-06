import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    const business = await db.business.findUnique({
      where: { id },
      include: {
        owner: {
          select: { id: true, name: true, phone: true, email: true },
        },
        categoryRef: {
          select: { id: true, name: true },
        },
        _count: {
          select: {
            products: true,
            requests: true,
            businessClients: true,
            salesInvoices: true,
            purchaseInvoices: true,
          },
        },
      },
    })

    if (!business) {
      return NextResponse.json(
        { error: 'Business not found' },
        { status: 404 }
      )
    }

    // Get summary
    const [totalIncome, totalExpenses, totalPurchases] = await Promise.all([
      db.businessTransaction.aggregate({
        where: { businessId: id, type: 'income' },
        _sum: { amount: true },
      }),
      db.businessTransaction.aggregate({
        where: { businessId: id, type: 'expense' },
        _sum: { amount: true },
      }),
      db.businessTransaction.aggregate({
        where: { businessId: id, type: 'purchase' },
        _sum: { amount: true },
      }),
    ])

    const summary = {
      totalIncome: totalIncome._sum.amount || 0,
      totalExpenses: totalExpenses._sum.amount || 0,
      totalPurchases: totalPurchases._sum.amount || 0,
      netProfit:
        (totalIncome._sum.amount || 0) -
        (totalExpenses._sum.amount || 0) -
        (totalPurchases._sum.amount || 0),
    }

    return NextResponse.json({ ...business, summary })
  } catch (error) {
    console.error('Error fetching business:', error)
    return NextResponse.json(
      { error: 'Failed to fetch business' },
      { status: 500 }
    )
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const body = await request.json()

    const existing = await db.business.findUnique({ where: { id } })
    if (!existing) {
      return NextResponse.json(
        { error: 'Business not found' },
        { status: 404 }
      )
    }

    const business = await db.business.update({
      where: { id },
      data: {
        name: body.name,
        nameEn: body.nameEn,
        description: body.description,
        phone: body.phone,
        email: body.email,
        website: body.website,
        businessType: body.businessType,
        categoryId: body.categoryId ? parseInt(String(body.categoryId)) : undefined,
        governorate: body.governorate,
        city: body.city,
        address: body.address,
        isActive: body.isActive,
      },
    })

    return NextResponse.json(business)
  } catch (error) {
    console.error('Error updating business:', error)
    return NextResponse.json(
      { error: 'Failed to update business' },
      { status: 500 }
    )
  }
}

export async function DELETE(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    const existing = await db.business.findUnique({ where: { id } })
    if (!existing) {
      return NextResponse.json(
        { error: 'Business not found' },
        { status: 404 }
      )
    }

    await db.business.update({
      where: { id },
      data: { isActive: false },
    })

    return NextResponse.json({ message: 'Business deleted successfully' })
  } catch (error) {
    console.error('Error deleting business:', error)
    return NextResponse.json(
      { error: 'Failed to delete business' },
      { status: 500 }
    )
  }
}
