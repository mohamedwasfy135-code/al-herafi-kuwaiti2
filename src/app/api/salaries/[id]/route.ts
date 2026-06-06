import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { logAudit } from '@/lib/audit'

export async function PUT(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params
    const body = await request.json()
    const { allowances, deductions, netSalary, status, accountId, paidDate, notes } = body

    // Wrap in transaction for atomicity
    const salary = await db.$transaction(async (tx) => {
      const updateData: Record<string, unknown> = {}
      if (allowances !== undefined) {
        updateData.allowances = parseFloat(String(allowances))
      }
      if (deductions !== undefined) {
        updateData.deductions = parseFloat(String(deductions))
      }
      if (netSalary !== undefined) {
        updateData.netSalary = parseFloat(String(netSalary))
      }
      if (status !== undefined) {
        updateData.status = status
      }
      if (accountId !== undefined) {
        updateData.accountId = parseInt(accountId)
      }
      if (paidDate !== undefined) {
        updateData.paidDate = paidDate ? new Date(paidDate) : null
      }
      if (notes !== undefined) {
        updateData.notes = notes
      }

      const updatedSalary = await tx.salary.update({
        where: { id: parseInt(id) },
        data: updateData,
        include: {
          employee: { select: { name: true } },
          account: { select: { name: true, code: true } },
        },
      })

      // If marking as paid with account, update accounting
      if (status === 'paid' && updatedSalary.accountId) {
        const salaryAmount = updatedSalary.netSalary

        // Create BusinessTransaction for the salary expense
        await tx.businessTransaction.create({
          data: {
            businessId: updatedSalary.businessId,
            type: 'expense',
            amount: salaryAmount,
            description: `راتب ${updatedSalary.employee?.name || 'موظف'} - ${updatedSalary.month}/${updatedSalary.year}`,
            category: 'salary',
            referenceType: 'salary',
            referenceId: updatedSalary.id,
            debitAccountId: updatedSalary.accountId,
            transactionDate: updatedSalary.paidDate || new Date(),
          },
        })

        // Update account currentBalance (decrease)
        await tx.account.update({
          where: { id: updatedSalary.accountId },
          data: { currentBalance: { decrement: salaryAmount } },
        })

        // Update BusinessSummary - increase totalExpenses
        const existingSummary = await tx.businessSummary.findFirst({
          where: { businessId: updatedSalary.businessId },
        })

        if (existingSummary) {
          const newTotalExpenses = existingSummary.totalExpenses + salaryAmount
          await tx.businessSummary.update({
            where: { id: existingSummary.id },
            data: {
              totalExpenses: newTotalExpenses,
              netProfit: existingSummary.totalIncome - newTotalExpenses,
              transactionCount: existingSummary.transactionCount + 1,
              lastUpdated: new Date(),
            },
          })
        } else {
          await tx.businessSummary.create({
            data: {
              businessId: updatedSalary.businessId,
              totalIncome: 0,
              totalExpenses: salaryAmount,
              totalPurchases: 0,
              netProfit: -salaryAmount,
              transactionCount: 1,
            },
          })
        }
      }

      return updatedSalary
    })

    if (status === 'paid') {
      await logAudit({
        businessId: salary.businessId,
        action: 'PAY',
        entity: 'Salary',
        entityId: salary.id,
        changes: { after: { employeeName: salary.employee?.name, netSalary: salary.netSalary, month: salary.month, year: salary.year } },
      })
    } else {
      await logAudit({
        businessId: salary.businessId,
        action: 'UPDATE',
        entity: 'Salary',
        entityId: salary.id,
        changes: { after: { employeeName: salary.employee?.name, netSalary: salary.netSalary, status: salary.status } },
      })
    }

    return NextResponse.json(salary)
  } catch (error) {
    console.error('[SALARY] PUT error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
