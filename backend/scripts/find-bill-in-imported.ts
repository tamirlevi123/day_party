/**
 * Find a specific bill in the imported list
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function findBill() {
  try {
    const billId = 1046149;

    // Get all imported bills from MySQL
    const topic = await prisma.topic.findFirst({
      where: { name: 'חוקים מהמליאה' },
      include: {
        threads: {
          include: {
            nodes: {
              where: { parentNodeId: null }, // Root nodes only
            },
          },
        },
      },
    });

    if (!topic) {
      console.log('❌ Topic "חוקים מהמליאה" not found');
      return;
    }

    // Find the bill
    for (let i = 0; i < topic.threads.length; i++) {
      const thread = topic.threads[i];
      const rootNode = thread.nodes[0];
      if (!rootNode || !rootNode.metadataJson) {
        continue;
      }

      const metadata = rootNode.metadataJson as any;
      if (metadata.billId === billId) {
        console.log(`\n✅ Found bill at position ${i + 1} of ${topic.threads.length}`);
        console.log(`   Thread ID: ${thread.threadId}`);
        console.log(`   Title: ${thread.title}`);
        console.log(`   BillID: ${metadata.billId}`);
        console.log(`   BillNumber: ${metadata.billNumber}`);
        console.log(`   KnessetNum: ${metadata.knessetNum}`);
        return;
      }
    }

    console.log(`\n❌ BillID ${billId} not found in imported bills`);
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

findBill();

