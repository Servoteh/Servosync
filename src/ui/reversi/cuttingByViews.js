/**
 * Reversi — pregledi reznog alata po mašini i po zaposlenom (Sprint RZ-5).
 * Dva sub-renderera koji se montiraju unutar "Rezni alat" tab-a.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  fetchCuttingByMachine,
  fetchCuttingByEmployee,
  fetchEmployeeDepartments,
} from '../../services/reversiService.js';

function fmtDate(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return String(iso).slice(0, 10);
  return d.toLocaleDateString('sr-Latn-RS', { day: 'numeric', month: 'numeric', year: 'numeric' });
}

/* ============================================================
 *  PO MAŠINAMA
 * ============================================================ */

const machineState = { rows: [], search: '', searchDeb: null };

function groupByMachine(rows) {
  const map = new Map();
  for (const r of rows) {
    const k = r.machine_code || '—';
    if (!map.has(k)) {
      map.set(k, {
        machine_code: k,
        machine_name: r.machine_name || '',
        items: [],
        total_qty: 0,
        last_issued_at: null,
      });
    }
    const grp = map.get(k);
    grp.items.push(r);
    grp.total_qty += Number(r.remaining_qty) || 0;
    if (!grp.last_issued_at || (r.last_issued_at && r.last_issued_at > grp.last_issued_at)) {
      grp.last_issued_at = r.last_issued_at;
    }
  }
  return Array.from(map.values()).sort((a, b) => b.total_qty - a.total_qty);
}

function machineCardHtml(grp) {
  return `<article class="rev-mz-card" data-mch-card="${escHtml(grp.machine_code)}" style="cursor:pointer">
    <header class="rev-mz-card-head">
      <span class="rev-mono rev-strong">${escHtml(grp.machine_code)}</span>
      <span class="rev-mz-mchip">${escHtml(String(grp.items.length))} šifri</span>
    </header>
    <div class="rev-mz-card-body">
      <div class="rev-mz-name">${escHtml(grp.machine_name || 'mašina')}</div>
      <div class="rev-mz-meta">Ukupno na mašini: <strong>${escHtml(String(grp.total_qty))}</strong> kom</div>
    </div>
    <footer class="rev-mz-card-foot">
      <span>Poslednje zaduženje: ${escHtml(fmtDate(grp.last_issued_at))}</span>
    </footer>
  </article>`;
}

