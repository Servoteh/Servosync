/**
 * Zahtevi za godišnji odmor — Supabase REST (Faza K5).
 *
 * Tabela: vacation_requests
 * RLS: zaposleni vidi samo SVOJE; HR/admin/menadzment/leadpm/pm vidi SVE.
 */

import { sbReq } from './supabase.js';
import { getIsOnline, getCurrentUser, canManageVacationRequests } from '../state/auth.js';

export function mapDbVacReq(d) {
  return {
    id:             d.id,
    employeeId:     d.employee_id,
    year:           Number(d.year),
    dateFrom:       d.date_from || '',
    dateTo:         d.date_to   || '',
    daysCount:      Number(d.days_count ?? 0),
    note:           d.note           || '',
    status:         d.status         || 'pending',
    reviewedBy:     d.reviewed_by    || null,
    reviewedAt:     d.reviewed_at    || null,
    rejectionNote:  d.rejection_note || '',
    submittedBy:    d.submitted_by   || '',
    createdAt:      d.created_at     || null,
    updatedAt:      d.updated_at     || null,
  };
}

function buildInsertPayload(req) {
  return {
    employee_id:  req.employeeId,
    year:         Number(req.year),
    date_from:    req.dateFrom,
    date_to:      req.dateTo,
    days_count:   Number(req.daysCount ?? 0),
    note:         req.note || '',
    submitted_by: (getCurrentUser()?.email || '').toLowerCase(),
    status:       'pending',
  };
}

/** Svi zahtevi — za HR/admin/menadzment prikaz u KADROVI. */
export async function loadAllVacationRequestsFromDb() {
  if (!getIsOnline()) return null;
  const data = await sbReq('vacation_requests?select=*&order=created_at.desc');
  if (!data) return null;
  return data.map(mapDbVacReq);
}

/** Samo sopstveni zahtevi — za self-service. */
export async function loadMyVacationRequestsFromDb() {
  if (!getIsOnline()) return null;
  const email = (getCurrentUser()?.email || '').toLowerCase();
  if (!email) return [];
  const data = await sbReq(
    `vacation_requests?submitted_by=eq.${encodeURIComponent(email)}&order=created_at.desc`,
  );
  if (!data) return null;
  return data.map(mapDbVacReq);
}

/** Zahtevi za određenog zaposlenog — za self-service pregled. */
export async function loadVacationRequestsForEmployeeFromDb(employeeId) {
  if (!getIsOnline() || !employeeId) return null;
  const data = await sbReq(
    `vacation_requests?employee_id=eq.${encodeURIComponent(employeeId)}&order=created_at.desc`,
  );
  if (!data) return null;
  return data.map(mapDbVacReq);
}

/** Podnesi novi zahtev. */
export async function saveVacationRequestToDb(req) {
  if (!getIsOnline()) return null;
  const res = await sbReq('vacation_requests', 'POST', buildInsertPayload(req), { upsert: false });
  if (res === null) {
    console.warn('[vacReq] save failed — run sql/migrations/add_kadr_vacation_requests.sql');
  }
  return res;
}

/**
 * Odobri ili odbij zahtev (samo HR/admin/menadzment/leadpm/pm).
 * @param {string} id UUID zahteva
 * @param {'approved'|'rejected'} status
 * @param {string} [rejectionNote] obavezan ako status='rejected'
 */
export async function updateVacationRequestStatusInDb(id, status, rejectionNote = '') {
  if (!getIsOnline() || !canManageVacationRequests() || !id) return null;
  const patch = {
    status,
    reviewed_by:     (getCurrentUser()?.email || '').toLowerCase(),
    reviewed_at:     new Date().toISOString(),
    rejection_note:  status === 'rejected' ? (rejectionNote || '') : null,
    updated_at:      new Date().toISOString(),
  };
  return await sbReq(
    `vacation_requests?id=eq.${encodeURIComponent(id)}`,
    'PATCH',
    patch,
  );
}

/** Briše zahtev — samo HR/admin prema RLS. */
export async function deleteVacationRequestFromDb(id) {
  if (!getIsOnline() || !id) return false;
  return (await sbReq(`vacation_requests?id=eq.${encodeURIComponent(id)}`, 'DELETE')) !== null;
}

/**
 * Upisuje email + WhatsApp notifikaciju u kadr_notification_log
 * kada se GO zahtev odobri ili odbije.
 * Koristi SECURITY DEFINER SQL funkciju — zaobilazi RLS.
 */
export async function queueVacationNotification(id, status, rejectionNote = '') {
  if (!getIsOnline() || !id) return;
  await sbReq('rpc/kadr_queue_vacation_notification', 'POST', {
    p_vacation_request_id: id,
    p_new_status:          status,
    p_rejection_note:      rejectionNote || '',
  });
}
