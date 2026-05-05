/**
 * Projektni biro — root shell (tabs + Plan + Kanban + Gantt + Izveštaji + Analiza).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { logout } from '../../services/auth.js';
import { toggleTheme } from '../../lib/theme.js';
import { canEditProjektniBiro, getAuth, isAdmin } from '../../state/auth.js';
import {
  getPbProjects,
  getPbEngineers,
  getPbTasks,
  getPbLoadStats,
  getPbWorkReports,
} from '../../services/pb.js';
import {
  loadPbState,
  savePbState,
  openTaskEditorModal,
  savePbGanttMonth,
  stopPbIzvestajiSpeech,
  pbErrorMessage,
} from './shared.js';
import { renderPlanTab } from './planTab.js';
import { renderKanbanTab } from './kanbanTab.js';
import { renderGanttTab } from './ganttTab.js';
import { renderIzvestaji } from './izvestajiTab.js';
import { renderAnaliza } from './analizaTab.js';
import { renderPbPodesavanja } from './podesavanjaTab.js';

let teardownResize = null;

function mqMobile() {
  return window.matchMedia('(max-width: 767px)');
}

/* ── Inline SVG ikone (Lucide-compatible paths) ─── */
const IC_BACK = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>';
const IC_PLUS = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>';
const IC_MODULE = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>';

const TAB_ICONS = {
  plan:        '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>',
  kanban:      '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="18"/><rect x="14" y="3" width="7" height="18"/></svg>',
  gantt:       '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/><line x1="2" y1="20" x2="22" y2="20"/></svg>',
  izvestaji:   '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>',
  analiza:     '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></svg>',
  podesavanja: '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>',
};

/**
 * @param {HTMLElement} root
 * @param {{ onBackToHub: () => void, onLogout: () => void }} options
 */
