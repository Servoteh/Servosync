import { sbReq } from './supabase.js';
import { getIsOnline } from '../state/auth.js';

const SELECT = [
  'id', 'sastanak_id', 'rb', 'naslov', 'opis',
  'odlucio_email', 'odlucio_label', 'odluka_datum', 'uticaj',
  'veza_tema_id', 'veza_akcija_id', 'status', 'created_at', 'updated_at',
].join(',');

export const ODLUKA_STATUSI = {
  na_snazi: 'Na snazi',
  opozvana: 'Opozvana',
};

export function mapDbOdluka(d) {
  if (!d) return null;
  return {
    id: d.id,
    sastanakId: d.sastanak_id,
    rb: d.rb,
    naslov: d.naslov || '',
    opis: d.opis || '',
    odlucioEmail: d.odlucio_email || '',
    odlucioLabel: d.odlucio_label || '',
    odlukaDatum: d.odluka_datum || null,
    uticaj: d.uticaj || '',
    vezaTemaId: d.veza_tema_id || null,
    vezaAkcijaId: d.veza_akcija_id || null,
    status: d.status || 'na_snazi',
    createdAt: d.created_at,
    updatedAt: d.updated_at,
  };
}

export async function loadOdlukeBySastanak(sastanakId) {
  if (!sastanakId || !getIsOnline()) return [];
  const data = await sbReq(
    `sastanak_odluke?sastanak_id=eq.${encodeURIComponent(sastanakId)}&select=${SELECT}&order=rb.asc.nullslast,created_at.asc`,
  );
  return Array.isArray(data) ? data.map(mapDbOdluka) : [];
}

function buildPayload(o) {
  return {
    sastanak_id: o.sastanakId,
    rb: o.rb ?? null,
    naslov: o.naslov || '',
    opis: o.opis || null,
    odlucio_email: o.odlucioEmail || null,
    odlucio_label: o.odlucioLabel || null,
    odluka_datum: o.odlukaDatum || null,
    uticaj: o.uticaj || null,
    veza_tema_id: o.vezaTemaId || null,
    veza_akcija_id: o.vezaAkcijaId || null,
    status: o.status || 'na_snazi',
    updated_at: new Date().toISOString(),
    ...(o.id ? { id: o.id } : {}),
  };
}

export async function saveOdluka(o) {
  if (!getIsOnline() || !o?.sastanakId) return null;
  const data = await sbReq('sastanak_odluke', 'POST', buildPayload(o));
  return Array.isArray(data) && data.length ? mapDbOdluka(data[0]) : null;
}

export async function deleteOdluka(id) {
  if (!id || !getIsOnline()) return false;
  return (await sbReq(`sastanak_odluke?id=eq.${encodeURIComponent(id)}`, 'DELETE')) !== null;
}
