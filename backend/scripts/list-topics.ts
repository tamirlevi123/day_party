import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function listTopics() {
  try {
    const topics = await prisma.topic.findMany({
      select: {
        id: true,
        name: true,
        description: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    console.log('\n📋 Topics in database:\n');
    topics.forEach((topic, index) => {
      console.log(`${index + 1}. "${topic.name}"`);
      console.log(`   ID: ${topic.id}`);
      console.log(`   Description: ${topic.description?.substring(0, 50)}...`);
      console.log('');
    });
  } catch (error: any) {
    console.error('❌ Error:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

listTopics();

