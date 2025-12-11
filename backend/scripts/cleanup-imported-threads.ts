/**
 * Cleanup script to remove imported threads and their nodes
 * Usage: tsx scripts/cleanup-imported-threads.ts [--topic-name "Topic Name"] [--delete-users]
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const TOPIC_NAME = 'אזרחים כותבים חוקה';

async function cleanupImportedThreads() {
  try {
    console.log('🧹 Starting cleanup of imported threads...\n');
    
    // Test database connection first
    console.log('🔌 Testing database connection...');
    await prisma.$connect();
    console.log('✅ Database connected\n');

    // Parse command line arguments
    const args = process.argv.slice(2);
    const topicNameIndex = args.indexOf('--topic-name');
    const topicName = topicNameIndex >= 0 && args[topicNameIndex + 1] 
      ? args[topicNameIndex + 1] 
      : TOPIC_NAME;
    const topicIdIndex = args.indexOf('--topic-id');
    const topicId = topicIdIndex >= 0 && args[topicIdIndex + 1] 
      ? args[topicIdIndex + 1] 
      : null;
    const deleteUsers = args.includes('--delete-users');

    // Find the topic
    console.log('🔍 Searching for topic...');
    let topic;
    if (topicId) {
      console.log(`📁 Looking for topic by ID: "${topicId}"\n`);
      topic = await prisma.topic.findUnique({
        where: { id: topicId },
      });
    } else {
      console.log(`📁 Looking for topic by name: "${topicName}"\n`);
      topic = await prisma.topic.findFirst({
        where: { name: topicName },
      });
    }
    console.log('✅ Topic search complete\n');

    if (!topic) {
      console.log(`❌ Topic "${topicName}" not found. Nothing to clean up.\n`);
      return;
    }

    // Get ALL threads in this topic
    const threads = await prisma.thread.findMany({
      where: {
        topicId: topic.id,
      },
      select: {
        id: true,
        title: true,
      },
    });

    const threadIds = threads.map(t => t.id);
    console.log(`📋 Found ${threadIds.length} threads in topic "${topicName}"\n`);

    if (threadIds.length === 0) {
      console.log('✅ No threads to delete.\n');
      return;
    }

    // Show which threads will be deleted
    console.log('📋 Threads to be deleted:');
    threads.forEach((thread, index) => {
      console.log(`  ${index + 1}. ${thread.title.substring(0, 60)}...`);
    });
    console.log('');

    // Count nodes before deletion
    const nodeCount = await prisma.node.count({
      where: {
        threadId: { in: threadIds },
      },
    });

    console.log(`📊 Statistics:`);
    console.log(`  Threads: ${threadIds.length}`);
    console.log(`  Nodes: ${nodeCount}\n`);

    // Delete nodes first (they reference threads)
    console.log('🗑️  Deleting nodes...');
    const deletedNodes = await prisma.node.deleteMany({
      where: {
        threadId: { in: threadIds },
      },
    });
    console.log(`  ✅ Deleted ${deletedNodes.count} nodes\n`);

    // Delete threads
    console.log('🗑️  Deleting threads...');
    const deletedThreads = await prisma.thread.deleteMany({
      where: {
        id: { in: threadIds },
      },
    });
    console.log(`  ✅ Deleted ${deletedThreads.count} threads\n`);

    // Optionally delete import users
    if (deleteUsers) {
      console.log('🗑️  Deleting import users...');
      
      // Find users with import email pattern
      const importUsers = await prisma.user.findMany({
        where: {
          OR: [
            { email: { endsWith: '_import@dayparty.com' } },
            { email: 'import@dayparty.com' },
          ],
        },
      });

      if (importUsers.length > 0) {
        const userIds = importUsers.map(u => u.id);
        const deletedUsers = await prisma.user.deleteMany({
          where: {
            id: { in: userIds },
          },
        });
        console.log(`  ✅ Deleted ${deletedUsers.count} import users\n`);
      } else {
        console.log(`  ℹ️  No import users found\n`);
      }
    } else {
      console.log('ℹ️  Import users preserved (use --delete-users to remove them)\n');
    }

    console.log('✅ Cleanup complete!\n');
    console.log('📈 Summary:');
    console.log(`  Threads deleted: ${deletedThreads.count}`);
    console.log(`  Nodes deleted: ${deletedNodes.count}`);
    if (deleteUsers) {
      const importUsers = await prisma.user.findMany({
        where: {
          OR: [
            { email: { endsWith: '_import@dayparty.com' } },
            { email: 'import@dayparty.com' },
          ],
        },
      });
      console.log(`  Users deleted: ${importUsers.length > 0 ? importUsers.length : 0}`);
    }
  } catch (error: any) {
    console.error('❌ Cleanup failed:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Show usage
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log(`
Usage:
  tsx scripts/cleanup-imported-threads.ts [options]

Options:
  --topic-name <name>   Topic name to clean up (default: "אזרחים כותבים חוקה")
  --delete-users        Also delete import users (default: false)
  --help, -h            Show this help message

Examples:
  # Clean up default topic (keeps users):
  tsx scripts/cleanup-imported-threads.ts
  
  # Clean up specific topic and delete users:
  tsx scripts/cleanup-imported-threads.ts --topic-name "אזרחים כותבים חוקה" --delete-users
`);
  process.exit(0);
}

// Run cleanup
cleanupImportedThreads()
  .catch((e) => {
    console.error('❌ Fatal error:', e);
    process.exit(1);
  });

