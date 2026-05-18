/**
 * Podešavanja — tab ID-jevi, deep link (#tab= / ?tab=), sessionStorage migracija.
 */

import { SESSION_KEYS } from './constants.js';
import { ssGet, ssSet } from './storage.js';

/** @typedef {'users'|'uloge'|'organizacija'|'masters'|'masine'|'maint-profiles'|'predmet-aktivacija'|'notifikacije'|'integracije'|'audit-log'|'system'} PodesavanjaTabId */

/** Svi poznati tab ID-jevi (uključujući „uskoro“ pod menijem). */
export const PODESAVANJA_TAB_IDS = Object.freeze([
  'users',
  'uloge',
  'organizacija',
  'masters',
  'masine',
  'maint-profiles',
  'predmet-aktivacija',
  'notifikacije',
  'integracije',
  'audit-log',
  'system',
]);

const LEGACY_SETTINGS_TAB_KEY = 'plan_montaze_v51_settings_tab';

/**
 * Čita sačuvani tab: novi ključ → legacy ključ → default.
 * @param {string} [fallback='users']
 * @returns {string}
 */
export function readStoredPodesavanjaTab(fallback = 'users') {
  const v2 = ssGet(SESSION_KEYS.SETTINGS_TAB, null);
  if (v2 && PODESAVANJA_TAB_IDS.includes(v2)) return v2;
  try {
    const leg = sessionStorage.getItem(LEGACY_SETTINGS_TAB_KEY);
    if (leg && PODESAVANJA_TAB_IDS.includes(leg)) {
      ssSet(SESSION_KEYS.SETTINGS_TAB, leg);
      return leg;
    }
  } catch {
    /* ignore */
  }
  return fallback;
}

/**
 * @param {string} tab
 */
export function writeStoredPodesavanjaTab(tab) {
  ssSet(SESSION_KEYS.SETTINGS_TAB, tab);
}

/**
 * @param {string|undefined|null} raw
 * @returns {string|null}
 */
export function parsePodesavanjaTabFromLocation(raw) {
  const t = String(raw || '').trim();
  if (!t) return null;
  return PODESAVANJA_TAB_IDS.includes(t) ? t : null;
}

/**
 * Hash (#tab=users) ima prednost nad query (?tab=users).
 * @returns {string|null}
 */
export function getPodesavanjaTabFromUrl() {
  if (typeof window === 'undefined') return null;
  try {
    const hash = window.location.hash || '';
    const hm = /^#tab=([a-z0-9-]+)$/i.exec(hash);
    if (hm) return parsePodesavanjaTabFromLocation(hm[1]);
    const q = new URLSearchParams(window.location.search || '');
    return parsePodesavanjaTabFromLocation(q.get('tab'));
  } catch {
    return null;
  }
}

/**
 * @param {string} tab
 * @param {{ replace?: boolean }} [opts]
 */
export function syncPodesavanjaTabToUrl(tab, opts = {}) {
  if (typeof window === 'undefined') return;
  const valid = parsePodesavanjaTabFromLocation(tab);
  if (!valid) return;
  const path = '/podesavanja';
  const search = `?tab=${encodeURIComponent(valid)}`;
  const url = path + search;
  const cur = window.location.pathname.replace(/\/$/, '') || '/';
  const curTab = getPodesavanjaTabFromUrl();
  if (cur === path && curTab === valid && window.location.search === search) return;
  const state = { podesavanjaTab: valid };
  if (opts.replace) {
    window.history.replaceState(state, '', url);
  } else {
    window.history.pushState(state, '', url);
  }
}

/**
 * @param {string} tab
 * @returns {string}
 */
export function buildPodesavanjaModulePath(tab = null) {
  const base = '/podesavanja';
  const valid = parsePodesavanjaTabFromLocation(tab);
  if (!valid) return base;
  return `${base}?tab=${encodeURIComponent(valid)}`;
}
