/**
 * Projektni biro — Saveti (engineering tips / baza znanja).
 */

import {
  sbReqThrow,
  sbReq,
  getSupabaseUrl,
  getSupabaseAnonKey,
} from './supabase.js';
import { getCurrentUser, getIsOnline, isAdmin } from '../state/auth.js';
import { getPbEngineers } from './pb.js';

const PB_ENG_TIPS_BUCKET = 'pb-eng-tip-files';
const MAX_TAGS = 10;
const MAX_FILES = 8;
const MAX_FILE_BYTES = 5 * 1024 * 1024;

function actorEmail() {
  const u = getCurrentUser();
  return u?.email ? String(u.email) : null;
}

function sanitizeFileName(name) {
  return String(name || 'file')
    .normalize('NFKD')
    .replace(/[^\w.\-]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 80) || 'file';
}

function assertAllowedMime(mime) {
  const m = String(mime || '').toLowerCase();
  if (!m) return;
  if (m.startsWith('image/') || m === 'application/pdf') return;
  const e = new Error('Dozvoljeni su samo slike i PDF');
  e.code = 'VALIDATION';
  throw e;
}

function assertFileSize(size) {
  if (size != null && size > MAX_FILE_BYTES) {
    const e = new Error('Fajl je veći od 5 MB');
    e.code = 'VALIDATION';
    throw e;
  }
}

export function validateEngTipPayload(payload, { partial = false } = {}) {
  const p = payload || {};
  if (!partial || Object.prototype.hasOwnProperty.call(p, 'naslov')) {
    const naslov = String(p.naslov ?? '').trim();
    if (naslov.length < 3 || naslov.length > 200) {
      const e = new Error('Naslov mora imati 3–200 karaktera');
      e.code = 'VALIDATION';
      throw e;
    }
  }
  if (!partial || Object.prototype.hasOwnProperty.call(p, 'telo')) {
    const telo = String(p.telo ?? '').trim();
    if (telo.length < 10) {
      const e = new Error('Telo mora imati najmanje 10 karaktera');
      e.code = 'VALIDATION';
      throw e;
    }
  }
  if (p.tags != null) {
    const tags = Array.isArray(p.tags) ? p.tags.filter(t => String(t).trim()) : [];
    if (tags.length > MAX_TAGS) {
      const e = new Error(`Maksimalno ${MAX_TAGS} tag-ova`);
      e.code = 'VALIDATION';
      throw e;
    }
  }
}

export async function listEngTips({
  search,
  categoryIds,
  tags,
  myOnly,
  includeDrafts,
  sort,
  limit,
  offset,
} = {}) {
  if (!getIsOnline()) return [];
  const data = await sbReqThrow('rpc/pb_list_eng_tips', 'POST', {
    p_filter: {
      search: search?.trim() || null,
      category_ids: categoryIds?.length ? categoryIds : null,
      tags: tags?.length ? tags : null,
      my_only: !!myOnly,
      include_drafts: !!includeDrafts,
      sort: sort || 'recent',
      limit: limit ?? 200,
      offset: offset ?? 0,
    },
  }, { upsert: false });
  return Array.isArray(data) ? data : [];
}

export async function getEngTip(id) {
  if (!id || !getIsOnline()) return null;
  const data = await sbReqThrow('rpc/pb_get_eng_tip', 'POST', { p_id: id }, { upsert: false });
  return data && typeof data === 'object' ? data : null;
}

export async function saveEngTip(payload) {
  if (!getIsOnline()) {
    const e = new Error('Saveti zahtevaju internet');
    e.code = 'OFFLINE';
    throw e;
  }
  validateEngTipPayload(payload, { partial: !!payload?.id });
  const body = {
    id: payload.id || null,
    naslov: String(payload.naslov).trim(),
    telo: String(payload.telo).trim(),
    category_id: payload.category_id || null,
    tags: Array.isArray(payload.tags) ? payload.tags.map(t => String(t).trim()).filter(Boolean) : [],
    vendor: payload.vendor?.trim() || null,
    url: payload.url?.trim() || null,
    project_id: payload.project_id || null,
    status: payload.status || 'draft',
  };
  const data = await sbReqThrow('rpc/pb_save_eng_tip', 'POST', { p_payload: body }, { upsert: false });
  return data;
}

export async function softDeleteEngTip(id) {
  if (!id || !getIsOnline()) return null;
  return sbReqThrow('rpc/pb_soft_delete_eng_tip', 'POST', { p_id: id }, { upsert: false });
}

export async function toggleEngTipLike(id) {
  if (!id || !getIsOnline()) return null;
  const data = await sbReqThrow('rpc/pb_toggle_eng_tip_like', 'POST', { p_id: id }, { upsert: false });
  return data && typeof data === 'object' ? data : null;
}

export async function listEngTipCategories() {
  if (!getIsOnline()) return [];
  const data = await sbReqThrow('rpc/pb_list_eng_tip_categories', 'POST', {}, { upsert: false });
  return Array.isArray(data) ? data : [];
}

/** Admin: sve kategorije uključujući neaktivne (Podešavanja). */
export async function listAllEngTipCategoriesAdmin() {
  if (!getIsOnline()) return [];
  const data = await sbReqThrow(
    'pb_eng_tip_categories?select=*&order=redosled.asc,naziv.asc',
    'GET',
  );
  return Array.isArray(data) ? data : [];
}

export async function upsertEngTipCategory(payload) {
  if (!getIsOnline()) {
    const e = new Error('Saveti zahtevaju internet');
    e.code = 'OFFLINE';
    throw e;
  }
  const data = await sbReqThrow(
    'rpc/pb_upsert_eng_tip_category',
    'POST',
    { p_payload: payload || {} },
    { upsert: false },
  );
  return data;
}

