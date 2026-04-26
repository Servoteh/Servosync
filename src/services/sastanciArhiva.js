/**
 * Servis za PDF zapisnike u bucketу 'sastanci-arhiva'.
 *
 * Eksportuje:
 *   uploadSastanakPdf(sastanakId, blob)   → { storagePath } | null
 *   downloadSastanakPdf(storagePath)      → otvara u novom tabu
 *   regenerateSastanakPdf(sastanakId)     → boolean
 */

import { getSupabaseHeaders, getSupabaseUrl, sbReq } from './supabase.js';
import { getCurrentUser, getIsOnline } from '../state/auth.js';
import { generateSastanakPdf } from '../lib/sastanciPdf.js';
import { getSastanakFull } from './sastanciDetalj.js';

const BUCKET = 'sastanci-arhiva';

/**
 * Uploada PDF blob u Storage i ažurira sastanak_arhiva sa pdf pathom.
 * @param {string} sastanakId
 * @param {Blob} blob
 * @returns {Promise<{ storagePath: string } | null>}
 */
export async function uploadSastanakPdf(sastanakId, blob) {
  if (!sastanakId || !blob || !getIsOnline()) return null;

  const cu = getCurrentUser();
  const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const storagePath = `${sastanakId}/${ts}_zapisnik.pdf`;

  const supabaseUrl = getSupabaseUrl();
  const headers = getSupabaseHeaders();

  const uploadRes = await fetch(
    `${supabaseUrl}/storage/v1/object/${BUCKET}/${storagePath}`,
    {
      method: 'POST',
      headers: {
        ...headers,
        'Content-Type': 'application/pdf',
        'x-upsert': 'true',
      },
      body: blob,
    },
  );

  if (!uploadRes.ok) {
    console.error('[uploadSastanakPdf] Storage upload failed', await uploadRes.text());
    return null;
  }

  // Ažuriraj sastanak_arhiva red sa pdf pathom
  const existing = await sbReq(
    `sastanak_arhiva?sastanak_id=eq.${encodeURIComponent(sastanakId)}&select=id&limit=1`,
  );

  const arhivaId = Array.isArray(existing) && existing.length ? existing[0].id : crypto.randomUUID();

  const payload = {
    id: arhivaId,
    sastanak_id: sastanakId,
    zapisnik_storage_path: storagePath,
    zapisnik_size_bytes: blob.size,
    zapisnik_generated_at: new Date().toISOString(),
    arhivirao_email: cu?.email || null,
    arhivirao_label: cu?.user_metadata?.full_name || cu?.email || null,
    arhivirano_at: new Date().toISOString(),
  };

  const data = await sbReq('sastanak_arhiva', 'POST', payload);
  if (!Array.isArray(data) || !data.length) {
    console.error('[uploadSastanakPdf] Arhiva upsert failed');
    return null;
  }

  return { storagePath };
}

/**
 * Generiše signed URL (TTL 300s) i otvara PDF u novom tabu.
 * @param {string} storagePath  iz sastanak_arhiva.zapisnik_storage_path
 */
export async function downloadSastanakPdf(storagePath) {
  if (!storagePath || !getIsOnline()) return;

  const supabaseUrl = getSupabaseUrl();
  const headers = getSupabaseHeaders();

  const res = await fetch(
    `${supabaseUrl}/storage/v1/object/sign/${BUCKET}/${storagePath}`,
    {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ expiresIn: 300 }),
    },
  );

  if (!res.ok) {
    console.error('[downloadSastanakPdf] Sign URL failed', await res.text());
    return;
  }

  const json = await res.json();
  if (json?.signedURL) {
    window.open(`${supabaseUrl}/storage/v1${json.signedURL}`, '_blank');
  }
}

/**
 * Re-generiše PDF za zaključan sastanak (admin/menadzment).
 * Novi PDF se uploaduje pod novim timestamp-om; arhiva se ažurira.
 * @param {string} sastanakId
 * @returns {Promise<boolean>}
 */
export async function regenerateSastanakPdf(sastanakId) {
  if (!sastanakId || !getIsOnline()) return false;

  const sast = await getSastanakFull(sastanakId);
  if (!sast) return false;

  let blob;
  try {
    blob = await generateSastanakPdf(sast);
  } catch (e) {
    console.error('[regenerateSastanakPdf] PDF generation failed', e);
    return false;
  }

  const result = await uploadSastanakPdf(sastanakId, blob);
  return !!result;
}
