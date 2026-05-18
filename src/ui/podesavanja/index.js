/**
 * Podešavanja — root modula.
 *
 * Navigacija: levi sidebar. Deep link: /podesavanja?tab=users (#tab=users).
 * Pristup: admin — svi tabovi; menadžment — Mašine, Održ. profili, Podeš. predmeta.
 */

import { escHtml } from '../../lib/dom.js';
import { onAuthChange, getAuth, canManageUsers, canAccessPodesavanja } from '../../state/auth.js';
import { usersState } from '../../state/users.js';
import {
  readStoredPodesavanjaTab,
  writeStoredPodesavanjaTab,
  getPodesavanjaTabFromUrl,
  syncPodesavanjaTabToUrl,
  parsePodesavanjaTabFromLocation,
} from '../../lib/podesavanjaTabs.js';
import { toggleTheme } from '../../lib/theme.js';
import { ROLE_LABELS } from '../../lib/constants.js';
import { renderUsersTab, refreshUsers, wireUsersTab } from './usersTab.js';
import { renderMastersTab } from './mastersTab.js';
import { renderSystemTab, wireSystemTab } from './systemTab.js';
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
import {
  refreshMaintMachinesTab,
  renderMasineTab,
  wireMasineTab,
} from './masineTab.js';
import { renderUlogeTab, wireUlogeTab } from './ulogeTab.js';
import { renderNotifikacijeTab, wireNotifikacijeTab } from './notifikacijeTab.js';
import { renderIntegracijeTab, wireIntegracijeTab } from './integracijeTab.js';
import {
  renderAuditLogTab,
  wireAuditLogTab,
  refreshSettingsAuditLog,
} from './auditLogTab.js';

let _mountEl = null;
let _onLogoutCb = null;
let _onBackToHubCb = null;
let _authUnsubscribe = null;
let _popstateHandler = null;
let _activeTab = 'users';
/** @type {Map<string, string>} */
const _panelHtmlCache = new Map();
/** @type {Set<string>} */
const _loadedTabs = new Set();

const SIDEBAR_GROUPS = [
  {
    label: 'Korisnici i pristup',
    items: [
      { id: 'users', icon: '👤', label: 'Korisnici', adminOnly: true, badgeKey: 'users' },
      { id: 'uloge', icon: '🛡', label: 'Uloge i dozvole', adminOnly: true },
    ],
  },
  {
    label: 'Organizacija',
    items: [
      { id: 'organizacija', icon: '🏢', label: 'Organizacija', adminOnly: true },
    ],
  },
  {
    label: 'Podaci',
    items: [
      { id: 'masters', icon: '🗄', label: 'Matični podaci', adminOnly: true },
      { id: 'masine', icon: '🛠', label: 'Mašine', adminOnly: false },
      { id: 'maint-profiles', icon: '🔧', label: 'Održ. profili', adminOnly: false },
      { id: 'predmet-aktivacija', icon: '📋', label: 'Podeš. predmeta', adminOnly: false },
    ],
  },
  {
    label: 'Sistem',
    items: [
      { id: 'notifikacije', icon: '🔔', label: 'Notifikacije', adminOnly: true },
      { id: 'integracije', icon: '🔗', label: 'Integracije', adminOnly: true },
      { id: 'audit-log', icon: '📜', label: 'Audit log', adminOnly: true },
      { id: 'system', icon: '⚙', label: 'Sistem', adminOnly: true },
    ],
  },
];

const TAB_SUBTITLES = {
  users: 'Korisnici i pristup',
  uloge: 'Korisnici i pristup',
  organizacija: 'Organizacija',
  masters: 'Podaci',
  masine: 'Podaci',
  'maint-profiles': 'Podaci',
  'predmet-aktivacija': 'Podaci',
  notifikacije: 'Sistem',
  integracije: 'Sistem',
  'audit-log': 'Sistem',
  system: 'Sistem',
};

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

function _badgeValue(key) {
  if (key === 'users') return usersState.items.length || '';
  if (key === 'uloge') return Object.keys(ROLE_LABELS).length;
  return '';
}

function _resolveInitialTab() {
  const fromUrl = getPodesavanjaTabFromUrl();
  if (fromUrl) return fromUrl;
  return readStoredPodesavanjaTab('users');
}

