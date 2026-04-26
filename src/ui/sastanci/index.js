/**
 * Sastanci modul — root shell sa tabovima.
 *
 * Tabovi:
 *   - dashboard      ✅ S1: Pregled (statistike + nadolazeći + akcije koje kasne)
 *   - pm-teme        ✅ S1: PM teme (predlog → usvojeno)
 *   - akcioni-plan   ✅ S1: Akcioni plan (svi otvoreni zadaci, filteri)
 *   - sastanci       ✅ S1+S2: Lista svih sastanaka (sedmični + projektni)
 *   - arhiva         ✅ S3: Arhivirani (zaključani) sastanci sa zapisnicima
 *
 * Kreiranje sastanka i otvaranje pojedinačnog sastanka su modal-ovi —
 * ne posebni screen-ovi.
 */

import { escHtml } from '../../lib/dom.js';
import { toggleTheme } from '../../lib/theme.js';
import { logout } from '../../services/auth.js';
import { getAuth, canEdit, canEditSastanci } from '../../state/auth.js';
import { getSastanciState, setActiveTab } from '../../state/sastanci.js';
import { navigateToAppPath } from '../router.js';
import { buildSastanakDetaljPath } from '../../lib/appPaths.js';

import { renderDashboardTab, teardownDashboardTab } from './dashboardTab.js';
import { renderPmTemeTab, teardownPmTemeTab } from './pmTemeTab.js';
import { renderPregledPoProjektuTab, teardownPregledPoProjektuTab } from './pregledPoProjektuTab.js';
import { renderAkcioniPlanTab, teardownAkcioniPlanTab } from './akcioniPlanTab.js';
import { renderSastanciTab, teardownSastanciTab } from './sastanciTab.js';
import { renderArhivaTab, teardownArhivaTab } from './arhivaTab.js';
import { renderPodesavanjaNotifikacijaTab, teardownPodesavanjaNotifikacijaTab } from './podesavanjaNotifikacijaTab.js';
import { mountSastanciFab, unmountSastanciFab } from './quickAddTemaButton.js';
import { renderSastanakDetalj, teardownSastanakDetalj } from './sastanakDetalj/index.js';

const TABS = [
  { id: 'dashboard',         label: 'Pregled',           icon: '📊', desc: 'Statistike i nadolazeći sastanci.' },
  { id: 'sastanci',          label: 'Sastanci',          icon: '📅', desc: 'Lista svih sastanaka.' },
  { id: 'pm-teme',           label: 'PM teme',           icon: '💡', desc: 'Predlozi PM-ova za dnevni red.' },
  { id: 'pregled-projekti',  label: 'Po projektu',       icon: '🎯', desc: 'Pregled tema po projektu sa master rangom (admin).' },
  { id: 'akcioni-plan',      label: 'Akcioni plan',      icon: '✅', desc: 'Otvorene akcije sa rokovima.' },
  { id: 'arhiva',            label: 'Arhiva',            icon: '🗃', desc: 'Zaključani sastanci i zapisnici.' },
  { id: 'podesavanja-notif', label: 'Podešavanja',       icon: '⚙️',  desc: 'Podešavanja email notifikacija.' },
];

/**
 * Navigacija na detalj stranicu sastanka (menja URL i renderuje detalj).
 * @param {string} sastanakId UUID
 * @param {string} [tab] 'pripremi'|'zapisnik'|'akcije'|'arhiva'
 */
export function navigateToSastanakDetalj(sastanakId, tab) {
  navigateToAppPath(buildSastanakDetaljPath(sastanakId, tab || null));
}

