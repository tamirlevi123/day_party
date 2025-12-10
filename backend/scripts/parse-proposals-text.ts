/**
 * Parser for proposals text file format
 * Format:
 * ID: <id>
 * Title: <title>
 * Description: <description>
 * ================
 */

import * as fs from 'fs';

interface ProposalData {
  id: number;
  title: string;
  description: string;
  authorName?: string;
}

export function parseProposalsText(filePath: string): ProposalData[] {
  const content = fs.readFileSync(filePath, 'utf8');
  const proposals: ProposalData[] = [];
  
  // Split by separator lines (===)
  const sections = content.split(/={10,}/);
  
  for (const section of sections) {
    const lines = section.trim().split(/\r?\n/);
    
    let id: number | null = null;
    let title = '';
    let authorName: string | undefined;
    let description = '';
    let inDescription = false;
    let foundTitle = false;
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const trimmed = line.trim();
      
      // Skip header lines
      if (trimmed.startsWith('Found') || trimmed.match(/^\d+ proposals/)) {
        continue;
      }
      
      // Parse ID
      if (trimmed.startsWith('ID:')) {
        const idMatch = trimmed.match(/ID:\s*(\d+)/);
        if (idMatch) {
          id = parseInt(idMatch[1], 10);
        }
      }
      // Parse Author
      else if (trimmed.startsWith('Author:')) {
        authorName = trimmed.replace(/^Author:\s*/, '').trim();
        if (authorName === '') {
          authorName = undefined;
        }
      }
      // Parse Title
      else if (trimmed.startsWith('Title:')) {
        title = trimmed.replace(/^Title:\s*/, '').trim();
        foundTitle = true;
        inDescription = false;
      }
      // Parse Description (can be on same line or following lines)
      else if (trimmed.startsWith('Description:')) {
        const descText = trimmed.replace(/^Description:\s*/, '').trim();
        if (descText && descText !== '(empty)') {
          description = descText;
          inDescription = true;
        } else {
          inDescription = false;
        }
      }
      // Skip separator line (---)
      else if (trimmed === '---' || trimmed.match(/^-+$/)) {
        // This is the separator between title and description
        continue;
      }
      // Continue reading description if we're in description mode
      else if (inDescription && trimmed) {
        description += '\n' + trimmed;
      }
      // If we have title but haven't started description yet, and this isn't empty, it might be description
      else if (foundTitle && !inDescription && trimmed && id !== null) {
        // Check if next line is separator or end
        const nextLine = i + 1 < lines.length ? lines[i + 1].trim() : '';
        if (nextLine === '---' || nextLine.match(/^={10,}$/) || nextLine === '') {
          // This is likely description content
          description = trimmed;
          inDescription = true;
        }
      }
    }
    
    if (id !== null && title) {
      // Clean up description - decode HTML entities
      let cleanDescription = description.trim()
        .replace(/&nbsp;/g, ' ')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>');
      
      proposals.push({
        id,
        title: title.trim(),
        description: cleanDescription,
        authorName: authorName,
      });
    }
  }
  
  return proposals;
}

