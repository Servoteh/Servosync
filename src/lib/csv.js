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
 *  - **CSV injection escape (Härd-2 / L24)**: ako prvi karakter stringa je
 *    `=`, `+`, `-`, `@`, `\t`, `\r` ili `\n` (vodeći whitespace ne računamo),
 *    prefiksujemo apostrof `'`. Excel/LibreOffice taj prefiks tretiraju kao
 *    „obični tekst" i NE pokreću formulu. Bez ovog escape-a, polje
 *    `=cmd|'/c calc'!A1` može da pokrene komandu pri otvaranju CSV-a.
 */

/* Karakteri koji u Excel-u/LibreOffice-u označavaju početak formule.
 * Tab i CR/LF su tu jer mnogi parseri ignorišu vodeći whitespace pa
 * "\t=cmd..." stigne do interpretera. */
const CSV_INJECTION_PREFIXES = new Set(['=', '+', '-', '@', '\t', '\r', '\n']);

/**
 * Formatiranje jednog polja.
 * @param {*} v
 * @returns {string}
 */
export function toCsvField(v) {
  if (v == null) return '';
  let s;
  let isNumeric = false;  /* legitimni brojevi/bool-ovi ne smeju da dobiju ' prefiks */
  if (v instanceof Date) {
    s = Number.isFinite(v.getTime()) ? v.toISOString() : '';
  } else if (typeof v === 'object') {
    try {
      s = JSON.stringify(v);
    } catch {
      s = String(v);
    }
  } else if (typeof v === 'number' || typeof v === 'bigint' || typeof v === 'boolean') {
    s = String(v);
    isNumeric = true;
  } else {
    s = String(v);
  }
  /* CSV injection escape (Härd-2 / L24): ako prvi karakter stringa je opasan
   * (=, +, -, @, \t, \r, \n) i polje NIJE došlo iz primitivnog broja/bool-a,
   * prefiksujemo `'`. Excel/LibreOffice tretiraju `'` kao indikator teksta.
   * Negativni brojevi (-1) ostaju kao -1 (nisu napad — `isNumeric=true`).
   * Stringovi koji počinju sa `-` (npr. user input "-foo") dobijaju escape. */
  if (!isNumeric && s.length > 0 && CSV_INJECTION_PREFIXES.has(s.charAt(0))) {
    s = "'" + s;
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

/**
 * Trigger-uje download CSV fajla u browseru.
 *  - automatski dodaje BOM (Excel kompatibilnost)
 *  - koristi Blob + a[download] pattern (radi u svim modernim browserima)
 *  - filename treba da bude kompletno ime sa .csv ekstenzijom
 */
export function downloadCsv(filename, headers, rows) {
  const csv = CSV_BOM + rowsToCsv(headers, rows);
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 100);
}

/**
 * Jednostavan CSV parser (RFC 4180 — navodnici i duplirani `"`).
 * @param {string} text
 * @returns {{ headers: string[], rows: string[][] }}
 */
export function parseCsv(text) {
  const raw = String(text || '').replace(/^\uFEFF/, '');
  const out = [];
  let row = [];
  let field = '';
  let i = 0;
  let inQuotes = false;
  while (i < raw.length) {
    const c = raw[i];
    if (inQuotes) {
      if (c === '"') {
        if (raw[i + 1] === '"') {
          field += '"';
          i += 2;
          continue;
        }
        inQuotes = false;
        i += 1;
        continue;
      }
      field += c;
      i += 1;
      continue;
    }
    if (c === '"') {
      inQuotes = true;
      i += 1;
      continue;
    }
    if (c === ',') {
      row.push(field);
      field = '';
      i += 1;
      continue;
    }
    if (c === '\r') {
      i += 1;
      continue;
    }
    if (c === '\n') {
      row.push(field);
      field = '';
      out.push(row);
      row = [];
      i += 1;
      continue;
    }
    field += c;
    i += 1;
  }
  row.push(field);
  if (row.length > 1 || row[0] !== '') {
    out.push(row);
  }
  if (out.length === 0) {
    return { headers: [], rows: [] };
  }
  const headers = out[0].map((h) => String(h).trim());
  const rows = out
    .slice(1)
    .filter((r) => r.some((cell) => String(cell).trim() !== ''))
    .map((r) => r.map((c) => String(c).trim()));
  return { headers, rows };
}
