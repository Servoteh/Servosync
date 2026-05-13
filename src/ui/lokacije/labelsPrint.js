/**
 * Nalepnice — priprema podataka, print-ready HTML, štampa u pregledaču (Ctrl+P).
 * Opcioni LAN adapter: `VITE_LABEL_PRINTER_PROXY_URL` (POST JSON) za TSC gateway.
 *
 * **Layout TP nalepnice (80×50mm portrait, redizajn 2026-04):**
 *   - Tekst gore (8 polja, key:value, kompaktno)
 *   - Horizontalni CODE128 barkod dole, FULL WIDTH minus 2mm quiet zone svake strane
 *   - `@page { margin: 0 }` da Chrome NE doda datum / URL / page-num u sam label
 *   - Operater jednom u Chrome print dijalogu isključi „Headers and footers" za TSC printer
 *
 * **TSC ML340P (300 DPI) — clean path:**
 *   Ako je `VITE_LABEL_PRINTER_PROXY_URL` postavljen, šaljemo JSON koji UZ
 *   `payload.fields` sadrži i `payload.tspl2` — raw TSPL2 program kojim
 *   lokalni agent piše direktno u TCP 9100 na štampač (zaobilazi browser
 *   print headers/footers u potpunosti). Vidi `src/lib/tspl2.js`.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { fetchLocations } from '../../services/lokacije.js';
import { formatBigTehnRnzBarcode, formatBigTehnShortBarcode } from '../../lib/barcodeParse.js';
import { buildShelfPrintBarcodeParts } from '../../lib/shelfBarcode.js';
import { buildTspLabelProgram, buildTspShelfLabelProgram } from '../../lib/tspl2.js';

const SHELF_TYPES = ['SHELF', 'RACK', 'BIN'];

function removeEl(id) {
  document.getElementById(id)?.remove();
}

function bindEsc(onClose) {
  const h = ev => {
    if (ev.key === 'Escape') {
      ev.preventDefault();
      onClose();
    }
  };
  document.addEventListener('keydown', h);
  return () => document.removeEventListener('keydown', h);
}

/**
 * @param {{ mode: 'shelf'|'tech_process', payload: object }} args
 * @returns {Promise<{ ok: boolean, reason?: string }>}
 */
export async function dispatchOptionalNetworkLabelPrint(args) {
  const url =
    (typeof import.meta !== 'undefined' && import.meta.env?.VITE_LABEL_PRINTER_PROXY_URL) || '';
  if (!url || typeof url !== 'string') {
    return { ok: false, reason: 'no_proxy_url' };
  }
  try {
    const r = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(args),
    });
    return { ok: r.ok, reason: r.ok ? undefined : `http_${r.status}` };
  } catch (e) {
    return { ok: false, reason: String(e?.message || e) };
  }
}

/**
 * Format opcije za nalepnicu police:
 *   - 'wide-200x99' — 200×99 mm (portrait; podrazumevano — kod ima maksimalnu visinu za CODE128 na A4)
 *   - 'tsc'         — TSC ML340P 80×40mm (TSPL2 push, paralelni preview u browser-u)
 *   - 'a4-105x74'   — A4, 105×74,25 mm, 2 nalepnice u redu (puna širina 210 mm)
 *   - 'a4-large'    — A4, 80×80mm po nalepnici, 4 po stranici (2×2)
 *   - 'a4-grid'     — A4, kompaktni 3-kolona ~60mm raster (legacy)
 *
 * @typedef {'wide-200x99'|'tsc'|'a4-105x74'|'a4-large'|'a4-grid'} ShelfLabelFormat
 * @typedef {'barcode'|'qr'} ShelfCodeType
 */

const FORMAT_DIMS = {
  'wide-200x99': {
    w: '200mm',
    h: '99mm',
    cols: 1,
    name: '200×99 mm (široka)',
    /** 210 − 200 = 10 mm → uniformno 5 mm sa strana; ostaje prostor za 2× visina (~198 mm + gap) ili 3 strane kod nultih margina štampača. */
    pageMargins: '4.95mm 5mm',
    gapScreen: '10mm',
    gapPrint: '2mm',
  },
  tsc:         { w: '80mm',    h: '40mm',    cols: 1, name: 'TSC 80×40mm' },
  /* Dve × 105 mm širine = tačno portrait A4 210 mm; margin 0 u štampačkom @page kada je dostupno. */
  'a4-105x74': {
    w: '105mm',
    h: '74.25mm',
    cols: 2,
    name: 'A4 105×74,25 mm (2 u redu)',
    pageMargins: '0',
    gapScreen: '10mm',
    gapPrint: '0mm',
  },
  'a4-large':  { w: '80mm',    h: '80mm',    cols: 2, name: 'A4 80×80mm (2×2)' },
  'a4-grid':   { w: '60mm',    h: '40mm',    cols: 3, name: 'A4 kompakt (3 kol)' },
};

