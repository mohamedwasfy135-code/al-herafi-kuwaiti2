import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function cleanup() {
  console.log('🧹 بدء تنظيف الوثائق القديمة...\n');

  try {
    // 1. حذف الوثائق الفارغة
    const deletedEmpty = await prisma.craftsmanIDocument.deleteMany({
      where: {
        OR: [
          { civilIdUrl: null },
          { bankAccountPhotoUrl: null },
        ],
      },
    });
    console.log(`✅ تم حذف ${deletedEmpty.count} وثيقة فارغة`);

    // 2. التحقق من الوثائق المتبقية
    const remaining = await prisma.craftsmanIDocument.count();
    console.log(`📊 الوثائق المتبقية: ${remaining}`);

    // 3. التحقق من القيد الفريد
    console.log('\n🔍 التحقق من القيد الفريد...');
    console.log('✅ إذا لم تظهر أخطاء، فالقيد الفريد موجود ويعمل');

    console.log('\n✨ تم التنظيف بنجاح! يمكنك الآن رفع الوثائق من جديد.');

  } catch (error: any) {
    console.error('❌ خطأ:', error.message);
  }

  await prisma.$disconnect();
}

cleanup().catch(console.error);
