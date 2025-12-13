/**
 * Create the "ממים" (Memes) topic
 * 
 * Usage:
 *   tsx scripts/create-memes-topic.ts
 */

import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import dotenv from 'dotenv';

dotenv.config();

const prisma = new PrismaClient();

async function createMemesTopic() {
  try {
    console.log('🎭 Creating "ממים" topic...\n');

    // Get or create admin user
    let adminUser = await prisma.user.findFirst({
      where: { role: 'admin' },
    });

    if (!adminUser) {
      adminUser = await prisma.user.create({
        data: {
          id: randomUUID(),
          email: 'admin@dayparty.com',
          displayName: 'System Admin',
          role: 'admin',
        },
      });
      console.log('✅ Created default admin user');
    }

    // Check if topic already exists
    const existingTopic = await prisma.topic.findFirst({
      where: {
        name: 'ממים',
      },
    });

    if (existingTopic) {
      console.log('ℹ️  Topic "ממים" already exists:');
      console.log(`   ID: ${existingTopic.id}`);
      console.log(`   Description: ${existingTopic.description}`);
      console.log(`   Threads: ${existingTopic.threadCount || 0}`);
      return;
    }

    // Create the topic
    const topic = await prisma.topic.create({
      data: {
        id: randomUUID(),
        name: 'ממים',
        description: 'תמונות וסרטונים מצחיקים להארת האווירה בדיונים',
        visibility: 'public',
        createdBy: adminUser.id,
      },
    });

    console.log('✅ Topic "ממים" created successfully!');
    console.log(`   ID: ${topic.id}`);
    console.log(`   Name: ${topic.name}`);
    console.log(`   Description: ${topic.description}`);
    console.log(`   Visibility: ${topic.visibility}\n`);
  } catch (error: any) {
    console.error('❌ Error creating topic:', error.message);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

createMemesTopic()
  .catch((e) => {
    console.error('❌ Fatal error:', e);
    process.exit(1);
  });

