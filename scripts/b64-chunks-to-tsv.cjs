#!/usr/bin/env node
/**
 * Spaja c1..c5 base64 fragmente iz JSON fajla (jedan red iz MCP) u UTF-8 TSV.
 *   node scripts/b64-chunks-to-tsv.cjs docs/reports/_emp_chunks_mcp.json docs/reports/employees_org_export.tsv
 */
const fs = require('fs');
const [,, inPath, outPath] = process.argv;
if (!inPath || !outPath) {
  console.error('Usage: node scripts/b64-chunks-to-tsv.cjs <chunks.json> <out.tsv>');
  process.exit(1);
}
const row = JSON.parse(fs.readFileSync(inPath, 'utf8'))[0];
const parts = ['c1', 'c2', 'c3', 'c4', 'c5'].map(k => String(row[k] || '').replace(/\r?\n/g, ''));
const b64 = parts.join('');
const buf = Buffer.from(b64, 'base64');
fs.writeFileSync(outPath, buf);
console.error('Decoded', buf.length, 'bytes →', outPath);
