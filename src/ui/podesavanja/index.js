/**
 * Podešavanja — root modula (F5b).
 *
 * Navigacija: levi sidebar sa grupama (umesto horizontalnih tabova).
 *
 * Grupe:
 *   GENERALNO      — Organizacija
 *   KORISNICI      — Korisnici (admin), Održ. profili
 *   PODACI         — Podeš. predmeta, Matični podaci
 *   SISTEM         — Sistem (admin)
 *
 * Pristup: admin vidi sve; menadžment samo maint-profiles i predmet-aktivacija.
 * Aktivni tab se persistuje u sessionStorage (SETTINGS_TAB).
 */

import { escHtml } from '../../lib/dom.js';
import { ssGet, ssSet } from '../../lib/storage.js';
import { SESSION_KEYS } from '../../lib/constants.js';
import { toggleTheme } from '../../lib/theme.js';
import { onAuthChange, getAuth, canManageUsers, canAccessPodesavanja } from '../../state/auth.js';
import { usersState } from '../../state/users.js';
import { renderUsersTab, refreshUsers, wireUsersTab } from './usersTab.js';
import { renderMastersTab } from './mastersTab.js';
import { renderSystemTab } from './systemTab.js';
import {
  renderMaintProfilesTab,
  wireMaintProfilesTab,
  refreshMaintProfiles,
} from './maintProfilesTab.js';
import {
  renderOrgStructureTab,
  wireOrgStructureTab,
  refreshOrgStructure,
} from './orgStructureTab.js';
import {
  refreshPredmetAktivacija,
  renderPodesavanjePredmetaPanel,
  wirePodesavanjePredmetaPanel,
} from './podesavanjePredmeta/index.js';

let _mountEl = null;
let _onLogoutCb = null;
let _onBackToHubCb = null;
let _authUnsubscribe = null;
let _activeTab = 'users';

/* ── Sidebar struktura ───────────────────────────────────────────────── */

const SIDEBAR_GROUPS = [
  {
    label: 'Generalno',
    items: [
      { id: 'organizacija', icon: '🏢', label: 'Organizacija', adminOnly: true },
    ],
  },
  {
    label: 'Korisnici i pristup',
    items: [
      { id: 'users', icon: '👥', label: 'Korisnici', adminOnly: true, badge: true },
      { id: 'maint-profiles', icon: '🔧', label: 'Održ. profili', adminOnly: false },
    ],
  },
  {
    label: 'Podaci',
    items: [
      { id: 'predmet-aktivacija', icon: '📋', label: 'Podeš. predmeta', adminOnly: false },
      { id: 'masters', icon: '🗄', label: 'Matični podaci', adminOnly: true },
    ],
  },
  {
    label: 'Sistem',
    items: [
      { id: 'system', icon: '⚙', label: 'Sistem', adminOnly: true },
    ],
  },
];

function _visibleGroups() {
  const isAdmin = canManageUsers();
  return SIDEBAR_GROUPS.map(g => ({
    ...g,
    items: g.items.filter(it => isAdmin || !it.adminOnly),
  })).filter(g => g.items.length > 0);
}

function _visibleTabs() {
  return _visibleGroups().flatMap(g => g.items);
}

/* ── PUBLIC ──────────────────────────────────────────────────────────── */

export async function renderPodesavanjaModule(mountEl, options = {}) {
  _mountEl = mountEl;
  _onLogoutCb = options.onLogout || null;
  _onBackToHubCb = options.onBackToHub || null;
  _activeTab = ssGet(SESSION_KEYS.SETTINGS_TAB, 'users') || 'users';

  const visible = _visibleTabs();
  if (!visible.some(t => t.id === _activeTab)) {
    _activeTab = visible[0]?.id || 'maint-profiles';
  }

  _renderShell();

  if (_activeTab === 'users') {
    refreshUsers().then(() => _renderShell()).catch(e => console.warn('[podesavanja] users load failed', e));
  }
  if (_activeTab === 'maint-profiles') {
    refreshMaintProfiles().then(() => _renderShell()).catch(e => console.warn('[podesavanja] maint profiles load failed', e));
  }
  if (_activeTab === 'predmet-aktivacija') {
    refreshPredmetAktivacija().then(() => _renderShell()).catch(e => console.warn('[podesavanja] predmet aktivacija load failed', e));
  }
  if (_activeTab === 'organizacija') {
    refreshOrgStructure().then(() => _renderShell()).catch(e => console.warn('[podesavanja] org structure load failed', e));
  }

  if (_authUnsubscribe) _authUnsubscribe();
  _authUnsubscribe = onAuthChange(() => _renderShell());
}

export function teardownPodesavanjaModule() {
  if (_authUnsubscribe) { _authUnsubscribe(); _authUnsubscribe = null; }
}

/* ── INTERNAL ─────────────────────────────────────────────────────────── */

function _renderShell() {
  if (!_mountEl) return;

  if (!canAccessPodesavanja()) {
    _mountEl.innerHTML = _lockedScreenHtml();
    _mountEl.querySelector('#podBackBtn')?.addEventListener('click', () => _onBackToHubCb?.());
    _mountEl.querySelector('#podLogoutBtn')?.addEventListener('click', () => _onLogoutCb?.());
    return;
  }

  _mountEl.innerHTML = `
    ${_headerHtml()}
    <div class="set-layout">
      <nav class="set-sidebar" role="navigation" aria-label="Podešavanja navigacija">
        ${_sidebarHtml()}
      </nav>
      <div class="set-content">
        ${_panelHtml(_activeTab)}
      </div>
    </div>
  `;

  _wireHeader();
  _wireSidebar();
  _wireTabBody();
}

