#!/usr/bin/env node
/**
 * Spaja dva base64 fragmenta (bez novih redova između) u UTF-8 TSV.
 * Upotreba:
 *   node scripts/merge-employee-b64-to-tsv.cjs docs/reports/_emp_b64_1.txt docs/reports/_emp_b64_2.txt docs/reports/employees_org_export.tsv
 */
const fs = require('fs');
const [,, aPath, bPath, outPath] = process.argv;
if (!aPath || !bPath || !outPath) {
  console.error('Usage: node scripts/merge-employee-b64-to-tsv.cjs <part1.b64> <part2.b64> <out.tsv>');
  process.exit(1);
}
const raw = fs.readFileSync(aPath, 'utf8').trim() + fs.readFileSync(bPath, 'utf8').trim();
const buf = Buffer.from(raw, 'base64');
fs.writeFileSync(outPath, buf);
console.error('Wrote', outPath, buf.length, 'bytes');
