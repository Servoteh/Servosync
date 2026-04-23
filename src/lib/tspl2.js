/**
 * TSPL2 command generator za TSC termalne štampače (ML340P, 300 DPI).
 *
 * TSPL2 je proprietary command jezik koji TSC štampači razumeju nativno —
 * brži, oštriji i potpuno bez browser print artifacts (datum/title u sredini
 * papira, CSS DPI varijacije, scaling). Naš payload se šalje JSON-om kroz
 * `VITE_LABEL_PRINTER_PROXY_URL` (vidi `dispatchOptionalNetworkLabelPrint`),
 * a lokalni agent (Node/Python na PC-u u istoj LAN-i) prima JSON, izvlači
 * `tspl2` polje iz `payload`, otvara TCP socket na 9100 ka štampaču i šalje
 * raw bajtove.
 *
 * Specifikacija TSPL2 jezika:
 *   - https://www.tscprinters.com/Tehnology/TSPL2_eng.pdf
 *
 * Konvencije za ML340P (300 DPI = 11.81 dots/mm):
 *   - SIZE komanda u milimetrima sa `mm` jedinicom
 *   - GAP komanda obavezna (3mm gap između nalepnica je standard)
 *   - DENSITY 8 default (1-15) — za termal transfer ribbon
 *   - SPEED 4 (1-12 ips) za balans brzina/kvalitet
 *   - TEXT komanda: koordinate u dots; pomnoži mm sa 11.81 i zaokruži
 *   - BARCODE komanda: 128M auto-mode CODE128 sa ručnim FNC1 ako treba
 *
 * @typedef {object} TspLabelSpec
 * @property {{ brojPredmeta?: string, komitent?: string, nazivPredmeta?: string,
 *   nazivDela?: string, brojCrteza?: string, kolicina?: string,
 *   materijal?: string, datum?: string }} fields
 * @property {string} barcodeValue RNZ payload (npr. "RNZ:0:7351/1088:0:0")
 * @property {number} [copies=1] Koliko identičnih nalepnica štampati u nizu
 */

const DOTS_PER_MM = 11.81; /* ML340P 300 DPI */

/** Konvertuj mm u dots (ceo broj). */
const mm = v => Math.round(v * DOTS_PER_MM);

/**
 * Sanitizuj string za TSPL2 TEXT komandu — TSC firmware očekuje CP1250
 * (Centralna Evropa) za ćirilicu/latinicu sa dijakriticima, ali default
 * codepage u ML340P je 850 (Latin-1). Da ne ulazimo u code-page rat sa
 * konkretnim firmware-om svakog uređaja, transliterujemo dijakritike u
 * ASCII parnjak (š→s, č→c, ć→c, ž→z, đ→dj). Ovo je dovoljno čitljivo na
 * 80mm nalepnici i radi sa default font-om.
 *
 * @param {string} s
 * @returns {string}
 */
