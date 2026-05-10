/**
 * Projektni biro — Supabase servis (pb_tasks, pb_work_reports, load stats).
 */

import {
  sbReqThrow,
  sbReq,
  getSupabaseUrl,
  getSupabaseAnonKey,
} from './supabase.js';
import { ensureSessionFresh, refreshSessionNow } from './auth.js';
import { SUPABASE_CONFIG, hasSupabaseConfig } from '../lib/constants.js';
import { getCurrentUser, getIsOnline } from '../state/auth.js';
import { ensurePrioritetHydrated } from '../ui/podesavanja/podesavanjePredmeta/prioritetService.js';
import { sortProjectsForPredmetPrioritet } from './projects.js';

const PB_FILES_BUCKET = 'pb-task-files';

/** @returns {string|null} */
function actorEmail() {
  const u = getCurrentUser();
  return u?.email ? String(u.email) : null;
}

/**
 * @param {object} data
 * @param {boolean} partial - true za PATCH (samo prisutna polja)
 */
function assertValidTaskInput(data, partial) {
  if (!partial) {
    if (!data.naziv || !String(data.naziv).trim()) {
      const e = new Error('Naziv zadatka je obavezan');
      e.code = 'VALIDATION';
      throw e;
    }
  } else if (Object.prototype.hasOwnProperty.call(data, 'naziv')) {
    if (data.naziv != null && !String(data.naziv).trim()) {
      const e = new Error('Naziv zadatka ne sme biti prazan');
      e.code = 'VALIDATION';
      throw e;
    }
  }
  if (data.procenat_zavrsenosti !== undefined && data.procenat_zavrsenosti !== null) {
    const pct = Number(data.procenat_zavrsenosti);
    if (Number.isNaN(pct) || pct < 0 || pct > 100) {
      const e = new Error('Procenat završenosti mora biti između 0 i 100');
      e.code = 'VALIDATION';
      throw e;
    }
  }
  if (data.norma_sati_dan !== undefined && data.norma_sati_dan !== null) {
    const h = Number(data.norma_sati_dan);
    if (Number.isNaN(h) || h < 1 || h > 7) {
      const e = new Error('Norma mora biti između 1 i 7 sati/dan');
      e.code = 'VALIDATION';
      throw e;
    }
  }
  const dp = data.datum_pocetka_plan;
  const dr = data.datum_zavrsetka_plan;
  if (dp && dr && String(dr).slice(0, 10) < String(dp).slice(0, 10)) {
    const e = new Error('Planirani rok ne može biti pre datuma početka');
    e.code = 'VALIDATION';
    throw e;
  }
  const rp = data.datum_pocetka_real;
  const rz = data.datum_zavrsetka_real;
  if (rp && rz && String(rz).slice(0, 10) < String(rp).slice(0, 10)) {
    const e = new Error('Realni završetak ne može biti pre realnog početka');
    e.code = 'VALIDATION';
    throw e;
  }
}

/**
 * Lista projekata za PB — RPC iz production.predmet_aktivacija + bigtehn_items_cache
 * (je_aktivan AND je_projektovanje_montaza), ne ručni public.projects bez predmeta.
 */
export async function getPbProjects() {
  if (!getIsOnline()) return [];
  await ensurePrioritetHydrated().catch(() => {});
  const data = await sbReqThrow('rpc/pb_list_projects', 'POST', {});
  const rows = Array.isArray(data) ? data : [];
  return sortProjectsForPredmetPrioritet(rows);
}

/**
 * Inženjeri Mašinskog projektovanja (Inženjering i projektovanje) — filter čipovi i dodela;
 * isti kriterijum kao opterećenje (RPC `pb_get_mechanical_projecting_engineers`).
 */
export async function getPbEngineers() {
  if (!getIsOnline()) return [];
  const data = await sbReqThrow('rpc/pb_get_mechanical_projecting_engineers', 'POST', {});
  return Array.isArray(data) ? data : [];
}

