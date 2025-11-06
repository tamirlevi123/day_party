import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import dotenv from 'dotenv';

dotenv.config();

const prisma = new PrismaClient();

async function seed() {
  // Upsert base user (create if doesn't exist, otherwise get existing)
  const user = await prisma.user.upsert({
    where: { email: 'test@dayparty.com' },
    update: {},
    create: {
      id: randomUUID(),
      displayName: 'Test User',
      email: 'test@dayparty.com',
      locale: 'he-IL',
      role: 'user',
    },
  });
  console.log('✅ User:', user.displayName, user.id);

  // ---------------------------------------------------------------------------
  // Add a few more users to emulate a real conversation
  // ---------------------------------------------------------------------------
  const participantSpecs = [
    { email: 'noa@dayparty.com', displayName: 'נועה' },
    { email: 'david@dayparty.com', displayName: 'David' },
    { email: 'yael@dayparty.com', displayName: 'Yael' },
    { email: 'amir@dayparty.com', displayName: 'Amir' },
  ];

  const participants = [] as { id: string; displayName: string }[];
  for (const spec of participantSpecs) {
    const p = await prisma.user.upsert({
      where: { email: spec.email },
      update: {},
      create: {
        id: randomUUID(),
        displayName: spec.displayName,
        email: spec.email,
        locale: 'he-IL',
        role: 'user',
      },
    });
    participants.push({ id: p.id, displayName: p.displayName ?? spec.displayName });
  }
  console.log('✅ Seeded participants:', participants.map((p) => p.displayName).join(', '));

  // Upsert test topic
  const existingTopic = await prisma.topic.findFirst({
    where: { name: 'Test Topic', createdBy: user.id },
  });
  
  let topic;
  if (existingTopic) {
    topic = existingTopic;
    console.log('✅ Using existing topic:', topic.name);
  } else {
    topic = await prisma.topic.create({
      data: {
        id: randomUUID(),
        name: 'Test Topic',
        description: 'A test topic for development',
        visibility: 'public',
        createdBy: user.id,
      },
    });
    console.log('✅ Created topic:', topic.name);
  }

  // Upsert test thread
  const existingThread = await prisma.thread.findFirst({
    where: { topicId: topic.id, title: 'Test Thread: Should we implement feature X?' },
  });
  
  let thread;
  if (existingThread) {
    thread = existingThread;
    console.log('✅ Using existing thread:', thread.title);
    
    // Delete existing nodes to recreate them fresh
    await prisma.node.deleteMany({
      where: { threadId: thread.id },
    });
    console.log('✅ Cleared existing nodes');
  } else {
    thread = await prisma.thread.create({
      data: {
        id: randomUUID(),
        topicId: topic.id,
        title: 'Test Thread: Should we implement feature X?',
        description: 'This is a test thread for API development',
        createdBy: user.id,
        status: 'open',
      },
    });
    console.log('✅ Created thread:', thread.title);
  }

  // Create root node (no parent)
  const rootNode = await prisma.node.create({
    data: {
      id: randomUUID(),
      threadId: thread.id,
      parentNodeId: null,
      parentRelation: null,
      title: 'Root Node: Initial Discussion',
      textContent: 'This is the root node. It has no parent relation.',
      textFormat: 'plain',
      authorId: user.id,
      isAnonymous: false,
      moderationState: 'visible',
      textStatus: 'provided',
      videoStatus: 'missing',
      votingEnabled: true,
    },
  });
  console.log('✅ Created root node:', rootNode.title);

  // Create reply nodes with different parent relations
  const proNode = await prisma.node.create({
    data: {
      id: randomUUID(),
      threadId: thread.id,
      parentNodeId: rootNode.id,
      parentRelation: 'pro',
      title: 'Pro reply',
      textContent: 'I agree with this!',
      textFormat: 'plain',
      authorId: user.id,
      isAnonymous: false,
      moderationState: 'visible',
      textStatus: 'provided',
      videoStatus: 'missing',
      votingEnabled: true,
    },
  });
  console.log('✅ Created PRO reply:', proNode.title);

  const againstNode = await prisma.node.create({
    data: {
      id: randomUUID(),
      threadId: thread.id,
      parentNodeId: rootNode.id,
      parentRelation: 'against',
      title: 'Against reply',
      textContent: 'I disagree with this.',
      textFormat: 'plain',
      authorId: user.id,
      isAnonymous: false,
      moderationState: 'visible',
      textStatus: 'provided',
      videoStatus: 'missing',
      votingEnabled: true,
    },
  });
  console.log('✅ Created AGAINST reply:', againstNode.title);

  const neutralNode = await prisma.node.create({
    data: {
      id: randomUUID(),
      threadId: thread.id,
      parentNodeId: rootNode.id,
      parentRelation: 'neutral',
      title: 'Neutral reply',
      textContent: 'I have mixed feelings about this.',
      textFormat: 'plain',
      authorId: user.id,
      isAnonymous: false,
      moderationState: 'visible',
      textStatus: 'provided',
      videoStatus: 'missing',
      votingEnabled: true,
    },
  });
  console.log('✅ Created NEUTRAL reply:', neutralNode.title);

  // ---------------------------------------------------------------------------
  // Add a "real data" Hebrew thread with multiple participants and replies
  // Topic: Cannabis regulation
  // Title (Hebrew):
  // "צריך לשנות את היחס לקנאביס כך שיהיה חוקי עם הרבה מס, כמו סיגריות"
  // ---------------------------------------------------------------------------
  const hebrewTitle = 'צריך לשנות את היחס לקנאביס כך שיהיה חוקי עם הרבה מס, כמו סיגריות';
  const existingHebrewThread = await prisma.thread.findFirst({
    where: { topicId: topic.id, title: hebrewTitle },
  });

  let hebrewThread;
  if (existingHebrewThread) {
    hebrewThread = existingHebrewThread;
    console.log('✅ Using existing Hebrew thread');
    await prisma.node.deleteMany({ where: { threadId: hebrewThread.id } });
    console.log('✅ Cleared existing nodes for Hebrew thread');
  } else {
    hebrewThread = await prisma.thread.create({
      data: {
        id: randomUUID(),
        topicId: topic.id,
        title: hebrewTitle,
        description: 'דיון ציבורי: האם נכון להפוך קנאביס לחוקי, עם מיסוי משמעותי לטובת בריאות הציבור?',
        createdBy: user.id,
        status: 'open',
      },
    });
    console.log('✅ Created Hebrew thread');
  }

  // Root node (no parent)
  const hebrewRoot = await prisma.node.create({
    data: {
      id: randomUUID(),
      threadId: hebrewThread.id,
      parentNodeId: null,
      parentRelation: null,
      title: 'הפיכת קנאביס לחוקי עם מס גבוה – בעד?',
      textContent:
        'רעיון: להסדיר שוק חוקי לקנאביס בדומה לסיגריות, עם מס משמעותי ומנגנוני פיקוח. ההכנסות יופנו לבריאות הציבור וחינוך.',
      textFormat: 'plain',
      authorId: participants[0]?.id ?? user.id,
      isAnonymous: false,
      moderationState: 'visible',
      textStatus: 'provided',
      videoStatus: 'missing',
      votingEnabled: true,
    },
  });

  // Replies (pro / against / neutral)
  await prisma.node.create({
    data: {
      id: randomUUID(),
      threadId: hebrewThread.id,
      parentNodeId: hebrewRoot.id,
      parentRelation: 'pro',
      title: 'הסדרה תקטין פשיעה ותאפשר פיקוח',
      textContent:
        'ברגע שהשוק חוקי – אפשר לפקח על איכות, גיל קנייה, ולצמצם את השוק השחור. המס יחזור לקהילה.',
      textFormat: 'plain',
      authorId: participants[1]?.id ?? user.id,
      isAnonymous: false,
      moderationState: 'visible',
      textStatus: 'provided',
      videoStatus: 'missing',
      votingEnabled: true,
    },
  });

  await prisma.node.create({
    data: {
      id: randomUUID(),
      threadId: hebrewThread.id,
      parentNodeId: hebrewRoot.id,
      parentRelation: 'against',
      title: 'חשש מעלייה בשימוש בקרב צעירים',
      textContent:
        'למרות מס גבוה, זמינות גבוהה עלולה להעלות שימוש בקרב צעירים. צריך אכיפה וחינוך מקדים.',
      textFormat: 'plain',
      authorId: participants[2]?.id ?? user.id,
      isAnonymous: false,
      moderationState: 'visible',
      textStatus: 'provided',
      videoStatus: 'missing',
      votingEnabled: true,
    },
  });

  await prisma.node.create({
    data: {
      id: randomUUID(),
      threadId: hebrewThread.id,
      parentNodeId: hebrewRoot.id,
      parentRelation: 'neutral',
      title: 'ניסוי מדורג עם בקרה',
      textContent:
        'אפשר להתחיל בפיילוט ערים/מחוזות, למדוד נתונים על בריאות ובטיחות, ולהרחיב רק אם המדדים טובים.',
      textFormat: 'plain',
      authorId: participants[3]?.id ?? user.id,
      isAnonymous: false,
      moderationState: 'visible',
      textStatus: 'provided',
      videoStatus: 'missing',
      votingEnabled: true,
    },
  });

  console.log('\n✅ Seed data created successfully!');
  console.log('\nTest IDs:');
  console.log('Thread ID:', thread.id);
  console.log('Root Node ID:', rootNode.id);
  console.log('Pro Reply ID:', proNode.id);
  console.log('Against Reply ID:', againstNode.id);
  console.log('Neutral Reply ID:', neutralNode.id);
  console.log('Hebrew Thread ID:', hebrewThread.id);
  console.log('Hebrew Root Node ID:', hebrewRoot.id);
}

seed()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

