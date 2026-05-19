/**
 * Quick Return — skeniraj barkod alata i potvrdi povraćaj.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { startScan, stopScan } from '../../services/barcode.js';
import {
  confirmReturn,
  confirmCuttingReturn,
  fetchOpenHandLineByToolBarcode,
  fetchMyIssuedCuttingTools,
  getMagacinLocationId,
} from '../../services/reversiService.js';

/**
 * @param {{ onSuccess?: () => void }} opts
 */
export function openQuickReturnModal(opts = {}) {
  const id = `revQr_${Date.now()}`;
  const state = { pending: false, scanCtrl: null, match: null };

  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay rev-modal-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal rev-modal rev-modal--quick-return">
        <div class="kadr-modal-header">
          <h2>Skeniraj vraćanje</h2>
          <button type="button" class="kadr-modal-close" data-rev-qr-close>×</button>
        </div>
        <div class="kadr-modal-body rev-modal-body" id="revQrBody"></div>
        <div class="kadr-modal-footer rev-modal-footer" id="revQrFoot"></div>
      </div>
    </div>`;
  const overlay = wrap.firstElementChild;
  if (!overlay) return;
  document.body.appendChild(overlay);

  const close = () => {
    stopScan(state.scanCtrl);
    overlay.remove();
  };
  overlay.querySelector('[data-rev-qr-close]')?.addEventListener('click', close);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) close();
  });

  function paint() {
    const body = overlay.querySelector('#revQrBody');
    const foot = overlay.querySelector('#revQrFoot');
    if (!body || !foot) return;

    const card = state.match
      ? `<div class="rev-qr-card">
          <p>Vraćaš <strong class="rev-mono">${escHtml(state.match.barcode || '')}</strong></p>
          <p>sa reversa <span class="rev-mono">${escHtml(state.match.doc_number || '')}</span></p>
          <p class="rev-muted">zadužio ${escHtml(state.match.recipient_label || '—')}</p>
        </div>`
      : `<p class="rev-muted">Skeniraj barkod alata (ALAT-… ili RZN-…)</p>
         <div class="rev-qi-video-wrap">
           <video id="revQrVideo" playsinline muted></video>
         </div>
         <button type="button" class="rev-btn rev-btn--secondary" id="revQrScan">Skeniraj</button>`;

    body.innerHTML = card;
    foot.innerHTML = state.match
      ? `<button type="button" class="rev-btn" data-rev-qr-close>Otkaži</button>
         <button type="button" class="rev-btn rev-btn--primary" id="revQrConfirm" ${state.pending ? 'disabled' : ''}>${state.pending ? 'Čuvam…' : 'Potvrdi vraćanje'}</button>`
      : `<button type="button" class="rev-btn" data-rev-qr-close>Zatvori</button>`;

    foot.querySelector('#revQrConfirm')?.addEventListener('click', () => void confirm());
    body.querySelector('#revQrScan')?.addEventListener('click', () => void startScanFlow());
    if (!state.match) void startScanFlow();
  }

  async function startScanFlow() {
    const video = overlay.querySelector('#revQrVideo');
    if (!video) return;
    stopScan(state.scanCtrl);
    state.scanCtrl = await startScan(video, {
      decodeProfile: 'item',
      onResult: (text) => {
        stopScan(state.scanCtrl);
        state.scanCtrl = null;
        void resolveBarcode(text.trim());
      },
    });
  }

  async function resolveBarcode(bc) {
    if (/^ALAT-/i.test(bc)) {
      const r = await fetchOpenHandLineByToolBarcode(bc);
      if (!r.ok || !r.data) {
        showToast('Nema otvorenog reversa za ovaj alat');
        return;
      }
      state.match = {
        kind: 'HAND',
        barcode: r.data.tool.barcode,
        doc_number: r.data.doc_number,
        recipient_label: r.data.recipient_label,
        line_id: r.data.line_id,
        document_id: r.data.document_id,
      };
      paint();
      return;
    }
    if (/^RZN-/i.test(bc)) {
      const my = await fetchMyIssuedCuttingTools();
      const rows = my.ok && Array.isArray(my.data) ? my.data : [];
      const hit = rows.find((x) => String(x.barcode || '').toUpperCase() === bc.toUpperCase());
      if (!hit?.line_id) {
        showToast('Nema vašeg otvorenog zaduženja za ovu šifru');
        return;
      }
      state.match = {
        kind: 'CUTTING',
        barcode: hit.barcode,
        doc_number: hit.doc_number,
        recipient_label: hit.issued_to_employee_name || '—',
        line_id: hit.line_id,
        document_id: hit.document_id,
        remaining: Number(hit.remaining_quantity ?? hit.quantity) || 1,
        unit: hit.unit || 'kom',
      };
      paint();
      return;
    }
    showToast('Nepoznat format barkoda');
  }

  async function confirm() {
    if (!state.match || state.pending) return;
    state.pending = true;
    paint();
    const magId = await getMagacinLocationId();
    if (!magId) {
      state.pending = false;
      showToast('Magacin lokacija nije podešena');
      paint();
      return;
    }
    if (state.match.kind === 'HAND') {
      const res = await confirmReturn({
        doc_id: state.match.document_id,
        return_to_location_id: magId,
        return_notes: 'Quick return skener',
        returned_lines: [{ line_id: state.match.line_id, returned_quantity: 1 }],
      });
      state.pending = false;
      if (!res.ok) {
        showToast(res.error || 'Greška povraćaja');
        paint();
        return;
      }
    } else {
      const res = await confirmCuttingReturn({
        doc_id: state.match.document_id,
        return_to_location_id: null,
        returned_lines: [
          {
            line_id: state.match.line_id,
            returned_quantity: state.match.remaining || 1,
          },
        ],
        return_notes: 'Quick return skener',
      });
      state.pending = false;
      if (!res.ok) {
        showToast(res.error || 'Greška povraćaja');
        paint();
        return;
      }
    }
    showToast('Vraćeno');
    close();
    opts.onSuccess?.();
  }

  paint();
}