/**
 * @param {{ projectId?: string|null, employeeId?: string|null, status?: string|null }} filters
 */
export async function getPbTasks(filters = {}) {
  if (!getIsOnline()) return [];
  let url =
    'pb_tasks?select=*,projects(project_code,project_name),employees(full_name)'
    + '&deleted_at=is.null';
  const { projectId, employeeId, status } = filters;
  if (projectId) url += `&project_id=eq.${encodeURIComponent(projectId)}`;
  if (employeeId) url += `&employee_id=eq.${encodeURIComponent(employeeId)}`;
  if (status) url += `&status=eq.${encodeURIComponent(status)}`;
  url += '&order=datum_zavrsetka_plan.asc.nullslast';
  const data = await sbReqThrow(url);
  if (!Array.isArray(data)) return [];
  return data.map(row => ({
    ...row,
    project_code: row.projects?.project_code ?? null,
    project_name: row.projects?.project_name ?? null,
    engineer_name: row.employees?.full_name ?? null,
    projects: undefined,
    employees: undefined,
  }));
}

function sanitizeTaskPayload(data) {
  const allowed = [
    'naziv', 'opis', 'problem', 'project_id', 'employee_id',
    'vrsta', 'prioritet', 'status',
    'datum_pocetka_plan', 'datum_zavrsetka_plan',
    'datum_pocetka_real', 'datum_zavrsetka_real',
    'procenat_zavrsenosti', 'norma_sati_dan',
  ];
  const out = {};
  for (const k of allowed) {
    if (Object.prototype.hasOwnProperty.call(data, k)) {
      let v = data[k];
      if (v === '') v = null;
      out[k] = v;
    }
  }
  return out;
}

export async function createPbTask(data) {
  const payload = {
    ...sanitizeTaskPayload(data),
    created_by: actorEmail(),
    updated_by: actorEmail(),
  };
  assertValidTaskInput(payload, false);
  const res = await sbReqThrow('pb_tasks', 'POST', payload, { upsert: false });
  return Array.isArray(res) && res[0] ? res[0] : null;
}

export async function updatePbTask(id, data) {
  if (!id) return null;
  const payload = {
    ...sanitizeTaskPayload(data),
    updated_by: actorEmail(),
  };
  assertValidTaskInput(payload, true);
  const res = await sbReqThrow(
    `pb_tasks?id=eq.${encodeURIComponent(id)}`,
    'PATCH',
    payload,
  );
  return Array.isArray(res) && res[0] ? res[0] : null;
}

/**
 * Brza promena statusa (Kanban). Vraća `{ ok, row?, status? }` za razlikovanje 403 i mreže.
 */
export async function quickUpdatePbTaskStatus(id, newStatus) {
  if (!id || !newStatus || !getIsOnline()) return { ok: false, status: 0 };
  const email = actorEmail();
  const payload = { status: newStatus, updated_by: email };
  return patchPbTasksResponse(
    `pb_tasks?id=eq.${encodeURIComponent(id)}&deleted_at=is.null`,
    payload,
  );
}

/**
 * @returns {Promise<{ ok: boolean, row?: object, status: number }>}
 */
