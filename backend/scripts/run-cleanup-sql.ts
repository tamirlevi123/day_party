/**
 * Simple script to run the cleanup SQL using Prisma
 * Usage: tsx scripts/run-cleanup-sql.ts
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function runCleanup() {
  try {
    console.log('🧹 Running cleanup SQL...\n');

    // First, delete all nodes in threads belonging to the topic
    console.log('🗑️  Deleting nodes...');
    const deletedNodes = await prisma.$executeRawUnsafe(`
      DELETE n FROM nodes n
      INNER JOIN threads t ON n.thread_id = t.id
      INNER JOIN topics top ON t.topic_id = top.id
      WHERE top.name = 'אזרחים כותבים חוקה'
    `);
    console.log(`  ✅ Deleted ${deletedNodes} nodes\n`);

    // Then, delete all threads in the topic
    console.log('🗑️  Deleting threads...');
    const deletedThreads = await prisma.$executeRawUnsafe(`
      DELETE t FROM threads t
      INNER JOIN topics top ON t.topic_id = top.id
      WHERE top.name = 'אזרחים כותבים חוקה'
    `);
    console.log(`  ✅ Deleted ${deletedThreads} threads\n`);

    console.log('✅ Cleanup complete!\n');
  } catch (error: any) {
    console.error('❌ Error:', error.message);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

runCleanup()
  .catch((e) => {
    console.error('❌ Fatal error:', e);
    process.exit(1);
  });

