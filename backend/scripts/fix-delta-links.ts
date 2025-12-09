/**
 * Script to fix Delta content that was migrated without preserving links
 * This checks Delta content and re-migrates from node_versions if original HTML exists
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

function containsHtml(content: string): boolean {
  if (!content) return false;
  const htmlTagRegex = /<[a-z][\s\S]*>/i;
  return htmlTagRegex.test(content.trim());
}

function htmlToDelta(html: string): string {
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
      const textBefore = beforeLink.replace(/<[^>]+>/g, '').replace(/\n{3,}/g, '\n\n');
      if (textBefore.trim()) {
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
    const linkText = match[2] || linkUrl;
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
    const cleanText = remaining
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n')
      .replace(/<\/div>/gi, '\n')
      .replace(/<\/h[1-6]>/gi, '\n')
      .replace(/<[^>]+>/g, '')
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

  // Handle case where there were no links
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

  if (ops.length === 0) {
    ops.push({ insert: '\n' });
  }

  return JSON.stringify({ ops });
}

async function fixDeltaLinks() {
  try {
    console.log('Checking for nodes with Delta format that might need link fixes...');

    // Get all nodes with Delta format
    const deltaNodes = await prisma.node.findMany({
      where: {
        textFormat: 'delta',
        textContent: { not: null },
      },
      select: {
        id: true,
        textContent: true,
        title: true,
      },
    });

    console.log(`Found ${deltaNodes.length} nodes with Delta format`);

    let fixed = 0;
    let errors = 0;

    for (const node of deltaNodes) {
      try {
        if (!node.textContent) continue;

        // Check if Delta JSON is valid and check for links
        let hasLinks = false;
        try {
          const delta = JSON.parse(node.textContent);
          if (delta.ops) {
            hasLinks = delta.ops.some((op: any) => op.attributes?.link);
          }
        } catch {
          // Invalid JSON, might need fixing
        }

        // Check node_versions for original HTML
        const versions = await prisma.nodeVersion.findMany({
          where: {
            nodeId: node.id,
            textContent: { not: null },
          },
          orderBy: {
            versionNumber: 'desc',
          },
          take: 5, // Check last 5 versions
          select: {
            textContent: true,
            textFormat: true,
            versionNumber: true,
          },
        });

        // Find the first version with HTML
        let htmlVersion = null;
        for (const version of versions) {
          if (version.textFormat === 'html' || containsHtml(version.textContent || '')) {
            htmlVersion = version;
            break;
          }
        }

        // If we found HTML in versions and current Delta doesn't have links, re-migrate
        if (htmlVersion && htmlVersion.textContent) {
          if (!hasLinks) {
            console.log(`Fixing node ${node.id} (${node.title.substring(0, 50)}...)`);
            console.log(`  Found HTML in version ${htmlVersion.versionNumber}`);
            const fixedDelta = htmlToDelta(htmlVersion.textContent);
            console.log(`  Fixed Delta: ${fixedDelta.substring(0, 100)}...`);

            await prisma.node.update({
              where: { id: node.id },
              data: {
                textContent: fixedDelta,
                textFormat: 'delta',
              },
            });

            fixed++;
          }
        } else {
          // Check if current Delta is malformed (like the one in the screenshot)
          try {
            const delta = JSON.parse(node.textContent);
            if (delta.ops) {
              // Check if it looks malformed (has raw text that should be links)
              const hasMalformedContent = delta.ops.some((op: any) => 
                typeof op.insert === 'string' && 
                (op.insert.includes('href=') || op.insert.includes('<a'))
              );
              if (hasMalformedContent) {
                console.log(`Node ${node.id} has malformed Delta content - manual fix needed`);
              }
            }
          } catch {
            console.log(`Node ${node.id} has invalid Delta JSON - manual fix needed`);
          }
        }
      } catch (error) {
        console.error(`Error fixing node ${node.id}:`, error);
        errors++;
      }
    }

    console.log(`\nFix complete!`);
    console.log(`  Fixed: ${fixed}`);
    console.log(`  Errors: ${errors}`);
  } catch (error) {
    console.error('Fix failed:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  fixDeltaLinks()
    .then(() => {
      console.log('Fix script completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Fix script failed:', error);
      process.exit(1);
    });
}

