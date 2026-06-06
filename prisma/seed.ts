import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  console.log('🌱 بدء إنشاء البيانات التجريبية...')

  // 1. Create demo user (shop owner)
  const existingUser = await prisma.user.findFirst({ where: { phone: '57654321' } })
  let userId: string

  if (existingUser) {
    console.log('✅ المستخدم التجريبي موجود بالفعل')
    userId = existingUser.id
  } else {
    const user = await prisma.user.create({
      data: {
        name: 'صاحب المحل التجريبي',
        phone: '57654321',
        password: '123456',
        role: 'business',
        language: 'ar',
      }
    })
    userId = user.id
    console.log('✅ تم إنشاء المستخدم التجريبي')
  }

  // 2. Create business
  const existingBusiness = await prisma.business.findFirst({ where: { ownerId: userId } })
  let businessId: string

  if (existingBusiness) {
    console.log('✅ المحل التجريبي موجود بالفعل')
    businessId = existingBusiness.id
  } else {
    const business = await prisma.business.create({
      data: {
        ownerId: userId,
        name: 'محل الحرفي للسباكة والكهرباء',
        nameEn: 'Sana3i Plumbing & Electrical Shop',
        phone: '57654321',
        businessType: 'shop',
        category: 'سباكة وكهرباء',
        governorate: 'العاصمة',
        city: 'الشويخ',
        address: 'الشويخ الصناعية - شارع 5',
      }
    })
    businessId = business.id
    console.log('✅ تم إنشاء المحل التجريبي')
  }

  // 3. Create chart of accounts
  const existingAccounts = await prisma.account.count({ where: { businessId } })
  if (existingAccounts === 0) {
    const assets = await prisma.account.create({ data: { businessId, code: '1000', name: 'الأصول', nameEn: 'Assets', accountType: 'asset' } })
    const currentAssets = await prisma.account.create({ data: { businessId, code: '1100', name: 'الأصول المتداولة', nameEn: 'Current Assets', accountType: 'asset', parentId: assets.id } })
    await prisma.account.createMany({ data: [
      { businessId, code: '1110', name: 'الصندوق (النقدية)', nameEn: 'Cash', accountType: 'asset', parentId: currentAssets.id, currentBalance: 5000 },
      { businessId, code: '1120', name: 'البنك', nameEn: 'Bank', accountType: 'asset', parentId: currentAssets.id, currentBalance: 15000 },
      { businessId, code: '1130', name: 'المدينون (العملاء)', nameEn: 'Accounts Receivable', accountType: 'asset', parentId: currentAssets.id },
      { businessId, code: '1140', name: 'المخزون', nameEn: 'Inventory', accountType: 'asset', parentId: currentAssets.id, currentBalance: 8000 },
    ]})
    const fixedAssets = await prisma.account.create({ data: { businessId, code: '1200', name: 'الأصول الثابتة', nameEn: 'Fixed Assets', accountType: 'asset', parentId: assets.id } })
    await prisma.account.createMany({ data: [
      { businessId, code: '1210', name: 'المعدات والأجهزة', nameEn: 'Equipment', accountType: 'asset', parentId: fixedAssets.id },
      { businessId, code: '1220', name: 'الأثاث والتجهيزات', nameEn: 'Furniture & Fixtures', accountType: 'asset', parentId: fixedAssets.id },
    ]})

    const liabilities = await prisma.account.create({ data: { businessId, code: '2000', name: 'الخصوم', nameEn: 'Liabilities', accountType: 'liability' } })
    const currentLiab = await prisma.account.create({ data: { businessId, code: '2100', name: 'الخصوم المتداولة', nameEn: 'Current Liabilities', accountType: 'liability', parentId: liabilities.id } })
    await prisma.account.createMany({ data: [
      { businessId, code: '2110', name: 'الدائنون (الموردين)', nameEn: 'Accounts Payable', accountType: 'liability', parentId: currentLiab.id },
      { businessId, code: '2120', name: 'أوراق دفع', nameEn: 'Notes Payable', accountType: 'liability', parentId: currentLiab.id },
    ]})

    const equity = await prisma.account.create({ data: { businessId, code: '3000', name: 'حقوق الملكية', nameEn: 'Equity', accountType: 'equity' } })
    await prisma.account.createMany({ data: [
      { businessId, code: '3100', name: 'رأس المال', nameEn: 'Capital', accountType: 'equity', parentId: equity.id, currentBalance: 28000 },
      { businessId, code: '3200', name: 'الأرباح المحتجزة', nameEn: 'Retained Earnings', accountType: 'equity', parentId: equity.id },
    ]})

    const revenue = await prisma.account.create({ data: { businessId, code: '4000', name: 'الإيرادات', nameEn: 'Revenue', accountType: 'revenue' } })
    await prisma.account.createMany({ data: [
      { businessId, code: '4100', name: 'إيرادات المبيعات', nameEn: 'Sales Revenue', accountType: 'revenue', parentId: revenue.id },
      { businessId, code: '4200', name: 'إيرادات الخدمات', nameEn: 'Service Revenue', accountType: 'revenue', parentId: revenue.id },
      { businessId, code: '4300', name: 'إيرادات أخرى', nameEn: 'Other Revenue', accountType: 'revenue', parentId: revenue.id },
    ]})

    const expenses = await prisma.account.create({ data: { businessId, code: '5000', name: 'المصروفات', nameEn: 'Expenses', accountType: 'expense' } })
    await prisma.account.createMany({ data: [
      { businessId, code: '5100', name: 'تكلفة البضاعة المباعة', nameEn: 'Cost of Goods Sold', accountType: 'expense', parentId: expenses.id },
      { businessId, code: '5200', name: 'مصروفات الرواتب', nameEn: 'Salary Expenses', accountType: 'expense', parentId: expenses.id },
      { businessId, code: '5300', name: 'مصروفات الإيجار', nameEn: 'Rent Expenses', accountType: 'expense', parentId: expenses.id },
      { businessId, code: '5400', name: 'مصروفات الكهرباء والماء', nameEn: 'Utilities', accountType: 'expense', parentId: expenses.id },
      { businessId, code: '5500', name: 'مصروفات النقل', nameEn: 'Transportation', accountType: 'expense', parentId: expenses.id },
      { businessId, code: '5600', name: 'مصروفات الصيانة', nameEn: 'Maintenance', accountType: 'expense', parentId: expenses.id },
      { businessId, code: '5700', name: 'مصروفات إدارية', nameEn: 'Administrative', accountType: 'expense', parentId: expenses.id },
      { businessId, code: '5800', name: 'مصروفات تسويق', nameEn: 'Marketing', accountType: 'expense', parentId: expenses.id },
    ]})

    console.log('✅ تم إنشاء شجرة الحسابات (28 حساب)')
  } else {
    console.log('✅ شجرة الحسابات موجودة بالفعل')
  }

  // 4. Create product categories
  const existingCategories = await prisma.productCategory.count({ where: { businessId } })
  if (existingCategories === 0) {
    const plumbingCat = await prisma.productCategory.create({ data: { businessId, name: 'سباكة', nameEn: 'Plumbing', icon: '🔧', sortOrder: 1 } })
    const electricalCat = await prisma.productCategory.create({ data: { businessId, name: 'كهرباء', nameEn: 'Electrical', icon: '⚡', sortOrder: 2 } })
    const paintCat = await prisma.productCategory.create({ data: { businessId, name: 'دهان', nameEn: 'Painting', icon: '🎨', sortOrder: 3 } })
    const acCat = await prisma.productCategory.create({ data: { businessId, name: 'تكييف', nameEn: 'AC', icon: '❄️', sortOrder: 4 } })
    await prisma.productCategory.create({ data: { businessId, name: 'نجارة', nameEn: 'Carpentry', icon: '🪚', sortOrder: 5 } })
    await prisma.productCategory.create({ data: { businessId, name: 'تنظيف', nameEn: 'Cleaning', icon: '🧹', sortOrder: 6 } })
    await prisma.productCategory.create({ data: { businessId, name: 'بناء', nameEn: 'Building', icon: '🏗️', sortOrder: 7 } })
    await prisma.productCategory.createMany({ data: [
      { businessId, name: 'أنابيب', nameEn: 'Pipes', icon: '💧', parentId: plumbingCat.id, sortOrder: 1 },
      { businessId, name: 'صنابير', nameEn: 'Faucets', icon: '🚿', parentId: plumbingCat.id, sortOrder: 2 },
      { businessId, name: 'كابلات', nameEn: 'Cables', icon: '🔌', parentId: electricalCat.id, sortOrder: 1 },
      { businessId, name: 'مفاتيح', nameEn: 'Switches', icon: '💡', parentId: electricalCat.id, sortOrder: 2 },
    ]})
    console.log('✅ تم إنشاء فئات المنتجات (11 فئة)')
  }

  // 5. Create warehouses
  const existingWarehouses = await prisma.warehouse.count({ where: { businessId } })
  if (existingWarehouses === 0) {
    await prisma.warehouse.create({ data: { businessId, name: 'المستودع الرئيسي', nameEn: 'Main Warehouse', code: 'WH-001', address: 'المنطقة الصناعية - الشويخ', managerName: 'أحمد السالم', managerPhone: '+96598881234' } })
    await prisma.warehouse.create({ data: { businessId, name: 'مستودع الفرع', nameEn: 'Branch Warehouse', code: 'WH-002', address: 'الفروانية - منطقة 3', managerName: 'سعد الحربي', managerPhone: '+96598885678' } })
    console.log('✅ تم إنشاء المستودعات (2)')
  }

  // 6. Create suppliers
  const existingSuppliers = await prisma.supplier.count({ where: { businessId } })
  if (existingSuppliers === 0) {
    await prisma.supplier.create({ data: { businessId, name: 'شركة الأنابيب الكويتية', nameEn: 'Kuwait Pipes Co', phone: '+96522456677', email: 'info@kwpipes.com', contactPerson: 'خالد المطيري', contactPhone: '+96597771234', balance: 350, paymentTerms: 'خلال 30 يوم' } })
    await prisma.supplier.create({ data: { businessId, name: 'مؤسسة الكابلات', nameEn: 'Cables Establishment', phone: '+96522458899', email: 'sales@cableskw.com', contactPerson: 'عمر السيد', contactPhone: '+96597775678', balance: 480, paymentTerms: 'خلال 45 يوم' } })
    await prisma.supplier.create({ data: { businessId, name: 'مصنع الدهانات', nameEn: 'Paints Factory', phone: '+96522451122', email: 'info@paintskw.com', contactPerson: 'فهد العتيبي', contactPhone: '+96597779012', balance: 0, paymentTerms: 'نقدي' } })
    console.log('✅ تم إنشاء الموردين (3)')
  }

  // 7. Create employees
  const existingEmployees = await prisma.employee.count({ where: { businessId } })
  if (existingEmployees === 0) {
    await prisma.employee.createMany({ data: [
      { businessId, name: 'محمد عبدالله', nameEn: 'Mohammed Abdullah', phone: '+96598881111', position: 'مدير المبيعات', department: 'المبيعات', salary: 1200, joinDate: new Date('2023-01-15'), bankName: 'بنك الكويت الوطني', bankIban: 'KW81NBOK000000000000123456' },
      { businessId, name: 'أحمد حسن', nameEn: 'Ahmed Hassan', phone: '+96598882222', position: 'محاسب', department: 'المالية', salary: 900, joinDate: new Date('2023-03-01'), bankName: 'بنك الكويت الوطني', bankIban: 'KW81NBOK000000000000123457' },
      { businessId, name: 'سعاد الفهد', nameEn: 'Suad Alfahad', phone: '+96598883333', position: 'أمين مستودع', department: 'المخزون', salary: 650, joinDate: new Date('2023-06-15') },
      { businessId, name: 'عبدالرحمن صالح', nameEn: 'Abdulrahman Saleh', phone: '+96598884444', position: 'مندوب مبيعات', department: 'المبيعات', salary: 550, joinDate: new Date('2024-01-10') },
    ]})
    console.log('✅ تم إنشاء الموظفين (4)')
  }

  // 8. Create products
  const existingProducts = await prisma.product.count({ where: { businessId } })
  if (existingProducts === 0) {
    const plumbingCat = await prisma.productCategory.findFirst({ where: { businessId, name: 'سباكة' } })
    const electricalCat = await prisma.productCategory.findFirst({ where: { businessId, name: 'كهرباء' } })
    const paintCat = await prisma.productCategory.findFirst({ where: { businessId, name: 'دهان' } })
    const acCat = await prisma.productCategory.findFirst({ where: { businessId, name: 'تكييف' } })
    const supplier1 = await prisma.supplier.findFirst({ where: { businessId } })
    const supplier2 = await prisma.supplier.findMany({ where: { businessId } })
    const mainWarehouse = await prisma.warehouse.findFirst({ where: { businessId } })

    const productsData = [
      { businessId, name: 'أنبوب PVC 4 بوصة', nameEn: 'PVC Pipe 4 inch', sku: 'PLB-001', price: 2.5, costPrice: 1.8, stockQuantity: 200, lowStockThreshold: 20, categoryId: plumbingCat?.id, supplierId: supplier1?.id, unit: 'قطعة' },
      { businessId, name: 'صنبور مياه كروم', nameEn: 'Chrome Water Faucet', sku: 'PLB-002', price: 8.5, costPrice: 5.2, stockQuantity: 50, lowStockThreshold: 5, categoryId: plumbingCat?.id, supplierId: supplier1?.id, unit: 'قطعة' },
      { businessId, name: 'كابل كهربائي 2.5 مم', nameEn: 'Electric Cable 2.5mm', sku: 'ELC-001', price: 3.0, costPrice: 2.1, stockQuantity: 500, lowStockThreshold: 50, categoryId: electricalCat?.id, supplierId: supplier2[1]?.id, unit: 'متر' },
      { businessId, name: 'مفتاح كهربائي مزدوج', nameEn: 'Double Electric Switch', sku: 'ELC-002', price: 1.5, costPrice: 0.9, stockQuantity: 150, lowStockThreshold: 15, categoryId: electricalCat?.id, supplierId: supplier2[1]?.id, unit: 'قطعة' },
      { businessId, name: 'دهان جص أبيض 20 كجم', nameEn: 'White Gypsum Paint 20kg', sku: 'PNT-001', price: 6.0, costPrice: 4.0, stockQuantity: 80, lowStockThreshold: 10, categoryId: paintCat?.id, unit: 'جالون' },
      { businessId, name: 'دهان بلاستيك أبيض 18 لتر', nameEn: 'White Plastic Paint 18L', sku: 'PNT-002', price: 12.0, costPrice: 8.5, stockQuantity: 40, lowStockThreshold: 5, categoryId: paintCat?.id, unit: 'جالون' },
      { businessId, name: 'وحدة تكييف سبليت 1.5 طن', nameEn: 'Split AC Unit 1.5 Ton', sku: 'AC-001', price: 280.0, costPrice: 220.0, stockQuantity: 10, lowStockThreshold: 2, categoryId: acCat?.id, unit: 'وحدة' },
      { businessId, name: 'فلتر تكييف قابل للغسيل', nameEn: 'Washable AC Filter', sku: 'AC-002', price: 3.5, costPrice: 1.5, stockQuantity: 100, lowStockThreshold: 10, categoryId: acCat?.id, unit: 'قطعة' },
    ]

    for (const p of productsData) {
      const product = await prisma.product.create({
        data: { ...p, categoryId: p.categoryId || undefined, supplierId: p.supplierId || undefined }
      })
      if (mainWarehouse) {
        await prisma.warehouseProduct.create({
          data: { warehouseId: mainWarehouse.id, productId: product.id, quantity: p.stockQuantity, minQuantity: p.lowStockThreshold }
        })
      }
    }
    console.log('✅ تم إنشاء المنتجات (8)')
  }

  // 9. Create business clients
  const existingClients = await prisma.businessClient.count({ where: { businessId } })
  if (existingClients === 0) {
    await prisma.businessClient.createMany({ data: [
      { businessId, name: 'عبدالله الشمري', phone: '+96596661111', email: 'abdullah@gmail.com', address: 'الجهراء - منطقة 5', totalPurchases: 450, totalPaid: 350, balance: 100 },
      { businessId, name: 'فاطمة الحسيني', phone: '+96596662222', email: 'fatima@gmail.com', address: 'السالمية - شارع 12', totalPurchases: 280, totalPaid: 280, balance: 0 },
      { businessId, name: 'سالم الدوسري', phone: '+96596663333', address: 'الفروانية - قطعة 7', totalPurchases: 120, totalPaid: 50, balance: 70 },
      { businessId, name: 'نورة العنزي', phone: '+96596664444', email: 'noura@gmail.com', address: 'حولي - شارع بن خلدون', totalPurchases: 600, totalPaid: 600, balance: 0 },
      { businessId, name: 'يوسف الغانم', phone: '+96596665555', address: 'مدينة جابر العلي - قطعة 3', totalPurchases: 320, totalPaid: 200, balance: 120 },
    ]})
    console.log('✅ تم إنشاء العملاء (5)')
  }

  // 10. Create sample rents (with payments for ledger)
  const existingRents = await prisma.rent.count({ where: { businessId } })
  if (existingRents === 0) {
    const bankAccount = await prisma.account.findFirst({ where: { businessId, code: '1120' } })
    const cashAccount = await prisma.account.findFirst({ where: { businessId, code: '1110' } })

    const now = new Date()
    const currentMonth = now.getMonth() + 1
    const currentYear = now.getFullYear()
    const prevMonth = currentMonth === 1 ? 12 : currentMonth - 1
    const prevYear = currentMonth === 1 ? currentYear - 1 : currentYear

    await prisma.rent.create({ data: {
      businessId, propertyOwner: 'مؤسسة العقارات الكويتية', propertyDesc: 'محل تجاري - الشويخ الصناعية - شارع 5', amount: 200, dueDay: 1, startDate: new Date('2024-01-01'), endDate: new Date('2025-12-31'), accountId: bankAccount?.id, notes: 'عقد إيجار سنوي - قابل للتجديد', paymentMethod: 'bank', paymentDate: new Date(currentYear, currentMonth - 1, 1),
    }})
    await prisma.rent.create({ data: {
      businessId, propertyOwner: 'أحمد الفهد', propertyDesc: 'مستودع - الفروانية - قطعة 7', amount: 75, dueDay: 5, startDate: new Date('2024-06-01'), endDate: new Date('2025-05-31'), accountId: cashAccount?.id, notes: 'مستودع إضافي للتخزين', paymentMethod: 'cash', paymentDate: new Date(prevYear, prevMonth - 1, 5),
    }})
    console.log('✅ تم إنشاء الإيجارات (2 مدفوعة)')
  }

  // 11. Create sample salaries (paid)
  const existingSalaries = await prisma.salary.count({ where: { businessId } })
  if (existingSalaries === 0) {
    const employees = await prisma.employee.findMany({ where: { businessId } })
    const bankAccount = await prisma.account.findFirst({ where: { businessId, code: '1120' } })
    const cashAccount = await prisma.account.findFirst({ where: { businessId, code: '1110' } })

    const now = new Date()
    const currentMonth = now.getMonth() + 1
    const currentYear = now.getFullYear()

    for (const emp of employees) {
      // Create salary for current month
      const netSalary = emp.salary
      await prisma.salary.create({
        data: {
          businessId,
          employeeId: emp.id,
          month: currentMonth,
          year: currentYear,
          basicSalary: emp.salary,
          allowances: 0,
          deductions: 0,
          netSalary,
          status: 'paid',
          paidDate: new Date(currentYear, currentMonth - 1, 28),
          paymentMethod: 'bank',
          accountId: bankAccount?.id,
        }
      })
      // Create salary for previous month
      const prevMonth = currentMonth === 1 ? 12 : currentMonth - 1
      const prevYear = currentMonth === 1 ? currentYear - 1 : currentYear
      await prisma.salary.create({
        data: {
          businessId,
          employeeId: emp.id,
          month: prevMonth,
          year: prevYear,
          basicSalary: emp.salary,
          allowances: 0,
          deductions: 0,
          netSalary,
          status: 'paid',
          paidDate: new Date(prevYear, prevMonth - 1, 28),
          paymentMethod: 'bank',
          accountId: bankAccount?.id,
        }
      })
    }
    console.log(`✅ تم إنشاء الرواتب (${employees.length * 2} سجل)`)
  }

  // 12. Create sample invoices
  const existingSalesInvoices = await prisma.salesInvoice.count({ where: { businessId } })
  if (existingSalesInvoices === 0) {
    const clients = await prisma.businessClient.findMany({ where: { businessId } })
    const products = await prisma.product.findMany({ where: { businessId } })
    const cashAccount = await prisma.account.findFirst({ where: { businessId, code: '1110' } })
    const bankAccount = await prisma.account.findFirst({ where: { businessId, code: '1120' } })

    if (clients.length > 0 && products.length > 0) {
      // Sales invoice 1 - paid
      const inv1 = await prisma.salesInvoice.create({
        data: { businessId, invoiceNumber: 'SI-2025-001', clientId: clients[0].id, clientName: clients[0].name, clientPhone: clients[0].phone, subtotal: 25, discountAmount: 0, taxAmount: 0, total: 25, status: 'paid', paidAmount: 25, paymentMethod: 'cash', accountId: cashAccount?.id, issuedAt: new Date('2025-05-15') }
      })
      if (products[0]) await prisma.salesInvoiceItem.create({ data: { invoiceId: inv1.id, productId: products[0].id, description: products[0].name, quantity: 10, unitPrice: 2.5, total: 25 } })

      // Sales invoice 2 - unpaid
      const inv2 = await prisma.salesInvoice.create({
        data: { businessId, invoiceNumber: 'SI-2025-002', clientId: clients[2]?.id || clients[0].id, clientName: clients[2]?.name || clients[0].name, clientPhone: clients[2]?.phone || clients[0].phone, subtotal: 56, discountAmount: 0, taxAmount: 0, total: 56, status: 'unpaid', paidAmount: 0, dueDate: new Date('2025-06-30'), issuedAt: new Date('2025-05-20') }
      })
      if (products[2]) await prisma.salesInvoiceItem.create({ data: { invoiceId: inv2.id, productId: products[2].id, description: products[2].name, quantity: 10, unitPrice: 3.0, total: 30 } })
      if (products[1]) await prisma.salesInvoiceItem.create({ data: { invoiceId: inv2.id, productId: products[1].id, description: products[1].name, quantity: 3, unitPrice: 8.5, total: 25.5 } })

      // Sales invoice 3 - partial
      const inv3 = await prisma.salesInvoice.create({
        data: { businessId, invoiceNumber: 'SI-2025-003', clientId: clients[4]?.id || clients[0].id, clientName: clients[4]?.name || clients[0].name, clientPhone: clients[4]?.phone || clients[0].phone, subtotal: 320, discountAmount: 20, taxAmount: 0, total: 300, status: 'partial', paidAmount: 200, paymentMethod: 'bank', accountId: bankAccount?.id, dueDate: new Date('2025-07-15'), issuedAt: new Date('2025-06-01') }
      })
      if (products[6]) await prisma.salesInvoiceItem.create({ data: { invoiceId: inv3.id, productId: products[6].id, description: products[6].name, quantity: 1, unitPrice: 280, total: 280 } })

      console.log('✅ تم إنشاء فواتير المبيعات (3)')
    }
  }

  // 13. Create sample purchase invoices
  const existingPurchaseInvoices = await prisma.purchaseInvoice.count({ where: { businessId } })
  if (existingPurchaseInvoices === 0) {
    const suppliers = await prisma.supplier.findMany({ where: { businessId } })
    const products = await prisma.product.findMany({ where: { businessId } })
    const cashAccount = await prisma.account.findFirst({ where: { businessId, code: '1110' } })

    if (suppliers.length > 0) {
      const pInv1 = await prisma.purchaseInvoice.create({
        data: { businessId, invoiceNumber: 'PI-2025-001', supplierId: suppliers[0].id, supplierName: suppliers[0].name, supplierPhone: suppliers[0].phone, subtotal: 360, taxAmount: 0, total: 360, status: 'paid', paidAmount: 360, paymentMethod: 'cash', accountId: cashAccount?.id, issuedAt: new Date('2025-04-10') }
      })
      if (products[0]) await prisma.purchaseInvoiceItem.create({ data: { invoiceId: pInv1.id, productId: products[0].id, description: products[0].name, quantity: 200, unitPrice: 1.8, total: 360 } })

      const pInv2 = await prisma.purchaseInvoice.create({
        data: { businessId, invoiceNumber: 'PI-2025-002', supplierId: suppliers[1]?.id || suppliers[0].id, supplierName: suppliers[1]?.name || suppliers[0].name, subtotal: 1050, taxAmount: 0, total: 1050, status: 'unpaid', paidAmount: 0, dueDate: new Date('2025-06-15'), issuedAt: new Date('2025-05-01') }
      })
      if (products[2]) await prisma.purchaseInvoiceItem.create({ data: { invoiceId: pInv2.id, productId: products[2].id, description: products[2].name, quantity: 500, unitPrice: 2.1, total: 1050 } })

      console.log('✅ تم إنشاء فواتير الشراء (2)')
    }
  }

  // 14. Create sample bonds
  const existingBonds = await prisma.bond.count({ where: { businessId } })
  if (existingBonds === 0) {
    const cashAccount = await prisma.account.findFirst({ where: { businessId, code: '1110' } })
    const bankAccount = await prisma.account.findFirst({ where: { businessId, code: '1120' } })

    await prisma.bond.createMany({ data: [
      { businessId, bondNumber: 'RB-2025-001', bondType: 'receipt', amount: 350, accountId: cashAccount?.id, partyName: 'عبدالله الشمري', partyType: 'client', description: 'تحصيل مبلغ من العميل عبدالله الشمري', issuedDate: new Date('2025-05-15') },
      { businessId, bondNumber: 'RB-2025-002', bondType: 'receipt', amount: 280, accountId: bankAccount?.id, partyName: 'فاطمة الحسيني', partyType: 'client', description: 'تحويل بنكي من العميل فاطمة الحسيني', issuedDate: new Date('2025-05-18') },
      { businessId, bondNumber: 'PB-2025-001', bondType: 'payment', amount: 350, accountId: cashAccount?.id, partyName: 'شركة الأنابيب الكويتية', partyType: 'supplier', description: 'سداد مستحقات شركة الأنابيب الكويتية', issuedDate: new Date('2025-05-10') },
      { businessId, bondNumber: 'PB-2025-002', bondType: 'payment', amount: 200, accountId: bankAccount?.id, partyName: 'إيجار المحل - مايو', partyType: 'rent', description: 'سداد إيجار محل شهر مايو 2025', issuedDate: new Date('2025-05-01') },
    ]})
    console.log('✅ تم إنشاء السندات (4)')
  }

  // 15. Create sample transactions
  const existingTransactions = await prisma.businessTransaction.count({ where: { businessId } })
  if (existingTransactions === 0) {
    const cashAccount = await prisma.account.findFirst({ where: { businessId, code: '1110' } })
    const bankAccount = await prisma.account.findFirst({ where: { businessId, code: '1120' } })
    const salesRevenue = await prisma.account.findFirst({ where: { businessId, code: '4100' } })
    const rentExpense = await prisma.account.findFirst({ where: { businessId, code: '5300' } })
    const salaryExpense = await prisma.account.findFirst({ where: { businessId, code: '5200' } })
    const costOfGoods = await prisma.account.findFirst({ where: { businessId, code: '5100' } })

    await prisma.businessTransaction.createMany({ data: [
      { businessId, type: 'income', amount: 630, description: 'إيرادات مبيعات شهر مايو', category: 'مبيعات', debitAccountId: cashAccount?.id, creditAccountId: salesRevenue?.id, transactionDate: new Date('2025-05-31') },
      { businessId, type: 'expense', amount: 200, description: 'إيجار محل شهر مايو', category: 'إيجارات', debitAccountId: rentExpense?.id, creditAccountId: bankAccount?.id, transactionDate: new Date('2025-05-01') },
      { businessId, type: 'expense', amount: 3300, description: 'رواتب موظفين شهر مايو', category: 'رواتب', debitAccountId: salaryExpense?.id, creditAccountId: bankAccount?.id, transactionDate: new Date('2025-05-28') },
      { businessId, type: 'expense', amount: 360, description: 'مشتريات أنابيب PVC', category: 'مشتريات', debitAccountId: costOfGoods?.id, creditAccountId: cashAccount?.id, transactionDate: new Date('2025-04-10') },
    ]})
    console.log('✅ تم إنشاء المعاملات المالية (4)')
  }

  // 16. Create offers
  const existingOffers = await prisma.offer.count({ where: { businessId } })
  if (existingOffers === 0) {
    const products = await prisma.product.findMany({ where: { businessId } })
    await prisma.offer.createMany({ data: [
      { businessId, title: 'عرض الصيف - خصم على الدهانات', description: 'خصم 20% على جميع أنواع الدهانات', discountPercentage: 20, originalPrice: 12, offerPrice: 9.6, productId: products[4]?.id, isActive: true, startDate: new Date('2025-06-01'), endDate: new Date('2025-08-31') },
      { businessId, title: 'عرض التكييف الشامل', description: 'وحدة تكييف سبليت مع تركيب مجاني', discountPercentage: 10, originalPrice: 280, offerPrice: 252, productId: products[6]?.id, isActive: true, startDate: new Date('2025-05-01'), endDate: new Date('2025-07-31') },
    ]})
    console.log('✅ تم إنشاء العروض (2)')
  }

  console.log('')
  console.log('🎉 تم إنشاء جميع البيانات التجريبية بنجاح!')
  console.log('')
  console.log('🔑 بيانات تسجيل الدخول:')
  console.log('   الهاتف: 57654321')
  console.log('   كلمة المرور: 123456')
  console.log('   نوع الحساب: صاحب محل')
}

main()
  .catch((e) => {
    console.error('❌ خطأ في إنشاء البيانات:', e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
