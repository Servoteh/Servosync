/**
 * Top ⭐ prioritet predmeta (Plan montaže / PB / Lokacije) — Supabase RPC.
 */

import { sbReq, sbReqThrow } from './supabase.js';
import { getIsOnline } from '../state/auth.js';

function normalizeIds(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map(Number).filter(x => Number.isFinite(x) && x > 0);
}

function assertOnline() {
  if (!getIsOnline()) throw new Error('Supabase nije dostupan (offline)');
}

/**
 * @returns {Promise<number[]|null>} lista ili null ako nema mreže / RPC nije uspeo
 */
export async function pullPredmetPlanPrioritetIds() {
  if (!getIsOnline()) return null;
  const res = await sbReq('rpc/get_predmet_plan_prioritet_ids', 'POST', {}, { upsert: false });
  if (res === null) return null;
  return normalizeIds(res).slice(0, 10);
}

/** @param {number[]} ids */
export async function pushPredmetPlanPrioritetIds(ids) {
  assertOnline();
  const clean = normalizeIds(ids).slice(0, 10);
  await sbReqThrow(
    'rpc/set_predmet_plan_prioritet',
    'POST',
    { p_item_ids: clean },
    { upsert: false },
  );
}
