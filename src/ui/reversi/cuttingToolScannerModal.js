/**
 * Reversi — scanner-driven zaduženje reznog alata (Sprint RZ-3).
 *
 * Flow:
 *   1. Skeniraj barkod alata (RZN-NNNNNN) → fetchCuttingToolByBarcode → dodaj u stavke
 *   2. Skeniraj/izaberi radnika preko card_barcode (fizička ID kartica) ili dropdown
 *   3. Skeniraj/izaberi mašinu preko ZADU-M-<rj_code> ili dropdown (default: poslednja mašina iz prijava_rada)
 *   4. POTVRDI → issueCuttingReversal
 *
 * "Smart input" sluša HID čitač (klavijatura + ENTER) i razlikuje barkode po prefiksu:
 *   RZN-      → alat
 *   ZADU-M-   → mašina (recipient location code)
 *   ostalo    → probaj kao card_barcode → ako ne, ponudi izbor (radnik / mašina)
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { openReversiScanOverlay } from './scanOverlay.js';
import {
  fetchCuttingToolByBarcode,
  fetchEmployeeByCardBarcode,
  fetchEmployeesAny,
  fetchMachines,
  issueCuttingReversal,
  fetchMyIssuedCuttingTools,
  confirmCuttingReturn,
} from '../../services/reversiService.js';

function modalShell(title, bodyHtml, footerHtml, id) {
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay rev-modal-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal rev-modal rev-modal--scanner">
        <div class="kadr-modal-header">
          <h2 id="${id}Title">${escHtml(title)}</h2>
          <button type="button" class="kadr-modal-close" data-rev-close aria-label="Zatvori">×</button>
        </div>
        <div class="kadr-modal-body rev-modal-body">${bodyHtml}</div>
        <div class="kadr-modal-footer rev-modal-footer">${footerHtml}</div>
      </div>
    </div>`;
  return wrap.firstElementChild;
}

function attachClose(root, onClose) {
  root.querySelector('[data-rev-close]')?.addEventListener('click', () => {
    root.remove();
    onClose?.();
  });
  root.addEventListener('click', (e) => {
    if (e.target === root) {
      root.remove();
      onClose?.();
    }
  });
}

/**
 * Modal za skenirano zaduženje reznog alata.
 * @param {{ onSuccess?: (result: object) => void }} [opts]
 */
