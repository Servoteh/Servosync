/**
 * Kadrovska Pregled — KPI RPC + action stack (PostgREST, session keš 60s).
 */

import { SESSION_KEYS } from '../lib/constants.js';
import {
  getCurrentRole,
  getIsOnline,
  canManageVacationRequests,
  isHrOrAdmin,
} from '../state/auth.js';
import { sbReq } from './supabase.js';
import { ssGet, ssSet, ssRemove } from '../lib/storage.js';

const CACHE_TTL_MS = 60_000;
const CACHE_KEY = 'kadr_dashboard_v1';

/**
 * Pročitaj i obriši jednokratni intent sa dashboard-a ako `tab` odgovara.
 * @param {string} expectedTab — npr. 'contracts', 'employees', 'vac-requests'
 * @returns {Record<string, unknown>|null}
 */
export function consumeKadrDashIntent(expectedTab) {
  try {
    const raw = ssGet(SESSION_KEYS.KADR_DASH_INTENT, null);
    if (!raw) return null;
    const j = JSON.parse(raw);
    if (j?.tab !== expectedTab) return null;
    ssRemove(SESSION_KEYS.KADR_DASH_INTENT);
    return j;
  } catch {
    return null;
  }
}

export function publishKadrDashIntent(payload) {
  try {
    ssSet(SESSION_KEYS.KADR_DASH_INTENT, JSON.stringify(payload));
  } catch {
    /* noop */
  }
}

function readSessionCache(key) {
  try {
    const raw = sessionStorage.getItem(key);
    if (!raw) return null;
    const obj = JSON.parse(raw);
    if (Date.now() - obj.t > CACHE_TTL_MS) return null;
    return obj.v;
  } catch {
    return null;
  }
}

function writeSessionCache(key, value) {
  try {
    sessionStorage.setItem(key, JSON.stringify({ t: Date.now(), v: value }));
  } catch {
    /* noop */
  }
}

export function clearDashboardCache() {
  try {
    for (const k of Object.keys(sessionStorage)) {
      if (k.startsWith(CACHE_KEY)) sessionStorage.removeItem(k);
    }
  } catch {
    /* noop */
  }
}

export async function loadDashboardKpis({ year, month, forceRefresh = false } = {}) {
  if (!getIsOnline()) return null;
  const fullKey = `${CACHE_KEY}__kpi__${year ?? 'curr'}_${month ?? 'curr'}`;
  if (!forceRefresh) {
    const cached = readSessionCache(fullKey);
    if (cached) return cached;
  }
  const body = { p_year: year ?? null, p_month: month ?? null };
  const result = await sbReq('rpc/kadr_dashboard_kpis', 'POST', body, { upsert: false });
  if (result && typeof result === 'object') writeSessionCache(fullKey, result);
  return result;
}

async function employeeRowsQuery(queryWithoutTable) {
  let rows = await sbReq(`v_employees_safe?${queryWithoutTable}`);
  if (!Array.isArray(rows)) {
    rows = await sbReq(`employees?${queryWithoutTable}`);
  }
  return Array.isArray(rows) ? rows : [];
}

function daysUntil(dateStr) {
  const t = new Date(`${dateStr}T12:00:00`);
  const n = new Date();
  n.setHours(12, 0, 0, 0);
  return Math.floor((t - n) / (24 * 3600 * 1000));
}

/** Sledeći kalendar upaljen rođendan u narednih 7 dana (bez godine). */
function birthdayWithinDays(birthDateStr, maxDays) {
  if (!birthDateStr) return null;
  const d = new Date(`${birthDateStr}T12:00:00`);
  if (Number.isNaN(d.getTime())) return null;
  const today = new Date();
  today.setHours(12, 0, 0, 0);
  const y = today.getFullYear();
  const next = new Date(y, d.getMonth(), d.getDate(), 12, 0, 0, 0);
  if (next < today) next.setFullYear(y + 1);
  const diff = Math.floor((next - today) / (24 * 3600 * 1000));
  if (diff >= 0 && diff <= maxDays) return diff;
  return null;
}

