import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function PUT(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params
    const body = await request.json()
    const { name, nameEn, phone, email, nationalId, position, department, salary, joinDate, leaveDate, bankName, bankIban, address, notes, isActive } = body

    const employee = await db.employee.update({
      where: { id: parseInt(id) },
      data: {
        ...(name !== undefined && { name }),
        ...(nameEn !== undefined && { nameEn }),
        ...(phone !== undefined && { phone }),
        ...(email !== undefined && { email }),
        ...(nationalId !== undefined && { nationalId }),
        ...(position !== undefined && { position }),
        ...(department !== undefined && { department }),
        ...(salary !== undefined && { salary: parseFloat(String(salary)) }),
        ...(joinDate !== undefined && { joinDate: joinDate ? new Date(joinDate) : null }),
        ...(leaveDate !== undefined && { leaveDate: leaveDate ? new Date(leaveDate) : null }),
        ...(bankName !== undefined && { bankName }),
        ...(bankIban !== undefined && { bankIban }),
        ...(address !== undefined && { address }),
        ...(notes !== undefined && { notes }),
        ...(isActive !== undefined && { isActive }),
      },
    })

    return NextResponse.json(employee)
  } catch (error) {
    console.error('[EMPLOYEE] PUT error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params
    await db.employee.delete({ where: { id: parseInt(id) } })
    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('[EMPLOYEE] DELETE error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
