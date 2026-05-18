/**
 * Sastanci modul — root shell.
 * Glavni tabovi + admin meni (⚙).
 */

import { escHtml } from '../../lib/dom.js';
import { toggleTheme } from '../../lib/theme.js';
import { logout } from '../../services/auth.js';
import { getAuth, canEdit } from '../../state/auth.js';
import { getSastanciState, setActiveTab } from '../../state/sastanci.js';
import { navigateToAppPath } from '../router.js';
import { buildSastanakDetaljPath } from '../../lib/appPaths.js';
import { mountSastanciFab, unmountSastanciFab } from './quickAddTemaButton.js';
import { renderSastanakDetalj, teardownSastanakDetalj } from './sastanakDetalj/index.js';

const MAIN_TABS = [
  { id: 'dashboard', label: 'Pregled', icon: '📊' },
  { id: 'sastanci', label: 'Sastanci', icon: '📅' },
  { id: 'moj-rad', label: 'Moj rad', icon: '👤' },
  { id: 'akcioni-plan', label: 'Akcioni plan', icon: '✅' },
];

const ADMIN_TABS = [
  { id: 'pm-teme', label: 'PM teme', icon: '💡' },
  { id: 'pregled-projekti', label: 'Po projektu', icon: '🎯' },
  { id: 'draft-teme', label: 'Draft teme', icon: '📝' },
  { id: 'sabloni', label: 'Šabloni', icon: '📋' },
  { id: 'arhiva', label: 'Arhiva', icon: '🗃' },
  { id: 'podesavanja-notif', label: 'Podešavanja', icon: '⚙️' },
];

const ALL_TAB_IDS = new Set([...MAIN_TABS, ...ADMIN_TABS].map(t => t.id));

const TAB_LOADERS = {
  dashboard: () => import('./dashboardTab.js'),
  sastanci: () => import('./sastanciTab.js'),
  'moj-rad': () => import('./mojRadTab.js'),
  'akcioni-plan': () => import('./akcioniPlanTab.js'),
  'pm-teme': () => import('./pmTemeTab.js'),
  'pregled-projekti': () => import('./pregledPoProjektuTab.js'),
  'draft-teme': () => import('./draftTemePanel.js'),
  sabloni: () => import('./sabloniTab.js'),
  arhiva: () => import('./arhivaTab.js'),
  'podesavanja-notif': () => import('./podesavanjaNotifikacijaTab.js'),
};

const TEARDOWN = {
  dashboard: (m) => m.teardownDashboardTab?.(),
  sastanci: (m) => m.teardownSastanciTab?.(),
  'moj-rad': (m) => m.teardownMojRadTab?.(),
  'akcioni-plan': (m) => m.teardownAkcioniPlanTab?.(),
  'pm-teme': (m) => m.teardownPmTemeTab?.(),
  'pregled-projekti': (m) => m.teardownPregledPoProjektuTab?.(),
  'draft-teme': (m) => m.teardownDraftTemePanel?.(),
  sabloni: (m) => m.teardownSabloniTab?.(),
  arhiva: (m) => m.teardownArhivaTab?.(),
  'podesavanja-notif': (m) => m.teardownPodesavanjaNotifikacijaTab?.(),
};

let loadedTabModule = null;
let loadedTabId = null;

export function navigateToSastanakDetalj(sastanakId, tab) {
  navigateToAppPath(buildSastanakDetaljPath(sastanakId, tab || null));
}