function openMachineDetailsModal(grp) {
  const id = `revMchDet_${Date.now()}`;
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay rev-modal-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal rev-modal" style="max-width:820px">
        <div class="kadr-modal-header">
          <h2>Mašina ${escHtml(grp.machine_code)} — ${escHtml(grp.machine_name || '')}</h2>
          <button type="button" class="kadr-modal-close" data-mch-close>×</button>
        </div>
        <div class="kadr-modal-body rev-modal-body">
          <p class="rev-muted">Aktivna zaduženja reznog alata na ovoj mašini. Ukupno: <strong>${escHtml(String(grp.total_qty))}</strong> kom u ${escHtml(String(grp.items.length))} šifri.</p>
          <div class="rev-table-shell">
            <table class="rev-data-table">
              <thead><tr>
                <th>Barkod</th>
                <th>Oznaka / Naziv</th>
                <th>Klasa</th>
                <th class="rev-th-num">Količina</th>
                <th>Operateri</th>
                <th>Datum</th>
                <th class="rev-th-num">Doc</th>
              </tr></thead>
              <tbody>${grp.items
                .map(
                  (it) => `<tr>
                  <td><span class="rev-mono">${escHtml(it.barcode || '')}</span></td>
                  <td><strong>${escHtml(it.oznaka || '')}</strong> <span class="rev-muted">${escHtml(it.naziv || '')}</span></td>
                  <td>${escHtml(it.klasa || '—')}</td>
                  <td class="rev-td-num">${escHtml(String(it.remaining_qty || 0))} ${escHtml(it.unit || 'kom')}</td>
                  <td>${escHtml(it.operator_names || it.last_issued_to_name || '—')}</td>
                  <td>${escHtml(fmtDate(it.last_issued_at))}</td>
                  <td class="rev-td-num">${escHtml(String(it.doc_count || 0))}</td>
                </tr>`,
                )
                .join('')}</tbody>
            </table>
          </div>
        </div>
        <div class="kadr-modal-footer rev-modal-footer">
          <button type="button" class="rev-btn" data-mch-close>Zatvori</button>
        </div>
      </div>
    </div>`;
  const overlay = wrap.firstElementChild;
  document.body.appendChild(overlay);
  overlay.querySelectorAll('[data-mch-close]').forEach((b) => b.addEventListener('click', () => overlay.remove()));
  overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
}

async function loadMachines() {
  const r = await fetchCuttingByMachine({ search: machineState.search });
  if (!r.ok) {
    showToast(`Greška: ${r.error}`);
    machineState.rows = [];
    return;
  }
  machineState.rows = r.data || [];
}

/** @param {HTMLElement} body @param {{ initialSearch?: string }} [opts] */
export async function renderByMachineSubview(body, opts = {}) {
  if (opts.initialSearch) machineState.search = String(opts.initialSearch);
  body.innerHTML = '<div class="rev-loading-card">Učitavanje pregleda po mašinama…</div>';
  await loadMachines();

  const groups = groupByMachine(machineState.rows);
  body.innerHTML = `
    <div class="rev-toolbar-panel rev-panel">
      <div class="rev-field rev-field--grow">
        <label class="rev-field-label">Pretraga (mašina, šifra, barkod)</label>
        <input type="search" id="revByMchSearch" class="rev-input rev-input--search" placeholder="npr. 8.3 ili glodalo…" value="${escHtml(machineState.search)}"/>
      </div>
    </div>
    ${
      groups.length === 0
        ? '<div class="rev-empty-card"><p>Nema aktivnih zaduženja reznog alata ni na jednoj mašini.</p></div>'
        : `<div class="rev-mz-cards">${groups.map(machineCardHtml).join('')}</div>`
    }`;

  body.querySelector('#revByMchSearch')?.addEventListener('input', (e) => {
    clearTimeout(machineState.searchDeb);
    machineState.searchDeb = setTimeout(() => {
      machineState.search = e.target.value;
      void renderByMachineSubview(body);
    }, 300);
  });
  body.querySelectorAll('[data-mch-card]').forEach((card) => {
    card.addEventListener('click', () => {
      const code = card.getAttribute('data-mch-card');
      const grp = groups.find((g) => g.machine_code === code);
      if (grp) openMachineDetailsModal(grp);
    });
  });
}

/* ============================================================
 *  PO ZAPOSLENIMA
 * ============================================================ */

const employeeState = { rows: [], search: '', department: '', departments: [], searchDeb: null };

function groupByEmployee(rows) {
  const map = new Map();
  for (const r of rows) {
    const k = r.employee_id || r.employee_name || '—';
    if (!map.has(k)) {
      map.set(k, {
        employee_id: r.employee_id,
        employee_name: r.employee_name || 'Nepoznat',
        department: r.department || '',
        items: [],
        total_qty: 0,
        machines: new Set(),
        last_issued_at: null,
      });
    }
    const grp = map.get(k);
    grp.items.push(r);
    grp.total_qty += Number(r.remaining_qty) || 0;
    for (const m of r.machine_codes || []) {
      if (m) grp.machines.add(m);
    }
    if (!grp.last_issued_at || (r.last_issued_at && r.last_issued_at > grp.last_issued_at)) {
      grp.last_issued_at = r.last_issued_at;
    }
  }
  return Array.from(map.values())
    .map((g) => ({ ...g, machines: Array.from(g.machines) }))
    .sort((a, b) => b.total_qty - a.total_qty);
}

function employeeCardHtml(grp) {
  return `<article class="rev-mz-card" data-emp-card="${escHtml(grp.employee_id || grp.employee_name)}" style="cursor:pointer">
    <header class="rev-mz-card-head">
      <span class="rev-strong">${escHtml(grp.employee_name)}</span>
      <span class="rev-mz-mchip">${escHtml(String(grp.items.length))} šifri</span>
    </header>
    <div class="rev-mz-card-body">
      ${grp.department ? `<div class="rev-mz-meta">Odeljenje: ${escHtml(grp.department)}</div>` : ''}
      <div class="rev-mz-meta">Ukupno na njemu: <strong>${escHtml(String(grp.total_qty))}</strong> kom</div>
      ${grp.machines.length > 0 ? `<div class="rev-mz-meta">Mašine: ${grp.machines.map((m) => `<span class="rev-mchip">${escHtml(m)}</span>`).join(' ')}</div>` : ''}
    </div>
    <footer class="rev-mz-card-foot">
      <span>Poslednje zaduženje: ${escHtml(fmtDate(grp.last_issued_at))}</span>
    </footer>
  </article>`;
}

function openEmployeeDetailsModal(grp) {
  const id = `revEmpDet_${Date.now()}`;
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay rev-modal-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal rev-modal" style="max-width:820px">
        <div class="kadr-modal-header">
          <h2>Zaposleni: ${escHtml(grp.employee_name)}</h2>
          <button type="button" class="kadr-modal-close" data-emp-close>×</button>
        </div>
        <div class="kadr-modal-body rev-modal-body">
          <p class="rev-muted">${grp.department ? `Odeljenje: <strong>${escHtml(grp.department)}</strong> · ` : ''}Ukupno: <strong>${escHtml(String(grp.total_qty))}</strong> kom u ${escHtml(String(grp.items.length))} šifri</p>
          <div class="rev-table-shell">
            <table class="rev-data-table">
              <thead><tr>
                <th>Barkod</th>
                <th>Oznaka / Naziv</th>
                <th>Klasa</th>
                <th class="rev-th-num">Količina</th>
                <th>Mašine</th>
                <th>Datum</th>
                <th class="rev-th-num">Doc</th>
              </tr></thead>
              <tbody>${grp.items
                .map(
                  (it) => `<tr>
                  <td><span class="rev-mono">${escHtml(it.barcode || '')}</span></td>
                  <td><strong>${escHtml(it.oznaka || '')}</strong> <span class="rev-muted">${escHtml(it.naziv || '')}</span></td>
                  <td>${escHtml(it.klasa || '—')}</td>
                  <td class="rev-td-num">${escHtml(String(it.remaining_qty || 0))} ${escHtml(it.unit || 'kom')}</td>
                  <td>${(it.machine_codes || []).map((m) => `<span class="rev-mchip">${escHtml(m)}</span>`).join(' ') || '—'}</td>
                  <td>${escHtml(fmtDate(it.last_issued_at))}</td>
                  <td class="rev-td-num">${escHtml(String(it.doc_count || 0))}</td>
                </tr>`,
                )
                .join('')}</tbody>
            </table>
          </div>
        </div>
        <div class="kadr-modal-footer rev-modal-footer">
          <button type="button" class="rev-btn" data-emp-close>Zatvori</button>
        </div>
      </div>
    </div>`;
  const overlay = wrap.firstElementChild;
  document.body.appendChild(overlay);
  overlay.querySelectorAll('[data-emp-close]').forEach((b) => b.addEventListener('click', () => overlay.remove()));
  overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
}

