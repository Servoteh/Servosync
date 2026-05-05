#!/usr/bin/env node
/**
 * Čita JSON niz nizova (iz Supabase MCP execute_sql) i piše TSV.
 * Primer ulaza: [[ "Ime", "Prezime", ... ], ...]
 *
 *   node scripts/json-rows-to-employees-tsv.cjs docs/reports/employees_org_rows.json docs/reports/employees_org_export.tsv
 */
const fs = require('fs');
const [,, inPath, outPath] = process.argv;
if (!inPath || !outPath) {
  console.error('Usage: node scripts/json-rows-to-employees-tsv.cjs <rows.json> <out.tsv>');
  process.exit(1);
}
const rows = JSON.parse(fs.readFileSync(inPath, 'utf8'));
if (!Array.isArray(rows)) {
  console.error('Expected JSON array of rows');
  process.exit(1);
}
const esc = s => String(s ?? '').replace(/\t/g, ' ').replace(/\r?\n/g, ' ');
const lines = ['ime\tprezime\todeljenje\tpododeljenje\tradno_mesto\taktivan\temployee_id'];
for (const r of rows) {
  if (!Array.isArray(r) || r.length < 7) {
    console.error('Bad row', r);
    process.exit(1);
  }
  lines.push(r.map(esc).join('\t'));
}
fs.writeFileSync(outPath, lines.join('\n'), 'utf8');
console.error('Wrote', outPath, rows.length, 'rows');
