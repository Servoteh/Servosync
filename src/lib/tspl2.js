/**
 * TSPL2 command generator za TSC termalne štampače (ML340P, 300 DPI).
 *
 * **VAŽNO — printer-side configuration je READ-ONLY:**
 *
 * Štampač TSC ML340P u pogonu već ima konfigurisane:
 *   - Paper Width:  80.34 mm
 *   - Paper Height: 40.30 mm
 *   - Gap Size:     3.05 mm
 *   - Print Method: Direct-Thermal
 *   - Sensor:       Continuous (gap)
 *
 * Ova podešavanja su urađena kroz TSC web admin (http://192.168.70.20).
 * Ako pošaljemo `SIZE`, `GAP`, `DIRECTION`, `DENSITY`, `SPEED`, `CODEPAGE`
 * ili `SET TEAR` komande, štampač PIŠE preko ovih vrednosti i može da
 * uđe u blocked stanje (operater javio da se "blokira"). Zato u našem
 * generisanom programu šaljemo SAMO komande koje crtaju sadržaj:
 *
 *   CLS         — briše print buffer (NE menja konfiguraciju)
 *   TEXT        — crta tekst u tekućoj orijentaciji/kalibraciji
 *   BARCODE     — crta barkod
 *   PRINT       — šalje u feed
 *
 * **Layout (80.34mm × 40.3mm, koordinate u dots, 0,0 = gornji-levi):**
 *
 *   ┌───────────── 80.34 mm ──────────────┐
 *   │ Broj Predmeta      |     Komitent   │ y=1.0mm,  font 11pt
 *   │ Naziv predmeta (full width)         │ y=5.0mm,  font 7.2pt
 *   │ Naziv dela (full width)             │ y=8.0mm,  font 7.2pt
 *   │ Br. crteža         |    Materijal   │ y=11.0mm, font 7.2pt
 *   │ Količina 2/96      |    23-04-26    │ y=14.0mm, font 7.2pt
 *   │                                     │
 *   │ ║║│║║║│║│║║│║║║║│║│║║│║║║║│║║│║║│║║│ │ y=17.0mm, h=20mm, full-width
 *   │ ║║│║║║│║│║║│║║║║│║│║║│║║║║│║║│║║│║║│ │
 *   └─────────────────────────────────────┘
 *                40.3 mm
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
 * Sanitizuj string za TSPL2 TEXT komandu — TSC firmware očekuje konkretan
 * codepage. Pošto NE šaljemo `CODEPAGE` komandu (vidi top-of-file), oslanjamo
 * se na ono što je već konfigurisano u štampaču. Da budemo robusni
 * nezavisno od konfiguracije, transliterujemo dijakritike u ASCII parnjak
 * (š→s, č→c, ć→c, ž→z, đ→dj). Ovo je dovoljno čitljivo na 80mm nalepnici
 * i radi sa default font-om bez code-page nepoznanica.
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
    .replace(/[^\x20-\x7E]/g, '?');
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
 * Skrati string na max N karaktera bez prelamanja sredinom reči (jednostavno —
 * sečemo i dodajemo elipsu ako je predugačko, da se ne preklopi sa drugom
 * polovinom reda).
 *
 * @param {string} s
 * @param {number} n
 * @returns {string}
 */
function truncFit(s, n) {
  const v = String(s ?? '').trim();
  if (v.length <= n) return v;
  return v.slice(0, Math.max(0, n - 1)) + '…';
}