async function patchPbTasksResponse(path, payload) {
  if (!hasSupabaseConfig()) return { ok: false, status: 0 };

  await ensureSessionFresh();

  const headersBase = () => {
    const user = getCurrentUser();
    const token = user?._token || SUPABASE_CONFIG.anonKey;
    return {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_CONFIG.anonKey,
      'Authorization': `Bearer ${token}`,
      Prefer: 'return=representation',
    };
  };

  function looksJwtExpired(status, txt) {
    if (status !== 401) return false;
    const raw = String(txt || '').toLowerCase();
    if (raw.includes('jwt expired') || raw.includes('token expired')) return true;
    try {
      const j = JSON.parse(txt);
      const m = String(j?.message || '').toLowerCase();
      return m.includes('jwt expired') || m.includes('token expired');
    } catch {
      return false;
    }
  }

  try {
    let r;
    let txt;
    for (let attempt = 0; attempt < 2; attempt++) {
      r = await fetch(SUPABASE_CONFIG.url + '/rest/v1/' + path, {
        method: 'PATCH',
        headers: headersBase(),
        body: JSON.stringify(payload),
      });
      txt = await r.text();
      if (r.ok || attempt === 1) break;
      if (looksJwtExpired(r.status, txt)) {
        const refreshed = await refreshSessionNow();
        if (refreshed) continue;
      }
      break;
    }
    if (!r.ok) {
      console.error('SB PATCH err', { path, status: r.status, body: txt });
      return { ok: false, status: r.status };
    }
    let parsed = null;
    if (txt) {
      try {
        parsed = JSON.parse(txt);
      } catch {
        parsed = null;
      }
    }
    const row = Array.isArray(parsed) && parsed[0] ? parsed[0] : null;
    return { ok: true, status: r.status, row };
  } catch (e) {
    console.error('SB PATCH fetch failed', e);
    return { ok: false, status: 0 };
  }
}

export async function softDeletePbTask(id) {
  if (!id) throw new Error('ID nedostaje');
  const payload = {
    deleted_at: new Date().toISOString(),
    updated_by: actorEmail(),
  };
  await sbReqThrow(
    `pb_tasks?id=eq.${encodeURIComponent(id)}&deleted_at=is.null`,
    'PATCH',
    payload,
  );
}

/**
 * Batch PATCH preko PostgREST `id=in.(...)` filtera. Vraća broj zaista
 * izmenjenih redova (RLS može filtrirati neki).
 * @param {string[]} ids
 * @param {object} data
 */
export async function bulkUpdatePbTasks(ids, data) {
  if (!Array.isArray(ids) || ids.length === 0) return { ok: 0, requested: 0 };
  const sanitized = sanitizeTaskPayload(data);
  assertValidTaskInput(sanitized, true);
  const payload = { ...sanitized, updated_by: actorEmail() };
  const inList = ids.map(encodeURIComponent).join(',');
  const res = await sbReqThrow(
    `pb_tasks?id=in.(${inList})&deleted_at=is.null`,
    'PATCH',
    payload,
  );
  const count = Array.isArray(res) ? res.length : 0;
  return { ok: count, requested: ids.length };
}

/**
 * Batch soft delete. Vraća broj zaista obrisanih redova.
 * @param {string[]} ids
 */
export async function bulkSoftDeletePbTasks(ids) {
  if (!Array.isArray(ids) || ids.length === 0) return { ok: 0, requested: 0 };
  const payload = {
    deleted_at: new Date().toISOString(),
    updated_by: actorEmail(),
  };
  const inList = ids.map(encodeURIComponent).join(',');
  const res = await sbReqThrow(
    `pb_tasks?id=in.(${inList})&deleted_at=is.null`,
    'PATCH',
    payload,
  );
  const count = Array.isArray(res) ? res.length : 0;
  return { ok: count, requested: ids.length };
}

export async function getPbLoadStats(windowDays = 20) {
  if (!getIsOnline()) return [];
  const body = { window_days: windowDays };
  const data = await sbReqThrow('rpc/pb_get_load_stats', 'POST', body);
  return Array.isArray(data) ? data : [];
}

export async function getPbTeamLoadStats(windowDays = 20) {
  if (!getIsOnline()) return [];
  const body = { window_days: windowDays };
  try {
    const data = await sbReqThrow('rpc/pb_get_team_load_stats', 'POST', body);
    return Array.isArray(data) ? data : [];
  } catch {
    /* RPC možda nije migriran — vrati prazan niz umesto bacanja. */
    return [];
  }
}