export function openCuttingToolIssueScannerModal(opts = {}) {
  const id = `revRznScan_${Date.now()}`;
  const state = {
    machine: null, // { rj_code, name }
    employee: null, // { id, full_name }
    lines: [], // [{ catalog_id, oznaka, naziv, klasa, unit, quantity, compatible }]
    machines: [],
    employees: [],
    expectedReturnDate: '',
    napomena: '',
    secondaryIds: [],
    pending: false,
    lastInput: '',
    empPickQuery: '',
    empPickRows: null,
  };

  const overlay = modalShell(
    '🎯 Skenirano zaduženje reznog alata',
    `<div id="revRznScanBody"></div>`,
    `<div id="revRznScanFoot"></div>`,
    id,
  );
  document.body.appendChild(overlay);
  attachClose(overlay, opts.onClose);

  void preloadDropdowns();

  async function preloadDropdowns() {
    const [m, e] = await Promise.all([fetchMachines(), fetchEmployeesAny('')]);
    state.machines = m.ok && Array.isArray(m.data) ? m.data : [];
    state.employees = e.ok && Array.isArray(e.data) ? e.data : [];
    paint();
  }

  function compatibleWarning() {
    if (!state.machine || state.lines.length === 0) return '';
    const incompat = state.lines.filter((ln) => {
      const list = Array.isArray(ln.compatible) ? ln.compatible : [];
      return list.length > 0 && !list.includes(state.machine.rj_code);
    });
    if (incompat.length === 0) return '';
    return `<div class="rev-warn-banner">⚠ Upozorenje: alat <strong>${incompat
      .map((x) => escHtml(x.oznaka))
      .join(', ')}</strong> nije označen kao kompatibilan sa mašinom <strong>${escHtml(state.machine.rj_code)}</strong>. Možeš da nastaviš ako je realna potreba (rezerva / privremeno).</div>`;
  }

  function machineOptionsHtml() {
    return state.machines
      .map(
        (m) =>
          `<option value="${escHtml(m.rj_code)}" ${state.machine?.rj_code === m.rj_code ? 'selected' : ''}>${escHtml(m.rj_code)} ${escHtml(m.name || '')}</option>`,
      )
      .join('');
  }

  function employeeOptionsHtml() {
    return state.employees
      .map(
        (e) =>
          `<option value="${escHtml(e.id)}" ${state.employee?.id === e.id ? 'selected' : ''}>${escHtml(e.full_name)}</option>`,
      )
      .join('');
  }

  function linesHtml() {
    if (state.lines.length === 0) {
      return '<p class="rev-muted">Nema stavki. Skeniraj barkod reznog alata ili otvori manuelni unos.</p>';
    }
    return `<table class="rev-data-table"><thead><tr>
      <th>Barkod</th><th>Naziv</th><th class="rev-th-num">Količina</th><th></th>
    </tr></thead><tbody>${state.lines
      .map(
        (ln, idx) => `<tr>
          <td><span class="rev-mono">${escHtml(ln.barcode || '')}</span></td>
          <td>${escHtml(ln.naziv || ln.oznaka || '')}</td>
          <td class="rev-td-num">
            <button type="button" class="rev-qty-btn" data-rev-qty-dec="${idx}">−</button>
            <input type="number" class="rev-qty-input" data-rev-qty-inp="${idx}" min="1" step="1" value="${escHtml(String(ln.quantity || 1))}"/>
            <button type="button" class="rev-qty-btn" data-rev-qty-inc="${idx}">+</button>
            <span class="rev-muted"> ${escHtml(ln.unit || 'kom')}</span>
          </td>
          <td><button type="button" class="rev-act-btn" title="Ukloni" data-rev-line-rm="${idx}">×</button></td>
        </tr>`,
      )
      .join('')}</tbody></table>`;
  }

  function paint() {
    const body = overlay.querySelector('#revRznScanBody');
    const foot = overlay.querySelector('#revRznScanFoot');
    if (!body || !foot) return;

    body.innerHTML = `
      <div class="rev-scan-grid">
        ${compatibleWarning()}
        <section class="rev-qa-block">
          <button type="button" class="rev-qa-cta rev-qa-cta--primary" id="revRznQaTool">
            <span class="rev-qa-ico" aria-hidden="true">📷</span>
            <span class="rev-qa-txt">
              <span class="rev-qa-title">SKENIRAJ ALAT</span>
              <span class="rev-qa-sub">Barkod sa pločice (RZN-…)</span>
            </span>
          </button>
          <div class="rev-qa-row">
            <button type="button" class="rev-qa-cta rev-qa-cta--secondary" id="revRznQaCard">
              <span class="rev-qa-ico" aria-hidden="true">🆔</span>
              <span class="rev-qa-txt">
                <span class="rev-qa-title">KARTICA OPERATERA</span>
                <span class="rev-qa-sub">${state.employee ? escHtml(state.employee.full_name) : 'Skeniraj ID'}</span>
              </span>
            </button>
            <button type="button" class="rev-qa-cta rev-qa-cta--secondary" id="revRznQaMachine">
              <span class="rev-qa-ico" aria-hidden="true">🏭</span>
              <span class="rev-qa-txt">
                <span class="rev-qa-title">MAŠINA</span>
                <span class="rev-qa-sub">${state.machine ? escHtml(state.machine.rj_code) : 'Skeniraj ZADU-M-…'}</span>
              </span>
            </button>
          </div>
          <details class="rev-qa-pick" id="revRznQaEmpDetails">
            <summary class="rev-qa-cta rev-qa-cta--secondary rev-qa-cta--pick">
              <span class="rev-qa-ico" aria-hidden="true">✍</span>
              <span class="rev-qa-txt">
                <span class="rev-qa-title">UNESI IME RADNIKA</span>
                <span class="rev-qa-sub">${state.employee ? escHtml(state.employee.full_name) : 'Bez kartice — pretraga po imenu'}</span>
              </span>
              <span class="rev-qa-pick-chevron" aria-hidden="true">▾</span>
            </summary>
            <div class="rev-qa-pick-body">
              <input type="search" id="revRznQaEmpSearch" class="rev-input" autocomplete="off"
                     placeholder="Pretraga: ime, prezime…" value="${escHtml(state.empPickQuery)}"/>
              <ul class="rev-qa-emp-list" id="revRznQaEmpList"></ul>
            </div>
          </details>
        </section>

        <div class="rev-scan-lines">
          <h3 class="rev-h3">Stavke za zaduženje</h3>
          ${linesHtml()}
        </div>

        <div class="rev-form-grid">
          <label>Rok povraćaja (opciono)
            <input type="date" id="revRznExpRet" class="rev-input" value="${escHtml(state.expectedReturnDate || '')}"/>
          </label>
          <label>Napomena (opciono)
            <textarea id="revRznNote" rows="2" class="rev-input">${escHtml(state.napomena || '')}</textarea>
          </label>
        </div>

        <details class="rev-qa-manual">
          <summary>Manuelni / HID unos (USB skener, klavijatura)</summary>
          <div class="rev-scan-input-row">
            <label class="rev-field-label">Skeniraj barkod (alat / radnik / mašina)</label>
            <input type="text" id="revRznScanIn" class="rev-input rev-input--scan" placeholder="Skeniraj ili otkucaj kod… (Enter za potvrdu)" autocomplete="off" value="${escHtml(state.lastInput)}"/>
            <p class="rev-muted rev-scan-hint">Prefiksi: <code>RZN-</code> = alat, <code>ZADU-M-</code> = mašina, ostalo = ID kartica radnika.</p>
          </div>
          <div class="rev-scan-summary">
            <div class="rev-scan-pill ${state.machine ? 'is-on' : ''}">
              <span class="rev-scan-pill-label">Mašina</span>
              <span class="rev-scan-pill-val">${state.machine ? `${escHtml(state.machine.rj_code)} <span class="rev-muted">${escHtml(state.machine.name || '')}</span>` : '<em>—</em>'}</span>
            </div>
            <div class="rev-scan-pill ${state.employee ? 'is-on' : ''}">
              <span class="rev-scan-pill-label">Operater</span>
              <span class="rev-scan-pill-val">${state.employee ? escHtml(state.employee.full_name) : '<em>—</em>'}</span>
            </div>
            <div class="rev-scan-pill ${state.lines.length > 0 ? 'is-on' : ''}">
              <span class="rev-scan-pill-label">Stavki</span>
              <span class="rev-scan-pill-val">${state.lines.length}</span>
            </div>
          </div>
        </details>

        <div class="rev-scan-fallback">
          <details>
            <summary>Manuelni izbor (ako skener ne radi)</summary>
            <div class="rev-form-grid">
              <label>Mašina
                <select id="revRznMSel" class="rev-select">
                  <option value="">— izaberi —</option>
                  ${machineOptionsHtml()}
                </select>
              </label>
              <label>Operater
                <select id="revRznESel" class="rev-select">
                  <option value="">— izaberi —</option>
                  ${employeeOptionsHtml()}
                </select>
              </label>
              <label>Dodatni operateri <span class="rev-muted">(druga smena, opciono)</span>
                <select id="revRznSecOps" class="rev-select rev-select--multi" multiple size="5">
                  ${state.employees
                    .filter((e) => !state.employee?.id || e.id !== state.employee.id)
                    .map((e) => {
                      const sel = state.secondaryIds.includes(e.id) ? 'selected' : '';
                      return `<option value="${escHtml(e.id)}" ${sel}>${escHtml(e.full_name)}</option>`;
                    })
                    .join('')}
                </select>
              </label>
            </div>
          </details>
        </div>
      </div>`;

    foot.innerHTML = `
      <button type="button" class="rev-btn" data-rev-close>Otkaži</button>
      <button type="button" class="rev-btn rev-btn--primary rev-btn--lg rev-qa-submit" id="revRznScanSubmit" ${canSubmit() ? '' : 'disabled'}>${state.pending ? 'Čuvam…' : `POTVRDI ZADUŽENJE${state.lines.length ? ` (${state.lines.length})` : ''}`}</button>`;

    bindEvents();
  }

  function canSubmit() {
    return state.machine && state.employee && state.lines.length > 0 && !state.pending;
  }

  function bindEvents() {
    overlay.querySelector('#revRznQaTool')?.addEventListener('click', () => {
      openReversiScanOverlay({
        title: 'Skeniraj rezni alat',
        hint: 'Barkod RZN-… sa pločice. Skener ostaje otvoren za seriju.',
        acceptKinds: ['CUTTING'],
        continuous: true,
        onResult: async (parsed) => {
          if (!parsed.data?.id) {
            showToast('Alat nije u katalogu');
            return;
          }
          addLineFromCatalog(parsed.data, 1);
          paint();
        },
      });
    });

    overlay.querySelector('#revRznQaCard')?.addEventListener('click', () => {
      openReversiScanOverlay({
        title: 'Skeniraj karticu operatera',
        hint: 'ID kartica zaposlenog',
        acceptKinds: ['EMPLOYEE'],
        continuous: false,
        onResult: async (parsed) => {
          const emp = parsed.data;
          if (!emp?.id) {
            showToast('Kartica nije prepoznata');
            return;
          }
          state.employee = { id: emp.id, full_name: emp.full_name };
          paint();
        },
      });
    });

    overlay.querySelector('#revRznQaMachine')?.addEventListener('click', () => {
      openReversiScanOverlay({
        title: 'Skeniraj mašinu',
        hint: 'Nalepnica ZADU-M-… na mašini',
        acceptUnknown: true,
        continuous: false,
        onResult: async (parsed) => {
          void handleScannedInput(parsed.barcode);
        },
      });
    });

    const inp = overlay.querySelector('#revRznScanIn');
    if (inp) {
      inp.addEventListener('keydown', (ev) => {
        if (ev.key === 'Enter') {
          ev.preventDefault();
          const v = inp.value.trim();
          inp.value = '';
          state.lastInput = '';
          if (v) handleScannedInput(v);
        }
      });
      inp.addEventListener('input', (ev) => {
        state.lastInput = ev.target.value;
      });
    }

    const det = overlay.querySelector('.rev-qa-manual');
    det?.addEventListener('toggle', () => {
      if (det.open) overlay.querySelector('#revRznScanIn')?.focus();
    });

    overlay.querySelector('#revRznMSel')?.addEventListener('change', (ev) => {
      const code = ev.target.value;
      state.machine = state.machines.find((m) => m.rj_code === code) || null;
      paint();
    });
    overlay.querySelector('#revRznESel')?.addEventListener('change', (ev) => {
      const eid = ev.target.value;
      state.employee = state.employees.find((e) => e.id === eid) || null;
      state.secondaryIds = state.secondaryIds.filter((id) => id && id !== state.employee?.id);
      paint();
    });
    overlay.querySelector('#revRznSecOps')?.addEventListener('change', (ev) => {
      state.secondaryIds = Array.from(ev.target.selectedOptions).map((o) => o.value);
    });
    overlay.querySelector('#revRznExpRet')?.addEventListener('change', (ev) => {
      state.expectedReturnDate = ev.target.value;
    });
    overlay.querySelector('#revRznNote')?.addEventListener('input', (ev) => {
      state.napomena = ev.target.value;
    });

    overlay.querySelectorAll('[data-rev-qty-inc]').forEach((b) => {
      b.addEventListener('click', () => {
        const i = Number(b.getAttribute('data-rev-qty-inc'));
        state.lines[i].quantity = (Number(state.lines[i].quantity) || 1) + 1;
        paint();
      });
    });
    overlay.querySelectorAll('[data-rev-qty-dec]').forEach((b) => {
      b.addEventListener('click', () => {
        const i = Number(b.getAttribute('data-rev-qty-dec'));
        const q = Number(state.lines[i].quantity) || 1;
        state.lines[i].quantity = Math.max(1, q - 1);
        paint();
      });
    });
    overlay.querySelectorAll('[data-rev-qty-inp]').forEach((b) => {
      b.addEventListener('change', () => {
        const i = Number(b.getAttribute('data-rev-qty-inp'));
        const v = Math.max(1, Math.floor(Number(b.value) || 1));
        state.lines[i].quantity = v;
        paint();
      });
    });
    overlay.querySelectorAll('[data-rev-line-rm]').forEach((b) => {
      b.addEventListener('click', () => {
        const i = Number(b.getAttribute('data-rev-line-rm'));
        state.lines.splice(i, 1);
        paint();
      });
    });

    overlay.querySelector('#revRznScanSubmit')?.addEventListener('click', submit);

    const empDet = overlay.querySelector('#revRznQaEmpDetails');
    const empSearch = overlay.querySelector('#revRznQaEmpSearch');

    if (empDet) {
      empDet.addEventListener('toggle', () => {
        if (!empDet.open) return;
        paintEmpPickList(state.empPickRows);
        setTimeout(() => empSearch?.focus(), 50);
      });
    }

    if (empSearch) {
      empSearch.addEventListener('input', () => {
        const q = empSearch.value.trim();
        state.empPickQuery = q;
        clearTimeout(bindEvents._empDeb);
        bindEvents._empDeb = setTimeout(async () => {
          if (!q) {
            state.empPickRows = null;
            paintEmpPickList(state.employees);
            return;
          }
          const r = await fetchEmployeesAny(q);
          state.empPickRows = r.ok && Array.isArray(r.data) ? r.data : [];
          paintEmpPickList(state.empPickRows);
        }, 220);
      });
    }
  }

  function paintEmpPickList(rows) {
    const ul = overlay.querySelector('#revRznQaEmpList');
    if (!ul) return;
    const list = Array.isArray(rows) ? rows : state.employees;
    const limited = list.slice(0, 8);
    if (limited.length === 0) {
      ul.innerHTML = '<li class="rev-qa-emp-empty">Nema rezultata</li>';
      return;
    }
    ul.innerHTML = limited
      .map(
        (e) => `<li>
        <button type="button" class="rev-qa-emp-row" data-rev-emp-pick="${escHtml(e.id)}">
          <strong>${escHtml(e.full_name)}</strong>
          ${e.department ? `<span class="rev-muted"> · ${escHtml(e.department)}</span>` : ''}
        </button>
      </li>`,
      )
      .join('');
    ul.querySelectorAll('[data-rev-emp-pick]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const eid = btn.getAttribute('data-rev-emp-pick');
        const emp = (Array.isArray(rows) ? rows : state.employees).find((e) => e.id === eid);
        if (!emp) return;
        state.employee = { id: emp.id, full_name: emp.full_name };
        const det = overlay.querySelector('#revRznQaEmpDetails');
        if (det) det.open = false;
        state.empPickQuery = '';
        state.empPickRows = null;
        paint();
        showToast(`Operater: ${emp.full_name}`);
      });
    });
  }

  async function handleScannedInput(raw) {
    const v = raw.trim();
    if (!v) return;

    if (/^RZN-/i.test(v)) {
      await tryAddTool(v);
      return;
    }
    if (/^ZADU-M-/i.test(v)) {
      const code = v.replace(/^ZADU-M-/i, '').replace(/_/g, '.');
      const m = state.machines.find((mm) => mm.rj_code === code) || null;
      if (m) {
        state.machine = m;
        showToast(`Mašina: ${m.rj_code} ${m.name || ''}`);
      } else {
        showToast(`Mašina ${code} nije pronađena`);
      }
      paint();
      return;
    }

    /* Probaj kao card_barcode → operater */
    const er = await fetchEmployeeByCardBarcode(v);
    if (er.ok && er.data?.id) {
      state.employee = { id: er.data.id, full_name: er.data.full_name };
      showToast(`Operater: ${er.data.full_name}`);
      paint();
      return;
    }

    /* Fallback: probaj kao alat (možda barkod nema RZN- prefiks) */
    const tr = await fetchCuttingToolByBarcode(v);
    if (tr.ok && tr.data?.id) {
      addLineFromCatalog(tr.data, 1);
      paint();
      promptEmployeeCardIfNeeded();
      return;
    }

    /* Fallback 2: probaj kao rj_code mašine direktno */
    const m2 = state.machines.find((mm) => mm.rj_code === v);
    if (m2) {
      state.machine = m2;
      showToast(`Mašina: ${m2.rj_code} ${m2.name || ''}`);
      paint();
      return;
    }

    showToast(`Nepoznat barkod: ${v}`);
  }

  function promptEmployeeCardIfNeeded() {
    if (!state.employee && state.lines.length === 1) {
      setTimeout(() => overlay.querySelector('#revRznQaCard')?.click(), 250);
    }
  }

  async function tryAddTool(barcode) {
    const r = await fetchCuttingToolByBarcode(barcode);
    if (!r.ok || !r.data?.id) {
      showToast(`Šifra nije pronađena: ${barcode}`);
      return;
    }
    addLineFromCatalog(r.data, 1);
    paint();
    promptEmployeeCardIfNeeded();
  }

  function addLineFromCatalog(catalog, qty) {
    const existing = state.lines.find((ln) => ln.catalog_id === catalog.id);
    if (existing) {
      existing.quantity = (Number(existing.quantity) || 0) + (qty || 1);
    } else {
      state.lines.push({
        catalog_id: catalog.id,
        barcode: catalog.barcode,
        oznaka: catalog.oznaka,
        naziv: catalog.naziv,
        klasa: catalog.klasa,
        unit: catalog.unit || 'kom',
        compatible: catalog.compatible_machine_codes || [],
        quantity: qty || 1,
      });
    }
  }

  async function submit() {
    if (!canSubmit()) {
      showToast('Skeniraj/izaberi mašinu, operatera i bar jednu stavku');
      return;
    }
    state.pending = true;
    paint();
    const payload = {
      recipient_machine_code: state.machine.rj_code,
      issued_to_employee_id: state.employee.id,
      issued_to_employee_name: state.employee.full_name,
      expected_return_date: state.expectedReturnDate || null,
      napomena: state.napomena || null,
      lines: state.lines.map((ln, i) => ({
        catalog_id: ln.catalog_id,
        quantity: ln.quantity,
        sort_order: i,
      })),
    };
    const secRaw = state.secondaryIds.filter((id) => id && id !== state.employee.id);
    if (secRaw.length > 0) {
      const assignees = [
        { employee_id: state.employee.id, role: 'PRIMARY' },
        ...secRaw.map((id) => ({ employee_id: id, role: 'SECONDARY' })),
      ];
      payload.assignees = assignees;
    }
    const res = await issueCuttingReversal(payload);
    state.pending = false;
    if (!res.ok) {
      showToast(`Greška: ${res.error}`);
      paint();
      return;
    }
    showToast(`✓ Zaduženje kreirano: ${res.data?.doc_number || ''}`);
    overlay.remove();
    opts.onSuccess?.(res.data);
  }

  paint();
}

