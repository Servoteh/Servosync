/**
 * Arhiva tab — zaključan info, JSON snapshot, PDF zapisnik (Faza C).
 */

import { escHtml, showToast } from '../../../lib/dom.js';
import { loadArhivaSnapshot, saveSnapshot } from '../../../services/sastanciDetalj.js';
import { downloadSastanakPdf, regenerateSastanakPdf } from '../../../services/sastanciArhiva.js';
import { isAdmin, isAdminOrMenadzment } from '../../../state/auth.js';

let abortFlag = false;

export async function renderArhivaDetaljTab(host, { sastanak, canWrite }) {
  abortFlag = false;
  const isLocked = sastanak.status === 'zakljucan' || sastanak.status === 'zavrsen';

  if (!isLocked) {
    host.innerHTML = `
      <div class="sast-arhiva-empty">
        <p>Sastanak još nije zaključan.</p>
        <p class="sast-txt2">Kad završiš zapisnik, klikni <strong>Zaključaj</strong> u zaglavlju.</p>
      </div>
    `;
    return;
  }

  host.innerHTML = '<div class="sast-loading">Učitavam arhivu…</div>';

  let arhiva;
  try {
    arhiva = await loadArhivaSnapshot(sastanak.id);
  } catch (e) {
    console.error('[ArhivaDetaljTab] load error', e);
  }

  if (abortFlag) return;

  render(host, arhiva, sastanak, canWrite);
}

function render(host, arhiva, sastanak, canWrite) {
  const zakljucanAt = sastanak.zakljucanAt
    ? new Date(sastanak.zakljucanAt).toLocaleString('sr-Latn-RS')
    : '—';

  const hasPdf = !!(arhiva?.zapisnikStoragePath);
  const canRegen = isAdminOrMenadzment();
  const pdfGenAt = arhiva?.zapisnikGeneratedAt
    ? new Date(arhiva.zapisnikGeneratedAt).toLocaleString('sr-Latn-RS')
    : null;

  host.innerHTML = `
    <div class="sast-arhiva-detalj">

      <section class="sast-pripremi-section">
        <h3>🔒 Zaključano</h3>
        <div class="sast-meta-grid">
          <div class="sast-meta-row"><span>Datum</span><span>${zakljucanAt}</span></div>
          <div class="sast-meta-row"><span>Zaključao</span><span>${escHtml(sastanak.zakljucanByEmail || '—')}</span></div>
        </div>
      </section>

      <section class="sast-pripremi-section">
        <h3>📄 PDF zapisnik</h3>
        ${hasPdf ? `
          <p class="sast-txt2">Generisan: ${pdfGenAt || '—'}</p>
          <div class="sast-arhiva-btns">
            <button type="button" class="btn btn-primary" id="sdDownloadPdf">📥 Skini PDF</button>
            ${canRegen ? `
              <button type="button" class="btn" id="sdRegenPdf">🔄 Re-generiši PDF</button>
            ` : ''}
          </div>
        ` : `
          <div id="sdPdfBanner" class="sast-pdf-banner sast-pdf-banner--warn">
            ⚠ PDF nije generisan. Klikni dugme ispod da ga kreiraš.
          </div>
          ${canWrite ? `
            <button type="button" class="btn btn-primary" id="sdRegenPdf" style="margin-top:8px">
              📄 Generiši PDF zapisnik
            </button>
          ` : ''}
        `}
      </section>

      ${arhiva ? `
        <section class="sast-pripremi-section">
          <h3>📦 Snapshot</h3>
          <p class="sast-txt2">Datum snimanja: ${arhiva.arhiviranoAt ? new Date(arhiva.arhiviranoAt).toLocaleString('sr-Latn-RS') : '—'}</p>
          <div class="sast-arhiva-btns">
            <button type="button" class="btn" id="sdDownloadSnapshot">📥 Skini snapshot JSON</button>
            <button type="button" class="btn" id="sdRefreshSnapshot" title="Osveži snapshot">🔄 Osveži snapshot</button>
          </div>
        </section>
      ` : canWrite ? `
        <section class="sast-pripremi-section">
          <p class="sast-txt2">Snapshot još nije kreiran.</p>
          <button type="button" class="btn btn-primary" id="sdRefreshSnapshot">📦 Kreiraj snapshot</button>
        </section>
      ` : ''}

    </div>
  `;

  // PDF download
  host.querySelector('#sdDownloadPdf')?.addEventListener('click', async () => {
    if (!arhiva?.zapisnikStoragePath) return;
    showToast('⏳ Preuzimam PDF…');
    await downloadSastanakPdf(arhiva.zapisnikStoragePath);
  });

  // PDF regenerate / generate
  host.querySelector('#sdRegenPdf')?.addEventListener('click', async () => {
    const btn = host.querySelector('#sdRegenPdf');
    if (!confirm('Generisati / re-generisati PDF zapisnik? Ovo može potrajati nekoliko sekundi.')) return;
    if (btn) btn.disabled = true;
    showToast('⏳ Generisujem PDF…');
    const ok = await regenerateSastanakPdf(sastanak.id);
    if (ok) {
      showToast('✅ PDF zapisnik je kreiran');
      renderArhivaDetaljTab(host, { sastanak, canWrite });
    } else {
      showToast('⚠ Generisanje nije uspelo. Pokušaj ponovo.');
      if (btn) btn.disabled = false;
    }
  });

  // Snapshot download
  host.querySelector('#sdDownloadSnapshot')?.addEventListener('click', () => {
    if (!arhiva?.snapshot) return;
    downloadJson(arhiva.snapshot, `snapshot_${sastanak.id}.json`);
  });

  // Snapshot refresh
  host.querySelector('#sdRefreshSnapshot')?.addEventListener('click', async () => {
    const btn = host.querySelector('#sdRefreshSnapshot');
    if (btn) btn.disabled = true;
    showToast('⏳ Kreiram snapshot…');
    const saved = await saveSnapshot(sastanak.id);
    if (saved) {
      showToast('✅ Snapshot sačuvan');
      renderArhivaDetaljTab(host, { sastanak, canWrite });
    } else {
      showToast('⚠ Nije uspelo');
      if (btn) btn.disabled = false;
    }
  });
}

function downloadJson(data, filename) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
  URL.revokeObjectURL(a.href);
}

export function teardownArhivaDetaljTab() {
  abortFlag = true;
}
