/**
 * Generički offline queue za Kadrovska mutacije (Faza K8).
 *
 * Pattern je isti kao `offlineQueue.js` (mobilni modul lokacija): kada
 * korisnik napravi mutaciju a nema mreže, payload se upisuje u localStorage
 * i automatski flush-uje kad se WiFi vrati ili kad korisnik klikne badge.
 *
 * Razlika u odnosu na lokacije:
 *  - Mutacije idu kroz Supabase REST (ne RPC), pa zapis sadrži:
 *      { kind: 'POST'|'PATCH'|'DELETE', path: 'kadr_certificates?id=eq.…',
 *        body: <json> }
 *  - Idempotentnost: PATCH/DELETE su idempotentni; POST nije, pa se
 *    enqueue-uje SAMO ako developer eksplicitno pozove `kadrEnqueue` —
 *    ne pravimo automatske wrappere oko svih save funkcija.
 *
 * Tipičan use-case:
 *   if (!getIsOnline()) {
 *     kadrEnqueue({ kind: 'PATCH', path: `employees?id=eq.${id}`, body: payload });
 *     return; // UI optimistically updates state
 *   }
 *   await sbReq(path, 'PATCH', body);
 */

import { sbReq } from './supabase.js';

const STORAGE_KEY = 'kadr.offlineQueue.v1';
const MAX_QUEUE_SIZE = 200;
const MAX_ATTEMPTS = 8;

function readQueue() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const arr = JSON.parse(raw);
    return Array.isArray(arr) ? arr : [];
  } catch {
    try { localStorage.removeItem(STORAGE_KEY); } catch {}
    return [];
  }
}

function writeQueue(queue) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(queue));
  } catch (e) {
    console.error('[kadrOfflineQueue] write failed', e);
  }
}

function genId() {
  return 'KQ-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8);
}

/**
 * Ubaci kadrovska mutaciju u queue.
 * @param {{kind: 'POST'|'PATCH'|'DELETE', path: string, body?: any, label?: string}} entry
 */
export function kadrEnqueue(entry) {
  if (!entry || !entry.kind || !entry.path) {
    throw new Error('kadrEnqueue: payload mora imati kind + path');
  }
  if (!['POST', 'PATCH', 'DELETE'].includes(entry.kind)) {
    throw new Error('kadrEnqueue: nepoznat kind ' + entry.kind);
  }
  const queue = readQueue();
  if (queue.length >= MAX_QUEUE_SIZE) {
    throw new Error(`Queue pun (${MAX_QUEUE_SIZE}) — sinhronizuj postojeće pre novog unosa.`);
  }
  const e = {
    id: genId(),
    createdAt: new Date().toISOString(),
    attempts: 0,
    lastError: null,
    label: entry.label || `${entry.kind} ${entry.path.split('?')[0]}`,
    kind: entry.kind,
    path: entry.path,
    body: entry.body == null ? null : entry.body,
  };
  queue.push(e);
  writeQueue(queue);
  return e;
}

export function listKadrPending() {
  return readQueue();
}

export function countKadrPending() {
  return readQueue().length;
}

export function clearKadrPending() {
  try { localStorage.removeItem(STORAGE_KEY); } catch {}
}

function persistEntry(entry) {
  const queue = readQueue();
  const idx = queue.findIndex(x => x.id === entry.id);
  if (idx >= 0) { queue[idx] = entry; writeQueue(queue); }
}

function removeEntry(id) {
  const queue = readQueue();
  const next = queue.filter(e => e.id !== id);
  if (next.length !== queue.length) writeQueue(next);
}

/**
 * Pokušaj flush svih zapisa. Pri success = uklanja iz queue-a.
 * Failed (mreža) → ostaje za sledeći retry. MAX_ATTEMPTS → drop u dead letter (console).
 *
 * @returns {Promise<{ok:number,failed:number,dropped:number}>}
 */
export async function flushKadrPending() {
  const queue = readQueue();
  let ok = 0, failed = 0, dropped = 0;
  for (const entry of queue) {
    if (entry.attempts >= MAX_ATTEMPTS) {
      console.error('[kadrOfflineQueue] dropping (max attempts)', entry);
      removeEntry(entry.id);
      dropped += 1;
      continue;
    }
    entry.attempts += 1;
    try {
      const res = await sbReq(entry.path, entry.kind, entry.body);
      if (res !== null) {
        removeEntry(entry.id);
        ok += 1;
      } else {
        entry.lastError = 'sbReq returned null';
        persistEntry(entry);
        failed += 1;
      }
    } catch (e) {
      entry.lastError = (e && e.message) || String(e);
      persistEntry(entry);
      failed += 1;
    }
  }
  return { ok, failed, dropped };
}

let _wired = false;
/**
 * Instalira `online` event listener — automatski flush-uje kad se vrati mreža.
 * Idempotentno. Pozvati jednom u app bootstrap-u (npr. `services/kadrovska.js`).
 */
export function installKadrAutoFlush() {
  if (_wired) return;
  _wired = true;
  window.addEventListener('online', async () => {
    if (countKadrPending() === 0) return;
    try { await flushKadrPending(); } catch (e) {
      console.error('[kadrOfflineQueue] auto-flush failed', e);
    }
  });
}