/**
 * Modal za scanner-driven povraćaj reznog alata.
 *
 * Operater skenira barkod alata → tražimo mu otvoren revers (kao issued_to_employee_id);
 * ako ima više otvorenih za istu šifru, biramo prvi (FIFO). Količina default = preostalo.
 *
 * @param {{ onSuccess?: () => void }} [opts]
 */
export function openCuttingToolReturnScannerModal(opts = {}) {
  const id = `revRznRet_${Date.now()}`;
  const state = {
    items: [], // [{ document_id, line_id, barcode, naziv, remaining, return_qty, unit }]
    pending: false,
    lastInput: '',
    notes: '',
  };

  const overlay = modalShell(
    '↩ Skenirani povraćaj reznog alata',
    `<div id="revRznRetBody"></div>`,
    `<div id="revRznRetFoot"></div>`,
    id,
  );
  document.body.appendChild(overlay);
  attachClose(overlay, opts.onClose);

  function paint() {
    const body = overlay.querySelector('#revRznRetBody');
    const foot = overlay.querySelector('#revRznRetFoot');
    if (!body || !foot) return;

    const itemsHtml = state.items.length === 0
      ? '<p class="rev-muted">Nema stavki. Skeniraj barkod alata koji vraćaš.</p>'
      : `<table class="rev-data-table"><thead><tr>
          <th>Barkod</th><th>Naziv</th><th>Doc</th><th class="rev-th-num">Vraćam</th><th></th>
        </tr></thead><tbody>${state.items
          .map(
            (it, i) => `<tr>
              <td><span class="rev-mono">${escHtml(it.barcode || '')}</span></td>
              <td>${escHtml(it.naziv || '')}</td>
              <td><span class="rev-mono rev-muted">${escHtml(it.doc_number || '')}</span></td>
              <td class="rev-td-num">
                <button type="button" class="rev-qty-btn" data-rev-rqty-dec="${i}">−</button>
                <input type="number" class="rev-qty-input" data-rev-rqty-inp="${i}" min="1" max="${escHtml(String(it.remaining))}" value="${escHtml(String(it.return_qty || it.remaining))}"/>
                <button type="button" class="rev-qty-btn" data-rev-rqty-inc="${i}">+</button>
                <span class="rev-muted">/ ${escHtml(String(it.remaining))} ${escHtml(it.unit || 'kom')}</span>
              </td>
              <td><button type="button" class="rev-act-btn" data-rev-rline-rm="${i}">×</button></td>
            </tr>`,
          )
          .join('')}</tbody></table>`;

    body.innerHTML = `
      <div class="rev-scan-grid">
        <section class="rev-qa-block">
          <button type="button" class="rev-qa-cta rev-qa-cta--primary" id="revRznRetQa">
            <span class="rev-qa-ico" aria-hidden="true">📷</span>
            <span class="rev-qa-txt">
              <span class="rev-qa-title">SKENIRAJ ZA POVRAĆAJ</span>
              <span class="rev-qa-sub">RZN-… sa pločice — skener radi u seriji</span>
            </span>
          </button>
        </section>
        ${itemsHtml}
        <label>Napomena povraćaja
          <textarea id="revRznRetNote" rows="2" class="rev-input">${escHtml(state.notes)}</textarea>
        </label>
        <details class="rev-qa-manual">
          <summary>Manuelni / HID unos (USB skener, klavijatura)</summary>
          <div class="rev-scan-input-row">
            <label class="rev-field-label">Skeniraj barkod alata za povraćaj</label>
            <input type="text" id="revRznRetIn" class="rev-input rev-input--scan" placeholder="Skeniraj barkod (RZN-…)" autocomplete="off" value="${escHtml(state.lastInput)}"/>
          </div>
        </details>
      </div>`;

    foot.innerHTML = `
      <button type="button" class="rev-btn" data-rev-close>Otkaži</button>
      <button type="button" class="rev-btn rev-btn--primary rev-btn--lg rev-qa-submit" id="revRznRetSubmit" ${state.items.length > 0 && !state.pending ? '' : 'disabled'}>${state.pending ? 'Čuvam…' : `POTVRDI POVRAĆAJ${state.items.length ? ` (${state.items.length})` : ''}`}</button>`;

    bindEvents();
  }

  function bindEvents() {
    overlay.querySelector('#revRznRetQa')?.addEventListener('click', () => {
      openReversiScanOverlay({
        title: 'Skeniraj povraćaj',
        hint: 'RZN-… sa pločice — vraća se sa otvorenog reversa',
        acceptKinds: ['CUTTING'],
        continuous: true,
        onResult: async (parsed) => {
          await handleReturnScan(parsed.barcode);
        },
      });
    });

    const inp = overlay.querySelector('#revRznRetIn');
    if (inp) {
      inp.addEventListener('keydown', (ev) => {
        if (ev.key === 'Enter') {
          ev.preventDefault();
          const v = inp.value.trim();
          inp.value = '';
          state.lastInput = '';
          if (v) handleReturnScan(v);
        }
      });
      inp.addEventListener('input', (ev) => {
        state.lastInput = ev.target.value;
      });
    }

    const retDet = overlay.querySelector('.rev-qa-manual');
    retDet?.addEventListener('toggle', () => {
      if (retDet.open) overlay.querySelector('#revRznRetIn')?.focus();
    });

    overlay.querySelector('#revRznRetNote')?.addEventListener('input', (e) => {
      state.notes = e.target.value;
    });
    overlay.querySelectorAll('[data-rev-rqty-inc]').forEach((b) => {
      b.addEventListener('click', () => {
        const i = Number(b.getAttribute('data-rev-rqty-inc'));
        state.items[i].return_qty = Math.min(state.items[i].remaining, Number(state.items[i].return_qty || 0) + 1);
        paint();
      });
    });
    overlay.querySelectorAll('[data-rev-rqty-dec]').forEach((b) => {
      b.addEventListener('click', () => {
        const i = Number(b.getAttribute('data-rev-rqty-dec'));
        state.items[i].return_qty = Math.max(1, Number(state.items[i].return_qty || 0) - 1);
        paint();
      });
    });
    overlay.querySelectorAll('[data-rev-rqty-inp]').forEach((b) => {
      b.addEventListener('change', () => {
        const i = Number(b.getAttribute('data-rev-rqty-inp'));
        const max = state.items[i].remaining;
        state.items[i].return_qty = Math.max(1, Math.min(max, Math.floor(Number(b.value) || 1)));
        paint();
      });
    });
    overlay.querySelectorAll('[data-rev-rline-rm]').forEach((b) => {
      b.addEventListener('click', () => {
        const i = Number(b.getAttribute('data-rev-rline-rm'));
        state.items.splice(i, 1);
        paint();
      });
    });
    overlay.querySelector('#revRznRetSubmit')?.addEventListener('click', submit);
  }

  async function handleReturnScan(barcode) {
    const my = await fetchMyIssuedCuttingTools();
    if (!my.ok) {
      showToast(`Greška: ${my.error}`);
      return;
    }
    const matches = (my.data || []).filter((r) => r.barcode === barcode && r.line_status === 'ISSUED');
    if (matches.length === 0) {
      showToast(`Nema otvorenog reversa za alat ${barcode} na vama`);
      return;
    }
    matches.sort((a, b) => String(a.issued_at).localeCompare(String(b.issued_at)));
    const m = matches[0];
    if (state.items.find((it) => it.line_id === m.line_id)) {
      showToast('Stavka je već u listi');
      return;
    }
    state.items.push({
      document_id: m.document_id,
      doc_number: m.doc_number,
      line_id: m.line_id,
      barcode: m.barcode,
      naziv: m.naziv,
      remaining: Number(m.remaining_quantity) || 0,
      return_qty: Number(m.remaining_quantity) || 0,
      unit: m.unit,
    });
    paint();
  }

  async function submit() {
    if (state.items.length === 0) return;
    state.pending = true;
    paint();
    const byDoc = new Map();
    for (const it of state.items) {
      if (!byDoc.has(it.document_id)) byDoc.set(it.document_id, []);
      byDoc.get(it.document_id).push({ line_id: it.line_id, returned_quantity: Number(it.return_qty) });
    }
    let totalDocs = 0;
    let failed = 0;
    for (const [docId, lines] of byDoc.entries()) {
      const r = await confirmCuttingReturn({
        doc_id: docId,
        return_to_location_id: null,
        return_notes: state.notes || null,
        returned_lines: lines,
      });
      if (r.ok) totalDocs += 1;
      else failed += 1;
    }
    state.pending = false;
    if (failed > 0) {
      showToast(`Povraćaj: ${totalDocs} dokumenta uspešno, ${failed} neuspešno`);
    } else {
      showToast(`✓ Povraćaj kreiran (${totalDocs} dokumenata)`);
    }
    overlay.remove();
    opts.onSuccess?.();
  }

  paint();
}