/**
 * Server-side agregat za Izveštaji — obračun po periodu (PB4).
 * @param {string} dateFrom 'YYYY-MM-DD'
 * @param {string} dateTo 'YYYY-MM-DD'
 * @param {string|null} [employeeId] uuid ili null = svi (u okviru RLS)
 */
export async function getPbWorkReportSummary(dateFrom, dateTo, employeeId = null) {
  if (!getIsOnline()) return [];
  if (!dateFrom || !dateTo) {
    const e = new Error('Datum od i datum do su obavezni za obračun');
    e.code = 'VALIDATION';
    throw e;
  }
  if (String(dateTo).slice(0, 10) < String(dateFrom).slice(0, 10)) {
    const e = new Error('Datum do ne može biti pre datuma od');
    e.code = 'VALIDATION';
    throw e;
  }
  const body = {
    p_date_from: dateFrom,
    p_date_to: dateTo,
    p_employee_id: employeeId || null,
  };
  const data = await sbReqThrow('rpc/pb_get_work_report_summary', 'POST', body, { upsert: false });
  return Array.isArray(data) ? data : [];
}

/**
 * @param {{
 *   employeeId?: string|null,
 *   dateFrom: string,
 *   dateTo: string,
 *   limit?: number,
 *   offset?: number,
 * }} filters
 */
export async function getPbWorkReports(filters = {}) {
  if (!getIsOnline()) return [];
  if (!filters.dateFrom || !filters.dateTo) {
    const e = new Error(
      'getPbWorkReports zahteva dateFrom i dateTo — koristi getPbWorkReportSummary za agregat',
    );
    e.code = 'VALIDATION';
    throw e;
  }
  const limit = filters.limit != null ? Number(filters.limit) : 500;
  const offset = filters.offset != null ? Number(filters.offset) : 0;
  let url =
    'pb_work_reports?select=*,employees(full_name)'
    + '&order=datum.desc,created_at.desc';
  const { employeeId, dateFrom, dateTo } = filters;
  if (employeeId) url += `&employee_id=eq.${encodeURIComponent(employeeId)}`;
  url += `&datum=gte.${encodeURIComponent(dateFrom)}`;
  url += `&datum=lte.${encodeURIComponent(dateTo)}`;
  url += `&limit=${encodeURIComponent(String(limit))}`;
  if (offset > 0) url += `&offset=${encodeURIComponent(String(offset))}`;
  const data = await sbReqThrow(url);
  if (!Array.isArray(data)) return [];
  return data.map(row => ({
    ...row,
    engineer_name: row.employees?.full_name ?? null,
    employees: undefined,
  }));
}

export async function createPbWorkReport(data) {
  if (!getIsOnline()) {
    const e = new Error('Offline');
    e.code = 'OFFLINE';
    throw e;
  }
  if (!data.datum) {
    const e = new Error('Datum je obavezan');
    e.code = 'VALIDATION';
    throw e;
  }
  const sat = Number(data.sati);
  if (!Number.isFinite(sat) || sat <= 0 || sat > 24) {
    const e = new Error('Sati moraju biti između 0.5 i 24');
    e.code = 'VALIDATION';
    throw e;
  }
  const email = actorEmail();
  const payload = {
    employee_id: data.employee_id || null,
    datum: data.datum || null,
    sati: sat,
    opis: data.opis ?? '',
    created_by: email,
  };
  const res = await sbReqThrow('pb_work_reports', 'POST', payload, { upsert: false });
  return Array.isArray(res) && res[0] ? res[0] : null;
}

export async function deletePbWorkReport(id) {
  if (!id || !getIsOnline()) {
    const e = new Error('Offline');
    e.code = 'OFFLINE';
    throw e;
  }
  await sbReqThrow(`pb_work_reports?id=eq.${encodeURIComponent(id)}`, 'DELETE');
}

export async function getPbNotifConfig() {
  if (!getIsOnline()) return null;
  const data = await sbReqThrow('pb_notification_config?id=eq.1');
  return Array.isArray(data) && data[0] ? data[0] : null;
}

