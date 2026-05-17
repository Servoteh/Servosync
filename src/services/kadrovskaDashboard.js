/**
 * Kadrovska Pregled — KPI RPC + action stack (PostgREST, session keš 60s).
 */

import { SESSION_KEYS } from '../lib/constants.js';
import { getIsOnline } from '../state/auth.js';
import { sbReq } from './supabase.js';
import { ssGet, ssSet, ssRemove } from '../lib/storage.js';

const CACHE_TTL_MS = 60_000;
const CACHE_KEY = 'kadr_dashboard_v1';

/**
 * Pročitaj i obriši jednokratni intent sa dashboard-a ako `tab` odgovara.
 * @param {string} expectedTab — npr. 'contracts', 'employees', 'vac-requests'
 * @returns {Record<string, unknown>|null}
 */
export function consumeKadrDashIntent(expectedTab) {
  try {
    const raw = ssGet(SESSION_KEYS.KADR_DASH_INTENT, null);
    if (!raw) return null;
    const j = JSON.parse(raw);
    if (j?.tab !== expectedTab) return null;
    ssRemove(SESSION_KEYS.KADR_DASH_INTENT);
    return j;
  } catch {
    return null;
  }
}

function readSessionCache(key) {
  try {
    const raw = sessionStorage.getItem(key);
    if (!raw) return null;
    const obj = JSON.parse(raw);
    if (Date.now() - obj.t > CACHE_TTL_MS) return null;
    return obj.v;
  } catch {
    return null;
  }
}

function writeSessionCache(key, value) {
  try {
    sessionStorage.setItem(key, JSON.stringify({ t: Date.now(), v: value }));
  } catch {
    /* noop */
  }
}

export function clearDashboardCache() {
  try {
    for (const k of Object.keys(sessionStorage)) {
      if (k.startsWith(CACHE_KEY)) sessionStorage.removeItem(k);
    }
  } catch {
    /* noop */
  }
}

export async function loadDashboardKpis({ year, month, forceRefresh = false } = {}) {
  if (!getIsOnline()) return null;
  const fullKey = `${CACHE_KEY}__kpi__${year ?? 'curr'}_${month ?? 'curr'}`;
  if (!forceRefresh) {
    const cached = readSessionCache(fullKey);
    if (cached) return cached;
  }
  const body = { p_year: year ?? null, p_month: month ?? null };
  const result = await sbReq('rpc/kadr_dashboard_kpis', 'POST', body, { upsert: false });
  if (result && typeof result === 'object') writeSessionCache(fullKey, result);
  return result;
}

export async function loadMiniReports({ year, month, forceRefresh = false } = {}) {
  if (!getIsOnline()) return null;
  const fullKey = `${CACHE_KEY}__mini__${year ?? 'curr'}_${month ?? 'curr'}`;
  if (!forceRefresh) {
    const cached = readSessionCache(fullKey);
    if (cached) return cached;
  }
  const body = { p_year: year ?? null, p_month: month ?? null };
  const result = await sbReq('rpc/kadr_dashboard_mini_reports', 'POST', body, { upsert: false });
  if (result && typeof result === 'object') writeSessionCache(fullKey, result);
  return result;
}

export async function loadActionStack({ forceRefresh = false } = {}) {
  if (!getIsOnline()) return [];
  const fullKey = `${CACHE_KEY}__actions`;
  if (!forceRefresh) {
    const cached = readSessionCache(fullKey);
    if (cached) return cached;
  }
  const result = await sbReq('rpc/kadr_dashboard_action_stack', 'POST', { p_limit: 10 }, { upsert: false });
  const list = Array.isArray(result) ? result : [];
  writeSessionCache(fullKey, list);
  return list;
}