export async function deleteEngTipCategory(id) {
  if (!id || !getIsOnline()) return null;
  return sbReqThrow('rpc/pb_delete_eng_tip_category', 'POST', { p_id: id }, { upsert: false });
}

export async function getEngTipFileSignedUrl(storagePath, ttlSeconds = 3600) {
  if (!storagePath) return null;
  const user = getCurrentUser();
  const token = user?._token || getSupabaseAnonKey();
  const apiKey = getSupabaseAnonKey();
  const baseUrl = getSupabaseUrl();
  try {
    const r = await fetch(
      `${baseUrl}/storage/v1/object/sign/${PB_ENG_TIPS_BUCKET}/${encodeURI(storagePath)}`,
      {
        method: 'POST',
        headers: {
          Authorization: 'Bearer ' + token,
          apikey: apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ expiresIn: ttlSeconds }),
      },
    );
    if (!r.ok) return null;
    const j = await r.json();
    const signed = j?.signedURL || j?.signedUrl;
    return signed ? `${baseUrl}/storage/v1${signed}` : null;
  } catch (err) {
    console.error('[getEngTipFileSignedUrl]', err);
    return null;
  }
}

/**
 * @param {string} tipId
 * @param {File|Blob} file
 * @param {{ existingCount?: number }} [opts]
 */
export async function uploadEngTipFile(tipId, file, opts = {}) {
  if (!tipId || !file) {
    const e = new Error('Nedostaje savet ili fajl');
    e.code = 'VALIDATION';
    throw e;
  }
  if (!getIsOnline()) {
    const e = new Error('Saveti zahtevaju internet');
    e.code = 'OFFLINE';
    throw e;
  }
  const count = opts.existingCount ?? 0;
  if (count >= MAX_FILES) {
    const e = new Error(`Maksimalno ${MAX_FILES} priloga po savetu`);
    e.code = 'VALIDATION';
    throw e;
  }
  assertAllowedMime(file.type);
  assertFileSize(file.size);

  const origName = file.name || 'file';
  const safeName = sanitizeFileName(origName);
  const uuid = crypto?.randomUUID?.() || String(Date.now());
  const storagePath = `${tipId}/${uuid}__${safeName}`;

  const user = getCurrentUser();
  const token = user?._token || getSupabaseAnonKey();
  const apiKey = getSupabaseAnonKey();
  const baseUrl = getSupabaseUrl();

  const r = await fetch(
    `${baseUrl}/storage/v1/object/${PB_ENG_TIPS_BUCKET}/${encodeURI(storagePath)}`,
    {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + token,
        apikey: apiKey,
        'Content-Type': file.type || 'application/octet-stream',
        'x-upsert': 'false',
        'cache-control': '3600',
      },
      body: file,
    },
  );
  if (!r.ok) {
    const txt = await r.text().catch(() => '');
    const e = new Error(`Upload nije uspeo (${r.status}): ${txt || 'greška'}`);
    e.code = 'STORAGE';
    throw e;
  }

  let row;
  try {
    row = await sbReqThrow(
      'rpc/pb_add_eng_tip_file',
      'POST',
      {
        p_tip_id: tipId,
        p_storage_path: storagePath,
        p_file_name: origName,
        p_mime_type: file.type || null,
        p_size_bytes: file.size ?? null,
      },
      { upsert: false },
    );
  } catch (err) {
    try {
      await fetch(
        `${baseUrl}/storage/v1/object/${PB_ENG_TIPS_BUCKET}/${encodeURI(storagePath)}`,
        { method: 'DELETE', headers: { Authorization: 'Bearer ' + token, apikey: apiKey } },
      );
    } catch { /* ignore */ }
    throw err;
  }

  const signedUrl = await getEngTipFileSignedUrl(storagePath);
  const isImage = String(file.type || '').startsWith('image/');
  return {
    id: row?.id,
    file_name: origName,
    mime_type: file.type || null,
    is_image: isImage,
    size_bytes: file.size ?? null,
    storage_path: storagePath,
    signed_url: signedUrl,
  };
}

export async function deleteEngTipFile(fileId, storagePath) {
  if (!fileId || !getIsOnline()) {
    const e = new Error('Prilog nije pronađen');
    e.code = 'VALIDATION';
    throw e;
  }
  const res = await sbReqThrow(
    'rpc/pb_delete_eng_tip_file',
    'POST',
    { p_file_id: fileId },
    { upsert: false },
  );
  const path = storagePath || res?.storage_path;
  if (path) {
    const user = getCurrentUser();
    const token = user?._token || getSupabaseAnonKey();
    const apiKey = getSupabaseAnonKey();
    const baseUrl = getSupabaseUrl();
    try {
      await fetch(
        `${baseUrl}/storage/v1/object/${PB_ENG_TIPS_BUCKET}/${encodeURI(path)}`,
        { method: 'DELETE', headers: { Authorization: 'Bearer ' + token, apikey: apiKey } },
      );
    } catch { /* ignore */ }
  }
  return res;
}

export async function canCurrentUserWriteEngTip() {
  if (!getIsOnline()) return false;
  if (isAdmin()) return true;
  try {
    const data = await sbReq('rpc/can_write_pb_eng_tips', 'POST', {}, { upsert: false });
    if (data === true) return true;
    if (data === false) return false;
  } catch {
    /* fallback */
  }
  const email = actorEmail();
  if (!email) return false;
  const engineers = await getPbEngineers().catch(() => []);
  return engineers.some(e => String(e.email || '').toLowerCase() === email.toLowerCase());
}
