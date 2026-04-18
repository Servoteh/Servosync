/**
 * Plan Montaže — Supabase orchestrator + debounced save queue.
 *
 * UI moduli treba da koriste samo ove visoke API-je, a ne `projects.js`
 * direktno (osim za map/build helpere). Ovde su:
 *   - fetchAllProjectsHierarchy(): kompletan load svih projekata sa WP-ovima
 *     i fazama (replace `allData.projects`).
 *   - queueProjectSave(), queuePhaseSaveByIndex(i), queueCurrentWpSync():
 *     debounce kao u legacy (SAVE_DEBOUNCE_MS).
 *   - saveAllCurrentPhases(): forsirani upsert svih faza aktivnog WP-a.
 *
 * Race protection: switchProject može da bude prekinut tokom load-a; UI sloj
 * koristi `planMontazeState.activeProjectLoadToken` da odbaci stari rezultat.
 */

import { sbReq } from './supabase.js';
import {
  loadProjectsFromDb,
  loadAllProjectData,
  saveProjectToDb,
  saveWorkPackageToDb,
  savePhaseToDb,
  deletePhaseFromDb,
  deleteWorkPackageFromDb,
  deleteProjectFromDb,
} from './projects.js';
import { canEdit, getIsOnline } from '../state/auth.js';
import {
  allData,
  planMontazeState,
  getActiveProject,
  getActiveWP,
  getActivePhases,
  ensureProjectLocations,
  ensureLocationColorsForProjects,
  ensurePeopleFromProjects,
  persistState,
} from '../state/planMontaze.js';
import { SAVE_DEBOUNCE_MS } from '../lib/constants.js';

/* ── LOAD: kompletna hijerarhija projects → WP → phases ──────────────── */

/**
 * Učitaj sve projekte iz baze + njihove WP-ove i faze. Replace-uje
 * `allData.projects`. Vraća true ako je sve uspelo, false ako je makar jedan
 * korak vratio null. UI treba posle ovoga da pozove `cacheToLocal` ekvivalent
 * (`persistState`).
 */
export async function fetchAllProjectsHierarchy() {
  if (!getIsOnline()) return false;
  const projects = await loadProjectsFromDb();
  if (!projects) return false;
  for (const p of projects) {
    const wps = await loadAllProjectData(p.id);
    p.workPackages = wps || [];
  }
  /* Replace allData.projects in place tako da getteri vide novi state. */
  allData.projects.length = 0;
  projects.forEach(p => allData.projects.push(p));
  allData.projects.forEach(ensureProjectLocations);
  ensureLocationColorsForProjects();
  ensurePeopleFromProjects();
  persistState();
  return true;
}

/* ── SAVE QUEUE: debounce upsert ─────────────────────────────────────── */

/**
 * Debouncedi save aktivnog projekta (project meta polja). Više uzastopnih
 * editova → jedan POST nakon mirovanja od SAVE_DEBOUNCE_MS.
 */
export function queueProjectSave() {
  if (!getIsOnline() || !canEdit()) return;
  if (planMontazeState.projectSaveTimer) {
    clearTimeout(planMontazeState.projectSaveTimer);
  }
  planMontazeState.projectSaveTimer = setTimeout(async () => {
    const proj = getActiveProject();
    if (proj) await saveProjectToDb(proj);
    planMontazeState.projectSaveTimer = null;
  }, SAVE_DEBOUNCE_MS);
}

/**
 * Debouncedi save jedne faze po indeksu u aktivnom WP. Race-safe: u trenutku
 * stvarnog snimanja, posebno se traži živa faza preko ID-a, jer se može
 * dogoditi da se redosled u međuvremenu promenio.
 */
export function queuePhaseSaveByIndex(i) {
  if (!getIsOnline() || !canEdit()) return;
  const proj = getActiveProject();
  const wp = getActiveWP();
  const ph = getActivePhases()[i];
  if (!proj || !wp || !ph?.id) return;
  const existing = planMontazeState.phaseSaveTimers.get(ph.id);
  if (existing) clearTimeout(existing);
  const timer = setTimeout(async () => {
    const liveProj = getActiveProject();
    const liveWp = getActiveWP();
    if (!liveProj || !liveWp) return;
    const liveIndex = liveWp.phases.findIndex(x => x.id === ph.id);
    if (liveIndex === -1) return;
    await savePhaseToDb(liveWp.phases[liveIndex], liveProj.id, liveWp.id, liveIndex);
    planMontazeState.phaseSaveTimers.delete(ph.id);
  }, SAVE_DEBOUNCE_MS);
  planMontazeState.phaseSaveTimers.set(ph.id, timer);
}

/**
 * Debouncedi sync celog aktivnog WP-a (struktura + sve faze) — koristi se
 * posle reorder-a / dodavanja / brisanja faze.
 */
export function queueCurrentWpSync() {
  if (!getIsOnline() || !canEdit()) return;
  if (planMontazeState.wpSyncTimer) clearTimeout(planMontazeState.wpSyncTimer);
  planMontazeState.wpSyncTimer = setTimeout(async () => {
    await saveAllCurrentPhases();
    planMontazeState.wpSyncTimer = null;
  }, SAVE_DEBOUNCE_MS);
}

/** Forsiran upsert svih faza iz aktivnog WP-a (sekvencijalno). */
export async function saveAllCurrentPhases() {
  if (!getIsOnline() || !canEdit()) return;
  const p = getActiveProject();
  const wp = getActiveWP();
  if (!p || !wp) return;
  for (let i = 0; i < wp.phases.length; i++) {
    await savePhaseToDb(wp.phases[i], p.id, wp.id, i);
  }
}

/* ── DELETE wrappers — UI poziva ove, ne direktno services/projects.js ─ */

export async function deletePhaseAndPersist(phaseId) {
  if (!phaseId) return;
  await deletePhaseFromDb(phaseId);
}

export async function deleteWorkPackageAndPersist(wpId) {
  if (!wpId) return;
  await deleteWorkPackageFromDb(wpId);
}

export async function deleteProjectAndPersist(projectId) {
  if (!projectId) return;
  await deleteProjectFromDb(projectId);
}

/* ── Reminder (basic skeleton — ujedinjuje legacy buildReminderPayload) ─ */

export async function callReminderEndpoint(buildPayloadFn) {
  if (!canEdit()) return { ok: false, reason: 'forbidden' };
  const payload = buildPayloadFn ? buildPayloadFn() : [];
  if (!payload.length) return { ok: true, sent: 0, empty: true };
  if (!getIsOnline()) {
    console.log('Reminder payload:', payload);
    return { ok: true, sent: payload.length, offline: true };
  }
  /* Edge functions endpoint — Authorization je već default kroz sbReq, ali
     Edge Functions koriste poseban path /functions/v1, pa idemo direktno. */
  try {
    const res = await sbReq('rpc/send_reminders', 'POST', { alerts: payload });
    return { ok: !!res, sent: payload.length };
  } catch (e) {
    return { ok: false, reason: 'network', error: String(e) };
  }
}