async function loadEmployees() {
  const [er, dr] = await Promise.all([
    fetchCuttingByEmployee({ search: employeeState.search, department: employeeState.department }),
    employeeState.departments.length === 0 ? fetchEmployeeDepartments() : Promise.resolve({ ok: true, data: employeeState.departments }),
  ]);
  if (!er.ok) {
    showToast(`Greška: ${er.error}`);
    employeeState.rows = [];
  } else {
    employeeState.rows = er.data || [];
  }
  if (dr.ok && Array.isArray(dr.data)) employeeState.departments = dr.data;
}

/** @param {HTMLElement} body */
export async function renderByEmployeeSubview(body) {
  body.innerHTML = '<div class="rev-loading-card">Učitavanje pregleda po zaposlenima…</div>';
  await loadEmployees();

  const groups = groupByEmployee(employeeState.rows);

  body.innerHTML = `
    <div class="rev-toolbar-panel rev-panel">
      <div class="rev-field rev-field--grow">
        <label class="rev-field-label">Pretraga (ime, šifra, barkod)</label>
        <input type="search" id="revByEmpSearch" class="rev-input rev-input--search" placeholder="npr. Petar ili glodalo…" value="${escHtml(employeeState.search)}"/>
      </div>
      <div class="rev-field">
        <label class="rev-field-label">Odeljenje</label>
        <select id="revByEmpDep" class="rev-select">
          <option value="" ${employeeState.department === '' ? 'selected' : ''}>— sva —</option>
          ${employeeState.departments
            .map((d) => `<option value="${escHtml(d)}" ${employeeState.department === d ? 'selected' : ''}>${escHtml(d)}</option>`)
            .join('')}
        </select>
      </div>
    </div>
    ${
      groups.length === 0
        ? '<div class="rev-empty-card"><p>Nema aktivnih zaduženja reznog alata ni za jednog zaposlenog.</p></div>'
        : `<div class="rev-mz-cards">${groups.map(employeeCardHtml).join('')}</div>`
    }`;

  body.querySelector('#revByEmpSearch')?.addEventListener('input', (e) => {
    clearTimeout(employeeState.searchDeb);
    employeeState.searchDeb = setTimeout(() => {
      employeeState.search = e.target.value;
      void renderByEmployeeSubview(body);
    }, 300);
  });
  body.querySelector('#revByEmpDep')?.addEventListener('change', (e) => {
    employeeState.department = e.target.value;
    void renderByEmployeeSubview(body);
  });
  body.querySelectorAll('[data-emp-card]').forEach((card) => {
    card.addEventListener('click', () => {
      const id = card.getAttribute('data-emp-card');
      const grp = groups.find((g) => (g.employee_id || g.employee_name) === id);
      if (grp) openEmployeeDetailsModal(grp);
    });
  });
}

export function teardownCuttingByViews() {
  machineState.rows = [];
  machineState.search = '';
  clearTimeout(machineState.searchDeb);
  employeeState.rows = [];
  employeeState.search = '';
  employeeState.department = '';
  employeeState.departments = [];
  clearTimeout(employeeState.searchDeb);
}