function shelfLabelHtml(loc, codeType, format) {
  const cls = `label fmt-${format}`;
  const codeBox =
    codeType === 'qr'
      ? `<canvas id="qr_${escHtml(String(loc.id))}" class="label-qr"></canvas>`
      : `<svg id="bc_${escHtml(String(loc.id))}" class="label-barcode"></svg>`;
  return `
    <div class="${cls}">
      <div class="label-codebox">${codeBox}</div>
    </div>`;
}

function shelfLabelsHtmlShell(count, codeType, format) {
  const dims = FORMAT_DIMS[format] || FORMAT_DIMS['wide-200x99'];
  const codeLabel = codeType === 'qr' ? 'QR kod' : 'Barkod';
  const isCompact = format === 'a4-grid';
  const isLarge = format === 'a4-large';
  const isTwoUp105 = format === 'a4-105x74';
  const isWide200 = format === 'wide-200x99';
  const isTsc = format === 'tsc';
  const pageMarginA4 = !isTsc && dims.pageMargins != null ? dims.pageMargins : '8mm';
  const gapScreen = dims.gapScreen != null ? dims.gapScreen : isLarge ? '5mm' : '4mm';
  const gapPrint = dims.gapPrint != null ? dims.gapPrint : isCompact ? '3mm' : isLarge ? '5mm' : '0';

  /* TSC put zapravo ide preko TSPL2 mreže — browser je samo backup preview.
   * A4 put = stvarna fizička štampa preko Chrome dijaloga. */
  const pageRule = isTsc
    ? `@page { size: ${dims.w} ${dims.h}; margin: 0; }`
    : `@page { size: A4; margin: ${pageMarginA4}; }`;

  /* Grafika ispuni nalepnicu (čitljiv trag); min-visina štiti mali TSC odozgo. */
  const codeBoxH =
    codeType === 'qr'
      ? isWide200 ? '88mm'
        : isLarge || isTwoUp105 ? '70mm'
        : '32mm'
      : isWide200 ? '90mm'
        : isLarge ? '74mm'
        : isTwoUp105 ? '64mm'
        : isTsc ? '32mm'
        : '30mm';
  return `<!DOCTYPE html>
<html lang="sr-Latn">
<head>
  <meta charset="UTF-8">
  <title>Nalepnice polica (${count})</title>
  <style>
    ${pageRule}
    * { box-sizing: border-box; }
    html, body {
      margin: 0; padding: 0;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      color: #000; background: #fff;
    }
    .toolbar {
      position: sticky; top: 0; z-index: 10;
      padding: 10px 16px; background: #eef;
      border-bottom: 1px solid #99c;
      font-size: 13px; color: #234;
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
    .label {
      width: ${dims.w};
      height: ${dims.h};
      border: 1px dashed #666;
      border-radius: 2mm;
      padding: 3mm;
      text-align: center;
      page-break-inside: avoid;
      break-inside: avoid;
      display: flex; flex-direction: column; justify-content: center; align-items: stretch;
      gap: 0;
      overflow: hidden;
    }
    .label-codebox {
      flex: 1 1 0;
      width: 100%;
      min-height: ${codeBoxH};
      display: flex; align-items: center; justify-content: center;
    }
    .label-barcode {
      width: 100%;
      height: 100%;
      max-height: 100%;
      display: block;
    }
    .label-qr {
      max-width: 100%;
      max-height: 100%;
      width: auto; height: auto;
      image-rendering: pixelated;
    }
    @media print {
      .toolbar { display: none; }
      .grid {
        padding: 0;
        gap: ${gapPrint};
        ${isTwoUp105 ? 'justify-content: flex-start;' : ''}
      }
      .label { border: 1px solid #000; }
      ${isWide200 && codeType === 'barcode' ? '.label.fmt-wide-200x99 { overflow: visible; }' : ''}
      ${isWide200 && codeType === 'barcode' ? '.label.fmt-wide-200x99 .label-codebox { min-height: 86mm; }' : ''}
      ${isTsc ? '.label { border: 0; }' : ''}
    }
  </style>
</head>
<body>
  <div class="toolbar">
    Nalepnice polica: <strong>${count}</strong> · format <strong>${escHtml(dims.name)}</strong> · <strong>${escHtml(codeLabel)}</strong>.
    Pritisni <strong>Ctrl + P</strong> za štampu.
    <button onclick="window.print()">Štampaj</button>
    <button onclick="window.close()">Zatvori</button>
  </div>
  <div id="labelGrid" class="grid"></div>
</body>
</html>`;
}

