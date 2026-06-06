import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const suppliers = await db.supplier.findMany({
      where: { businessId },
      include: {
        _count: { select: { purchaseInvoices: true, products: true } },
      },
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json(suppliers)
  } catch (error) {
    console.error('[SUPPLIERS] GET error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      name,
      nameEn,
      phone,
      email,
      address,
      contactPerson,
      contactPhone,
      balance,
      paymentTerms,
      taxNumber,
      notes,
    } = body

    if (!name) {
      return NextResponse.json({ error: 'اسم المورد مطلوب' }, { status: 400 })
    }

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const supplier = await db.supplier.create({
      data: {
        businessId,
        name,
        nameEn: nameEn || null,
        phone: phone || null,
        email: email || null,
        address: address || null,
        contactPerson: contactPerson || null,
        contactPhone: contactPhone || null,
        balance: parseFloat(String(balance || 0)),
        paymentTerms: paymentTerms || null,
        taxNumber: taxNumber || null,
        notes: notes || null,
      },
    })

    return NextResponse.json(supplier, { status: 201 })
  } catch (error) {
    console.error('[SUPPLIERS] POST error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
