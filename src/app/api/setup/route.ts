import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

/**
 * GET /api/setup - فحص حالة قاعدة البيانات
 * POST /api/setup - إنشاء المستخدم التجريبي + المحل + البيانات
 */
export async function GET() {
  try {
    // Check database connection
    await db.$queryRaw`SELECT 1`

    // Check if users table has data
    const userCount = await db.user.count()
    const businessCount = await db.business.count()

    return NextResponse.json({
      connected: true,
      hasUsers: userCount > 0,
      hasBusiness: businessCount > 0,
      userCount,
      businessCount,
      needsSetup: userCount === 0,
    })
  } catch (error: any) {
    console.error('[SETUP] Database check error:', error?.message)
    return NextResponse.json({
      connected: false,
      error: error?.message || 'فشل الاتصال بقاعدة البيانات',
      needsSetup: true,
    }, { status: 503 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { action } = body

    // Check database connection first
    try {
      await db.$queryRaw`SELECT 1`
    } catch (dbError: any) {
      return NextResponse.json({
        success: false,
        error: 'فشل الاتصال بقاعدة البيانات. تأكد من تعيين DATABASE_URL بشكل صحيح في متغيرات البيئة.',
        details: dbError?.message,
      }, { status: 503 })
    }

    if (action === 'seed' || action === 'full') {
      const results: Record<string, any> = {}

      // 1. Create demo user if not exists
      const existingUser = await db.user.findFirst({ where: { phone: '57654321' } })
      let userId: string

      if (existingUser) {
        userId = existingUser.id
        results.user = 'existing'
      } else {
        const user = await db.user.create({
          data: {
            name: 'صاحب المحل التجريبي',
            phone: '57654321',
            password: '123456',
            role: 'business',
            language: 'ar',
          }
        })
        userId = user.id
        results.user = 'created'
      }

      // 2. Create business if not exists
      const existingBusiness = await db.business.findFirst({ where: { ownerId: userId } })
      let businessId: string

      if (existingBusiness) {
        businessId = existingBusiness.id
        results.business = 'existing'
      } else {
        const business = await db.business.create({
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
        results.business = 'created'
      }

      // 3. Create chart of accounts
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

      // 4-9. Create categories, warehouses, suppliers, employees, products, clients
      const existingCategories = await db.productCategory.count({ where: { businessId } })
      if (existingCategories === 0) {
        const plumbingCat = await db.productCategory.create({ data: { businessId, name: 'سباكة', nameEn: 'Plumbing', icon: '🔧', sortOrder: 1 } })
        const electricalCat = await db.productCategory.create({ data: { businessId, name: 'كهرباء', nameEn: 'Electrical', icon: '⚡', sortOrder: 2 } })
        const paintCat = await db.productCategory.create({ data: { businessId, name: 'دهان', nameEn: 'Painting', icon: '🎨', sortOrder: 3 } })
        const acCat = await db.productCategory.create({ data: { businessId, name: 'تكييف', nameEn: 'AC', icon: '❄️', sortOrder: 4 } })
        await db.productCategory.create({ data: { businessId, name: 'نجارة', nameEn: 'Carpentry', icon: '🪚', sortOrder: 5 } })
        await db.productCategory.create({ data: { businessId, name: 'تنظيف', nameEn: 'Cleaning', icon: '🧹', sortOrder: 6 } })
        await db.productCategory.create({ data: { businessId, name: 'بناء', nameEn: 'Building', icon: '🏗️', sortOrder: 7 } })
        await db.productCategory.createMany({ data: [
          { businessId, name: 'أنابيب', nameEn: 'Pipes', icon: '💧', parentId: plumbingCat.id, sortOrder: 1 },
          { businessId, name: 'صنابير', nameEn: 'Faucets', icon: '🚿', parentId: plumbingCat.id, sortOrder: 2 },
          { businessId, name: 'كابلات', nameEn: 'Cables', icon: '🔌', parentId: electricalCat.id, sortOrder: 1 },
          { businessId, name: 'مفاتيح', nameEn: 'Switches', icon: '💡', parentId: electricalCat.id, sortOrder: 2 },
        ]})
      }

      const existingWarehouses = await db.warehouse.count({ where: { businessId } })
      if (existingWarehouses === 0) {
        await db.warehouse.create({ data: { businessId, name: 'المستودع الرئيسي', nameEn: 'Main Warehouse', code: 'WH-001', address: 'المنطقة الصناعية - الشويخ', managerName: 'أحمد السالم', managerPhone: '+96598881234' } })
        await db.warehouse.create({ data: { businessId, name: 'مستودع الفرع', nameEn: 'Branch Warehouse', code: 'WH-002', address: 'الفروانية - منطقة 3', managerName: 'سعد الحربي', managerPhone: '+96598885678' } })
      }

      const existingSuppliers = await db.supplier.count({ where: { businessId } })
      if (existingSuppliers === 0) {
        await db.supplier.create({ data: { businessId, name: 'شركة الأنابيب الكويتية', nameEn: 'Kuwait Pipes Co', phone: '+96522456677', email: 'info@kwpipes.com', contactPerson: 'خالد المطيري', contactPhone: '+96597771234', balance: 350, paymentTerms: 'خلال 30 يوم' } })
        await db.supplier.create({ data: { businessId, name: 'مؤسسة الكابلات', nameEn: 'Cables Establishment', phone: '+96522458899', email: 'sales@cableskw.com', contactPerson: 'عمر السيد', contactPhone: '+96597775678', balance: 480, paymentTerms: 'خلال 45 يوم' } })
        await db.supplier.create({ data: { businessId, name: 'مصنع الدهانات', nameEn: 'Paints Factory', phone: '+96522451122', email: 'info@paintskw.com', contactPerson: 'فهد العتيبي', contactPhone: '+96597779012', balance: 0, paymentTerms: 'نقدي' } })
      }

      const existingEmployees = await db.employee.count({ where: { businessId } })
      if (existingEmployees === 0) {
        await db.employee.createMany({ data: [
          { businessId, name: 'محمد عبدالله', nameEn: 'Mohammed Abdullah', phone: '+96598881111', position: 'مدير المبيعات', department: 'المبيعات', salary: 1200, joinDate: new Date('2023-01-15') },
          { businessId, name: 'أحمد حسن', nameEn: 'Ahmed Hassan', phone: '+96598882222', position: 'محاسب', department: 'المالية', salary: 900, joinDate: new Date('2023-03-01') },
          { businessId, name: 'سعاد الفهد', nameEn: 'Suad Alfahad', phone: '+96598883333', position: 'أمين مستودع', department: 'المخزون', salary: 650, joinDate: new Date('2023-06-15') },
          { businessId, name: 'عبدالرحمن صالح', nameEn: 'Abdulrahman Saleh', phone: '+96598884444', position: 'مندوب مبيعات', department: 'المبيعات', salary: 550, joinDate: new Date('2024-01-10') },
        ]})
      }

      const existingProducts = await db.product.count({ where: { businessId } })
      if (existingProducts === 0) {
        const plumbingCat = await db.productCategory.findFirst({ where: { businessId, name: 'سباكة' } })
        const electricalCat = await db.productCategory.findFirst({ where: { businessId, name: 'كهرباء' } })
        const paintCat = await db.productCategory.findFirst({ where: { businessId, name: 'دهان' } })
        const acCat = await db.productCategory.findFirst({ where: { businessId, name: 'تكييف' } })
        const supplier1 = await db.supplier.findFirst({ where: { businessId } })
        const allSuppliers = await db.supplier.findMany({ where: { businessId } })
        const mainWarehouse = await db.warehouse.findFirst({ where: { businessId } })

        const productsData = [
          { businessId, name: 'أنبوب PVC 4 بوصة', nameEn: 'PVC Pipe 4 inch', sku: 'PLB-001', price: 2.5, costPrice: 1.8, stockQuantity: 200, lowStockThreshold: 20, categoryId: plumbingCat?.id, supplierId: supplier1?.id, unit: 'قطعة' },
          { businessId, name: 'صنبور مياه كروم', nameEn: 'Chrome Water Faucet', sku: 'PLB-002', price: 8.5, costPrice: 5.2, stockQuantity: 50, lowStockThreshold: 5, categoryId: plumbingCat?.id, supplierId: supplier1?.id, unit: 'قطعة' },
          { businessId, name: 'كابل كهربائي 2.5 مم', nameEn: 'Electric Cable 2.5mm', sku: 'ELC-001', price: 3.0, costPrice: 2.1, stockQuantity: 500, lowStockThreshold: 50, categoryId: electricalCat?.id, supplierId: allSuppliers[1]?.id, unit: 'متر' },
          { businessId, name: 'مفتاح كهربائي مزدوج', nameEn: 'Double Electric Switch', sku: 'ELC-002', price: 1.5, costPrice: 0.9, stockQuantity: 150, lowStockThreshold: 15, categoryId: electricalCat?.id, supplierId: allSuppliers[1]?.id, unit: 'قطعة' },
          { businessId, name: 'دهان جص أبيض 20 كجم', nameEn: 'White Gypsum Paint 20kg', sku: 'PNT-001', price: 6.0, costPrice: 4.0, stockQuantity: 80, lowStockThreshold: 10, categoryId: paintCat?.id, unit: 'جالون' },
          { businessId, name: 'دهان بلاستيك أبيض 18 لتر', nameEn: 'White Plastic Paint 18L', sku: 'PNT-002', price: 12.0, costPrice: 8.5, stockQuantity: 40, lowStockThreshold: 5, categoryId: paintCat?.id, unit: 'جالون' },
          { businessId, name: 'وحدة تكييف سبليت 1.5 طن', nameEn: 'Split AC Unit 1.5 Ton', sku: 'AC-001', price: 280.0, costPrice: 220.0, stockQuantity: 10, lowStockThreshold: 2, categoryId: acCat?.id, unit: 'وحدة' },
          { businessId, name: 'فلتر تكييف قابل للغسيل', nameEn: 'Washable AC Filter', sku: 'AC-002', price: 3.5, costPrice: 1.5, stockQuantity: 100, lowStockThreshold: 10, categoryId: acCat?.id, unit: 'قطعة' },
        ]

        for (const p of productsData) {
          const product = await db.product.create({
            data: { ...p, categoryId: p.categoryId || undefined, supplierId: p.supplierId || undefined }
          })
          if (mainWarehouse) {
            await db.warehouseProduct.create({
              data: { warehouseId: mainWarehouse.id, productId: product.id, quantity: p.stockQuantity, minQuantity: p.lowStockThreshold }
            })
          }
        }
      }

      const existingClients = await db.businessClient.count({ where: { businessId } })
      if (existingClients === 0) {
        await db.businessClient.createMany({ data: [
          { businessId, name: 'عبدالله الشمري', phone: '+96596661111', email: 'abdullah@gmail.com', address: 'الجهراء - منطقة 5', totalPurchases: 450, totalPaid: 350, balance: 100 },
          { businessId, name: 'فاطمة الحسيني', phone: '+96596662222', email: 'fatima@gmail.com', address: 'السالمية - شارع 12', totalPurchases: 280, totalPaid: 280, balance: 0 },
          { businessId, name: 'سالم الدوسري', phone: '+96596663333', address: 'الفروانية - قطعة 7', totalPurchases: 120, totalPaid: 50, balance: 70 },
          { businessId, name: 'نورة العنزي', phone: '+96596664444', email: 'noura@gmail.com', address: 'حولي - شارع بن خلدون', totalPurchases: 600, totalPaid: 600, balance: 0 },
          { businessId, name: 'يوسف الغانم', phone: '+96596665555', address: 'مدينة جابر العلي - قطعة 3', totalPurchases: 320, totalPaid: 200, balance: 120 },
        ]})
      }

      return NextResponse.json({
        success: true,
        message: 'تم إعداد قاعدة البيانات وإنشاء البيانات التجريبية بنجاح',
        results,
        loginInfo: {
          phone: '57654321',
          password: '123456',
        }
      })
    }

    return NextResponse.json({ success: false, error: 'إجراء غير معروف' }, { status: 400 })

  } catch (error: any) {
    console.error('[SETUP] Error:', error)
    return NextResponse.json({
      success: false,
      error: 'فشل إعداد قاعدة البيانات',
      details: error?.message,
      hint: error?.message?.includes('does not exist')
        ? 'جداول قاعدة البيانات غير موجودة. يجب تشغيل: npx prisma db push'
        : undefined,
    }, { status: 500 })
  }
}