function _invalidatePanelCache(tabId = null) {
  if (tabId) _panelHtmlCache.delete(tabId);
  else _panelHtmlCache.clear();
}

export async function renderPodesavanjaModule(mountEl, options = {}) {
  _mountEl = mountEl;
  _onLogoutCb = options.onLogout || null;
  _onBackToHubCb = options.onBackToHub || null;

  _activeTab = _resolveInitialTab();
  const visible = _visibleTabs();
  if (!visible.some(t => t.id === _activeTab)) {
    _activeTab = visible[0]?.id || 'maint-profiles';
  }
  writeStoredPodesavanjaTab(_activeTab);
  syncPodesavanjaTabToUrl(_activeTab, { replace: true });

  _renderShell();
  await _loadActiveTabData(true);

  if (_authUnsubscribe) _authUnsubscribe();
  _authUnsubscribe = onAuthChange(() => {
    const vis = _visibleTabs();
    if (!vis.some(t => t.id === _activeTab)) {
      _activeTab = vis[0]?.id || 'maint-profiles';
      writeStoredPodesavanjaTab(_activeTab);
      syncPodesavanjaTabToUrl(_activeTab, { replace: true });
    }
    _renderShell();
  });

  if (_popstateHandler) window.removeEventListener('popstate', _popstateHandler);
  _popstateHandler = () => {
    const t = getPodesavanjaTabFromUrl();
    if (!t || t === _activeTab) return;
    if (!_visibleTabs().some(x => x.id === t)) return;
    _activeTab = t;
    writeStoredPodesavanjaTab(t);
    _renderShell();
    _loadActiveTabData(false).catch(e => console.warn('[podesavanja] popstate load', e));
  };
  window.addEventListener('popstate', _popstateHandler);
}

export function teardownPodesavanjaModule() {
  if (_authUnsubscribe) {
    _authUnsubscribe();
    _authUnsubscribe = null;
  }
  if (_popstateHandler) {
    window.removeEventListener('popstate', _popstateHandler);
    _popstateHandler = null;
  }
  _panelHtmlCache.clear();
  _loadedTabs.clear();
}

async function _loadActiveTabData(force) {
  const t = _activeTab;
  if (!force && _loadedTabs.has(t)) return;
  try {
    if (t === 'users') {
      await refreshUsers(force);
      _invalidatePanelCache('users');
    } else if (t === 'maint-profiles') {
      await refreshMaintProfiles();
      _invalidatePanelCache('maint-profiles');
    } else if (t === 'predmet-aktivacija') {
      await refreshPredmetAktivacija();
      _invalidatePanelCache('predmet-aktivacija');
    } else if (t === 'organizacija') {
      await refreshOrgStructure();
      _invalidatePanelCache('organizacija');
    } else if (t === 'masine') {
      await refreshMaintMachinesTab();
      _invalidatePanelCache('masine');
    } else if (t === 'audit-log') {
      await refreshSettingsAuditLog();
      _invalidatePanelCache('audit-log');
    }
    _loadedTabs.add(t);
  } catch (e) {
    console.warn('[podesavanja] tab load failed', t, e);
  }
  _updatePanelOnly();
}

function _renderShell() {
  if (!_mountEl) return;

  if (!canAccessPodesavanja()) {
    _mountEl.innerHTML = _lockedScreenHtml();
    _mountEl.querySelector('#podBackBtn')?.addEventListener('click', () => _onBackToHubCb?.());
    _mountEl.querySelector('#podLogoutBtn')?.addEventListener('click', () => _onLogoutCb?.());
    return;
  }

  const subtitle = TAB_SUBTITLES[_activeTab] || 'Podešavanja';
  const panelHtml = _getPanelHtml(_activeTab);

  _mountEl.innerHTML = `
    <div class="set-shell">
      ${_headerHtml()}
      <div class="set-layout">
        <nav class="set-sidebar" role="navigation" aria-label="Podešavanja navigacija">
          <div class="set-sidebar-header">
            <div class="set-sidebar-header-label">Podešavanja</div>
            <div class="set-sidebar-header-title">${escHtml(subtitle)}</div>
          </div>
          <div class="set-sidebar-items">
            ${_sidebarGroupsHtml()}
          </div>
          <div class="set-sidebar-footer">v 1.1 · build 2026.05</div>
        </nav>
        <div class="set-content" id="setContentPanel">${panelHtml}</div>
      </div>
    </div>
  `;

  _wireHeader();
  _wireSidebar();
  _wireTabBody();
}

