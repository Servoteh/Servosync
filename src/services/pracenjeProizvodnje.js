/**
 * Praćenje proizvodnje — service sloj.
 *
 * Tanki wrapper oko production RPC-ja iz Inkrementa 1. Zadržava postojeći
 * projekat pattern: UI/state nikad ne pozivaju `sbReq` direktno.
 */

import { sbReq } from './supabase.js';
import { getIsOnline } from '../state/auth.js';

function assertOnline() {
  if (!getIsOnline()) {
    throw new Error('Supabase nije dostupan (offline)');
  }
}

async function rpc(name, body = {}) {
  assertOnline();
  const res = await sbReq(`rpc/${name}`, 'POST', body, { upsert: false });
  if (res == null) {
    throw new Error(`RPC ${name} nije uspeo`);
  }
  return res;
}

async function select(path, fallback = []) {
  if (!getIsOnline()) return fallback;
  const res = await sbReq(path);
  return Array.isArray(res) ? res : fallback;
}

export async function fetchPracenjeRn(rnId) {
  if (!rnId) throw new Error('RN ID je obavezan');
  return rpc('get_pracenje_rn', { p_rn_id: rnId });
}

export async function fetchOperativniPlan({ rnId = null, projekatId = null } = {}) {
  if (!rnId && !projekatId) throw new Error('Prosledi rnId ili projekatId');
  return rpc('get_operativni_plan', {
    p_rn_id: rnId || null,
    p_projekat_id: projekatId || null,
  });
}

export async function upsertOperativnaAktivnost(payload = {}) {
  const p = normalizeAktivnostPayload(payload);
  return rpc('upsert_operativna_aktivnost', p);
}

export async function zatvoriAktivnost(id, napomena = '') {
  if (!id) throw new Error('ID aktivnosti je obavezan');
  return rpc('zatvori_aktivnost', { p_id: id, p_napomena: napomena || '' });
}

export async function setBlokirano(id, razlog) {
  if (!id) throw new Error('ID aktivnosti je obavezan');
  if (!String(razlog || '').trim()) throw new Error('Razlog blokade je obavezan');
  return rpc('set_blokirano', { p_id: id, p_razlog: razlog.trim() });
}

export async function skiniBlokadu(id, napomena = '') {
  if (!id) throw new Error('ID aktivnosti je obavezan');
  return rpc('skini_blokadu', { p_id: id, p_napomena: napomena || '' });
}

export async function canEditPracenje(projectId, rnId) {
  if (!projectId && !rnId) return false;
  try {
    return !!await rpc('can_edit_pracenje', {
      p_project_id: projectId || null,
      p_rn_id: rnId || null,
    });
  } catch (e) {
    console.warn('[pracenje] canEditPracenje failed', e);
    return false;
  }
}

/**
 * Dodatni lookup-i za modal. Ako non-public schema nije izložena kroz PostgREST,
 * vraćamo prazne liste i UI ostaje read-safe.
 */
export async function listOdeljenja() {
  return select('odeljenje?select=id,kod,naziv,boja,sort_order&order=sort_order.asc,naziv.asc');
}

export async function listRadnici() {
  return select('radnik?select=id,ime,puno_ime,email,aktivan&aktivan=eq.true&order=puno_ime.asc,ime.asc');
}

export async function fetchOperativneAktivnostiRaw(rnId) {
  if (!rnId) return [];
  return select(
    `v_operativna_aktivnost?select=*&radni_nalog_id=eq.${encodeURIComponent(rnId)}&order=rb.asc`,
  );
}

function normalizeAktivnostPayload(payload) {
  return {
    p_id: payload.id || null,
    p_radni_nalog_id: payload.radni_nalog_id || payload.radniNalogId || null,
    p_projekat_id: payload.projekat_id || payload.projekatId || null,
    p_odeljenje_id: payload.odeljenje_id || payload.odeljenjeId || null,
    p_naziv_aktivnosti: payload.naziv_aktivnosti || payload.nazivAktivnosti || '',
    p_planirani_pocetak: payload.planirani_pocetak || payload.planiraniPocetak || null,
    p_planirani_zavrsetak: payload.planirani_zavrsetak || payload.planiraniZavrsetak || null,
    p_odgovoran_user_id: payload.odgovoran_user_id || null,
    p_odgovoran_radnik_id: payload.odgovoran_radnik_id || null,
    p_status: payload.status || 'nije_krenulo',
    p_prioritet: payload.prioritet || 'srednji',
    p_rb: Number.isFinite(Number(payload.rb)) ? Number(payload.rb) : 100,
    p_opis: payload.opis || null,
    p_broj_tp: payload.broj_tp || null,
    p_kolicina_text: payload.kolicina_text || null,
    p_odgovoran_label: payload.odgovoran_label || null,
    p_zavisi_od_aktivnost_id: payload.zavisi_od_aktivnost_id || null,
    p_zavisi_od_text: payload.zavisi_od_text || null,
    p_status_mode: payload.status_mode || 'manual',
    p_rizik_napomena: payload.rizik_napomena || null,
    p_izvor: payload.izvor || 'rucno',
    p_izvor_akcioni_plan_id: payload.izvor_akcioni_plan_id || null,
    p_izvor_pozicija_id: payload.izvor_pozicija_id || null,
    p_izvor_tp_operacija_id: payload.izvor_tp_operacija_id || null,
  };
}
