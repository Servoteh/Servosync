/**
 * Sastanci modul — module-local state.
 *
 * Pattern parity sa state/kadrovska.js — singleton state objekat sa
 * resetSastanciState() koji router zove pri logout-u.
 */

import { SESSION_KEYS } from '../lib/constants.js';

const state = {
  /* Cache projekata (lite verzija {id, label}) — koristi ga PM Teme select. */
  projektiCache: null,
  projektiCacheAt: 0,
  /* Aktivni tab kroz reload — sessionStorage. */
  activeTab: 'dashboard',
  /* Trenutno otvoren sastanak (kad je u modal-u/stranici). */
  openSastanakId: null,
};

const PROJEKTI_TTL = 60 * 1000; // 60s

export function getSastanciState() {
  return state;
}

export function getProjektiCache() {
  if (!state.projektiCache) return null;
  if (Date.now() - state.projektiCacheAt > PROJEKTI_TTL) return null;
  return state.projektiCache;
}

export function setProjektiCache(arr) {
  state.projektiCache = arr;
  state.projektiCacheAt = Date.now();
}

export function clearProjektiCache() {
  state.projektiCache = null;
  state.projektiCacheAt = 0;
}

export function setActiveTab(tab) {
  state.activeTab = tab;
}

export function setOpenSastanak(id) {
  state.openSastanakId = id;
}

/** Lista / kalendar u tabu Sastanci (sessionStorage). */
export function getSastSastanView() {
  try {
    return sessionStorage.getItem(SESSION_KEYS.SAST_SASTANCI_VIEW) || 'lista';
  } catch {
    return 'lista';
  }
}

export function resetSastanciState() {
  state.projektiCache = null;
  state.projektiCacheAt = 0;
  state.activeTab = 'dashboard';
  state.openSastanakId = null;
}
