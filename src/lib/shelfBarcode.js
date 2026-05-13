/**
 * Nalepnica police za premestanje:
 * - **Štampa (novo):** kratak slog `ŠIFRA_HALE - ŠIFRA_POLICE` u CODE128 / QR.
 * - **Legacy štampa:** još uvek skenovanje `LP:<uuid_halе>:<uuid_police>`.
 */

import { isHallType, isShelfType } from './lokacijeTypes.js';

/** @typedef {{ ok: true, loc: object, presetHallFilterId: string } | { ok: false, msg: string }} ShelfCompositeResolve */

const LP_COMPOSITE =
  /^LP:([0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}):([0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$/i;

const UUID_HEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * @param {Map<string, object>|undefined} locById
 * @param {string} uuid
 * @returns {object|undefined}
 */
function mapGetUuid(locById, uuid) {
  if (!locById) return undefined;
  const u = String(uuid || '').trim();
  let v = locById.get(u);
  if (v) return v;
  const lower = u.toLowerCase();
  for (const [k, row] of locById) {
    if (String(k).toLowerCase() === lower) return row;
  }
  return undefined;
}

/**
 * @param {object} loc
 * @param {Map<string, object>} locById
 * @returns {string|null}
 */
export function nearestHallAncestorId(loc, locById) {
  if (!loc || !locById?.size) return null;
  let cur = loc;
  const seen = new Set();
  for (let i = 0; i < 64; i++) {
    if (!cur?.id || seen.has(cur.id)) return null;
    seen.add(cur.id);
    const pid = cur.parent_id ? String(cur.parent_id) : '';
    if (!pid) return null;
    const p = mapGetUuid(locById, pid);
    if (!p) return null;
    if (isHallType(p.location_type)) return String(p.id);
    cur = p;
  }
  return null;
}

/**
 * Jedan red kao vrednost grafike barkoda / QR.
 *
 * @param {string|null|undefined} hCode šifra halе (location_code)
 * @param {string|null|undefined} sCode šifra police
 */
export function formatShelfBarcodeHumanLine(hCode, sCode) {
  const h = String(hCode ?? '').trim();
  const s = String(sCode ?? '').trim();
  if (h && s) return `${h} - ${s}`;
  return s || h || '';
}

function codesInsensitiveEq(a, b) {
  return String(a ?? '').trim().toLowerCase() === String(b ?? '').trim().toLowerCase();
}

/**
 * Kratko `halaŠifra - policaŠifra` — prvi blok sa „ - “ deli hala|polica (Unicode crtice takođе).
 *
 * @param {string} t
 * @returns {{ hallCode: string, shelfCode: string } | null}
 */
export function parseShortShelfBarcodePair(t) {
  const raw = String(t || '').trim().replace(/\u2013|\u2014/g, '-');
  if (!raw || /^LP:/i.test(raw)) return null;
  const m = /^(.+?)\s+-\s+(.+)$/s.exec(raw.trim());
  if (!m) return null;
  const hallCode = m[1].trim();
  const shelfCode = m[2].trim();
  if (!hallCode || !shelfCode) return null;
  return { hallCode, shelfCode };
}

function locIsActiveShelfMatchingCode(l, needle) {
  return (
    l &&
    l.is_active !== false &&
    isShelfType(l.location_type) &&
    codesInsensitiveEq(l.location_code, needle)
  );
}

/**
 * @param {{ hallCode: string, shelfCode: string }} pair
 * @param {object[]} locs
 * @param {Map<string, object>} locById
 * @returns {ShelfCompositeResolve}
 */
export function resolveShortShelfBarcodePair(pair, locs, locById) {
  const hc = pair.hallCode.trim();
  const sc = pair.shelfCode.trim();
  const shelvesHit = locs.filter(l => locIsActiveShelfMatchingCode(l, sc));
  const narrowed = [];
  for (const sh of shelvesHit) {
    const hid = nearestHallAncestorId(sh, locById);
    if (!hid) continue;
    const hallLoc = mapGetUuid(locById, hid);
    if (!hallLoc || hallLoc.is_active === false || !isHallType(hallLoc.location_type)) continue;
    if (codesInsensitiveEq(hallLoc.location_code, hc)) narrowed.push(sh);
  }
  if (!narrowed.length) {
    return {
      ok: false,
      msg: 'Ne postoji aktivna polica za ovaj par (hala − polica) u master lokacija.',
    };
  }
  if (narrowed.length > 1) {
    return {
      ok: false,
      msg: 'Dvostruko poklapanje šifara u master-u — pojedinačne šifre moraju ostati jednoznačne.',
    };
  }
  const shelf = narrowed[0];
  const hidFinal = nearestHallAncestorId(shelf, locById);
  const hallLoc = hidFinal ? mapGetUuid(locById, hidFinal) : undefined;
  if (!hidFinal || !hallLoc?.id)
    return { ok: false, msg: 'Nadređena hala za ovu policu nedostaje u master-u.' };
  return {
    ok: true,
    loc: shelf,
    presetHallFilterId: String(hallLoc.id),
  };
}

/**
 * Samo kod police — ako je kod globalno jedinstven među SHELF/RACK/BIN aktivnim lokacijama.
 *
 * @param {string} code
 * @param {object[]} locs
 * @param {Map<string, object>} locById
 * @returns {ShelfCompositeResolve | null}
 */
function resolveShelfUniqueByShelfCodeGlobally(code, locs, locById) {
  const trimmed = String(code || '').trim();
  if (
    !trimmed ||
    /^LP:/i.test(trimmed) ||
    UUID_HEX.test(trimmed) ||
    trimmed.includes(' - ')
  ) {
    return null;
  }
  const shelves = locs.filter(l => locIsActiveShelfMatchingCode(l, trimmed));
  if (shelves.length !== 1) return null;
  const shelf = shelves[0];
  const hidFinal = nearestHallAncestorId(shelf, locById);
  const hallLoc = hidFinal ? mapGetUuid(locById, hidFinal) : undefined;
  const presetHall = hallLoc?.id ? String(hallLoc.id) : null;
  return { ok: true, loc: shelf, presetHallFilterId: presetHall };
}

/**
 * Vrednost u CODE128 / QR (jedan kratak slog u grafici — bez dodatnih natpisa na nalepnici).
 *
 * @param {object} shelfLoc
 * @param {Map<string, object>} locById
 * @returns {{ barcodeValue: string, displayPrimary: string, presetHallFilterId: string|null }}
 */
export function buildShelfPrintBarcodeParts(shelfLoc, locById) {
  const shelfId = String(shelfLoc?.id ?? '').trim();
  const fallbackCode =
    shelfLoc?.location_code != null ? String(shelfLoc.location_code).trim() : shelfId.slice(0, 8);

  const hallId = nearestHallAncestorId(shelfLoc, locById);
  if (!hallId) {
    const line =
      fallbackCode ||
      shelfId.slice(0, 13) ||
      'ERR';
    return {
      barcodeValue: line,
      displayPrimary: line,
      presetHallFilterId: null,
    };
  }

  const hall = mapGetUuid(locById, hallId);
  const hCode = hall?.location_code != null ? String(hall.location_code).trim() : '';
  const sCode = shelfLoc.location_code != null ? String(shelfLoc.location_code).trim() : '';
  const line = formatShelfBarcodeHumanLine(hCode, sCode) || fallbackCode;

  return {
    barcodeValue: line,
    displayPrimary: line,
    presetHallFilterId: hallId,
  };
}

/**
 * @param {string} t trimmed token
 * @returns {{ hallId: string, shelfId: string } | null}
 */
export function parseShelfCompositeBarcodeToken(t) {
  const m = LP_COMPOSITE.exec(String(t || '').trim());
  if (!m) return null;
  return { hallId: m[1], shelfId: m[2] };
}

/** @internal */
function resolveLpUuidComposite(p, _locs, locById) {
  const shelf = mapGetUuid(locById, p.shelfId);
  if (!shelf || shelf.is_active === false) {
    return { ok: false, msg: 'Nema aktivne police za ovaj barkod (proveri štampanu nalepnicu).' };
  }
  if (!isShelfType(shelf.location_type)) {
    return { ok: false, msg: 'Barkod pokazuje lokaciju koja nije polica/regal/KES.' };
  }

  const hall = mapGetUuid(locById, p.hallId);
  if (!hall || hall.is_active === false || !isHallType(hall.location_type)) {
    return {
      ok: false,
      msg: 'Halа iz barkoda nije u aktivnom masteru lokacija (ILI / zastarelа nalepnica).',
    };
  }

  const ancestorId = nearestHallAncestorId(shelf, locById);
  const want = String(p.hallId).toLowerCase();
  const got = ancestorId ? String(ancestorId).toLowerCase() : '';
  if (!ancestorId || got !== want) {
    return {
      ok: false,
      msg: 'Barkod ne odgovara trenutnoj strukturi lokacija (proveri kojoj hali polica sad pripada).',
    };
  }

  return { ok: true, loc: shelf, presetHallFilterId: String(hall.id) };
}

/**
 * Jednoznačno odredi policu + halu: `LP:…`, kratko `ŠIF_HALE - ŠIF_POLICE`, ili sama šifrum police ako je jedinstvena.
 *
 * @param {string} trimmedNormalized normalizeBarcodeText + trim
 * @param {object[]} locs aktivne lokacije kao u scan modal-u
 * @param {Map<string, object>} locById
 * @returns {ShelfCompositeResolve | null} `null` kad format nije naš kompozit pa dalje ostaje obični lookup šifrе.
 */
export function resolveCompositeShelfScan(trimmedNormalized, locs, locById) {
  const t = String(trimmedNormalized || '').trim();
  const lpTok = parseShelfCompositeBarcodeToken(t);
  if (lpTok) return resolveLpUuidComposite(lpTok, locs, locById);

  const pair = parseShortShelfBarcodePair(t);
  if (pair) return resolveShortShelfBarcodePair(pair, locs, locById);

  const uniq = resolveShelfUniqueByShelfCodeGlobally(t, locs, locById);
  return uniq ?? null;
}