/**
 * Tanki HTTP wrapper nad Supabase REST/RPC API-jem.
 *
 * Ekvivalent legacy `sbReq()`:
 *  - bez framework-a, bez supabase-js zavisnosti
 *  - pre poziva: ensureSessionFresh() osvežava istekli JWT preko refresh_token-a iz sesije;
 *    uz 401 „JWT expired" jedan ponavljan poziva refreshSessionNow().
 *  - Prefer header za UPSERT (POST → merge-duplicates) i RETURN=representation
 *
 * Vraća parsiran JSON, ili `null` na BILO KOJU grešku (HTTP, parse, mreža).
 * Zovi-strane (services) se OSLANJAJU na ovo: `null` znači "nije uspelo".
 */

import { SUPABASE_CONFIG, hasSupabaseConfig } from '../lib/constants.js';
import { getCurrentUser } from '../state/auth.js';
import { ensureSessionFresh, refreshSessionNow } from './auth.js';

export { hasSupabaseConfig };

function isJwtExpiredBody(txt) {
  const raw = String(txt || '').trim().toLowerCase();
  if (raw.includes('jwt expired') || raw.includes('token expired')) return true;
  try {
    const j = JSON.parse(txt);
    const m = String(j?.message || '').toLowerCase();
    return m.includes('jwt expired') || m.includes('token expired');
  } catch {
    return false;
  }
}

/** Skraćeno telo odgovora za konzolu (PostgREST JSON ili plain tekst). */
function sbErrBodySnippet(txt, max = 700) {
  const s = (txt ?? '').trim();
  if (!s) return '(prazno telo)';
  try {
    const j = JSON.parse(s);
    if (j && typeof j === 'object') {
      const parts = ['message', 'code', 'details', 'hint']
        .map(k => (j[k] != null && String(j[k]).trim() !== '' ? `${k}=${String(j[k]).slice(0, 200)}` : null))
        .filter(Boolean);
      if (parts.length) return parts.join(' | ');
    }
  } catch {
    /* plain tekst */
  }
  return s.length <= max ? s : `${s.slice(0, max)}…`;
}

export function getSupabaseUrl() {
  return SUPABASE_CONFIG.url;
}

export function getSupabaseAnonKey() {
  return SUPABASE_CONFIG.anonKey;
}

/** Auth headers za direktne fetch pozive (Storage API itd.). */
export function getSupabaseHeaders() {
  const user = getCurrentUser();
  const token = user?._token || SUPABASE_CONFIG.anonKey;
  return {
    'apikey': SUPABASE_CONFIG.anonKey,
    'Authorization': 'Bearer ' + token,
  };
}

/**
 * @param {string} path     PostgREST putanja BEZ vodećeg slash-a, npr. 'employees?select=*'
 *                          ili 'rpc/get_my_user_roles' za RPC.
 * @param {'GET'|'POST'|'PATCH'|'DELETE'} [method='GET']
 * @param {object|null} [body=null]
 * @param {{ upsert?: boolean, withCount?: boolean }} [options]
 *        `upsert` (default `true`) — na POST pridružuje `resolution=merge-duplicates`
 *        kako bi UNIQUE konflikti odradili UPSERT; prosledi `false` kada želiš
 *        klasičan INSERT koji na duplikat vraća 409 (npr. kreiranje master zapisa).
 *        `withCount` — kada je `true` koristi internu grananu varijantu koja
 *        vraća `{ rows, total }`. NE koristi ovo sa sbReq direktno; postoji
 *        {@link sbReqWithCount} wrapper radi type-safety.
 * @returns {Promise<any|null>}
 */
