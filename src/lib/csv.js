/**
 * Pure CSV formatiranje (RFC 4180). Bez DOM/network zavisnosti radi testabilnosti.
 *
 * Pravila:
 *  - separator: `,`
 *  - redovi odvojeni `\r\n` (Excel/Windows friendly)
 *  - polje se citira duplim navodnicima kada sadrži `"`, `,`, `\r` ili `\n`
 *  - unutarnji `"` se duplira (`"` → `""`)
 *  - `null`/`undefined` → prazno polje
 *  - `Date` → ISO 8601 string
 *  - objekti → `JSON.stringify` (rezerva za neočekivane vrednosti)
 */

/**
 * Formatiranje jednog polja.
 * @param {*} v
 * @returns {string}
 */
export function toCsvField(v) {
  if (v == null) return '';
  let s;
  if (v instanceof Date) {
    s = Number.isFinite(v.getTime()) ? v.toISOString() : '';
  } else if (typeof v === 'object') {
    try {
      s = JSON.stringify(v);
    } catch {
      s = String(v);
    }
  } else {
    s = String(v);
  }
  if (/[",\r\n]/.test(s)) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

/**
 * Sastavljanje celokupnog CSV dokumenta.
 * @param {string[]} headers — labele prve linije
 * @param {Array<Array<*>>} rows — redovi, svaki niz vrednosti iste dužine kao headers
 * @returns {string}
 */
export function rowsToCsv(headers, rows) {
  const lines = [headers.map(toCsvField).join(',')];
  for (const r of rows) {
    lines.push(r.map(toCsvField).join(','));
  }
  return lines.join('\r\n');
}

/**
 * UTF-8 BOM prefix — Excel na Windows-u bez ovoga tretira ć/č/š/đ/ž kao mojibake.
 */
export const CSV_BOM = '\uFEFF';
