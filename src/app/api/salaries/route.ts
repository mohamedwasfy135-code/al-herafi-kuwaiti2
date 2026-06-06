import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'
import { logAudit } from '@/lib/audit'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    const employeeId = searchParams.get('employeeId')
    const month = searchParams.get('month')
    const year = searchParams.get('year')
    const status = searchParams.get('status')

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const where: Record<string, unknown> = { businessId }
    if (employeeId) where.employeeId = parseInt(employeeId)
    if (month) where.month = parseInt(month)
    if (year) where.year = parseInt(year)
    if (status) where.status = status

    const salaries = await db.salary.findMany({
      where,
      include: {
        employee: { select: { id: true, name: true, position: true, department: true } },
        account: { select: { id: true, name: true, code: true } },
      },
      orderBy: [{ year: 'desc' }, { month: 'desc' }],
    })

    return NextResponse.json(salaries)
  } catch (error) {
    console.error('[SALARIES] GET error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { businessId: rawBusinessId, action, month, year, employeeId } = body

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    // Handle "pay" action for salary payment with payment method support
    if (action === 'pay') {
      const { salaryId, paymentMethod, accountId } = body
      if (!salaryId) {
        return NextResponse.json({ error: 'salaryId مطلوب' }, { status: 400 })
      }

      const salary = await db.salary.findUnique({
        where: { id: parseInt(salaryId) },
        include: { employee: true, account: true }
      })

      if (!salary) {
        return NextResponse.json({ error: 'الراتب غير موجود' }, { status: 404 })
      }

      const updateData: Record<string, unknown> = {
        status: 'paid',
        paidDate: new Date(),
      }

      if (paymentMethod) updateData.paymentMethod = paymentMethod
      if (accountId) updateData.accountId = parseInt(accountId)

      const updated = await db.salary.update({
        where: { id: salary.id },
        data: updateData,
        include: {
          employee: { select: { id: true, name: true, position: true, department: true } },
          account: { select: { id: true, name: true, code: true } },
        }
      })

      // Log audit
      await logAudit({
        businessId,
        action: 'PAY',
        entity: 'Salary',
        entityId: salary.id,
        changes: { before: { status: salary.status }, after: { status: 'paid', paymentMethod, accountId } }
      })

      return NextResponse.json(updated)
    }

    if (action === 'generate') {
      // Generate salaries for all active employees for a given month/year
      if (!month || !year) {
        return NextResponse.json({ error: 'الشهر والسنة مطلوبان' }, { status: 400 })
      }

      const employees = await db.employee.findMany({
        where: { businessId, isActive: true },
      })

      if (employees.length === 0) {
        return NextResponse.json({ error: 'لا يوجد موظفين نشطين' }, { status: 400 })
      }

      // Check if salaries already exist for this month/year
      const existingSalaries = await db.salary.findMany({
        where: { businessId, month, year },
      })

      if (existingSalaries.length > 0) {
        return NextResponse.json({ error: 'تم إنشاء رواتب هذا الشهر مسبقاً' }, { status: 400 })
      }

      const salaries = await Promise.all(
        employees.map((emp) =>
          db.salary.create({
            data: {
              businessId,
              employeeId: emp.id,
              month,
              year,
              basicSalary: emp.salary,
              allowances: 0,
              deductions: 0,
              netSalary: emp.salary,
              status: 'pending',
              paymentMethod: body.paymentMethod || null,
            },
          })
        )
      )

      return NextResponse.json(salaries, { status: 201 })
    } else {
      // Create single salary
      if (!employeeId || !month || !year) {
        return NextResponse.json(
          { error: 'الموظف والشهر والسنة مطلوبون' },
          { status: 400 }
        )
      }

      const salary = await db.salary.create({
        data: {
          businessId,
          employeeId: parseInt(employeeId),
          month,
          year,
          basicSalary: parseFloat(String(body.basicSalary || 0)),
          allowances: parseFloat(String(body.allowances || 0)),
          deductions: parseFloat(String(body.deductions || 0)),
          netSalary: parseFloat(String(body.netSalary || body.basicSalary || 0)),
          status: 'pending',
          notes: body.notes || null,
          paymentMethod: body.paymentMethod || null,
        },
      })

      return NextResponse.json(salary, { status: 201 })
    }
  } catch (error) {
    console.error('[SALARIES] POST error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
