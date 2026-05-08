/**
 * Kadrovska modul — root render + tab dispatcher.
 *
 * Faza 4 milestone (ovaj fajl):
 *   - Header (back/title/theme/role/logout) prikazan ispravno
 *   - Tab strip sa 6 tabova, persist-uje aktivni tab u localStorage
 *     pod istim ključem kao legacy (`pm_kadrovska_active_tab_v1`).
 *   - Zaposleni tab je 100% funkcionalan (CRUD + modal + filteri)
 *   - Ostali tabovi su "coming soon" placeholder dok ne stignu u F4.x
 *
 * Mount:
 *   import { renderKadrovskaModule } from './ui/kadrovska/index.js';
 *   renderKadrovskaModule(rootEl);
 */

import { canAccessKadrovska, canAccessSalary, canManageVacationRequests } from '../../state/auth.js';
import { showToast } from '../../lib/dom.js';
import { logout } from '../../services/auth.js';
import { toggleTheme } from '../../lib/theme.js';
import { SESSION_KEYS } from '../../lib/constants.js';
import { ssSet } from '../../lib/storage.js';
import {
  installKadrAutoFlush,
  countKadrPending,
  flushKadrPending,
} from '../../services/kadrOfflineQueue.js';

import {
  kadrovskaHeaderHtml,
  kadrTabsHtml,
  KADROVSKA_TAB_DEFS,
} from './shared.js';
import { renderKadrovskaGridToolbarHtml, renderGridPanelBody, wireGridTab } from './gridTab.js';
import { kadrovskaState, setActiveKadrTab } from '../../state/kadrovska.js';
import {
  renderEmployeesTab,
  wireEmployeesTab,
} from './employeesTab.js';
import {
  renderWorkHoursTab,
  wireWorkHoursTab,
} from './workHoursTab.js';
import {
  renderContractsTab,
  wireContractsTab,
} from './contractsTab.js';
import {
  renderReportsTab,
  wireReportsTab,
} from './reportsTab.js';
import {
  renderVacationTab,
  wireVacationTab,
} from './vacationTab.js';
import {
  renderSalaryTab,
  wireSalaryTab,
} from './salaryTab.js';
import {
  renderHrNotificationsTab,
  wireHrNotificationsTab,
} from './hrNotificationsTab.js';
import { renderComingSoonTab } from './comingSoon.js';
import { renderAbsencesTab, wireAbsencesTab } from './absencesTab.js';
import { renderVacationRequestsTab, wireVacationRequestsTab, refreshVacReqBadge } from './vacationRequestsTab.js';

let rootEl = null;
let onBackToHubCb = null;
let onLogoutCb = null;

/**
 * Mount Kadrovska modul u dati root element.
 * @param {HTMLElement} root — kontejner (npr. #app)
 * @param {{ onBackToHub: () => void, onLogout: () => void }} options
 */
export function renderKadrovskaModule(root, { onBackToHub, onLogout } = {}) {
  rootEl = root;
  onBackToHubCb = onBackToHub || null;
  onLogoutCb = onLogout || null;

  /* Hard-guard: korisnik bez prava → toast + povratak na hub */
  if (!canAccessKadrovska()) {
    showToast('⚠ Nemaš pristup modulu Kadrovska');
    onBackToHubCb?.();
    return;
  }

  /* UX odluka: pri ulasku u Kadrovsku UVEK otvori Mesečni grid (najčešća radnja).
     Unutar iste sesije korisnik dalje može menjati tab — to se pamti u sessionStorage,
     ali na svaki fresh mount resetujemo na 'grid'. */
  kadrovskaState.activeTab = 'grid';
  setActiveKadrTab('grid');
  const activeTab = 'grid';

  root.innerHTML = `
    <section id="module-kadrovska" class="kadrovska-section" aria-label="Modul Kadrovska">
      <div class="kadr-sticky-header-chrome" id="kadrStickyChrome">
        ${kadrovskaHeaderHtml()}
        ${kadrTabsHtml(activeTab)}
        <div id="kadrGridToolbarSlot" class="kadr-grid-toolbar-slot" hidden></div>
      </div>
      <div id="kadrPanelHost" class="kadr-panel-host"></div>
    </section>
  `;

  /* Header: back / theme / logout / pending-badge */
  root.querySelector('#kadrBackBtn').addEventListener('click', () => {
    onBackToHubCb?.();
  });
  root.querySelector('#kadrThemeToggle').addEventListener('click', () => toggleTheme());
  root.querySelector('#kadrLogoutBtn').addEventListener('click', async () => {
    await logout();
    onLogoutCb?.();
  });

  /* Offline queue: auto-flush + badge. Klik na badge = ručni retry. */
  installKadrAutoFlush();
  refreshPendingBadge();
  setInterval(refreshPendingBadge, 5000);
  root.querySelector('#kadrPendingBadge').addEventListener('click', async () => {
    const before = countKadrPending();
    if (!before) return;
    showToast(`⏳ Pokušaj sinhronizacije ${before} stavki…`);
    const r = await flushKadrPending();
    refreshPendingBadge();
    if (r.ok > 0) showToast(`✅ Sinhronizovano ${r.ok}${r.failed ? `, neuspešno ${r.failed}` : ''}`);
    else if (r.failed > 0) showToast(`⚠ Neuspeh: ${r.failed} stavki ostaje za retry`);
    else if (r.dropped > 0) showToast(`⚠ Odbačeno ${r.dropped} stavki (max attempts)`);
  });

  /* Tab strip — switch */
  root.querySelectorAll('.kadrovska-tab').forEach(tabBtn => {
    tabBtn.addEventListener('click', () => {
      const id = tabBtn.dataset.kadrTab;
      switchTab(id);
    });
  });

  mountTabBody(activeTab);

  /* Badge za pending GO zahteve — učitaj u pozadini samo za upravljačke role */
  if (canManageVacationRequests()) {
    import('../../services/vacationRequests.js').then(({ loadAllVacationRequestsFromDb }) => {
      import('../../state/kadrovska.js').then(({ kadrVacReqState }) => {
        loadAllVacationRequestsFromDb().then(data => {
          if (data) {
            kadrVacReqState.items = data;
            kadrVacReqState.loaded = true;
            refreshVacReqBadge();
          }
        });
      });
    });
  }
}