export async function sbReq(path, method = 'GET', body = null, options = {}) {
  if (!hasSupabaseConfig()) return options.withCount ? { rows: null, total: null } : null;

  try {
    await ensureSessionFresh();

    let r;
    let txt;
    for (let attempt = 0; attempt < 2; attempt++) {
      const userNow = getCurrentUser();
      const token = userNow?._token || SUPABASE_CONFIG.anonKey;

      const headers = {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_CONFIG.anonKey,
        'Authorization': 'Bearer ' + token,
      };
      if (method === 'POST') {
        const upsert = options.upsert !== false;
        headers['Prefer'] = upsert
          ? 'return=representation,resolution=merge-duplicates'
          : 'return=representation';
      } else if (method === 'PATCH') {
        headers['Prefer'] = 'return=representation';
      }
      if (options.withCount && method === 'GET') {
        headers['Prefer'] = (headers['Prefer'] ? headers['Prefer'] + ',' : '') + 'count=exact';
      }

      const url = SUPABASE_CONFIG.url + '/rest/v1/' + path;
      const init = {
        method,
        headers,
        body: body ? JSON.stringify(body) : undefined,
      };
      /* Härd-4 (L21): podrška za AbortController. Pozivaoc može da prosledi
       * `options.signal` (npr. iz predmetTab-a sa 30s timeout-om). fetch baca
       * `AbortError` koji se propagira kroz `throw` ispod. */
      if (options.signal && typeof options.signal === 'object') {
        init.signal = options.signal;
      }
      /*
       * Transient „Failed to fetch“ (offline trenutni pad, flaky WiFi/CORS-proxy):
       * ponovi samo idempotent GET da ne rizikuje dupli POST/PATCH ako je server zapravo obrađio.
       */
      const GET_RETRIES = 3;
      const sleep = ms => new Promise(res => setTimeout(res, ms));
      /* eslint-disable no-await-in-loop */
      for (let fetchTry = 0; fetchTry < GET_RETRIES; fetchTry++) {
        try {
          r = await fetch(url, init);
          txt = await r.text();
          break;
        } catch (fe) {
          const canRetry = method === 'GET' && fetchTry < GET_RETRIES - 1;
          if (canRetry) {
            await sleep(180 * (fetchTry + 1));
            continue;
          }
          throw fe;
        }
      }
      /* eslint-enable no-await-in-loop */

      if (r.ok || attempt === 1) break;
      if (r.status === 401 && isJwtExpiredBody(txt)) {
        const refreshed = await refreshSessionNow();
        if (refreshed) continue;
      }
      break;
    }

    if (!r.ok) {
      console.error(`SB err ${method} ${path} HTTP ${r.status}: ${sbErrBodySnippet(txt)}`);
      return options.withCount ? { rows: null, total: null } : null;
    }
    /* PostgREST ponekad vrati prazno telo uz 2xx (npr. 204); ranije je to bilo kao greška (null). */
    let parsed;
    if (!txt) {
      if (method === 'PATCH') parsed = [];
      else if (method === 'DELETE') parsed = true;
      /* PostgREST: RPC sa RETURNS void daje 200/204 sa praznim telom — to je uspeh, ne NULL greška. */
      else if (method === 'POST') parsed = true;
      /* GET sa praznim telom (retko, ali proxy/edge): tretiraj kao prazan niz, ne kao grešku. */
      else if (method === 'GET') parsed = [];
      else parsed = null;
    } else {
      try {
        parsed = JSON.parse(txt);
      } catch (parseErr) {
        console.error(
          `SB JSON parse err ${method} ${path} HTTP ${r.status}: ${sbErrBodySnippet(txt)}`,
          parseErr,
        );
        return options.withCount ? { rows: null, total: null } : null;
      }
    }
    if (options.withCount && method === 'GET') {
      const cr = r.headers.get('content-range') || ''; /* primer: "0-49/1234" */
      const total = parseContentRangeTotal(cr);
      return { rows: Array.isArray(parsed) ? parsed : [], total };
    }
    return parsed;
  } catch (e) {
    /* Härd-4 (L21): AbortError mora da se propagira pozivaocu da može da
     * prikaže razlikujući toast (timeout vs. mrežna greška). Ne loguje se
     * kao "fetch failed" jer to nije failure nego eksplicitan otkaz. */
    if (e && (e.name === 'AbortError' || e.code === 20)) {
      throw e;
    }
    console.error(`SB fetch failed ${method} ${path}: ${e instanceof Error ? e.message : String(e)}`);
    return options.withCount ? { rows: null, total: null } : null;
  }
}

/**
 * Wrapper nad `sbReq` koji vraća `{ rows, total }` gde je `total` iz Content-Range header-a.
 * Koristi se za paginated liste.
 * @param {string} path
 * @returns {Promise<{ rows: any[]|null, total: number|null }>}
 */
export async function sbReqWithCount(path) {
  return sbReq(path, 'GET', null, { withCount: true });
}

