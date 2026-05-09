/**
 * Reversi — tab "Magacin" (redizajn CURSOR_REVERSI / objedinjeni pregled).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { canManageReversi } from '../../state/auth.js';
import { rowsToCsv, CSV_BOM } from '../../lib/csv.js';
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

function minForRow(r) {
  if (r.grupa === 'CUTTING') return Number(r.min_stock_qty) || 0;
  return 1;
}

function stockPresentation(r) {
  const qty = Number(r.in_warehouse_qty) || 0;
  const minQ = minForRow(r);
  let cls = 'rev-mag-qty-ok';
  let pill = 'rev-status-pill--ok';
  let label = 'Na stanju';
  if (qty === 0) {
    cls = 'rev-mag-qty-danger';
    pill = 'rev-status-pill--danger';
    label = 'Nema';
  } else if (minQ > 0 && qty < minQ) {
    cls = 'rev-mag-qty-warn';
    pill = 'rev-status-pill--warn';
    label = 'Nisko stanje';
  }
  return { qty, minQ, cls, pill, label };
}

function statusStockPill(p) {
  const dot = '<span class="rev-status-pill__dot"></span>';
  if (p.pill === 'rev-status-pill--danger') {
    return `<span class="rev-status-pill rev-status-pill--danger">${dot}${escHtml(p.label)}</span>`;
  }
  if (p.pill === 'rev-status-pill--warn') {
    return `<span class="rev-status-pill rev-status-pill--warn">${dot}${escHtml(p.label)}</span>`;
  }
  return `<span class="rev-status-pill rev-status-pill--ok">${dot}${escHtml(p.label)}</span>`;
}

function grupaBadge(g) {
  return g === 'CUTTING'
    ? '<span class="rev-grupa-badge--cut">✂ Rezni</span>'
    : '<span class="rev-grupa-badge--hand">🔧 Ručni</span>';
}

function magacinStatsHtml(rows) {
  const total = rows.length;
  const handUnits = rows.filter((r) => r.grupa === 'HAND' && Number(r.in_warehouse_qty) > 0).length;
  const rezniKom = rows.filter((r) => r.grupa === 'CUTTING').reduce((s, r) => s + (Number(r.in_warehouse_qty) || 0), 0);
  let low = 0;
  for (const r of rows) {
    const p = stockPresentation(r);
    if (p.label === 'Nisko stanje') low += 1;
  }
  return `
    <div class="rev-mag-stat-grid">
      <div class="rev-stat-card rev-stat-card--primary">
        <div class="rev-stat-label">Ukupno u prikazu</div>
        <div class="rev-stat-value">${total}</div>
        <div class="rev-stat-hint">Redova (filter)</div>
      </div>
      <div class="rev-stat-card">
        <div class="rev-stat-label">Ručni (slobodno)</div>
        <div class="rev-stat-value">${handUnits}</div>
        <div class="rev-stat-hint">Jedinica u magacinu</div>
      </div>
      <div class="rev-stat-card rev-stat-card--amber">
        <div class="rev-stat-label">Rezni (kom)</div>
        <div class="rev-stat-value">${rezniKom}</div>
        <div class="rev-stat-hint">Zbir WAREHOUSE</div>
      </div>
      <div class="rev-stat-card rev-mag-stat-card--danger">
        <div class="rev-stat-label">Nisko stanje</div>
        <div class="rev-stat-value">${low}</div>
        <div class="rev-stat-hint">Ispod minimuma</div>
      </div>
    </div>`;
}

function renderPageHeader() {
  return `
    <header class="rev-page-header rev-mag-page-header">
      <div class="rev-page-header__icon" aria-hidden="true">📦</div>
      <div class="rev-page-header__text">
        <h2 class="rev-page-header__title">Magacin</h2>
        <p class="rev-page-header__desc">Ručni i rezni artikli u skladištu — jedan pregled, iste logike statusa po količini.</p>
      </div>
    </header>`;
}

function renderToolbar() {
  const klase = uniqueKlase(state.rows);
  return `
    <div class="rev-rzn-toolbar">
      <div class="rev-rzn-toolbar__row rev-rzn-toolbar__row--filters">
        <div class="rev-field rev-field--grow">
          <label class="rev-field-label">Pretraga</label>
          <input type="search" id="revMagSearch" class="rev-input rev-input--search"
            placeholder="Oznaka, naziv, barkod…" value="${escHtml(state.search)}"/>
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
            <option value="" ${state.klasa === '' ? 'selected' : ''}>Sve</option>
            ${klase.map((k) => `<option value="${escHtml(k)}" ${state.klasa === k ? 'selected' : ''}>${escHtml(k)}</option>`).join('')}
          </select>
        </div>`
            : ''
        }
        <div class="rev-field">
          <label class="rev-field-label" style="display:flex;align-items:center;gap:6px;white-space:nowrap">
            <input type="checkbox" id="revMagInclZero" ${state.includeZero ? 'checked' : ''}/>
            Nulta stanja
          </label>
        </div>
      </div>
      <div class="rev-rzn-toolbar__row rev-rzn-toolbar__row--actions">
        <button type="button" class="rev-btn rev-btn--excel" id="revMagExcel">Excel</button>
        ${canManageReversi() ? `<button type="button" class="rev-btn rev-btn--primary" id="revMagNewHand">+ Novi ručni artikal</button>` : ''}
        <span class="rev-rzn-toolbar__spacer"></span>
        <span class="rev-muted" style="font-size:12px">Novi rezni unos: tab Rezni alat → Nova šifra</span>
      </div>
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

function exportMagacin() {
  if (state.rows.length === 0) {
    showToast('Nema redova');
    return;
  }
  const headers = ['Grupa', 'Kataloški broj', 'Barkod', 'Naziv', 'Klasa', 'Lokacija', 'Količina', 'Min', 'Status', 'Napomena'];
  const data = state.rows.map((r) => {
    const p = stockPresentation(r);
    const kat = r.grupa === 'HAND' ? r.oznaka || '' : r.oznaka || '';
    return [
      r.grupa === 'CUTTING' ? 'Rezni' : 'Ručni',
      kat,
      r.barcode || '',
      r.naziv || '',
      r.klasa || '',
      r.location_code || '',
      String(p.qty),
      String(p.minQ),
      p.label,
      r.napomena || '',
    ];
  });
  downloadCsv(`magacin-reversi-${new Date().toISOString().slice(0, 10)}.csv`, rowsToCsv(headers, data));
  showToast(`Eksport ${state.rows.length} redova`);
}

function renderTable() {
  if (state.rows.length === 0) {
    return `<div class="rev-empty-card"><p>Nema artikala u magacinu prema filteru.</p></div>`;
  }

  return `
    <div class="rev-table-shell rev-table-shell--rzn">
      <table class="rev-data-table rev-data-table--zebra">
        <thead><tr>
          <th>Kataloški broj</th>
          <th>Naziv</th>
          <th>Grupa</th>
          <th>Lokacija</th>
          <th class="rev-th-num">Količina</th>
          <th>Status</th>
          <th>Ažurirano</th>
          ${canManageReversi() ? '<th class="rev-th-actions">Akcije</th>' : ''}
        </tr></thead>
        <tbody>${state.rows
          .map((r) => {
            const p = stockPresentation(r);
            const kat = `<div class="rev-rzn-idstack">
              <span class="rev-mono rev-strong">${escHtml(r.oznaka || '—')}</span>
              <span class="rev-mono rev-rzn-barcode">${escHtml(r.barcode || '')}</span>
            </div>`;
            const minLine =
              r.grupa === 'CUTTING' && p.minQ > 0
                ? `<span class="rev-mag-kpi-thumb">min. ${escHtml(String(p.minQ))}</span>`
                : r.grupa === 'HAND'
                  ? '<span class="rev-mag-kpi-thumb">1 kom</span>'
                  : '';
            return `<tr data-mag-row="${escHtml(r.item_id)}">
              <td>${kat}</td>
              <td>${escHtml(r.naziv || '')}</td>
              <td>${grupaBadge(r.grupa)}</td>
              <td>${
                r.location_code
                  ? `<span class="rev-mono rev-muted">${escHtml(r.location_code)}</span>`
                  : '<span class="rev-muted">—</span>'
              }</td>
              <td class="rev-td-num">
                <div class="rev-mag-stock-pill">
                  <span class="${p.cls}">${escHtml(String(p.qty))}</span>
                  <span class="rev-unit-muted">${escHtml(r.unit || 'kom')}</span>
                  ${minLine}
                </div>
              </td>
              <td>${statusStockPill(p)}</td>
              <td><span class="rev-mag-updated">—</span></td>
              ${
                canManageReversi()
                  ? `<td class="rev-td-actions">
                <button type="button" class="rev-act-btn" title="Pregled" data-mag-eye="${escHtml(r.item_id)}">👁</button>
                ${
                  r.grupa === 'CUTTING'
                    ? `<button type="button" class="rev-act-btn" title="Dopuna / izmena zalihe" data-mag-topup="${escHtml(r.item_id)}">✎</button>`
                    : '<button type="button" class="rev-act-btn" title="Ručni alat — izmene u Inventaru" data-mag-hand-hint>✎</button>'
                }
              </td>`
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
    }, 250);
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
  r.querySelector('#revMagExcel')?.addEventListener('click', () => exportMagacin());
  r.querySelector('#revMagNewHand')?.addEventListener('click', () => {
    showToast('Koristi tab „Inventar alata i opreme“ → Nova jedinica');
  });
  r.querySelectorAll('[data-mag-eye]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-mag-eye');
      const row = state.rows.find((x) => x.item_id === id);
      if (row) showToast(`${row.oznaka}: ${row.naziv} · ${Number(row.in_warehouse_qty) || 0} ${row.unit || 'kom'}`);
    });
  });
  r.querySelectorAll('[data-mag-hand-hint]').forEach((btn) => {
    btn.addEventListener('click', () => showToast('Ručni alat menjate u tabu „Inventar alata i opreme“'));
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
    const lr = await fetchActiveLocations();
    state.locations = lr.ok && Array.isArray(lr.data) ? lr.data : [];
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
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) overlay.remove();
  });

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
        ${renderPageHeader()}
        ${magacinStatsHtml(state.rows)}
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
