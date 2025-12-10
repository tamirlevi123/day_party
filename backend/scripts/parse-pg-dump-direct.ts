/**
 * Direct parser for PostgreSQL custom format dump files
 * Reads the binary format and extracts table data
 */

import * as fs from 'fs';

interface TableData {
  columns: string[];
  rows: any[][];
}

/**
 * Parse PostgreSQL custom format dump file and extract table data
 * 
 * Format documentation: https://www.postgresql.org/docs/current/app-pgrestore.html
 * Custom format is a tar-like archive with entries
 */
interface TOCEntry {
  dumpId: number;
  dumpTag: string;
  description: string;
  defn?: string;
  dropStmt?: string;
  dataOffset?: number;
  dataLength?: number;
}

export async function parsePgDumpDirect(dumpFilePath: string): Promise<Map<string, TableData>> {
  const data = new Map<string, TableData>();
  const buffer = fs.readFileSync(dumpFilePath);
  
  // Check magic header
  if (buffer.toString('ascii', 0, 5) !== 'PGDMP') {
    throw new Error('Not a PostgreSQL custom format dump file');
  }

  // Read version (can be 1.0-1.14 format)
  const versionByte = buffer[5];
  const versionMinor = buffer[6];
  const versionMajor = buffer[7];
  const versionInt = buffer[8];
  
  // Version is stored as: major.minor (e.g., 1.14 = 0x01 0x0E)
  const version = versionByte === 1 ? `${versionByte}.${versionMinor}` : `${versionByte}.${versionMinor}`;
  console.log(`📦 Dump version: ${version}`);

  // Read TOC offset (position 9-12, 4 bytes big-endian)
  let pos = 9;
  const tocOffset = buffer.readUInt32BE(pos);
  pos += 4;
  
  console.log(`📋 TOC offset: ${tocOffset}`);
  
  // Parse TOC (Table of Contents)
  pos = tocOffset;
  const tocEntries: TOCEntry[] = [];
  
  // Read number of TOC entries
  const tocEntryCount = buffer.readUInt32BE(pos);
  pos += 4;
  
  console.log(`📋 TOC entries: ${tocEntryCount}`);
  
  // Read each TOC entry
  for (let i = 0; i < tocEntryCount; i++) {
    try {
      const dumpId = buffer.readUInt32BE(pos);
      pos += 4;
      
      const dumpTag = buffer.toString('ascii', pos, pos + 1);
      pos += 1;
      
      // Read description
      const descLen = buffer.readUInt32BE(pos);
      pos += 4;
      const description = descLen > 0 ? buffer.toString('utf8', pos, pos + descLen) : '';
      pos += descLen;
      
      // Read defn (if present)
      let defn = '';
      if (dumpTag !== 'B' && dumpTag !== 'd') {
        const defnLen = buffer.readUInt32BE(pos);
        pos += 4;
        if (defnLen > 0) {
          defn = buffer.toString('utf8', pos, pos + defnLen);
          pos += defnLen;
        }
      }
      
      // Read drop statement
      const dropLen = buffer.readUInt32BE(pos);
      pos += 4;
      let dropStmt = '';
      if (dropLen > 0) {
        dropStmt = buffer.toString('utf8', pos, pos + dropLen);
        pos += dropLen;
      }
      
      // Read data offset and length (for data entries)
      let dataOffset = 0;
      let dataLength = 0;
      if (dumpTag === 'd') {
        dataOffset = buffer.readUInt32BE(pos);
        pos += 4;
        dataLength = buffer.readUInt32BE(pos);
        pos += 4;
      }
      
      tocEntries.push({
        dumpId,
        dumpTag,
        description,
        defn: defn || undefined,
        dropStmt: dropStmt || undefined,
        dataOffset: dataOffset || undefined,
        dataLength: dataLength || undefined,
      });
    } catch (error) {
      console.warn(`⚠️  Error reading TOC entry ${i}:`, error);
      break;
    }
  }
  
  // Now process data entries from TOC
  for (const entry of tocEntries) {
    if (entry.dumpTag === 'd' && entry.dataOffset && entry.dataLength) {
      // Extract table name from description
      const copyMatch = entry.description.match(/COPY\s+public\.(\w+)\s*\(([^)]+)\)\s+FROM\s+stdin;/i);
      if (copyMatch) {
        const tableName = copyMatch[1];
        const columns = copyMatch[2].split(',').map(c => c.trim().replace(/"/g, ''));
        
        // Read data section
        const dataStart = entry.dataOffset;
        const dataEnd = dataStart + entry.dataLength;
        
        if (dataEnd <= buffer.length) {
          const dataBuffer = buffer.subarray(dataStart, dataEnd);
          const dataText = dataBuffer.toString('utf8');
          
          // Parse the COPY data
          const rows = parseCopyData(dataText);
          
          if (rows.length > 0) {
            data.set(tableName, { columns, rows });
            console.log(`✅ Extracted ${rows.length} rows from ${tableName} (${columns.length} columns)`);
          }
        } else {
          console.warn(`⚠️  Data section out of bounds for ${tableName}: offset ${dataStart}, length ${entry.dataLength}, buffer size ${buffer.length}`);
        }
      }
    }
  }
  
  return data;
}

/**
 * Parse COPY data format (tab-separated values)
 * Handles NULL values (\N) and escaped characters
 * 
 * Format: Each row is tab-separated, ends with newline
 * NULL values are represented as \N
 * End marker is \. on its own line
 */
function parseCopyData(dataText: string): any[][] {
  const rows: any[][] = [];
  const lines = dataText.split(/\r?\n/);
  
  for (const line of lines) {
    const trimmed = line.trim();
    
    // Skip empty lines and end marker
    if (trimmed === '' || trimmed === '\\.' || trimmed === '.') {
      continue;
    }
    
    // Split by tab
    const values = line.split('\t').map(val => {
      // Handle NULL values
      if (val === '\\N' || val === '') {
        return null;
      }
      
      // Unescape PostgreSQL COPY format escape sequences
      // \t = tab, \n = newline, \r = carriage return, \\ = backslash
      // Note: We need to be careful with the order of replacements
      return val
        .replace(/\\\\/g, '\u0001') // Temporarily replace \\ with placeholder
        .replace(/\\t/g, '\t')
        .replace(/\\n/g, '\n')
        .replace(/\\r/g, '\r')
        .replace(/\u0001/g, '\\'); // Restore backslashes
    });
    
    // Only add non-empty rows
    if (values.some(v => v !== null && v !== '')) {
      rows.push(values);
    }
  }
  
  return rows;
}

