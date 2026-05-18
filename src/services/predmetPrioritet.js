/**
 * Top ⭐ prioritet predmeta — keš + sort helper (Plan montaže / PB / Lokacije / Praćenje).
 * Server: {@link pullPredmetPlanPrioritetIds} / {@link pushPredmetPlanPrioritetIds}.
 */

import {
  pullPredmetPlanPrioritetIds,
  pushPredmetPlanPrioritetIds,
} from './predmetPlanPrioritet.js';

export const LEGACY_LS_KEY = 'servoteh_predmet_prioritet_v1';
const MAX = 10;

/** @type {number[]} */
let _cachedIds = [];
/** @type {Promise<void>|null} */
let _hydratePromise = null;

function readLegacyLs() {
  try {
    if (typeof localStorage === 'undefined') return [];
    const raw = localStorage.getItem(LEGACY_LS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.map(Number).filter(n => Number.isFinite(n) && n > 0).slice(0, MAX);
  } catch {
    return [];
  }
}

export function clearLegacyPrioritetLs() {
  try {
    if (typeof localStorage !== 'undefined') localStorage.removeItem(LEGACY_LS_KEY);
  } catch {
    /* ignore */
  }
}

async function tryMigrateLegacyWhenServerEmpty() {
  const leg = readLegacyLs();
  if (!leg.length) return;
  try {
    await pushPredmetPlanPrioritetIds(leg);
    _cachedIds = leg.slice(0, MAX);
    clearLegacyPrioritetLs();
  } catch {
    _cachedIds = leg.slice(0, MAX);
  }
}

async function doHydrate() {
  try {
    const remote = await pullPredmetPlanPrioritetIds();
    if (remote !== null) {
      if (remote.length > 0) {
        _cachedIds = remote.slice();
        clearLegacyPrioritetLs();
      } else {
        await tryMigrateLegacyWhenServerEmpty();
        if (!_cachedIds.length) _cachedIds = [];
      }
      return;
    }
  } catch {
    /* fallback LS */
  }
  _cachedIds = readLegacyLs();
}

export function ensurePrioritetHydrated() {
  if (!_hydratePromise) {
    _hydratePromise = doHydrate().finally(() => {});
  }
  return _hydratePromise;
}

export async function refreshPrioritetFromServer() {
  const remote = await pullPredmetPlanPrioritetIds();
  if (remote !== null) {
    _cachedIds = remote.slice();
    if (remote.length > 0) clearLegacyPrioritetLs();
  }
}

export function getPrioritetIds() {
  return _cachedIds.slice();
}

async function persistAfterMutation(before) {
  try {
    await pushPredmetPlanPrioritetIds(_cachedIds);
    clearLegacyPrioritetLs();
  } catch (e) {
    _cachedIds = before;
    throw e;
  }
}

export async function addToPrioritet(itemId) {
  const id = Number(itemId);
  const before = _cachedIds.slice();
  if (_cachedIds.includes(id)) return false;
  if (_cachedIds.length >= MAX) return false;
  _cachedIds.push(id);
  await persistAfterMutation(before);
  return true;
}

export async function removeFromPrioritet(itemId) {
  const id = Number(itemId);
  const before = _cachedIds.slice();
  const next = _cachedIds.filter(x => x !== id);
  if (next.length === before.length) return;
  _cachedIds = next;
  await persistAfterMutation(before);
}

export function isPrioritet(itemId) {
  return _cachedIds.includes(Number(itemId));
}

export async function movePrioritetUp(itemId) {
  const id = Number(itemId);
  const before = _cachedIds.slice();
  const list = _cachedIds;
  const ix = list.indexOf(id);
  if (ix <= 0) return;
  [list[ix - 1], list[ix]] = [list[ix], list[ix - 1]];
  await persistAfterMutation(before);
}

export async function movePrioritetDown(itemId) {
  const id = Number(itemId);
  const before = _cachedIds.slice();
  const list = _cachedIds;
  const ix = list.indexOf(id);
  if (ix < 0 || ix >= list.length - 1) return;
  [list[ix], list[ix + 1]] = [list[ix + 1], list[ix]];
  await persistAfterMutation(before);
}

/**
 * @template T
 * @param {T[]} rows
 * @param {(row: T) => number|null|undefined} getPredmetItemId
 * @param {(a: T, b: T) => number} [fallbackCmp]
 * @returns {T[]}
 */
export function sortByPredmetPrioritet(rows, getPredmetItemId, fallbackCmp) {
  if (!Array.isArray(rows) || rows.length <= 1) return rows || [];
  const prioIds = getPrioritetIds();
  const fb =
    fallbackCmp
    || ((a, b) =>
      String(a?.project_code ?? a?.code ?? '').localeCompare(
        String(b?.project_code ?? b?.code ?? ''),
        'sr',
      ));
  if (!prioIds.length) return [...rows].sort(fb);
  const ranked = [...rows];
  ranked.sort((a, b) => {
    const ida = Number(getPredmetItemId(a));
    const idb = Number(getPredmetItemId(b));
    const ia = Number.isFinite(ida) && ida > 0 ? prioIds.indexOf(ida) : -1;
    const ib = Number.isFinite(idb) && idb > 0 ? prioIds.indexOf(idb) : -1;
    if (ia !== -1 && ib !== -1) return ia - ib;
    if (ia !== -1) return -1;
    if (ib !== -1) return 1;
    return fb(a, b);
  });
  return ranked;
}
