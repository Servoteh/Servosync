/**
 * Mobilni Reversi hub — skeniranje, mašina (ljubičasto), operater (crveno),
 * pregled zaduženja (zeleno). Optimizovano za iOS/Android (safe-area, 72px tap).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { canAccessReversi, canManageReversi, getAuth } from '../../state/auth.js';
import {
  getMobileRevMachine,
  setMobileRevMachine,
  getMobileRevOperator,
  setMobileRevOperator,
} from '../../lib/mobileReversiSession.js';
import {
  fetchMachines,
  fetchCuttingByMachine,
} from '../../services/reversiService.js';
import { openReversiScanOverlay } from '../reversi/scanOverlay.js';
import { openQuickIssueModal } from '../reversi/quickIssueModal.js';

const SHELL = 'm-shell m-rev-shell';

function fmtDate(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return String(iso).slice(0, 10);
  return d.toLocaleDateString('sr-Latn-RS', { day: 'numeric', month: 'numeric', year: 'numeric' });
}

function headerHtml(title, sub, backAct = 'back') {
  const auth = getAuth();
  const email = auth?.user?.email || '—';
  return `
    <header class="m-header">
      <button type="button" class="m-btn-ghost m-back-btn" data-act="${backAct}" aria-label="Nazad">←</button>
      <div class="m-brand">
        <div class="m-brand-title">${escHtml(title)}</div>
        <div class="m-brand-sub">${escHtml(sub)}</div>
      </div>
      <button type="button" class="m-btn-ghost" data-act="home" aria-label="Početna">⌂</button>
    </header>
    <div class="m-user-strip">
      <span class="m-user-email">${escHtml(email)}</span>
    </div>`;
}

function ctxStripHtml() {
  const m = getMobileRevMachine();
  const o = getMobileRevOperator();
  return `
    <div class="m-rev-ctx-strip">
      <span class="m-rev-ctx m-rev-ctx--machine ${m ? 'is-set' : ''}">
        <span class="m-rev-ctx-label">Mašina</span>
        <span class="m-rev-ctx-val">${m ? escHtml(m.rj_code) : '—'}</span>
      </span>
      <span class="m-rev-ctx m-rev-ctx--operator ${o ? 'is-set' : ''}">
        <span class="m-rev-ctx-label">Operater</span>
        <span class="m-rev-ctx-val">${o ? escHtml(o.full_name) : '—'}</span>
      </span>
    </div>`;
}

function bindNav(mountEl, ctx, defaultBack = '/m/reversi') {
  mountEl.addEventListener('click', (ev) => {
    const act = ev.target.closest('[data-act]')?.dataset?.act;
    if (!act) return;
    switch (act) {
      case 'back':
        ctx.onNavigate(defaultBack);
        break;
      case 'home':
        ctx.onNavigate('/m');
        break;
      default:
        break;
    }
  });
}

/**
 * @param {HTMLElement} mountEl
 * @param {{ onNavigate: (path: string) => void }} ctx
 */
