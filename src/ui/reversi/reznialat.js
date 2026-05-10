/**
 * Reversi — tab "Rezni alat" (redizajn prema docs/CURSOR_REVERSI_REZNI_ALAT.md).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { canManageReversi } from '../../state/auth.js';
import { ssGet, ssSet } from '../../lib/storage.js';
import { rowsToCsv, CSV_BOM } from '../../lib/csv.js';
import { fetchCuttingToolCatalog, fetchMachines } from '../../services/reversiService.js';
import {
  openAddCuttingToolModal,
  openCuttingToolDetailsModal,
  printCuttingToolLabel,
} from './cuttingToolModals.js';
import { ICON_REZNI_MACHINING } from './revMachiningIcon.js';
import { renderByMachineSubview, renderByEmployeeSubview } from './cuttingByViews.js';

const SUB_TAB_KEY = 'sess:rev_rzn_sub_tab';
const SUB_TABS = [
  { id: 'katalog', label: 'Katalog' },
  { id: 'masine', label: 'Po mašinama' },
  { id: 'zaposleni', label: 'Po zaposlenima' },
];

const PAGE = 25;
const SEARCH_DEB_MS = 250;
const EXPORT_CAP = 12_000;

const KLASE_FILTER = [
  { id: '', label: '— Sve klase —' },
  { id: 'glodalo', label: 'Glodalo' },
  { id: 'burgija', label: 'Burgija' },
  { id: 'pločica', label: 'Pločica' },
  { id: 'držač', label: 'Držač' },
  { id: 'narez', label: 'Narez' },
  { id: 'urezna', label: 'Urezna' },
  { id: 'razvrtač', label: 'Razvrtač' },
  { id: 'ostalo', label: 'Ostalo' },
];

const state = {
  search: '',
  status: 'active',
  machine: '',
  klasa: '',
  offset: 0,
  rows: [],
  total: null,
  machines: [],
  selected: new Set(),
  expanded: new Set(),
  searchDeb: null,
  stats: null,
};

let bodyRoot = null;
let onIssueScan = null;
let onReturnScan = null;

function normKlasaKey(k) {
  return String(k || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

function klasaBadgeClass(klasa) {
  const k = normKlasaKey(klasa);
  if (k.includes('glodalo')) return 'rev-klasa-badge rev-klasa-badge--glodalo';
  if (k.includes('burgij')) return 'rev-klasa-badge rev-klasa-badge--burgija';
  if (k.includes('ploč') || k.includes('ploc')) return 'rev-klasa-badge rev-klasa-badge--plocica';
  if (k.includes('urez')) return 'rev-klasa-badge rev-klasa-badge--urezivac';
  if (k.includes('razvrt')) return 'rev-klasa-badge rev-klasa-badge--razvrtac';
  if (k.includes('narez')) return 'rev-klasa-badge rev-klasa-badge--urezivac';
  if (k.includes('drž') || k.includes('drz')) return 'rev-klasa-badge rev-klasa-badge--glodalo';
  return 'rev-klasa-badge rev-klasa-badge--neutral';
}

function machineBreakdownFromStock(stock) {
  const m = new Map();
  for (const s of stock || []) {
    const loc = Array.isArray(s.loc_locations) ? s.loc_locations[0] : s.loc_locations;
    const code = loc?.location_code || '';
    if (!code.startsWith('ZADU-M-')) continue;
    const mc = code.slice('ZADU-M-'.length);
    const qty = Number(s.on_hand_qty) || 0;
    if (qty <= 0) continue;
    m.set(mc, (m.get(mc) || 0) + qty);
  }
  return Array.from(m.entries())
    .map(([masina, kolicina]) => ({ masina, kolicina }))
    .sort((a, b) => a.masina.localeCompare(b.masina, 'sr'));
}

function machineBreakdownFromRow(t) {
  if (Array.isArray(t.machine_breakdown) && t.machine_breakdown.length > 0) {
    return [...t.machine_breakdown].sort((a, b) =>
      String(a.masina).localeCompare(String(b.masina), 'sr'),
    );
  }
  return machineBreakdownFromStock(t.stock);
}

function statusPill(s) {
  if (s === 'scrapped') {
    return '<span class="rev-status-pill rev-status-pill--neutral"><span class="rev-status-pill__dot"></span>Povučena</span>';
  }
  return '<span class="rev-status-pill rev-status-pill--ok"><span class="rev-status-pill__dot"></span>Aktivna</span>';
}

function ukupnoClass(ukupno, minQ, warehouseQty) {
  const u = Number(ukupno) || 0;
  const m = Number(minQ) || 0;
  const w = Number(warehouseQty) || 0;
  if (u === 0) return 'rev-qty-total rev-qty-total--danger';
  if (m > 0 && w < m) return 'rev-qty-total rev-qty-total--warn';
  return 'rev-qty-total rev-qty-total--ok';
}

function syncPrintBtnLabel() {
  const r = bodyRoot;
  if (!r) return;
  const pb = r.querySelector('#revRznPrintSel');
  if (!pb) return;
  const n = state.selected.size;
  pb.disabled = n === 0;
  const label = n > 0 ? `Štampa odabranih (${n})` : 'Štampa odabranih';
  pb.innerHTML = `<span class="rev-btn-ic" aria-hidden="true">🖨</span>${escHtml(label)}`;
}

async function ensureMachines() {
  if (state.machines.length > 0) return;
  const res = await fetchMachines();
  state.machines = res.ok && Array.isArray(res.data) ? res.data : [];
}

function catalogQueryParams() {
  return {
    search: state.search,
    status: state.status,
    machine: state.machine,
    klasa: state.klasa,
  };
}

async function loadPage() {
  const r = await fetchCuttingToolCatalog({
    ...catalogQueryParams(),
    limit: PAGE,
    offset: state.offset,
  });
  if (!r.ok) {
    showToast(`Greška: ${r.error}`);
    state.rows = [];
    state.total = 0;
    return;
  }
  const batch = r.data?.rows || [];
  state.rows = state.offset === 0 ? batch : state.rows.concat(batch);
  state.total = r.data?.total ?? null;
}

async function loadStats() {
  const r = await fetchCuttingToolCatalog({
    ...catalogQueryParams(),
    limit: EXPORT_CAP,
    offset: 0,
  });
  if (!r.ok) {
    state.stats = null;
    return;
  }
  const rows = r.data?.rows || [];
  const total = r.data?.total ?? rows.length;
  let sumWh = 0;
  let sumMach = 0;
  let low = 0;
  let activeSyms = 0;
  for (const row of rows) {
    if (row.status === 'active') activeSyms += 1;
    const wh = Number(row.in_warehouse_qty) || 0;
    const om = Number(row.on_machines_qty) || 0;
    sumWh += wh;
    sumMach += om;
    const uk = wh + om;
    const minQ = Number(row.min_stock_qty) || 0;
    if (row.status === 'active' && minQ > 0 && wh < minQ) low += 1;
  }
  state.stats = {
    totalSymbols: total,
    activeInSample: activeSyms,
    sampleSize: rows.length,
    truncated: rows.length < total,
    sumWh,
    sumMach,
    low,
  };
}

function renderToolbar() {
  const nSel = state.selected.size;
  const printDisabled = !canManageReversi() || nSel === 0;
  const printLabel = nSel > 0 ? `Štampa odabranih (${nSel})` : 'Štampa odabranih';

  return `
    <div class="rev-rzn-toolbar">
      <div class="rev-rzn-toolbar__row rev-rzn-toolbar__row--filters">
        <div class="rev-field rev-field--grow">
          <label class="rev-field-label rev-field-label--hidden" for="revRznSearch">Pretraga</label>
          <input type="search" id="revRznSearch" class="rev-input rev-input--search" placeholder="Pretraga po oznaci, nazivu, klasi ili barkodu…" value="${escHtml(state.search)}"/>
        </div>
        <div class="rev-field">
          <label class="rev-field-label">Klasa</label>
          <select id="revRznKlasa" class="rev-select">
            ${KLASE_FILTER.map(
              (o) =>
                `<option value="${escHtml(o.id)}" ${state.klasa === o.id ? 'selected' : ''}>${escHtml(o.label)}</option>`,
            ).join('')}
          </select>
        </div>
        <div class="rev-field">
          <label class="rev-field-label">Mašina</label>
          <select id="revRznMachine" class="rev-select">
            <option value="" ${state.machine === '' ? 'selected' : ''}>— Sve mašine —</option>
            ${state.machines
              .map(
                (m) =>
                  `<option value="${escHtml(m.rj_code)}" ${state.machine === m.rj_code ? 'selected' : ''}>${escHtml(m.rj_code)} ${escHtml(m.name || '')}</option>`,
              )
              .join('')}
          </select>
        </div>
        <div class="rev-field">
          <label class="rev-field-label">Status</label>
          <select id="revRznStatus" class="rev-select">
            <option value="active" ${state.status === 'active' ? 'selected' : ''}>Aktivne</option>
            <option value="scrapped" ${state.status === 'scrapped' ? 'selected' : ''}>Povučene</option>
            <option value="all" ${state.status === 'all' ? 'selected' : ''}>Sve</option>
          </select>
        </div>
      </div>
      <div class="rev-rzn-toolbar__row rev-rzn-toolbar__row--actions">
        ${
          canManageReversi()
            ? `<button type="button" class="rev-btn rev-btn--secondary" id="revRznPrintSel" ${printDisabled ? 'disabled' : ''}><span class="rev-btn-ic" aria-hidden="true">🖨</span>${escHtml(printLabel)}</button>`
            : ''
        }
        ${canManageReversi() ? `<button type="button" class="rev-btn rev-btn--primary" id="revRznScanIssue"><span class="rev-btn-ic" aria-hidden="true">📠</span>Zaduženje (skener)</button>` : ''}
        <button type="button" class="rev-btn rev-btn--outline-coral" id="revRznScanReturn"><span class="rev-btn-ic" aria-hidden="true">↩</span>Povraćaj (skener)</button>
        <span class="rev-rzn-toolbar__spacer"></span>
        <button type="button" class="rev-btn rev-btn--excel" id="revRznExcel"><span class="rev-btn-ic" aria-hidden="true">📗</span>Excel</button>
        ${canManageReversi() ? `<button type="button" class="rev-btn rev-btn--primary" id="revRznNew">+ Nova šifra</button>` : ''}
      </div>
    </div>`;
}

function renderStats() {
  const st = state.stats;
  const tot = st?.totalSymbols ?? state.total ?? '—';
  const akt = st?.activeInSample ?? '—';
  const naM = st?.sumMach ?? '—';
  const uM = st?.sumWh ?? '—';
  const low = st?.low ?? '—';
  const katalogHint = st?.truncated
    ? `Procena: prvih ${st.sampleSize} od ${st.totalSymbols} u katalogu`
    : 'U katalogu (prema filteru)';
  const activeHint = st?.truncated
    ? `U učitanom uzorku (${st.sampleSize} šifri)`
    : 'Aktivne šifre u prikazu';

  return `
    <div class="rev-rzn-stats">
      <div class="rev-rzn-stat-card rev-rzn-stat-card--with-icon">
        <div class="rev-rzn-stat-card__icon rev-rzn-stat-card__icon--coral" aria-hidden="true">${ICON_REZNI_MACHINING}</div>
        <div class="rev-rzn-stat-card__body">
          <div class="rev-rzn-stat-card__label">Ukupno šifri</div>
          <div class="rev-rzn-stat-card__value">${escHtml(String(tot))}</div>
          <div class="rev-rzn-stat-card__hint">${escHtml(katalogHint)}</div>
        </div>
      </div>
      <div class="rev-rzn-stat-card rev-rzn-stat-card--with-icon rev-rzn-stat-card--ok">
        <div class="rev-rzn-stat-card__icon rev-rzn-stat-card__icon--ok" aria-hidden="true">✓</div>
        <div class="rev-rzn-stat-card__body">
          <div class="rev-rzn-stat-card__label">Aktivne</div>
          <div class="rev-rzn-stat-card__value">${escHtml(String(akt))}</div>
          <div class="rev-rzn-stat-card__hint">${escHtml(activeHint)}</div>
        </div>
      </div>
      <div class="rev-rzn-stat-card rev-rzn-stat-card--with-icon">
        <div class="rev-rzn-stat-card__icon rev-rzn-stat-card__icon--coral" aria-hidden="true">⚙</div>
        <div class="rev-rzn-stat-card__body">
          <div class="rev-rzn-stat-card__label">Na mašinama</div>
          <div class="rev-rzn-stat-card__value">${escHtml(String(naM))}</div>
          <div class="rev-rzn-stat-card__hint">Kom na mašinama (uzorak)</div>
        </div>
      </div>
      <div class="rev-rzn-stat-card rev-rzn-stat-card--with-icon">
        <div class="rev-rzn-stat-card__icon rev-rzn-stat-card__icon--coral" aria-hidden="true">🏭</div>
        <div class="rev-rzn-stat-card__body">
          <div class="rev-rzn-stat-card__label">U magacinu</div>
          <div class="rev-rzn-stat-card__value">${escHtml(String(uM))}</div>
          <div class="rev-rzn-stat-card__hint">Kom u skladištu</div>
        </div>
      </div>
      <div class="rev-rzn-stat-card rev-rzn-stat-card--with-icon rev-rzn-stat-card--alert">
        <div class="rev-rzn-stat-card__icon rev-rzn-stat-card__icon--alert" aria-hidden="true">⚠</div>
        <div class="rev-rzn-stat-card__body">
          <div class="rev-rzn-stat-card__label">Niska zaliha</div>
          <div class="rev-rzn-stat-card__value">${escHtml(String(low))}</div>
          <div class="rev-rzn-stat-card__hint">Ispod minimuma (uzorak)</div>
        </div>
      </div>
    </div>`;
}

function colCount() {
  return canManageReversi() ? 10 : 9;
}

function renderTable() {
  if (state.rows.length === 0) {
    return `<div class="rev-empty-card"><p>Nema šifri koje odgovaraju filteru.</p>${canManageReversi() ? '<p><button type="button" class="rev-btn rev-btn--primary" id="revRznEmptyNew">+ Dodaj prvu šifru</button></p>' : ''}</div>`;
  }

  const spans = colCount();
  const rowsHtml = state.rows
    .map((t) => {
      const checked = state.selected.has(t.id) ? 'checked' : '';
      const exp = state.expanded.has(t.id);
      const br = machineBreakdownFromRow(t);
      const locCount = br.length;
      const uk = (Number(t.in_warehouse_qty) || 0) + (Number(t.on_machines_qty) || 0);
      const wh = Number(t.in_warehouse_qty) || 0;
      const minQ = Number(t.min_stock_qty) || 0;
      const uClass = ukupnoClass(uk, minQ, wh);
      const kl = escHtml(t.klasa || '—');
      const klBadge = `<span class="${klasaBadgeClass(t.klasa)}">${kl}</span>`;

      const omCell =
        Number(t.on_machines_qty) > 0
          ? `<button type="button" class="rev-rzn-mach-hit rev-rzn-mach-hit--active" data-rzn-toggle-m="${escHtml(t.id)}">
              <span class="rev-rzn-mach-qty">&gt; <span class="rev-td-num__main">${escHtml(String(t.on_machines_qty))}</span> <span class="rev-rzn-mach-locs">(${escHtml(String(locCount))})</span></span>
              <span class="rev-rzn-chevron${exp ? ' is-open' : ''}" aria-hidden="true">›</span>
            </button>`
          : `<span class="rev-muted">0</span>`;

      const expandRow = exp
        ? `<tr class="rev-rzn-expand-row" data-rzn-exp-parent="${escHtml(t.id)}">
            <td colspan="${spans}" class="rev-rzn-expand-cell">
              <div class="rev-rzn-expand-inner">
                <span class="rev-muted rev-rzn-expand-label">Raspored po mašinama:</span>
                ${
                  br.length === 0
                    ? '<span class="rev-muted">—</span>'
                    : br
                        .map(
                          (b) =>
                            `<span class="rev-rzn-mach-pill"><span class="rev-mono">${escHtml(b.masina)}</span> ${escHtml(String(b.kolicina))} kom</span>`,
                        )
                        .join('')
                }
              </div>
            </td>
          </tr>`
        : '';

      const rowSel = state.selected.has(t.id) ? ' rev-data-row--selected' : '';

      return `<tr class="rev-data-row rev-rzn-data-row${rowSel}" data-rzn-row="${escHtml(t.id)}">
          ${canManageReversi() ? `<td class="rev-th-cb"><input type="checkbox" class="rev-rzn-cb" data-rzn-cb="${escHtml(t.id)}" ${checked}/></td>` : ''}
          <td>
            <div class="rev-rzn-idstack">
              <span class="rev-mono rev-strong">${escHtml(t.oznaka || '')}</span>
              <span class="rev-mono rev-rzn-barcode">${escHtml(t.barcode || '')}</span>
            </div>
          </td>
          <td>${escHtml(t.naziv || '')}</td>
          <td>${klBadge}</td>
          <td class="rev-td-num">${escHtml(String(minQ))}</td>
          <td class="rev-td-num">${escHtml(String(Number(t.in_warehouse_qty) || 0))} <span class="rev-unit-muted">${escHtml(t.unit || 'kom')}</span></td>
          <td class="rev-td-num rev-td-num--mach">${omCell}</td>
          <td class="rev-td-num">
            <div class="${uClass}">${escHtml(String(uk))} <span class="rev-unit-muted">${escHtml(t.unit || 'kom')}</span></div>
          </td>
          <td>${statusPill(t.status)}</td>
          <td class="rev-td-actions">
            <button type="button" class="rev-act-btn" title="Štampaj nalepnicu" data-rzn-print="${escHtml(t.id)}">🏷</button>
            <button type="button" class="rev-act-btn" title="Pregled" data-rzn-det="${escHtml(t.id)}">👁</button>
            ${canManageReversi() ? `<button type="button" class="rev-act-btn" title="Izmena" data-rzn-edit="${escHtml(t.id)}">✎</button>` : ''}
          </td>
        </tr>${expandRow}`;
    })
    .join('');

  return `
    <div class="rev-table-shell rev-table-shell--rzn">
      <table class="rev-data-table rev-data-table--rzn rev-data-table--zebra">
        <thead><tr>
          ${canManageReversi() ? '<th class="rev-th-cb"><input type="checkbox" id="revRznSelAll"/></th>' : ''}
          <th>Oznaka</th>
          <th>Naziv</th>
          <th>Klasa</th>
          <th class="rev-th-num">Min.</th>
          <th class="rev-th-num">U magacinu</th>
          <th class="rev-th-num rev-th-num--mach-h">Na mašinama</th>
          <th class="rev-th-num">Ukupno</th>
          <th>Status</th>
          <th class="rev-th-actions">Akcije</th>
        </tr></thead>
        <tbody>${rowsHtml}</tbody>
      </table>
    </div>
    <div class="rev-pager rev-rzn-pager">
      <span><strong class="rev-rzn-pager-count">${escHtml(String(state.rows.length))}</strong> <span class="rev-rzn-pager-label">šifri prikazano</span>${state.total != null ? ` <span class="rev-muted">· ukupno ${escHtml(String(state.total))}</span>` : ''} <span class="rev-muted">· sortirano po Oznaci</span></span>
      ${state.offset + state.rows.length < (state.total ?? Infinity) ? '<button type="button" class="rev-btn rev-btn--secondary" id="revRznMore">Učitaj još</button>' : ''}
    </div>`;
}

function downloadCsv(filename, csvBody) {
  const blob = new Blob([CSV_BOM + csvBody], { type: 'text/csv;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
  URL.revokeObjectURL(a.href);
}

async function exportExcel() {
  const r = await fetchCuttingToolCatalog({
    ...catalogQueryParams(),
    limit: EXPORT_CAP,
    offset: 0,
  });
  if (!r.ok) {
    showToast(`Greška: ${r.error}`);
    return;
  }
  const rows = r.data?.rows || [];
  if (rows.length === 0) {
    showToast('Nema podataka za izvoz');
    return;
  }
  const headers = [
    'Oznaka',
    'Barkod',
    'Naziv',
    'Klasa',
    'Min. zaliha',
    'U magacinu',
    'Na mašinama',
    'Ukupno',
    'JM',
    'Status',
    'Mašine (ZADU)',
  ];
  const data = rows.map((t) => {
    const br = machineBreakdownFromRow(t);
    const uk = (Number(t.in_warehouse_qty) || 0) + (Number(t.on_machines_qty) || 0);
    const machStr = br.map((b) => `${b.masina}:${b.kolicina}`).join('; ');
    return [
      t.oznaka || '',
      t.barcode || '',
      t.naziv || '',
      t.klasa || '',
      String(Number(t.min_stock_qty) || 0),
      String(Number(t.in_warehouse_qty) || 0),
      String(Number(t.on_machines_qty) || 0),
      String(uk),
      t.unit || 'kom',
      t.status === 'scrapped' ? 'povučena' : 'aktivna',
      machStr,
    ];
  });
  downloadCsv(`rezni-alat-${new Date().toISOString().slice(0, 10)}.csv`, rowsToCsv(headers, data));
  showToast(`Eksportovano ${rows.length} redova`);
}

function wireToolbarAndFilters(refreshAll) {
  const r = bodyRoot;
  if (!r) return;

  r.querySelector('#revRznSearch')?.addEventListener('input', (e) => {
    clearTimeout(state.searchDeb);
    state.searchDeb = setTimeout(() => {
      state.search = e.target.value;
      state.offset = 0;
      state.expanded.clear();
      void refreshAll();
    }, SEARCH_DEB_MS);
  });
  r.querySelector('#revRznKlasa')?.addEventListener('change', (e) => {
    state.klasa = e.target.value;
    state.offset = 0;
    state.expanded.clear();
    void refreshAll();
  });
  r.querySelector('#revRznMachine')?.addEventListener('change', (e) => {
    state.machine = e.target.value;
    state.offset = 0;
    state.expanded.clear();
    void refreshAll();
  });
  r.querySelector('#revRznStatus')?.addEventListener('change', (e) => {
    state.status = e.target.value;
    state.offset = 0;
    state.expanded.clear();
    void refreshAll();
  });

  r.querySelector('#revRznNew')?.addEventListener('click', () => {
    openAddCuttingToolModal({ onSuccess: () => { state.offset = 0; void refreshAll(); } });
  });
  r.querySelector('#revRznEmptyNew')?.addEventListener('click', () => {
    openAddCuttingToolModal({ onSuccess: () => { state.offset = 0; void refreshAll(); } });
  });
  r.querySelector('#revRznScanIssue')?.addEventListener('click', () => {
    if (typeof onIssueScan === 'function') onIssueScan();
  });
  r.querySelector('#revRznScanReturn')?.addEventListener('click', () => {
    if (typeof onReturnScan === 'function') onReturnScan();
  });
  r.querySelector('#revRznExcel')?.addEventListener('click', () => {
    void exportExcel();
  });

  r.querySelector('#revRznPrintSel')?.addEventListener('click', async () => {
    if (state.selected.size === 0) {
      showToast('Nema označenih šifri');
      return;
    }
    const items = state.rows.filter((x) => state.selected.has(x.id));
    const btn = r.querySelector('#revRznPrintSel');
    btn.disabled = true;
    const prev = btn.textContent;
    btn.textContent = `Štampam ${items.length}…`;
    let ok = 0;
    let fail = 0;
    for (const t of items) {
      const res = await printCuttingToolLabel(t, 1);
      if (res.ok) ok += 1;
      else fail += 1;
    }
    btn.disabled = false;
    btn.textContent = prev;
    syncPrintBtnLabel();
    showToast(`Štampa: ${ok} uspešno, ${fail} neuspešno`);
  });
}

function wireTable(refreshAll) {
  const r = bodyRoot;
  if (!r) return;

  r.querySelector('#revRznSelAll')?.addEventListener('change', (e) => {
    if (e.target.checked) state.rows.forEach((t) => state.selected.add(t.id));
    else state.selected.clear();
    r.querySelectorAll('[data-rzn-cb]').forEach((cb) => {
      cb.checked = state.selected.has(cb.getAttribute('data-rzn-cb'));
    });
    r.querySelectorAll('.rev-rzn-data-row').forEach((row) => {
      const id = row.getAttribute('data-rzn-row');
      row.classList.toggle('rev-data-row--selected', !!(id && state.selected.has(id)));
    });
    syncPrintBtnLabel();
  });

  r.querySelectorAll('[data-rzn-cb]').forEach((cb) => {
    cb.addEventListener('change', () => {
      const id = cb.getAttribute('data-rzn-cb');
      if (cb.checked) state.selected.add(id);
      else state.selected.delete(id);
      const row = r.querySelector(`tr[data-rzn-row="${id}"]`);
      row?.classList.toggle('rev-data-row--selected', cb.checked);
      syncPrintBtnLabel();
    });
  });

  r.querySelectorAll('[data-rzn-toggle-m]').forEach((btn) => {
    btn.addEventListener('click', (ev) => {
      ev.preventDefault();
      const id = btn.getAttribute('data-rzn-toggle-m');
      if (state.expanded.has(id)) state.expanded.delete(id);
      else state.expanded.add(id);
      const host = r.querySelector('#revRznTableHost');
      if (host) {
        host.innerHTML = renderTable();
        wireTable(refreshAll);
      }
    });
  });

  r.querySelectorAll('[data-rzn-det]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-rzn-det');
      const t = state.rows.find((x) => x.id === id);
      if (t) openCuttingToolDetailsModal({ tool: t });
    });
  });
  r.querySelectorAll('[data-rzn-edit]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-rzn-edit');
      const t = state.rows.find((x) => x.id === id);
      if (t) openAddCuttingToolModal({ tool: t, onSuccess: () => { state.offset = 0; void refreshAll(); } });
    });
  });
  r.querySelectorAll('[data-rzn-print]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const id = btn.getAttribute('data-rzn-print');
      const t = state.rows.find((x) => x.id === id);
      if (!t) return;
      btn.disabled = true;
      btn.textContent = '⏳';
      try {
        await printCuttingToolLabel(t, 1);
      } finally {
        btn.disabled = false;
        btn.textContent = '🏷';
      }
    });
  });

  r.querySelector('#revRznMore')?.addEventListener('click', () => {
    state.offset += PAGE;
    void refreshAll();
  });
}

function subTabStripHtml(active) {
  return `<nav class="rev-subtab-strip rev-subtab-strip--coral" role="tablist" aria-label="Rezni alat pod-tabovi">
    ${SUB_TABS.map(
      (t) =>
        `<button type="button" role="tab" class="rev-subtab rev-subtab--sm ${t.id === active ? 'is-active' : ''}" data-rzn-sub="${escHtml(t.id)}">${escHtml(t.label)}</button>`,
    ).join('')}
  </nav>`;
}

async function renderKatalogSubview(body, refreshAll) {
  await ensureMachines();
  await Promise.all([loadPage(), loadStats()]);
  const subHost = body.querySelector('#revRznSubHost');
  if (!subHost) return;
  subHost.innerHTML = `
    <div class="rev-print-area rev-rzn-katalog">
    ${renderStats()}
    ${renderToolbar()}
    <div id="revRznTableHost">${renderTable()}</div>
    </div>`;
  syncPrintBtnLabel();
  wireToolbarAndFilters(refreshAll);
  wireTable(refreshAll);
}

/**
 * @param {HTMLElement} body
 * @param {{ onIssueScan?: () => void, onReturnScan?: () => void }} [opts]
 */