/**
 * Otvara novi prozor sa jednom ili više nalepnica polica.
 *
 * @param {object[]} locs
 * @param {{ codeType?: ShelfCodeType, format?: ShelfLabelFormat, copies?: number, locById?: Map<string, object> }} [opts]
 */
export async function printShelfLabelsToBrowserWindow(locs, opts = {}) {
  if (!Array.isArray(locs) || !locs.length) {
    showToast('⚠ Nema lokacija za štampu');
    return;
  }

  const locByIdForPrint =
    opts.locById instanceof Map && opts.locById.size ? opts.locById : new Map(locs.map(l => [String(l.id), l]));

  const codeType = opts.codeType === 'qr' ? 'qr' : 'barcode';
  const format = FORMAT_DIMS[opts.format] ? opts.format : 'wide-200x99';
  const copies = Math.max(1, Math.floor(Number(opts.copies) || 1));

  /* Razvi `copies` u flat listu — N kopija po polici izlazi N puta. */
  const flat = [];
  for (const l of locs) {
    const parts = buildShelfPrintBarcodeParts(l, locByIdForPrint);
    for (let i = 0; i < copies; i++)
      flat.push({
        ...l,
        printBarcodeValue: parts.barcodeValue,
        printDisplayPrimary: parts.displayPrimary,
      });
  }

  const [{ default: JsBarcode }, qrcodeMod] = await Promise.all([
    import('jsbarcode'),
    codeType === 'qr' ? import('qrcode') : Promise.resolve(null),
  ]);
  const QRCode = qrcodeMod ? (qrcodeMod.default || qrcodeMod) : null;

  const w = window.open('', '_blank');
  if (!w) {
    showToast('⚠ Dozvoli pop-up da bi štampao nalepnice');
    return;
  }

  w.document.write(shelfLabelsHtmlShell(flat.length, codeType, format));
  w.document.close();

  const runWhenReady = async () => {
    try {
      const host = w.document.getElementById('labelGrid');
      /* Mali per-render uniqueness suffix da multi-copies imaju jedinstven id u DOM-u. */
      host.innerHTML = flat
        .map((loc, i) => shelfLabelHtml({ ...loc, id: `${loc.id}_${i}` }, codeType, format))
        .join('');
      for (let i = 0; i < flat.length; i++) {
        const loc = flat[i];
        const code = String(loc.printBarcodeValue || '').trim();
        if (!code) continue;
        if (codeType === 'qr') {
          const canvas = w.document.getElementById(`qr_${loc.id}_${i}`);
          if (canvas && QRCode) {
            const qrWidthPx =
              format === 'wide-200x99'
                ? 880
                : format === 'a4-large' || format === 'a4-105x74'
                  ? 640
                  : format === 'tsc'
                    ? 440
                    : 420;
            await QRCode.toCanvas(canvas, code, {
              /* Manje ECC = manje modula pri istoj širini → krupniji modul lakši za foto/sistemsku kameru. */
              errorCorrectionLevel: 'L',
              margin: 2,
              width: qrWidthPx,
              color: { dark: '#000000', light: '#ffffff' },
            });
          }
        } else {
          const svg = w.document.getElementById(`bc_${loc.id}_${i}`);
          if (svg) {
            /* Istа skala kao na TP/stampaNalepnica (height 80, width 2.2); viša zona u CSS-u
             * dodaje „mast” po Y osi da dug LP ne izgleda kao tanka crtica na nalepnici. */
            const tall =
              format === 'wide-200x99'
                ? 148
                : format === 'a4-large'
                  ? 92
                  : format === 'a4-105x74'
                    ? 86
                    : format === 'tsc'
                      ? 72
                      : 58;
            const modW =
              format === 'wide-200x99' ? 2.95
              : 2.2;
            JsBarcode(svg, code, {
              format: 'CODE128',
              displayValue: false,
              margin: 0,
              height: tall,
              width: modW,
              background: '#ffffff',
              lineColor: '#000000',
            });
          }
        }
      }
    } catch (e) {
      console.error('[labels] render failed', e);
      w.document.body.innerHTML = `<p style="padding:20px;color:#c00">Greška: ${String(e?.message || e)}</p>`;
    }
  };

  if (w.document.readyState === 'complete') void runWhenReady();
  else w.addEventListener('load', () => void runWhenReady(), { once: true });

  /* TSPL2 paralelno SAMO za TSC format — A4 putevi idu samo kroz browser. */
  if (format === 'tsc') {
    let tspl2 = '';
    try {
      tspl2 = locs
        .map(l => {
          const parts = buildShelfPrintBarcodeParts(l, locByIdForPrint);
          return buildTspShelfLabelProgram({
            location_code: l.location_code,
            barcodeValue: parts.barcodeValue,
            copies,
            codeType,
          });
        })
        .join('');
    } catch (e) {
      console.warn('[labels/shelf] TSPL2 build failed:', e);
    }
    void dispatchOptionalNetworkLabelPrint({
      mode: 'shelf',
      payload: {
        locations: locs.map(l => {
          const parts = buildShelfPrintBarcodeParts(l, locByIdForPrint);
          return {
            id: l.id,
            code: l.location_code,
            name: l.name,
            barcodeValue: parts.barcodeValue,
            displayPrimary: parts.displayPrimary,
          };
        }),
        codeType,
        copies,
        tspl2,
      },
    });
  }
}

