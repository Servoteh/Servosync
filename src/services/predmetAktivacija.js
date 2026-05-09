/**
 * Podešavanje predmeta — RPC nad production.predmet_aktivacija.
 * Pristup: admin ili menadžment (baza: can_manage_predmet_aktivacija).
 */

import { sbReq, sbReqThrow } from './supabase.js';
import { getIsOnline } from '../state/auth.js';

function assertOnline() {
  if (!getIsOnline()) {
    throw new Error('Supabase nije dostupan (offline)');
  }
}

/**
 * Svi predmeti iz bigtehn_items_cache + polja aktivacije; jsonb niz.
 * @returns {Promise<object[]|null>} parsiran niz elemenata ili null (greška/403)
 */
export async function listPredmetAktivacijaAdmin() {
  assertOnline();
  const res = await sbReq('rpc/list_predmet_aktivacija_admin', 'POST', {}, { upsert: false });
  if (res == null) return null;
  if (Array.isArray(res)) return res;
  if (Array.isArray(res.json)) return res.json;
  return res;
}

/**
 * @param {number} itemId
 * @param {boolean} aktivan
 * @param {string|null|undefined} napomena null = ne menja postojeću
 * @param {boolean|undefined} projektovanjeMontaza undefined = ne menja flag
 * @returns {Promise<void>}
 */
export async function setPredmetAktivacija(itemId, aktivan, napomena = undefined, projektovanjeMontaza = undefined) {
  assertOnline();
  const id = Number(itemId);
  if (!Number.isFinite(id) || id <= 0) throw new Error('Neispravan ID predmeta.');
  const body = { p_item_id: id, p_aktivan: !!aktivan };
  if (napomena !== undefined) {
    body.p_napomena = napomena === null || napomena === '' ? null : String(napomena);
  }
  if (projektovanjeMontaza !== undefined) {
    body.p_projektovanje_montaza = !!projektovanjeMontaza;
  }
  await sbReqThrow('rpc/set_predmet_aktivacija', 'POST', body, { upsert: false });
}
