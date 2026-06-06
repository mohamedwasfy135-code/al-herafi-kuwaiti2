import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    let businessId = body.businessId

    if (!businessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    // If the ID is a user ID (not a business ID), look up the business
    const business = await db.business.findFirst({ where: { ownerId: businessId } })
    if (business) {
      businessId = business.id
    } else {
      const directBusiness = await db.business.findUnique({ where: { id: businessId } })
      if (!directBusiness) {
        return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
      }
    }

    const results: Record<string, number> = {}

    // 1. Create default chart of accounts if not exists
    const existingAccounts = await db.account.count({ where: { businessId } })
    if (existingAccounts === 0) {
      const assets = await db.account.create({ data: { businessId, code: '1000', name: 'الأصول', accountType: 'asset' } })
      const currentAssets = await db.account.create({ data: { businessId, code: '1100', name: 'الأصول المتداولة', accountType: 'asset', parentId: assets.id } })
      await db.account.createMany({ data: [
        { businessId, code: '1110', name: 'الصندوق (النقدية)', accountType: 'asset', parentId: currentAssets.id, currentBalance: 5000 },
        { businessId, code: '1120', name: 'البنك', accountType: 'asset', parentId: currentAssets.id, currentBalance: 15000 },
        { businessId, code: '1130', name: 'المدينون (العملاء)', accountType: 'asset', parentId: currentAssets.id },
        { businessId, code: '1140', name: 'المخزون', accountType: 'asset', parentId: currentAssets.id, currentBalance: 8000 },
      ]})
      const fixedAssets = await db.account.create({ data: { businessId, code: '1200', name: 'الأصول الثابتة', accountType: 'asset', parentId: assets.id } })
      await db.account.createMany({ data: [
        { businessId, code: '1210', name: 'المعدات والأجهزة', accountType: 'asset', parentId: fixedAssets.id },
        { businessId, code: '1220', name: 'الأثاث والتجهيزات', accountType: 'asset', parentId: fixedAssets.id },
      ]})

      const liabilities = await db.account.create({ data: { businessId, code: '2000', name: 'الخصوم', accountType: 'liability' } })
      const currentLiab = await db.account.create({ data: { businessId, code: '2100', name: 'الخصوم المتداولة', accountType: 'liability', parentId: liabilities.id } })
      await db.account.createMany({ data: [
        { businessId, code: '2110', name: 'الدائنون (الموردين)', accountType: 'liability', parentId: currentLiab.id },
        { businessId, code: '2120', name: 'أوراق دفع', accountType: 'liability', parentId: currentLiab.id },
      ]})

      const equity = await db.account.create({ data: { businessId, code: '3000', name: 'حقوق الملكية', accountType: 'equity' } })
      await db.account.createMany({ data: [
        { businessId, code: '3100', name: 'رأس المال', accountType: 'equity', parentId: equity.id, currentBalance: 28000 },
        { businessId, code: '3200', name: 'الأرباح المحتجزة', accountType: 'equity', parentId: equity.id },
      ]})

      const revenue = await db.account.create({ data: { businessId, code: '4000', name: 'الإيرادات', accountType: 'revenue' } })
      await db.account.createMany({ data: [
        { businessId, code: '4100', name: 'إيرادات المبيعات', accountType: 'revenue', parentId: revenue.id },
        { businessId, code: '4200', name: 'إيرادات الخدمات', accountType: 'revenue', parentId: revenue.id },
        { businessId, code: '4300', name: 'إيرادات أخرى', accountType: 'revenue', parentId: revenue.id },
      ]})

      const expenses = await db.account.create({ data: { businessId, code: '5000', name: 'المصروفات', accountType: 'expense' } })
      await db.account.createMany({ data: [
        { businessId, code: '5100', name: 'تكلفة البضاعة المباعة', accountType: 'expense', parentId: expenses.id },
        { businessId, code: '5200', name: 'مصروفات الرواتب', accountType: 'expense', parentId: expenses.id },
        { businessId, code: '5300', name: 'مصروفات الإيجار', accountType: 'expense', parentId: expenses.id },
        { businessId, code: '5400', name: 'مصروفات الكهرباء والماء', accountType: 'expense', parentId: expenses.id },
        { businessId, code: '5500', name: 'مصروفات النقل', accountType: 'expense', parentId: expenses.id },
        { businessId, code: '5600', name: 'مصروفات الصيانة', accountType: 'expense', parentId: expenses.id },
        { businessId, code: '5700', name: 'مصروفات إدارية', accountType: 'expense', parentId: expenses.id },
        { businessId, code: '5800', name: 'مصروفات تسويق', accountType: 'expense', parentId: expenses.id },
      ]})

      results.accounts = 28
    } else {
      results.accounts = existingAccounts
    }

    // 2. Create product categories
    const existingCategories = await db.productCategory.count({ where: { businessId } })
    let plumbingCat: { id: number } | null = null
    let electricalCat: { id: number } | null = null
    let paintCat: { id: number } | null = null
    let acCat: { id: number } | null = null

    if (existingCategories === 0) {
      plumbingCat = await db.productCategory.create({ data: { businessId, name: 'سباكة', nameEn: 'Plumbing', icon: '🔧', sortOrder: 1 } })
      electricalCat = await db.productCategory.create({ data: { businessId, name: 'كهرباء', nameEn: 'Electrical', icon: '⚡', sortOrder: 2 } })
      paintCat = await db.productCategory.create({ data: { businessId, name: 'دهان', nameEn: 'Painting', icon: '🎨', sortOrder: 3 } })
      acCat = await db.productCategory.create({ data: { businessId, name: 'تكييف', nameEn: 'AC', icon: '❄️', sortOrder: 4 } })
      const carpentry = await db.productCategory.create({ data: { businessId, name: 'نجارة', nameEn: 'Carpentry', icon: '🪚', sortOrder: 5 } })
      const cleaning = await db.productCategory.create({ data: { businessId, name: 'تنظيف', nameEn: 'Cleaning', icon: '🧹', sortOrder: 6 } })
      const building = await db.productCategory.create({ data: { businessId, name: 'بناء', nameEn: 'Building', icon: '🏗️', sortOrder: 7 } })

      await db.productCategory.createMany({ data: [
        { businessId, name: 'أنابيب', nameEn: 'Pipes', icon: '💧', parentId: plumbingCat.id, sortOrder: 1 },
        { businessId, name: 'صنابير', nameEn: 'Faucets', icon: '🚿', parentId: plumbingCat.id, sortOrder: 2 },
        { businessId, name: 'كابلات', nameEn: 'Cables', icon: '🔌', parentId: electricalCat.id, sortOrder: 1 },
        { businessId, name: 'مفاتيح', nameEn: 'Switches', icon: '💡', parentId: electricalCat.id, sortOrder: 2 },
      ]})

      results.productCategories = 11
    } else {
      results.productCategories = existingCategories
      // Get existing category IDs for product creation
      const cats = await db.productCategory.findMany({ where: { businessId, parentId: null } })
      plumbingCat = cats.find(c => c.name === 'سباكة') || null
      electricalCat = cats.find(c => c.name === 'كهرباء') || null
      paintCat = cats.find(c => c.name === 'دهان') || null
      acCat = cats.find(c => c.name === 'تكييف') || null
    }

    // 3. Create warehouses
    const existingWarehouses = await db.warehouse.count({ where: { businessId } })
    let mainWarehouse: { id: number } | null = null
    if (existingWarehouses === 0) {
      mainWarehouse = await db.warehouse.create({ data: { businessId, name: 'المستودع الرئيسي', nameEn: 'Main Warehouse', code: 'WH-001', address: 'المنطقة الصناعية - الشويخ', managerName: 'أحمد السالم', managerPhone: '+96598881234' } })
      await db.warehouse.create({ data: { businessId, name: 'مستودع الفرع', nameEn: 'Branch Warehouse', code: 'WH-002', address: 'الفروانية - منطقة 3', managerName: 'سعد الحربي', managerPhone: '+96598885678' } })
      results.warehouses = 2
    } else {
      results.warehouses = existingWarehouses
      mainWarehouse = await db.warehouse.findFirst({ where: { businessId } })
    }

    // 4. Create suppliers
    const existingSuppliers = await db.supplier.count({ where: { businessId } })
    let supplier1: { id: number } | null = null
    let supplier2: { id: number } | null = null
    if (existingSuppliers === 0) {
      supplier1 = await db.supplier.create({ data: { businessId, name: 'شركة الأنابيب الكويتية', nameEn: 'Kuwait Pipes Co', phone: '+96522456677', email: 'info@kwpipes.com', contactPerson: 'خالد المطيري', contactPhone: '+96597771234', balance: 350, paymentTerms: 'خلال 30 يوم' } })
      supplier2 = await db.supplier.create({ data: { businessId, name: 'مؤسسة الكابلات', nameEn: 'Cables Establishment', phone: '+96522458899', email: 'sales@cableskw.com', contactPerson: 'عمر السيد', contactPhone: '+96597775678', balance: 480, paymentTerms: 'خلال 45 يوم' } })
      await db.supplier.create({ data: { businessId, name: 'مصنع الدهانات', nameEn: 'Paints Factory', phone: '+96522451122', email: 'info@paintskw.com', contactPerson: 'فهد العتيبي', contactPhone: '+96597779012', balance: 0, paymentTerms: 'نقدي' } })
      results.suppliers = 3
    } else {
      results.suppliers = existingSuppliers
      const sups = await db.supplier.findMany({ where: { businessId }, take: 2 })
      supplier1 = sups[0] || null
      supplier2 = sups[1] || null
    }

    // 5. Create employees
    const existingEmployees = await db.employee.count({ where: { businessId } })
    if (existingEmployees === 0) {
      await db.employee.createMany({ data: [
        { businessId, name: 'محمد عبدالله', nameEn: 'Mohammed Abdullah', phone: '+96598881111', position: 'مدير المبيعات', department: 'المبيعات', salary: 1200, joinDate: new Date('2023-01-15'), bankName: 'بنك الكويت الوطني', bankIban: 'KW81NBOK000000000000123456' },
        { businessId, name: 'أحمد حسن', nameEn: 'Ahmed Hassan', phone: '+96598882222', position: 'محاسب', department: 'المالية', salary: 900, joinDate: new Date('2023-03-01'), bankName: 'بنك الكويت الوطني', bankIban: 'KW81NBOK000000000000123457' },
        { businessId, name: 'سعاد الفهد', nameEn: 'Suad Alfahad', phone: '+96598883333', position: 'أمين مستودع', department: 'المخزون', salary: 650, joinDate: new Date('2023-06-15') },
        { businessId, name: 'عبدالرحمن صالح', nameEn: 'Abdulrahman Saleh', phone: '+96598884444', position: 'مندوب مبيعات', department: 'المبيعات', salary: 550, joinDate: new Date('2024-01-10') },
      ]})
      results.employees = 4
    } else {
      results.employees = existingEmployees
    }

    // 6. Create products
    const existingProducts = await db.product.count({ where: { businessId } })
    if (existingProducts === 0) {
      const productsData = [
        { businessId, name: 'أنبوب PVC 4 بوصة', nameEn: 'PVC Pipe 4 inch', sku: 'PLB-001', barcode: '628100100001', price: 2.5, costPrice: 1.8, stockQuantity: 200, lowStockThreshold: 20, categoryId: plumbingCat?.id, supplierId: supplier1?.id, unit: 'قطعة' },
        { businessId, name: 'صنبور مياه كروم', nameEn: 'Chrome Water Faucet', sku: 'PLB-002', barcode: '628100100002', price: 8.5, costPrice: 5.2, stockQuantity: 50, lowStockThreshold: 5, categoryId: plumbingCat?.id, supplierId: supplier1?.id, unit: 'قطعة' },
        { businessId, name: 'كابل كهربائي 2.5 مم', nameEn: 'Electric Cable 2.5mm', sku: 'ELC-001', barcode: '628100100003', price: 3.0, costPrice: 2.1, stockQuantity: 500, lowStockThreshold: 50, categoryId: electricalCat?.id, supplierId: supplier2?.id, unit: 'متر' },
        { businessId, name: 'مفتاح كهربائي مزدوج', nameEn: 'Double Electric Switch', sku: 'ELC-002', barcode: '628100100004', price: 1.5, costPrice: 0.9, stockQuantity: 150, lowStockThreshold: 15, categoryId: electricalCat?.id, supplierId: supplier2?.id, unit: 'قطعة' },
        { businessId, name: 'دهان جص أبيض 20 كجم', nameEn: 'White Gypsum Paint 20kg', sku: 'PNT-001', barcode: '628100100005', price: 6.0, costPrice: 4.0, stockQuantity: 80, lowStockThreshold: 10, categoryId: paintCat?.id, unit: 'جالون' },
        { businessId, name: 'دهان بلاستيك أبيض 18 لتر', nameEn: 'White Plastic Paint 18L', sku: 'PNT-002', barcode: '628100100006', price: 12.0, costPrice: 8.5, stockQuantity: 40, lowStockThreshold: 5, categoryId: paintCat?.id, unit: 'جالون' },
        { businessId, name: 'وحدة تكييف سبليت 1.5 طن', nameEn: 'Split AC Unit 1.5 Ton', sku: 'AC-001', barcode: '628100100007', price: 280.0, costPrice: 220.0, stockQuantity: 10, lowStockThreshold: 2, categoryId: acCat?.id, unit: 'وحدة' },
        { businessId, name: 'فلتر تكييف قابل للغسيل', nameEn: 'Washable AC Filter', sku: 'AC-002', barcode: '628100100008', price: 3.5, costPrice: 1.5, stockQuantity: 100, lowStockThreshold: 10, categoryId: acCat?.id, unit: 'قطعة' },
      ]

      for (const p of productsData) {
        const product = await db.product.create({
          data: {
            ...p,
            categoryId: p.categoryId || undefined,
            supplierId: p.supplierId || undefined,
          }
        })

        // Add product to warehouse if warehouse exists
        if (mainWarehouse) {
          await db.warehouseProduct.create({
            data: {
              warehouseId: mainWarehouse.id,
              productId: product.id,
              quantity: p.stockQuantity,
              minQuantity: p.lowStockThreshold,
            }
          })
        }
      }

      results.products = productsData.length
    } else {
      results.products = existingProducts
    }

    // 7. Create business clients
    const existingClients = await db.businessClient.count({ where: { businessId } })
    if (existingClients === 0) {
      await db.businessClient.createMany({ data: [
        { businessId, name: 'عبدالله الشمري', phone: '+96596661111', email: 'abdullah@gmail.com', address: 'الجهراء - منطقة 5', totalPurchases: 450, totalPaid: 350, balance: 100 },
        { businessId, name: 'فاطمة الحسيني', phone: '+96596662222', email: 'fatima@gmail.com', address: 'السالمية - شارع 12', totalPurchases: 280, totalPaid: 280, balance: 0 },
        { businessId, name: 'سالم الدوسري', phone: '+96596663333', address: 'الفروانية - قطعة 7', totalPurchases: 120, totalPaid: 50, balance: 70 },
        { businessId, name: 'نورة العنزي', phone: '+96596664444', email: 'noura@gmail.com', address: 'حولي - شارع بن خلدون', totalPurchases: 600, totalPaid: 600, balance: 0 },
        { businessId, name: 'يوسف الغانم', phone: '+96596665555', address: 'مدينة جابر العلي - قطعة 3', totalPurchases: 320, totalPaid: 200, balance: 120 },
      ]})
      results.clients = 5
    } else {
      results.clients = existingClients
    }

    // 8. Create sample invoices
    const existingSalesInvoices = await db.salesInvoice.count({ where: { businessId } })
    if (existingSalesInvoices === 0) {
      const clients = await db.businessClient.findMany({ where: { businessId } })
      const products = await db.product.findMany({ where: { businessId } })

      if (clients.length > 0 && products.length > 0) {
        // Sales invoice 1 - paid
        const inv1 = await db.salesInvoice.create({
          data: {
            businessId,
            invoiceNumber: 'SI-2025-001',
            clientId: clients[0].id,
            clientName: clients[0].name,
            clientPhone: clients[0].phone,
            subtotal: 25,
            discountAmount: 0,
            taxAmount: 0,
            total: 25,
            status: 'paid',
            paidAmount: 25,
            issuedAt: new Date('2025-05-15'),
          }
        })
        if (products[0]) {
          await db.salesInvoiceItem.create({
            data: {
              invoiceId: inv1.id,
              productId: products[0].id,
              description: products[0].name,
              quantity: 10,
              unitPrice: 2.5,
              total: 25,
            }
          })
        }

        // Sales invoice 2 - unpaid
        const inv2 = await db.salesInvoice.create({
          data: {
            businessId,
            invoiceNumber: 'SI-2025-002',
            clientId: clients[2]?.id || clients[0].id,
            clientName: clients[2]?.name || clients[0].name,
            clientPhone: clients[2]?.phone || clients[0].phone,
            subtotal: 56,
            discountAmount: 0,
            taxAmount: 0,
            total: 56,
            status: 'unpaid',
            paidAmount: 0,
            dueDate: new Date('2025-06-30'),
            issuedAt: new Date('2025-05-20'),
          }
        })
        if (products[2]) {
          await db.salesInvoiceItem.create({
            data: {
              invoiceId: inv2.id,
              productId: products[2].id,
              description: products[2].name,
              quantity: 10,
              unitPrice: 3.0,
              total: 30,
            }
          })
        }
        if (products[1]) {
          await db.salesInvoiceItem.create({
            data: {
              invoiceId: inv2.id,
              productId: products[1].id,
              description: products[1].name,
              quantity: 3,
              unitPrice: 8.5,
              total: 25.5,
            }
          })
        }

        // Sales invoice 3 - partial
        const inv3 = await db.salesInvoice.create({
          data: {
            businessId,
            invoiceNumber: 'SI-2025-003',
            clientId: clients[4]?.id || clients[0].id,
            clientName: clients[4]?.name || clients[0].name,
            clientPhone: clients[4]?.phone || clients[0].phone,
            subtotal: 320,
            discountAmount: 20,
            taxAmount: 0,
            total: 300,
            status: 'partial',
            paidAmount: 200,
            dueDate: new Date('2025-07-15'),
            issuedAt: new Date('2025-06-01'),
          }
        })
        if (products[6]) {
          await db.salesInvoiceItem.create({
            data: {
              invoiceId: inv3.id,
              productId: products[6].id,
              description: products[6].name,
              quantity: 1,
              unitPrice: 280,
              total: 280,
            }
          })
        }

        results.salesInvoices = 3
      }
    } else {
      results.salesInvoices = existingSalesInvoices
    }

    // 9. Create sample purchase invoices
    const existingPurchaseInvoices = await db.purchaseInvoice.count({ where: { businessId } })
    if (existingPurchaseInvoices === 0) {
      const suppliers = await db.supplier.findMany({ where: { businessId } })
      const products = await db.product.findMany({ where: { businessId } })

      if (suppliers.length > 0) {
        const pInv1 = await db.purchaseInvoice.create({
          data: {
            businessId,
            invoiceNumber: 'PI-2025-001',
            supplierId: suppliers[0].id,
            supplierName: suppliers[0].name,
            supplierPhone: suppliers[0].phone,
            subtotal: 360,
            taxAmount: 0,
            total: 360,
            status: 'paid',
            paidAmount: 360,
            issuedAt: new Date('2025-04-10'),
          }
        })
        if (products[0]) {
          await db.purchaseInvoiceItem.create({
            data: {
              invoiceId: pInv1.id,
              productId: products[0].id,
              description: products[0].name,
              quantity: 200,
              unitPrice: 1.8,
              total: 360,
            }
          })
        }

        const pInv2 = await db.purchaseInvoice.create({
          data: {
            businessId,
            invoiceNumber: 'PI-2025-002',
            supplierId: suppliers[1]?.id || suppliers[0].id,
            supplierName: suppliers[1]?.name || suppliers[0].name,
            subtotal: 1050,
            taxAmount: 0,
            total: 1050,
            status: 'unpaid',
            paidAmount: 0,
            dueDate: new Date('2025-06-15'),
            issuedAt: new Date('2025-05-01'),
          }
        })
        if (products[2]) {
          await db.purchaseInvoiceItem.create({
            data: {
              invoiceId: pInv2.id,
              productId: products[2].id,
              description: products[2].name,
              quantity: 500,
              unitPrice: 2.1,
              total: 1050,
            }
          })
        }

        results.purchaseInvoices = 2
      }
    } else {
      results.purchaseInvoices = existingPurchaseInvoices
    }

    // 10. Create sample bonds
    const existingBonds = await db.bond.count({ where: { businessId } })
    if (existingBonds === 0) {
      const cashAccount = await db.account.findFirst({ where: { businessId, code: '1110' } })
      const bankAccount = await db.account.findFirst({ where: { businessId, code: '1120' } })
      const salesRevenue = await db.account.findFirst({ where: { businessId, code: '4100' } })
      const rentExpense = await db.account.findFirst({ where: { businessId, code: '5300' } })

      await db.bond.createMany({ data: [
        {
          businessId,
          bondNumber: 'RB-2025-001',
          bondType: 'receipt',
          amount: 350,
          accountId: cashAccount?.id,
          partyName: 'عبدالله الشمري',
          partyType: 'client',
          description: 'تحصيل مبلغ من العميل عبدالله الشمري',
          issuedDate: new Date('2025-05-15'),
        },
        {
          businessId,
          bondNumber: 'RB-2025-002',
          bondType: 'receipt',
          amount: 280,
          accountId: bankAccount?.id,
          partyName: 'فاطمة الحسيني',
          partyType: 'client',
          description: 'تحويل بنكي من العميل فاطمة الحسيني',
          issuedDate: new Date('2025-05-18'),
        },
        {
          businessId,
          bondNumber: 'PB-2025-001',
          bondType: 'payment',
          amount: 350,
          accountId: cashAccount?.id,
          partyName: 'شركة الأنابيب الكويتية',
          partyType: 'supplier',
          description: 'سداد مستحقات شركة الأنابيب الكويتية',
          issuedDate: new Date('2025-05-10'),
        },
        {
          businessId,
          bondNumber: 'PB-2025-002',
          bondType: 'payment',
          amount: 200,
          accountId: bankAccount?.id,
          partyName: 'إيجار المحل - مايو',
          partyType: 'rent',
          description: 'سداد إيجار محل شهر مايو 2025',
          issuedDate: new Date('2025-05-01'),
        },
      ]})
      results.bonds = 4
    } else {
      results.bonds = existingBonds
    }

    // 11. Create sample rents
    const existingRents = await db.rent.count({ where: { businessId } })
    if (existingRents === 0) {
      const rentAccount = await db.account.findFirst({ where: { businessId, code: '5300' } })
      const bankAccount = await db.account.findFirst({ where: { businessId, code: '1120' } })

      await db.rent.createMany({ data: [
        {
          businessId,
          propertyOwner: 'مؤسسة العقارات الكويتية',
          propertyDesc: 'محل تجاري - الشويخ الصناعية - شارع 5',
          amount: 200,
          dueDay: 1,
          startDate: new Date('2024-01-01'),
          endDate: new Date('2025-12-31'),
          accountId: bankAccount?.id,
          notes: 'عقد إيجار سنوي - قابل للتجديد',
        },
        {
          businessId,
          propertyOwner: 'أحمد الفهد',
          propertyDesc: 'مستودع - الفروانية - قطعة 7',
          amount: 75,
          dueDay: 5,
          startDate: new Date('2024-06-01'),
          endDate: new Date('2025-05-31'),
          accountId: rentAccount?.id,
          notes: 'مستودع إضافي للتخزين',
        },
      ]})
      results.rents = 2
    } else {
      results.rents = existingRents
    }

    // 12. Create sample offers
    const existingOffers = await db.offer.count({ where: { businessId } })
    if (existingOffers === 0) {
      const products = await db.product.findMany({ where: { businessId } })
      await db.offer.createMany({ data: [
        {
          businessId,
          title: 'عرض الصيف - خصم على الدهانات',
          description: 'خصم 20% على جميع أنواع الدهانات لفترة محدودة',
          discountPercentage: 20,
          originalPrice: 12,
          offerPrice: 9.6,
          productId: products[4]?.id,
          isActive: true,
          startDate: new Date('2025-06-01'),
          endDate: new Date('2025-08-31'),
        },
        {
          businessId,
          title: 'عرض التكييف الشامل',
          description: 'وحدة تكييف سبليت مع تركيب مجاني',
          discountPercentage: 10,
          originalPrice: 280,
          offerPrice: 252,
          productId: products[6]?.id,
          isActive: true,
          startDate: new Date('2025-05-01'),
          endDate: new Date('2025-07-31'),
        },
        {
          businessId,
          title: 'عرض السباكة - أنابيب PVC',
          description: 'عرض خاص على أنابيب PVC - اشتري 100 احصل على 10 مجاناً',
          discountPercentage: 10,
          originalPrice: 2.5,
          offerPrice: 2.25,
          productId: products[0]?.id,
          isActive: false,
          startDate: new Date('2025-03-01'),
          endDate: new Date('2025-04-30'),
        },
      ]})
      results.offers = 3
    } else {
      results.offers = existingOffers
    }

    // 13. Create sample transactions
    const existingTransactions = await db.businessTransaction.count({ where: { businessId } })
    if (existingTransactions === 0) {
      const cashAccount = await db.account.findFirst({ where: { businessId, code: '1110' } })
      const salesRevenue = await db.account.findFirst({ where: { businessId, code: '4100' } })
      const rentExpense = await db.account.findFirst({ where: { businessId, code: '5300' } })
      const salaryExpense = await db.account.findFirst({ where: { businessId, code: '5200' } })
      const costOfGoods = await db.account.findFirst({ where: { businessId, code: '5100' } })
      const bankAccount = await db.account.findFirst({ where: { businessId, code: '1120' } })

      await db.businessTransaction.createMany({ data: [
        {
          businessId,
          type: 'income',
          amount: 630,
          description: 'إيرادات مبيعات شهر مايو',
          category: 'مبيعات',
          debitAccountId: cashAccount?.id,
          creditAccountId: salesRevenue?.id,
          transactionDate: new Date('2025-05-31'),
        },
        {
          businessId,
          type: 'expense',
          amount: 200,
          description: 'إيجار محل شهر مايو',
          category: 'إيجارات',
          debitAccountId: rentExpense?.id,
          creditAccountId: bankAccount?.id,
          transactionDate: new Date('2025-05-01'),
        },
        {
          businessId,
          type: 'expense',
          amount: 3300,
          description: 'رواتب موظفين شهر مايو',
          category: 'رواتب',
          debitAccountId: salaryExpense?.id,
          creditAccountId: bankAccount?.id,
          transactionDate: new Date('2025-05-28'),
        },
        {
          businessId,
          type: 'expense',
          amount: 360,
          description: 'مشتريات أنابيب PVC',
          category: 'مشتريات',
          debitAccountId: costOfGoods?.id,
          creditAccountId: cashAccount?.id,
          transactionDate: new Date('2025-04-10'),
        },
      ]})
      results.transactions = 4
    } else {
      results.transactions = existingTransactions
    }

    return NextResponse.json({
      success: true,
      message: 'تم إنشاء البيانات الاختبارية بنجاح',
      results,
    })
  } catch (error) {
    console.error('Seed error:', error)
    return NextResponse.json(
      { success: false, error: 'فشل إنشاء البيانات: ' + String(error) },
      { status: 500 }
    )
  }
}
