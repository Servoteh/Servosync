/**
 * Projektni biro — root shell (tabs + Plan + Kanban + Gantt + Izveštaji + Analiza).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { logout } from '../../services/auth.js';
import { toggleTheme } from '../../lib/theme.js';
import {
  canEditPbTasks,
  canEditPbWorkReports,
  getAuth,
  isAdmin,
  isPbReadOnly,
} from '../../state/auth.js';
import {
  closePbFilterDrawer,
  countPbActiveFilters,
  openPbFilterDrawer,
  pbIsCompact,
  updatePbFilterBadge,
  wirePbFilterDrawer,
} from './filterDrawer.js';
import {
  getPbProjects,
  getPbEngineers,
  getPbTasks,
  getPbLoadStats,
  getPbTeamLoadStats,
  getPbWorkReports,
} from '../../services/pb.js';
import {
  loadPbState,
  savePbState,
  openTaskEditorModal,
  savePbGanttMonth,
  stopPbIzvestajiSpeech,
  pbErrorMessage,
  syncPbModuleFilters,
} from './shared.js';
import { sortProjectsForPredmetPrioritet } from '../../services/projects.js';
import { renderPlanTab } from './planTab.js';
import { renderKanbanTab } from './kanbanTab.js';
import { renderGanttTab } from './ganttTab.js';
import { renderIzvestaji } from './izvestajiTab.js';
import { renderAnaliza } from './analizaTab.js';
import { renderPbPodesavanja } from './podesavanjaTab.js';

let teardownResize = null;
let _chromeSearchDebounceTimer = null;
let _pbMoreDocHandler = null;

/** Kompaktan chrome (tabovi, filteri) — širi prag od 767 zbog iOS / tablet / zoom. */
function mqCompactChrome() {
  return window.matchMedia('(max-width: 1024px)');
}

/* ── Inline SVG ikone (Lucide-compatible paths) ─── */
const IC_BACK = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>';
const IC_PLUS = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>';
const IC_MODULE = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>';