export async function updatePbNotifConfig(patch) {
  if (!getIsOnline()) return null;
  const payload = {
    ...patch,
    updated_by: actorEmail(),
    updated_at: new Date().toISOString(),
  };
  const res = await sbReqThrow(
    'pb_notification_config?id=eq.1',
    'PATCH',
    payload,
  );
  return Array.isArray(res) && res[0] ? res[0] : null;
}

/* ── Komentari na zadacima (pb_task_comments) ───────────────────────── */

const PB_COMMENT_COLS = [
  'id', 'task_id', 'body', 'mentions',
  'created_at', 'updated_at', 'created_by', 'created_by_user_id', 'edited_at',
].join(',');

/**
 * Vraća komentare za zadat task — najnoviji prvi.
 * @param {string} taskId
 */
export async function getPbTaskComments(taskId) {
  if (!taskId || !getIsOnline()) return [];
  const url =
    `pb_task_comments?select=${PB_COMMENT_COLS}`
    + `&task_id=eq.${encodeURIComponent(taskId)}`
    + '&order=created_at.desc&limit=200';
  const rows = await sbReq(url);
  return Array.isArray(rows) ? rows : [];
}

/** Izvuče @-mentions iz teksta. Konvencija: @ime ili @email. */
export function parseMentions(text) {
  const matches = String(text || '').match(/@[\w.\-+]+/g) || [];
  return [...new Set(matches.map(m => m.slice(1)))];
}

export async function createPbTaskComment(taskId, body) {
  if (!taskId || !body) return { ok: false, error: 'Prazan komentar.' };
  if (!getIsOnline()) return { ok: false, error: 'Offline.' };
  const user = getCurrentUser();
  const payload = {
    task_id: taskId,
    body: String(body).slice(0, 4000),
    mentions: parseMentions(body),
    created_by: actorEmail(),
    created_by_user_id: user?.id || null,
  };
  const res = await sbReq('pb_task_comments', 'POST', payload, { upsert: false });
  const row = Array.isArray(res) ? (res[0] || null) : (res || null);
  return row ? { ok: true, row } : { ok: false, error: 'Insert nije uspeo (RLS?).' };
}

export async function updatePbTaskComment(id, body) {
  if (!id || !getIsOnline()) return false;
  const payload = {
    body: String(body || '').slice(0, 4000),
    mentions: parseMentions(body),
    edited_at: new Date().toISOString(),
  };
  const res = await sbReq(
    `pb_task_comments?id=eq.${encodeURIComponent(id)}`,
    'PATCH',
    payload,
  );
  return !!(res && (Array.isArray(res) ? res.length : true));
}

export async function deletePbTaskComment(id) {
  if (!id || !getIsOnline()) return false;
  await sbReqThrow(`pb_task_comments?id=eq.${encodeURIComponent(id)}`, 'DELETE');
  return true;
}

/* ── Zavisnosti između zadataka (pb_task_deps) ─────────────────────────── */

/**
 * Vraća listu zavisnosti za zadat task — sa nazivima ciljnih zadataka.
 * Format: [{ id, task_id, depends_on_task_id, depends_on: { id, naziv, status } }]
 * @param {string} taskId
 */
export async function getPbTaskDeps(taskId) {
  if (!taskId || !getIsOnline()) return [];
  const url =
    'pb_task_deps?select=id,task_id,depends_on_task_id,'
    + 'depends_on:pb_tasks!pb_task_deps_depends_on_task_id_fkey(id,naziv,status)'
    + `&task_id=eq.${encodeURIComponent(taskId)}`
    + '&order=created_at.asc';
  const rows = await sbReq(url);
  return Array.isArray(rows) ? rows : [];
}

/**
 * Dodaje zavisnost (task_id čeka depends_on_task_id).
 * Vraća { ok, row?, error? } — error može biti "ciklus" (Postgres exception).
 */
