const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const categories = [
    { name: 'كهرباء', nameEn: 'Electricity', icon: '⚡', type: 'shop', sortOrder: 10 },
    { name: 'أدوات صحية', nameEn: 'Plumbing Supplies', icon: '🚿', type: 'shop', sortOrder: 11 },
    { name: 'تكييف', nameEn: 'AC Supplies', icon: '❄️', type: 'shop', sortOrder: 12 },
    { name: 'أصباغ', nameEn: 'Paints', icon: '🎨', type: 'shop', sortOrder: 13 },
    { name: 'مواد بناء', nameEn: 'Building Materials', icon: '🧱', type: 'shop', sortOrder: 14 },
    { name: 'محلات تشطيب وديكورات', nameEn: 'Finishing & Decoration', icon: '🛋️', type: 'shop', sortOrder: 15 },
    { name: 'مقاولات بناء', nameEn: 'Construction Contracting', icon: '🏗️', type: 'contractor', sortOrder: 20 },
    { name: 'شركات', nameEn: 'Companies', icon: '🏢', type: 'company', sortOrder: 30 },
    { name: 'مقاولين', nameEn: 'Contractors', icon: '👷', type: 'contractor', sortOrder: 21 },
    { name: 'استشاريين', nameEn: 'Consultants', icon: '📐', type: 'consultant', sortOrder: 40 },
  ];

  for (const c of categories) {
    const exists = await prisma.category.findUnique({ where: { name: c.name } });
    if (!exists) {
      await prisma.category.create({ data: c });
      console.log(`✅ تمت إضافة الفئة: ${c.name}`);
    } else {
      console.log(`⏭️ الفئة موجودة مسبقاً: ${c.name}`);
    }
  }
  console.log('✅ تم تحضير فئات المحلات');
}

main()
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());
