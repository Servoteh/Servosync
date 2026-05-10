/**
 * Reversi — Bulk import iz Excel/CSV (RZ-6).
 *
 * Tri tipa importa u jednom modalu (segmented switch):
 *   1) Ručni alat / oprema / odelo → rev_tools (1 red = 1 komad, kategorija)
 *   2) Rezni alat (katalog)        → rev_cutting_tool_catalog + opciono početno stanje
 *   3) Reversi (već izdati)         → rev_documents + rev_document_lines
 *
 * Tok:
 *   - Upload XLSX/CSV (drag-drop ili picker)
 *   - Auto-mapping kolona po alias-ima (case-insensitive, dijakritike skinute)
 *   - Preview tabela sa validacijom
 *   - "Uvezi" → bulk insert preko postojećih servisa
 *
 * Excel template (download dugme po tipu) — header sa primerom.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { loadXlsx } from '../../lib/xlsx.js';
import { CSV_BOM } from '../../lib/csv.js';
import {
  insertTool,
  initialPlacementForTool,
  getMagacinLocationId,
  insertCuttingTool,
  seedCuttingToolStock,
  fetchActiveLocations,
  fetchEmployees,
  fetchMachines,
  fetchCuttingToolByBarcode,
  issueReversal,
  issueCuttingReversal,
} from '../../services/reversiService.js';

/* ─── Definicije kolona po tipu ─────────────────────────────────────── */

const HAND_COLS = [
  { key: 'oznaka', label: 'Oznaka', required: true,
    aliases: ['oznaka', 'sifra', 'šifra', 'kod', 'code'] },
  { key: 'naziv', label: 'Naziv', required: true,
    aliases: ['naziv', 'name', 'opis', 'description'] },
  { key: 'kategorija', label: 'Kategorija',
    aliases: ['kategorija', 'category', 'tip', 'vrsta'] },
  { key: 'serijski_broj', label: 'Serijski broj',
    aliases: ['serijski', 'serijski broj', 'sn', 'serial', 'serial number'] },
  { key: 'datum_kupovine', label: 'Datum kupovine', type: 'date',
    aliases: ['datum', 'datum kupovine', 'datum nabavke', 'purchase date', 'date'] },
  { key: 'napomena', label: 'Napomena',
    aliases: ['napomena', 'opis', 'note', 'notes', 'remark', 'pribor'] },
];

const CUTTING_COLS = [
  { key: 'oznaka', label: 'Oznaka', required: true,
    aliases: ['oznaka', 'sifra', 'šifra', 'kod', 'code'] },
  { key: 'naziv', label: 'Naziv', required: true,
    aliases: ['naziv', 'name', 'opis', 'description'] },
  { key: 'klasa', label: 'Klasa',
    aliases: ['klasa', 'class', 'tip', 'vrsta'] },
  { key: 'jedinica', label: 'Jedinica',
    aliases: ['jedinica', 'jedinica mere', 'jm', 'unit', 'jed mere'] },
  { key: 'kompatibilne_masine', label: 'Kompatibilne mašine',
    aliases: ['masine', 'mašine', 'machines', 'kompatibilne masine', 'kompatibilne mašine'] },
  { key: 'pocetna_kolicina', label: 'Početna količina', type: 'number',
    aliases: ['kolicina', 'količina', 'qty', 'pocetna', 'pocetno stanje', 'početno stanje', 'stanje'] },
  { key: 'napomena', label: 'Napomena',
    aliases: ['napomena', 'note', 'opis dodatni', 'notes'] },
];

const REVERS_COLS = [
  { key: 'tip', label: 'Tip dokumenta', required: true,
    aliases: ['tip', 'type', 'doc_type', 'tip dokumenta'] },
  { key: 'datum', label: 'Datum izdavanja', type: 'date',
    aliases: ['datum', 'date', 'datum izdavanja', 'issued at', 'issued_at'] },
  { key: 'primalac_tip', label: 'Tip primaoca', required: true,
    aliases: ['primalac tip', 'recipient_type', 'tip primaoca'] },
  { key: 'primalac', label: 'Primalac (ime / mašina / firma)', required: true,
    aliases: ['primalac', 'recipient', 'recipient_name', 'ime primaoca'] },
  { key: 'masina', label: 'Mašina (rj_code)',
    aliases: ['masina', 'mašina', 'machine', 'rj_code', 'rj code'] },
  { key: 'alat_oznaka_ili_barkod', label: 'Alat (oznaka ili barkod)', required: true,
    aliases: ['alat', 'oznaka', 'barkod', 'barcode', 'sifra', 'šifra'] },
  { key: 'kolicina', label: 'Količina', type: 'number',
    aliases: ['kolicina', 'količina', 'qty', 'qty_issued'] },
  { key: 'rok_povracaja', label: 'Rok povraćaja', type: 'date',
    aliases: ['rok', 'rok povracaja', 'rok povraćaja', 'expected return', 'return_date'] },
  { key: 'napomena', label: 'Napomena',
    aliases: ['napomena', 'note', 'notes'] },
];

