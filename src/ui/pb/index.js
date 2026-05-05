/**
 * Projektni biro — root shell (tabs + Plan + Kanban + Gantt + Izveštaji + Analiza).
 * // TODO(PB5 opciono): dodatno razdvajanje Gantt header vs row render ako treba perf — docs/pb_review_report.md §4
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { logout } from '../../services/auth.js';
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
  engineerDotClass,
} from './shared.js';
import { renderPlanTab, countWorkdaysBetween } from './planTab.js';
import { renderKanbanTab } from './kanbanTab.js';
import { renderGanttTab } from './ganttTab.js';
import { renderIzvestaji } from './izvestajiTab.js';
import { renderAnaliza } from './analizaTab.js';
import { renderPbPodesavanja } from './podesavanjaTab.js';

let teardownResize = null;

function mqMobile() {
  return window.matchMedia('(max-width: 767px)');
}

function pbInitials(name) {
  const p = String(name || '').trim().split(/\s+/).filter(Boolean);
  if (!p.length) return '?';
  if (p.length === 1) return p[0].slice(0, 2).toUpperCase();
  return (p[0][0] + p[p.length - 1][0]).toUpperCase();
}

function pbDisplayName(user) {
  if (!user) return 'Korisnik';
  const em = String(user.email || '').trim();
  const local = em.includes('@') ? em.slice(0, em.indexOf('@')) : em;
  const spaced = local.replace(/[._-]+/g, ' ').trim();
  if (!spaced) return em || 'Korisnik';
  return spaced.split(/\s+/).map(s => s.charAt(0).toUpperCase() + s.slice(1).toLowerCase()).join(' ');
}

function pbRoleSubtitle(role) {
  const m = {
    admin: 'Administrator',
    leadpm: 'Rukovodilac biroa',
    pm: 'Projektni menadžer',
    menadzment: 'Menadžment',
    hr: 'Kadrovska',
    viewer: 'Korisnik',
    magacioner: 'Magacioner',
    cnc_operater: 'CNC operater',
  };
  return m[role] || 'Korisnik';
}

/** Kolone kao na ekranu Plan (bez kolone akcija). */
function pbTasksToCsv(rows) {
  const esc = v => {
    const s = v == null ? '' : String(v);
    if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
    return s;
  };
  const header = ['#', 'Naziv zadatka', 'Projekat', 'Inženjer', 'Vrsta', 'Datum početka plan', 'Datum završetka plan', 'Datum početka ostvareno', 'Datum završetka ostvareno', 'Trajanje (rd)', 'Status', '%', 'Prioritet', 'Norma'];
  const lines = [header.join(',')];
  rows.forEach((t, i) => {
    const proj = [t.project_code, t.project_name].filter(Boolean).join(' ');
    const wd = countWorkdaysBetween(t.datum_pocetka_plan, t.datum_zavrsetka_plan);
    lines.push([
      i + 1,
      t.naziv,
      proj,
      t.engineer_name,
      t.vrsta,
      (t.datum_pocetka_plan || '').slice(0, 10),
      (t.datum_zavrsetka_plan || '').slice(0, 10),
      (t.datum_pocetka_real || '').slice(0, 10),
      (t.datum_zavrsetka_real || '').slice(0, 10),
      wd != null ? wd : '',
      t.status,
      t.procenat_zavrsenosti,
      t.prioritet,
      t.norma_sati_dan,
    ].map(esc).join(','));
  });
  return lines.join('\r\n');
}

