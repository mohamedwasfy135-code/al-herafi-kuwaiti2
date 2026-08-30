import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function testSave() {
  console.log('🧪 اختبار حفظ الوثيقة مباشرة...\n');

  try {
    // جلب أول حرفي
    const craftsman = await prisma.user.findFirst({
      where: { role: 'craftsman' },
      select: { id: true, name: true },
    });

    if (!craftsman) {
      console.log('❌ لا يوجد حرفيون في قاعدة البيانات');
      return;
    }

    console.log('👤 الحرفي:', craftsman.name, craftsman.id);

    // محاولة حفظ وثيقة
    console.log('\n📝 محاولة حفظ وثيقة...');
    
    const document = await prisma.craftsmanIDocument.upsert({
      where: { craftsmanId: craftsman.id },
      update: {
        civilIdUrl: '/test-image.jpg',
        status: 'pending',
      },
      create: {
        craftsmanId: craftsman.id,
        civilIdUrl: '/test-image.jpg',
        status: 'pending',
      },
    });

    console.log('✅ تم الحفظ بنجاح!');
    console.log('📄 الوثيقة:', document);

  } catch (error: any) {
    console.error('\n❌ خطأ في الحفظ:');
    console.error('الرسالة:', error.message);
    console.error('\nالتفاصيل الكاملة:');
    console.error(JSON.stringify(error, null, 2));
    
    if (error.code === 'P2002') {
      console.log('\n⚠️  القيد الفريد يمنع الحفظ - يوجد تكرار');
    } else if (error.code === 'P2025') {
      console.log('\n⚠️  السجل غير موجود');
    }
  }

  await prisma.$disconnect();
}

testSave().catch(console.error);
