/**
 * Reversi — tab "Rezni alat" (Sprint RZ-2): katalog šifri sa zbirnim stanjem,
 * akcije za nove šifre i štampu nalepnica preko TSC proxy-a.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { canManageReversi } from '../../state/auth.js';
import {
  fetchCuttingToolCatalog,
  fetchMachines,
} from '../../services/reversiService.js';
import {
  openAddCuttingToolModal,
  openCuttingToolDetailsModal,
  printCuttingToolLabel,
} from './cuttingToolModals.js';

const PAGE = 25;

const state = {
  search: '',
  status: 'active',
  machine: '',
  offset: 0,
  rows: [],
  total: null,
  machines: [],
  selected: new Set(),
  searchDeb: null,
};

let bodyRoot = null;
let onIssueScan = null;
let onReturnScan = null;

function statusPill(s) {
  if (s === 'scrapped') return '<span class="rev-pill rev-pill--muted rev-pill--sm">Otpisana</span>';
  return '<span class="rev-pill rev-pill--green rev-pill--sm">Aktivna</span>';
}

function machineList(arr) {
  if (!Array.isArray(arr) || arr.length === 0) {
    return '<span class="rev-muted">— bez ograničenja —</span>';
  }
  return arr.map((m) => `<span class="rev-mchip">${escHtml(m)}</span>`).join(' ');
}

async function ensureMachines() {
  if (state.machines.length > 0) return;
  const r = await fetchMachines();
  state.machines = r.ok && Array.isArray(r.data) ? r.data : [];
}

async function load() {
  const r = await fetchCuttingToolCatalog({
    search: state.search,
    status: state.status,
    machine: state.machine,
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

function renderToolbar() {
  return `
    <div class="rev-panel rev-toolbar-panel">
      <div class="rev-field rev-field--grow">
        <label class="rev-field-label">Pretraga (oznaka, naziv, klasa, barkod)</label>
        <input type="search" id="revRznSearch" class="rev-input rev-input--search" placeholder="npr. glodalo D12 ili RZN-000123…" value="${escHtml(state.search)}"/>
      </div>
      <div class="rev-field">
        <label class="rev-field-label">Mašina</label>
        <select id="revRznMachine" class="rev-select">
          <option value="" ${state.machine === '' ? 'selected' : ''}>— sve —</option>
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
          <option value="scrapped" ${state.status === 'scrapped' ? 'selected' : ''}>Otpisane</option>
          <option value="all" ${state.status === 'all' ? 'selected' : ''}>Sve</option>
        </select>
      </div>
      <div class="rev-toolbar-actions">
        ${canManageReversi() ? `<button type="button" class="rev-btn rev-btn--primary" id="revRznNew">+ Nova šifra</button>` : ''}
        ${canManageReversi() ? `<button type="button" class="rev-btn rev-btn--secondary" id="revRznPrintSel">🏷 Štampa odabranih</button>` : ''}
        ${canManageReversi() ? `<button type="button" class="rev-btn rev-btn--primary" id="revRznScanIssue">📷 Zaduženje (skener)</button>` : ''}
        <button type="button" class="rev-btn rev-btn--secondary" id="revRznScanReturn">↩ Povraćaj (skener)</button>
      </div>
    </div>`;
}

function renderTable() {
  if (state.rows.length === 0) {
    return `<div class="rev-empty-card"><p>Nema šifri reznog alata koje odgovaraju filteru.</p>${canManageReversi() ? '<p><button type="button" class="rev-btn rev-btn--primary" id="revRznEmptyNew">+ Dodaj prvu šifru</button></p>' : ''}</div>`;
  }
  return `
    <div class="rev-table-shell">
      <table class="rev-data-table">
        <thead><tr>
          ${canManageReversi() ? '<th class="rev-th-cb"><input type="checkbox" id="revRznSelAll"/></th>' : ''}
          <th>Barkod</th>
          <th>Oznaka</th>
          <th>Naziv</th>
          <th>Klasa</th>
          <th>Mašine</th>
          <th class="rev-th-num">U magacinu</th>
          <th class="rev-th-num">Na mašinama</th>
          <th>Status</th>
          <th class="rev-th-actions">Akcije</th>
        </tr></thead>
        <tbody>${state.rows
          .map((t) => {
            const checked = state.selected.has(t.id) ? 'checked' : '';
            return `<tr data-rzn-row="${escHtml(t.id)}">
              ${canManageReversi() ? `<td><input type="checkbox" class="rev-rzn-cb" data-rzn-cb="${escHtml(t.id)}" ${checked}/></td>` : ''}
              <td><span class="rev-mono rev-strong">${escHtml(t.barcode || '')}</span></td>
              <td>${escHtml(t.oznaka || '')}</td>
              <td>${escHtml(t.naziv || '')}</td>
              <td>${escHtml(t.klasa || '—')}</td>
              <td>${machineList(t.compatible_machine_codes)}</td>
              <td class="rev-td-num">${escHtml(String(Number(t.in_warehouse_qty) || 0))} ${escHtml(t.unit || 'kom')}</td>
              <td class="rev-td-num">${Number(t.on_machines_qty) > 0 ? `<strong>${escHtml(String(t.on_machines_qty))}</strong>` : '0'}</td>
              <td>${statusPill(t.status)}</td>
              <td class="rev-td-actions">
                <button type="button" class="rev-act-btn" title="Detalji + stanje po lokacijama" data-rzn-det="${escHtml(t.id)}">👁</button>
                ${canManageReversi() ? `<button type="button" class="rev-act-btn" title="Izmeni" data-rzn-edit="${escHtml(t.id)}">✎</button>` : ''}
                <button type="button" class="rev-act-btn" title="Štampaj nalepnicu" data-rzn-print="${escHtml(t.id)}">🏷</button>
              </td>
            </tr>`;
          })
          .join('')}
        </tbody>
      </table>
    </div>
    <div class="rev-pager">
      <span class="rev-muted">Prikazano ${state.rows.length}${state.total != null ? ` od ${state.total} šifri` : ''}</span>
      ${state.offset + state.rows.length < (state.total ?? Infinity) ? '<button type="button" class="rev-btn rev-btn--secondary" id="revRznMore">Učitaj još</button>' : ''}
    </div>`;
}

function bindEvents(refreshAll) {
  const r = bodyRoot;
  if (!r) return;

  r.querySelector('#revRznSearch')?.addEventListener('input', (e) => {
    clearTimeout(state.searchDeb);
    state.searchDeb = setTimeout(() => {
      state.search = e.target.value;
      state.offset = 0;
      void refreshAll();
    }, 300);
  });
  r.querySelector('#revRznMachine')?.addEventListener('change', (e) => {
    state.machine = e.target.value;
    state.offset = 0;
    void refreshAll();
  });
  r.querySelector('#revRznStatus')?.addEventListener('change', (e) => {
    state.status = e.target.value;
    state.offset = 0;
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
  r.querySelector('#revRznSelAll')?.addEventListener('change', (e) => {
    if (e.target.checked) {
      state.rows.forEach((t) => state.selected.add(t.id));
    } else {
      state.selected.clear();
    }
    r.querySelectorAll('[data-rzn-cb]').forEach((cb) => {
      cb.checked = state.selected.has(cb.getAttribute('data-rzn-cb'));
    });
  });
  r.querySelectorAll('[data-rzn-cb]').forEach((cb) => {
    cb.addEventListener('change', () => {
      const id = cb.getAttribute('data-rzn-cb');
      if (cb.checked) state.selected.add(id);
      else state.selected.delete(id);
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
  r.querySelector('#revRznPrintSel')?.addEventListener('click', async () => {
    if (state.selected.size === 0) {
      showToast('Nema označenih šifri za štampu');
      return;
    }
    const items = state.rows.filter((x) => state.selected.has(x.id));
    const btn = r.querySelector('#revRznPrintSel');
    btn.disabled = true;
    btn.textContent = `Štampam ${items.length}…`;
    let ok = 0;
    let fail = 0;
    for (const t of items) {
      const res = await printCuttingToolLabel(t, 1);
      if (res.ok) ok += 1;
      else fail += 1;
    }
    btn.disabled = false;
    btn.textContent = '🏷 Štampa odabranih';
    showToast(`Štampa: ${ok} uspešno, ${fail} neuspešno`);
  });
  r.querySelector('#revRznMore')?.addEventListener('click', () => {
    state.offset += PAGE;
    void refreshAll();
  });
}

/**
 * @param {HTMLElement} body Mount tačka (#revTabBody iz reversi/index.js)
 * @param {{ onIssueScan?: () => void, onReturnScan?: () => void }} [opts]
 */
export async function renderReznialatTab(body, opts = {}) {
  bodyRoot = body;
  onIssueScan = opts.onIssueScan;
  onReturnScan = opts.onReturnScan;

  body.innerHTML = '<div class="rev-loading-card">Učitavanje reznog alata…</div>';

  await ensureMachines();
  await load();

  const refreshAll = async () => {
    await load();
    body.innerHTML = `
      <div class="rev-print-area">
      <p class="rev-module-hint"><strong>Rezni alat</strong>: jedna šifra → količina po lokaciji. Stanje na mašinama (kolona „Na mašinama“) se gomila iz svih aktivnih reversa za tu šifru.</p>
      ${renderToolbar()}
      <div id="revRznTableHost">${renderTable()}</div>
      </div>`;
    bindEvents(refreshAll);
  };

  await refreshAll();
}

/** Cleanup state when module unmounts. */
export function teardownReznialatTab() {
  bodyRoot = null;
  onIssueScan = null;
  state.rows = [];
  state.total = null;
  state.offset = 0;
  state.selected.clear();
  clearTimeout(state.searchDeb);
}
