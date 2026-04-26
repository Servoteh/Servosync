/**
 * Arhiva tab — zaključan info, download snapshot, PDF placeholder (Faza C).
 */

import { escHtml, showToast } from '../../../lib/dom.js';
import { formatDate } from '../../../lib/date.js';
import { loadArhivaSnapshot, saveSnapshot } from '../../../services/sastanciDetalj.js';

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

  host.innerHTML = `
    <div class="sast-arhiva-detalj">
      <section class="sast-pripremi-section">
        <h3>🔒 Zaključano</h3>
        <div class="sast-meta-grid">
          <div class="sast-meta-row"><span>Datum</span><span>${zakljucanAt}</span></div>
          <div class="sast-meta-row"><span>Zaključao</span><span>${escHtml(sastanak.zakljucanByEmail || '—')}</span></div>
        </div>
      </section>

      ${arhiva ? `
        <section class="sast-pripremi-section">
          <h3>📦 Snapshot</h3>
          <p class="sast-txt2">Datum snimanja: ${arhiva.arhiviranoAt ? new Date(arhiva.arhiviranoAt).toLocaleString('sr-Latn-RS') : '—'}</p>
          <div class="sast-arhiva-btns">
            <button type="button" class="btn" id="sdDownloadSnapshot">📥 Skini snapshot JSON</button>
            <button type="button" class="btn" id="sdRefreshSnapshot" title="Osveži snapshot sa trenutnim podacima">🔄 Osveži snapshot</button>
          </div>
        </section>
      ` : canWrite ? `
        <section class="sast-pripremi-section">
          <p class="sast-txt2">Snapshot još nije kreiran.</p>
          <button type="button" class="btn btn-primary" id="sdRefreshSnapshot">📦 Kreiraj snapshot</button>
        </section>
      ` : ''}

      <section class="sast-pripremi-section">
        <h3>📄 PDF zapisnik</h3>
        <button type="button" class="btn" disabled title="Stiže u Fazi C">📄 Generiši PDF zapisnik</button>
        <p class="sast-txt2" style="margin-top:8px">Generisanje PDF-a stiže u sledećoj fazi (Faza C).</p>
      </section>
    </div>
  `;

  if (arhiva) {
    host.querySelector('#sdDownloadSnapshot')?.addEventListener('click', () => {
      downloadJson(arhiva.snapshot, `snapshot_${sastanak.id}.json`);
    });
  }

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
