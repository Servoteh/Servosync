/**
 * Deljeni building blocks za sve Kadrovska tabove.
 *
 * - kadrovskaHeaderHtml() vraća HTML za header (back/title/theme/role/logout).
 *   Wire-ovi se vežu u root render-u (renderKadrovskaModule).
 * - renderSummaryChips() popunjava .kadr-summary-strip kroz dati ID.
 * - kadrTabsHtml() — top tab bar (Kadrovska sekcije).
 *
 * Sva dugmad rade preko addEventListener (selectori po ID-u/data atributu).
 */

import { escHtml } from '../../lib/dom.js';
import {
  getAuth,
  canEdit,
  canAccessSalary,
  canAccessOdsustvaPregled,
  canManageVacationRequests,
  canAccessKadrovska,
} from '../../state/auth.js';
import { kadrovskaState } from '../../state/kadrovska.js';
import {
  compareEmployeesByLastFirst,
  employeeDisplayName,
} from '../../lib/employeeNames.js';

/** Stranica jedne kartice u summary strip-u. */
export function summaryChipHtml(label, value, tone) {
  const cls = tone ? 'kadr-summary-chip ' + tone : 'kadr-summary-chip';
  return `<div class="${cls}"><span class="kscl">${escHtml(label)}</span><span class="kscv">${escHtml(String(value))}</span></div>`;
}

/** Renderuj listu chip-ova u kontejner; sakrij ako je prazno. */
export function renderSummaryChips(containerId, chips) {
  const host = document.getElementById(containerId);
  if (!host) return;
  if (!chips || !chips.length) {
    host.innerHTML = '';
    host.style.display = 'none';
    return;
  }
  host.style.display = 'flex';
  host.innerHTML = chips.map(c => summaryChipHtml(c.label, c.value, c.tone)).join('');
}

/** Header za Kadrovska modul. ID-ovi se koriste za event wire-ovanje. */
export function kadrovskaHeaderHtml() {
  const auth = getAuth();
  return `
    <header class="kadrovska-header">
      <div class="kadrovska-header-left">
        <button class="btn-hub-back" id="kadrBackBtn" title="Nazad na listu modula" aria-label="Nazad na module">
          <span class="back-icon" aria-hidden="true">←</span>
          <span>Moduli</span>
        </button>
        <div class="kadrovska-title">
          <span class="ktitle-mark" aria-hidden="true">👥</span>
          <span>Kadrovska</span>
        </div>
      </div>
      <div class="kadrovska-header-right">
        <button class="kadr-pending-badge" id="kadrPendingBadge" title="Mutacije čekaju da se sinhronizuju" hidden>
          ⏳ <span id="kadrPendingCount">0</span> čeka
        </button>
        <button class="theme-toggle" id="kadrShortcutsBtn" title="Tastaturni prečice (pritisni ?)" aria-label="Tastaturni prečice">
          ⌨
        </button>
        <button class="theme-toggle" id="kadrThemeToggle" title="Promeni temu" aria-label="Promeni temu">
          <span class="theme-icon-dark">🌙</span>
          <span class="theme-icon-light">☀️</span>
        </button>
        <span class="role-indicator ${canEdit() ? 'role-pm' : 'role-viewer'}" id="kadrovskaRoleLabel">${escHtml((auth.role || 'viewer').toUpperCase())}</span>
        <button class="hub-logout" id="kadrLogoutBtn">Odjavi se</button>
      </div>
    </header>`;
}

/**
 * HTML <option> liste svih zaposlenih (sortirano po prezimenu, sr-locale).
 *  - includeBlank: doda prazan top option ('Svi zaposleni' / '— izaberi —').
 *  - blankLabel: tekst praznog opciona.
 *  - selectedId: prefilled value.
 *  - activeOnly: ako true, samo isActive.
 */
export function employeeOptionsHtml({
  includeBlank = true,
  blankLabel = '— izaberi —',
  selectedId = '',
  activeOnly = false,
} = {}) {
  let list = kadrovskaState.employees.slice();
  if (activeOnly) list = list.filter(e => e.isActive);
  list.sort(compareEmployeesByLastFirst);
  const opts = [];
  if (includeBlank) {
    opts.push(`<option value="">${escHtml(blankLabel)}</option>`);
  }
  for (const e of list) {
    const sel = String(e.id) === String(selectedId) ? ' selected' : '';
    opts.push(`<option value="${escHtml(e.id)}"${sel}>${escHtml(employeeDisplayName(e) || '—')}</option>`);
  }
  return opts.join('');
}

