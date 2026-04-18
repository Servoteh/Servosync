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

import { canAccessKadrovska, canEdit, getAuth } from '../../state/auth.js';
import { showToast } from '../../lib/dom.js';
import { logout } from '../../services/auth.js';
import { toggleTheme } from '../../lib/theme.js';

import {
  kadrovskaHeaderHtml,
  kadrTabsHtml,
} from './shared.js';
import { kadrovskaState, setActiveKadrTab } from '../../state/kadrovska.js';
import {
  renderEmployeesTab,
  wireEmployeesTab,
} from './employeesTab.js';
import { renderComingSoonTab } from './comingSoon.js';

const TABS = [
  { id: 'employees', label: 'Zaposleni' },
  { id: 'absences', label: 'Odsustva', plannedPhase: 'F4.1' },
  { id: 'grid', label: 'Mesečni grid', plannedPhase: 'F4.2' },
  { id: 'hours', label: 'Sati (pojedinačno)', plannedPhase: 'F4.1' },
  { id: 'contracts', label: 'Ugovori', plannedPhase: 'F4.1' },
  { id: 'reports', label: 'Izveštaji', plannedPhase: 'F4.3' },
];

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

  const activeTab = kadrovskaState.activeTab || 'employees';

  root.innerHTML = `
    <section id="module-kadrovska" class="kadrovska-section" aria-label="Modul Kadrovska">
      ${kadrovskaHeaderHtml()}
      ${kadrTabsHtml(activeTab)}
      <div id="kadrPanelHost"></div>
    </section>
  `;

  /* Header: back / theme / logout */
  root.querySelector('#kadrBackBtn').addEventListener('click', () => {
    onBackToHubCb?.();
  });
  root.querySelector('#kadrThemeToggle').addEventListener('click', () => toggleTheme());
  root.querySelector('#kadrLogoutBtn').addEventListener('click', async () => {
    await logout();
    onLogoutCb?.();
  });

  /* Tab strip — switch */
  root.querySelectorAll('.kadrovska-tab').forEach(tabBtn => {
    tabBtn.addEventListener('click', () => {
      const id = tabBtn.dataset.kadrTab;
      switchTab(id);
    });
  });

  mountTabBody(activeTab);
}

function switchTab(id) {
  if (!rootEl) return;
  if (kadrovskaState.activeTab === id) return;
  kadrovskaState.activeTab = id;
  setActiveKadrTab(id);

  /* Update tab buttons */
  rootEl.querySelectorAll('.kadrovska-tab').forEach(btn => {
    const active = btn.dataset.kadrTab === id;
    btn.classList.toggle('active', active);
    btn.setAttribute('aria-selected', String(active));
  });

  mountTabBody(id);
}

function mountTabBody(id) {
  const host = rootEl?.querySelector('#kadrPanelHost');
  if (!host) return;
  host.innerHTML = `<div class="kadr-panel active" id="kadrPanel-${id}" role="tabpanel" aria-label="${id}"></div>`;
  const panel = host.firstElementChild;

  if (id === 'employees') {
    panel.innerHTML = renderEmployeesTab();
    /* wire async — fetch sa Supabase, pa render */
    wireEmployeesTab(panel).catch(e => {
      console.error('[kadrovska] employees wire failed', e);
      showToast('⚠ Greška pri učitavanju zaposlenih');
    });
    return;
  }

  /* Ostali tabovi: placeholder + auth status info */
  const meta = TABS.find(t => t.id === id);
  panel.innerHTML = renderComingSoonTab(
    meta?.label || id,
    meta?.plannedPhase || 'F4.x'
  );
}