export async function addPbTaskDep(taskId, dependsOnId) {
  if (!taskId || !dependsOnId || taskId === dependsOnId) {
    return { ok: false, error: 'Neispravni ID-evi.' };
  }
  if (!getIsOnline()) return { ok: false, error: 'Offline.' };
  try {
    const payload = {
      task_id: taskId,
      depends_on_task_id: dependsOnId,
      created_by: actorEmail(),
    };
    const res = await sbReqThrow('pb_task_deps', 'POST', payload, { upsert: false });
    const row = Array.isArray(res) && res[0] ? res[0] : null;
    return row ? { ok: true, row } : { ok: false, error: 'Insert nije uspeo.' };
  } catch (e) {
    const msg = e?.message || '';
    /* Tolerantna provera: hvata "Ciklicna", "Ciklična", legacy "Cikličnа" (Cyrillic а), "cycle". */
    if (/iklic|cycle/i.test(msg)) {
      return { ok: false, error: 'Ciklicna zavisnost nije dozvoljena.' };
    }
    if (msg.includes('duplicate') || msg.includes('unique')) {
      return { ok: false, error: 'Ta zavisnost već postoji.' };
    }
    return { ok: false, error: msg || 'Greška.' };
  }
}

/** @param {string} depId */
export async function deletePbTaskDep(depId) {
  if (!depId || !getIsOnline()) return false;
  await sbReqThrow(`pb_task_deps?id=eq.${encodeURIComponent(depId)}`, 'DELETE');
  return true;
}

/* ── Prilozi uz zadatak (pb_task_files + Storage bucket pb-task-files) ───── */

const PB_FILE_COLS = [
  'id', 'task_id', 'file_name', 'storage_path',
  'mime_type', 'size_bytes', 'category', 'description',
  'uploaded_at', 'uploaded_by', 'uploaded_by_email', 'deleted_at',
].join(',');

/**
 * Listaj priloge za zadat task. Vraća prazan niz ako nema fajlova ili offline.
 * @param {string} taskId
 */
export async function fetchPbTaskFiles(taskId) {
  if (!taskId || !getIsOnline()) return [];
  const url =
    `pb_task_files?select=${PB_FILE_COLS}`
    + `&task_id=eq.${encodeURIComponent(taskId)}`
    + '&deleted_at=is.null'
    + '&order=uploaded_at.desc&limit=200';
  const rows = await sbReq(url);
  return Array.isArray(rows) ? rows : [];
}

/**
 * Upload-uje fajl u Storage bucket i kreira metapodatak.
 * @param {{ taskId: string, file: File|Blob, category?: string, description?: string }} opts
 * @returns {Promise<{ ok: boolean, row?: object, error?: string }>}
 */
