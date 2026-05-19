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
 * TSC QRCODE helper: konservativna širina u modulima (kratak štampani string ili duži `LP:…`).
 *
 * @param {number} encodingLength
 */
function tspEstimateQrSymbolSideModules(encodingLength) {
  const n = Math.max(0, Math.floor(Number(encodingLength) || 0));
  /* Gornji limit da ne zgnječimo simbol koji je veći od procene. */
  if (n <= 17) return 25;
  if (n <= 32) return 29;
  if (n <= 48) return 33;
  if (n <= 66) return 41;
  if (n <= 84) return 53;
  if (n <= 110) return 57;
  return 61;
}

/**
 * Preferirani cell širinski za QR (automatski se smanjuje kad tekst ima mnogo karaktera).
 *
 * @param {string} encode
 */
function tspShelfQrPreferCellDots(encode) {
  const units = [...String(encode || '')].length;
  if (units >= 70) return 5;
  if (units >= 42) return 6;
  if (units >= 24) return 7;
  return 8;
}

/**
 * @param {string} encode
 * @returns {{ xDots: number, cellDots: number }}
 */
function tspShelfQrLayoutDots(encode) {
  const enc = String(encode || '');
  const chars = [...enc].length;
  /** @type {number} */
  let side = tspEstimateQrSymbolSideModules(chars);
  /** @type {number} */
  let cellDots = tspShelfQrPreferCellDots(enc);
  const paperDots = mm(80.34);
  /** Najveća dozvoljena širina simbola (~2 mm od obe ivice narivnice). */
  const maxDots = paperDots - mm(4);
  /*
   * (side + 8) ~= moduli strane + TIŠINA; smanjuj cell dok ceo simbol statično stane po širini.
   * Ako i dalje ne stane procenu strane konservativno uvećavamo što smanjuje cell pritisak.
   */
  let guard = 0;
  while (guard++ < 14 && cellDots * (side + 8) > maxDots && cellDots > 3) {
    cellDots -= 1;
  }
  const totalDots = cellDots * (side + 8);
  let xDots = Math.round((paperDots - Math.min(totalDots, maxDots)) / 2);
  if (!Number.isFinite(xDots)) xDots = mm(2);
  xDots = Math.max(mm(1.5), Math.min(mm(42), xDots));
  return { xDots, cellDots };
}
/**
 * Generiše TSPL za nalepnicu police: CODE128 ili QR plus jedan red teksta (`HALA_CODE - SHELF_CODE`).
 * **NE šalje SIZE/GAP/DENSITY**.
 *
 * @param {{ location_code?: string, copies?: number, codeType?: 'barcode'|'qr',
 *   barcodeValue?: string, labelFootline?: string }} loc
 *   `labelFootline` tekst reda ispod grafike (isti kao na ekranu / PDF-u).
 */
export function buildTspShelfLabelProgram(loc) {
  const encode = String(loc?.barcodeValue ?? loc?.location_code ?? '').trim();
  const footRaw = loc?.labelFootline ?? loc?.barcodeValue ?? loc?.location_code;
  const foot = String(footRaw ?? '').trim();
  const copies = Math.max(1, Math.floor(Number(loc?.copies) || 1));
  const codeType = loc?.codeType === 'qr' ? 'qr' : 'barcode';
  if (!encode) throw new Error('buildTspShelfLabelProgram: štampani barkod / šifra obavezni');

  const lines = [];
  lines.push('CLS');

  if (codeType === 'qr') {
    const { xDots, cellDots } = tspShelfQrLayoutDots(encode);
    lines.push(`QRCODE ${xDots},${mm(2)},L,${cellDots},A,0,M2,${tsplStr(encode)}`);
  } else {
    lines.push(`BARCODE ${mm(2)},${mm(2)},"128M",${mm(22)},0,0,2,5,${tsplStr(encode)}`);
  }

  if (foot) {
    const yText = codeType === 'qr' ? mm(30.5) : mm(26.5);
    lines.push(`TEXT ${mm(2)},${yText},"3",0,1,1,${tsplStr(truncFit(foot, 46))}`);
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

/**
 * TSPL2 nalepnica ručnog alata (80.34×40.3mm, isti profil kao rezni).
 * NE šalje SIZE/GAP/DENSITY.
 *
 * @param {{ barcode: string, oznaka?: string, naziv?: string, asset_kind?: string,
 *   serial?: string, copies?: number }} tool
 * @returns {string}
 */
export function buildTspHandToolLabelProgram(tool) {
  const barcode = String(tool?.barcode || '').trim();
  if (!barcode) throw new Error('buildTspHandToolLabelProgram: barcode je obavezan');

  const oznaka = String(tool?.oznaka || '').trim();
  const naziv = String(tool?.naziv || '').trim();
  const assetKind = String(tool?.asset_kind || '').trim();
  const serial = String(tool?.serial || tool?.serijski_broj || '').trim();
  const copies = Math.max(1, Math.floor(Number(tool?.copies) || 1));

  const lines = [];
  lines.push('CLS');

  if (oznaka) {
    lines.push(`TEXT ${mm(2)},${mm(1)},"4",0,1,1,${tsplStr(truncFit(oznaka, 22))}`);
  }
  if (naziv) {
    lines.push(`TEXT ${mm(2)},${mm(6)},"2",0,1,1,${tsplStr(truncFit(naziv, 38))}`);
  }
  const kindLine = [assetKind, serial].filter(Boolean).join(': ');
  if (kindLine) {
    lines.push(`TEXT ${mm(2)},${mm(10)},"1",0,1,1,${tsplStr(truncFit(kindLine, 42))}`);
  }

  const BC_X = mm(2);
  const BC_Y = mm(22);
  const BC_H = mm(14);
  lines.push(`BARCODE ${BC_X},${BC_Y},"128M",${BC_H},1,0,2,4,${tsplStr(barcode)}`);

  lines.push(`PRINT ${copies},1`);
  return lines.join('\r\n') + '\r\n';
}

/**
 * Mini nalepnica 30×15mm (glodačke pločice). Pretpostavlja da je štampač već
 * podešen na 30×15 u TSC admin-u — NE šalje SIZE/GAP/DENSITY.
 *
 * @param {{ barcode: string, oznaka?: string, klasa?: string, copies?: number }} spec
 * @returns {string}
 */
export function buildTspMiniInsertLabelProgram(spec) {
  const barcode = String(spec?.barcode || '').trim();
  if (!barcode) throw new Error('buildTspMiniInsertLabelProgram: barcode je obavezan');

  const oznaka = String(spec?.oznaka || '').trim();
  const klasa = String(spec?.klasa || '').trim();
  const copies = Math.max(1, Math.floor(Number(spec?.copies) || 1));

  const lines = [];
  lines.push('CLS');

  if (oznaka) {
    lines.push(`TEXT ${mm(1)},${mm(0.5)},"2",0,1,1,${tsplStr(truncFit(oznaka, 14))}`);
  }
  if (klasa && klasa !== oznaka) {
    lines.push(`TEXT ${mm(1)},${mm(3)},"1",0,1,1,${tsplStr(truncFit(klasa, 18))}`);
  }

  const BC_X = mm(1);
  const BC_Y = mm(6);
  const BC_H = mm(8);
  lines.push(`BARCODE ${BC_X},${BC_Y},"128M",${BC_H},0,0,2,3,${tsplStr(barcode)}`);

  lines.push(`PRINT ${copies},1`);
  return lines.join('\r\n') + '\r\n';
}
