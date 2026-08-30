const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const requests = await prisma.request.findMany({ include: { client: true, craftsman: true } });
  console.log(JSON.stringify(requests, null, 2));
}
main().catch(e => console.error(e)).finally(() => prisma.$disconnect());