export async function uploadPbTaskFile(opts) {
  const { taskId, file, category, description } = opts || {};
  if (!taskId || !file) return { ok: false, error: 'Nedostaje task ili fajl.' };
  if (!getIsOnline()) return { ok: false, error: 'Offline.' };

  const origName = file.name || 'file';
  const safeName = String(origName)
    .normalize('NFKD')
    .replace(/[^\w.\-]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 80) || 'file';

  const uuid = (crypto?.randomUUID?.() || String(Date.now())).replace(/-/g, '').slice(0, 12);
  const storagePath = `${taskId}/${uuid}_${safeName}`;

  const user = getCurrentUser();
  const token = user?._token || getSupabaseAnonKey();
  const apiKey = getSupabaseAnonKey();
  const baseUrl = getSupabaseUrl();

  /* 1) PUT u Storage */
  try {
    const r = await fetch(
      `${baseUrl}/storage/v1/object/${PB_FILES_BUCKET}/${encodeURI(storagePath)}`,
      {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ' + token,
          'apikey': apiKey,
          'Content-Type': file.type || 'application/octet-stream',
          'x-upsert': 'false',
          'cache-control': '3600',
        },
        body: file,
      },
    );
    if (!r.ok) {
      const txt = await r.text().catch(() => '');
      console.error('[uploadPbTaskFile] storage failed', r.status, txt);
      return { ok: false, error: `Storage upload (${r.status}): ${txt || 'fail'}` };
    }
  } catch (e) {
    console.error('[uploadPbTaskFile] storage exception', e);
    return { ok: false, error: 'Mreža/Storage greška.' };
  }

  /* 2) INSERT metadata */
  const payload = {
    task_id: taskId,
    file_name: origName,
    storage_path: storagePath,
    mime_type: file.type || null,
    size_bytes: file.size || null,
    category: category ? String(category).slice(0, 40) : null,
    description: description ? String(description).slice(0, 500) : null,
    uploaded_by: user?.id || null,
    uploaded_by_email: actorEmail(),
  };
  const res = await sbReq('pb_task_files', 'POST', payload, { upsert: false });
  const row = Array.isArray(res) ? (res[0] || null) : (res || null);
  if (!row) {
    /* Best-effort cleanup: obriši uploadovani blob da ne ostane „siroče". */
    try {
      await fetch(
        `${baseUrl}/storage/v1/object/${PB_FILES_BUCKET}/${encodeURI(storagePath)}`,
        { method: 'DELETE', headers: { 'Authorization': 'Bearer ' + token, 'apikey': apiKey } },
      );
    } catch { /* ignore */ }
    return { ok: false, error: 'Metadata upis u bazu nije uspeo (RLS?).' };
  }
  return { ok: true, row };
}

/**
 * Signed URL za preview/download (default 5 min).
 * @param {string} storagePath
 * @param {number} [expiresSec]
 */
export async function getPbTaskFileSignedUrl(storagePath, expiresSec = 300) {
  if (!storagePath) return null;
  const user = getCurrentUser();
  const token = user?._token || getSupabaseAnonKey();
  const apiKey = getSupabaseAnonKey();
  const baseUrl = getSupabaseUrl();
  try {
    const r = await fetch(
      `${baseUrl}/storage/v1/object/sign/${PB_FILES_BUCKET}/${encodeURI(storagePath)}`,
      {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ' + token,
          'apikey': apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ expiresIn: expiresSec }),
      },
    );
    if (!r.ok) return null;
    const j = await r.json();
    const signed = j?.signedURL || j?.signedUrl;
    return signed ? `${baseUrl}/storage/v1${signed}` : null;
  } catch (e) {
    console.error('[getPbTaskFileSignedUrl] err', e);
    return null;
  }
}

/**
 * Soft delete (metadata) + best-effort delete iz Storage-a.
 * @param {{ id: string, storage_path?: string }} file
 */
export async function deletePbTaskFile(file) {
  if (!file?.id || !getIsOnline()) return { ok: false };
  /* 1) Soft delete metadata */
  const payload = { deleted_at: new Date().toISOString() };
  const res = await sbReq(
    `pb_task_files?id=eq.${encodeURIComponent(file.id)}`,
    'PATCH',
    payload,
  );
  if (!res || (Array.isArray(res) && res.length === 0)) {
    return { ok: false, error: 'Brisanje metapodatka nije uspelo (RLS?).' };
  }
  /* 2) Best-effort obriši fajl iz Storage-a (ne baca grešku ako fail). */
  if (file.storage_path) {
    const user = getCurrentUser();
    const token = user?._token || getSupabaseAnonKey();
    const apiKey = getSupabaseAnonKey();
    const baseUrl = getSupabaseUrl();
    try {
      await fetch(
        `${baseUrl}/storage/v1/object/${PB_FILES_BUCKET}/${encodeURI(file.storage_path)}`,
        { method: 'DELETE', headers: { 'Authorization': 'Bearer ' + token, 'apikey': apiKey } },
      );
    } catch { /* ignore */ }
  }
  return { ok: true };
}
