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

    const employees = await db.employee.findMany({
      where: { businessId },
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json(employees)
  } catch (error) {
    console.error('[EMPLOYEES] GET error:', error)
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
      nationalId,
      position,
      department,
      salary,
      joinDate,
      bankName,
      bankIban,
      address,
      notes,
    } = body

    if (!name) {
      return NextResponse.json({ error: 'اسم الموظف مطلوب' }, { status: 400 })
    }

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const employee = await db.employee.create({
      data: {
        businessId,
        name,
        nameEn: nameEn || null,
        phone: phone || null,
        email: email || null,
        nationalId: nationalId || null,
        position: position || null,
        department: department || null,
        salary: parseFloat(String(salary || 0)),
        joinDate: joinDate ? new Date(joinDate) : null,
        bankName: bankName || null,
        bankIban: bankIban || null,
        address: address || null,
        notes: notes || null,
      },
    })

    return NextResponse.json(employee, { status: 201 })
  } catch (error) {
    console.error('[EMPLOYEES] POST error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