const PB_ICON = {
  fileText: '<svg class="pb-tab-svg" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/></svg>',
  columns: '<svg class="pb-tab-svg" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="18" height="18" x="3" y="3" rx="2"/><path d="M12 3v18"/></svg>',
  barChart: '<svg class="pb-tab-svg" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 20V10"/><path d="M18 20V4"/><path d="M6 20v-4"/></svg>',
  fileBarChart: '<svg class="pb-tab-svg" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M15 18a3 3 0 1 0-6 0"/><path d="M18 12h-5"/><path d="M21.66 19a2 2 0 0 1-3.32 1"/><path d="M10 12H6a2 2 0 0 0-2 2v8"/><path d="M4 22h16"/></svg>',
  trending: '<svg class="pb-tab-svg" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/></svg>',
  settings: '<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>',
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
  let chipSearchFilter = '';
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
        getPbTasks({
          ...projFilter,
          ...engFilter,
        }),
        getPbLoadStats(30),
      ]);
      projects = p;
      engineers = e;
      if (
        state.activeEngineer !== 'all'
        && !engineers.some(en => en.id === state.activeEngineer)
      ) {
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
    const displayName = pbDisplayName(auth.user);
    const initials = pbInitials(displayName);
    const roleLbl = (auth.role || '').toUpperCase();
    const canPbEdit = canEditProjektniBiro();

    hub.innerHTML = `
      <header class="kadrovska-header pb-header pb-header--minimal">
        <div class="kadrovska-header-left">
          <button type="button" class="btn-hub-back" id="pbBackBtn" aria-label="Nazad na module"><span class="back-icon" aria-hidden="true">←</span><span>Moduli</span></button>
        </div>
        <div class="kadrovska-header-right">
          <span class="role-indicator ${auth.role === 'admin' ? 'role-admin' : ''}" id="pbRoleBadge">${escHtml(roleLbl)}</span>
          <button type="button" class="hub-logout" id="pbLogoutBtn">Odjavi se</button>
        </div>
      </header>
      <div class="pb-page-shell">
        <section class="pb-page-header-card" aria-label="Kontekst stranice">
          <div class="pb-page-header-row">
            <div class="pb-page-header-lead">
              <div class="pb-page-icon" aria-hidden="true">${PB_ICON.settings}</div>
              <div>
                <h1 class="pb-page-title">Projektni biro — plan rada</h1>
                <p class="pb-page-sub">Projektni biro</p>
              </div>
            </div>
            <div class="pb-page-header-actions">
              <label class="pb-field-compact"><span class="pb-field-lbl">Projekat:</span>
                <select id="pbProjectSel" class="pb-select">
                  <option value="all">Svi projekti</option>
                  ${projects.map(p => `<option value="${escHtml(p.id)}" ${state.activeProject === p.id ? 'selected' : ''}>${escHtml(p.project_code)} — ${escHtml(p.project_name)}</option>`).join('')}
                </select>
              </label>
              ${canPbEdit ? `<button type="button" class="btn btn-primary pb-new-header" id="pbNewHeader">+ Novi zadatak</button>` : ''}
              <button type="button" class="btn btn-outline pb-csv-btn" id="pbCsvBtn">↓ CSV</button>
              <div class="pb-user-pill">
                <span class="pb-user-avatar" aria-hidden="true">${escHtml(initials)}</span>
                <span class="pb-user-meta">
                  <span class="pb-user-name">${escHtml(displayName)}</span>
                  <span class="pb-user-role">${escHtml(pbRoleSubtitle(auth.role))}</span>
                </span>
              </div>
            </div>
          </div>
        </section>
        <div class="pb-engineer-toolbar">
          <div class="pb-eng-search-wrap">
            <span class="pb-eng-search-icon" aria-hidden="true"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg></span>
            <input type="search" class="pb-eng-search" id="pbEngSearch" placeholder="Inženjer…" value="${escHtml(chipSearchFilter)}" autocomplete="off" />
          </div>
          <div class="pb-chip-scroll" id="pbChipHost"></div>
        </div>
        <nav class="kadrovska-tabs pb-subtabs" role="tablist" aria-label="Projektni biro tabovi">
          ${pbTabBtn('plan', 'Plan', PB_ICON.fileText, state.activeTab === 'plan')}
          ${pbTabBtn('kanban', 'Kanban', PB_ICON.columns, state.activeTab === 'kanban')}
          ${pbTabBtn('gantt', 'Gantt', PB_ICON.barChart, state.activeTab === 'gantt')}
          ${pbTabBtn('izvestaji', 'Izveštaji', PB_ICON.fileBarChart, state.activeTab === 'izvestaji')}
          ${pbTabBtn('analiza', 'Analiza', PB_ICON.trending, state.activeTab === 'analiza')}
          ${isAdmin() ? pbTabBtn('podesavanja', 'Podešavanja', PB_ICON.settings, state.activeTab === 'podesavanja') : ''}
        </nav>
      </div>`;

    root.querySelector('#pbBackBtn')?.addEventListener('click', () => onBackToHub?.());
    root.querySelector('#pbLogoutBtn')?.addEventListener('click', async () => {
      await logout();
      onLogout?.();
    });

    root.querySelector('#pbProjectSel')?.addEventListener('change', e => {
      state.activeProject = e.target.value;
      savePbState(state);
      loadAll();
    });

    const openNew = () => {
      openTaskEditorModal({
        task: null,
        projects,
        engineers,
        canEdit: canPbEdit,
        onSaved: () => loadAll(),
      });
    };
    root.querySelector('#pbNewHeader')?.addEventListener('click', openNew);

    root.querySelector('#pbCsvBtn')?.addEventListener('click', () => {
      const csv = pbTasksToCsv(tasks);
      const blob = new Blob([`\ufeff${csv}`], { type: 'text/csv;charset=utf-8' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `projektni-biro-zadaci-${new Date().toISOString().slice(0, 10)}.csv`;
      a.click();
      URL.revokeObjectURL(a.href);
    });

    root.querySelector('#pbEngSearch')?.addEventListener('input', e => {
      chipSearchFilter = e.target.value;
      renderEngineerChips(root.querySelector('#pbChipHost'), state);
    });

    root.querySelectorAll('.pb-subtab').forEach(btn => {
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
    const q = chipSearchFilter.trim().toLowerCase();
    const list = !q
      ? engineers
      : engineers.filter(en => String(en.full_name || '').toLowerCase().includes(q));
    host.innerHTML = `
      <button type="button" class="pb-chip ${st.activeEngineer === 'all' ? 'active' : ''}" data-eng="all" title="Svi mašinski projektanti">Svi</button>
      ${list.map(en => `
        <button type="button" class="pb-chip ${st.activeEngineer === en.id ? 'active' : ''}" data-eng="${escHtml(en.id)}">
          <span class="pb-chip-dot ${engineerDotClass(en.full_name)}" aria-hidden="true"></span>
          <span>${escHtml(en.full_name)}</span>
        </button>
      `).join('')}
    `;
    host.querySelectorAll('[data-eng]').forEach(btn => {
      btn.addEventListener('click', () => {
        st.activeEngineer = btn.getAttribute('data-eng') || 'all';
        savePbState(st);
        renderEngineerChips(host, st);
        loadAll();
      });
    });
  }

  function pbTabBtn(id, label, iconHtml, active) {
    return `<button type="button" role="tab" class="kadrovska-tab pb-subtab${active ? ' active' : ''}" data-pb-tab="${escHtml(id)}" aria-selected="${active}">
      <span class="pb-tab-ic" aria-hidden="true">${iconHtml}</span>
      <span class="pb-tab-lbl">${escHtml(label)}</span>
    </button>`;
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
      let viewMonth = state.ganttStartDate
        ? new Date(state.ganttStartDate)
        : new Date();
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
    <div id="pbHubSlot"></div>
    <main id="pbTabBody" class="pb-tab-body pb-tab-body--loading" aria-busy="true">
      <div class="pb-loading-skel">
        <div class="pb-skel-line pb-skel-line--lg"></div>
        <div class="pb-skel-grid">
          <div class="pb-skel-card"></div><div class="pb-skel-card"></div><div class="pb-skel-card"></div>
        </div>
        <div class="pb-skel-line"></div><div class="pb-skel-line"></div>
      </div>
    </main>
    ${canEditProjektniBiro() ? `<button type="button" class="pb-fab" id="pbFab" aria-label="Novi zadatak">+</button>` : ''}
  `;

  const mm = mqMobile();
  const applyMq = () => {
    root.classList.toggle('pb-module--mobile', mm.matches);
  };
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
