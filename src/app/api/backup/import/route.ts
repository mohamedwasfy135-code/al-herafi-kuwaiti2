import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'
import { logAudit } from '@/lib/audit'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { businessId: rawBusinessId, data } = body

    if (!rawBusinessId || !data) {
      return NextResponse.json({ error: 'businessId and data are required' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'Business not found' }, { status: 404 })
    }

    // Verify the business exists
    const business = await db.business.findUnique({ where: { id: businessId } })
    if (!business) {
      return NextResponse.json({ error: 'Business not found' }, { status: 404 })
    }

    // Delete all existing business data in correct order (respecting foreign keys)
    await db.$transaction(async (tx) => {
      // Delete child records first
      await tx.salesInvoiceItem.deleteMany({
        where: { invoice: { businessId } },
      })
      await tx.purchaseInvoiceItem.deleteMany({
        where: { invoice: { businessId } },
      })
      await tx.warehouseProduct.deleteMany({
        where: { warehouse: { businessId } },
      })
      await tx.productMovement.deleteMany({ where: { businessId } })
      await tx.salesReturn.deleteMany({ where: { businessId } })
      await tx.purchaseReturn.deleteMany({ where: { businessId } })
      await tx.shareholderTransaction.deleteMany({ where: { businessId } })
      await tx.shareholder.deleteMany({ where: { businessId } })

      // Delete main records
      await tx.salary.deleteMany({ where: { businessId } })
      await tx.rent.deleteMany({ where: { businessId } })
      await tx.bond.deleteMany({ where: { businessId } })
      await tx.expense.deleteMany({ where: { businessId } })
      await tx.salesInvoice.deleteMany({ where: { businessId } })
      await tx.purchaseInvoice.deleteMany({ where: { businessId } })
      await tx.businessTransaction.deleteMany({ where: { businessId } })
      await tx.account.deleteMany({ where: { businessId } })
      await tx.offer.deleteMany({ where: { businessId } })
      await tx.businessClient.deleteMany({ where: { businessId } })
      await tx.businessUser.deleteMany({ where: { businessId } })
      await tx.businessSummary.deleteMany({ where: { businessId } })
      await tx.subscription.deleteMany({ where: { businessId } })
      await tx.cartItem.deleteMany({ where: { businessId } })

      // Delete products and their categories
      await tx.product.deleteMany({ where: { businessId } })
      await tx.productCategory.deleteMany({ where: { businessId } })
      await tx.warehouse.deleteMany({ where: { businessId } })
      await tx.supplier.deleteMany({ where: { businessId } })
      await tx.employee.deleteMany({ where: { businessId } })

      // Now insert imported data
      const d = data

      // Product Categories
      if (d.productCategories?.length) {
        for (const cat of d.productCategories) {
          await tx.productCategory.create({
            data: {
              id: cat.id,
              businessId: cat.businessId || businessId,
              name: cat.name,
              nameEn: cat.nameEn,
              parentId: cat.parentId,
              icon: cat.icon,
              sortOrder: cat.sortOrder || 0,
              isActive: cat.isActive ?? true,
            },
          })
        }
      }

      // Warehouses
      if (d.warehouses?.length) {
        for (const wh of d.warehouses) {
          await tx.warehouse.create({
            data: {
              id: wh.id,
              businessId: wh.businessId || businessId,
              name: wh.name,
              nameEn: wh.nameEn,
              code: wh.code,
              address: wh.address,
              managerName: wh.managerName,
              managerPhone: wh.managerPhone,
              isActive: wh.isActive ?? true,
            },
          })
        }
      }

      // Suppliers
      if (d.suppliers?.length) {
        for (const sup of d.suppliers) {
          await tx.supplier.create({
            data: {
              id: sup.id,
              businessId: sup.businessId || businessId,
              name: sup.name,
              nameEn: sup.nameEn,
              phone: sup.phone,
              email: sup.email,
              address: sup.address,
              contactPerson: sup.contactPerson,
              contactPhone: sup.contactPhone,
              balance: sup.balance || 0,
              paymentTerms: sup.paymentTerms,
              taxNumber: sup.taxNumber,
              notes: sup.notes,
              isActive: sup.isActive ?? true,
            },
          })
        }
      }

      // Employees
      if (d.employees?.length) {
        for (const emp of d.employees) {
          await tx.employee.create({
            data: {
              id: emp.id,
              businessId: emp.businessId || businessId,
              name: emp.name,
              nameEn: emp.nameEn,
              phone: emp.phone,
              email: emp.email,
              nationalId: emp.nationalId,
              position: emp.position,
              department: emp.department,
              salary: emp.salary || 0,
              joinDate: emp.joinDate,
              leaveDate: emp.leaveDate,
              bankName: emp.bankName,
              bankIban: emp.bankIban,
              address: emp.address,
              notes: emp.notes,
              isActive: emp.isActive ?? true,
            },
          })
        }
      }

      // Products
      if (d.products?.length) {
        for (const prod of d.products) {
          await tx.product.create({
            data: {
              id: prod.id,
              businessId: prod.businessId || businessId,
              name: prod.name,
              nameEn: prod.nameEn,
              description: prod.description,
              sku: prod.sku,
              barcode: prod.barcode,
              price: prod.price || 0,
              costPrice: prod.costPrice || 0,
              discountPrice: prod.discountPrice,
              stockQuantity: prod.stockQuantity || 0,
              lowStockThreshold: prod.lowStockThreshold || 5,
              trackStock: prod.trackStock ?? true,
              category: prod.category,
              categoryId: prod.categoryId,
              supplierId: prod.supplierId,
              unit: prod.unit,
              images: prod.images,
              isActive: prod.isActive ?? true,
              isFeatured: prod.isFeatured ?? false,
            },
          })
        }
      }

      // Warehouse Products
      if (d.warehouseProducts?.length) {
        for (const wp of d.warehouseProducts) {
          await tx.warehouseProduct.create({
            data: {
              id: wp.id,
              warehouseId: wp.warehouseId,
              productId: wp.productId,
              quantity: wp.quantity || 0,
              minQuantity: wp.minQuantity || 0,
              location: wp.location,
            },
          })
        }
      }

      // Accounts
      if (d.accounts?.length) {
        for (const acc of d.accounts) {
          await tx.account.create({
            data: {
              id: acc.id,
              businessId: acc.businessId || businessId,
              code: acc.code,
              name: acc.name,
              nameEn: acc.nameEn,
              accountType: acc.accountType,
              parentId: acc.parentId,
              currentBalance: acc.currentBalance || 0,
              openingBalance: acc.openingBalance || 0,
              isActive: acc.isActive ?? true,
              description: acc.description,
            },
          })
        }
      }

      // Business Clients
      if (d.businessClients?.length) {
        for (const cl of d.businessClients) {
          await tx.businessClient.create({
            data: {
              id: cl.id,
              businessId: cl.businessId || businessId,
              userId: cl.userId,
              name: cl.name,
              phone: cl.phone,
              email: cl.email,
              address: cl.address,
              totalPurchases: cl.totalPurchases || 0,
              totalPaid: cl.totalPaid || 0,
              balance: cl.balance || 0,
              notes: cl.notes,
            },
          })
        }
      }

      // Sales Invoices + Items
      if (d.salesInvoices?.length) {
        for (const inv of d.salesInvoices) {
          await tx.salesInvoice.create({
            data: {
              id: inv.id,
              businessId: inv.businessId || businessId,
              invoiceNumber: inv.invoiceNumber,
              clientId: inv.clientId,
              clientName: inv.clientName,
              clientPhone: inv.clientPhone,
              subtotal: inv.subtotal || 0,
              discountAmount: inv.discountAmount || 0,
              taxAmount: inv.taxAmount || 0,
              total: inv.total || 0,
              status: inv.status || 'draft',
              paidAmount: inv.paidAmount || 0,
              paymentMethod: inv.paymentMethod,
              paymentDate: inv.paymentDate,
              accountId: inv.accountId,
              dueDate: inv.dueDate,
              notes: inv.notes,
              issuedAt: inv.issuedAt,
              createdBy: inv.createdBy,
            },
          })
          // Insert items
          if (inv.items?.length) {
            for (const item of inv.items) {
              await tx.salesInvoiceItem.create({
                data: {
                  id: item.id,
                  invoiceId: inv.id,
                  productId: item.productId,
                  description: item.description,
                  quantity: item.quantity || 1,
                  unitPrice: item.unitPrice || 0,
                  discountAmount: item.discountAmount || 0,
                  total: item.total || 0,
                },
              })
            }
          }
        }
      }

      // Purchase Invoices + Items
      if (d.purchaseInvoices?.length) {
        for (const inv of d.purchaseInvoices) {
          await tx.purchaseInvoice.create({
            data: {
              id: inv.id,
              businessId: inv.businessId || businessId,
              invoiceNumber: inv.invoiceNumber,
              supplierId: inv.supplierId,
              supplierName: inv.supplierName,
              supplierPhone: inv.supplierPhone,
              subtotal: inv.subtotal || 0,
              taxAmount: inv.taxAmount || 0,
              total: inv.total || 0,
              status: inv.status || 'draft',
              paidAmount: inv.paidAmount || 0,
              paymentMethod: inv.paymentMethod,
              paymentDate: inv.paymentDate,
              accountId: inv.accountId,
              dueDate: inv.dueDate,
              notes: inv.notes,
              issuedAt: inv.issuedAt,
              createdBy: inv.createdBy,
            },
          })
          if (inv.items?.length) {
            for (const item of inv.items) {
              await tx.purchaseInvoiceItem.create({
                data: {
                  id: item.id,
                  invoiceId: inv.id,
                  productId: item.productId,
                  description: item.description,
                  quantity: item.quantity || 1,
                  unitPrice: item.unitPrice || 0,
                  total: item.total || 0,
                },
              })
            }
          }
        }
      }

      // Sales Returns
      if (d.salesReturns?.length) {
        for (const ret of d.salesReturns) {
          await tx.salesReturn.create({
            data: {
              id: ret.id,
              businessId: ret.businessId || businessId,
              originalInvoiceId: ret.originalInvoiceId,
              returnNumber: ret.returnNumber,
              clientName: ret.clientName,
              total: ret.total || 0,
              reason: ret.reason,
              status: ret.status || 'pending',
            },
          })
        }
      }

      // Purchase Returns
      if (d.purchaseReturns?.length) {
        for (const ret of d.purchaseReturns) {
          await tx.purchaseReturn.create({
            data: {
              id: ret.id,
              businessId: ret.businessId || businessId,
              originalInvoiceId: ret.originalInvoiceId,
              returnNumber: ret.returnNumber,
              supplierName: ret.supplierName,
              total: ret.total || 0,
              reason: ret.reason,
              status: ret.status || 'pending',
            },
          })
        }
      }

      // Bonds
      if (d.bonds?.length) {
        for (const bond of d.bonds) {
          await tx.bond.create({
            data: {
              id: bond.id,
              businessId: bond.businessId || businessId,
              bondNumber: bond.bondNumber,
              bondType: bond.bondType,
              amount: bond.amount,
              accountId: bond.accountId,
              partyName: bond.partyName,
              partyType: bond.partyType,
              description: bond.description,
              referenceType: bond.referenceType,
              referenceId: bond.referenceId,
              paymentMethod: bond.paymentMethod,
              issuedDate: bond.issuedDate,
              createdBy: bond.createdBy,
            },
          })
        }
      }

      // Expenses
      if (d.expenses?.length) {
        for (const exp of d.expenses) {
          await tx.expense.create({
            data: {
              id: exp.id,
              businessId: exp.businessId || businessId,
              category: exp.category,
              description: exp.description,
              amount: exp.amount,
              expenseDate: exp.expenseDate,
              receiptUrl: exp.receiptUrl,
              attachmentUrls: exp.attachmentUrls,
              isRecurring: exp.isRecurring ?? false,
              recurringPeriod: exp.recurringPeriod,
              createdBy: exp.createdBy,
            },
          })
        }
      }

      // Salaries
      if (d.salaries?.length) {
        for (const sal of d.salaries) {
          await tx.salary.create({
            data: {
              id: sal.id,
              businessId: sal.businessId || businessId,
              employeeId: sal.employeeId,
              month: sal.month,
              year: sal.year,
              basicSalary: sal.basicSalary || 0,
              allowances: sal.allowances || 0,
              deductions: sal.deductions || 0,
              netSalary: sal.netSalary || 0,
              status: sal.status || 'pending',
              paidDate: sal.paidDate,
              notes: sal.notes,
              accountId: sal.accountId,
            },
          })
        }
      }

      // Rents
      if (d.rents?.length) {
        for (const rent of d.rents) {
          await tx.rent.create({
            data: {
              id: rent.id,
              businessId: rent.businessId || businessId,
              propertyOwner: rent.propertyOwner,
              propertyDesc: rent.propertyDesc,
              amount: rent.amount || 0,
              dueDay: rent.dueDay || 1,
              startDate: rent.startDate,
              endDate: rent.endDate,
              accountId: rent.accountId,
              notes: rent.notes,
              isActive: rent.isActive ?? true,
            },
          })
        }
      }

      // Business Transactions
      if (d.transactions?.length) {
        for (const tr of d.transactions) {
          await tx.businessTransaction.create({
            data: {
              id: tr.id,
              businessId: tr.businessId || businessId,
              type: tr.type,
              amount: tr.amount,
              description: tr.description,
              category: tr.category,
              referenceType: tr.referenceType,
              referenceId: tr.referenceId,
              debitAccountId: tr.debitAccountId,
              creditAccountId: tr.creditAccountId,
              attachmentUrls: tr.attachmentUrls,
              isRecurring: tr.isRecurring ?? false,
              recurringPeriod: tr.recurringPeriod,
              tags: tr.tags,
              createdBy: tr.createdBy,
              transactionDate: tr.transactionDate,
            },
          })
        }
      }

      // Offers
      if (d.offers?.length) {
        for (const offer of d.offers) {
          await tx.offer.create({
            data: {
              id: offer.id,
              businessId: offer.businessId || businessId,
              title: offer.title,
              description: offer.description,
              discountPercentage: offer.discountPercentage,
              originalPrice: offer.originalPrice,
              offerPrice: offer.offerPrice,
              imageUrl: offer.imageUrl,
              productId: offer.productId,
              isActive: offer.isActive ?? true,
              startDate: offer.startDate,
              endDate: offer.endDate,
            },
          })
        }
      }

      // Product Movements
      if (d.productMovements?.length) {
        for (const pm of d.productMovements) {
          await tx.productMovement.create({
            data: {
              id: pm.id,
              productId: pm.productId,
              businessId: pm.businessId || businessId,
              warehouseId: pm.warehouseId,
              movementType: pm.movementType,
              quantity: pm.quantity,
              referenceType: pm.referenceType,
              referenceId: pm.referenceId,
              notes: pm.notes,
              createdBy: pm.createdBy,
            },
          })
        }
      }

      // Shareholders
      if (d.shareholders?.length) {
        for (const sh of d.shareholders) {
          await tx.shareholder.create({
            data: {
              id: sh.id,
              businessId: sh.businessId || businessId,
              name: sh.name,
              phone: sh.phone,
              email: sh.email,
              shareType: sh.shareType || 'share',
              shareCount: sh.shareCount || 1,
              shareValue: sh.shareValue || 0,
              totalValue: sh.totalValue || 0,
              percentage: sh.percentage || 0,
              joinDate: sh.joinDate,
              exitDate: sh.exitDate,
              isActive: sh.isActive ?? true,
              notes: sh.notes,
            },
          })
        }
      }

      // Shareholder Transactions
      if (d.shareholderTransactions?.length) {
        for (const st of d.shareholderTransactions) {
          await tx.shareholderTransaction.create({
            data: {
              id: st.id,
              businessId: st.businessId || businessId,
              shareholderId: st.shareholderId,
              transactionType: st.transactionType,
              amount: st.amount,
              shareCount: st.shareCount || 0,
              description: st.description,
              transactionDate: st.transactionDate,
              accountId: st.accountId,
              referenceType: st.referenceType,
              referenceId: st.referenceId,
              createdBy: st.createdBy,
            },
          })
        }
      }

      // Business Users
      if (d.businessUsers?.length) {
        for (const bu of d.businessUsers) {
          await tx.businessUser.create({
            data: {
              id: bu.id,
              businessId: bu.businessId || businessId,
              userId: bu.userId,
              name: bu.name,
              phone: bu.phone,
              email: bu.email,
              password: bu.password || '123456',
              role: bu.role || 'seller',
              permissions: bu.permissions,
              isActive: bu.isActive ?? true,
            },
          })
        }
      }

      // Business Summaries
      if (d.businessSummaries?.length) {
        for (const bs of d.businessSummaries) {
          await tx.businessSummary.create({
            data: {
              id: bs.id,
              businessId: bs.businessId || businessId,
              totalIncome: bs.totalIncome || 0,
              totalExpenses: bs.totalExpenses || 0,
              totalPurchases: bs.totalPurchases || 0,
              totalCommission: bs.totalCommission || 0,
              netProfit: bs.netProfit || 0,
              transactionCount: bs.transactionCount || 0,
              monthlyData: bs.monthlyData,
            },
          })
        }
      }
    })

    // Log the import action
    const totalRecords = Object.values(data.stats || {}).reduce((a: number, b: unknown) => a + (b as number), 0)
    await logAudit({
      businessId,
      action: 'IMPORT',
      entity: 'Backup',
      changes: { after: { recordCount: totalRecords } },
    })

    return NextResponse.json({
      success: true,
      message: 'Backup imported successfully',
      recordsImported: totalRecords || 0,
    })
  } catch (error) {
    console.error('[BACKUP_IMPORT] Error:', error)
    return NextResponse.json({
      error: 'Failed to import backup',
      details: error instanceof Error ? error.message : String(error),
    }, { status: 500 })
  }
}