const TYPES = [
  { id: 'hand',    label: 'Ručni alat / oprema',  cols: HAND_COLS },
  { id: 'cutting', label: 'Rezni alat',           cols: CUTTING_COLS },
  { id: 'revers',  label: 'Reversi (izdati)',     cols: REVERS_COLS },
];

/* ─── Helper ─────────────────────────────────────────────────────── */

function normHeader(s) {
  return String(s || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/\s+/g, ' ');
}

function normalizeDate(v) {
  if (!v) return '';
  if (v instanceof Date) {
    if (Number.isNaN(v.getTime())) return '';
    return v.toISOString().slice(0, 10);
  }
  const s = String(v).trim();
  if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
  /* DD.MM.YYYY ili DD/MM/YYYY */
  const m = s.match(/^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})$/);
  if (m) {
    const d = m[1].padStart(2, '0');
    const mo = m[2].padStart(2, '0');
    let y = m[3];
    if (y.length === 2) y = '20' + y;
    return `${y}-${mo}-${d}`;
  }
  return '';
}

function mapRow(raw, cols) {
  const headerMap = new Map();
  const firstKeys = Object.keys(raw[0] || {});
  for (const hk of firstKeys) {
    const n = normHeader(hk);
    const col = cols.find(c =>
      normHeader(c.label) === n ||
      (c.aliases || []).some(a => normHeader(a) === n)
    );
    if (col) headerMap.set(hk, col);
  }
  return raw.map((src) => {
    const r = {};
    for (const [hk, col] of headerMap.entries()) {
      let v = src[hk];
      if (v === undefined || v === null) v = '';
      if (col.type === 'date') v = normalizeDate(v);
      else if (col.type === 'number') {
        const n = Number(String(v).replace(',', '.').replace(/\s/g, ''));
        v = Number.isFinite(n) ? n : 0;
      } else {
        v = String(v).trim();
      }
      r[col.key] = v;
    }
    return r;
  });
}

function modalShell(title, bodyHtml, footerHtml, id) {
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay rev-modal-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal rev-modal" style="max-width:980px">
        <div class="kadr-modal-header">
          <h2>${escHtml(title)}</h2>
          <button type="button" class="kadr-modal-close" data-imp-close>×</button>
        </div>
        <div class="kadr-modal-body rev-modal-body">${bodyHtml}</div>
        <div class="kadr-modal-footer rev-modal-footer">${footerHtml}</div>
      </div>
    </div>`;
  return wrap.firstElementChild;
}

function downloadTemplate(typeDef) {
  const headers = typeDef.cols.map((c) => c.label);
  const example = typeDef.cols.map((c) => {
    if (typeDef.id === 'hand') {
      if (c.key === 'oznaka') return 'AL-001';
      if (c.key === 'naziv') return 'Akumulatorska bušilica';
      if (c.key === 'kategorija') return 'alat';
      if (c.key === 'serijski_broj') return 'SN-12345';
      if (c.key === 'datum_kupovine') return '2024-03-15';
      if (c.key === 'napomena') return 'sa baterijom + punjac';
    } else if (typeDef.id === 'cutting') {
      if (c.key === 'oznaka') return 'GL-D12-HSS';
      if (c.key === 'naziv') return 'Glodalo HSS Ø12';
      if (c.key === 'klasa') return 'glodalo';
      if (c.key === 'jedinica') return 'kom';
      if (c.key === 'kompatibilne_masine') return '8.3, 10.1';
      if (c.key === 'pocetna_kolicina') return '20';
      if (c.key === 'napomena') return '';
    } else if (typeDef.id === 'revers') {
      if (c.key === 'tip') return 'TOOL';
      if (c.key === 'datum') return '2026-05-01';
      if (c.key === 'primalac_tip') return 'EMPLOYEE';
      if (c.key === 'primalac') return 'Petar Petrović';
      if (c.key === 'masina') return '';
      if (c.key === 'alat_oznaka_ili_barkod') return 'AL-001';
      if (c.key === 'kolicina') return '1';
      if (c.key === 'rok_povracaja') return '2026-08-01';
      if (c.key === 'napomena') return 'pribor: punjač';
    }
    return '';
  });
  const csv = headers.map((h) => `"${h}"`).join(',') + '\r\n' + example.map((v) => {
    const s = String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  }).join(',') + '\r\n';
  const blob = new Blob([CSV_BOM + csv], { type: 'text/csv;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `reversi-template-${typeDef.id}.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
}

