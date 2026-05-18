/**
 * Sastanci arhiva — zaključavanje (JSONB snapshot), print HTML, PDF storage.
 */

import { sbReq, getSupabaseHeaders, getSupabaseUrl } from './supabase.js';
import { getIsOnline } from '../state/auth.js';
import { SASTANAK_SLIKE_BUCKET } from './projektniSastanak.js';
import { generateSastanakPdf } from '../lib/sastanciPdf.js';
import { getSastanakFull } from './sastanciDetalj.js';

const BUCKET = 'sastanci-arhiva';

export function mapDbArhiva(d) {
  if (!d) return null;
  return {
    id: d.id,
    sastanakId: d.sastanak_id,
    snapshot: d.snapshot || null,
    zapisnikStoragePath: d.zapisnik_storage_path || '',
    zapisnikSizeBytes: d.zapisnik_size_bytes || 0,
    zapisnikGeneratedAt: d.zapisnik_generated_at || null,
    arhiviraoEmail: d.arhivirao_email || '',
    arhiviraoLabel: d.arhivirao_label || '',
    arhiviranoAt: d.arhivirano_at || null,
  };
}

const ARHIVA_SELECT = 'id,sastanak_id,snapshot,zapisnik_storage_path,zapisnik_size_bytes,zapisnik_generated_at,arhivirao_email,arhivirao_label,arhivirano_at';

export async function loadArhiva(sastanakId) {
  if (!sastanakId || !getIsOnline()) return null;
  const data = await sbReq(
    `sastanak_arhiva?sastanak_id=eq.${encodeURIComponent(sastanakId)}&select=${ARHIVA_SELECT}&limit=1`,
  );
  return Array.isArray(data) && data.length ? mapDbArhiva(data[0]) : null;
}

export async function loadSveArhive({ limit = 100 } = {}) {
  if (!getIsOnline()) return [];
  const data = await sbReq(
    `sastanak_arhiva?select=${ARHIVA_SELECT}&order=arhivirano_at.desc&limit=${limit}`,
  );
  return Array.isArray(data) ? data.map(mapDbArhiva) : [];
}

export async function zakljucajSastanakRpc(sastanakId, { pdfUrl = null, pdfStoragePath = null } = {}) {
  if (!sastanakId || !getIsOnline()) {
    return { ok: false, error: 'Nema sastanka ili nismo online.' };
  }

  const result = await sbReq('rpc/sast_zakljucaj_sastanak', 'POST', {
    p_sastanak_id: sastanakId,
    p_pdf_url: pdfUrl ?? null,
    p_pdf_storage_path: pdfStoragePath ?? null,
  });

  if (!result || result.ok === false) {
    return {
      ok: false,
      reason: result?.reason || 'rpc_failed',
      error: result?.reason === 'already_locked'
        ? 'Sastanak je već arhiviran.'
        : 'Zaključavanje sastanka nije uspelo.',
    };
  }

  return { ok: true, result };
}

export async function arhivirajSastanak(sastanakId, { pdfUrl = null, pdfStoragePath = null } = {}) {
  const locked = await zakljucajSastanakRpc(sastanakId, { pdfUrl, pdfStoragePath });
  if (!locked.ok) return locked;
  return { ok: true, result: locked.result, archive: await loadArhiva(sastanakId) };
}

