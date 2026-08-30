import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const iconMap: Record<string, string> = {
  'wrench': '',
  'zap': '⚡',
  'snowflake': '❄️',
  'grid': '🔲',
  'shield': '🛡️',
  'video': '📹',
  'wifi': '📶',
  'cpu': '💻',
  'sparkles': '✨',
  'paint-bucket': '',
  'truck': '',
  'tree': '',
  'hammer': '🔨',
  'anvil': '️',
  'appliance': '🔌',
  'bug': '',
  'store': '',
};

async function main() {
  const categories = await prisma.category.findMany();
  
  for (const cat of categories) {
    const emoji = iconMap[cat.icon] || '';
    await prisma.category.update({
      where: { id: cat.id },
      data: { icon: emoji },
    });
    console.log(`✅ ${cat.name} - ${emoji}`);
  }
  
  console.log('\n🎉 تم تحديث جميع الأيقونات بنجاح!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
