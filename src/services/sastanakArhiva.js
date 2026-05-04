/**
 * Sastanak arhiva — JSONB snapshot pri zaključavanju + opciono PDF generisanje.
 *
 * Workflow zaključavanja:
 *   1. UI proverava da li je sve "valid" (sve teme rešene, učesnici označeni
 *      itd.) — opciono.
 *   2. Pozove `arhivirajSastanak(sastanakId)`:
 *      a) povuci sve relacije (sastanak, ucesnici, pm_teme, akcioni_plan,
 *         presek_aktivnosti, presek_slike sa signed URL-om u trenutku snapshot-a)
 *      b) serijalizuj u JSONB
 *      c) INSERT u sastanak_arhiva
 *      d) UPDATE sastanci.status = 'zakljucan'
 *   3. UI sad prikazuje sastanak read-only.
 *
 * PDF generisanje je nezavisno — ako je PDF već uploadovan, RPC može da
 * primi storage path i upiše ga u arhivu.
 */

import { sbReq } from './supabase.js';
import { getIsOnline } from '../state/auth.js';
import { SASTANAK_SLIKE_BUCKET } from './projektniSastanak.js';

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

/* ── Loaders ── */

export async function loadArhiva(sastanakId) {
  if (!sastanakId || !getIsOnline()) return null;
  const data = await sbReq(
    `sastanak_arhiva?sastanak_id=eq.${encodeURIComponent(sastanakId)}&select=id,sastanak_id,snapshot,zapisnik_storage_path,zapisnik_size_bytes,zapisnik_generated_at,arhivirao_email,arhivirao_label,arhivirano_at&limit=1`,
  );
  return Array.isArray(data) && data.length ? mapDbArhiva(data[0]) : null;
}

export async function loadSveArhive({ limit = 100 } = {}) {
  if (!getIsOnline()) return [];
  const data = await sbReq(
    `sastanak_arhiva?select=id,sastanak_id,snapshot,zapisnik_storage_path,zapisnik_size_bytes,zapisnik_generated_at,arhivirao_email,arhivirao_label,arhivirano_at&order=arhivirano_at.desc&limit=${limit}`,
  );
  return Array.isArray(data) ? data.map(mapDbArhiva) : [];
}

/**
 * Zaključaj i arhiviraj sastanak.
 *
 * Zamenjeno sa sast_zakljucaj_sastanak RPC (Sprint 2, H3).
 *
 * @returns {Promise<{ ok: boolean, archive?: object, error?: string }>}
 */
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

/* ── PDF generisanje ── */

/**
 * Generiši HTML zapisnika za PDF print. Vraća HTML string koji UI može da
 * otvori u novom prozoru i pozove print(), ili da pretvori u PDF preko
 * jsPDF/html2pdf biblioteke.
 *
 * Ovo je MVP — bez slike-embedding-a u PDF (slike su signed URL-ovi).
 * Produkciono: koristiti pdfmake ili jspdf-html2canvas za pravi PDF.
 */
export function buildZapisnikHtml(snapshot) {
  if (!snapshot || !snapshot.sastanak) return '<p>Nema podataka za zapisnik.</p>';
  const s = snapshot.sastanak;
  const escHtml = (str) => String(str || '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
  const fmtDate = (d) => d ? new Date(d).toLocaleDateString('sr-RS') : '';

  const ucesniciHtml = (snapshot.ucesnici || [])
    .filter(u => u.prisutan)
    .map(u => escHtml(u.label || u.email))
    .join(', ') || '—';

  const temeHtml = (snapshot.pmTeme || []).length === 0 ? '' : `
    <h2>Dnevni red</h2>
    <ol>
      ${(snapshot.pmTeme || []).map(t => `
        <li><strong>${escHtml(t.naslov)}</strong>${t.opis ? ` — ${escHtml(t.opis)}` : ''}</li>
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
            <td><strong>${escHtml(a.naslov)}</strong>${a.opis ? `<br><small>${escHtml(a.opis)}</small>` : ''}</td>
            <td>${escHtml(a.odgovoranLabel || a.odgovoranText || a.odgovoranEmail || '—')}</td>
            <td>${escHtml(a.rokText || fmtDate(a.rok) || '—')}</td>
            <td>${escHtml(a.status)}</td>
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
            <td>${escHtml(String(a.rb))}</td>
            <td>
              <strong>${escHtml(a.naslov)}</strong>
              <div>${a.sadrzajHtml || ''}</div>
            </td>
            <td>${escHtml(a.odgovoranLabel || a.odgovoranText || '—')}</td>
            <td>${escHtml(a.rokText || fmtDate(a.rok) || '—')}</td>
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
          <img src="${escHtml(sl.signedUrl || '')}" style="max-width:100%;border:1px solid #ccc">
          ${sl.caption ? `<figcaption style="font-size:11px;color:#666">${escHtml(sl.caption)}</figcaption>` : ''}
        </figure>
      `).join('')}
    </div>
  `;

  return `
    <!DOCTYPE html>
    <html lang="sr">
    <head>
      <meta charset="utf-8">
      <title>Zapisnik — ${escHtml(s.naslov)}</title>
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
      <h1>${escHtml(s.naslov)}</h1>
      <div class="meta">
        <div><strong>Datum:</strong> ${fmtDate(s.datum)}${s.vreme ? ' u ' + s.vreme : ''}</div>
        ${s.mesto ? `<div><strong>Mesto:</strong> ${escHtml(s.mesto)}</div>` : ''}
        <div><strong>Vodio sastanak:</strong> ${escHtml(s.vodioLabel || s.vodioEmail || '—')}</div>
        ${s.zapisnicarLabel || s.zapisnicarEmail ? `<div><strong>Zapisničar:</strong> ${escHtml(s.zapisnicarLabel || s.zapisnicarEmail)}</div>` : ''}
        <div><strong>Učesnici:</strong> ${ucesniciHtml}</div>
      </div>
      ${temeHtml}
      ${aktivnostiHtml}
      ${akcijeHtml}
      ${slikeHtml}
      ${s.napomena ? `<h2>Napomena</h2><p>${escHtml(s.napomena)}</p>` : ''}
      <hr style="margin-top:32px">
      <small style="color:#888">Generisano: ${new Date().toLocaleString('sr-RS')} · Servoteh interni sistem · Sastanci modul</small>
    </body>
    </html>
  `;
}

/**
 * Otvori print preview za snapshot zapisnik.
 * Ovo je MVP — koristi browser print to PDF.
 */
export function printZapisnik(snapshot) {
  const html = buildZapisnikHtml(snapshot);
  const w = window.open('', '_blank');
  if (!w) return false;
  w.document.write(html);
  w.document.close();
  /* Mali delay da se slike učitaju. */
  setTimeout(() => {
    try { w.print(); } catch (e) { /* user can print manually */ }
  }, 800);
  return true;
}

/* eslint-disable no-unused-vars */
export { SASTANAK_SLIKE_BUCKET };
/* eslint-enable no-unused-vars */