/**
 * Modal: pretraga → izbor jedne ili više polica → izbor formata/koda → štampa.
 *
 * Funkcionalnost (2026-05):
 *   - Multi-select (čekboks) — operater bira N polica → 1 batch otisak
 *   - Grafika štampa **`ŠIF_HALE - ŠIF_POLICE`** (kratko je i u barcode/QR i na skenu); još uvek prima i legacy **`LP:hala_uuid:polica_uuid`**.
 *   - Kopije po polici (1+)
 *   - Pretraga po šifri / nazivu / path-u
 *   - "Označi sve prikazane" / "Očisti izbor"
 */
export async function openShelfLabelsPrintPicker() {
  const locs = await fetchLocations();
  if (!Array.isArray(locs) || !locs.length) {
    showToast('⚠ Nema lokacija');
    return;
  }

  const candidates = locs
    .filter(l => l.is_active !== false)
    .filter(l => SHELF_TYPES.includes(l.location_type))
    .sort((a, b) => (a.location_code || '').localeCompare(b.location_code || ''));

  if (!candidates.length) {
    showToast('⚠ Nema aktivnih polica (SHELF/RACK/BIN)');
    return;
  }

  const id = 'locModalShelfLabel';
  removeEl(id);
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal" style="max-width:640px">
        <div class="kadr-modal-title">Štampa nalepnica polica</div>
        <div class="kadr-modal-subtitle">Označi jednu ili više polica. Grafika štampa najkraće moguće: <strong>npr. MAG-X - P-09</strong> (šifrom hale razmak crtica razmak šifrom police) samo u barkodu ili QR-u, bez dodatnog teksta na nalepnici. Podrazumevano barkod na formatu <strong>200×99&nbsp;mm</strong>.</div>
        <div class="kadr-modal-body">
          <label class="loc-filter-field" style="display:block;margin-bottom:10px">
            <span>Pretraga police</span>
            <input type="search" class="loc-search-input" id="locShelfPickQ" autocomplete="off" placeholder="Šifra, naziv ili putanja…" />
          </label>

          <div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:8px">
            <button type="button" class="btn btn-xs" id="locShelfPickAllVisible">Označi sve prikazane</button>
            <button type="button" class="btn btn-xs" id="locShelfPickClearSel">Očisti izbor</button>
            <span class="loc-muted" id="locShelfPickCount" style="margin-left:auto;align-self:center;font-size:12px">0 izabrano</span>
          </div>

          <div id="locShelfPickList" class="loc-list" style="max-height:240px;overflow:auto;border:1px solid var(--border2,#ddd);border-radius:6px;padding:4px"></div>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:14px">
            <label class="loc-filter-field" style="display:block">
              <span>Tip koda</span>
              <select id="locShelfPickCodeType" class="loc-search-input">
                <option value="barcode" selected>Barkod (CODE128)</option>
                <option value="qr">QR kod</option>
              </select>
            </label>
            <label class="loc-filter-field" style="display:block">
              <span>Format</span>
              <select id="locShelfPickFormat" class="loc-search-input">
                <option value="wide-200x99" selected>200×99 mm (široka — podrazumevano)</option>
                <option value="a4-105x74">A4 · 105×74,25 mm (2 u redu)</option>
                <option value="a4-large">A4 · 80×80 mm (2×2)</option>
                <option value="a4-grid">A4 kompakt 3-kolona</option>
                <option value="tsc">TSC 80×40 mm (termalni)</option>
              </select>
            </label>
          </div>
          <label class="loc-filter-field" style="display:block;margin-top:10px;max-width:160px">
            <span>Kopija po polici</span>
            <input type="number" id="locShelfPickCopies" class="loc-search-input" min="1" max="50" value="1" inputmode="numeric" />
          </label>

          <div class="kadr-modal-actions" style="margin-top:18px">
            <button type="button" class="btn btn-primary" id="locShelfPickDoPrint" disabled>Štampaj</button>
            <button type="button" class="btn" id="locShelfPickCancel">Otkaži</button>
          </div>
        </div>
      </div>
    </div>`;
  document.body.appendChild(wrap.firstElementChild);
  const overlay = document.getElementById(id);
  const listEl = overlay.querySelector('#locShelfPickList');
  const qEl = overlay.querySelector('#locShelfPickQ');
  const countEl = overlay.querySelector('#locShelfPickCount');
  const btnPrint = overlay.querySelector('#locShelfPickDoPrint');
  const btnCancel = overlay.querySelector('#locShelfPickCancel');
  const btnAllVisible = overlay.querySelector('#locShelfPickAllVisible');
  const btnClearSel = overlay.querySelector('#locShelfPickClearSel');
  const codeTypeEl = overlay.querySelector('#locShelfPickCodeType');
  const formatEl = overlay.querySelector('#locShelfPickFormat');
  const copiesEl = overlay.querySelector('#locShelfPickCopies');

  /** @type {Set<string>} */
  const selectedIds = new Set();
  let search = '';
  let visibleRows = candidates.slice();

  const close = () => {
    unesc();
    removeEl(id);
  };
  const unesc = bindEsc(close);

  const updateCount = () => {
    const n = selectedIds.size;
    const copies = Math.max(1, Math.floor(Number(copiesEl.value) || 1));
    const total = n * copies;
    countEl.textContent = n
      ? `${n} izabrano · ${total} otisak${total === 1 ? '' : total < 5 ? 'a' : 'a'}`
      : '0 izabrano';
    btnPrint.disabled = n === 0;
    btnPrint.textContent = n
      ? `Štampaj ${total} nalepnic${total === 1 ? 'u' : total < 5 ? 'e' : 'a'}`
      : 'Štampaj';
  };

  const renderRows = () => {
    const q = search.trim().toLowerCase();
    visibleRows = !q
      ? candidates
      : candidates.filter(
          l =>
            String(l.location_code || '').toLowerCase().includes(q) ||
            String(l.name || '').toLowerCase().includes(q) ||
            String(l.path_cached || '').toLowerCase().includes(q),
        );

    listEl.innerHTML = visibleRows.length
      ? visibleRows
          .map(l => {
            const lid = String(l.id);
            const checked = selectedIds.has(lid) ? ' checked' : '';
            return `<label class="loc-row-click" style="display:flex;align-items:center;gap:10px;padding:6px 8px;cursor:pointer;border-radius:4px"
              data-loc-id="${escHtml(lid)}">
              <input type="checkbox" data-loc-cb="${escHtml(lid)}"${checked} />
              <span style="flex:1;min-width:0">
                <strong>${escHtml(l.location_code || '')}</strong>
                <span class="loc-muted"> · ${escHtml(l.name || '')}</span>
                ${l.path_cached ? `<div class="loc-muted" style="font-size:11px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${escHtml(l.path_cached)}</div>` : ''}
              </span>
            </label>`;
          })
          .join('')
      : '<p class="loc-muted" style="padding:10px">Nema pogodaka.</p>';

    listEl.querySelectorAll('[data-loc-cb]').forEach(cb => {
      cb.addEventListener('change', () => {
        const lid = cb.getAttribute('data-loc-cb');
        if (cb.checked) selectedIds.add(lid);
        else selectedIds.delete(lid);
        updateCount();
      });
    });
  };

  qEl.addEventListener('input', () => {
    search = qEl.value;
    renderRows();
  });
  copiesEl.addEventListener('input', updateCount);

  btnAllVisible.addEventListener('click', () => {
    for (const l of visibleRows) selectedIds.add(String(l.id));
    renderRows();
    updateCount();
  });
  btnClearSel.addEventListener('click', () => {
    selectedIds.clear();
    renderRows();
    updateCount();
  });

  btnCancel.addEventListener('click', close);
  overlay.addEventListener('click', ev => {
    if (ev.target === overlay) close();
  });

  btnPrint.addEventListener('click', async () => {
    if (!selectedIds.size) return;
    const picked = candidates.filter(l => selectedIds.has(String(l.id)));
    if (!picked.length) return;
    const codeType = codeTypeEl.value === 'barcode' ? 'barcode' : 'qr';
    const format = ['tsc', 'a4-large', 'a4-grid', 'a4-105x74', 'wide-200x99'].includes(
      formatEl.value,
    )
      ? formatEl.value
      : 'wide-200x99';
    const copies = Math.max(1, Math.floor(Number(copiesEl.value) || 1));
    await printShelfLabelsToBrowserWindow(picked, {
      codeType,
      format,
      copies,
      locById: new Map(locs.map(l => [String(l.id), l])),
    });
    close();
  });

  renderRows();
  updateCount();
}

/**
 * Generiše HTML stranu za jednu TP nalepnicu (80×40mm portrait — stvarna
 * dimenzija stoka konfigurisana u TSC ML340P preko admin-a 192.168.70.20).
 *
 * Layout (po specifikaciji operatera):
 *   - Red 1: Broj Predmeta (levo, naglašen) | Komitent (desno)
 *   - Red 2: Naziv predmeta (full width)
 *   - Red 3: Naziv dela (full width)
 *   - Red 4: Br. crteža (levo) | Materijal (desno)
 *   - Red 5: Komada (levo) | Datum (desno)
 *   - Barkod ispod (full width, ~20mm visine)
 *
 * @param {{ fields: object, barcodeValue: string }} spec
 * @param {number} index 0-based redni broj nalepnice u batch-u (za jedinstveni `id` SVG-a)
 * @returns {string}
 */
export function buildTechLabelHtmlBlock(spec, index = 0) {
  const f = spec?.fields || {};
  const cell = (label, value, opts = {}) => {
    const v = value == null || value === '' ? '' : String(value);
    if (!v) return '';
    if (opts.bare) return `<span class="lbl-v">${escHtml(v)}</span>`;
    return `<span class="lbl-k">${escHtml(label)}:</span> <span class="lbl-v">${escHtml(v)}</span>`;
  };
  /* TIP operacije (opciono) — S/O/Z → SKLOP/OBRADA/ZAVARIVANJE; ostalo skipuj. */
  const tipMap = { S: 'SKLOP', O: 'OBRADA', Z: 'ZAVARIVANJE' };
  const tipLabel = tipMap[String(f.tipOperacije || '').trim().toUpperCase()] || '';
  const tipHtml = tipLabel ? `<div class="lbl-tip">${escHtml(tipLabel)}</div>` : '';
  return `<div class="label" data-bc-idx="${index}">
    <div class="lbl-meta">
      <div class="lbl-row lbl-row-split">
        <span class="lbl-cell lbl-rn">${escHtml(f.brojPredmeta || '')}</span>
        <span class="lbl-cell lbl-cell-right">${escHtml(f.komitent || '')}</span>
      </div>
      <div class="lbl-row lbl-row-full">${escHtml(f.nazivPredmeta || '')}</div>
      <div class="lbl-row lbl-row-full">${escHtml(f.nazivDela || '')}</div>
      <div class="lbl-row lbl-row-split">
        <span class="lbl-cell">${cell('Crtež', f.brojCrteza)}</span>
        <span class="lbl-cell lbl-cell-right">${cell('', f.materijal, { bare: true })}</span>
      </div>
      <div class="lbl-row lbl-row-split">
        <span class="lbl-cell">${cell('Komada', f.kolicina)}</span>
        <span class="lbl-cell lbl-cell-right">${cell('', f.datum, { bare: true })}</span>
      </div>
    </div>
    <div class="lbl-bc"><svg id="bc_${index}"></svg></div>
    ${tipHtml}
  </div>`;
}

/**
 * CSS za TP nalepnice — stvarna dimenzija stock-a u TSC ML340P pogonu:
 * **80mm × 40mm** (po web admin-u: Paper Width 80.34, Paper Height 40.30).
 *
 * Kritično: `@page { margin: 0 }` + `body { margin: 0 }` + prazan
 * `<title>` značajno smanjuje šansu da Chrome ubaci browser headers
 * (datum/URL/page-number) na sam label. Operater takođe MORA jednom u
 * print dijalogu isključiti „Headers and footers" za TSC profil.
 */
const TECH_LABEL_CSS = `
  /* @page = fizicka veličina nalepnice (80mm × 38mm; 38 a ne 40.30 da Chrome
   * line-height varijacije ne izazovu page-break, vidi commit ac68565). */
  @page { size: 80mm 38mm; margin: 0; }
  * { box-sizing: border-box; }
  html, body { margin:0; padding:0; font-family: 'Arial', 'Liberation Sans', sans-serif; color:#000; background:#fff; }
  /* CSS varijabla --print-scale = ono sto bi operater inace morao da
   * kuca u Chrome print dijalog ▸ Custom scale. Promeni ovde ako treba
   * fino podesavanje (npr. 0.93 ako je previse pomeren u levo, 0.97
   * ako jos uvek udara o desnu ivicu). */
  :root { --print-scale: 0.95; }
  .toolbar {
    position: sticky; top: 0; z-index: 10;
    padding: 8px 12px; background:#eef; font-size:12px; border-bottom:1px solid #99c;
  }
  .toolbar button { margin-left:8px; padding:4px 10px; cursor:pointer; }
  .toolbar .hint { color:#444; margin-left:12px; }
  /* Total budget na 38mm: 0.4mm pad + 14mm text zone + 0.3mm gap + 17mm barkod + 0.4mm pad = 32.1mm
   * Padding gore/dole = 0.4mm = 0.0157" — ispod operaterskog limita 0.03" (0.762mm).
   * Padding levo = 7mm (2mm baseline + 5mm operaterski shift udesno — fizicki
   * ofset nalepnice u TL340P-u; ne diramo driver). Desno ostaje 2mm quiet zone.
   * Korisna sirina barkoda: 80 - 7 - 2 = 71mm (sa 76mm pre shift-a; CODE128
   * i dalje cita pouzdano). */
  .label {
    width: 80mm; height: 38mm; max-height: 38mm;
    padding: 0.4mm 2mm 0.4mm 7mm; /* gore/dole 0.4mm; levo 7mm (5mm shift), desno 2mm */
    display: flex; flex-direction: column;
    gap: 0.2mm;
    page-break-after: always;
    break-after: page;
    overflow: hidden;
    /* Programski Chrome "Custom scale 95%" — operater javio da rucni
     * 95% scale resi problem da se sadrzaj lepi za desnu fizicku ivicu.
     * Sa zoom u CSS-u to je auto: nema potrebe da se rucno podesava
     * pri svakom print-u. Promeni --print-scale gore ako treba drugi %. */
    zoom: var(--print-scale);
  }
  .label:last-child { page-break-after: auto; break-after: auto; }
  .lbl-meta { display: flex; flex-direction: column; gap: 0; flex: 0 0 auto; max-height: 14mm; overflow: hidden; }
  .lbl-row {
    font-size: 6.5pt; line-height: 1;
    display: flex; gap: 3mm;
    overflow: hidden;
    height: 2.6mm;
  }
  .lbl-row-full { display: block; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .lbl-row-split { display: flex; justify-content: space-between; align-items: baseline; }
  .lbl-cell { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; min-width: 0; flex: 1 1 50%; }
  .lbl-cell-right { text-align: right; }
  .lbl-rn { font-size: 10pt; font-weight: 700; line-height: 1; flex: 1 1 auto; }
  .lbl-row-split:first-child { height: 3.6mm; align-items: center; }
  .lbl-k { font-weight: 700; }
  .lbl-v { font-weight: 500; }
  .lbl-bc {
    flex: 0 0 17mm; max-height: 17mm;
    display: flex; align-items: center; justify-content: center;
    margin-top: 0.3mm;
    padding: 0; /* quiet zone vec dolazi iz .label padding (2mm) — ne dupliraj */
    overflow: hidden;
  }
  .lbl-bc svg { width: 100%; height: 100%; max-height: 17mm; display: block; }
  /* TIP (opciono) — krupan centrirani natpis ispod barkoda; renderuje se
   * samo ako je operater izabrao S/O/Z. Bez TIP-a element ne postoji u DOM-u
   * pa layout ostaje identican prethodnom. */
  .lbl-tip {
    flex: 0 0 auto;
    text-align: center;
    font-size: 10pt;
    font-weight: 800;
    line-height: 1;
    margin-top: 0.4mm;
    letter-spacing: 0.5px;
  }
  @media print {
    .toolbar { display: none !important; }
    body { margin:0; padding:0; }
    .label { border: 0; }
  }
`;

/**
 * Štampa jednu ili više TP nalepnica u jednom prozoru (svaka na svoj papir).
 * Layout: tekst gore (RN, komitent, predmet, deo, crtež, količina, materijal,
 * datum), CODE128 barkod dole — full-width minus 2mm quiet zone svake strane.
 *
 * Polja (`fields`):
 *   - brojPredmeta   → wo.ident_broj (npr. „7351/1088")
 *   - komitent       → bigtehn_customers_cache.name
 *   - nazivPredmeta  → bigtehn_items_cache.naziv_predmeta
 *   - nazivDela      → wo.naziv_dela
 *   - brojCrteza     → wo.broj_crteza
 *   - kolicina       → tekst komada na nalepnici (npr. „12/12" = prikaz / ukupno po RN-u), NIJE broj otisaka
 *   - materijal      → wo.materijal
 *   - datum          → DD-MM-YY (lokalno)
 * `barcodeValue` — RNZ string iz `formatBigTehnRnzBarcode(...)`.
 *
 * @param {Array<{
 *   fields: {
 *     brojPredmeta?: string, komitent?: string, nazivPredmeta?: string,
 *     nazivDela?: string, brojCrteza?: string, kolicina?: string,
 *     materijal?: string, datum?: string,
 *   },
 *   barcodeValue: string,
 *   copies?: number,
 * }>} specs
 */
export async function printTechProcessLabelsBatch(specs) {
  if (!Array.isArray(specs) || !specs.length) {
    showToast('⚠ Nema nalepnica za štampu');
    return;
  }

  /* Razvi `copies` u flat listu: ako spec ima copies=3, ide 3x u listu. */
  const flat = [];
  for (const s of specs) {
    const n = Math.max(1, Math.floor(Number(s?.copies) || 1));
    for (let i = 0; i < n; i++) flat.push(s);
  }

  const mod = await import('jsbarcode');
  const JsBarcode = mod.default || mod;
  const w = window.open('', '_blank');
  if (!w) {
    showToast('⚠ Dozvoli pop-up');
    return;
  }

  const labelsHtml = flat.map((s, i) => buildTechLabelHtmlBlock(s, i)).join('');
  const totalCount = flat.length;
  const firstRn = String(flat[0]?.fields?.brojPredmeta || '');

  /* Prazan <title> da Chrome ne odštampa „Nalepnica TP — 7351/1088" u
   * gornjem-levom uglu papira (deo „datum i naslov na sredini papira"
   * problema o kome operater govori). */
  w.document.write(`<!DOCTYPE html><html lang="sr-Latn"><head><meta charset="UTF-8"><title> </title>
  <style>${TECH_LABEL_CSS}</style></head><body>
  <div class="toolbar">
    <strong>${totalCount}</strong> nalepnic${totalCount === 1 ? 'a' : totalCount < 5 ? 'e' : 'a'}${firstRn ? ` (prva: <strong>${escHtml(firstRn)}</strong>)` : ''}.
    <button onclick="window.print()">Štampaj</button>
    <button onclick="window.close()">Zatvori</button>
    <span class="hint">U Chrome dijalogu ▸ <em>More settings</em> ▸ isključi <em>Headers and footers</em> i postavi marginu na <em>None</em> (samo prvi put po štampaču).</span>
  </div>
  ${labelsHtml}
  </body></html>`);
  w.document.close();

  const run = () => {
    flat.forEach((s, i) => {
      const svg = w.document.getElementById(`bc_${i}`);
      if (!svg || !s.barcodeValue) return;
      try {
        JsBarcode(svg, String(s.barcodeValue).trim(), {
          format: 'CODE128',
          displayValue: false,
          margin: 0,
          height: 80,
          width: 2.2,
          background: '#ffffff',
          lineColor: '#000000',
        });
      } catch (e) {
        console.error('[labels/tp] JsBarcode render failed for', s.barcodeValue, e);
      }
    });
  };
  if (w.document.readyState === 'complete') run();
  else w.addEventListener('load', run, { once: true });

  /* TSPL2 paralelno — ako proxy postoji, šalje raw program direktno
   * štampaču (zaobilazi sve browser print artifacts). Browser print
   * ostaje kao fallback / preview. */
  let tspl2 = '';
  try {
    tspl2 = flat
      .map(s => buildTspLabelProgram({ fields: s.fields, barcodeValue: s.barcodeValue, copies: 1 }))
      .join('');
  } catch (e) {
    console.warn('[labels/tp] TSPL2 build failed:', e);
  }
  void dispatchOptionalNetworkLabelPrint({
    mode: 'tech_process_batch',
    count: totalCount,
    payload: {
      labels: flat.map(s => ({ barcode: s.barcodeValue, fields: s.fields })),
      tspl2,
    },
  });
}

/**
 * Backward-compatible single-label API. Pozivi iz starog koda
 * (`printTechProcessLabelWindow({fields, barcodeValue})`) i dalje rade.
 *
 * @param {{ fields: object, barcodeValue: string }} spec
 */
export async function printTechProcessLabelWindow(spec) {
  return printTechProcessLabelsBatch([spec]);
}

export function barcodeForPlacementRow(p) {
  const tbl = String(p.item_ref_table || '');
  const ord = String(p.order_no || '').trim();
  const iid = String(p.item_ref_id || '').trim();
  const dr = String(p.drawing_no || '').trim();
  if (tbl === 'bigtehn_rn' && ord && iid) {
    return formatBigTehnRnzBarcode({ orderNo: ord, tpNo: iid });
  }
  if (ord && (dr || iid)) {
    return formatBigTehnShortBarcode(ord, dr || iid);
  }
  return null;
}


/**
 * Otvara punu stranicu /stampa-nalepnica (UI prebačen iz modala).
 */
export async function openTechProcessLabelPrintModal() {
  const { navigateToAppPath } = await import('../router.js');
  navigateToAppPath('/stampa-nalepnica');
}
