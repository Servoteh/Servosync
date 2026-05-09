/**
 * Reversi — tab "Magacin" (RZ-5).
 *
 * Objedinjeni magacinski pregled: rev_tools (HAND, 1 komad = 1 red) +
 * rev_cutting_tool_catalog (CUTTING, qty sumirano po WAREHOUSE lokacijama).
 *
 * Filter po grupi (HAND / CUTTING / SVE), pretraga, klasa.
 * Akcija "Top-up" za CUTTING red (samo rev_can_manage role).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { canManageReversi } from '../../state/auth.js';
import {
  fetchUnifiedWarehouse,
  fetchActiveLocations,
  getMagacinLocationId,
  seedCuttingToolStock,
} from '../../services/reversiService.js';

const state = {
  rows: [],
  grupa: 'ALL',
  search: '',
  klasa: '',
  includeZero: false,
  searchDeb: null,
  locations: [],
  magacinId: null,
};

let bodyRoot = null;

async function load() {
  const r = await fetchUnifiedWarehouse({
    grupa: state.grupa,
    search: state.search,
    klasa: state.klasa,
    includeZero: state.includeZero,
  });
  state.rows = r.ok && Array.isArray(r.data) ? r.data : [];
}

function uniqueKlase(rows) {
  const set = new Set();
  for (const r of rows) {
    if (r.klasa) set.add(r.klasa);
  }
  return Array.from(set).sort();
}

function statusPill(s) {
  if (s === 'scrapped') return '<span class="rev-pill rev-pill--muted rev-pill--sm">Otpisan</span>';
  if (s === 'lost') return '<span class="rev-pill rev-pill--red rev-pill--sm">Izgubljen</span>';
  return '<span class="rev-pill rev-pill--green rev-pill--sm">Aktivan</span>';
}

function grupaPill(g) {
  return g === 'CUTTING'
    ? '<span class="rev-mchip" style="background:rgba(220,120,40,0.15);color:#c46e1f">REZNI</span>'
    : '<span class="rev-mchip" style="background:rgba(60,140,80,0.15);color:#3a8c4a">RUČNI</span>';
}

function renderToolbar() {
  const klase = uniqueKlase(state.rows);
  return `
    <div class="rev-panel rev-toolbar-panel">
      <div class="rev-field rev-field--grow">
        <label class="rev-field-label">Pretraga (oznaka, naziv, barkod)</label>
        <input type="search" id="revMagSearch" class="rev-input rev-input--search"
          placeholder="npr. glodalo D12 ili AL-001…" value="${escHtml(state.search)}"/>
      </div>
      <div class="rev-field">
        <label class="rev-field-label">Grupa</label>
        <div class="rev-seg" role="group">
          ${[
            ['ALL', 'Sve'],
            ['HAND', 'Ručni'],
            ['CUTTING', 'Rezni'],
          ]
            .map(
              ([id, lab]) => `
            <button type="button" class="rev-seg-btn ${state.grupa === id ? 'is-on' : ''}" data-mag-grupa="${id}">${lab}</button>`,
            )
            .join('')}
        </div>
      </div>
      ${
        klase.length > 0
          ? `<div class="rev-field">
        <label class="rev-field-label">Klasa</label>
        <select id="revMagKlasa" class="rev-select">
          <option value="" ${state.klasa === '' ? 'selected' : ''}>— sve —</option>
          ${klase.map((k) => `<option value="${escHtml(k)}" ${state.klasa === k ? 'selected' : ''}>${escHtml(k)}</option>`).join('')}
        </select>
      </div>`
          : ''
      }
      <div class="rev-field">
        <label class="rev-field-label" style="display:flex;align-items:center;gap:6px">
          <input type="checkbox" id="revMagInclZero" ${state.includeZero ? 'checked' : ''}/>
          Prikaži i nulta stanja
        </label>
      </div>
    </div>`;
}

function renderTable() {
  if (state.rows.length === 0) {
    return `<div class="rev-empty-card"><p>Nema artikala u magacinu prema filteru.</p></div>`;
  }

  const totalQty = state.rows.reduce((sum, r) => sum + (Number(r.in_warehouse_qty) || 0), 0);
  const handCount = state.rows.filter((r) => r.grupa === 'HAND' && Number(r.in_warehouse_qty) > 0).length;
  const cuttingTotal = state.rows
    .filter((r) => r.grupa === 'CUTTING')
    .reduce((sum, r) => sum + (Number(r.in_warehouse_qty) || 0), 0);

  return `
    <div class="rev-stat-grid" style="margin-bottom:12px">
      <div class="rev-stat-card rev-stat-card--primary">
        <div class="rev-stat-label">Ukupno artikala</div>
        <div class="rev-stat-value">${state.rows.length}</div>
        <div class="rev-stat-hint">u prikazu (ručni + rezni)</div>
      </div>
      <div class="rev-stat-card">
        <div class="rev-stat-label">Ručni alat (komada)</div>
        <div class="rev-stat-value">${handCount}</div>
        <div class="rev-stat-hint">slobodno u magacinu</div>
      </div>
      <div class="rev-stat-card rev-stat-card--amber">
        <div class="rev-stat-label">Rezni alat (kom)</div>
        <div class="rev-stat-value">${cuttingTotal}</div>
        <div class="rev-stat-hint">ukupno u WAREHOUSE lokacijama</div>
      </div>
    </div>
    <div class="rev-table-shell">
      <table class="rev-data-table">
        <thead><tr>
          <th>Grupa</th>
          <th>Barkod</th>
          <th>Oznaka</th>
          <th>Naziv</th>
          <th>Klasa</th>
          <th class="rev-th-num">Stanje</th>
          <th>Lokacija</th>
          <th>Status</th>
          ${canManageReversi() ? '<th class="rev-th-actions">Akcije</th>' : ''}
        </tr></thead>
        <tbody>${state.rows
          .map((r) => {
            const qty = Number(r.in_warehouse_qty) || 0;
            const canTopup = canManageReversi() && r.grupa === 'CUTTING';
            return `<tr data-mag-row="${escHtml(r.item_id)}">
              <td>${grupaPill(r.grupa)}</td>
              <td><span class="rev-mono">${escHtml(r.barcode || '')}</span></td>
              <td>${escHtml(r.oznaka || '')}</td>
              <td>${escHtml(r.naziv || '')}</td>
              <td>${escHtml(r.klasa || '—')}</td>
              <td class="rev-td-num"><strong>${escHtml(String(qty))}</strong> <span class="rev-muted">${escHtml(r.unit || 'kom')}</span></td>
              <td>${r.location_code ? `<span class="rev-mono rev-muted">${escHtml(r.location_code)}</span>` : '<span class="rev-muted">—</span>'}</td>
              <td>${statusPill(r.status)}</td>
              ${
                canManageReversi()
                  ? `<td class="rev-td-actions">${
                      canTopup
                        ? `<button type="button" class="rev-act-btn" title="Dopuna zalihe" data-mag-topup="${escHtml(r.item_id)}">📦+</button>`
                        : ''
                    }</td>`
                  : ''
              }
            </tr>`;
          })
          .join('')}
        </tbody>
      </table>
    </div>`;
}

function bindEvents(refreshAll) {
  const r = bodyRoot;
  if (!r) return;

  r.querySelector('#revMagSearch')?.addEventListener('input', (e) => {
    clearTimeout(state.searchDeb);
    state.searchDeb = setTimeout(() => {
      state.search = e.target.value;
      void refreshAll();
    }, 300);
  });
  r.querySelectorAll('[data-mag-grupa]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.grupa = btn.getAttribute('data-mag-grupa') || 'ALL';
      void refreshAll();
    });
  });
  r.querySelector('#revMagKlasa')?.addEventListener('change', (e) => {
    state.klasa = e.target.value;
    void refreshAll();
  });
  r.querySelector('#revMagInclZero')?.addEventListener('change', (e) => {
    state.includeZero = e.target.checked;
    void refreshAll();
  });
  r.querySelectorAll('[data-mag-topup]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-mag-topup');
      const row = state.rows.find((x) => x.item_id === id);
      if (row) openTopupDialog(row, refreshAll);
    });
  });
}

async function openTopupDialog(row, onSuccess) {
  if (!state.locations.length) {
    const r = await fetchActiveLocations();
    state.locations = r.ok && Array.isArray(r.data) ? r.data : [];
  }
  if (!state.magacinId) state.magacinId = await getMagacinLocationId();

  const id = `revMagTopup_${Date.now()}`;
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay rev-modal-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal rev-modal" style="max-width:480px">
        <div class="kadr-modal-header">
          <h2>Dopuna zalihe — ${escHtml(row.oznaka)}</h2>
          <button type="button" class="kadr-modal-close" data-mag-close>×</button>
        </div>
        <div class="kadr-modal-body rev-modal-body">
          <div class="rev-form-grid">
            <div><strong>${escHtml(row.naziv)}</strong> <span class="rev-muted">(${escHtml(row.barcode || '')})</span></div>
            <div class="rev-muted">Trenutno u magacinu: ${escHtml(String(Number(row.in_warehouse_qty) || 0))} ${escHtml(row.unit || 'kom')}</div>
            <label>Količina za dopunu
              <input type="number" id="revTopupQty" class="rev-input" min="1" step="1" value="1" autofocus/>
            </label>
            <label>Lokacija
              <select id="revTopupLoc" class="rev-select">
                <option value="">— izaberi —</option>
                ${state.locations
                  .filter((l) => l.location_type === 'WAREHOUSE')
                  .map(
                    (l) =>
                      `<option value="${escHtml(l.id)}" ${state.magacinId === l.id ? 'selected' : ''}>${escHtml(l.location_code)} ${escHtml(l.name || '')}</option>`,
                  )
                  .join('')}
              </select>
            </label>
          </div>
        </div>
        <div class="kadr-modal-footer rev-modal-footer">
          <button type="button" class="rev-btn" data-mag-close>Otkaži</button>
          <button type="button" class="rev-btn rev-btn--primary" id="revTopupSave">Dopuni</button>
        </div>
      </div>
    </div>`;
  const overlay = wrap.firstElementChild;
  document.body.appendChild(overlay);

  overlay.querySelectorAll('[data-mag-close]').forEach((b) => b.addEventListener('click', () => overlay.remove()));
  overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });

  overlay.querySelector('#revTopupSave')?.addEventListener('click', async () => {
    const qty = Math.max(1, Math.floor(Number(overlay.querySelector('#revTopupQty').value) || 0));
    const locId = overlay.querySelector('#revTopupLoc').value;
    if (!locId) {
      showToast('Izaberi lokaciju');
      return;
    }
    const btn = overlay.querySelector('#revTopupSave');
    btn.disabled = true;
    btn.textContent = 'Snimam…';
    const res = await seedCuttingToolStock(row.item_id, locId, qty);
    if (!res.ok) {
      showToast(`Greška: ${res.error}`);
      btn.disabled = false;
      btn.textContent = 'Dopuni';
      return;
    }
    showToast(`✓ +${qty} ${row.unit || 'kom'} u magacinu`);
    overlay.remove();
    onSuccess?.();
  });
}

/** @param {HTMLElement} body */
export async function renderMagacinTab(body) {
  bodyRoot = body;
  body.innerHTML = '<div class="rev-loading-card">Učitavanje magacina…</div>';

  const refreshAll = async () => {
    await load();
    body.innerHTML = `
      <div class="rev-print-area">
        <p class="rev-module-hint"><strong>Magacin</strong>: jedinstven pregled svih artikala u magacinu — ručni alat (jedan komad = jedan red, slobodan u magacinu) i rezni alat (suma po WAREHOUSE lokacijama).</p>
        ${renderToolbar()}
        ${renderTable()}
      </div>`;
    bindEvents(refreshAll);
  };

  await refreshAll();
}

export function teardownMagacinTab() {
  bodyRoot = null;
  state.rows = [];
  state.grupa = 'ALL';
  state.search = '';
  state.klasa = '';
  clearTimeout(state.searchDeb);
}
