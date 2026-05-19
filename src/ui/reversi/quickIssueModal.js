/**
 * Quick Issue — skener-prvi tok izdavanja (magacioner).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { canManageReversi } from '../../state/auth.js';
import { startScan, stopScan } from '../../services/barcode.js';
import {
  fetchEmployeeByCardBarcode,
  fetchEmployees,
  fetchHandToolByBarcode,
  fetchCuttingToolByBarcode,
  issueReversal,
  issueCuttingReversal,
} from '../../services/reversiService.js';

function defaultReturnDate() {
  const d = new Date();
  d.setDate(d.getDate() + 14);
  return d.toISOString().slice(0, 10);
}

function modalShell(title, bodyId, footId, id) {
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay rev-modal-overlay rev-quick-issue-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal rev-modal rev-modal--quick-issue">
        <div class="kadr-modal-header">
          <h2>${escHtml(title)}</h2>
          <button type="button" class="kadr-modal-close" data-rev-qi-close>×</button>
        </div>
        <div class="kadr-modal-body rev-modal-body" id="${bodyId}"></div>
        <div class="kadr-modal-footer rev-modal-footer" id="${footId}"></div>
      </div>
    </div>`;
  return wrap.firstElementChild;
}

/**
 * @param {{ onSuccess?: () => void, preselectedMachine?: { rj_code: string, name?: string }|null }} opts
 */