function refreshPendingBadge() {
  if (!rootEl) return;
  const badge = rootEl.querySelector('#kadrPendingBadge');
  const cnt = rootEl.querySelector('#kadrPendingCount');
  if (!badge || !cnt) return;
  const n = countKadrPending();
  if (n > 0) {
    badge.hidden = false;
    cnt.textContent = String(n);
  } else {
    badge.hidden = true;
  }
}

function switchTab(id, opts = {}) {
  if (!rootEl) return;
  if (kadrovskaState.activeTab === id && !opts.gridMonth) return;
  kadrovskaState.activeTab = id;
  setActiveKadrTab(id);

  /* Update tab buttons */
  rootEl.querySelectorAll('.kadrovska-tab').forEach(btn => {
    const active = btn.dataset.kadrTab === id;
    btn.classList.toggle('active', active);
    btn.setAttribute('aria-selected', String(active));
  });

  mountTabBody(id, opts);
}

function mountTabBody(id, opts = {}) {
  const host = rootEl?.querySelector('#kadrPanelHost');
  if (!host) return;

  host.innerHTML = `<div class="kadr-panel active" id="kadrPanel-${id}" role="tabpanel" aria-label="${id}"></div>`;
  const panel = host.firstElementChild;

  /* Mapa tab → render + wire (async). Wire može biti async — error u promise-u
     se hvata i logguje. */
  const slot = rootEl?.querySelector('#kadrGridToolbarSlot');
  if (slot) {
    if (id === 'grid') {
      slot.hidden = false;
      slot.innerHTML = renderKadrovskaGridToolbarHtml();
    } else {
      slot.hidden = true;
      slot.innerHTML = '';
    }
  }

  const tabImpl = {
    employees: { render: renderEmployeesTab, wire: wireEmployeesTab },
    vacation: { render: renderVacationTab, wire: wireVacationTab },
    grid: {
      render: renderGridPanelBody,
      wire: p => wireGridTab(p, id === 'grid' ? rootEl?.querySelector('#kadrGridToolbarSlot') : null),
    },
    odsustva: {
      render: renderAbsencesTab,
      wire: p => wireAbsencesTab(p, {
        onNavigateGrid: (empName, yyyymm) => {
          ssSet(SESSION_KEYS.KADR_GRID_SEARCH, empName);
          switchTab('grid', { gridMonth: yyyymm });
        },
      }),
    },
    hours: { render: renderWorkHoursTab, wire: wireWorkHoursTab },
    contracts: { render: renderContractsTab, wire: wireContractsTab },
    salary: { render: renderSalaryTab, wire: wireSalaryTab, adminOnly: true },
    'vac-requests': { render: renderVacationRequestsTab, wire: wireVacationRequestsTab },
    notifications: { render: renderHrNotificationsTab, wire: wireHrNotificationsTab },
    reports: { render: renderReportsTab, wire: wireReportsTab },
  };

  const impl = tabImpl[id];
  if (impl?.adminOnly && !canAccessSalary()) {
    /* Neovlašćen pokušaj (stari aktivni tab u storage-u) — fallback na grid. */
    kadrovskaState.activeTab = 'grid';
    setActiveKadrTab('grid');
    mountTabBody('grid');
    return;
  }
  if (impl) {
    panel.innerHTML = impl.render();
    /* Pre-fill grid month input synchronously before async wire runs. */
    if (opts.gridMonth && id === 'grid') {
      const monthInput = panel.querySelector('#gridMonth');
      if (monthInput) monthInput.value = opts.gridMonth;
    }
    Promise.resolve()
      .then(() => impl.wire(panel))
      .catch(e => {
        console.error(`[kadrovska] ${id} wire failed`, e);
        showToast(`⚠ Greška pri učitavanju (${id})`);
      });
    return;
  }

  const meta = KADROVSKA_TAB_DEFS.find(t => t.id === id);
  panel.innerHTML = renderComingSoonTab(
    meta?.label || id,
    'F4.x'
  );
}