export function renderMobileReversiHub(mountEl, ctx) {
  if (!canAccessReversi()) {
    mountEl.innerHTML = `<div class="${SHELL}"><main class="m-main"><p>Nemate pristup modulu Reversi.</p></div>`;
    return { teardown: () => {} };
  }

  mountEl.innerHTML = `
    <div class="${SHELL}">
      ${headerHtml('REVERSI — ALATI', 'Zaduženja i rezni alat', 'home')}
      ${ctxStripHtml()}
      <main class="m-main">
        ${
          canManageReversi()
            ? `<button type="button" class="m-cta m-cta-rev-issue" data-act="issue">
          <span class="m-cta-ico">📷</span>
          <span class="m-cta-txt">
            <span class="m-cta-title">SKENIRAJ ALAT</span>
            <span class="m-cta-sub">Rezni alat i ručni alat — barkod RZN / ALAT</span>
          </span>
        </button>`
            : ''
        }
        <div class="m-section-head">Pre izdavanja</div>
        <div class="m-cta-row">
          <button type="button" class="m-cta m-cta-rev-machine" data-act="machine">
            <span class="m-cta-ico">⚙</span>
            <span class="m-cta-txt">
              <span class="m-cta-title">MAŠINA</span>
              <span class="m-cta-sub">Broj mašine, ZADU-M-…</span>
            </span>
          </button>
          <button type="button" class="m-cta m-cta-rev-operator" data-act="operator">
            <span class="m-cta-ico">👤</span>
            <span class="m-cta-txt">
              <span class="m-cta-title">OPERATER</span>
              <span class="m-cta-sub">ID kartica radnika</span>
            </span>
          </button>
        </div>
        <button type="button" class="m-cta m-cta-rev-overview" data-act="overview">
          <span class="m-cta-ico">📋</span>
          <span class="m-cta-txt">
            <span class="m-cta-title">PREGLED ZADUŽENJA</span>
            <span class="m-cta-sub">Filter po osobi i broju mašine</span>
          </span>
        </button>
        <button type="button" class="m-cta m-cta-secondary" data-act="desktop">
          <span class="m-cta-ico">🖥</span>
          <span class="m-cta-txt">
            <span class="m-cta-title">PUN MODUL</span>
            <span class="m-cta-sub">Inventar, magacin, štampa nalepnica</span>
          </span>
        </button>
      </main>
    </div>`;

  document.body.classList.add('m-body', 'm-rev-body');
  bindNav(mountEl, ctx, '/m');

  mountEl.addEventListener('click', (ev) => {
    const act = ev.target.closest('[data-act]')?.dataset?.act;
    if (!act || act === 'back' || act === 'home') return;
    switch (act) {
      case 'issue':
        ctx.onNavigate('/m/reversi/issue');
        break;
      case 'machine':
        ctx.onNavigate('/m/reversi/machine');
        break;
      case 'operator':
        ctx.onNavigate('/m/reversi/operator');
        break;
      case 'overview':
        ctx.onNavigate('/m/reversi/overview');
        break;
      case 'desktop':
        ctx.onNavigate('/reversi');
        break;
      default:
        break;
    }
  });

  return {
    teardown() {
      document.body.classList.remove('m-body', 'm-rev-body');
      mountEl.innerHTML = '';
    },
  };
}

/** @param {string} raw */
function parseMachineCode(raw) {
  const t = String(raw || '').trim();
  if (/^ZADU-M-/i.test(t)) return t.replace(/^ZADU-M-/i, '').trim();
  return t;
}

/**
 * @param {HTMLElement} mountEl
 * @param {{ onNavigate: (path: string) => void }} ctx
 */
