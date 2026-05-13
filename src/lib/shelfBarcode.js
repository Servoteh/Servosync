/**
 * Kompozitni barkod nalepnice police za premestanje (TAB LOKACIJE / PREMESTANJE):
 * `LP:<uuid_hale>:<uuid_police>` — ne meša se sa RNZ / kompaktnim BigTehn formatom.
 */

import { isHallType, isShelfType } from './lokacijeTypes.js';

/** @typedef {{ ok: true, loc: object, presetHallFilterId: string } | { ok: false, msg: string }} ShelfCompositeResolve */

const LP_COMPOSITE =
  /^LP:([0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}):([0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$/i;

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
 * Vrednost u CODE128/QR za policu koja pripada hali (nadređeni HAL tip u stablu).
 *
 * `captionHall` / `captionShelf` — čitljiv tekst ispod grafike na nalepnici (NATPIS „Hala“ / „Polica”).
 *
 * @param {object} shelfLoc
 * @param {Map<string, object>} locById
 * @returns {{ barcodeValue: string, displayPrimary: string, presetHallFilterId: string|null,
 *   captionHall: string|null, captionShelf: string }}
 */
export function buildShelfPrintBarcodeParts(shelfLoc, locById) {
  const shelfId = String(shelfLoc?.id ?? '').trim();
  const fallbackCode =
    shelfLoc?.location_code != null ? String(shelfLoc.location_code).trim() : shelfId.slice(0, 8);
  const shelfNameTrim =
    shelfLoc?.name != null ? String(shelfLoc.name).trim().replace(/\s+/g, ' ') : '';

  const hallId = nearestHallAncestorId(shelfLoc, locById);
  if (!hallId) {
    const captionShelf =
      fallbackCode && shelfNameTrim && shelfNameTrim !== fallbackCode
        ? `${fallbackCode} · ${shelfNameTrim}`
        : fallbackCode || shelfNameTrim || shelfId.slice(0, 8);
    return {
      barcodeValue: shelfId || fallbackCode,
      displayPrimary: fallbackCode || shelfId,
      presetHallFilterId: null,
      captionHall: null,
      captionShelf,
    };
  }

  const hall = mapGetUuid(locById, hallId);
  const hCode = hall?.location_code != null ? String(hall.location_code).trim() : '';
  const sCode = shelfLoc.location_code != null ? String(shelfLoc.location_code).trim() : '';
  const hallNameTrim = hall?.name != null ? String(hall.name).trim().replace(/\s+/g, ' ') : '';
  const displayPrimary =
    hCode && sCode ? `${hCode} · ${sCode}` : sCode || hCode || shelfId.slice(0, 8);

  const captionHallChunks = [];
  if (hCode) captionHallChunks.push(hCode);
  if (hallNameTrim && hallNameTrim !== hCode) captionHallChunks.push(hallNameTrim);
  const captionHallRaw = captionHallChunks.length ? captionHallChunks.join(' · ') : hallNameTrim || hCode;

  const captionShelf =
    sCode && shelfNameTrim && shelfNameTrim !== sCode ? `${sCode} · ${shelfNameTrim}` :
    sCode || shelfNameTrim || displayPrimary;

  return {
    barcodeValue: `LP:${hallId}:${shelfId}`,
    displayPrimary,
    presetHallFilterId: hallId,
    captionHall: captionHallRaw || null,
    captionShelf,
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

/**
 * Jednoznačno odredi policu + halu kad je barkod u LP formatu (inače `null`).
 *
 * @param {string} trimmedNormalized normalizeBarcodeText + trim
 * @param {object[]} locs aktivne lokacije kao u scan modal-u
 * @param {Map<string, object>} locById
 * @returns {ShelfCompositeResolve | null}
 */
export function resolveCompositeShelfScan(trimmedNormalized, locs, locById) {
  const p = parseShelfCompositeBarcodeToken(trimmedNormalized);
  if (!p) return null;

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