async function loadExpiringContracts() {
  if (!getIsOnline()) return [];
  const today = new Date().toISOString().slice(0, 10);
  const end = new Date(Date.now() + 30 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const path =
    'contracts?select=id,employee_id,contract_type,date_to,employees(full_name)' +
    `&is_active=eq.true&date_to=gte.${today}&date_to=lte.${end}&order=date_to.asc&limit=5`;
  const rows = await sbReq(path);
  if (!Array.isArray(rows)) return [];
  return rows.map(r => {
    const name = r.employees?.full_name || '?';
    const du = daysUntil(r.date_to);
    return {
      id: `contract_${r.id}`,
      type: 'contract_expiring',
      title: `Ugovor ističe — ${name}`,
      subtitle: `${r.contract_type || ''} • do ${r.date_to}`,
      deepLink: {
        tab: 'contracts',
        employeeId: r.employee_id,
        contractStatusFilter: 'all',
      },
      priority: du < 7 ? 90 : 50,
    };
  });
}

async function loadExpiringMedical() {
  if (!getIsOnline()) return [];
  const today = new Date().toISOString().slice(0, 10);
  const end = new Date(Date.now() + 30 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const q =
    'select=id,full_name,medical_exam_expires' +
    `&is_active=eq.true&medical_exam_expires=not.is.null&medical_exam_expires=gte.${today}&medical_exam_expires=lte.${end}&order=medical_exam_expires.asc&limit=5`;
  const rows = await employeeRowsQuery(q);
  return rows.map(r => {
    const du = daysUntil(r.medical_exam_expires);
    return {
      id: `medical_${r.id}`,
      type: 'medical_expiring',
      title: `Lekarski ističe — ${r.full_name || '?'}`,
      subtitle: `Važi do ${r.medical_exam_expires}`,
      deepLink: { tab: 'employees', search: r.full_name || '' },
      priority: du < 14 ? 85 : 55,
    };
  });
}

async function loadBirthdaysThisWeek() {
  if (!getIsOnline()) return [];
  const q =
    'select=id,full_name,birth_date&is_active=eq.true&birth_date=not.is.null&limit=400';
  const rows = await employeeRowsQuery(q);
  if (!rows.length) return [];
  const out = [];
  for (const r of rows) {
    const diff = birthdayWithinDays(r.birth_date, 7);
    if (diff === null) continue;
    out.push({
      id: `birthday_${r.id}`,
      type: 'birthday_soon',
      title: `Rođendan — ${r.full_name || '?'}`,
      subtitle: diff === 0 ? 'Danas' : `Za ${diff} d.`,
      deepLink: { tab: 'employees', search: r.full_name || '' },
      priority: 70 - diff,
    });
  }
  return out.slice(0, 5);
}

async function loadQueuedNotifications() {
  if (!getIsOnline()) return [];
  const path =
    'kadr_notification_log?select=id,notification_type,status,subject,recipient,scheduled_at' +
    '&status=eq.queued&order=scheduled_at.asc&limit=5';
  const rows = await sbReq(path);
  if (!Array.isArray(rows)) return [];
  return rows.map(r => ({
    id: `notif_${r.id}`,
    type: 'notification_queued',
    title: `Notifikacija na čekanju — ${r.notification_type || 'HR'}`,
    subtitle: (r.subject || r.recipient || '').slice(0, 80),
    deepLink: { tab: 'notifications' },
    priority: 45,
  }));
}

async function loadPendingVacRequestsForActionStack() {
  if (!getIsOnline() || !canManageVacationRequests()) return [];
  const path =
    'vacation_requests?select=id,employee_id,status,date_from,date_to,days_count,employees(full_name)' +
    '&status=eq.pending&order=created_at.desc&limit=8';
  const rows = await sbReq(path);
  if (!Array.isArray(rows)) return [];
  return rows.map(r => {
    const name = r.employees?.full_name || '?';
    return {
      id: `vacreq_${r.id}`,
      type: 'vacation_pending',
      title: `GO na čekanju — ${name}`,
      subtitle: `${r.date_from} → ${r.date_to} (${r.days_count ?? '?'} d)`,
      deepLink: { tab: 'vac-requests', vacStatus: 'pending', search: name.split(/\s+/)[0] || '' },
      priority: 72,
    };
  });
}

export async function loadActionStack({ year, month, forceRefresh = false } = {}) {
  const role = getCurrentRole();
  const fullKey = `${CACHE_KEY}__actions__${role}__${year ?? 'curr'}_${month ?? 'curr'}`;
  if (!forceRefresh) {
    const cached = readSessionCache(fullKey);
    if (cached) return cached;
  }
  const fetches = [];
  if (isHrOrAdmin()) {
    fetches.push(
      loadExpiringContracts(),
      loadExpiringMedical(),
      loadBirthdaysThisWeek(),
      loadQueuedNotifications(),
    );
  }
  if (canManageVacationRequests()) {
    fetches.push(loadPendingVacRequestsForActionStack());
  }
  const chunks = await Promise.all(fetches);
  const items = [];
  for (const c of chunks) {
    if (Array.isArray(c)) items.push(...c);
  }
  items.sort((a, b) => b.priority - a.priority);
  const top = items.slice(0, 10);
  writeSessionCache(fullKey, top);
  return top;
}