export function renderMobileReversiMachine(mountEl, ctx) {
  const cur = getMobileRevMachine();
  let machines = [];

  async function paint() {
    const sel = mountEl.querySelector('#mRevMachSel');
    const cur2 = getMobileRevMachine();
    if (sel && machines.length) {
      sel.innerHTML =
        `<option value="">— Izaberi —</option>` +
        machines
          .map(
            (m) =>
              `<option value="${escHtml(m.rj_code)}" ${cur2?.rj_code === m.rj_code ? 'selected' : ''}>${escHtml(m.rj_code)} ${escHtml(m.name || '')}</option>`,
          )
          .join('');
    }
    const badge = mountEl.querySelector('#mRevMachCurrent');
    if (badge) {
      badge.innerHTML = cur2
        ? `<strong class="rev-mono">${escHtml(cur2.rj_code)}</strong> ${escHtml(cur2.name || '')}`
        : '<span class="m-muted">Nije izabrana</span>';
    }
  }

  mountEl.innerHTML = `
    <div class="${SHELL}">
      ${headerHtml('MAŠINA', 'Broj mašine za rezni alat')}
      <main class="m-main m-rev-form-main">
        <div class="m-rev-current m-rev-current--machine" id="mRevMachCurrent">
          ${cur ? `<strong class="rev-mono">${escHtml(cur.rj_code)}</strong> ${escHtml(cur.name || '')}` : '<span class="m-muted">Nije izabrana</span>'}
        </div>
        <button type="button" class="m-cta m-cta-rev-machine m-cta--full" data-act="scanMachine">
          <span class="m-cta-ico">📷</span>
          <span class="m-cta-txt">
            <span class="m-cta-title">SKENIRAJ MAŠINU</span>
            <span class="m-cta-sub">Barkod ZADU-M-… na mašini</span>
          </span>
        </button>
        <label class="m-field">
          <span class="m-field-label">ili izaberi sa liste</span>
          <select id="mRevMachSel" class="m-select"></select>
        </label>
        <div class="m-rev-actions">
          <button type="button" class="m-btn m-btn-primary" data-act="saveMachine">Sačuvaj</button>
          <button type="button" class="m-btn m-btn-ghost" data-act="clearMachine">Obriši</button>
        </div>
      </main>
    </div>`;

  document.body.classList.add('m-body', 'm-rev-body');
  bindNav(mountEl, ctx);

  void fetchMachines().then((r) => {
    machines = r.ok && Array.isArray(r.data) ? r.data : [];
    paint();
  });

  mountEl.addEventListener('click', (ev) => {
    const act = ev.target.closest('[data-act]')?.dataset?.act;
    if (!act || act === 'back' || act === 'home') return;
    if (act === 'scanMachine') {
      openReversiScanOverlay({
        title: 'Skeniraj mašinu',
        hint: 'ZADU-M-… ili broj mašine',
        acceptUnknown: true,
        continuous: false,
        onResult: async (parsed) => {
          const code = parseMachineCode(parsed.barcode);
          if (!code) {
            showToast('Nepoznat barkod mašine');
            return;
          }
          const hit = machines.find((m) => String(m.rj_code) === code);
          setMobileRevMachine({ rj_code: hit?.rj_code || code, name: hit?.name || '' });
          paint();
          showToast(`Mašina ${code}`);
        },
      });
      return;
    }
    if (act === 'saveMachine') {
      const code = mountEl.querySelector('#mRevMachSel')?.value;
      if (!code) {
        showToast('Izaberi mašinu');
        return;
      }
      const hit = machines.find((m) => m.rj_code === code);
      setMobileRevMachine({ rj_code: code, name: hit?.name || '' });
      paint();
      showToast('Mašina sačuvana');
      return;
    }
    if (act === 'clearMachine') {
      setMobileRevMachine(null);
      paint();
      showToast('Mašina uklonjena');
    }
  });

  return {
    teardown() {
      document.body.classList.remove('m-body', 'm-rev-body');
      mountEl.innerHTML = '';
    },
  };
}

/**
 * @param {HTMLElement} mountEl
 * @param {{ onNavigate: (path: string) => void }} ctx
 */
