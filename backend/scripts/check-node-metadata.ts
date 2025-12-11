import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function checkMetadata() {
  try {
    // Find a root node from the Knesset topic
    const node = await prisma.node.findFirst({
      where: {
        parentNodeId: null,
        metadataJson: { not: null },
      },
      include: {
        thread: {
          include: {
            topic: true,
          },
        },
      },
    });

    if (!node) {
      console.log('❌ No root node with metadata found');
      return;
    }

    console.log('\n📋 Found node:');
    console.log(`  Node ID: ${node.id}`);
    console.log(`  Thread: ${node.thread.title.substring(0, 50)}...`);
    console.log(`  Topic: ${node.thread.topic.name}`);
    console.log(`  Metadata: ${JSON.stringify(node.metadataJson, null, 2)}\n`);
  } catch (error: any) {
    console.error('❌ Error:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

checkMetadata();

