/**
 * Bulk štampa barkod nalepnica — Reversi magacin / inventar.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { canManageReversi } from '../../state/auth.js';
import {
  buildTspCuttingToolLabelProgram,
  buildTspHandToolLabelProgram,
  buildTspMiniInsertLabelProgram,
} from '../../lib/tspl2.js';
import { dispatchOptionalNetworkLabelPrint } from '../lokacije/labelsPrint.js';
import { formatRevAssetKind } from '../../lib/revAssetKind.js';
import JsBarcode from 'jsbarcode';

const JSPDF_CDN = 'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js';

/** @typedef {'standard'|'mini'|'pdf_a4'} BulkLabelTemplate */

/**
 * @param {object[]} rows
 * @param {BulkLabelTemplate} template
 * @param {number} copies
 * @returns {string}
 */
export function composeMultiLabelTspl(rows, template, copies) {
  const n = Math.max(1, Math.min(99, Math.floor(Number(copies) || 1)));
  const list = Array.isArray(rows) ? rows : [];
  const chunks = [];
  for (const row of list) {
    for (let c = 0; c < n; c += 1) {
      if (template === 'mini') {
        chunks.push(
          buildTspMiniInsertLabelProgram({
            barcode: row.barcode,
            oznaka: row.oznaka,
            klasa: row.klasa,
            copies: 1,
          }),
        );
      } else if (row.grupa === 'HAND' || row.kind === 'HAND') {
        chunks.push(
          buildTspHandToolLabelProgram({
            barcode: row.barcode,
            oznaka: row.oznaka,
            naziv: row.naziv,
            asset_kind: formatRevAssetKind(row.asset_kind),
            serial: row.serijski_broj || row.serial,
            copies: 1,
          }),
        );
      } else {
        chunks.push(
          buildTspCuttingToolLabelProgram({
            barcode: row.barcode,
            oznaka: row.oznaka,
            naziv: row.naziv,
            klasa: row.klasa,
            compatible_machine_codes: row.compatible_machine_codes || [],
            copies: 1,
          }),
        );
      }
    }
  }
  return chunks.join('\r\n');
}

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

async function loadJsPdf() {
  if (typeof window !== 'undefined' && window.jspdf?.jsPDF) {
    return window.jspdf.jsPDF;
  }
  await new Promise((resolve, reject) => {
    const existing = document.querySelector(`script[src="${JSPDF_CDN}"]`);
    if (existing?.dataset?.loaded) return resolve();
    if (existing) {
      existing.addEventListener('load', () => resolve());
      existing.addEventListener('error', () => reject(new Error('jsPDF CDN')));
      return;
    }
    const s = document.createElement('script');
    s.src = JSPDF_CDN;
    s.async = true;
    s.onload = () => {
      s.dataset.loaded = '1';
      resolve();
    };
    s.onerror = () => reject(new Error('jsPDF CDN'));
    document.head.appendChild(s);
  });
  return window.jspdf.jsPDF;
}

