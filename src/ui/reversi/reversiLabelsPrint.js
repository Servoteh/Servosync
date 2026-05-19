/**
 * Reversi — štampa nalepnica (isti formati i proxy put kao Lokacije → labelsPrint.js).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { formatRevAssetKind } from '../../lib/revAssetKind.js';
import {
  FORMAT_DIMS,
  dispatchOptionalNetworkLabelPrint,
} from '../lokacije/labelsPrint.js';
import {
  buildTspCuttingToolLabelProgram,
  buildTspHandToolLabelProgram,
  buildTspMiniInsertLabelProgram,
} from '../../lib/tspl2.js';

/** @typedef {'standard'|'mini'} ReversiTsplTemplate */
/** @typedef {keyof typeof FORMAT_DIMS} ReversiLabelFormat */

const REVERSI_LABEL_CSS = `
  @page { size: 80mm 38mm; margin: 0; }
  * { box-sizing: border-box; }
  html, body { margin:0; padding:0; font-family: Arial, sans-serif; color:#000; background:#fff; }
  :root { --print-scale: 0.95; }
  .toolbar {
    position: sticky; top: 0; z-index: 10;
    padding: 8px 12px; background:#eef; font-size:12px; border-bottom:1px solid #99c;
  }
  .toolbar button { margin-left:8px; padding:4px 10px; cursor:pointer; }
  .toolbar .hint { color:#444; margin-left:12px; }
  .label {
    width: 80mm; height: 38mm; max-height: 38mm;
    padding: 0.4mm 2mm 0.4mm 7mm;
    display: flex; flex-direction: column;
    gap: 0.3mm;
    page-break-after: always;
    overflow: hidden;
    zoom: var(--print-scale);
  }
  .label:last-child { page-break-after: auto; }
  .lbl-meta { flex: 0 0 auto; font-size: 7pt; line-height: 1.15; }
  .lbl-row-full { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .lbl-strong { font-weight: 700; font-size: 11pt; }
  .lbl-muted { font-size: 6.5pt; color: #333; }
  .lbl-bc { flex: 1 1 auto; min-height: 14mm; display:flex; align-items:flex-end; }
  .lbl-bc svg { width: 100%; height: 15mm; }
  .lbl-footline { flex: 0 0 auto; text-align: center; font-weight: 700; font-size: 9pt; font-family: monospace; }
  @media print { .toolbar { display: none; } .label { border: 0; } }
`;

function reversiLabelHtmlShell(count, format) {
  const dims = FORMAT_DIMS[format] || FORMAT_DIMS.tsc;
  const isTsc = format === 'tsc';
  const pageRule = isTsc
    ? `@page { size: ${dims.w} ${dims.h}; margin: 0; }`
    : `@page { size: A4; margin: ${dims.pageMargins != null ? dims.pageMargins : '8mm'}; }`;
  const gapScreen = dims.gapScreen != null ? dims.gapScreen : '4mm';
  const gapPrint = dims.gapPrint != null ? dims.gapPrint : '0';

  return `<!DOCTYPE html>
<html lang="sr-Latn">
<head>
  <meta charset="UTF-8">
  <title> </title>
  <style>
    ${pageRule}
    * { box-sizing: border-box; }
    html, body { margin:0; padding:0; font-family: Arial, sans-serif; color:#000; background:#fff; }
    .toolbar {
      position: sticky; top: 0; z-index: 10;
      padding: 10px 16px; background: #eef;
      border-bottom: 1px solid #99c; font-size: 13px;
    }
    .toolbar button {
      padding: 6px 14px; margin-left: 8px; cursor: pointer;
      font-size: 13px; border: 1px solid #334; background: #fff; border-radius: 4px;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(${dims.cols}, ${dims.w});
      gap: ${gapScreen};
      padding: 10px 16px 24px;
      justify-content: center;
    }
    .label.fmt-browser {
      width: ${dims.w};
      height: ${dims.h};
      border: 1px dashed #666;
      padding: 3mm;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      page-break-inside: avoid;
    }
    .label-codebox { flex: 1; display:flex; align-items:center; justify-content:center; min-height: 20mm; }
    .label-footline { font-weight: 900; text-align: center; font-size: 10pt; }
    @media print {
      .toolbar { display: none; }
      .grid { padding: 0; gap: ${gapPrint}; }
      .label.fmt-browser { border: 1px solid #000; }
    }
  </style>
  ${isTsc ? `<style>${REVERSI_LABEL_CSS}</style>` : ''}
</head>
<body>
  <div class="toolbar">
    Reversi nalepnice: <strong>${count}</strong> · format <strong>${escHtml(dims.name)}</strong>.
    Pritisni <strong>Ctrl + P</strong> za štampu.
    <button onclick="window.print()">Štampaj</button>
    <button onclick="window.close()">Zatvori</button>
    <span class="hint">U Chrome dijalogu isključi <em>Headers and footers</em> i marginu <em>None</em> (kao u modulu Lokacije).</span>
  </div>
  <div id="labelGrid" class="grid"></div>
</body>
</html>`;
}

/**
 * @param {object} row
 * @param {number} index
 * @param {boolean} isTsc
 */
