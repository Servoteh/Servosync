/**
 * Globalno stanje Plan Montaže modula.
 *
 * Čuva ono što UI rendereri (Faza 5) iznova čitaju:
 *  - allData {projects: []}
 *  - activeProjectId / activeWpId / activeView
 *  - locationColorMap (perzistira u localStorage)
 *  - phaseModels sidecar (3D model meta, perzistira u localStorage)
 *  - selectedDateIndices (gantt vertical column selection)
 *  - totalGanttFilters
 *  - showFinishedInGantt toggle (perzistira)
 *  - expandedMobileCards (Set ID-jeva otvorenih mobilnih kartica)
 *
 * Sve perzistencije su lazy: čitaju se prilikom prvog importa.
 */

import { lsGetJSON, lsSetJSON, lsGet, lsSet } from '../lib/storage.js';
import { STORAGE_KEYS } from '../lib/constants.js';

/* ── Glavni in-memory state ── */
export const allData = { projects: [] };

export const planMontazeState = {
  allData,
  activeProjectId: null,
  activeWpId: null,
  /** 'plan' | 'gantt' | 'total' | 'calendar' */
  activeView: 'plan',
  /** Filtrovani indeksi faza ili null. */
  filteredIndices: null,
  /** Async race protection za switchProject. */
  activeProjectLoadToken: 0,
  /** Save debouncing timers. */
  projectSaveTimer: null,
  wpSyncTimer: null,
  phaseSaveTimers: new Map(),
};

/* ── Persisted: Location → boja ── */
export let locationColorMap = lsGetJSON(STORAGE_KEYS.LOC_COLOR, {}) || {};

export function persistLocationColorMap() {
  lsSetJSON(STORAGE_KEYS.LOC_COLOR, locationColorMap);
}

export function setLocationColor(location, color) {
  locationColorMap[location] = color;
  persistLocationColorMap();
}

/* ── Persisted: Phase 3D model sidecar ── */
export let phaseModels = lsGetJSON(STORAGE_KEYS.PHASE_MODEL, {}) || {};

export function persistPhaseModels() {
  lsSetJSON(STORAGE_KEYS.PHASE_MODEL, phaseModels);
}

export function setPhaseModel(phaseId, model) {
  phaseModels[phaseId] = model;
  persistPhaseModels();
}

/* ── Mobile expand state (NIJE perzistovan — samo session in-memory) ── */
export const expandedMobileCards = new Set();

/* ── Selekcija vertikale u Gantu (po view-u) ── */
export const selectedDateIndices = {
  gantt: new Set(),
  total: new Set(),
};
export const lastSelectedDateIndex = {
  gantt: null,
  total: null,
};

/* ── Total Gantt filteri ── */
export const totalGanttFilters = {
  loc: '',
  lead: '',
  engineer: '',
  projectId: '',
  dateFrom: '',
  dateTo: '',
};

/* ── Gantt: Prikaži završene faze (persisted bool) ── */
export let showFinishedInGantt = lsGet(STORAGE_KEYS.GANTT_SHOW_DONE) === '1';

export function setShowFinishedInGantt(v) {
  showFinishedInGantt = !!v;
  lsSet(STORAGE_KEYS.GANTT_SHOW_DONE, showFinishedInGantt ? '1' : '0');
}

/* ── Gantt drag session (transient) ── */
export const dragState = {
  current: null, // {ri, wpId, projectId, mode, originX, ...} ili null
};

/* ── Lokalni cache fallback (offline mode) ── */
export function loadLocalCache() {
  return lsGetJSON(STORAGE_KEYS.LOCAL, null);
}
export function persistLocalCache(data) {
  lsSetJSON(STORAGE_KEYS.LOCAL, data);
}

/* ── Helpers za aktivni projekat / WP / faze ── */
export function getActiveProject() {
  if (!planMontazeState.activeProjectId) return null;
  return allData.projects.find(p => p.id === planMontazeState.activeProjectId) || null;
}

export function getActiveWP() {
  const p = getActiveProject();
  if (!p) return null;
  return p.workPackages.find(w => w.id === planMontazeState.activeWpId) || null;
}

export function getActivePhases() {
  return getActiveWP()?.phases || [];
}

export function setActiveProject(projectId) {
  planMontazeState.activeProjectId = projectId;
}

export function setActiveWp(wpId) {
  planMontazeState.activeWpId = wpId;
}

export function setActiveView(view) {
  planMontazeState.activeView = view;
}
