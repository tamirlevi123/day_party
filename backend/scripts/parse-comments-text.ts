/**
 * Parser for comments text file format
 * Format:
 * Comment ID: <id>
 * Proposal ID: <id>
 * Proposal Title: <title>
 * Comment Author: <name>
 * Type: Top-level comment | Parent Comment ID: <id> (reply)
 * Created: <timestamp>
 * Body: <text>
 * ================
 */

import * as fs from 'fs';

export interface CommentData {
  id: number;
  proposalId: number;
  proposalTitle: string;
  authorName: string;
  parentCommentId: number | null;
  createdAt: string;
  body: string;
}

export function parseCommentsText(filePath: string): CommentData[] {
  const content = fs.readFileSync(filePath, 'utf8');
  const comments: CommentData[] = [];
  
  // Split by separator lines (===)
  const sections = content.split(/={10,}/);
  
  for (const section of sections) {
    const lines = section.trim().split(/\r?\n/);
    
    // Skip header line
    if (lines[0]?.includes('Found') || lines[0]?.includes('comments')) {
      continue;
    }
    
    let id: number | null = null;
    let proposalId: number | null = null;
    let proposalTitle = '';
    let authorName = '';
    let parentCommentId: number | null = null;
    let createdAt = '';
    let body = '';
    let inBody = false;
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const trimmed = line.trim();
      
      // Skip empty lines and separators
      if (!trimmed || trimmed === '---' || trimmed.match(/^-+$/)) {
        if (trimmed === '---' || trimmed.match(/^-+$/)) {
          inBody = true; // Body starts after the separator
        }
        continue;
      }
      
      // Parse fields
      if (trimmed.startsWith('Comment ID:')) {
        const match = trimmed.match(/Comment ID:\s*(\d+)/);
        if (match) {
          id = parseInt(match[1], 10);
        }
      } else if (trimmed.startsWith('Proposal ID:')) {
        const match = trimmed.match(/Proposal ID:\s*(\d+)/);
        if (match) {
          proposalId = parseInt(match[1], 10);
        }
      } else if (trimmed.startsWith('Proposal Title:')) {
        proposalTitle = trimmed.replace(/^Proposal Title:\s*/, '').trim();
      } else if (trimmed.startsWith('Comment Author:')) {
        authorName = trimmed.replace(/^Comment Author:\s*/, '').trim();
      } else if (trimmed.startsWith('Parent Comment ID:')) {
        const match = trimmed.match(/Parent Comment ID:\s*(\d+)/);
        if (match) {
          parentCommentId = parseInt(match[1], 10);
        }
      } else if (trimmed.startsWith('Type:')) {
        // Check if it's a reply
        if (trimmed.includes('Parent Comment ID')) {
          const match = trimmed.match(/Parent Comment ID:\s*(\d+)/);
          if (match) {
            parentCommentId = parseInt(match[1], 10);
          }
        }
        // Type line also marks the start of body section
        inBody = false; // Reset, body starts after separator
      } else if (trimmed.startsWith('Created:')) {
        createdAt = trimmed.replace(/^Created:\s*/, '').trim();
        inBody = false; // Reset, body starts after separator
      } else if (trimmed.startsWith('Body:')) {
        const bodyText = trimmed.replace(/^Body:\s*/, '').trim();
        if (bodyText && bodyText !== '(empty)') {
          body = bodyText;
          inBody = true;
        } else {
          inBody = false;
        }
      } else if (inBody && trimmed) {
        // Continue reading body (multi-line)
        if (body) {
          body += '\n' + trimmed;
        } else {
          body = trimmed;
        }
      }
    }
    
    // Only add if we have required fields
    if (id !== null && proposalId !== null && authorName && body.trim()) {
      // Decode HTML entities in body
      let cleanBody = body.trim()
        .replace(/&nbsp;/g, ' ')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>');
      
      comments.push({
        id,
        proposalId,
        proposalTitle,
        authorName: authorName.trim(),
        parentCommentId,
        createdAt: createdAt || new Date().toISOString(),
        body: cleanBody,
      });
    }
  }
  
  console.log(`✅ Parsed ${comments.length} comments from text file.`);
  return comments;
}

