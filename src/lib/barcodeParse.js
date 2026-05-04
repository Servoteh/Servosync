/**
 * Pure helper-i za barcode tekst — bez kamera/ZXing zavisnosti.
 * Razlog izdvajanja: `src/services/barcode.js` importuje `@zxing/browser` na
 * top-level, što je skup (~250KB gzip). Parsing logiku testiramo odvojeno
 * u Vitest-u bez jsdom/DOM stub-ova.
 */

/**
 * Očisti sirov tekst barkoda u `item_ref_id` kandidat:
 *   - trim whitespace
 *   - skini CR/LF/TAB (često dolaze na kraju Code39/128)
 *   - skini Code39 `*...*` delimitere (ako čitač nije sam)
 *
 * @param {string} raw
 * @returns {string}
 */
export function normalizeBarcodeText(raw) {
  if (typeof raw !== 'string') return '';
  let t = raw.replace(/[\r\n\t]+/g, '').trim();
  if (t.startsWith('*') && t.endsWith('*') && t.length >= 3) {
    t = t.slice(1, -1);
  }
  return t;
}

/**
 * @typedef {object} ParsedBarcode
 * @property {string} orderNo Broj radnog naloga (npr. "7351").
 * @property {string} itemRefId Kompozitni ili prost identifikator stavke
 *   koji ide u `loc_item_placements.item_ref_id`:
 *     - RNZ format → TP ref (npr. "1088" ili alfanumerički "7-5-S1");
 *     - short format → broj crteža (legacy, npr. "1091063").
 * @property {string} drawingNo Broj crteža ako je u barkodu (short format);
 *   u RNZ formatu je prazno jer barkod ne sadrži crtež — čita se sa teksta
 *   nalepnice ili se auto-popunjava iz prethodnih placement-a.
 * @property {'rnz'|'short'|'ocr'} format Koji je format prepoznat (`ocr` = tekst sa nalepnice).
 * @property {string} raw Originalni očišćeni tekst.
 * @property {string} [idrn] RNZ: interni ID dokumenta (prvi broj posle RNZ:).
 * @property {string} [varijanta] RNZ: segment posle TP.
 * @property {string} [field4] RNZ: poslednji numerički segment (npr. Windows timer u štampi).
 */

/**
 * Parsiraj BigTehn barkod iz jednog od dva potvrđena formata.
 *
 * **Format A — RNZ (trenutno u produkciji):**
 *   `RNZ:8693:7351/1088:0:39757` ili `RNZ:9833:9400/7-5-S1:1:44963`
 *     - `RNZ`          prefix (konstantan)
 *     - `8693`         interni BigTehn ID (`idrn`) — čuva se, UI ga ne mora koristiti
 *     - `7351/1088`    **broj naloga / TP ref** (`itemRefId` može biti alfanumerički + `.-_`)
 *     - `0:39757`      `varijanta` i `field4` — čuvaju se; crtež i dalje iz ERP-a
 *
 *   U ovom formatu broj crteža NIJE u barkodu — samo na štampanom tekstu
 *   nalepnice. Parser vraća `drawingNo = ''`; UI ga auto-popunjava iz
 *   prethodnih placement-a za isti (order_no, item_ref_id) par, ili ga
 *   radnik prepisuje ručno sa teksta.
 *
 * **Format B — short (legacy, manje nalepnica):**
 *   `9000/1091063` → nalog `9000`, crtež `1091063`
 *
 * Oba formata vraćaju istu strukturu; polje `format` kaže koji je bio.
 *
 * @param {string} raw
 * @returns {ParsedBarcode | null}
 *   `null` ako ni jedan format ne odgovara.
 */
export function parseBigTehnBarcode(raw) {
  const clean = normalizeBarcodeText(raw);
  if (!clean) return null;

  /* RNZ format — isprobava se PRVI jer je stroža regex (mora da počne sa RNZ:).
   *
   * PRE (regresija alfanumeričkog TP): drugi segment posle `/` je bio samo \d{1,8},
   *   npr. /^RNZ\s*[:|]\s*\d{1,10}\s*[:|]\s*(\d{1,8})\s*[/\\\-_ ]\s*(\d{1,8})\s*[:|]\s*\d+\s*[:|]\s*\d+\s*$/i
   *   → ne prolazi za TP "7-5-S1".
   */
  const rnz = clean.match(
    /^RNZ\s*[:|]\s*(\d{1,10})\s*[:|]\s*(\d{1,8})\s*[/\\\-_ ]\s*([A-Za-z0-9._-]{1,64})\s*[:|]\s*(\d+)\s*[:|]\s*(\d+)\s*$/i,
  );
  if (rnz) {
    const [, idrn, orderNo, itemRefId, varijanta, field4] = rnz;
    return {
      orderNo,
      itemRefId,
      drawingNo: '',
      format: 'rnz',
      raw: clean,
      idrn,
      varijanta,
      field4,
    };
  }

  /* Short format — zadržavamo kao fallback za stare nalepnice ako ih
   * negde ima. Dozvoljavamo varijacije razdvajača (`/`, `\`, `-`, `_`,
   * razmak) jer neki čitači menjaju `/` keyboard layout-om. */
  const short = clean.match(/^(\d{1,8})\s*[/\\\-_ ]\s*(\d{1,10})$/);
  if (short) {
    const [, orderNo, drawingNo] = short;
    return {
      orderNo,
      itemRefId: drawingNo,
      drawingNo,
      format: 'short',
      raw: clean,
    };
  }

  return null;
}