function _updatePanelOnly() {
  const host = _mountEl?.querySelector('#setContentPanel');
  if (!host) return;
  host.innerHTML = _getPanelHtml(_activeTab);
  _wireTabBody();
}

function _getPanelHtml(tab) {
  if (_panelHtmlCache.has(tab) && tab !== 'users' && tab !== 'predmet-aktivacija') {
    return _panelHtmlCache.get(tab);
  }
  const html = _renderPanelFresh(tab);
  if (tab !== 'predmet-aktivacija') _panelHtmlCache.set(tab, html);
  return html;
}

function _renderPanelFresh(tab) {
  if (tab === 'users') return renderUsersTab();
  if (tab === 'organizacija') return renderOrgStructureTab();
  if (tab === 'maint-profiles') return renderMaintProfilesTab();
  if (tab === 'predmet-aktivacija') return renderPodesavanjePredmetaPanel();
  if (tab === 'masters') return renderMastersTab();
  if (tab === 'masine') return renderMasineTab();
  if (tab === 'uloge') return renderUlogeTab();
  if (tab === 'notifikacije') return renderNotifikacijeTab();
  if (tab === 'integracije') return renderIntegracijeTab();
  if (tab === 'audit-log') return renderAuditLogTab();
  if (tab === 'system') return renderSystemTab();
  return '';
}

function _sidebarGroupsHtml() {
  return _visibleGroups().map(g => `
    <div class="set-sidebar-group">
      <div class="set-sidebar-group-label">${escHtml(g.label)}</div>
      ${g.items.map(it => {
        const isActive = it.id === _activeTab;
        let badgeHtml = '';
        if (it.badgeKey) {
          const val = _badgeValue(it.badgeKey);
          if (val !== '') {
            badgeHtml = `<span class="set-sidebar-badge" id="setSidebarBadge-${escHtml(it.id)}">${val}</span>`;
          }
        }
        return `
          <button class="set-sidebar-item${isActive ? ' active' : ''}"
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
          <div class="auth-subtitle">Podešavanja su dostupna samo korisnicima sa <strong>admin</strong> ili <strong>menadžment</strong> rolom.</div>
        </div>
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
      if (!parsePodesavanjaTabFromLocation(t)) return;
      _activeTab = t;
      writeStoredPodesavanjaTab(t);
      syncPodesavanjaTabToUrl(t);
      _renderShell();
      _loadActiveTabData(false).catch(e => console.warn('[podesavanja] tab switch load', e));
    });
  });
}

function _wireTabBody() {
  const onUsersChange = () => {
    _invalidatePanelCache('users');
    _updatePanelOnly();
    _mountEl.querySelectorAll('#setSidebarBadge-users').forEach(b => {
      b.textContent = String(usersState.items.length);
    });
  };

  if (_activeTab === 'users') {
    wireUsersTab(_mountEl, { onChange: onUsersChange });
  }
  if (_activeTab === 'maint-profiles') {
    wireMaintProfilesTab(_mountEl, { onChange: () => {
      _invalidatePanelCache('maint-profiles');
      _updatePanelOnly();
    }});
  }
  if (_activeTab === 'predmet-aktivacija') {
    wirePodesavanjePredmetaPanel(_mountEl);
  }
  if (_activeTab === 'organizacija') {
    wireOrgStructureTab(_mountEl);
  }
  if (_activeTab === 'masine') {
    wireMasineTab(_mountEl);
  }
  if (_activeTab === 'uloge') wireUlogeTab(_mountEl);
  if (_activeTab === 'notifikacije') wireNotifikacijeTab(_mountEl);
  if (_activeTab === 'integracije') wireIntegracijeTab(_mountEl);
  if (_activeTab === 'audit-log') {
    wireAuditLogTab(_mountEl, {
      onRefresh: () => {
        _invalidatePanelCache('audit-log');
        _updatePanelOnly();
      },
    });
  }
  if (_activeTab === 'system') wireSystemTab(_mountEl);
}
