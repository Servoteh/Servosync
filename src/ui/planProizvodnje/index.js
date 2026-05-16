/**
 * Plan Proizvodnje — modul za šefove mašinske obrade.
 *
 * Sprintovi:
 *   F.1  ✅  Skelet + migracije + Bridge syncTechRouting
 *   F.2  ✅  Per-mašina view: dropdown mašina, tabela operacija, drag-drop,
 *              status pill, napomena, HITNO vizuali, REASSIGN
 *   F.3  ☐  Zauzetost mašina (workload summary), Pregled svih (matrica)
 *   F.4  ☐  Upload skica (Storage), acceptance test
 *
 * Pristup:
 *   - Svi sa canAccessPlanProizvodnje() vide modul
 *   - admin + pm + menadzment pišu (drag-drop, status, napomena, slike, REASSIGN)
 *   - leadpm / hr / viewer read-only — edit dugmad disabled
 */

import { escHtml } from '../../lib/dom.js';
import { toggleTheme } from '../../lib/theme.js';
import { logout } from '../../services/auth.js';
import {
  getAuth,
  canEditPlanProizvodnje,
} from '../../state/auth.js';
import {
  fetchPpBridgeSyncStatus,
  PP_BRIDGE_LABELS,
} from '../../services/planProizvodnje.js';
import {
  renderPoMasiniTab,
  teardownPoMasiniTab,
} from './poMasiniTab.js';
import { findDeptForMachineCode } from './departments.js';
import {
  renderZauzetostTab,
  teardownZauzetostTab,
} from './zauzetostTab.js';
import {
  renderPregledTab,
  teardownPregledTab,
} from './pregledTab.js';
import {
  renderKooperacijaTab,
  teardownKooperacijaTab,
} from './kooperacijaTab.js';

const STORAGE_KEY_LAST_MACHINE = 'plan-proizvodnje:last-machine';
const STORAGE_KEY_LAST_DEPT    = 'plan-proizvodnje:last-department';

const TABS = [
  {
    id: 'po-masini',
    label: 'Po mašini',
    icon: '🛠',
    desc: 'Šef bira mašinu i raspoređuje operacije po prioritetu.',
  },
  {
    id: 'zauzetost',
    label: 'Zauzetost mašina',
    icon: '📊',
    desc: 'Ukupno otvorenih operacija i tehnološkog vremena po mašini.',
  },
  {
    id: 'pregled',
    label: 'Pregled svih',
    icon: '🗂',
    desc: 'Matrica svih mašina × narednih 5 dana.',
  },
  {
    id: 'kooperacija',
    label: 'Kooperacija',
    icon: '↗',
    desc: 'Auto i ručno poslate operacije za eksternu obradu.',
  },
];

let activeTab = 'po-masini';

export function renderPlanProizvodnjeModule(mountEl, { onBackToHub, onLogout }) {
  const auth = getAuth();
  const canEdit = canEditPlanProizvodnje();

  mountEl.innerHTML = '';

  const container = document.createElement('div');
  container.className = 'kadrovska-section';
  container.id = 'module-plan-proizvodnje';
  container.style.display = 'block';

  container.innerHTML = `
    <header class="kadrovska-header">
      <div class="kadrovska-header-left">
        <button class="btn-hub-back" id="ppBackBtn" title="Nazad na listu modula" aria-label="Nazad na module">
          <span class="back-icon" aria-hidden="true">←</span>
          <span>Moduli</span>
        </button>
        <div class="kadrovska-title">
          <span class="ktitle-mark" aria-hidden="true">🏭</span>
          <span>Planiranje proizvodnje</span>
        </div>
      </div>
      <div class="kadrovska-header-right">
        <button class="theme-toggle" id="ppThemeToggle" title="Promeni temu" aria-label="Promeni temu">
          <span class="theme-icon-dark">🌙</span>
          <span class="theme-icon-light">☀️</span>
        </button>
        <div class="hub-user">
          <span class="hub-user-email">${escHtml(auth.user?.email || '—')}</span>
          <span class="hub-user-role">${escHtml(auth.role)}${canEdit ? '' : ' · read-only'}</span>
        </div>
        <button class="hub-logout" id="ppLogoutBtn">Odjavi se</button>
      </div>
    </header>

    <nav class="kadrovska-tabs" role="tablist" aria-label="Plan Proizvodnje tabovi">
      ${TABS.map(t => `
        <button type="button" role="tab"
          class="kadrovska-tab${t.id === activeTab ? ' is-active' : ''}"
          data-tab="${t.id}"
          aria-selected="${t.id === activeTab ? 'true' : 'false'}">
          <span aria-hidden="true">${t.icon}</span> ${escHtml(t.label)}
        </button>
      `).join('')}
    </nav>

    <div id="ppBridgeBanner" aria-live="polite"></div>

    <main class="kadrovska-tabpanel" id="ppTabBody" style="padding:24px;max-width:1600px;margin:0 auto"></main>
  `;

  mountEl.appendChild(container);

  /* H28/M20: učitaj bridge sync stanje. Fire-and-forget — ne čekamo
     da bismo renderovali glavni modul. Ako bridge_sync_log ne postoji
     ili fetch fail-uje, banner ostaje skriven. */
  void renderPpBridgeBanner(container.querySelector('#ppBridgeBanner'));

  /* Wire događaji */
  container.querySelector('#ppBackBtn').addEventListener('click', () => onBackToHub?.());
  container.querySelector('#ppThemeToggle').addEventListener('click', toggleTheme);
  container.querySelector('#ppLogoutBtn').addEventListener('click', async () => {
    await logout();
    onLogout?.();
  });

  container.querySelectorAll('button[data-tab]').forEach(btn => {
    btn.addEventListener('click', () => {
      const tabId = btn.dataset.tab;
      if (tabId === activeTab) return;
      teardownActiveTab();
      activeTab = tabId;
      /* Re-render header (active tab markup) + body */
      renderPlanProizvodnjeModule(mountEl, { onBackToHub, onLogout });
    });
  });

  renderTabBody(container.querySelector('#ppTabBody'), {
    canEdit, mountEl, onBackToHub, onLogout,
  });
}

