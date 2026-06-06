import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'

// POST /api/notifications/ai-report
// Body: { businessId, period: 'weekly' | 'monthly' }
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { businessId, period = 'weekly' } = body

    if (!businessId) {
      return NextResponse.json({ error: 'businessId is required' }, { status: 400 })
    }

    // Calculate date range based on period
    const now = new Date()
    const daysBack = period === 'monthly' ? 30 : 7
    const dateStart = new Date(now.getTime() - daysBack * 24 * 60 * 60 * 1000)

    // Fetch business info
    const business = await db.business.findUnique({
      where: { id: businessId },
      select: { name: true, nameEn: true },
    })

    // Aggregate data
    const [salesInvoices, purchaseInvoices, expenses, bonds, products, lowStockProducts, clients] = await Promise.all([
      db.salesInvoice.findMany({
        where: { businessId, createdAt: { gte: dateStart } },
        select: { total: true, paidAmount: true, status: true },
      }),
      db.purchaseInvoice.findMany({
        where: { businessId, createdAt: { gte: dateStart } },
        select: { total: true, paidAmount: true },
      }),
      db.expense.findMany({
        where: { businessId, expenseDate: { gte: dateStart } },
        select: { amount: true, category: true },
      }),
      db.bond.findMany({
        where: { businessId, issuedDate: { gte: dateStart } },
        select: { bondType: true, amount: true },
      }),
      db.product.count({ where: { businessId, isActive: true } }),
      db.product.findMany({
        where: { businessId, isActive: true, trackStock: true, stockQuantity: { lte: 5 } },
        select: { name: true, stockQuantity: true },
        take: 10,
      }),
      db.businessClient.count({ where: { businessId } }),
    ])

    const totalSales = salesInvoices.reduce((s, i) => s + i.total, 0)
    const totalPurchases = purchaseInvoices.reduce((s, i) => s + i.total, 0)
    const totalExpenses = expenses.reduce((s, e) => s + e.amount, 0)
    const invoiceCount = salesInvoices.length
    const productCount = products
    const lowStockCount = lowStockProducts.length
    const clientCount = clients
    const receiptBonds = bonds.filter(b => b.bondType === 'receipt').reduce((s, b) => s + b.amount, 0)
    const paymentBonds = bonds.filter(b => b.bondType === 'payment').reduce((s, b) => s + b.amount, 0)
    const netProfit = totalSales - totalPurchases - totalExpenses

    // Use z-ai-web-dev-sdk to generate AI insights
    let aiInsights = ''
    try {
      const zaiModule = await import('z-ai-web-dev-sdk')
      const ZAI = await zaiModule.default.create()
      const prompt = `أنت محلل مالي محترف متخصص في تحليل أعمال المحلات الكويتية. حلل البيانات التالية لمحل كويتي وأعطني تحليل شامل باللغة العربية:

1. ملخص الأداء المالي
2. نقاط القوة
3. نقاط الضعف
4. توصيات لتحسين المبيعات (3 توصيات عملية)
5. تنبيهات المخزون
6. توقعات الأداء للفترة القادمة

بيانات المحل (${period === 'weekly' ? 'أسبوعية' : 'شهرية'}):
- اسم المحل: ${business?.name || 'غير محدد'}
- إجمالي المبيعات: ${totalSales.toFixed(3)} د.ك
- إجمالي المشتريات: ${totalPurchases.toFixed(3)} د.ك
- إجمالي المصروفات: ${totalExpenses.toFixed(3)} د.ك
- صافي الربح: ${netProfit.toFixed(3)} د.ك
- عدد فواتير البيع: ${invoiceCount}
- عدد المنتجات: ${productCount}
- عدد العملاء: ${clientCount}
- سندات القبض: ${receiptBonds.toFixed(3)} د.ك
- سندات الصرف: ${paymentBonds.toFixed(3)} د.ك
- منتجات منخفضة المخزون: ${lowStockCount}
${lowStockProducts.length > 0 ? '- تفاصيل المخزون المنخفض: ' + lowStockProducts.map(p => `${p.name} (${p.stockQuantity} قطعة)`).join(', ') : ''}

اكتب التحليل بشكل منظم مع استخدام الإيموجي والتنسيق الواضح.`

      const result = await ZAI.chat.completions.create({
        model: 'deepseek-chat',
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.7,
        max_tokens: 2000,
      })

      aiInsights = result.choices?.[0]?.message?.content || 'لم يتم إنشاء التحليل'
    } catch (aiError) {
      console.error('AI report generation error:', aiError)
      // Fallback: generate a basic analysis without AI
      aiInsights = generateFallbackAnalysis({
        businessName: business?.name || 'المحل',
        totalSales,
        totalPurchases,
        totalExpenses,
        netProfit,
        invoiceCount,
        productCount,
        lowStockCount,
        period,
      })
    }

    // Store the notification log
    await db.notificationLog.create({
      data: {
        businessId,
        type: 'ai_analysis',
        channel: 'whatsapp',
        recipient: 'ai_report',
        title: period === 'weekly' ? 'تحليل ذكي أسبوعي' : 'تحليل ذكي شهري',
        message: aiInsights,
        status: 'sent',
        sentAt: new Date(),
      },
    })

    return NextResponse.json({
      success: true,
      period,
      insights: aiInsights,
      data: {
        totalSales,
        totalPurchases,
        totalExpenses,
        netProfit,
        invoiceCount,
        productCount,
        lowStockCount,
      },
    })
  } catch (error) {
    console.error('Error generating AI report:', error)
    return NextResponse.json({ error: 'Failed to generate AI report' }, { status: 500 })
  }
}