export function renderMobileReversiOperator(mountEl, ctx) {
  const cur = getMobileRevOperator();

  function paint() {
    const el = mountEl.querySelector('#mRevOpCurrent');
    if (!el) return;
    const o = getMobileRevOperator();
    el.innerHTML = o
      ? `<strong>${escHtml(o.full_name)}</strong>${o.department ? `<span class="m-muted"> · ${escHtml(o.department)}</span>` : ''}`
      : '<span class="m-muted">Nije izabran</span>';
  }

  mountEl.innerHTML = `
    <div class="${SHELL}">
      ${headerHtml('OPERATER', 'Ime radnika — ID kartica')}
      <main class="m-main m-rev-form-main">
        <div class="m-rev-current m-rev-current--operator" id="mRevOpCurrent">
          ${cur ? `<strong>${escHtml(cur.full_name)}</strong>` : '<span class="m-muted">Nije izabran</span>'}
        </div>
        <button type="button" class="m-cta m-cta-rev-operator m-cta--full" data-act="scanOperator">
          <span class="m-cta-ico">📷</span>
          <span class="m-cta-txt">
            <span class="m-cta-title">SKENIRAJ KARTICU</span>
            <span class="m-cta-sub">ID kartica radnika</span>
          </span>
        </button>
        <div class="m-rev-actions">
          <button type="button" class="m-btn m-btn-ghost" data-act="clearOperator">Obriši izbor</button>
        </div>
      </main>
    </div>`;

  document.body.classList.add('m-body', 'm-rev-body');
  bindNav(mountEl, ctx);

  mountEl.addEventListener('click', (ev) => {
    const act = ev.target.closest('[data-act]')?.dataset?.act;
    if (!act || act === 'back' || act === 'home') return;
    if (act === 'scanOperator') {
      openReversiScanOverlay({
        title: 'Skeniraj operatera',
        hint: 'ID kartica radnika',
        acceptKinds: ['EMPLOYEE'],
        continuous: false,
        onResult: async (parsed) => {
          const emp = parsed.data;
          if (!emp?.id) {
            showToast('Kartica nije prepoznata');
            return;
          }
          setMobileRevOperator({
            id: emp.id,
            full_name: emp.full_name,
            department: emp.department || '',
          });
          paint();
          showToast(emp.full_name);
        },
      });
      return;
    }
    if (act === 'clearOperator') {
      setMobileRevOperator(null);
      paint();
      showToast('Operater uklonjen');
    }
  });

  return {
    teardown() {
      document.body.classList.remove('m-body', 'm-rev-body');
      mountEl.innerHTML = '';
    },
  };
}

/**
 * @param {HTMLElement} mountEl
 * @param {{ onNavigate: (path: string) => void }} ctx
 */
export async function renderMobileReversiOverview(mountEl, ctx) {
  const state = {
    machineFilter: getMobileRevMachine()?.rj_code || '',
    personFilter: getMobileRevOperator()?.full_name || '',
    search: '',
    rows: [],
    loading: true,
  };

  function filteredRows() {
    let rows = state.rows;
    const m = state.machineFilter.trim().toLowerCase();
    const p = state.personFilter.trim().toLowerCase();
    if (m) rows = rows.filter((r) => String(r.machine_code || '').toLowerCase().includes(m));
    if (p) {
      rows = rows.filter((r) => {
        const names = `${r.operator_names || ''} ${r.last_issued_to_name || ''} ${r.employee_name || ''}`.toLowerCase();
        return names.includes(p);
      });
    }
    const s = state.search.trim().toLowerCase();
    if (s) {
      rows = rows.filter((r) => {
        const blob = `${r.oznaka} ${r.naziv} ${r.barcode} ${r.machine_code} ${r.klasa}`.toLowerCase();
        return blob.includes(s);
      });
    }
    return rows;
  }

  function cardHtml(r) {
    return `<article class="m-rev-card">
      <header class="m-rev-card-head">
        <span class="m-rev-card-machine rev-mono">${escHtml(r.machine_code || '—')}</span>
        <span class="m-rev-card-qty">${escHtml(String(r.remaining_qty || 0))} ${escHtml(r.unit || 'kom')}</span>
      </header>
      <div class="m-rev-card-title">${escHtml(r.oznaka || '')} · ${escHtml(r.naziv || '')}</div>
      <div class="m-rev-card-meta">
        <span>👤 ${escHtml(r.operator_names || r.last_issued_to_name || '—')}</span>
        <span>${escHtml(fmtDate(r.last_issued_at))}</span>
      </div>
    </article>`;
  }

  async function load() {
    state.loading = true;
    paint();
    const res = await fetchCuttingByMachine({ search: state.search || undefined });
    state.rows = res.ok && Array.isArray(res.data) ? res.data : [];
    state.loading = false;
    paint();
  }

  function paint() {
    const list = mountEl.querySelector('#mRevOverviewList');
    const meta = mountEl.querySelector('#mRevOverviewMeta');
    if (!list) return;
    const rows = filteredRows();
    if (meta) {
      meta.textContent = state.loading
        ? 'Učitavam…'
        : `${rows.length} aktivnih stavki${state.rows.length !== rows.length ? ` (od ${state.rows.length})` : ''}`;
    }
    if (state.loading) {
      list.innerHTML = '<div class="m-loading-dot"></div>';
      return;
    }
    if (!rows.length) {
      list.innerHTML = '<p class="m-muted m-rev-empty">Nema zaduženja za izabrane filtere.</p>';
      return;
    }
    list.innerHTML = rows.map(cardHtml).join('');
  }

  mountEl.innerHTML = `
    <div class="${SHELL}">
      ${headerHtml('PREGLED ZADUŽENJA', 'Rezni alat na mašinama')}
      <main class="m-main m-rev-overview-main">
        <div class="m-rev-filters">
          <label class="m-field m-field--compact">
            <span class="m-field-label m-field-label--machine">Mašina</span>
            <input type="text" id="mRevFMachine" class="m-input" placeholder="npr. 8.3" value="${escHtml(state.machineFilter)}"/>
          </label>
          <label class="m-field m-field--compact">
            <span class="m-field-label m-field-label--operator">Operater</span>
            <input type="text" id="mRevFPerson" class="m-input" placeholder="Ime radnika" value="${escHtml(state.personFilter)}"/>
          </label>
          <label class="m-field m-field--compact">
            <span class="m-field-label">Pretraga</span>
            <input type="search" id="mRevFSearch" class="m-input" placeholder="Šifra, naziv, barkod…" value="${escHtml(state.search)}"/>
          </label>
        </div>
        <p class="m-rev-overview-meta" id="mRevOverviewMeta">Učitavam…</p>
        <div class="m-rev-overview-list" id="mRevOverviewList"></div>
      </main>
    </div>`;

  document.body.classList.add('m-body', 'm-rev-body');
  bindNav(mountEl, ctx);

  let deb = null;
  mountEl.addEventListener('input', (ev) => {
    const id = ev.target?.id;
    if (id === 'mRevFMachine') state.machineFilter = ev.target.value;
    if (id === 'mRevFPerson') state.personFilter = ev.target.value;
    if (id === 'mRevFSearch') state.search = ev.target.value;
    clearTimeout(deb);
    deb = setTimeout(() => {
      if (id === 'mRevFSearch') void load();
      else paint();
    }, id === 'mRevFSearch' ? 350 : 80);
  });

  await load();

  return {
    teardown() {
      document.body.classList.remove('m-body', 'm-rev-body');
      mountEl.innerHTML = '';
    },
  };
}