export async function renderReznialatTab(body, opts = {}) {
  bodyRoot = body;
  onIssueScan = opts.onIssueScan;
  onReturnScan = opts.onReturnScan;

  body.innerHTML = '<div class="rev-loading-card">Učitavanje reznog alata…</div>';

  let activeSub = ssGet(SUB_TAB_KEY, 'katalog') || 'katalog';
  if (!SUB_TABS.find((t) => t.id === activeSub)) activeSub = 'katalog';

  const renderShell = () => {
    body.innerHTML = `${subTabStripHtml(activeSub)}<div id="revRznSubHost"></div>`;
    body.querySelectorAll('[data-rzn-sub]').forEach((btn) => {
      btn.addEventListener('click', () => {
        activeSub = btn.getAttribute('data-rzn-sub') || 'katalog';
        ssSet(SUB_TAB_KEY, activeSub);
        renderShell();
        void renderActiveSub();
      });
    });
  };

  const refreshKatalog = async () => {
    if (state.offset === 0) {
      await renderKatalogSubview(body, refreshKatalog);
      return;
    }
    await loadPage();
    await loadStats();
    const subHost = body.querySelector('#revRznSubHost');
    if (!subHost) return;
    const host = subHost.querySelector('#revRznTableHost');
    const statsEl = subHost.querySelector('.rev-rzn-stats');
    const toolbarEl = subHost.querySelector('.rev-rzn-toolbar');
    if (statsEl) statsEl.outerHTML = renderStats();
    if (toolbarEl) toolbarEl.outerHTML = renderToolbar();
    if (host) {
      host.innerHTML = renderTable();
      syncPrintBtnLabel();
      wireToolbarAndFilters(refreshKatalog);
      wireTable(refreshKatalog);
    }
  };

  const renderActiveSub = async () => {
    const subHost = body.querySelector('#revRznSubHost');
    if (!subHost) return;
    subHost.innerHTML = '<div class="rev-loading-card">Učitavanje…</div>';
    state.offset = 0;
    state.rows = [];
    state.expanded.clear();
    if (activeSub === 'masine') {
      await renderByMachineSubview(subHost);
    } else if (activeSub === 'zaposleni') {
      await renderByEmployeeSubview(subHost);
    } else {
      await renderKatalogSubview(body, refreshKatalog);
    }
  };

  renderShell();
  await renderActiveSub();
}

export function teardownReznialatTab() {
  bodyRoot = null;
  onIssueScan = null;
  onReturnScan = null;
  state.rows = [];
  state.total = null;
  state.offset = 0;
  state.selected.clear();
  state.expanded.clear();
  state.stats = null;
  clearTimeout(state.searchDeb);
}
