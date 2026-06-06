import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'
import { logAudit } from '@/lib/audit'

const BACKUP_VERSION = '1.0.0'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const rawBusinessId = searchParams.get('businessId')

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId is required' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'Business not found' }, { status: 404 })
    }

    // Fetch all business data
    const [
      business,
      products,
      productCategories,
      warehouses,
      warehouseProducts,
      suppliers,
      employees,
      salaries,
      rents,
      accounts,
      transactions,
      salesInvoices,
      purchaseInvoices,
      salesReturns,
      purchaseReturns,
      bonds,
      expenses,
      businessClients,
      offers,
      productMovements,
      shareholders,
      shareholderTransactions,
      businessUsers,
      businessSummaries,
    ] = await Promise.all([
      db.business.findUnique({ where: { id: businessId } }),
      db.product.findMany({ where: { businessId } }),
      db.productCategory.findMany({ where: { businessId } }),
      db.warehouse.findMany({ where: { businessId } }),
      db.warehouseProduct.findMany({
        where: { warehouse: { businessId } },
      }),
      db.supplier.findMany({ where: { businessId } }),
      db.employee.findMany({ where: { businessId } }),
      db.salary.findMany({ where: { businessId } }),
      db.rent.findMany({ where: { businessId } }),
      db.account.findMany({ where: { businessId } }),
      db.businessTransaction.findMany({ where: { businessId } }),
      db.salesInvoice.findMany({
        where: { businessId },
        include: { items: true },
      }),
      db.purchaseInvoice.findMany({
        where: { businessId },
        include: { items: true },
      }),
      db.salesReturn.findMany({ where: { businessId } }),
      db.purchaseReturn.findMany({ where: { businessId } }),
      db.bond.findMany({ where: { businessId } }),
      db.expense.findMany({ where: { businessId } }),
      db.businessClient.findMany({ where: { businessId } }),
      db.offer.findMany({ where: { businessId } }),
      db.productMovement.findMany({ where: { businessId } }),
      db.shareholder.findMany({ where: { businessId } }),
      db.shareholderTransaction.findMany({ where: { businessId } }),
      db.businessUser.findMany({ where: { businessId } }),
      db.businessSummary.findMany({ where: { businessId } }),
    ])

    const backupData = {
      version: BACKUP_VERSION,
      exportedAt: new Date().toISOString(),
      business: {
        id: business?.id,
        name: business?.name,
        nameEn: business?.nameEn,
      },
      data: {
        business: business ? JSON.parse(JSON.stringify(business)) : null,
        products: JSON.parse(JSON.stringify(products)),
        productCategories: JSON.parse(JSON.stringify(productCategories)),
        warehouses: JSON.parse(JSON.stringify(warehouses)),
        warehouseProducts: JSON.parse(JSON.stringify(warehouseProducts)),
        suppliers: JSON.parse(JSON.stringify(suppliers)),
        employees: JSON.parse(JSON.stringify(employees)),
        salaries: JSON.parse(JSON.stringify(salaries)),
        rents: JSON.parse(JSON.stringify(rents)),
        accounts: JSON.parse(JSON.stringify(accounts)),
        transactions: JSON.parse(JSON.stringify(transactions)),
        salesInvoices: JSON.parse(JSON.stringify(salesInvoices)),
        purchaseInvoices: JSON.parse(JSON.stringify(purchaseInvoices)),
        salesReturns: JSON.parse(JSON.stringify(salesReturns)),
        purchaseReturns: JSON.parse(JSON.stringify(purchaseReturns)),
        bonds: JSON.parse(JSON.stringify(bonds)),
        expenses: JSON.parse(JSON.stringify(expenses)),
        businessClients: JSON.parse(JSON.stringify(businessClients)),
        offers: JSON.parse(JSON.stringify(offers)),
        productMovements: JSON.parse(JSON.stringify(productMovements)),
        shareholders: JSON.parse(JSON.stringify(shareholders)),
        shareholderTransactions: JSON.parse(JSON.stringify(shareholderTransactions)),
        businessUsers: JSON.parse(JSON.stringify(businessUsers)),
        businessSummaries: JSON.parse(JSON.stringify(businessSummaries)),
      },
      stats: {
        products: products.length,
        productCategories: productCategories.length,
        warehouses: warehouses.length,
        suppliers: suppliers.length,
        employees: employees.length,
        salaries: salaries.length,
        rents: rents.length,
        accounts: accounts.length,
        transactions: transactions.length,
        salesInvoices: salesInvoices.length,
        purchaseInvoices: purchaseInvoices.length,
        salesReturns: salesReturns.length,
        purchaseReturns: purchaseReturns.length,
        bonds: bonds.length,
        expenses: expenses.length,
        businessClients: businessClients.length,
        offers: offers.length,
        productMovements: productMovements.length,
        shareholders: shareholders.length,
        shareholderTransactions: shareholderTransactions.length,
      },
    }

    // Log the export action
    await logAudit({
      businessId,
      action: 'EXPORT',
      entity: 'Backup',
      changes: { after: { recordCount: Object.values(backupData.stats).reduce((a: number, b: unknown) => a + (b as number), 0) } },
    })

    const jsonStr = JSON.stringify(backupData, null, 2)

    return new NextResponse(jsonStr, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Content-Disposition': `attachment; filename="sana3i-backup-${business?.name || 'unknown'}-${new Date().toISOString().split('T')[0]}.json"`,
      },
    })
  } catch (error) {
    console.error('[BACKUP_EXPORT] Error:', error)
    return NextResponse.json({ error: 'Failed to export backup' }, { status: 500 })
  }
}