/**
 * Generiše TSPL2 program za jednu TP nalepnicu (80.34×40.3mm).
 * **NE šalje SIZE/GAP/DENSITY/SPEED/CODEPAGE komande** — ti parametri su
 * već konfigurisani u štampaču preko web admin-a (192.168.70.20).
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
  /* CLS čisti samo render buffer — ne menja paper size ni druge konfige. */
  lines.push('CLS');

  /* Konvencije za TSC font ID:
   *   "1" = 8x12 dots          (~6pt)
   *   "2" = 12x20 dots         (~8pt) — koristimo za sve obične redove
   *   "3" = 16x24 dots         (~10pt)
   *   "4" = 24x32 dots         (~12pt) — koristimo za naglašeni broj predmeta
   *   "5" = 32x48 dots         (~16pt)
   *   "8" TSS24.BF2 (TT)       — variabilni
   * TEXT sintaksa: x,y,"font",rotation,xMul,yMul,"text"
   * Koordinate u dots; rotation 0=normalno, 90/180/270 za rotaciju.
   */

  /* PAD_LEFT (7mm) = 2mm baseline + 5mm operaterski shift udesno (zahtev:
   * pomeri sav sadrzaj 5mm udesno na TL340P bez diranja driver-a).
   * RIGHT_HALF_X = 41 + 5 = 46mm zadrzava odnos leve i desne polovine.
   * TSPL2 path ne ide kroz Chrome i ne pati od istog kalibracionog
   * offseta kao browser print. */
  const PAD_LEFT = mm(7);
  const RIGHT_HALF_X = mm(46);

  /* ─ Visina budžeta (40.30mm fizički):
   *   y=0.5mm pad
   *   y=0.5mm  Red 1 (RN, font "4" ~4mm)
   *   y=4.5mm  Red 2 (Predmet, font "2" ~2.5mm)
   *   y=7.0mm  Red 3 (Deo)
   *   y=9.5mm  Red 4 (Crtez | Materijal)
   *   y=12.0mm Red 5 (Kol | Datum)
   *   y=14.8mm Barkod start, h=15mm → ends y=29.8mm
   *   pad bottom: 40.30 - 29.8 = 10.5mm rezerve (više nego dovoljno)
   * Hard ograničavamo barkod na 15mm da niko nikad ne pređe ivicu. */

  /* ─ Red 1: Broj Predmeta (levo, naglašen) | Komitent (desno) ─ */
  if (f.brojPredmeta) {
    lines.push(`TEXT ${PAD_LEFT},${mm(0.5)},"4",0,1,1,${tsplStr(truncFit(f.brojPredmeta, 16))}`);
  }
  if (f.komitent) {
    lines.push(`TEXT ${RIGHT_HALF_X},${mm(1.2)},"2",0,1,1,${tsplStr(truncFit(f.komitent, 24))}`);
  }

  /* ─ Red 2: Naziv predmeta (full width, max ~74mm = ~58 char na font "2") ─ */
  if (f.nazivPredmeta) {
    lines.push(`TEXT ${PAD_LEFT},${mm(4.5)},"2",0,1,1,${tsplStr(truncFit(f.nazivPredmeta, 58))}`);
  }

  /* ─ Red 3: Naziv dela (full width) ─ */
  if (f.nazivDela) {
    lines.push(`TEXT ${PAD_LEFT},${mm(7)},"2",0,1,1,${tsplStr(truncFit(f.nazivDela, 58))}`);
  }

  /* ─ Red 4: Broj crteža (levo) | Materijal (desno) ─ */
  if (f.brojCrteza) {
    lines.push(`TEXT ${PAD_LEFT},${mm(9.5)},"2",0,1,1,${tsplStr('Crtez: ' + truncFit(f.brojCrteza, 16))}`);
  }
  if (f.materijal) {
    lines.push(`TEXT ${RIGHT_HALF_X},${mm(9.5)},"2",0,1,1,${tsplStr(truncFit(f.materijal, 24))}`);
  }

  /* ─ Red 5: Količina (levo) | Datum (desno) ─ */
  if (f.kolicina) {
    lines.push(`TEXT ${PAD_LEFT},${mm(12)},"2",0,1,1,${tsplStr('Kol: ' + truncFit(f.kolicina, 16))}`);
  }
  if (f.datum) {
    lines.push(`TEXT ${RIGHT_HALF_X},${mm(12)},"2",0,1,1,${tsplStr(f.datum)}`);
  }

  /* ─ Barkod (dole, ofsetovan 5mm udesno isto kao tekst — vidi PAD_LEFT) ─
   * BARCODE x,y,"128M",height,human_readable,rotation,narrow,wide,content
   *   - height = 15mm → 177 dots (smanjeno sa 20mm da apsolutno stane)
   *   - human_readable=0 = bez teksta ispod (RN je gore u Redu 1)
   *   - narrow=2 dots (~0.17mm) → modul width za 300 DPI
   *
   * Quiet zone: leva 7mm + barkod ~71mm + desna ~2mm = OK (CODE128 minimum
   * je 10× narrow-modul width = ~1.7mm, a 2mm prelazi taj limit).
   */
  const BC_X = mm(7);
  const BC_Y = mm(14.8);
  const BC_H = mm(15);
  lines.push(`BARCODE ${BC_X},${BC_Y},"128M",${BC_H},0,0,2,4,${tsplStr(bc)}`);

  /* ─ TIP operacije (opciono) — S/O/Z → SKLOP/OBRADA/ZAVARIVANJE ─
   * Pozicija: y=30.5mm (barkod zavrsava na 29.8mm; ostavi 0.7mm gap).
   * Font "4" (~12pt, 4mm visine) → end y≈34.5mm; nalepnica je 40.3mm.
   * Levo poravnano sa PAD_LEFT-om (vec ofsetovano 5mm zbog operaterskog
   * pomaka udesno — vidi gore). */
  const tipMap = { S: 'SKLOP', O: 'OBRADA', Z: 'ZAVARIVANJE' };
  const tipLabel = tipMap[String(f.tipOperacije || '').trim().toUpperCase()];
  if (tipLabel) {
    lines.push(`TEXT ${PAD_LEFT},${mm(30.5)},"4",0,1,1,${tsplStr(tipLabel)}`);
  }

  /* ─ Pošalji u feed ─ */
  lines.push(`PRINT ${copies},1`);

  return lines.join('\r\n') + '\r\n';
}

