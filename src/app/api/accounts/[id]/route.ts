import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function PUT(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params
    const body = await request.json()
    const { code, name, nameEn, accountType, parentId, currentBalance, openingBalance, isActive, description } = body

    const account = await db.account.update({
      where: { id: parseInt(id) },
      data: {
        ...(code !== undefined && { code }),
        ...(name !== undefined && { name }),
        ...(nameEn !== undefined && { nameEn }),
        ...(accountType !== undefined && { accountType }),
        ...(parentId !== undefined && { parentId: parentId ? parseInt(parentId) : null }),
        ...(currentBalance !== undefined && { currentBalance: parseFloat(String(currentBalance)) }),
        ...(openingBalance !== undefined && { openingBalance: parseFloat(String(openingBalance)) }),
        ...(isActive !== undefined && { isActive }),
        ...(description !== undefined && { description }),
      },
    })

    return NextResponse.json(account)
  } catch (error) {
    console.error('[ACCOUNT] PUT error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params
    const accountId = parseInt(id)

    const existing = await db.account.findUnique({ where: { id: accountId } })
    if (!existing) {
      return NextResponse.json({ error: 'الحساب غير موجود' }, { status: 404 })
    }

    // Check if account has any transactions before deleting
    const debitTransactionCount = await db.businessTransaction.count({ where: { debitAccountId: accountId } })
    const creditTransactionCount = await db.businessTransaction.count({ where: { creditAccountId: accountId } })
    const bondCount = await db.bond.count({ where: { accountId } })
    const salaryCount = await db.salary.count({ where: { accountId } })
    const rentCount = await db.rent.count({ where: { accountId } })
    const salesInvoiceCount = await db.salesInvoice.count({ where: { accountId } })
    const purchaseInvoiceCount = await db.purchaseInvoice.count({ where: { accountId } })
    const shareholderTransactionCount = await db.shareholderTransaction.count({ where: { accountId } })

    const totalReferences =
      debitTransactionCount +
      creditTransactionCount +
      bondCount +
      salaryCount +
      rentCount +
      salesInvoiceCount +
      purchaseInvoiceCount +
      shareholderTransactionCount

    if (totalReferences > 0) {
      return NextResponse.json(
        { error: 'لا يمكن حذف هذا الحساب لأنه مرتبط بمعاملات (قيدود محاسبية، سندات، رواتب، إيجارات، فواتير، أو حركات شركاء). يمكنك تعطيله بدلاً من ذلك.' },
        { status: 400 }
      )
    }

    // Also check for child accounts
    const childCount = await db.account.count({ where: { parentId: accountId } })
    if (childCount > 0) {
      return NextResponse.json(
        { error: 'لا يمكن حذف هذا الحساب لأنه يحتوي على حسابات فرعية. قم بحذف أو نقل الحسابات الفرعية أولاً.' },
        { status: 400 }
      )
    }

    await db.account.delete({ where: { id: accountId } })
    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('[ACCOUNT] DELETE error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