async function buildA4LabelsPdf(rows, copies) {
  const jsPDF = await loadJsPdf();
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  const labelW = 50;
  const labelH = 40;
  const cols = 4;
  const rowsPerPage = 6;
  const marginX = (210 - cols * labelW) / (cols + 1);
  const marginY = (297 - rowsPerPage * labelH) / (rowsPerPage + 1);
  const n = Math.max(1, Math.min(99, Math.floor(Number(copies) || 1)));
  const items = [];
  for (const row of rows) {
    for (let c = 0; c < n; c += 1) items.push(row);
  }
  let idx = 0;
  for (const row of items) {
    if (idx > 0 && idx % (cols * rowsPerPage) === 0) doc.addPage();
    const slot = idx % (cols * rowsPerPage);
    const col = slot % cols;
    const rowIdx = Math.floor(slot / cols);
    const x = marginX + col * (labelW + marginX);
    const y = marginY + rowIdx * (labelH + marginY);
    doc.setFontSize(9);
    doc.text(String(row.oznaka || '').slice(0, 28), x + 2, y + 5);
    doc.setFontSize(7);
    doc.text(String(row.naziv || '').slice(0, 36), x + 2, y + 10);
    const canvas = document.createElement('canvas');
    JsBarcode(canvas, String(row.barcode || ''), {
      format: 'CODE128',
      displayValue: true,
      fontSize: 10,
      margin: 2,
      height: 28,
      width: 1.1,
    });
    const img = canvas.toDataURL('image/png');
    const bcW = labelW - 4;
    const bcH = 18;
    doc.addImage(img, 'PNG', x + (labelW - bcW) / 2, y + labelH - bcH - 4, bcW, bcH);
    idx += 1;
  }
  return doc.output('bloburl');
}

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
  const state = { template: 'standard', copies: 1 };

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

    body.innerHTML = `
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
      <div class="rev-form-grid">
        <fieldset class="rev-field">
          <legend class="rev-field-label">Šablon</legend>
          <label class="rev-radio-row"><input type="radio" name="revBulkTpl" value="standard" ${state.template === 'standard' ? 'checked' : ''}/> Standard 80×40 (Ručni alat/Rezni alat)</label>
          <label class="rev-radio-row"><input type="radio" name="revBulkTpl" value="mini" ${state.template === 'mini' ? 'checked' : ''}/> Mini 30×15 (Glodačke pločice)</label>
          <label class="rev-radio-row"><input type="radio" name="revBulkTpl" value="pdf_a4" ${state.template === 'pdf_a4' ? 'checked' : ''}/> PDF A4 (24 nalepnice po listu)</label>
        </fieldset>
        <label>Broj kopija (1–99)
          <input type="number" id="revBulkCopies" class="rev-input" min="1" max="99" value="${state.copies}"/>
        </label>
      </div>`;

    foot.innerHTML = `
      <button type="button" class="rev-btn" data-rev-bulk-close>Otkaži</button>
      <button type="button" class="rev-btn rev-btn--secondary" id="revBulkPreview">Preview PDF</button>
      <button type="button" class="rev-btn rev-btn--primary" id="revBulkPrint">Pošalji u štampač</button>`;

    foot.querySelectorAll('[data-rev-bulk-close]').forEach((b) => b.addEventListener('click', close));

    body.querySelectorAll('input[name="revBulkTpl"]').forEach((inp) => {
      inp.addEventListener('change', () => {
        state.template = inp.value === 'mini' ? 'mini' : inp.value === 'pdf_a4' ? 'pdf_a4' : 'standard';
      });
    });
    body.querySelector('#revBulkCopies')?.addEventListener('change', (e) => {
      state.copies = Math.max(1, Math.min(99, Math.floor(Number(e.target.value) || 1)));
    });

    foot.querySelector('#revBulkPreview')?.addEventListener('click', async () => {
      const url = await buildA4LabelsPdf(rows, state.copies);
      window.open(url, '_blank', 'noopener');
    });

    foot.querySelector('#revBulkPrint')?.addEventListener('click', async () => {
      if (state.template === 'pdf_a4') {
        const url = await buildA4LabelsPdf(rows, state.copies);
        window.open(url, '_blank', 'noopener');
        showToast('PDF otvoren u novom tabu');
        return;
      }
      const tpl = state.template === 'mini' ? 'mini' : 'standard';
      let tspl2 = '';
      try {
        tspl2 = composeMultiLabelTspl(rows, tpl, state.copies);
      } catch (e) {
        showToast(`Greška TSPL: ${e?.message || e}`);
        return;
      }
      const res = await dispatchOptionalNetworkLabelPrint({
        mode: 'reversi_bulk',
        payload: { tspl2, count: rows.length * state.copies },
      });
      if (res.ok) {
        showToast(`Poslato ${rows.length * state.copies} nalepnica`);
        close();
      } else if (res.reason === 'no_proxy_url') {
        showToast('LAN proxy nije podešen (VITE_LABEL_PRINTER_PROXY_URL)');
      } else {
        showToast(`Štampač: ${res.reason || 'greška'}`);
      }
    });
  }

  paint();
}