function buildReversiLabelHtmlBlock(row, index, isTsc) {
  const barcode = String(row.barcode || '').trim();
  const oznaka = String(row.oznaka || '').trim();
  const naziv = String(row.naziv || '').trim();
  let sub = '';
  if (row.grupa === 'HAND' || row.kind === 'HAND') {
    const parts = [formatRevAssetKind(row.asset_kind), row.serijski_broj].filter(Boolean);
    sub = parts.join(' · ');
  } else if (row.klasa) {
    sub = `Klasa: ${row.klasa}`;
  }
  if (isTsc) {
    return `<div class="label" data-bc-idx="${index}">
      <div class="lbl-meta">
        <div class="lbl-row-full lbl-strong">${escHtml(oznaka)}</div>
        <div class="lbl-row-full">${escHtml(naziv)}</div>
        ${sub ? `<div class="lbl-row-full lbl-muted">${escHtml(sub)}</div>` : ''}
      </div>
      <div class="lbl-bc"><svg id="bc_${index}"></svg></div>
      <div class="lbl-footline">${escHtml(barcode)}</div>
    </div>`;
  }
  return `<div class="label fmt-browser">
    <div class="label-codebox"><svg id="bc_${index}" class="label-barcode"></svg></div>
    <div class="label-footline">${escHtml(oznaka)} — ${escHtml(barcode)}</div>
    <div style="font-size:9pt;text-align:center;margin-top:2px">${escHtml(naziv.slice(0, 42))}</div>
  </div>`;
}

/**
 * @param {object[]} rows
 * @param {ReversiTsplTemplate} template
 * @param {number} copies
 * @returns {string}
 */
export function composeMultiLabelTspl(rows, template, copies) {
  const n = Math.max(1, Math.min(50, Math.floor(Number(copies) || 1)));
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

/**
 * Batch štampa — isti obrazac kao Lokacije (browser + opcioni TSC proxy).
 *
 * @param {object[]} rows
 * @param {{ format?: ReversiLabelFormat, template?: ReversiTsplTemplate, copies?: number }} [opts]
 */
export async function printReversiLabelsBatch(rows, opts = {}) {
  if (!Array.isArray(rows) || !rows.length) {
    showToast('Nema stavki za štampu');
    return { ok: false, reason: 'empty' };
  }

  const format = FORMAT_DIMS[opts.format] ? opts.format : 'tsc';
  const template = opts.template === 'mini' ? 'mini' : 'standard';
  const copies = Math.max(1, Math.min(50, Math.floor(Number(opts.copies) || 1)));
  const isTsc = format === 'tsc';

  const flat = [];
  for (const row of rows) {
    if (!row?.barcode) continue;
    for (let i = 0; i < copies; i += 1) flat.push(row);
  }
  if (!flat.length) {
    showToast('Nema barkoda za štampu');
    return { ok: false, reason: 'no_barcode' };
  }

  const mod = await import('jsbarcode');
  const JsBarcode = mod.default || mod;
  const w = window.open('', '_blank');
  if (!w) {
    showToast('Dozvoli pop-up da bi štampao nalepnice');
    return { ok: false, reason: 'popup_blocked' };
  }

  w.document.write(reversiLabelHtmlShell(flat.length, format));
  w.document.close();

  const run = () => {
    const host = w.document.getElementById('labelGrid');
    if (!host) return;
    host.innerHTML = flat.map((row, i) => buildReversiLabelHtmlBlock(row, i, isTsc)).join('');
    flat.forEach((row, i) => {
      const svg = w.document.getElementById(`bc_${i}`);
      if (!svg || !row.barcode) return;
      const tall = isTsc ? 80 : format === 'wide-200x99' ? 148 : format === 'a4-large' ? 92 : 72;
      try {
        JsBarcode(svg, String(row.barcode).trim(), {
          format: 'CODE128',
          displayValue: false,
          margin: 0,
          height: tall,
          width: isTsc ? 2.2 : 2.2,
          background: '#ffffff',
          lineColor: '#000000',
        });
      } catch (e) {
        console.error('[reversi/labels] JsBarcode', e);
      }
    });
  };
  if (w.document.readyState === 'complete') run();
  else w.addEventListener('load', run, { once: true });

  let tspl2 = '';
  let proxyRes = { ok: false, reason: 'no_proxy_url' };
  if (isTsc) {
    try {
      tspl2 = composeMultiLabelTspl(rows, template, copies);
    } catch (e) {
      console.warn('[reversi/labels] TSPL2 build failed:', e);
      showToast(`Greška TSPL: ${e?.message || e}`);
      return { ok: false, reason: 'tspl2_build_failed' };
    }
    proxyRes = await dispatchOptionalNetworkLabelPrint({
      mode: 'reversi_bulk',
      count: flat.length,
      payload: {
        format,
        template,
        copies,
        labels: flat.map((r) => ({
          barcode: r.barcode,
          oznaka: r.oznaka,
          naziv: r.naziv,
          grupa: r.grupa || r.kind,
        })),
        tspl2,
      },
    });
    if (proxyRes.ok) {
      showToast(`Poslato ${flat.length} nalepnica na TSC (${FORMAT_DIMS.tsc.name})`);
    } else if (proxyRes.reason === 'no_proxy_url') {
      showToast('LAN proxy nije podešen — koristi browser print (Ctrl+P)');
    } else {
      showToast(`Štampač: ${proxyRes.reason} — koristi browser print`);
    }
  } else {
    showToast(`Otvoren preview — ${FORMAT_DIMS[format].name} (Ctrl+P)`);
  }

  return { ok: true, proxy: proxyRes };
}