/**
 * Generiše TSPL2 program za nalepnicu police.
 * **NE šalje SIZE/GAP/DENSITY** — koristi konfiguraciju štampača.
 *
 * Layout (kod GORE, šifra DOLE — operater traženo 2026-05):
 *   ┌───────── 80.34mm ─────────┐
 *   │  ║║│║║║│║│║║║│ ili [QR]    │  y=1.5mm  h≈26mm (kod — veći trag za dug LP payload)
 *   │                            │
 *   │       R-A-001              │  y≈29.5mm   font "5" (krupno)
 *   │   Magacin · Polica         │  y≈36mm    font "2" (sitno)
 *   └────────────────────────────┘
 *               40.3mm
 *
 * @param {{ location_code: string, name?: string, copies?: number, codeType?: 'barcode'|'qr',
 *   barcodeValue?: string, labelPrimary?: string }} loc
 *   `barcodeValue` — štampani kod (npr. `LP:<hala_uuid>:<polica_uuid>`); ako izostaje, ostaje šifra police.
 * @returns {string}
 */
export function buildTspShelfLabelProgram(loc) {
  const encode = String(loc?.barcodeValue ?? loc?.location_code ?? '').trim();
  const primaryRaw = String(loc?.labelPrimary ?? loc?.location_code ?? encode).trim();
  const primary = primaryRaw || encode;
  const name = String(loc?.name || '').trim();
  const copies = Math.max(1, Math.floor(Number(loc?.copies) || 1));
  const codeType = loc?.codeType === 'qr' ? 'qr' : 'barcode';
  if (!encode) throw new Error('buildTspShelfLabelProgram: štampani barkod / šifra obavezni');

  const lines = [];
  lines.push('CLS');

  /* Kod GORE: barkod (full-width 76mm × 22mm) ili QR (~22×22mm centriran). */
  if (codeType === 'qr') {
    /* QRCODE x,y,ECC,cell_width,mode,rotation,model,mask,"data"
     *   ECC=M (~15% recovery), cell_width=8 dots (~0.7mm) → ~22×22mm za "R-A-001" length
     *   Centriraj horizontalno: x = (80 - 22) / 2 = 29mm */
    lines.push(`QRCODE ${mm(29)},${mm(1.5)},M,8,A,0,M2,${tsplStr(encode)}`);
  } else {
    /* Barkod horizontalan — veća geometrijska visina da debeli LP Code128 ostane čitljiv na termalnoj traci */
    lines.push(`BARCODE ${mm(2)},${mm(1.5)},"128M",${mm(26)},0,0,2,5,${tsplStr(encode)}`);
  }

  /* Hala · polica ili šifra DOLE — krupno (font "5" ≈ 16pt) */
  lines.push(`TEXT ${mm(2)},${mm(29.5)},"5",0,1,1,${tsplStr(truncFit(primary, 22))}`);
  if (name) {
    lines.push(`TEXT ${mm(2)},${mm(36)},"2",0,1,1,${tsplStr(truncFit(name, 60))}`);
  }

  lines.push(`PRINT ${copies},1`);
  return lines.join('\r\n') + '\r\n';
}