/**
 * Iz sirovog OCR teksta (nalepnica: „Broj predmeta / Tehnološki postupak”)
 * izvuci par nalog/TP oblika `7351/1088`. Koristi se kada barkod ne čita.
 *
 * @param {string} raw
 * @returns {ParsedBarcode | null} `format: 'ocr'`, isti shape kao RNZ za ERP/autofill
 */
export function parsePredmetTpFromLabelText(raw) {
  if (typeof raw !== 'string') return null;
  const t = raw.replace(/\u00a0/g, ' ').trim();
  if (!t) return null;

  const tryMatch = (s, pattern) => {
    const m = s.match(pattern);
    if (!m) return null;
    const orderNo = m[1].replace(/\D/g, '').slice(0, 8);
    const tp = m[2].replace(/\D/g, '').slice(0, 8);
    if (!orderNo || !tp) return null;
    return {
      orderNo,
      itemRefId: tp,
      drawingNo: '',
      format: /** @type {'ocr'} */ ('ocr'),
      raw: `${orderNo}/${tp}`,
    };
  };

  /* Tipičan OCR: cifre + razdvajač (/ \\ - | I l) + cifre */
  const sep = '[/\\\\\\-_|Il]{1,4}';
  const core = new RegExp(`(\\d{1,8})\\s*${sep}\\s*(\\d{1,8})`, 'i');

  const blocks = [t, ...t.split(/[\r\n]+/)];
  for (const block of blocks) {
    const hit = tryMatch(block, core);
    if (hit) return hit;
  }

  /* Retki slučaj: OCR slomi kosu crtu — dva broja u istoj liniji posle „7351“ */
  const loose = t.match(/\b(\d{3,8})\s+(\d{2,8})\b/g);
  if (loose) {
    for (const frag of loose) {
      const m = frag.match(/\b(\d{3,8})\s+(\d{2,8})\b/);
      if (m) {
        const orderNo = m[1].slice(0, 8);
        const tp = m[2].slice(0, 8);
        if (orderNo.length >= 3 && tp.length >= 2) {
          return {
            orderNo,
            itemRefId: tp,
            drawingNo: '',
            format: 'ocr',
            raw: `${orderNo}/${tp}`,
          };
        }
      }
    }
  }

  return null;
}

/**
 * Generiši RNZ barkod kompatibilan sa {@link parseBigTehnBarcode}.
 *
 * @param {{ internalId?: string|number, orderNo: string|number, tpNo: string|number, segment3?: string|number, segment4?: string|number }} args
 * @returns {string|null}
 */
export function formatBigTehnRnzBarcode({
  internalId = '0',
  orderNo,
  tpNo,
  segment3 = '0',
  segment4 = '0',
} = {}) {
  if (orderNo == null || tpNo == null) return null;
  const a = String(internalId).replace(/\D/g, '').slice(0, 10) || '0';
  const o = String(orderNo).replace(/\D/g, '').slice(0, 8);
  const t = String(tpNo).replace(/\D/g, '').slice(0, 8);
  const s3 = String(segment3).replace(/\D/g, '').slice(0, 12) || '0';
  const s4 = String(segment4).replace(/\D/g, '').slice(0, 12) || '0';
  if (!o || !t) return null;
  return `RNZ:${a}:${o}/${t}:${s3}:${s4}`;
}

/**
 * Kratki format `NALOG/CRTEŽ` (legacy BigTehn).
 *
 * @param {string|number} orderNo
 * @param {string|number} drawingNo
 * @returns {string|null}
 */
export function formatBigTehnShortBarcode(orderNo, drawingNo) {
  if (orderNo == null || drawingNo == null) return null;
  const o = String(orderNo).replace(/\D/g, '').slice(0, 8);
  const d = String(drawingNo).replace(/\D/g, '').slice(0, 10);
  if (!o || !d) return null;
  return `${o}/${d}`;
}