export function openQuickIssueModal(opts = {}) {
  if (!canManageReversi()) {
    showToast('Nemate pravo za izdavanje');
    return;
  }

  const id = `revQi_${Date.now()}`;
  const state = {
    recipient: null,
    lines: [],
    expectedReturnDate: defaultReturnDate(),
    pending: false,
    scanCtrl: null,
    empSearch: '',
    employees: [],
  };

  const overlay = modalShell('Quick Issue', 'revQiBody', 'revQiFoot', id);
  document.body.appendChild(overlay);

  const close = () => {
    stopScan(state.scanCtrl);
    overlay.remove();
  };
  overlay.querySelector('[data-rev-qi-close]')?.addEventListener('click', close);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) close();
  });

  async function loadEmployees(q) {
    const r = await fetchEmployees(q);
    state.employees = r.ok && Array.isArray(r.data) ? r.data : [];
  }

  function lineKey(ln) {
    return ln.kind === 'HAND' ? `H:${ln.tool.id}` : `C:${ln.tool.id}`;
  }

  function paint() {
    const body = overlay.querySelector('#revQiBody');
    const foot = overlay.querySelector('#revQiFoot');
    if (!body || !foot) return;

    const recip = state.recipient
      ? `<div class="rev-qi-recipient is-set">
          <div class="rev-qi-recipient-name">${escHtml(state.recipient.employee_name)}</div>
          <div class="rev-muted">${escHtml(state.recipient.department || '')}</div>
          <button type="button" class="rev-btn rev-btn--sm" id="revQiClearRec">Promeni</button>
        </div>`
      : `<div class="rev-qi-recipient">
          <p>Skeniraj ID karticu radnika ILI izaberi sa liste</p>
          <button type="button" class="rev-btn rev-btn--secondary" id="revQiScanCard">Skeniraj karticu</button>
          <div class="rev-qi-emp-pick">
            <input type="search" id="revQiEmpSearch" class="rev-input" placeholder="Pretraga radnika…" value="${escHtml(state.empSearch)}"/>
            <select id="revQiEmpSel" class="rev-select" size="4">
              ${state.employees.map((e) => `<option value="${escHtml(e.id)}">${escHtml(e.full_name)}${e.department ? ` (${escHtml(e.department)})` : ''}</option>`).join('')}
            </select>
            <button type="button" class="rev-btn rev-btn--primary" id="revQiPickEmp">Izaberi</button>
          </div>
        </div>`;

    const chips = state.lines.length
      ? state.lines
          .map(
            (ln, i) => `<div class="rev-qi-chip">
            <span class="rev-mono">${escHtml(ln.tool.barcode || ln.tool.oznaka || '')}</span>
            <span>${escHtml(ln.tool.naziv || '')}</span>
            ${ln.kind === 'CUTTING' ? `<span class="rev-muted">×${ln.qty}</span>` : ''}
            <button type="button" class="rev-chip-x" data-rev-qi-rm="${i}">×</button>
          </div>`,
          )
          .join('')
      : '<p class="rev-muted">Nema stavki</p>';

    body.innerHTML = `
      <section class="rev-qi-section">
        <h3 class="rev-h3">Primalac</h3>
        ${recip}
      </section>
      <section class="rev-qi-section">
        <h3 class="rev-h3">Alati</h3>
        <div class="rev-qi-chips">${chips}</div>
        <div class="rev-qi-tool-actions">
          <button type="button" class="rev-btn rev-btn--secondary" id="revQiScanTool">Skeniraj alat</button>
          <button type="button" class="rev-btn" id="revQiPickTool" disabled title="Koristi skener">Izaberi sa liste</button>
        </div>
        <div id="revQiVideoWrap" class="rev-qi-video-wrap" hidden>
          <video id="revQiVideo" playsinline muted></video>
          <button type="button" class="rev-btn" id="revQiStopScan">Zaustavi skener</button>
        </div>
      </section>
      <section class="rev-qi-section">
        <label>Rok povraćaja
          <input type="date" id="revQiExp" class="rev-input" value="${escHtml(state.expectedReturnDate)}"/>
        </label>
      </section>`;

    foot.innerHTML = `
      <button type="button" class="rev-btn" data-rev-qi-close>Otkaži</button>
      <button type="button" class="rev-btn rev-btn--primary rev-btn--lg" id="revQiSubmit" ${state.lines.length && state.recipient && !state.pending ? '' : 'disabled'}>
        ${state.pending ? 'Izdajem…' : `Izdaj (${state.lines.length} stavki)`}
      </button>`;

    bindUi();
  }

  function bindUi() {
    overlay.querySelectorAll('[data-rev-qi-close]').forEach((b) => b.addEventListener('click', close));

    overlay.querySelector('#revQiClearRec')?.addEventListener('click', () => {
      state.recipient = null;
      paint();
    });

    overlay.querySelector('#revQiExp')?.addEventListener('change', (e) => {
      state.expectedReturnDate = e.target.value;
    });

    overlay.querySelector('#revQiEmpSearch')?.addEventListener('input', (e) => {
      state.empSearch = e.target.value;
      clearTimeout(bindUi._deb);
      bindUi._deb = setTimeout(() => void loadEmployees(state.empSearch).then(paint), 250);
    });

    overlay.querySelector('#revQiPickEmp')?.addEventListener('click', () => {
      const sel = overlay.querySelector('#revQiEmpSel');
      const eid = sel?.value;
      const emp = state.employees.find((e) => e.id === eid);
      if (!emp) {
        showToast('Izaberi radnika');
        return;
      }
      state.recipient = {
        type: 'EMPLOYEE',
        employee_id: emp.id,
        employee_name: emp.full_name,
        department: emp.department || '',
      };
      paint();
    });

    overlay.querySelectorAll('[data-rev-qi-rm]').forEach((b) => {
      b.addEventListener('click', () => {
        state.lines.splice(Number(b.getAttribute('data-rev-qi-rm')), 1);
        paint();
      });
    });

    overlay.querySelector('#revQiScanCard')?.addEventListener('click', () => startVideoScan('card'));
    overlay.querySelector('#revQiScanTool')?.addEventListener('click', () => startVideoScan('tool'));
    overlay.querySelector('#revQiStopScan')?.addEventListener('click', () => {
      stopScan(state.scanCtrl);
      state.scanCtrl = null;
      overlay.querySelector('#revQiVideoWrap')?.setAttribute('hidden', '');
    });

    overlay.querySelector('#revQiSubmit')?.addEventListener('click', () => void submit());
  }

  async function startVideoScan(mode) {
    const wrap = overlay.querySelector('#revQiVideoWrap');
    const video = overlay.querySelector('#revQiVideo');
    if (!video) return;
    wrap?.removeAttribute('hidden');
    stopScan(state.scanCtrl);
    state.scanCtrl = await startScan(video, {
      decodeProfile: 'item',
      onResult: (text) => {
        stopScan(state.scanCtrl);
        state.scanCtrl = null;
        wrap?.setAttribute('hidden', '');
        if (mode === 'card') void handleCardScan(text);
        else void handleToolScan(text);
      },
      onError: (err) => showToast(String(err?.message || err)),
    });
  }

  async function handleCardScan(raw) {
    const r = await fetchEmployeeByCardBarcode(raw.trim());
    if (!r.ok || !r.data?.id) {
      showToast('Kartica nije prepoznata');
      return;
    }
    state.recipient = {
      type: 'EMPLOYEE',
      employee_id: r.data.id,
      employee_name: r.data.full_name,
      department: r.data.department || '',
    };
    paint();
  }

  async function handleToolScan(raw) {
    const bc = raw.trim();
    if (/^ALAT-/i.test(bc)) {
      const tr = await fetchHandToolByBarcode(bc);
      if (!tr.ok || !tr.data?.id) {
        showToast('Ručni alat nije pronađen');
        return;
      }
      if (tr.data.issued_holder) {
        showToast('Alat je već zadužen');
        return;
      }
      const ln = { kind: 'HAND', tool: tr.data, qty: 1 };
      const k = lineKey(ln);
      if (state.lines.some((x) => lineKey(x) === k)) {
        showToast('Alat je već na listi');
        return;
      }
      state.lines.push(ln);
      paint();
      return;
    }
    if (/^RZN-/i.test(bc)) {
      const cr = await fetchCuttingToolByBarcode(bc);
      if (!cr.ok || !cr.data?.id) {
        showToast('Rezni alat nije pronađen');
        return;
      }
      const qtyStr = window.prompt('Količina za zaduženje:', '1');
      const qty = Math.max(1, Math.floor(Number(qtyStr) || 1));
      const ln = { kind: 'CUTTING', tool: cr.data, qty };
      const k = lineKey(ln);
      const ex = state.lines.find((x) => lineKey(x) === k);
      if (ex) ex.qty += qty;
      else state.lines.push(ln);
      paint();
      return;
    }
    showToast('Nepoznat format barkoda');
  }

  async function submit() {
    if (!state.recipient || state.lines.length === 0) return;
    state.pending = true;
    paint();
    const hand = state.lines.filter((l) => l.kind === 'HAND');
    const cutting = state.lines.filter((l) => l.kind === 'CUTTING');
    let issued = 0;

    if (hand.length > 0) {
      const payload = {
        doc_type: 'TOOL',
        recipient_type: 'EMPLOYEE',
        recipient_employee_id: state.recipient.employee_id,
        recipient_employee_name: state.recipient.employee_name,
        expected_return_date: state.expectedReturnDate || null,
        lines: hand.map((l, i) => ({
          line_type: 'TOOL',
          tool_id: l.tool.id,
          quantity: 1,
          unit: 'kom',
          napomena: '',
          sort_order: i + 1,
        })),
      };
      const res = await issueReversal(payload);
      if (!res.ok) {
        state.pending = false;
        showToast(res.error || 'Greška ručnog izdavanja');
        paint();
        return;
      }
      issued += hand.length;
    }

    for (const ln of cutting) {
      const payload = {
        recipient_machine_code: opts.preselectedMachine?.rj_code || null,
        issued_to_employee_id: state.recipient.employee_id,
        issued_to_employee_name: state.recipient.employee_name,
        expected_return_date: state.expectedReturnDate || null,
        lines: [{ catalog_id: ln.tool.id, quantity: ln.qty, sort_order: 0 }],
      };
      const res = await issueCuttingReversal(payload);
      if (!res.ok) {
        state.pending = false;
        showToast(res.error || 'Greška reznog izdavanja');
        paint();
        return;
      }
      issued += 1;
    }

    state.pending = false;
    showToast(`Izdato ${issued} stavki`);
    close();
    opts.onSuccess?.();
  }

  void loadEmployees('').then(paint);
}