function _sidebarHtml() {
  const groups = _visibleGroups();
  return groups.map(g => `
    <div class="set-sidebar-group">
      <div class="set-sidebar-group-label">${escHtml(g.label)}</div>
      ${g.items.map(it => {
        const isActive = it.id === _activeTab;
        const badgeHtml = it.badge
          ? `<span class="set-sidebar-badge" id="setSidebarBadge-${it.id}">${usersState.items.length}</span>`
          : '';
        return `
          <button class="set-sidebar-item ${isActive ? 'active' : ''}"
                  data-set-tab="${escHtml(it.id)}"
                  role="menuitem"
                  aria-current="${isActive ? 'page' : 'false'}">
            <span aria-hidden="true">${it.icon}</span>
            ${escHtml(it.label)}
            ${badgeHtml}
          </button>`;
      }).join('')}
    </div>
  `).join('');
}

function _headerHtml() {
  const auth = getAuth();
  return `
    <header class="kadrovska-header">
      <div class="kadrovska-header-left">
        <button class="btn-hub-back" id="podBackBtn" title="Nazad na listu modula" aria-label="Nazad na module">
          <span class="back-icon" aria-hidden="true">←</span>
          <span>Moduli</span>
        </button>
        <div class="kadrovska-title">
          <span class="ktitle-mark" aria-hidden="true">⚙</span>
          <span>Podešavanja</span>
        </div>
      </div>
      <div class="kadrovska-header-right">
        <button class="theme-toggle" id="podThemeToggle" title="Promeni temu" aria-label="Promeni temu">
          <span class="theme-icon-dark">🌙</span>
          <span class="theme-icon-light">☀️</span>
        </button>
        <span class="role-indicator role-${escHtml(auth.role || 'viewer')}" id="podRoleLabel">${escHtml((auth.role || 'viewer').toUpperCase())}</span>
        <button class="hub-logout" id="podLogoutBtn">Odjavi se</button>
      </div>
    </header>
  `;
}

function _panelHtml(tab) {
  if (tab === 'users') return renderUsersTab();
  if (tab === 'organizacija') return renderOrgStructureTab();
  if (tab === 'maint-profiles') return renderMaintProfilesTab();
  if (tab === 'predmet-aktivacija') return renderPodesavanjePredmetaPanel();
  if (tab === 'masters') return renderMastersTab();
  if (tab === 'system') return renderSystemTab();
  return '';
}

function _lockedScreenHtml() {
  const auth = getAuth();
  return `
    <header class="kadrovska-header">
      <div class="kadrovska-header-left">
        <button class="btn-hub-back" id="podBackBtn">
          <span class="back-icon" aria-hidden="true">←</span>
          <span>Moduli</span>
        </button>
        <div class="kadrovska-title">
          <span class="ktitle-mark" aria-hidden="true">🔒</span>
          <span>Podešavanja</span>
        </div>
      </div>
      <div class="kadrovska-header-right">
        <span class="role-indicator role-viewer">${escHtml((auth.role || 'viewer').toUpperCase())}</span>
        <button class="hub-logout" id="podLogoutBtn">Odjavi se</button>
      </div>
    </header>
    <main style="padding:32px;max-width:640px;margin:0 auto">
      <div class="auth-box" style="max-width:none;text-align:left">
        <div class="auth-brand">
          <div class="auth-title">🔒 Pristup zabranjen</div>
          <div class="auth-subtitle">Podešavanja su dostupna samo korisnicima sa <strong>admin</strong> ili <strong>menadžment</strong> rolom u ERP-u.</div>
        </div>
        <p class="form-hint" style="margin-top:14px">Ako misliš da bi trebalo da imaš pristup, javi se nekom od admina ili HR-u da ti dodeli odgovarajuću rolu kroz Supabase SQL Editor.</p>
      </div>
    </main>
  `;
}

function _wireHeader() {
  _mountEl.querySelector('#podBackBtn')?.addEventListener('click', () => _onBackToHubCb?.());
  _mountEl.querySelector('#podLogoutBtn')?.addEventListener('click', () => _onLogoutCb?.());
  _mountEl.querySelector('#podThemeToggle')?.addEventListener('click', () => toggleTheme());
}

function _wireSidebar() {
  _mountEl.querySelectorAll('[data-set-tab]').forEach(btn => {
    btn.addEventListener('click', () => {
      const t = btn.dataset.setTab;
      if (!t || t === _activeTab) return;
      _activeTab = t;
      ssSet(SESSION_KEYS.SETTINGS_TAB, t);
      _renderShell();
      if (t === 'users') {
        refreshUsers().then(() => _renderShell()).catch(e => console.warn('[podesavanja] users refresh failed', e));
      }
      if (t === 'maint-profiles') {
        refreshMaintProfiles().then(() => _renderShell()).catch(e => console.warn('[podesavanja] maint profiles refresh failed', e));
      }
      if (t === 'predmet-aktivacija') {
        refreshPredmetAktivacija().then(() => _renderShell()).catch(e => console.warn('[podesavanja] predmet aktivacija refresh failed', e));
      }
      if (t === 'organizacija') {
        refreshOrgStructure().then(() => _renderShell()).catch(e => console.warn('[podesavanja] org structure refresh failed', e));
      }
    });
  });
}

function _wireTabBody() {
  if (_activeTab === 'users') {
    wireUsersTab(_mountEl, { onChange: () => _renderShell() });
  }
  if (_activeTab === 'maint-profiles') {
    wireMaintProfilesTab(_mountEl, { onChange: () => _renderShell() });
  }
  if (_activeTab === 'predmet-aktivacija') {
    wirePodesavanjePredmetaPanel(_mountEl);
  }
  if (_activeTab === 'organizacija') {
    wireOrgStructureTab(_mountEl);
  }
}
