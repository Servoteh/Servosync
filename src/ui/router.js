/**
 * Mini router — bira koji "screen" se renderuje u root mount-u.
 *
 * Stanja (nisu URL-routes — apliakacija je SPA bez hash routing-a, kao i
 * legacy/index.html):
 *   'login'          — auth overlay (renderLoginScreen)
 *   'hub'            — module hub
 *   'plan-montaze'   — placeholder (Faza 5)
 *   'kadrovska'      — placeholder (Faza 4)
 *   'podesavanja'    — placeholder (Faza 5b)
 *
 * Aktivni modul se persistuje u sessionStorage pod SESSION_KEYS.MODULE_HUB
 * (isti ključ kao legacy → omogućava da F5 cutover ne resetuje aktivni tab).
 */

import { ssGet, ssSet, ssRemove } from '../lib/storage.js';
import { SESSION_KEYS } from '../lib/constants.js';
import { initTheme } from '../lib/theme.js';
import { renderLoginScreen } from './auth/loginScreen.js';
import { renderModuleHub } from './hub/moduleHub.js';
import { renderModulePlaceholder } from './modulePlaceholder.js';
import { getAuth, canAccessKadrovska, canManageUsers } from '../state/auth.js';
import { resetKadrovskaState } from '../state/kadrovska.js';
import { showToast } from '../lib/dom.js';
import { loadAndApplyUserRole } from '../services/userRoles.js';

const MODULES = ['plan-montaze', 'kadrovska', 'podesavanja'];

let mountEl = null;
let currentScreen = null;

function clearMount() {
  if (mountEl) mountEl.innerHTML = '';
  document.body.classList.remove('hub-active', 'kadrovska-active');
}

function getStoredModule() {
  return ssGet(SESSION_KEYS.MODULE_HUB, null);
}
function setStoredModule(mod) {
  if (mod) ssSet(SESSION_KEYS.MODULE_HUB, mod);
  else ssRemove(SESSION_KEYS.MODULE_HUB);
}

/* ── Screen renderers ── */

function showLogin() {
  currentScreen = 'login';
  clearMount();
  setStoredModule(null);
  const screen = renderLoginScreen({
    onLoginSuccess: async () => {
      /* Posle login-a: skoči na role lookup, pa hub. */
      const auth = getAuth();
      if (auth.user && auth.isOnline) {
        await loadAndApplyUserRole();
      }
      restoreOrShowHub();
    },
  });
  mountEl.appendChild(screen);
}

function showHub() {
  currentScreen = 'hub';
  clearMount();
  document.body.classList.add('hub-active');
  setStoredModule(null);
  const screen = renderModuleHub({
    onModuleSelect: (moduleId) => navigateToModule(moduleId),
    onLogout: () => {
      resetKadrovskaState();
      showLogin();
    },
  });
  mountEl.appendChild(screen);
}

function showModulePlaceholder(moduleId) {
  currentScreen = moduleId;
  clearMount();
  if (moduleId === 'kadrovska') {
    document.body.classList.add('kadrovska-active');
  }
  setStoredModule(moduleId);
  const screen = renderModulePlaceholder({
    moduleId,
    onBack: () => showHub(),
    onLogout: () => {
      resetKadrovskaState();
      showLogin();
    },
  });
  mountEl.appendChild(screen);
}

/* ── Navigation guards ── */

function navigateToModule(moduleId) {
  if (!MODULES.includes(moduleId)) {
    showToast('⚠ Nepoznat modul: ' + moduleId);
    return;
  }
  if (moduleId === 'kadrovska' && !canAccessKadrovska()) {
    showToast('🔒 Kadrovska je dostupna samo HR/admin korisnicima');
    return;
  }
  if (moduleId === 'podesavanja' && !canManageUsers()) {
    showToast('🔒 Podešavanja su dostupna samo admin korisnicima');
    return;
  }
  showModulePlaceholder(moduleId);
}

/** Posle login-a — vrati korisnika na poslednji aktivan modul, ili na hub. */
function restoreOrShowHub() {
  const last = getStoredModule();
  if (last && MODULES.includes(last)) {
    if (last === 'kadrovska' && !canAccessKadrovska()) return showHub();
    if (last === 'podesavanja' && !canManageUsers()) return showHub();
    return showModulePlaceholder(last);
  }
  showHub();
}

/* ── Public API ── */

export function initRouter(rootEl) {
  if (!rootEl) throw new Error('initRouter: rootEl je obavezan');
  mountEl = rootEl;
  initTheme();

  const auth = getAuth();
  if (auth.user) {
    /* Već smo ulogovani (restoreSession u bootstrap-u je uspeo). */
    restoreOrShowHub();
  } else {
    showLogin();
  }
}

export function getCurrentScreen() {
  return currentScreen;
}

/** Ručno (npr. iz logout call-back-a) — vrati na login. */
export function navigateToLogin() {
  showLogin();
}