/**
 * Izdavanje — rezni alat (scanner modal) ili Quick Issue ako nema mašine.
 * @param {HTMLElement} mountEl
 * @param {{ onNavigate: (path: string) => void }} ctx
 */
export function renderMobileReversiIssue(mountEl, ctx) {
  if (!canManageReversi()) {
    showToast('Nemate pravo za izdavanje');
    ctx.onNavigate('/m/reversi');
    return { teardown: () => {} };
  }

  mountEl.innerHTML = `<div class="m-shell m-shell-loading"><div class="m-loading-dot"></div></div>`;
  document.body.classList.add('m-body', 'm-rev-body', 'm-rev-issue-active');

  const goBack = () => ctx.onNavigate('/m/reversi');
  const machine = getMobileRevMachine();
  const operator = getMobileRevOperator();

  const preMachine = machine ? { rj_code: machine.rj_code, name: machine.name } : null;
  const preEmployee = operator
    ? { id: operator.id, full_name: operator.full_name }
    : null;

  openQuickIssueModal({
    preselectedMachine: preMachine,
    preselectedRecipient: operator
      ? {
          type: 'EMPLOYEE',
          employee_id: operator.id,
          employee_name: operator.full_name,
          department: operator.department || '',
        }
      : null,
    mobileLayout: true,
    onClose: goBack,
    onSuccess: goBack,
  });

  return {
    teardown() {
      document.body.classList.remove('m-body', 'm-rev-body', 'm-rev-issue-active');
      document.querySelectorAll('.rev-modal-overlay').forEach((el) => el.remove());
      mountEl.innerHTML = '';
    },
  };
}
