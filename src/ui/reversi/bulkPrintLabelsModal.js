/**
 * Bulk štampa barkod nalepnica — Reversi magacin / inventar.
 * Format i proxy: isto kao Lokacije → Štampa nalepnica polica (labelsPrint.js).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { canManageReversi } from '../../state/auth.js';
import { FORMAT_DIMS } from '../lokacije/labelsPrint.js';
import { printReversiLabelsBatch } from './reversiLabelsPrint.js';
import JsBarcode from 'jsbarcode';

export { composeMultiLabelTspl } from './reversiLabelsPrint.js';

function barcodeSvgHtml(value) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  try {
    JsBarcode(svg, String(value || ''), {
      format: 'CODE128',
      displayValue: false,
      margin: 0,
      height: 40,
      width: 1.2,
    });
  } catch {
    return '';
  }
  return svg.outerHTML;
}

const FORMAT_OPTIONS = [
  ['tsc', 'TSC 80×40 mm (termalni — podrazumevano)'],
  ['a4-105x74', 'A4 · 105×74,25 mm (2 u redu)'],
  ['a4-large', 'A4 · 80×80 mm (2×2)'],
  ['a4-grid', 'A4 kompakt 3-kolona'],
  ['wide-200x99', '200×99 mm (široka)'],
];

/**
 * @param {{ rows: object[], onClose?: () => void }} opts
 */
export function openBulkPrintLabelsModal(opts = {}) {
  if (!canManageReversi()) {
    showToast('Nemate pravo za štampu nalepnica');
    return;
  }
  const rows = Array.isArray(opts.rows) ? opts.rows.filter((r) => r?.barcode) : [];
  if (rows.length === 0) {
    showToast('Nema stavki sa barkodom');
    return;
  }

  const id = `revBulkLbl_${Date.now()}`;
  const state = { format: 'tsc', template: 'standard', copies: 1 };

  const shell = document.createElement('div');
  shell.innerHTML = `
    <div class="kadr-modal-overlay rev-modal-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal rev-modal" style="max-width:720px">
        <div class="kadr-modal-header">
          <h2>Štampa nalepnica (${rows.length})</h2>
          <button type="button" class="kadr-modal-close" data-rev-bulk-close>×</button>
        </div>
        <div class="kadr-modal-body rev-modal-body" id="revBulkLblBody"></div>
        <div class="kadr-modal-footer rev-modal-footer" id="revBulkLblFoot"></div>
      </div>
    </div>`;
  const overlay = shell.firstElementChild;
  if (!overlay) return;
  document.body.appendChild(overlay);

  const close = () => {
    overlay.remove();
    opts.onClose?.();
  };
  overlay.querySelector('[data-rev-bulk-close]')?.addEventListener('click', close);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) close();
  });

  function paint() {
    const body = overlay.querySelector('#revBulkLblBody');
    const foot = overlay.querySelector('#revBulkLblFoot');
    if (!body || !foot) return;

    const tscOnly = state.format === 'tsc';

    body.innerHTML = `
      <p class="rev-muted" style="font-size:12px;margin:0 0 10px">
        Isti formati kao u modulu <strong>Lokacije → Štampa nalepnica</strong>. TSC šalje TSPL2 na LAN proxy; A4 formati otvaraju browser (Ctrl+P).
      </p>
      <ul class="rev-bulk-lbl-list">
        ${rows
          .map(
            (r) => `<li class="rev-bulk-lbl-item">
            <div class="rev-bulk-lbl-thumb">${barcodeSvgHtml(r.barcode)}</div>
            <div>
              <div class="rev-mono rev-strong">${escHtml(r.barcode || '')}</div>
              <div>${escHtml(r.oznaka || '')} — ${escHtml((r.naziv || '').slice(0, 40))}</div>
            </div>
          </li>`,
          )
          .join('')}
      </ul>
      <div class="rev-form-grid" style="grid-template-columns:1fr 1fr;gap:12px">
        <label class="rev-field">
          <span class="rev-field-label">Format (kao Lokacije)</span>
          <select id="revBulkFormat" class="rev-select">
            ${FORMAT_OPTIONS.map(
              ([v, lab]) =>
                `<option value="${escHtml(v)}" ${state.format === v ? 'selected' : ''}>${escHtml(lab)}</option>`,
            ).join('')}
          </select>
        </label>
        <label class="rev-field">
          <span class="rev-field-label">Kopija po stavci</span>
          <input type="number" id="revBulkCopies" class="rev-input" min="1" max="50" value="${state.copies}"/>
        </label>
        ${
          tscOnly
            ? `<label class="rev-field">
          <span class="rev-field-label">Šablon TSC (sadržaj)</span>
          <select id="revBulkTpl" class="rev-select">
            <option value="standard" ${state.template === 'standard' ? 'selected' : ''}>Standard 80×40 (ručni / rezni)</option>
            <option value="mini" ${state.template === 'mini' ? 'selected' : ''}>Mini 30×15 (pločice — štampač podešen u admin-u)</option>
          </select>
        </label>`
            : ''
        }
      </div>`;

    foot.innerHTML = `
      <button type="button" class="rev-btn" data-rev-bulk-close>Otkaži</button>
      <button type="button" class="rev-btn rev-btn--secondary" id="revBulkPreview">Preview u novom tabu</button>
      <button type="button" class="rev-btn rev-btn--primary" id="revBulkPrint">Štampaj</button>`;

    foot.querySelectorAll('[data-rev-bulk-close]').forEach((b) => b.addEventListener('click', close));

    body.querySelector('#revBulkFormat')?.addEventListener('change', (e) => {
      const v = e.target.value;
      state.format = FORMAT_DIMS[v] ? v : 'tsc';
      paint();
    });
    body.querySelector('#revBulkTpl')?.addEventListener('change', (e) => {
      state.template = e.target.value === 'mini' ? 'mini' : 'standard';
    });
    body.querySelector('#revBulkCopies')?.addEventListener('change', (e) => {
      state.copies = Math.max(1, Math.min(50, Math.floor(Number(e.target.value) || 1)));
    });

    foot.querySelector('#revBulkPreview')?.addEventListener('click', async () => {
      await printReversiLabelsBatch(rows, {
        format: state.format,
        template: state.template,
        copies: state.copies,
        dryRun: true,
      });
    });

    foot.querySelector('#revBulkPrint')?.addEventListener('click', async () => {
      const btn = foot.querySelector('#revBulkPrint');
      if (btn) btn.disabled = true;
      const total = rows.length * state.copies;
      await printReversiLabelsBatch(rows, {
        format: state.format,
        template: state.template,
        copies: state.copies,
      });
      if (btn) btn.disabled = false;
      showToast(`Pripremljeno ${total} nalepnica za štampu`);
      close();
      opts.onPrinted?.();
    });
  }

  paint();
}