/** Kartice podmodula na Pregledu — tabId mora odgovarati `tabImpl` u index.js */
export const KADR_SUBMODULES = [
  { tabId: 'employees', label: 'Zaposleni', icon: '👥', description: 'Lista, profili, ugovori', requires: 'canAccessKadrovska' },
  { tabId: 'calendar', label: 'Kalendar', icon: '🗓️', description: 'Mesečni pregled odsustava', requires: 'canAccessKadrovska' },
  { tabId: 'odsustva', label: 'Odsustva', icon: '📅', description: 'GO, bolovanje, slobodni dani', requires: 'canAccessKadrovska' },
  { tabId: 'grid', label: 'Mesečni grid', icon: '📊', description: 'Excel-style unos sati', requires: 'canAccessKadrovska' },
  { tabId: 'vacation', label: 'Godišnji odmor', icon: '🏖️', description: 'Entitlementi, saldo', requires: 'canAccessKadrovska' },
  { tabId: 'vac-requests', label: 'Zahtevi GO', icon: '✋', description: 'Odobravanje i odbijanje', requires: 'canManageVacationRequests' },
  { tabId: 'hours', label: 'Sati', icon: '⏱️', description: 'Pojedinačni unos', requires: 'canAccessKadrovska' },
  { tabId: 'contracts', label: 'Ugovori', icon: '📄', description: 'Ugovori o radu', requires: 'canAccessKadrovska' },
  { tabId: 'salary', label: 'Zarade', icon: '💰', description: 'Uslovi i obračun', requires: 'canAccessSalary' },
  { tabId: 'notifications', label: 'Notifikacije', icon: '🔔', description: 'HR alerti, queue', requires: 'canAccessKadrovska' },
  { tabId: 'reports', label: 'Izveštaji', icon: '📈', description: 'Demografija, GO, obračun', requires: 'canAccessKadrovska' },
];

const authHelpers = {
  canAccessKadrovska,
  canManageVacationRequests,
  canAccessSalary,
};

/** Podmoduli dostupni trenutnoj roli (paritet sa RLS / auth helperima). */
export function visibleSubmodules() {
  return KADR_SUBMODULES.filter(s => {
    const check = authHelpers[s.requires];
    return typeof check === 'function' ? check() : false;
  });
}

/**
 * Definicije tabova (redosled = strip).
 *   adminOnly    — prikazuje se samo ako canAccessSalary()
 *   pregledOnly  — prikazuje se samo ako canAccessOdsustvaPregled()
 *   noBadge      — sakrij brojač u tab strip-u
 */
export const KADROVSKA_TAB_DEFS = [
  { id: 'dashboard', label: 'Pregled', icon: '🏠', noBadge: true },
  { id: 'calendar', label: 'Kalendar', icon: '🗓️', badgeId: 'kadrTabCountCalendar' },
  { id: 'grid', label: 'Mesecni grid', badgeId: 'kadrTabCountGrid' },
  { id: 'odsustva', label: 'Odsustva', badgeId: 'kadrTabCountAbsences', pregledOnly: true },
  { id: 'employees', label: 'Zaposleni', badgeId: 'kadrTabCountEmployees' },
  { id: 'vacation', label: 'Godisnji odmor', badgeId: 'kadrTabCountVacation' },
  { id: 'hours', label: 'Sati', badgeId: 'kadrTabCountHours' },
  { id: 'contracts', label: 'Ugovori', badgeId: 'kadrTabCountContracts' },
  { id: 'salary', label: 'Zarade', badgeId: 'kadrTabCountSalary', adminOnly: true },
  { id: 'vac-requests', label: 'Zahtevi GO', badgeId: 'kadrTabCountVacReq', requestsOnly: true },
  { id: 'notifications', label: 'Notifikacije', badgeId: 'kadrTabCountNotif' },
  { id: 'reports', label: 'Izvestaji', badgeId: 'kadrTabCountReports' },
];

export function kadrVisibleTabDefs() {
  return KADROVSKA_TAB_DEFS.filter(t => {
    if (t.id === 'dashboard') return canAccessKadrovska();
    if (t.adminOnly)    return canAccessSalary();
    if (t.pregledOnly)  return canAccessOdsustvaPregled();
    if (t.requestsOnly) return canManageVacationRequests();
    return true;
  });
}

/** Tab bar sa badge-ovima. Active tab se kontroliše classList.add('active'). */
export function kadrTabsHtml(activeTab) {
  const tabs = kadrVisibleTabDefs();
  return `
    <div class="kadrovska-tabs" role="tablist" aria-label="Kadrovska - sekcije">
      ${tabs.map(t => `
        <button class="kadrovska-tab${t.id === activeTab ? ' active' : ''}" role="tab"
                aria-selected="${t.id === activeTab}" data-kadr-tab="${t.id}">
          ${t.icon ? `<span class="kadrovska-tab-icon" aria-hidden="true">${t.icon}</span> ` : ''}${escHtml(t.label)}${t.noBadge ? '' : ` <span class="kadr-tab-badge" id="${t.badgeId}">0</span>`}
        </button>
      `).join('')}
    </div>`;
}