export function renderPbModule(root, { onBackToHub, onLogout } = {}) {
  if (!getAuth().user) {
    showToast('Prijavi se da otvoriš Projektovanje');
    onBackToHub?.();
    return;
  }

  const state = loadPbState();
  let projects = [];
  let engineers = [];
  let tasks = [];
  let loadStats = [];
  let workReports = [];

  function mergeStoredState() {
    const s = loadPbState();
    state.activeProject = s.activeProject;
    state.activeEngineer = s.activeEngineer;
    state.activeTab = s.activeTab;
    state.moduleSearch = s.moduleSearch ?? '';
    state.moduleShowDone = s.moduleShowDone ?? false;
    state.ganttStartDate = s.ganttStartDate ?? null;
  }

  const ctx = {
    get projects() { return projects; },
    get engineers() { return engineers; },
    get tasks() { return tasks; },
    get loadStats() { return loadStats; },
    get moduleSearch() { return state.moduleSearch ?? ''; },
    get moduleShowDone() { return state.moduleShowDone ?? false; },
    onRefresh: () => loadAll(),
  };

  async function loadWorkReportsForMonth(year, month0) {
    const first = new Date(year, month0, 1);
    const last = new Date(year, month0 + 1, 0);
    const dateFrom = first.toISOString().slice(0, 10);
    const dateTo = last.toISOString().slice(0, 10);
    const wr = await getPbWorkReports({ dateFrom, dateTo, limit: 500 });
    workReports = Array.isArray(wr) ? wr : [];
  }

  async function loadAll() {
    mergeStoredState();
    const body = root.querySelector('#pbTabBody');
    if (body) {
      body.classList.add('pb-tab-body--loading');
      body.setAttribute('aria-busy', 'true');
    }
    const projFilter = state.activeProject === 'all' ? {} : { projectId: state.activeProject };
    const engFilter = state.activeEngineer === 'all' ? {} : { employeeId: state.activeEngineer };
    try {
      const [p, e, t, l] = await Promise.all([
        getPbProjects(),
        getPbEngineers(),
        getPbTasks({ ...projFilter, ...engFilter }),
        getPbLoadStats(20),
      ]);
      projects = p;
      engineers = e;
      if (state.activeEngineer !== 'all' && !engineers.some(en => en.id === state.activeEngineer)) {
        state.activeEngineer = 'all';
        savePbState(state);
      }
      tasks = t;
      loadStats = l;
      paintChrome();
      if (body) {
        body.classList.remove('pb-tab-body--loading');
        body.removeAttribute('aria-busy');
      }
      void mountActiveTab();
    } catch (err) {
      const msg = err?.message || 'Greška pri učitavanju';
      if (body) {
        body.classList.remove('pb-tab-body--loading');
        body.removeAttribute('aria-busy');
        body.innerHTML = `<div class="pb-load-error"><p><strong>Učitavanje nije uspelo</strong></p><p class="pb-muted">${escHtml(msg)}</p><button type="button" class="btn btn-primary" id="pbRetryLoad">Pokušaj ponovo</button></div>`;
        body.querySelector('#pbRetryLoad')?.addEventListener('click', () => loadAll());
      }
    }
  }

  function paintChrome() {
    const hub = root.querySelector('#pbHubSlot');
    if (!hub) return;
    const auth = getAuth();
    hub.innerHTML = `
      <header class="pb-header">
        <div class="pb-header-left">
          <button type="button" class="pb-back-btn" id="pbBackBtn" aria-label="Nazad na module">
            ${IC_BACK} Moduli
          </button>
          <div class="pb-header-brand">
            <div class="pb-module-icon" aria-hidden="true">${IC_MODULE}</div>
            <div>
              <div class="pb-header-title">Projektovanje</div>
              <div class="pb-header-sub">Projektni biro</div>
            </div>
          </div>
        </div>
        <div class="pb-header-right">
          <button type="button" class="pb-theme-btn" id="pbThemeBtn" aria-label="Tema">🌙</button>
          ${auth.role ? `<span class="pb-role-badge">${escHtml(auth.role.toUpperCase())}</span>` : ''}
          ${canEditProjektniBiro() ? `<button type="button" class="pb-primary-btn pb-new-desktop" id="pbNewDesk">${IC_PLUS} Novi zadatak</button>` : ''}
          <button type="button" class="pb-logout-btn" id="pbLogoutBtn">Odjavi se</button>
        </div>
      </header>
      <div class="pb-context-card">
        <div class="pb-context-row">
          <span class="pb-context-label">Projekat</span>
          <select id="pbProjectSel" class="pb-context-select">
            <option value="all">Svi projekti</option>
            ${projects.map(p => `<option value="${escHtml(p.id)}" ${state.activeProject === p.id ? 'selected' : ''}>${escHtml(p.project_code)} — ${escHtml(p.project_name)}</option>`).join('')}
          </select>
        </div>
        <div class="pb-context-divider"></div>
        <div class="pb-context-row pb-context-row--eng" id="pbChipHost"></div>
      </div>
      <nav class="pb-tabs" role="tablist" aria-label="Projektni biro tabovi">
        ${pbTabBtn('plan', 'Plan', state.activeTab === 'plan')}
        ${pbTabBtn('kanban', 'Kanban', state.activeTab === 'kanban')}
        ${pbTabBtn('gantt', 'Gantt', state.activeTab === 'gantt')}
        ${pbTabBtn('izvestaji', 'Izveštaji', state.activeTab === 'izvestaji')}
        ${pbTabBtn('analiza', 'Analiza', state.activeTab === 'analiza')}
        ${isAdmin() ? pbTabBtn('podesavanja', 'Podešavanja', state.activeTab === 'podesavanja') : ''}
      </nav>`;

    root.querySelector('#pbBackBtn')?.addEventListener('click', () => onBackToHub?.());
    root.querySelector('#pbThemeBtn')?.addEventListener('click', () => toggleTheme());
    root.querySelector('#pbLogoutBtn')?.addEventListener('click', async () => {
      await logout();
      onLogout?.();
    });
    root.querySelector('#pbProjectSel')?.addEventListener('change', e => {
      state.activeProject = e.target.value;
      savePbState(state);
      loadAll();
    });
    root.querySelector('#pbNewDesk')?.addEventListener('click', () => {
      openTaskEditorModal({
        task: null,
        projects,
        engineers,
        canEdit: canEditProjektniBiro(),
        onSaved: () => loadAll(),
      });
    });
    root.querySelectorAll('.pb-tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        state.activeTab = btn.dataset.pbTab || 'plan';
        savePbState(state);
        paintChrome();
        void mountActiveTab();
      });
    });

    renderEngineerChips(root.querySelector('#pbChipHost'), state);
  }

  function renderEngineerChips(host, st) {
    if (!host) return;
    const searchVal = host._engSearch || '';
    const filtered = searchVal
      ? engineers.filter(en => en.full_name.toLowerCase().includes(searchVal.toLowerCase()))
      : engineers;

    host.innerHTML = `
      <span class="pb-context-label">Inženjer</span>
      <div class="pb-eng-search-wrap">
        <input type="search" class="pb-eng-search" placeholder="Filter..." id="pbEngSearch" value="${escHtml(searchVal)}" />
      </div>
      <div class="pb-chip-list">
        <button type="button" class="pb-chip ${st.activeEngineer === 'all' ? 'active' : ''}" data-eng="all">Svi</button>
        ${filtered.map(en => `<button type="button" class="pb-chip ${st.activeEngineer === en.id ? 'active' : ''}" data-eng="${escHtml(en.id)}">${escHtml(en.full_name)}</button>`).join('')}
      </div>
    `;

    host.querySelector('#pbEngSearch')?.addEventListener('input', e => {
      host._engSearch = e.target.value;
      renderEngineerChips(host, st);
    });
    host.querySelectorAll('[data-eng]').forEach(btn => {
      btn.addEventListener('click', () => {
        st.activeEngineer = btn.getAttribute('data-eng') || 'all';
        savePbState(st);
        renderEngineerChips(host, st);
        loadAll();
      });
    });
  }

  function pbTabBtn(id, label, active) {
    const icon = TAB_ICONS[id] || '';
    return `<button type="button" role="tab" class="pb-tab-btn ${active ? 'active' : ''}" data-pb-tab="${escHtml(id)}" aria-selected="${active}">${icon}${escHtml(label)}</button>`;
  }

  function switchToPlanShowDone() {
    state.activeTab = 'plan';
    state.moduleShowDone = true;
    savePbState(state);
    paintChrome();
    void mountActiveTab();
  }

  async function mountActiveTab() {
    const body = root.querySelector('#pbTabBody');
    if (!body) return;
    mergeStoredState();
    const tab = state.activeTab || 'plan';
    if (tab !== 'izvestaji') stopPbIzvestajiSpeech();
    if (tab === 'plan') {
      renderPlanTab(body, ctx);
      return;
    }
    if (tab === 'kanban') {
      renderKanbanTab(body, {
        tasks,
        projects,
        engineers,
        search: state.moduleSearch ?? '',
        showDone: state.moduleShowDone ?? false,
        onRefresh: () => loadAll(),
        onSwitchToPlanShowDone: switchToPlanShowDone,
      });
      return;
    }
    if (tab === 'gantt') {
      let viewMonth = state.ganttStartDate ? new Date(state.ganttStartDate) : new Date();
      if (Number.isNaN(viewMonth.getTime())) viewMonth = new Date();
      viewMonth.setDate(1);
      renderGanttTab(body, {
        tasks,
        projects,
        engineers,
        search: state.moduleSearch ?? '',
        viewMonth,
        onViewMonthChange: d => {
          const x = new Date(d);
          x.setDate(1);
          x.setHours(0, 0, 0, 0);
          savePbGanttMonth(x.toISOString());
          mergeStoredState();
          void mountActiveTab();
        },
        onRefresh: () => loadAll(),
      });
      return;
    }
    if (tab === 'izvestaji') {
      renderIzvestaji(body, {
        getWorkReports: () => workReports,
        loadMonthReports: loadWorkReportsForMonth,
        engineers,
        canEdit: canEditProjektniBiro(),
        defaultEmployeeId: null,
        actorEmail: getAuth().user?.emailRaw || getAuth().user?.email || null,
        onRefresh: async (year, month0) => {
          const y = year ?? new Date().getFullYear();
          const m = month0 ?? new Date().getMonth();
          try {
            await loadWorkReportsForMonth(y, m);
          } catch (err) {
            showToast(pbErrorMessage(err));
            return;
          }
          void mountActiveTab();
        },
      });
      return;
    }
    if (tab === 'analiza') {
      renderAnaliza(body, {
        tasks,
        engineers,
        projects,
        initialProjectId: state.activeProject !== 'all' ? state.activeProject : null,
      });
      return;
    }
    if (tab === 'podesavanja') {
      if (!isAdmin()) {
        body.innerHTML = '<p class="pb-muted">Samo administrator.</p>';
        return;
      }
      body.innerHTML = '';
      await renderPbPodesavanja(body, {});
      return;
    }
  }

  root.className = 'pb-module kadrovska-section';
  root.innerHTML = `
    <div id="pbHubSlot" class="pb-chrome"></div>
    <main id="pbTabBody" class="pb-tab-body pb-tab-body--loading" aria-busy="true">
      <div class="pb-loading-skel">
        <div class="pb-skel-line pb-skel-line--lg"></div>
        <div class="pb-skel-grid">
          <div class="pb-skel-card"></div><div class="pb-skel-card"></div><div class="pb-skel-card"></div>
        </div>
        <div class="pb-skel-line"></div><div class="pb-skel-line"></div>
      </div>
    </main>
    ${canEditProjektniBiro() ? '<button type="button" class="pb-fab" id="pbFab" aria-label="Novi zadatak">+</button>' : ''}
  `;

  const mm = mqMobile();
  const applyMq = () => root.classList.toggle('pb-module--mobile', mm.matches);
  applyMq();
  mm.addEventListener('change', applyMq);
  teardownResize = () => mm.removeEventListener('change', applyMq);

  root.querySelector('#pbFab')?.addEventListener('click', () => {
    openTaskEditorModal({
      task: null,
      projects,
      engineers,
      canEdit: canEditProjektniBiro(),
      onSaved: () => loadAll(),
    });
  });

  loadAll();
}

export function teardownPbModule() {
  try {
    teardownResize?.();
  } catch {
    /* ignore */
  }
  teardownResize = null;
}