/**
 * Generiše TSPL2 program za nalepnicu reznog alata (Sprint RZ-2).
 *
 * Layout (80.34×40.3mm):
 *   ┌───────────────────────────────────────┐
 *   │ RZN-000123                            │  y=1.5mm  font "5" — barkod (čitljiv)
 *   │ Glodalo HSS D12                       │  y=9mm    font "3" — naziv
 *   │ Klasa: glodalo                        │  y=13mm   font "2" — klasa
 *   │ Mašine: 8.3, 10.1                     │  y=16mm   font "2" — kompatibilne mašine
 *   │ ║║│║║║│║│║║│║║║║│║│║║│║║║║│║║│║║│║║│   │  y=19.5mm h=18mm — Code128 barkod
 *   └───────────────────────────────────────┘
 *
 * @param {{ barcode: string, oznaka?: string, naziv?: string, klasa?: string,
 *   compatible_machine_codes?: string[], copies?: number }} tool
 * @returns {string}
 */
export function buildTspCuttingToolLabelProgram(tool) {
  const barcode = String(tool?.barcode || '').trim();
  if (!barcode) throw new Error('buildTspCuttingToolLabelProgram: barcode je obavezan');

  const oznaka = String(tool?.oznaka || '').trim();
  const naziv = String(tool?.naziv || '').trim();
  const klasa = String(tool?.klasa || '').trim();
  const machines = Array.isArray(tool?.compatible_machine_codes)
    ? tool.compatible_machine_codes.filter(Boolean).join(', ')
    : '';
  const copies = Math.max(1, Math.floor(Number(tool?.copies) || 1));

  const lines = [];
  lines.push('CLS');

  /* ─ Red 1: barkod string (font "5" ~16pt) — čitljiv pored barkoda ─ */
  lines.push(`TEXT ${mm(2)},${mm(1.5)},"5",0,1,1,${tsplStr(truncFit(barcode, 18))}`);

  /* ─ Red 2: oznaka — ako se razlikuje od barkoda, prikaži je ─ */
  if (oznaka && oznaka !== barcode) {
    lines.push(`TEXT ${mm(46)},${mm(2.5)},"2",0,1,1,${tsplStr(truncFit(oznaka, 16))}`);
  }

  /* ─ Red 3: naziv (full width, font "3" ~10pt) ─ */
  if (naziv) {
    lines.push(`TEXT ${mm(2)},${mm(9)},"3",0,1,1,${tsplStr(truncFit(naziv, 38))}`);
  }

  /* ─ Red 4: klasa ─ */
  if (klasa) {
    lines.push(`TEXT ${mm(2)},${mm(13.5)},"2",0,1,1,${tsplStr('Klasa: ' + truncFit(klasa, 26))}`);
  }

  /* ─ Red 5: kompatibilne mašine ─ */
  if (machines) {
    lines.push(`TEXT ${mm(2)},${mm(16.5)},"2",0,1,1,${tsplStr('Masine: ' + truncFit(machines, 50))}`);
  }

  /* ─ Barkod horizontalan, full width minus 2mm svake strane, h=18mm ─ */
  const BC_X = mm(2);
  const BC_Y = mm(19.5);
  const BC_H = mm(18);
  lines.push(`BARCODE ${BC_X},${BC_Y},"128M",${BC_H},1,0,2,4,${tsplStr(barcode)}`);

  lines.push(`PRINT ${copies},1`);
  return lines.join('\r\n') + '\r\n';
}
