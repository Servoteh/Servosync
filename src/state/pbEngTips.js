/**
 * PB Saveti — pub/sub state (filter, lista, kategorije).
 */

import { SESSION_KEYS } from '../lib/constants.js';
import { ssGet, ssSet } from '../lib/storage.js';

const DEFAULT_FILTER = Object.freeze({
  search: '',
  categoryIds: [],
  tags: [],
  myOnly: false,
  includeDrafts: false,
  sort: 'recent',
});

function readPersistedFilter() {
  const raw = ssGet(SESSION_KEYS.PB_ENG_TIPS_FILTER, null);
  if (!raw) return { ...DEFAULT_FILTER };
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return { ...DEFAULT_FILTER };
    return {
      ...DEFAULT_FILTER,
      categoryIds: Array.isArray(parsed.categoryIds) ? parsed.categoryIds : [],
      tags: Array.isArray(parsed.tags) ? parsed.tags : [],
      myOnly: !!parsed.myOnly,
      includeDrafts: !!parsed.includeDrafts,
      sort: parsed.sort === 'popular' ? 'popular' : 'recent',
      search: '',
    };
  } catch {
    return { ...DEFAULT_FILTER };
  }
}

function writePersistedFilter(filter) {
  const { search, ...rest } = filter;
  try {
    ssSet(SESSION_KEYS.PB_ENG_TIPS_FILTER, JSON.stringify(rest));
  } catch { /* noop */ }
}

const state = {
  categories: [],
  tips: [],
  filter: readPersistedFilter(),
  loading: false,
  error: null,
  selectedTipId: null,
  canWrite: false,
};

const listeners = new Set();

function emit() {
  for (const fn of listeners) {
    try {
      fn(snapshotEngTips());
    } catch (e) {
      console.warn('[pbEngTips] listener failed', e);
    }
  }
}

export function subscribeEngTips(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function snapshotEngTips() {
  return {
    ...state,
    filter: { ...state.filter },
    categories: [...state.categories],
    tips: [...state.tips],
  };
}

export function setEngTipsFilter(patch) {
  state.filter = { ...state.filter, ...patch };
  writePersistedFilter(state.filter);
  emit();
}

export function setEngTips(tips) {
  state.tips = Array.isArray(tips) ? tips : [];
  emit();
}

export function setEngTipCategories(cats) {
  state.categories = Array.isArray(cats) ? cats : [];
  emit();
}

export function setEngTipsLoading(b) {
  state.loading = !!b;
  emit();
}

export function setEngTipsError(err) {
  state.error = err ?? null;
  emit();
}

export function setSelectedTipId(id) {
  state.selectedTipId = id ?? null;
  emit();
}

export function setEngTipsCanWrite(b) {
  state.canWrite = !!b;
  emit();
}

export function resetEngTipsState() {
  state.categories = [];
  state.tips = [];
  state.filter = { ...DEFAULT_FILTER };
  state.loading = false;
  state.error = null;
  state.selectedTipId = null;
  state.canWrite = false;
  emit();
}

/** Registrovan iz savetiTab — otvara punostrani editor u tabu. */
let _openSavetiEditor = null;

export function registerSavetiEditorOpener(fn) {
  _openSavetiEditor = typeof fn === 'function' ? fn : null;
}

export function openSavetiTipEditor(opts) {
  _openSavetiEditor?.(opts);
}
