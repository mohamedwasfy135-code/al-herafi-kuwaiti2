import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function checkDocuments() {
  console.log('🔍 فحص جدول الوثائق...\n');

  try {
    // جلب كل الوثائق
    const allDocs = await prisma.craftsmanIDocument.findMany({
      select: { 
        id: true, 
        craftsmanId: true, 
        status: true,
        civilIdUrl: true,
        bankAccountPhotoUrl: true,
        createdAt: true 
      },
      orderBy: { createdAt: 'desc' },
    });

    console.log('📄 إجمالي الوثائق:', allDocs.length);
    allDocs.forEach(doc => {
      console.log(`   - وثيقة #${doc.id}:`);
      console.log(`     craftsmanId: ${doc.craftsmanId}`);
      console.log(`     status: ${doc.status}`);
      console.log(`     civilIdUrl: ${doc.civilIdUrl || 'لا يوجد'}`);
      console.log(`     bankAccountPhotoUrl: ${doc.bankAccountPhotoUrl || 'لا يوجد'}`);
      console.log(`     createdAt: ${doc.createdAt}`);
      console.log('');
    });

    // فحص التكرار
    const craftsmanIds = allDocs.map(d => d.craftsmanId);
    const uniqueIds = new Set(craftsmanIds);

    if (craftsmanIds.length !== uniqueIds.size) {
      console.log('\n⚠️  يوجد تكرار! بعض الحرفيين لديهم أكثر من وثيقة.');
      
      const counts = new Map<string, number>();
      craftsmanIds.forEach(id => counts.set(id, (counts.get(id) || 0) + 1));
      
      const duplicates = Array.from(counts.entries()).filter(([_, count]) => count > 1);
      console.log('\nالحرفيون المكررون:');
      duplicates.forEach(([id, count]) => {
        console.log(`   - craftsmanId: ${id} (${count} وثائق)`);
      });
    } else {
      console.log('\n✅ لا يوجد تكرار');
    }

  } catch (error: any) {
    console.error('❌ خطأ في الفحص:', error.message);
    if (error.message.includes('unique constraint')) {
      console.log('\n⚠️  القيد الفريد غير موجود بعد. شغّل: npx prisma db push');
    }
  }

  await prisma.$disconnect();
}

checkDocuments().catch(console.error);