function generateFallbackAnalysis(data: {
  businessName: string
  totalSales: number
  totalPurchases: number
  totalExpenses: number
  netProfit: number
  invoiceCount: number
  productCount: number
  lowStockCount: number
  period: string
}): string {
  const periodLabel = data.period === 'weekly' ? 'الأسبوعي' : 'الشهري'
  const profitStatus = data.netProfit > 0 ? '📈 إيجابي' : data.netProfit < 0 ? '📉 سلبي' : '➡️ محايد'
  const profitMargin = data.totalSales > 0 ? ((data.netProfit / data.totalSales) * 100).toFixed(1) : '0'

  return `🤖 *تحليل ذكي ${periodLabel} - ${data.businessName}*

📊 *ملخص الأداء المالي:*
├ إجمالي المبيعات: ${data.totalSales.toFixed(3)} د.ك
├ إجمالي المشتريات: ${data.totalPurchases.toFixed(3)} د.ك
├ إجمالي المصروفات: ${data.totalExpenses.toFixed(3)} د.ك
├ صافي الربح: ${data.netProfit.toFixed(3)} د.ك
└ حالة الربح: ${profitStatus}

💪 *نقاط القوة:*
${data.invoiceCount > 0 ? '├ حجم مبيعات نشط مع ' + data.invoiceCount + ' فاتورة' : '├ لا توجد مبيعات مسجلة'}
${data.netProfit > 0 ? '├ تحقيق ربح صافي إيجابي' : '├ يجب مراجعة التكاليف'}
${data.productCount > 0 ? '├ محفظة منتجات متنوعة (' + data.productCount + ' منتج)' : ''}

⚠️ *نقاط الضعف:*
${data.lowStockCount > 0 ? '├ ' + data.lowStockCount + ' منتج منخفض المخزون يحتاج إعادة طلب' : '├ لا توجد تنبيهات مخزون'}
${data.netProfit < 0 ? '├ صافي ربح سلبي - يجب خفض المصروفات' : ''}
${data.totalExpenses > data.totalSales * 0.5 ? '├ نسبة المصروفات مرتفعة مقارنة بالمبيعات' : ''}

💡 *توصيات:*
├ مراجعة أسعار المنتجات لتحسين هامش الربح (${profitMargin}%)
├ التفاوض مع الموردين للحصول على أسعار أفضل
${data.lowStockCount > 0 ? '├ إعادة طلب المنتجات المنخفضة المخزون فوراً' : '├ الحفاظ على مستويات المخزون'}
└ تحسين استراتيجية التسويق لزيادة المبيعات

📦 *تنبيهات المخزون:* ${data.lowStockCount > 0 ? data.lowStockCount + ' منتج تحتاج اهتمام' : 'لا توجد تنبيهات'}

🔮 *التوقعات:*
بناءً على الأداء ${periodLabel}، نتوقع ${data.netProfit > 0 ? 'استمرار النمو مع التركيز على تقليل المصروفات' : 'الحاجة لمراجعة شاملة للهيكل التكاليفي'}

---
تحليل ذكي من الحرفي الكويتي 🇰🇼`
}
