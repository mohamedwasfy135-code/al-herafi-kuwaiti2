import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 بدء إضافة الفئات (الحرف والمحلات) المطلوبة...');

  const categoriesData = [
    { name: 'فني صحي', icon: 'wrench', type: 'service' },
    { name: 'فني كهربائي', icon: 'zap', type: 'service' },
    { name: 'فني تكييف', icon: 'snowflake', type: 'service' },
    { name: 'فني سيراميك', icon: 'grid', type: 'service' },
    { name: 'فني عازل', icon: 'shield', type: 'service' },
    { name: 'فني كاميرات', icon: 'video', type: 'service' },
    { name: 'فني انترنت واعمال هاتف', icon: 'wifi', type: 'service' },
    { name: 'فني اتوميشن سيستم', icon: 'cpu', type: 'service' },
    { name: 'اعمال تنظيف', icon: 'sparkles', type: 'service' },
    { name: 'فني صبغ', icon: 'paint-bucket', type: 'service' },
    { name: 'نقل عفش', icon: 'truck', type: 'service' },
    { name: 'تنسيق حدائق', icon: 'tree', type: 'service' },
    { name: 'فني نجارة', icon: 'hammer', type: 'service' },
    { name: 'فني حداد', icon: 'anvil', type: 'service' },
    { name: 'فني أجهزة منزلية', icon: 'appliance', type: 'service' },
    { name: 'مكافحة حشرات', icon: 'bug', type: 'service' },
    { name: 'محلات ادوات صحية', icon: 'store', type: 'business' },
    { name: 'محلات ادوات كهرباء', icon: 'store', type: 'business' },
    { name: 'محلات مواد بناء', icon: 'store', type: 'business' },
  ];

  for (const cat of categoriesData) {
    await prisma.category.upsert({
      where: { name: cat.name },
      update: {},
      create: cat,
    });
  }

  console.log(`✅ تم إضافة ${categoriesData.length} فئة بنجاح.`);
  console.log('🎉 اكتملت العملية! النظام جاهز الآن.');
}

main()
  .catch((e) => {
    console.error('❌ خطأ:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
