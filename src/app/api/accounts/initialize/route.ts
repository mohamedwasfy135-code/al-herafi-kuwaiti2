import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'

interface AccountTreeNode {
  code: string
  name: string
  accountType: string
  children?: AccountTreeNode[]
}

const defaultAccounts: AccountTreeNode[] = [
  // أصول - Assets
  { code: '1000', name: 'الأصول', accountType: 'asset', children: [
    { code: '1100', name: 'الأصول المتداولة', accountType: 'asset', children: [
      { code: '1110', name: 'الصندوق (النقدية)', accountType: 'asset' },
      { code: '1120', name: 'البنك', accountType: 'asset' },
      { code: '1130', name: 'المدينون (العملاء)', accountType: 'asset' },
      { code: '1140', name: 'المخزون', accountType: 'asset' },
      { code: '1150', name: 'أوراق قبض', accountType: 'asset' },
    ]},
    { code: '1200', name: 'الأصول الثابتة', accountType: 'asset', children: [
      { code: '1210', name: 'المعدات والأجهزة', accountType: 'asset' },
      { code: '1220', name: 'الأثاث والتجهيزات', accountType: 'asset' },
      { code: '1230', name: 'المركبات', accountType: 'asset' },
    ]},
  ]},
  // خصوم - Liabilities
  { code: '2000', name: 'الخصوم', accountType: 'liability', children: [
    { code: '2100', name: 'الخصوم المتداولة', accountType: 'liability', children: [
      { code: '2110', name: 'الدائنون (الموردين)', accountType: 'liability' },
      { code: '2120', name: 'أوراق دفع', accountType: 'liability' },
      { code: '2130', name: 'مصروفات مستحقة', accountType: 'liability' },
    ]},
  ]},
  // حقوق ملكية - Equity
  { code: '3000', name: 'حقوق الملكية', accountType: 'equity', children: [
    { code: '3100', name: 'رأس المال', accountType: 'equity' },
    { code: '3200', name: 'الأرباح المحتجزة', accountType: 'equity' },
    { code: '3300', name: 'أرباح العام الحالي', accountType: 'equity' },
  ]},
  // إيرادات - Revenue
  { code: '4000', name: 'الإيرادات', accountType: 'revenue', children: [
    { code: '4100', name: 'إيرادات المبيعات', accountType: 'revenue' },
    { code: '4200', name: 'إيرادات الخدمات', accountType: 'revenue' },
    { code: '4300', name: 'إيرادات أخرى', accountType: 'revenue' },
    { code: '4400', name: 'مرتجعات المبيعات', accountType: 'revenue' },
  ]},
  // مصروفات - Expenses
  { code: '5000', name: 'المصروفات', accountType: 'expense', children: [
    { code: '5100', name: 'تكلفة البضاعة المباعة', accountType: 'expense' },
    { code: '5200', name: 'مصروفات الرواتب', accountType: 'expense' },
    { code: '5300', name: 'مصروفات الإيجار', accountType: 'expense' },
    { code: '5400', name: 'مصروفات الكهرباء والماء', accountType: 'expense' },
    { code: '5500', name: 'مصروفات النقل', accountType: 'expense' },
    { code: '5600', name: 'مصروفات الصيانة', accountType: 'expense' },
    { code: '5700', name: 'مصروفات إدارية', accountType: 'expense' },
    { code: '5800', name: 'مصروفات تسويق', accountType: 'expense' },
    { code: '5900', name: 'مصروفات أخرى', accountType: 'expense' },
  ]},
]

async function createAccountTree(
  businessId: string,
  accounts: AccountTreeNode[],
  parentId: number | null = null
): Promise<number> {
  let count = 0
  for (const acct of accounts) {
    const created = await db.account.create({
      data: {
        businessId,
        code: acct.code,
        name: acct.name,
        accountType: acct.accountType,
        parentId,
        currentBalance: 0,
        openingBalance: 0,
      },
    })
    count++
    if ('children' in acct && acct.children) {
      count += await createAccountTree(businessId, acct.children, created.id)
    }
  }
  return count
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { businessId: rawBusinessId } = body

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    // Check if accounts already exist
    const existingCount = await db.account.count({
      where: { businessId },
    })

    if (existingCount > 0) {
      return NextResponse.json({
        message: 'توجد حسابات بالفعل',
        count: existingCount,
      })
    }

    const count = await createAccountTree(businessId, defaultAccounts)

    return NextResponse.json({
      success: true,
      message: `تم إنشاء ${count} حساب بنجاح`,
      count,
    })
  } catch (error) {
    console.error('[ACCOUNTS_INITIALIZE] POST error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
