import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 بدء إضافة الفئات (الحرف والمحلات) المطلوبة...');

  const categoriesData = [
    // --- الحرف المطلوبة ---
    { name: 'فني صحي', icon: 'wrench', description: 'صيانة وإصلاح السباكة' },
    { name: 'فني كهربائي', icon: 'zap', description: 'صيانة وتمديدات الكهرباء' },
    { name: 'فني تكييف', icon: 'snowflake', description: 'صيانة وتركيب المكيفات' },
    { name: 'فني سيراميك', icon: 'grid', description: 'تركيب وصيانة السيراميك والبلاط' },
    { name: 'فني عازل', icon: 'shield', description: 'عزل الأسطح والمباني' },
    { name: 'فني كاميرات', icon: 'video', description: 'تركيب وصيانة كاميرات المراقبة' },
    { name: 'فني انترنت واعمال هاتف', icon: 'wifi', description: 'تمديدات الشبكات والهواتف' },
    { name: 'فني اتوميشن سيستم', icon: 'cpu', description: 'المنازل الذكية وأنظمة الأتمتة' },
    { name: 'اعمال تنظيف', icon: 'sparkles', description: 'تنظيف المنازل والمباني' },
    { name: 'فني صبغ', icon: 'paint-bucket', description: 'أعمال الدهان والصبغ' },
    { name: 'نقل عفش', icon: 'truck', description: 'نقل الأثاث والعفش' },
    { name: 'تنسيق حدائق', icon: 'tree', description: 'تصميم وصيانة الحدائق' },
    
    // --- اقتراحات لحرف إضافية شائعة (يمكنك حذفها من الكود إذا لم ترد) ---
    { name: 'فني نجارة', icon: 'hammer', description: 'أعمال النجارة والمطابخ والأبواب' },
    { name: 'فني حداد', icon: 'anvil', description: 'أعمال الحديد والأبواب والشبابيك' },
    { name: 'فني أجهزة منزلية', icon: 'appliance', description: 'صيانة الغسالات والثلاجات والأفران' },
    { name: 'مكافحة حشرات', icon: 'bug', description: 'رش ومكافحة الحشرات والقوارض' },

    // --- المحلات المطلوبة ---
    { name: 'محلات ادوات صحية', icon: 'store', description: 'بيع الأدوات الصحية ومستلزمات السباكة' },
    { name: 'محلات ادوات كهرباء', icon: 'store', description: 'بيع الأدوات الكهربائية والإضاءة' },
    { name: 'محلات مواد بناء', icon: 'store', description: 'بيع مواد البناء والأسمنت والحديد' },
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
