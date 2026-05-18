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

function mqMobile() {
  return window.matchMedia('(max-width: 767px)');
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
        pbSafe('tasks', getPbTasks({ ...projFilter, ...engFilter })),
      ]);

      projects = sortProjectsForPredmetPrioritet(rProj.data);
      engineers = rEng.data;
      tasks = rTasks.data;

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

  function paintChrome() {
    const hub = root.querySelector('#pbHubSlot');
    if (!hub) return;
    const auth = getAuth();
    const searchValue = state.moduleSearch ?? '';
    hub.innerHTML = `
      <div class="pb-chrome-pinned">
      <header class="pb-topbar">
        <div class="pb-topbar-start">
          <button type="button" class="pb-back-btn" id="pbBackBtn" aria-label="Nazad na module">
            ${IC_BACK} Moduli
          </button>
          <div class="pb-topbar-brand">
            <div class="pb-module-icon" aria-hidden="true">${IC_MODULE}</div>
            <div class="pb-topbar-title">Projektovanje</div>
          </div>
        </div>
        <nav class="pb-tabs" role="tablist" aria-label="Projektni biro tabovi">
          ${pbTabBtn('plan', 'Plan', state.activeTab === 'plan')}
          ${pbTabBtn('kanban', 'Kanban', state.activeTab === 'kanban')}
          ${pbTabBtn('gantt', 'Gantt', state.activeTab === 'gantt')}
          ${pbTabBtn('izvestaji', 'Izveštaji', state.activeTab === 'izvestaji')}
          ${pbTabBtn('analiza', 'Analiza', state.activeTab === 'analiza')}
          ${isAdmin() ? pbTabBtn('podesavanja', 'Podešavanja', state.activeTab === 'podesavanja') : ''}
        </nav>
        <div class="pb-topbar-end">
          <button type="button" class="pb-theme-btn" id="pbThemeBtn" aria-label="Tema">🌙</button>
          ${auth.role ? `<span class="pb-role-badge">${escHtml(auth.role.toUpperCase())}</span>` : ''}
          ${canEditProjektniBiro() ? `<button type="button" class="pb-primary-btn pb-new-desktop" id="pbNewDesk">${IC_PLUS} Novi zadatak</button>` : ''}
          <button type="button" class="pb-logout-btn" id="pbLogoutBtn">Odjavi se</button>
        </div>
      </header>
      <div class="pb-context-row">
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
        </div>
      </div>
      </div>`;

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
    root.querySelector('#pbEngineerSel')?.addEventListener('change', e => {
      state.activeEngineer = e.target.value || 'all';
      savePbState(state);
      loadAll();
    });
    root.querySelector('#pbChromeSearch')?.addEventListener('input', e => {
      // Search se filtrira klijent-side u Plan/Kanban/Gantt tabu — ne mora loadAll().
      state.moduleSearch = e.target.value || '';
      syncPbModuleFilters({ moduleSearch: state.moduleSearch });
      if (_chromeSearchDebounceTimer) clearTimeout(_chromeSearchDebounceTimer);
      _chromeSearchDebounceTimer = setTimeout(() => {
        void mountActiveTab();
      }, 180);
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
      const viewZoom = loadPbState().ganttZoom || 'day';
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
