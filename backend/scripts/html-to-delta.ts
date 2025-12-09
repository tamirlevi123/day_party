/**
 * Utility script to convert HTML content to Delta JSON format
 * This can be used to migrate existing HTML content to Delta format
 * 
 * Usage:
 *   ts-node scripts/html-to-delta.ts
 * 
 * Or import and use in other scripts:
 *   import { htmlToDelta } from './scripts/html-to-delta';
 */

/**
 * Converts HTML string to Delta JSON format
 * Preserves links, basic formatting, and structure
 * 
 * @param html - HTML string to convert
 * @returns Delta JSON string
 */
export function htmlToDelta(html: string): string {
  if (!html || html.trim().length === 0) {
    return JSON.stringify({ ops: [{ insert: '\n' }] });
  }

  const ops: Array<{ insert: string; attributes?: Record<string, unknown> }> = [];
  
  // Decode HTML entities first
  let decoded = html
    .replace(/&nbsp;/g, ' ')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");

  // Process links: <a href="url">text</a>
  const linkRegex = /<a\s+[^>]*href=["']([^"']+)["'][^>]*>([^<]*)<\/a>/gi;
  let lastIndex = 0;
  let match;

  while ((match = linkRegex.exec(decoded)) !== null) {
    // Add text before the link
    const beforeLink = decoded.substring(lastIndex, match.index);
    if (beforeLink) {
      // Process text before link (handle other tags)
      const textBefore = beforeLink.replace(/<[^>]+>/g, '').replace(/\n{3,}/g, '\n\n');
      if (textBefore.trim()) {
        // Split by newlines and add each line
        const lines = textBefore.split('\n');
        for (let i = 0; i < lines.length; i++) {
          if (lines[i].trim()) {
            ops.push({ insert: lines[i] });
          }
          if (i < lines.length - 1) {
            ops.push({ insert: '\n' });
          }
        }
      }
    }

    // Add the link
    const linkUrl = match[1];
    const linkText = match[2] || linkUrl; // Use URL as text if no link text
    ops.push({
      insert: linkText,
      attributes: {
        link: linkUrl,
      },
    });

    lastIndex = match.index + match[0].length;
  }

  // Add remaining text after last link
  const remaining = decoded.substring(lastIndex);
  if (remaining) {
    // Remove all HTML tags and normalize
    const cleanText = remaining
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n')
      .replace(/<\/div>/gi, '\n')
      .replace(/<\/h[1-6]>/gi, '\n')
      .replace(/<[^>]+>/g, '') // Remove all remaining HTML tags
      .replace(/\n{3,}/g, '\n\n')
      .trim();

    if (cleanText) {
      const lines = cleanText.split('\n');
      for (let i = 0; i < lines.length; i++) {
        if (lines[i].trim()) {
          ops.push({ insert: lines[i] });
        }
        if (i < lines.length - 1) {
          ops.push({ insert: '\n' });
        }
      }
    }
  }

  // Handle case where there were no links - process entire content
  if (ops.length === 0) {
    const plainText = decoded
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n')
      .replace(/<\/div>/gi, '\n')
      .replace(/<\/h[1-6]>/gi, '\n')
      .replace(/<[^>]+>/g, '')
      .replace(/\n{3,}/g, '\n\n')
      .trim();

    if (plainText) {
      const lines = plainText.split('\n');
      for (let i = 0; i < lines.length; i++) {
        if (lines[i].trim()) {
          ops.push({ insert: lines[i] });
        }
        if (i < lines.length - 1) {
          ops.push({ insert: '\n' });
        }
      }
    }
  }

  // If still no content, add a newline
  if (ops.length === 0) {
    ops.push({ insert: '\n' });
  }

  return JSON.stringify({ ops });
}

/**
 * Migrate all nodes with HTML format to Delta format
 * This updates the database directly
 */
/**
 * Check if content contains HTML tags
 */
function containsHtml(content: string): boolean {
  if (!content) return false;
  // Check for HTML tags (simple regex - covers most cases)
  const htmlTagRegex = /<[a-z][\s\S]*>/i;
  return htmlTagRegex.test(content.trim());
}

export async function migrateHtmlToDelta() {
  const { PrismaClient } = require('@prisma/client');
  const prisma = new PrismaClient();

  try {
    console.log('Starting HTML to Delta migration...');

    // Find all nodes with non-null text content
    const allNodes = await prisma.node.findMany({
      where: {
        textContent: { not: null },
      },
      select: {
        id: true,
        textContent: true,
        textFormat: true,
      },
    });

    // Filter nodes that actually contain HTML (regardless of format field)
    const htmlNodes = allNodes.filter(node => 
      node.textContent && containsHtml(node.textContent)
    );

    console.log(`Found ${allNodes.length} total nodes with text content`);
    console.log(`Found ${htmlNodes.length} nodes containing HTML (regardless of format field)`);

    let migrated = 0;
    let errors = 0;

    for (const node of htmlNodes) {
      try {
        if (!node.textContent) continue;

        const deltaJson = htmlToDelta(node.textContent);

        await prisma.node.update({
          where: { id: node.id },
          data: {
            textContent: deltaJson,
            textFormat: 'delta',
          },
        });

        migrated++;
        if (migrated % 10 === 0) {
          console.log(`Migrated ${migrated}/${htmlNodes.length} nodes...`);
        }
      } catch (error) {
        console.error(`Error migrating node ${node.id}:`, error);
        errors++;
      }
    }

    console.log(`\nMigration complete!`);
    console.log(`  Migrated: ${migrated}`);
    console.log(`  Errors: ${errors}`);

    // Also migrate node_versions
    const allVersions = await prisma.nodeVersion.findMany({
      where: {
        textContent: { not: null },
      },
      select: {
        id: true,
        textContent: true,
        textFormat: true,
      },
    });

    // Filter versions that actually contain HTML
    const htmlVersions = allVersions.filter(version =>
      version.textContent && containsHtml(version.textContent)
    );

    console.log(`\nFound ${allVersions.length} total node versions with text content`);
    console.log(`Found ${htmlVersions.length} versions containing HTML (regardless of format field)`);

    let migratedVersions = 0;
    let versionErrors = 0;

    for (const version of htmlVersions) {
      try {
        if (!version.textContent) continue;

        const deltaJson = htmlToDelta(version.textContent);

        await prisma.nodeVersion.update({
          where: { id: version.id },
          data: {
            textContent: deltaJson,
            textFormat: 'delta',
          },
        });

        migratedVersions++;
        if (migratedVersions % 10 === 0) {
          console.log(`Migrated ${migratedVersions}/${htmlVersions.length} versions...`);
        }
      } catch (error) {
        console.error(`Error migrating version ${version.id}:`, error);
        versionErrors++;
      }
    }

    console.log(`\nVersion migration complete!`);
    console.log(`  Migrated: ${migratedVersions}`);
    console.log(`  Errors: ${versionErrors}`);
  } catch (error) {
    console.error('Migration failed:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Run migration if called directly
if (require.main === module) {
  migrateHtmlToDelta()
    .then(() => {
      console.log('Migration script completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Migration script failed:', error);
      process.exit(1);
    });
}