export function buildZapisnikHtml(snapshot) {
  if (!snapshot || !snapshot.sastanak) return '<p>Nema podataka za zapisnik.</p>';
  const s = snapshot.sastanak;
  const esc = (str) => String(str || '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
  const fmtDate = (d) => d ? new Date(d).toLocaleDateString('sr-RS') : '';

  const ucesniciHtml = (snapshot.ucesnici || [])
    .filter(u => u.prisutan)
    .map(u => esc(u.label || u.email))
    .join(', ') || '—';

  const temeHtml = (snapshot.pmTeme || []).length === 0 ? '' : `
    <h2>Dnevni red</h2>
    <ol>
      ${(snapshot.pmTeme || []).map(t => `
        <li><strong>${esc(t.naslov)}</strong>${t.opis ? ` — ${esc(t.opis)}` : ''}</li>
      `).join('')}
    </ol>
  `;

  const akcijeHtml = (snapshot.akcije || []).length === 0 ? '' : `
    <h2>Akcioni plan</h2>
    <table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;width:100%">
      <thead><tr><th>RB</th><th>Zadatak</th><th>Odgovoran</th><th>Rok</th><th>Status</th></tr></thead>
      <tbody>
        ${(snapshot.akcije || []).map((a, i) => `
          <tr>
            <td>${i + 1}</td>
            <td><strong>${esc(a.naslov)}</strong>${a.opis ? `<br><small>${esc(a.opis)}</small>` : ''}</td>
            <td>${esc(a.odgovoranLabel || a.odgovoranText || a.odgovoranEmail || '—')}</td>
            <td>${esc(a.rokText || fmtDate(a.rok) || '—')}</td>
            <td>${esc(a.status)}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;

  const aktivnostiHtml = (snapshot.aktivnosti || []).length === 0 ? '' : `
    <h2>Pregled stanja po podstavkama</h2>
    <table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;width:100%">
      <thead><tr><th>RB</th><th>Aktivnosti</th><th>Odgovoran</th><th>Rok</th></tr></thead>
      <tbody>
        ${(snapshot.aktivnosti || []).map(a => `
          <tr>
            <td>${esc(String(a.rb))}</td>
            <td><strong>${esc(a.naslov)}</strong><div>${a.sadrzajHtml || ''}</div></td>
            <td>${esc(a.odgovoranLabel || a.odgovoranText || '—')}</td>
            <td>${esc(a.rokText || fmtDate(a.rok) || '—')}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;

  const slikeHtml = (snapshot.slike || []).length === 0 ? '' : `
    <h2>Foto dokumentacija (${(snapshot.slike || []).length})</h2>
    <div style="display:grid;grid-template-columns:repeat(2,1fr);gap:12px">
      ${(snapshot.slike || []).map(sl => `
        <figure style="margin:0">
          <img src="${esc(sl.signedUrl || '')}" style="max-width:100%;border:1px solid #ccc">
          ${sl.caption ? `<figcaption style="font-size:11px;color:#666">${esc(sl.caption)}</figcaption>` : ''}
        </figure>
      `).join('')}
    </div>
  `;

  const metaMesto = s.mesto ? `<div><strong>Mesto:</strong> ${esc(s.mesto)}</div>` : '';
  const metaZapis = (s.zapisnicarLabel || s.zapisnicarEmail)
    ? `<div><strong>Zapisničar:</strong> ${esc(s.zapisnicarLabel || s.zapisnicarEmail)}</div>`
    : '';

  return `<!DOCTYPE html>
<html lang="sr">
<head>
  <meta charset="utf-8">
  <title>Zapisnik — ${esc(s.naslov)}</title>
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; padding: 24px; color: #1a1a1a; }
    h1 { border-bottom: 2px solid #333; padding-bottom: 8px; }
    h2 { margin-top: 24px; color: #333; }
    table { font-size: 12px; }
    th { background: #f0f0f0; text-align: left; }
    .meta { background: #f6f6f6; padding: 12px; border-left: 4px solid #2563eb; margin: 12px 0; }
    .meta div { margin: 4px 0; }
  </style>
</head>
<body>
  <h1>${esc(s.naslov)}</h1>
  <div class="meta">
    <div><strong>Datum:</strong> ${fmtDate(s.datum)}${s.vreme ? ' u ' + s.vreme : ''}</div>
    ${metaMesto}
    <div><strong>Vodio sastanak:</strong> ${esc(s.vodioLabel || s.vodioEmail || '—')}</div>
    ${metaZapis}
    <div><strong>Učesnici:</strong> ${ucesniciHtml}</div>
  </div>
  ${temeHtml}
  ${aktivnostiHtml}
  ${akcijeHtml}
  ${slikeHtml}
  ${s.napomena ? `<h2>Napomena</h2><p>${esc(s.napomena)}</p>` : ''}
  <hr style="margin-top:32px">
  <small style="color:#888">Generisano: ${new Date().toLocaleString('sr-RS')} · Servoteh interni sistem · Sastanci modul</small>
</body>
</html>`;
}

export function printZapisnik(snapshot) {
  const html = buildZapisnikHtml(snapshot);
  const w = window.open('', '_blank');
  if (!w) return false;
  w.document.write(html);
  w.document.close();
  setTimeout(() => {
    try { w.print(); } catch { /* manual */ }
  }, 800);
  return true;
}

export async function uploadSastanakPdf(sastanakId, blob) {
  if (!sastanakId || !blob || !getIsOnline()) return null;

  const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const storagePath = `${sastanakId}/${ts}_zapisnik.pdf`;
  const supabaseUrl = getSupabaseUrl();
  const headers = getSupabaseHeaders();

  const uploadRes = await fetch(
    `${supabaseUrl}/storage/v1/object/${BUCKET}/${storagePath}`,
    {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/pdf', 'x-upsert': 'true' },
      body: blob,
    },
  );

  if (!uploadRes.ok) {
    console.error('[uploadSastanakPdf] Storage upload failed', await uploadRes.text());
    return null;
  }

  return { storagePath };
}

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

export { SASTANAK_SLIKE_BUCKET };