/** Isti princip kao Lokacije — emoji + label u tabu. */
const TAB_EMOJI = {
  plan:        '📋',
  kanban:      '🗂️',
  gantt:       '📈',
  izvestaji:   '📑',
  analiza:     '📊',
  saveti:      '📚',
  podesavanja: '⚙️',
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
  let teamLoadStats = [];
  let workReports = [];
  /** Pun skup zadataka (kad su projekat i inženjer „Svi”) — client filter bez novog fetch-a. */
  let allTasksCache = null;

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
    get teamLoadStats() { return teamLoadStats; },
    get moduleSearch() { return state.moduleSearch ?? ''; },
    get moduleShowDone() { return state.moduleShowDone ?? false; },
    onRefresh: () => {
      allTasksCache = null;
      return loadAll(true);
    },
    onFilterCountChange: planFilters => {
      updatePbFilterBadge(root, countPbActiveFilters(
        {
          project: state.activeProject,
          engineer: state.activeEngineer,
          search: state.moduleSearch,
        },
        planFilters,
      ));
    },
    isReadOnly: isPbReadOnly(),
  };

  function applyChromeTaskFilters(list) {
    let l = list || [];
    if (state.activeProject !== 'all') {
      l = l.filter(t => t.project_id === state.activeProject);
    }
    if (state.activeEngineer !== 'all') {
      l = l.filter(t => t.employee_id === state.activeEngineer);
    }
    return l;
  }

  function refreshFilterBadge(planFilters) {
    updatePbFilterBadge(root, countPbActiveFilters(
      {
        project: state.activeProject,
        engineer: state.activeEngineer,
        search: state.moduleSearch,
      },
      planFilters,
    ));
  }

  async function applyChromeFiltersAndRemount() {
    if (allTasksCache) {
      tasks = applyChromeTaskFilters(allTasksCache);
      refreshFilterBadge(loadPbState().activeTab === 'plan' ? {
        status: loadPbState().moduleStatus,
        vrsta: loadPbState().moduleVrsta,
        prioritet: loadPbState().modulePrioritet,
        problemOnly: loadPbState().moduleProblemOnly,
        unassignedOnly: loadPbState().moduleUnassignedOnly,
        showDone: loadPbState().moduleShowDone,
      } : undefined);
      paintChrome();
      await mountActiveTab();
      return;
    }
    await loadAll();
  }

  async function loadWorkReportsForMonth(year, month0) {
    const first = new Date(year, month0, 1);
    const last = new Date(year, month0 + 1, 0);
    const dateFrom = first.toISOString().slice(0, 10);
    const dateTo = last.toISOString().slice(0, 10);
    const wr = await getPbWorkReports({ dateFrom, dateTo, limit: 500 });
    workReports = Array.isArray(wr) ? wr : [];
  }

  async function loadAll(forceRefresh = false) {
    mergeStoredState();
    const body = root.querySelector('#pbTabBody');
    if (body) {
      body.classList.add('pb-tab-body--loading');
      body.setAttribute('aria-busy', 'true');
    }
    const fetchAllTasks = state.activeProject === 'all' && state.activeEngineer === 'all';
    const projFilter = state.activeProject === 'all' ? {} : { projectId: state.activeProject };
    const engFilter = state.activeEngineer === 'all' ? {} : { employeeId: state.activeEngineer };

    if (!forceRefresh && allTasksCache && !fetchAllTasks) {
      tasks = applyChromeTaskFilters(allTasksCache);
      paintChrome();
      await mountActiveTab();
      if (body) {
        body.classList.remove('pb-tab-body--loading');
        body.removeAttribute('aria-busy');
      }
      return;
    }

    /**
     * Jedan REST/RPC poziv ne sme da obrise ceo chrome — hvata grešku i loguje.
     * @param {string} label
     * @param {Promise<unknown>} promise
     */
    async function pbSafe(label, promise) {
      try {
        const data = await promise;
        return {
          ok: true,
          label,
          data: Array.isArray(data) ? data : [],
        };
      } catch (e) {
        console.error(`PB load failed [${label}]`, e);
        return { ok: false, label, data: [], err: e };
      }
    }

    try {
      const [rProj, rEng, rTasks] = await Promise.all([
        pbSafe('projects', getPbProjects()),
        pbSafe('engineers', getPbEngineers()),
        pbSafe('tasks', getPbTasks(fetchAllTasks ? {} : { ...projFilter, ...engFilter })),
      ]);

      projects = sortProjectsForPredmetPrioritet(rProj.data);
      engineers = rEng.data;
      if (fetchAllTasks && rTasks.ok) {
        allTasksCache = rTasks.data;
        tasks = allTasksCache;
      } else {
        allTasksCache = null;
        tasks = rTasks.data;
      }

      if (state.activeProject !== 'all' && !projects.some(p => p.id === state.activeProject)) {
        state.activeProject = 'all';
        savePbState(state);
      }

      if (state.activeEngineer !== 'all' && !engineers.some(en => en.id === state.activeEngineer)) {
        state.activeEngineer = 'all';
        savePbState(state);
      }

      let statsOk = true;
      try {
        loadStats = await getPbLoadStats(20);
      } catch (statsErr) {
        statsOk = false;
        console.error('PB load failed [loadStats]', statsErr);
        loadStats = [];
      }

      /* Team load — opcionalan, RPC možda nije migriran u staroj bazi. */
      try {
        teamLoadStats = await getPbTeamLoadStats(20);
      } catch (e) {
        console.error('PB load failed [teamLoadStats]', e);
        teamLoadStats = [];
      }

      const failedLabels = [rProj, rEng, rTasks].filter(x => !x.ok).map(x => x.label);
      if (!statsOk) failedLabels.push('loadStats');
      if (failedLabels.length) {
        const detail = failedLabels.join(', ');
        showToast(`Delimično učitano (${detail}). F12 → Console za detalje.`);
      }

      paintChrome();
      void mountActiveTab();
    } catch (err) {
      console.error('PB loadAll fatal', err);
      const msg = pbErrorMessage(err) || 'Greška pri učitavanju';
      if (body) {
        body.innerHTML = `<div class="pb-load-error"><p><strong>Učitavanje nije uspelo</strong></p><p class="pb-muted">${escHtml(msg)}</p><button type="button" class="btn btn-primary" id="pbRetryLoad">Pokušaj ponovo</button></div>`;
        body.querySelector('#pbRetryLoad')?.addEventListener('click', () => loadAll());
      }
    } finally {
      if (body) {
        body.classList.remove('pb-tab-body--loading');
        body.removeAttribute('aria-busy');
      }
    }
  }

  function buildContextFieldsHtml() {
    const searchValue = state.moduleSearch ?? '';
    return `
        <div class="pb-context-field">
          <span class="pb-context-label">Projekat</span>
          <select id="pbProjectSel" class="pb-context-select">
            <option value="all">Svi projekti</option>
            ${projects.map(p => `<option value="${escHtml(p.id)}" ${state.activeProject === p.id ? 'selected' : ''}>${escHtml(p.project_code)} — ${escHtml(p.project_name)}</option>`).join('')}
          </select>
        </div>
        <div class="pb-context-field">
          <span class="pb-context-label">Inženjer</span>
          <select id="pbEngineerSel" class="pb-context-select">
            <option value="all" ${state.activeEngineer === 'all' ? 'selected' : ''}>Svi inženjeri</option>
            ${engineers.map(en => `<option value="${escHtml(en.id)}" ${state.activeEngineer === en.id ? 'selected' : ''}>${escHtml(en.full_name)}</option>`).join('')}
          </select>
        </div>
        <div class="pb-context-field pb-context-field--grow">
          <span class="pb-context-label">Pretraga</span>
          <input type="search" id="pbChromeSearch" class="pb-context-search" placeholder="Pretraži po nazivu zadatka..." value="${escHtml(searchValue)}" />
        </div>`;
  }

  function wireChromeContextControls() {
    const onProject = e => {
      state.activeProject = e.target.value;
      savePbState(state);
      void applyChromeFiltersAndRemount();
    };
    const onEngineer = e => {
      state.activeEngineer = e.target.value || 'all';
      savePbState(state);
      void applyChromeFiltersAndRemount();
    };
    const onSearch = e => {
      state.moduleSearch = e.target.value || '';
      syncPbModuleFilters({ moduleSearch: state.moduleSearch });
      refreshFilterBadge(loadPbState().activeTab === 'plan' ? {
        status: loadPbState().moduleStatus,
        vrsta: loadPbState().moduleVrsta,
        prioritet: loadPbState().modulePrioritet,
        problemOnly: loadPbState().moduleProblemOnly,
        unassignedOnly: loadPbState().moduleUnassignedOnly,
        showDone: loadPbState().moduleShowDone,
      } : undefined);
      if (_chromeSearchDebounceTimer) clearTimeout(_chromeSearchDebounceTimer);
      _chromeSearchDebounceTimer = setTimeout(() => { void mountActiveTab(); }, 180);
    };
    for (const sel of root.querySelectorAll('#pbProjectSel')) sel.addEventListener('change', onProject);
    for (const sel of root.querySelectorAll('#pbEngineerSel')) sel.addEventListener('change', onEngineer);
    for (const inp of root.querySelectorAll('#pbChromeSearch')) inp.addEventListener('input', onSearch);
  }

  function paintChrome() {
    const hub = root.querySelector('#pbHubSlot');
    if (!hub) return;
    const auth = getAuth();
    const readOnly = isPbReadOnly();
    const contextFields = buildContextFieldsHtml();
    hub.innerHTML = `
      <div class="pb-chrome-pinned">
      ${readOnly ? '<div class="pb-readonly-banner" role="status">Samo pregled — izmene zadataka nisu dostupne za vašu ulogu.</div>' : ''}
      <div class="pb-chrome-nav" role="navigation" aria-label="Projektovanje navigacija">
        <div class="pb-topbar-start">
          <button type="button" class="pb-back-btn" id="pbBackBtn" aria-label="Nazad na module">
            ${IC_BACK}<span class="pb-back-btn-label">Moduli</span>
          </button>
          <div class="pb-topbar-brand">
            <div class="pb-module-icon" aria-hidden="true">${IC_MODULE}</div>
            <div class="pb-topbar-title">Projektovanje</div>
          </div>
          <button type="button" class="pb-open-filters-btn" id="pbOpenFilters" aria-expanded="false" aria-controls="pbFilterDrawer">
            Filteri <span class="pb-filter-badge" id="pbFilterBadge" hidden>0</span>
          </button>
        </div>
        <nav class="pb-tabs" role="tablist" aria-label="Projektni biro tabovi">
          ${pbTabBtn('plan', 'Plan', state.activeTab === 'plan')}
          ${pbTabBtn('kanban', 'Kanban', state.activeTab === 'kanban')}
          ${pbTabBtn('gantt', 'Gantt', state.activeTab === 'gantt')}
          ${pbTabBtn('izvestaji', 'Izveštaji', state.activeTab === 'izvestaji')}
          ${pbTabBtn('analiza', 'Analiza', state.activeTab === 'analiza')}
          ${pbTabBtn('saveti', 'Saveti', state.activeTab === 'saveti')}
          ${isAdmin() ? pbTabBtn('podesavanja', 'Podešavanja', state.activeTab === 'podesavanja') : ''}
        </nav>
        <div class="pb-topbar-end">
          <div class="pb-topbar-actions-pc">
            <button type="button" class="pb-theme-btn" id="pbThemeBtn" aria-label="Tema">🌙</button>
            ${auth.role ? `<span class="pb-role-badge">${escHtml(auth.role.toUpperCase())}</span>` : ''}
            ${canEditPbTasks() ? `<button type="button" class="pb-primary-btn pb-new-desktop" id="pbNewDesk">${IC_PLUS} Novi zadatak</button>` : ''}
            <button type="button" class="pb-logout-btn" id="pbLogoutBtn">Odjavi se</button>
          </div>
          <button type="button" class="pb-more-btn" id="pbMoreBtn" aria-haspopup="menu" aria-expanded="false" aria-controls="pbMoreMenu" aria-label="Meni">⋮</button>
          <div class="pb-more-menu" id="pbMoreMenu" role="menu" hidden>
            <button type="button" class="pb-more-menu-item" id="pbMoreTheme" role="menuitem">Tema</button>
            <button type="button" class="pb-more-menu-item" id="pbMoreRefresh" role="menuitem">Osveži podatke</button>
            ${auth.role ? `<span class="pb-more-menu-meta" role="presentation">${escHtml(auth.role.toUpperCase())}</span>` : ''}
            <button type="button" class="pb-more-menu-item" id="pbMoreLogout" role="menuitem">Odjavi se</button>
          </div>
        </div>
      </div>
      ${pbIsCompact(root) || state.activeTab === 'saveti' ? '' : `<div class="pb-context-row pb-context-row--inline">${contextFields}</div>`}
      </div>`;

    const drawerChrome = root.querySelector('#pbFilterDrawerChrome');
    if (drawerChrome) {
      drawerChrome.innerHTML = pbIsCompact(root) && state.activeTab !== 'saveti' ? contextFields : '';
    }
    root.classList.toggle('pb-module--saveti-tab', state.activeTab === 'saveti');
    const planSec = root.querySelector('#pbFilterDrawerPlanSection');
    if (planSec) planSec.hidden = state.activeTab !== 'plan';
    refreshFilterBadge(state.activeTab === 'plan' ? {
      status: loadPbState().moduleStatus,
      vrsta: loadPbState().moduleVrsta,
      prioritet: loadPbState().modulePrioritet,
      problemOnly: loadPbState().moduleProblemOnly,
      unassignedOnly: loadPbState().moduleUnassignedOnly,
      showDone: loadPbState().moduleShowDone,
    } : undefined);

    root.querySelector('#pbBackBtn')?.addEventListener('click', () => onBackToHub?.());
    root.querySelector('#pbThemeBtn')?.addEventListener('click', () => toggleTheme());
    root.querySelector('#pbLogoutBtn')?.addEventListener('click', async () => {
      await logout();
      onLogout?.();
    });
    const moreBtn = root.querySelector('#pbMoreBtn');
    const moreMenu = root.querySelector('#pbMoreMenu');
    const setMoreOpen = open => {
      if (!moreBtn || !moreMenu) return;
      moreMenu.hidden = !open;
      moreBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
    };
    moreBtn?.addEventListener('click', e => {
      e.stopPropagation();
      setMoreOpen(moreMenu?.hidden !== false);
    });
    root.querySelector('#pbMoreTheme')?.addEventListener('click', () => {
      toggleTheme();
      setMoreOpen(false);
    });
    root.querySelector('#pbMoreRefresh')?.addEventListener('click', () => {
      setMoreOpen(false);
      allTasksCache = null;
      void loadAll(true);
    });
    root.querySelector('#pbMoreLogout')?.addEventListener('click', async () => {
      setMoreOpen(false);
      await logout();
      onLogout?.();
    });
    if (!_pbMoreDocHandler) {
      _pbMoreDocHandler = e => {
        if (!moreMenu || moreMenu.hidden) return;
        if (e.target instanceof Node && moreBtn?.contains(e.target)) return;
        if (e.target instanceof Node && moreMenu.contains(e.target)) return;
        setMoreOpen(false);
      };
      document.addEventListener('click', _pbMoreDocHandler);
    }
    wireChromeContextControls();
    root.querySelector('#pbNewDesk')?.addEventListener('click', () => {
      openTaskEditorModal({
        task: null,
        projects,
        engineers,
        canEdit: canEditPbTasks(),
        onSaved: () => loadAll(true),
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
  }

  function pbTabBtn(id, label, active) {
    const em = TAB_EMOJI[id] || '';
    return `<button type="button" role="tab" class="pb-tab-btn ${active ? 'active' : ''}" data-pb-tab="${escHtml(id)}" aria-selected="${active}"><span class="pb-tab-icon" aria-hidden="true">${em}</span><span class="pb-tab-label">${escHtml(label)}</span></button>`;
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
    body.classList.toggle('pb-tab-body--saveti', tab === 'saveti');
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
      const savedZoom = loadPbState().ganttZoom;
      const viewZoom = savedZoom || (pbIsCompact(root) ? 'week' : 'day');
      renderGanttTab(body, {
        tasks,
        projects,
        engineers,
        search: state.moduleSearch ?? '',
        viewMonth,
        viewZoom,
        onViewMonthChange: d => {
          const x = new Date(d);
          x.setDate(1);
          x.setHours(0, 0, 0, 0);
          savePbGanttMonth(x.toISOString());
          mergeStoredState();
          void mountActiveTab();
        },
        onViewZoomChange: () => {
          /* savePbGanttZoom je već pozvan u ganttTab; samo re-mount taba. */
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
        canEdit: canEditPbWorkReports(),
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
    if (tab === 'saveti') {
      const { renderSavetiTab, refreshSavetiCategories } = await import('./savetiTab.js');
      renderSavetiTab(body, {
        projects,
        onRefresh: () => loadAll(true),
      });
      void refreshSavetiCategories();
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
  if (isPbReadOnly()) root.classList.add('pb-module--readonly');
  root.innerHTML = `
    <div id="pbHubSlot" class="pb-chrome"></div>
    <div id="pbFilterDrawer" class="pb-filter-drawer" hidden>
      <button type="button" class="pb-filter-drawer-backdrop" id="pbFilterDrawerBackdrop" aria-label="Zatvori filtere"></button>
      <div class="pb-filter-drawer-panel" role="dialog" aria-labelledby="pbFilterDrawerTitle">
        <header class="pb-filter-drawer-head">
          <h2 id="pbFilterDrawerTitle" class="pb-filter-drawer-title">Filteri</h2>
          <button type="button" class="pb-filter-drawer-close" id="pbFilterDrawerClose" aria-label="Zatvori">✕</button>
        </header>
        <div class="pb-filter-drawer-body">
          <section class="pb-filter-drawer-section" aria-label="Modul">
            <h3 class="pb-filter-drawer-sub">Modul</h3>
            <div id="pbFilterDrawerChrome" class="pb-filter-drawer-chrome"></div>
          </section>
          <section class="pb-filter-drawer-section" id="pbFilterDrawerPlanSection" hidden>
            <h3 class="pb-filter-drawer-sub">Plan</h3>
            <div id="pbFilterDrawerPlan"></div>
          </section>
        </div>
      </div>
    </div>
    <main id="pbTabBody" class="pb-tab-body pb-tab-body--loading" aria-busy="true">
      <div class="pb-loading-skel">
        <div class="pb-skel-line pb-skel-line--lg"></div>
        <div class="pb-skel-grid">
          <div class="pb-skel-card"></div><div class="pb-skel-card"></div><div class="pb-skel-card"></div>
        </div>
        <div class="pb-skel-line"></div><div class="pb-skel-line"></div>
      </div>
    </main>
    ${canEditPbTasks() ? '<button type="button" class="pb-fab" id="pbFab" aria-label="Novi zadatak">+</button>' : ''}
  `;

  const mm = mqCompactChrome();
  const applyMqClass = () => root.classList.toggle('pb-module--compact', mm.matches);
  applyMqClass();
  mm.addEventListener('change', () => {
    applyMqClass();
    paintChrome();
    void mountActiveTab();
  });
  teardownResize = () => mm.removeEventListener('change', applyMq);

  root.querySelector('#pbFab')?.addEventListener('click', () => {
    openTaskEditorModal({
      task: null,
      projects,
      engineers,
      canEdit: canEditPbTasks(),
      onSaved: () => loadAll(true),
    });
  });

  wirePbFilterDrawer(root);
  loadAll();
}

export function teardownPbModule() {
  try {
    teardownResize?.();
  } catch {
    /* ignore */
  }
  teardownResize = null;
  if (_pbMoreDocHandler) {
    document.removeEventListener('click', _pbMoreDocHandler);
    _pbMoreDocHandler = null;
  }
}