function renderTabBody(host, { canEdit, mountEl, onBackToHub, onLogout }) {
  /* Callback koji "Zauzetost" i "Pregled" tabovi koriste za skok u
     "Po mašini" sa preselektovanom mašinom. */
  const jumpToPoMasini = (machineCode) => {
    if (machineCode) {
      localStorage.setItem(STORAGE_KEY_LAST_MACHINE, machineCode);
      /* V2: postavi i odeljenje (tab) u kome ta mašina živi, da „Po mašini"
         odmah otvori odgovarajući tab + drill-down (a ne 'sve' default). */
      const deptSlug = findDeptForMachineCode(machineCode);
      if (deptSlug) {
        localStorage.setItem(STORAGE_KEY_LAST_DEPT, deptSlug);
      }
    }
    if (activeTab !== 'po-masini') {
      teardownActiveTab();
      activeTab = 'po-masini';
      renderPlanProizvodnjeModule(mountEl, { onBackToHub, onLogout });
    }
  };

  if (activeTab === 'po-masini') {
    /* SPRINT F.2: glavni view — selektor mašine, tabela operacija,
       drag-drop, status pill, napomena, REASSIGN. */
    renderPoMasiniTab(host, { canEdit });
    return;
  }

  if (activeTab === 'zauzetost') {
    /* SPRINT F.3a: zbirno po mašini (otvorene operacije, planirano vreme,
       hitnost, premešteno…) */
    renderZauzetostTab(host, { canEdit, onJumpToPoMasini: jumpToPoMasini });
    return;
  }

  if (activeTab === 'pregled') {
    /* SPRINT F.3b: matrica MAŠINA × NAREDNIH 5 RADNIH DANA */
    renderPregledTab(host, { canEdit, onJumpToPoMasini: jumpToPoMasini });
    return;
  }

  if (activeTab === 'kooperacija') {
    renderKooperacijaTab(host, { canEdit });
    return;
  }

  /* Fallback (ne bi trebalo da se desi) */
  const tab = TABS.find(t => t.id === activeTab) || TABS[0];
  host.innerHTML = `<div class="pp-state"><div class="pp-state-title">${escHtml(tab.label)}</div></div>`;
}

function teardownActiveTab() {
  if (activeTab === 'po-masini') teardownPoMasiniTab();
  if (activeTab === 'zauzetost') teardownZauzetostTab();
  if (activeTab === 'pregled')   teardownPregledTab();
  if (activeTab === 'kooperacija') teardownKooperacijaTab();
}

export function teardownPlanProizvodnjeModule() {
  teardownActiveTab();
}

/**
 * H28/M20: bridge health banner. Pokazuje upozorenje ako PP-relevantni
 * BigTehn cache job-ovi nisu sveže sinhronizovani.
 *
 * Pragovi:
 *   - < 30 min: skriveno
 *   - 30 min – 2 h: žuti banner (pp-warning paleta, ⚠ ikona)
 *   - > 2 h: crveni banner (pp-bridge-critical override, 🔴 ikona)
 *
 * Refresh: jednom po renderPlanProizvodnjeModule pozivu (tab switch
 * trigger-uje re-render → svežiji status). Bez setInterval.
 */
async function renderPpBridgeBanner(host) {
  if (!host) return;
  host.innerHTML = '';

  let status;
  try {
    status = await fetchPpBridgeSyncStatus();
  } catch (_e) {
    return;
  }
  if (!Array.isArray(status) || !status.length) return;

  const now = Date.now();
  const WARN_MS = 30 * 60 * 1000;
  const CRITICAL_MS = 2 * 60 * 60 * 1000;

  let worstAge = 0;
  const staleParts = [];

  for (const it of status) {
    const t = it.last_finished ? Date.parse(it.last_finished) : NaN;
    if (!Number.isFinite(t)) continue;
    const ageMs = now - t;
    if (ageMs <= WARN_MS) continue;
    worstAge = Math.max(worstAge, ageMs);
    const min = Math.round(ageMs / 60000);
    const hours = Math.round(ageMs / 3600000);
    const ageStr = min < 120 ? `${min} min` : `${hours} h`;
    const label = PP_BRIDGE_LABELS[it.sync_job] || it.sync_job;
    staleParts.push(`<strong>${escHtml(label)}</strong> · pre ${escHtml(ageStr)}`);
  }

  if (!staleParts.length) return;

  const isCritical = worstAge > CRITICAL_MS;
  const wrap = document.createElement('div');
  wrap.className = isCritical
    ? 'pp-warning pp-bridge-banner pp-bridge-critical'
    : 'pp-warning pp-bridge-banner';
  wrap.innerHTML = `
    <span class="pp-bridge-icon" aria-hidden="true">${isCritical ? '🔴' : '⚠'}</span>
    <span>
      <strong>Bridge sync ${isCritical ? 'NE RADI' : 'kasni'}:</strong>
      ${staleParts.join(' · ')}.
      ${isCritical
        ? 'Spremnost crteža i status u radu možda nisu tačni.'
        : 'Podaci možda nisu sveži.'}
    </span>
  `;
  host.appendChild(wrap);
}