/* ─── Glavni modal ─────────────────────────────────────────────── */

export function openBulkImportModal(opts = {}) {
  const id = `revBulkImp_${Date.now()}`;
  const state = {
    type: 'hand',
    rows: [],
    importing: false,
    progress: { ok: 0, fail: 0, total: 0 },
  };
  const overlay = modalShell(
    '📥 Bulk import iz Excel/CSV',
    `<div id="revImpBody"></div>`,
    `<div id="revImpFoot"></div>`,
    id,
  );
  document.body.appendChild(overlay);

  overlay.querySelectorAll('[data-imp-close]').forEach((b) =>
    b.addEventListener('click', () => overlay.remove()),
  );
  overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });

  function paint() {
    const typeDef = TYPES.find((t) => t.id === state.type);
    const body = overlay.querySelector('#revImpBody');
    const foot = overlay.querySelector('#revImpFoot');

    body.innerHTML = `
      <div class="rev-form-grid">
        <fieldset class="rev-fieldset">
          <legend>Tip importa</legend>
          <div class="rev-seg" role="group">
            ${TYPES.map((t) => `<button type="button" class="rev-seg-btn ${state.type === t.id ? 'is-on' : ''}" data-imp-type="${t.id}">${escHtml(t.label)}</button>`).join('')}
          </div>
        </fieldset>

        <div class="rev-imp-template">
          <p class="rev-muted">Očekivane kolone (header u prvom redu — dijakritici i veličina slova nisu bitni):</p>
          <ul class="rev-imp-cols">
            ${typeDef.cols.map((c) => `<li><strong>${escHtml(c.label)}</strong>${c.required ? ' <span class="rev-warn">*</span>' : ''} <span class="rev-muted">(${(c.aliases || []).slice(0, 3).join(' / ')})</span></li>`).join('')}
          </ul>
          <button type="button" class="rev-btn rev-btn--secondary" id="revImpDlTpl">📄 Preuzmi template (CSV)</button>
        </div>

        <div class="rev-imp-drop" id="revImpDrop">
          <p>Prevuci Excel/CSV fajl ovde ili klikni za izbor.</p>
          <p class="rev-muted">Podržani formati: .xlsx, .xls, .csv</p>
          <input type="file" id="revImpFile" accept=".xlsx,.xls,.csv" hidden/>
          <button type="button" class="rev-btn" id="revImpBrowse">Izaberi fajl…</button>
        </div>

        ${
          state.rows.length === 0
            ? ''
            : `
          <div class="rev-imp-preview">
            <div class="rev-imp-preview-head">
              <strong>Preview:</strong> ${state.rows.length} redova
              <button type="button" class="rev-btn rev-btn--secondary" id="revImpClear">Očisti</button>
            </div>
            <div class="rev-table-shell" style="max-height:300px;overflow:auto">
              <table class="rev-data-table">
                <thead><tr>${typeDef.cols.map((c) => `<th>${escHtml(c.label)}${c.required ? ' *' : ''}</th>`).join('')}<th>Validno?</th></tr></thead>
                <tbody>${state.rows
                  .slice(0, 200)
                  .map((r, idx) => {
                    const errs = validateRow(r, typeDef);
                    const valid = errs.length === 0;
                    return `<tr class="${valid ? '' : 'is-invalid'}">${typeDef.cols
                      .map((c) => `<td>${escHtml(String(r[c.key] ?? ''))}</td>`)
                      .join('')}<td>${valid ? '✓' : `<span class="rev-warn" title="${escHtml(errs.join(', '))}">⚠ ${errs.length}</span>`}</td></tr>`;
                  })
                  .join('')}
              </tbody></table>
            </div>
            ${state.rows.length > 200 ? `<p class="rev-muted">Prikazano prvih 200 redova; biće uvezeno svih ${state.rows.length}.</p>` : ''}
          </div>`
        }

        ${state.importing ? `<div class="rev-loading-card">Uvozim ${state.progress.ok + state.progress.fail} / ${state.progress.total}…</div>` : ''}
      </div>`;

    const validRowsCount = state.rows.filter((r) => validateRow(r, typeDef).length === 0).length;
    foot.innerHTML = `
      <button type="button" class="rev-btn" data-imp-close>Otkaži</button>
      <button type="button" class="rev-btn rev-btn--primary" id="revImpRun" ${state.rows.length > 0 && validRowsCount > 0 && !state.importing ? '' : 'disabled'}>
        ${state.importing ? 'Uvozim…' : `Uvezi ${validRowsCount} redova`}
      </button>`;

    bindEvents();
  }

  function validateRow(r, typeDef) {
    const errs = [];
    for (const c of typeDef.cols) {
      if (c.required && !r[c.key]) errs.push(`${c.label} obavezno`);
    }
    if (typeDef.id === 'revers') {
      if (r.tip && !['TOOL', 'COOPERATION_GOODS', 'CUTTING_TOOL'].includes(r.tip.toUpperCase())) {
        errs.push(`tip mora biti TOOL/COOPERATION_GOODS/CUTTING_TOOL`);
      }
      if (r.primalac_tip && !['EMPLOYEE', 'DEPARTMENT', 'EXTERNAL_COMPANY', 'MACHINE'].includes(r.primalac_tip.toUpperCase())) {
        errs.push(`primalac_tip mora biti EMPLOYEE/DEPARTMENT/EXTERNAL_COMPANY/MACHINE`);
      }
      if ((r.primalac_tip || '').toUpperCase() === 'MACHINE' && !r.masina) {
        errs.push(`masina obavezno za MACHINE primaoca`);
      }
    }
    if (typeDef.id === 'cutting' && r.pocetna_kolicina && Number(r.pocetna_kolicina) < 0) {
      errs.push('početna količina ne može biti negativna');
    }
    return errs;
  }

  function bindEvents() {
    overlay.querySelectorAll('[data-imp-type]').forEach((b) => {
      b.addEventListener('click', () => {
        state.type = b.getAttribute('data-imp-type');
        state.rows = [];
        paint();
      });
    });
    overlay.querySelector('#revImpDlTpl')?.addEventListener('click', () => {
      const td = TYPES.find((t) => t.id === state.type);
      downloadTemplate(td);
    });
    const fileInput = overlay.querySelector('#revImpFile');
    overlay.querySelector('#revImpBrowse')?.addEventListener('click', () => fileInput?.click());
    overlay.querySelector('#revImpClear')?.addEventListener('click', () => {
      state.rows = [];
      paint();
    });
    fileInput?.addEventListener('change', async () => {
      const f = fileInput.files?.[0];
      if (f) await handleFile(f);
      fileInput.value = '';
    });
    const drop = overlay.querySelector('#revImpDrop');
    if (drop) {
      drop.addEventListener('dragover', (e) => { e.preventDefault(); drop.classList.add('is-dragging'); });
      drop.addEventListener('dragleave', () => drop.classList.remove('is-dragging'));
      drop.addEventListener('drop', async (e) => {
        e.preventDefault();
        drop.classList.remove('is-dragging');
        const f = e.dataTransfer?.files?.[0];
        if (f) await handleFile(f);
      });
    }
    overlay.querySelector('#revImpRun')?.addEventListener('click', runImport);
  }

  async function handleFile(file) {
    try {
      const typeDef = TYPES.find((t) => t.id === state.type);
      let raw = [];
      if (/\.csv$/i.test(file.name)) {
        const text = await file.text();
        raw = parseCsvToObjects(text);
      } else {
        const XLSX = await loadXlsx();
        const buf = await file.arrayBuffer();
        const wb = XLSX.read(buf, { type: 'array', cellDates: true });
        const sheet = wb.Sheets[wb.SheetNames[0]];
        if (!sheet) { showToast('Fajl je prazan'); return; }
        raw = XLSX.utils.sheet_to_json(sheet, { defval: '', raw: false, dateNF: 'yyyy-mm-dd' });
      }
      state.rows = mapRow(raw, typeDef.cols);
      showToast(`✔ Učitano ${state.rows.length} redova`);
      paint();
    } catch (e) {
      console.error('[bulkImport] parse fail', e);
      showToast(`Greška pri čitanju fajla: ${e?.message || e}`);
    }
  }

  async function runImport() {
    const typeDef = TYPES.find((t) => t.id === state.type);
    const valid = state.rows.filter((r) => validateRow(r, typeDef).length === 0);
    if (valid.length === 0) return;
    state.importing = true;
    state.progress = { ok: 0, fail: 0, total: valid.length };
    paint();

    try {
      if (typeDef.id === 'hand') await importHand(valid);
      else if (typeDef.id === 'cutting') await importCutting(valid);
      else if (typeDef.id === 'revers') await importRevers(valid);
    } catch (e) {
      console.error('[bulkImport] run fail', e);
      showToast(`Greška: ${e?.message || e}`);
    }
    state.importing = false;
    showToast(`✓ Uvezeno: ${state.progress.ok}, neuspešno: ${state.progress.fail}`);
    if (state.progress.ok > 0) {
      opts.onSuccess?.();
    }
    if (state.progress.fail === 0) {
      overlay.remove();
    } else {
      paint();
    }
  }

  async function importHand(rows) {
    const magId = await getMagacinLocationId();
    for (const r of rows) {
      const payload = {
        oznaka: r.oznaka,
        naziv: r.naziv,
        kategorija: r.kategorija || null,
        serijski_broj: r.serijski_broj || null,
        datum_kupovine: r.datum_kupovine || null,
        napomena: r.napomena || null,
        status: 'active',
      };
      const ins = await insertTool(payload);
      if (!ins.ok) { state.progress.fail += 1; paint(); continue; }
      if (magId) {
        const pl = await initialPlacementForTool(ins.data.loc_item_ref_id, magId);
        if (!pl.ok) { state.progress.fail += 1; paint(); continue; }
      }
      state.progress.ok += 1;
      paint();
    }
  }

  async function importCutting(rows) {
    const magId = await getMagacinLocationId();
    for (const r of rows) {
      const machines = String(r.kompatibilne_masine || '')
        .split(/[,;]/)
        .map((s) => s.trim())
        .filter(Boolean);
      const payload = {
        oznaka: r.oznaka,
        naziv: r.naziv,
        klasa: r.klasa || null,
        compatible_machine_codes: machines,
        unit: r.jedinica || 'kom',
        napomena: r.napomena || null,
        status: 'active',
      };
      const ins = await insertCuttingTool(payload);
      if (!ins.ok) { state.progress.fail += 1; paint(); continue; }
      const qty = Math.max(0, Math.floor(Number(r.pocetna_kolicina) || 0));
      if (qty > 0 && magId) {
        const seed = await seedCuttingToolStock(ins.data.id, magId, qty);
        if (!seed.ok) { state.progress.fail += 1; paint(); continue; }
      }
      state.progress.ok += 1;
      paint();
    }
  }

  async function importRevers(rows) {
    /* Cache za lookup-ove */
    const empCache = new Map();
    const machineCache = new Map();
    const cuttingCache = new Map();
    /* Grupiši po (datum, primalac, tip) → 1 dokument; svaki red = 1 stavka */
    const byDoc = new Map();
    for (const r of rows) {
      const key = [r.tip || 'TOOL', r.primalac_tip, r.primalac, r.masina, r.datum].join('|');
      if (!byDoc.has(key)) byDoc.set(key, { meta: r, lines: [] });
      byDoc.get(key).lines.push(r);
    }

    for (const grp of byDoc.values()) {
      const m = grp.meta;
      const tip = (m.tip || 'TOOL').toUpperCase();
      const primTip = (m.primalac_tip || 'EMPLOYEE').toUpperCase();

      try {
        if (tip === 'CUTTING_TOOL') {
          /* MACHINE recipient za CUTTING_TOOL */
          if (!m.masina) { state.progress.fail += grp.lines.length; paint(); continue; }
          let empId = null;
          if (m.primalac) {
            const e = await resolveEmployee(m.primalac, empCache);
            empId = e?.id || null;
          }
          if (!empId) { state.progress.fail += grp.lines.length; paint(); continue; }

          const lines = [];
          for (const ln of grp.lines) {
            const cat = await resolveCuttingByOznakaOrBarcode(ln.alat_oznaka_ili_barkod, cuttingCache);
            if (!cat) continue;
            lines.push({ catalog_id: cat.id, quantity: Number(ln.kolicina) || 1 });
          }
          if (lines.length === 0) { state.progress.fail += grp.lines.length; paint(); continue; }

          const res = await issueCuttingReversal({
            recipient_machine_code: m.masina,
            issued_to_employee_id: empId,
            issued_to_employee_name: m.primalac,
            expected_return_date: m.rok_povracaja || null,
            napomena: m.napomena || null,
            lines,
          });
          if (res.ok) state.progress.ok += grp.lines.length;
          else state.progress.fail += grp.lines.length;
        } else {
          /* TOOL ili COOPERATION_GOODS — koristi postojeći issueReversal */
          const payload = {
            doc_type: tip,
            recipient_type: primTip,
            recipient_employee_id: null,
            recipient_employee_name: null,
            recipient_department: null,
            recipient_company_name: null,
            expected_return_date: m.rok_povracaja || null,
            napomena: m.napomena || null,
            lines: [],
          };
          if (primTip === 'EMPLOYEE') {
            const e = await resolveEmployee(m.primalac, empCache);
            if (e) {
              payload.recipient_employee_id = e.id;
              payload.recipient_employee_name = e.full_name;
            } else {
              payload.recipient_employee_name = m.primalac;
            }
          } else if (primTip === 'DEPARTMENT') {
            payload.recipient_department = m.primalac;
          } else if (primTip === 'EXTERNAL_COMPANY') {
            payload.recipient_company_name = m.primalac;
          }
          for (const ln of grp.lines) {
            payload.lines.push({
              line_type: 'TOOL',
              tool_id: null /* tool_id resolve preko oznake bi tražio dodatnu logiku — preskačemo, koristimo PRODUCTION_PART fallback ako nema match-a */,
              part_name: ln.alat_oznaka_ili_barkod,
              drawing_no: '',
              quantity: Number(ln.kolicina) || 1,
              unit: 'kom',
              napomena: ln.napomena || '',
            });
          }
          const res = await issueReversal(payload);
          if (res.ok) state.progress.ok += grp.lines.length;
          else state.progress.fail += grp.lines.length;
        }
      } catch (e) {
        console.error('[bulkImport/revers] grp fail', e);
        state.progress.fail += grp.lines.length;
      }
      paint();
    }
  }

  async function resolveEmployee(name, cache) {
    if (!name) return null;
    if (cache.has(name)) return cache.get(name);
    const r = await fetchEmployees(name);
    const list = r.ok && Array.isArray(r.data) ? r.data : [];
    const exact = list.find((e) => e.full_name?.toLowerCase() === name.toLowerCase()) || list[0] || null;
    cache.set(name, exact);
    return exact;
  }

  async function resolveCuttingByOznakaOrBarcode(value, cache) {
    if (!value) return null;
    if (cache.has(value)) return cache.get(value);
    const byBarcode = await fetchCuttingToolByBarcode(value);
    if (byBarcode.ok && byBarcode.data?.id) {
      cache.set(value, byBarcode.data);
      return byBarcode.data;
    }
    cache.set(value, null);
    return null;
  }

  paint();
}

function parseCsvToObjects(text) {
  const lines = text.replace(/﻿/, '').split(/\r?\n/).filter((l) => l.trim() !== '');
  if (lines.length === 0) return [];
  const splitCsv = (line) => {
    const out = [];
    let cur = '';
    let inQ = false;
    for (let i = 0; i < line.length; i += 1) {
      const ch = line[i];
      if (ch === '"') {
        if (inQ && line[i + 1] === '"') { cur += '"'; i += 1; }
        else inQ = !inQ;
      } else if (ch === ',' && !inQ) {
        out.push(cur); cur = '';
      } else {
        cur += ch;
      }
    }
    out.push(cur);
    return out;
  };
  const headers = splitCsv(lines[0]).map((h) => h.trim());
  return lines.slice(1).map((ln) => {
    const cells = splitCsv(ln);
    const obj = {};
    headers.forEach((h, i) => { obj[h] = cells[i] ?? ''; });
    return obj;
  });
}
