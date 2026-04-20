/**
 * Lokalni UI state za modul Lokacije delova (aktivni tab).
 */

import { lsGetJSON, lsSetJSON } from '../lib/storage.js';
import { STORAGE_KEYS } from '../lib/constants.js';

/* Whitelist legitimnih tab ID-jeva — sprečava da korumpirana LS vrednost dovede
 * do praznog panela (renderPanel ima if-grane po tabId-u). */
const VALID_TABS = new Set(['dashboard', 'browse', 'items', 'sync']);
const DEFAULT_TAB = 'dashboard';

/* Veličine stranice za items paginator — striktan whitelist da se LS ne koristi kao XSS vektor. */
const VALID_PAGE_SIZES = new Set([25, 50, 100, 250]);
const DEFAULT_PAGE_SIZE = 50;

const state = {
  activeTab: DEFAULT_TAB,
  browseFilter: '',
  itemsFilter: '',
  itemsPage: 0,
  itemsPageSize: DEFAULT_PAGE_SIZE,
};

function normalizeTab(v) {
  return typeof v === 'string' && VALID_TABS.has(v) ? v : DEFAULT_TAB;
}

function normalizeFilter(v) {
  if (typeof v !== 'string') return '';
  /* Ograničavamo dužinu i strippujemo kontrol znakove. */
  return v.replace(/[\x00-\x1f\x7f]/g, '').slice(0, 120);
}

function normalizePageSize(v) {
  const n = Number(v);
  return VALID_PAGE_SIZES.has(n) ? n : DEFAULT_PAGE_SIZE;
}

export function getLokacijeUiState() {
  return { ...state };
}

export function setLokacijeActiveTab(tabId) {
  state.activeTab = normalizeTab(tabId);
  lsSetJSON(STORAGE_KEYS.LOC_TAB, state.activeTab);
}

export function loadLokacijeTabFromStorage() {
  const v = lsGetJSON(STORAGE_KEYS.LOC_TAB, null);
  state.activeTab = normalizeTab(v);
}

export function setBrowseFilter(v) {
  state.browseFilter = normalizeFilter(v);
}

export function setItemsFilter(v) {
  state.itemsFilter = normalizeFilter(v);
  /* Pri promeni filtera reset paginacije je očekivano UX ponašanje. */
  state.itemsPage = 0;
}

export function setItemsPage(n) {
  const p = Math.max(0, Number(n) || 0);
  state.itemsPage = p;
}

export function setItemsPageSize(n) {
  state.itemsPageSize = normalizePageSize(n);
  state.itemsPage = 0;
}