function asciiTranslit(s) {
  if (s == null) return '';
  return String(s)
    .replace(/š/g, 's').replace(/Š/g, 'S')
    .replace(/č/g, 'c').replace(/Č/g, 'C')
    .replace(/ć/g, 'c').replace(/Ć/g, 'C')
    .replace(/ž/g, 'z').replace(/Ž/g, 'Z')
    .replace(/đ/g, 'dj').replace(/Đ/g, 'Dj')
    .replace(/[„"]/g, '"')
    .replace(/[—–]/g, '-')
    .replace(/[^\x20-\x7E]/g, '?'); /* zameni sve ne-ASCII upitnikom */
}

/**
 * Esc-uj literal za TSPL2 string parametar:
 *   - obmotaj duple navodnike
 *   - zameni interne navodnike (TSPL2 nema escape sequence — koristimo
 *     `'` umesto `"` kao bezopasnu zamenu).
 *
 * @param {string} s
 */
function tsplStr(s) {
  const a = asciiTranslit(s).replace(/"/g, "'");
  return `"${a}"`;
}

/**
 * Generiše kompletan TSPL2 program za jednu TP nalepnicu (80×50mm portrait,
 * tekst gore + horizontalni CODE128 barkod dole full-width).
 *
 * Layout (mm, koordinatni sistem TSPL2: 0,0 = gornji-levi):
 *   ┌─────────────────────────── 80mm ─────────────────────────┐
 *   │ 1.5mm padding                                            │
 *   │ ┌──────────────────────────────────────────────────────┐ │
 *   │ │ Broj predmeta:      <vrednost>             font 24pt │ │ y=2mm
 *   │ │ Komitent:           <vrednost>             font 16pt │ │ y=8mm
 *   │ │ Naziv predmeta:     <vrednost>             font 12pt │ │ y=12mm
 *   │ │ Naziv dela:         <vrednost>             font 12pt │ │ y=15mm
 *   │ │ Broj crteža:        <vrednost>  Kol: x/y   font 14pt │ │ y=18mm
 *   │ │ Materijal:          <vrednost>  Datum: ddmmyy        │ │ y=22mm
 *   │ ├──────────────────────────────────────────────────────┤ │
 *   │ │                                                      │ │ y=26mm
 *   │ │            ║║║│║║│║│║║║║│║║║│║║│║║║║│║║║│║║          │ │ barkod
 *   │ │                  CODE128, ~22mm visine                │ │ y=46mm
 *   │ └──────────────────────────────────────────────────────┘ │
 *   └──────────────────────────────────────────────────────────┘
 *
 * Quiet zone: 2mm leve i desne strane barkoda (TSPL2 BARCODE komanda
 * ne ubacuje quiet zone sama — moramo ručno).
 *
 * @param {TspLabelSpec} spec
 * @returns {string} Multi-line TSPL2 program; svaka komanda na svom redu sa CRLF.
 */
export function buildTspLabelProgram(spec) {
  const f = spec?.fields || {};
  const bc = String(spec?.barcodeValue || '').trim();
  const copies = Math.max(1, Math.floor(Number(spec?.copies) || 1));

  if (!bc) {
    throw new Error('buildTspLabelProgram: barcodeValue je obavezan');
  }

  const lines = [];
  /* ── Setup ─────────────────────────────────────────────────────── */
  lines.push('SIZE 80 mm, 50 mm');
  lines.push('GAP 3 mm, 0 mm');
  lines.push('DIRECTION 1');
  lines.push('REFERENCE 0,0');
  lines.push('OFFSET 0 mm');
  lines.push('SET TEAR ON');
  lines.push('DENSITY 8');
  lines.push('SPEED 4');
  lines.push('CODEPAGE 1252');
  lines.push('CLS');

  /* ── Tekst (gore) ──────────────────────────────────────────────────
   * TSC font ID 3 = scalable; xMul/yMul množioci 1-10. Koordinate u dots.
   * Sve TEXT pozicije računamo kao mm × DOTS_PER_MM. */

  const PAD_X = mm(1.5); /* leva margina */

  /* Broj predmeta — najveći, dominantan na vrhu */
  if (f.brojPredmeta) {
    lines.push(`TEXT ${PAD_X},${mm(1.5)},"4",0,1,1,${tsplStr('RN: ' + f.brojPredmeta)}`);
  }

  /* Komitent (drugi red) */
  if (f.komitent) {
    lines.push(`TEXT ${PAD_X},${mm(7)},"3",0,1,1,${tsplStr('Komitent: ' + f.komitent)}`);
  }

  /* Naziv predmeta */
  if (f.nazivPredmeta) {
    const v = (f.nazivPredmeta || '').slice(0, 50);
    lines.push(`TEXT ${PAD_X},${mm(11)},"2",0,1,1,${tsplStr('Predmet: ' + v)}`);
  }

  /* Naziv dela */
  if (f.nazivDela) {
    const v = (f.nazivDela || '').slice(0, 50);
    lines.push(`TEXT ${PAD_X},${mm(14.5)},"2",0,1,1,${tsplStr('Deo: ' + v)}`);
  }

  /* Crtež + količina u istom redu */
  const crLine = [];
  if (f.brojCrteza) crLine.push('Crtez: ' + f.brojCrteza);
  if (f.kolicina) crLine.push('Kol: ' + f.kolicina);
  if (crLine.length) {
    lines.push(`TEXT ${PAD_X},${mm(18)},"3",0,1,1,${tsplStr(crLine.join('  |  '))}`);
  }

  /* Materijal + datum u istom redu */
  const matLine = [];
  if (f.materijal) matLine.push('Mat: ' + (f.materijal || '').slice(0, 30));
  if (f.datum) matLine.push('Dat: ' + f.datum);
  if (matLine.length) {
    lines.push(`TEXT ${PAD_X},${mm(22)},"2",0,1,1,${tsplStr(matLine.join('  |  '))}`);
  }

  /* ── Barkod (dole, full-width) ─────────────────────────────────────
   * BARCODE x,y,"128M",height,human_readable,rotation,narrow,wide,content
   *   - 128M = CODE128 sa auto-subset switching (najefikasnije za mešovit sadržaj)
   *   - height u dots
   *   - human_readable=2 = ispod barkoda upiši text (kao backup čitanja golim okom)
   *   - narrow=2 dots (~0.17mm) → modul width za 300 DPI; daje guste, ali oštre crte
   *
   * Quiet zone: leva margina 2mm = mm(2) dots; pošto je SIZE 80mm a barkod
   * širina ~76mm, ostaje 2mm desno = OK.
   */
  const BC_X = mm(2);
  const BC_Y = mm(26);
  const BC_H = mm(18); /* visina samog barkoda; +2.5mm za HR text ispod */
  lines.push(`BARCODE ${BC_X},${BC_Y},"128M",${BC_H},2,0,2,4,${tsplStr(bc)}`);

  /* ── Štampaj ───────────────────────────────────────────────────── */
  lines.push(`PRINT ${copies},1`);

  return lines.join('\r\n') + '\r\n';
}

/**
 * Generiše TSPL2 program za nalepnicu police (CODE128 = `location_code`).
 * Kraći, jednostavniji layout: veliki tekst sa kodom + barkod ispod.
 *
 * @param {{ location_code: string, name?: string, copies?: number }} loc
 * @returns {string}
 */
export function buildTspShelfLabelProgram(loc) {
  const code = String(loc?.location_code || '').trim();
  const name = String(loc?.name || '').trim();
  const copies = Math.max(1, Math.floor(Number(loc?.copies) || 1));
  if (!code) throw new Error('buildTspShelfLabelProgram: location_code obavezan');

  const lines = [];
  lines.push('SIZE 80 mm, 50 mm');
  lines.push('GAP 3 mm, 0 mm');
  lines.push('DIRECTION 1');
  lines.push('DENSITY 8');
  lines.push('SPEED 4');
  lines.push('CODEPAGE 1252');
  lines.push('CLS');

  /* Veliki tekst sa kodom — operator vidi i golim okom */
  lines.push(`TEXT ${mm(2)},${mm(2)},"5",0,1,1,${tsplStr(code)}`);
  if (name) {
    lines.push(`TEXT ${mm(2)},${mm(13)},"2",0,1,1,${tsplStr(name.slice(0, 50))}`);
  }
  /* Barkod horizontalan ispod, full width minus 2mm svake strane */
  lines.push(`BARCODE ${mm(2)},${mm(20)},"128M",${mm(22)},2,0,3,5,${tsplStr(code)}`);

  lines.push(`PRINT ${copies},1`);
  return lines.join('\r\n') + '\r\n';
}