export function renderSastanciModule(mountEl, { onBackToHub, onLogout, sastanakId = null, sastanciTab = null } = {}) {
  const auth = getAuth();
  const editor = canEdit();
  const state = getSastanciState();

  if (sastanciTab && ALL_TAB_IDS.has(sastanciTab)) {
    setActiveTab(sastanciTab);
  }

  if (sastanakId) {
    mountEl.innerHTML = '';
    const container = document.createElement('div');
    container.className = 'kadrovska-section';
    container.id = 'module-sastanci';
    container.style.display = 'block';
    mountEl.appendChild(container);
    document.body.classList.add('kadrovska-active', 'module-sastanci');
    renderSastanakDetalj(container, {
      sastanakId,
      onBack: () => history.back(),
      onNavigate: (path) => navigateToAppPath(path),
    });
    return;
  }

  mountEl.innerHTML = '';
  const container = document.createElement('div');
  container.className = 'kadrovska-section';
  container.id = 'module-sastanci';
  container.style.display = 'block';

  const isAdminTab = ADMIN_TABS.some(t => t.id === state.activeTab);

  container.innerHTML = `
    <header class="kadrovska-header">
      <div class="kadrovska-header-left">
        <button class="btn-hub-back" id="sastBackBtn" title="Nazad na listu modula" aria-label="Nazad na module">
          <span class="back-icon" aria-hidden="true">←</span>
          <span>Moduli</span>
        </button>
        <div class="kadrovska-title">
          <span class="ktitle-mark" aria-hidden="true">📅</span>
          <span>Sastanci</span>
        </div>
      </div>
      <div class="kadrovska-header-right">
        <div class="sast-admin-wrap">
          <button type="button" class="sast-admin-gear" id="sastAdminGear" title="Admin meni" aria-haspopup="true" aria-expanded="false">⚙</button>
          <div class="sast-admin-menu" id="sastAdminMenu" hidden>
            ${ADMIN_TABS.map(t => `
              <button type="button" class="sast-admin-menu-item${t.id === state.activeTab ? ' is-active' : ''}" data-tab="${t.id}">
                <span aria-hidden="true">${t.icon}</span> ${escHtml(t.label)}
              </button>
            `).join('')}
          </div>
        </div>
        <button class="theme-toggle" id="sastThemeToggle" title="Promeni temu" aria-label="Promeni temu">
          <span class="theme-icon-dark">🌙</span>
          <span class="theme-icon-light">☀️</span>
        </button>
        <div class="hub-user">
          <span class="hub-user-email">${escHtml(auth.user?.email || '—')}</span>
          <span class="hub-user-role">${escHtml(auth.role)}${editor ? '' : ' · read-only'}</span>
        </div>
        <button class="hub-logout" id="sastLogoutBtn">Odjavi se</button>
      </div>
    </header>

    <nav class="kadrovska-tabs sast-main-tabs" role="tablist" aria-label="Sastanci">
      ${MAIN_TABS.map(t => `
        <button type="button" role="tab"
          class="kadrovska-tab${!isAdminTab && t.id === state.activeTab ? ' is-active' : ''}"
          data-tab="${t.id}"
          aria-selected="${!isAdminTab && t.id === state.activeTab ? 'true' : 'false'}">
          <span aria-hidden="true">${t.icon}</span> ${escHtml(t.label)}
        </button>
      `).join('')}
      ${isAdminTab ? `<span class="sast-admin-tab-hint">Admin: ${escHtml(ADMIN_TABS.find(t => t.id === state.activeTab)?.label || '')}</span>` : ''}
    </nav>

    <main class="kadrovska-tabpanel sast-tabpanel" id="sastTabBody"></main>
  `;

  mountEl.appendChild(container);

  mountSastanciFab(container, {
    getActiveTab: () => getSastanciState().activeTab,
    canEdit: editor,
  });

  container.querySelector('#sastBackBtn').addEventListener('click', () => onBackToHub?.());
  container.querySelector('#sastThemeToggle').addEventListener('click', toggleTheme);
  container.querySelector('#sastLogoutBtn').addEventListener('click', async () => {
    await logout();
    onLogout?.();
  });

  const gear = container.querySelector('#sastAdminGear');
  const menu = container.querySelector('#sastAdminMenu');
  gear?.addEventListener('click', (e) => {
    e.stopPropagation();
    const open = menu.hidden;
    menu.hidden = !open;
    gear.setAttribute('aria-expanded', open ? 'true' : 'false');
  });
  if (menu) {
    const closeMenu = (e) => {
      if (menu.contains(e.target) || gear?.contains(e.target)) return;
      menu.hidden = true;
      gear?.setAttribute('aria-expanded', 'false');
    };
    setTimeout(() => document.addEventListener('click', closeMenu), 0);
  }

  container.querySelectorAll('.sast-admin-menu-item').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const tabId = btn.dataset.tab;
      menu.hidden = true;
      if (tabId === state.activeTab) return;
      void switchTab(mountEl, tabId, { onBackToHub, onLogout, canEdit: editor });
    });
  });

  container.querySelectorAll('.sast-main-tabs [data-tab]').forEach(btn => {
    btn.addEventListener('click', () => {
      const tabId = btn.dataset.tab;
      if (tabId === state.activeTab) return;
      void switchTab(mountEl, tabId, { onBackToHub, onLogout, canEdit: editor });
    });
  });

  void renderTabBody(container.querySelector('#sastTabBody'), { canEdit: editor });
}

async function switchTab(mountEl, tabId, ctx) {
  await teardownActiveTab();
  setActiveTab(tabId);
  renderSastanciModule(mountEl, ctx);
}

async function renderTabBody(host, { canEdit }) {
  const tabId = getSastanciState().activeTab;
  const loader = TAB_LOADERS[tabId];
  if (!loader || !host) return;

  if (loadedTabId !== tabId) {
    await teardownActiveTab();
    loadedTabModule = await loader();
    loadedTabId = tabId;
  }

  const m = loadedTabModule;
  if (tabId === 'dashboard') {
    await m.renderDashboardTab(host, { canEdit, onJumpToTab: (t) => {
      setActiveTab(t);
      const mountEl = host.closest('#module-sastanci')?.parentElement;
      if (mountEl) renderSastanciModule(mountEl, { canEdit });
    }});
  } else if (tabId === 'sastanci') await m.renderSastanciTab(host, { canEdit });
  else if (tabId === 'moj-rad') await m.renderMojRadTab(host, { canEdit });
  else if (tabId === 'akcioni-plan') await m.renderAkcioniPlanTab(host, { canEdit });
  else if (tabId === 'pm-teme') await m.renderPmTemeTab(host, { canEdit });
  else if (tabId === 'pregled-projekti') await m.renderPregledPoProjektuTab(host);
  else if (tabId === 'draft-teme') await m.renderDraftTemePanel(host, { canEdit });
  else if (tabId === 'sabloni') await m.renderSabloniTab(host, { canEdit });
  else if (tabId === 'arhiva') await m.renderArhivaTab(host, { canEdit });
  else if (tabId === 'podesavanja-notif') await m.renderPodesavanjaNotifikacijaTab(host);
}

async function teardownActiveTab() {
  const tabId = loadedTabId;
  if (!tabId || !loadedTabModule) return;
  const fn = TEARDOWN[tabId];
  fn?.(loadedTabModule);
  loadedTabId = null;
  loadedTabModule = null;
}

export function teardownSastanciModule() {
  teardownSastanakDetalj();
  unmountSastanciFab();
  void teardownActiveTab();
}