export function renderSastanciModule(mountEl, { onBackToHub, onLogout, sastanakId = null, sastanciTab = null } = {}) {
  const auth = getAuth();
  const editor = canEdit();
  const state = getSastanciState();

  // Deep link na specifičan tab (npr. /sastanci/podesavanja-notifikacija)
  if (sastanciTab && TABS.some(t => t.id === sastanciTab)) {
    setActiveTab(sastanciTab);
  }

  /* Deep link na /sastanci/<uuid> — prikaži detalj, bez main tab strip-a */
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
      onBack: () => {
        history.back();
      },
      onNavigate: (path) => navigateToAppPath(path),
    });
    return;
  }

  mountEl.innerHTML = '';

  const container = document.createElement('div');
  container.className = 'kadrovska-section';
  container.id = 'module-sastanci';
  container.style.display = 'block';

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

    <nav class="kadrovska-tabs" role="tablist" aria-label="Sastanci tabovi">
      ${TABS.map(t => `
        <button type="button" role="tab"
          class="kadrovska-tab${t.id === state.activeTab ? ' is-active' : ''}"
          data-tab="${t.id}"
          aria-selected="${t.id === state.activeTab ? 'true' : 'false'}">
          <span aria-hidden="true">${t.icon}</span> ${escHtml(t.label)}
        </button>
      `).join('')}
    </nav>

    <main class="kadrovska-tabpanel sast-tabpanel" id="sastTabBody"></main>
  `;

  mountEl.appendChild(container);

  mountSastanciFab(container, {
    getActiveTab: () => getSastanciState().activeTab,
    canEdit: editor,
  });

  /* Wire događaji */
  container.querySelector('#sastBackBtn').addEventListener('click', () => onBackToHub?.());
  container.querySelector('#sastThemeToggle').addEventListener('click', toggleTheme);
  container.querySelector('#sastLogoutBtn').addEventListener('click', async () => {
    await logout();
    onLogout?.();
  });

  container.querySelectorAll('button[data-tab]').forEach(btn => {
    btn.addEventListener('click', () => {
      const tabId = btn.dataset.tab;
      if (tabId === state.activeTab) return;
      teardownActiveTab();
      setActiveTab(tabId);
      renderSastanciModule(mountEl, { onBackToHub, onLogout });
    });
  });

  renderTabBody(container.querySelector('#sastTabBody'), { canEdit: editor });
}

function renderTabBody(host, { canEdit }) {
  const state = getSastanciState();

  if (state.activeTab === 'dashboard') {
    renderDashboardTab(host, { canEdit, onJumpToTab: (tab) => {
      teardownActiveTab();
      setActiveTab(tab);
      const mountEl = host.parentElement?.parentElement;
      if (mountEl) renderSastanciModule(mountEl, {});
    }});
    return;
  }
  if (state.activeTab === 'sastanci') {
    renderSastanciTab(host, { canEdit });
    return;
  }
  if (state.activeTab === 'pm-teme') {
    renderPmTemeTab(host, { canEdit });
    return;
  }
  if (state.activeTab === 'pregled-projekti') {
    renderPregledPoProjektuTab(host);
    return;
  }
  if (state.activeTab === 'akcioni-plan') {
    renderAkcioniPlanTab(host, { canEdit });
    return;
  }
  if (state.activeTab === 'arhiva') {
    renderArhivaTab(host, { canEdit });
    return;
  }
  if (state.activeTab === 'podesavanja-notif') {
    renderPodesavanjaNotifikacijaTab(host);
    return;
  }
}

function teardownActiveTab() {
  const state = getSastanciState();
  if (state.activeTab === 'dashboard') teardownDashboardTab();
  if (state.activeTab === 'sastanci') teardownSastanciTab();
  if (state.activeTab === 'pm-teme') teardownPmTemeTab();
  if (state.activeTab === 'pregled-projekti') teardownPregledPoProjektuTab();
  if (state.activeTab === 'akcioni-plan') teardownAkcioniPlanTab();
  if (state.activeTab === 'arhiva') teardownArhivaTab();
  if (state.activeTab === 'podesavanja-notif') teardownPodesavanjaNotifikacijaTab();
}

export function teardownSastanciModule() {
  teardownSastanakDetalj();
  unmountSastanciFab();
  teardownActiveTab();
}