function parseContentRangeTotal(cr) {
  if (!cr) return null;
  const idx = cr.lastIndexOf('/');
  if (idx < 0) return null;
  const tail = cr.slice(idx + 1).trim();
  if (!tail || tail === '*') return null;
  const n = Number(tail);
  return Number.isFinite(n) ? n : null;
}

/**
 * Kao {@link sbReq}, ali baca `Error` na HTTP grešku ili mrežu (za PB i slične servise).
 * Greška ima `status` (HTTP) i često `code` (PostgREST / aplikacija).
 *
 * @param {string} path
 * @param {'GET'|'POST'|'PATCH'|'DELETE'} [method='GET']
 * @param {object|null} [body=null]
 * @param {{ upsert?: boolean, withCount?: boolean }} [options]
 */
export async function sbReqThrow(path, method = 'GET', body = null, options = {}) {
  if (!hasSupabaseConfig()) {
    const e = new Error('Supabase nije konfigurisan');
    e.code = 'NO_CONFIG';
    throw e;
  }

  await ensureSessionFresh();

  let r;
  let txt;

  for (let attempt = 0; attempt < 2; attempt++) {
    const userNow = getCurrentUser();
    const token = userNow?._token || SUPABASE_CONFIG.anonKey;

    const headers = {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_CONFIG.anonKey,
      'Authorization': `Bearer ${token}`,
    };
    if (method === 'POST') {
      const upsert = options.upsert !== false;
      headers['Prefer'] = upsert
        ? 'return=representation,resolution=merge-duplicates'
        : 'return=representation';
    } else if (method === 'PATCH') {
      headers['Prefer'] = 'return=representation';
    }
    if (options.withCount && method === 'GET') {
      headers['Prefer'] = (headers['Prefer'] ? headers['Prefer'] + ',' : '') + 'count=exact';
    }

    try {
      r = await fetch(SUPABASE_CONFIG.url + '/rest/v1/' + path, {
        method,
        headers,
        body: body ? JSON.stringify(body) : undefined,
      });
      txt = await r.text();
    } catch (e) {
      const err = new Error(e instanceof Error ? e.message : String(e));
      err.code = 'NETWORK';
      throw err;
    }

    if (r.ok || attempt === 1) break;
    if (r.status === 401 && isJwtExpiredBody(txt)) {
      const refreshed = await refreshSessionNow();
      if (refreshed) continue;
    }
    break;
  }

  if (!r.ok) {
    let msg = txt?.trim() || `HTTP ${r.status}`;
    try {
      const j = JSON.parse(txt);
      if (j && typeof j === 'object' && j.message) msg = String(j.message);
    } catch {
      /* ostavi msg */
    }
    const err = new Error(msg);
    err.status = r.status;
    err.code = String(r.status);
    try {
      const j = JSON.parse(txt);
      if (j && typeof j === 'object' && j.code) err.code = String(j.code);
    } catch {
      /* ignore */
    }
    throw err;
  }

  let parsed;
  if (!txt) {
    if (method === 'PATCH') parsed = [];
    else if (method === 'DELETE') parsed = true;
    else if (method === 'POST') parsed = true;
    else if (method === 'GET') parsed = [];
    else parsed = null;
  } else {
    try {
      parsed = JSON.parse(txt);
    } catch {
      const err = new Error('Nevalidan JSON odgovor od Supabase-a');
      err.code = 'PARSE';
      throw err;
    }
  }
  if (options.withCount && method === 'GET') {
    const cr = r.headers.get('content-range') || '';
    const total = parseContentRangeTotal(cr);
    return { rows: Array.isArray(parsed) ? parsed : [], total };
  }
  return parsed;
}

/**
 * Health-check: pinguj Supabase REST-om. Koristi se za inicijalnu detekciju
 * online/offline statusa. Rezultat upiši kroz state/auth.js -> setOnline().
 */
export async function pingSupabase() {
  if (!hasSupabaseConfig()) return false;
  try {
    const r = await fetch(SUPABASE_CONFIG.url + '/rest/v1/?select=*', {
      method: 'GET',
      headers: {
        'apikey': SUPABASE_CONFIG.anonKey,
        'Authorization': 'Bearer ' + SUPABASE_CONFIG.anonKey,
      },
    });
    return r.ok || r.status === 404; // 404 znači da REST radi ali tabela ne postoji
  } catch (e) {
    return false;
  }
}
