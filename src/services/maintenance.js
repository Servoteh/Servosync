/**
 * Servisi za modul održavanje mašina (Supabase REST).
 * Zavisi od migracije sql/migrations/add_maintenance_module.sql.
 */

import { sbReq } from './supabase.js';
import { getCurrentUser } from '../state/auth.js';

/** @param {string} code */
function enc(code) {
  return encodeURIComponent(code);
}

/**
 * @param {{ limit?: number }} [opts]
 * @returns {Promise<Array<{ machine_code: string, status: string, open_incidents_count: number, overdue_checks_count: number }>|null>}
 */
export async function fetchMaintMachineStatuses(opts = {}) {
  const limit = opts.limit ?? 500;
  return await sbReq(
    `v_maint_machine_current_status?select=machine_code,status,open_incidents_count,overdue_checks_count,override_reason,override_valid_until&order=machine_code.asc&limit=${limit}`
  );
}

/**
 * Nazivi mašina iz BigTehn cache-a (read-only).
 * @param {{ limit?: number }} [opts]
 * @returns {Promise<Array<{ rj_code: string, name: string, no_procedure?: boolean }>|null>}
 */
export async function fetchBigtehnMachineNames(opts = {}) {
  const limit = opts.limit ?? 2000;
  return await sbReq(
    `bigtehn_machines_cache?select=rj_code,name,no_procedure&order=name.asc&limit=${limit}`
  );
}

/**
 * @returns {Promise<object|null>}
 */
export async function fetchMaintUserProfile() {
  const uid = getCurrentUser()?.id;
  if (!uid) return null;
  const rows = await sbReq(`maint_user_profiles?select=*&user_id=eq.${uid}&limit=1`);
  return Array.isArray(rows) && rows[0] ? rows[0] : null;
}

/**
 * @param {string} machineCode
 * @returns {Promise<Array<object>|null>}
 */
export async function fetchMaintTasksForMachine(machineCode) {
  return await sbReq(
    `maint_tasks?select=id,title,severity,interval_value,interval_unit,active,grace_period_days&machine_code=eq.${enc(machineCode)}&active=eq.true&order=title.asc`
  );
}

/**
 * Svi šabloni kontrola (aktivni i neaktivni) za jednu mašinu — za admin/šef CRUD.
 * @param {string} machineCode
 * @returns {Promise<Array<object>|null>}
 */
export async function fetchMaintTasksForMachineAll(machineCode) {
  return await sbReq(
    `maint_tasks?select=*&machine_code=eq.${enc(machineCode)}&order=active.desc,title.asc`
  );
}

/**
 * @param {{ machine_code: string, title: string, description?: string|null,
 *           instructions?: string|null, interval_value: number,
 *           interval_unit: 'hours'|'days'|'weeks'|'months',
 *           severity?: 'normal'|'important'|'critical',
 *           required_role?: 'operator'|'technician'|'chief'|'management'|'admin',
 *           grace_period_days?: number, active?: boolean }} payload
 * @returns {Promise<object|null>}
 */
export async function insertMaintTask(payload) {
  const uid = getCurrentUser()?.id;
  const body = {
    machine_code: payload.machine_code,
    title: payload.title,
    description: payload.description || null,
    instructions: payload.instructions || null,
    interval_value: payload.interval_value,
    interval_unit: payload.interval_unit,
    severity: payload.severity || 'normal',
    required_role: payload.required_role || 'operator',
    grace_period_days: payload.grace_period_days ?? 3,
    active: payload.active ?? true,
    created_by: uid || null,
    updated_by: uid || null,
  };
  const rows = await sbReq('maint_tasks', 'POST', body);
  return Array.isArray(rows) && rows[0] ? rows[0] : rows;
}

/**
 * @param {string} taskId uuid
 * @param {object} fields
 * @returns {Promise<boolean>}
 */
export async function patchMaintTask(taskId, fields) {
  const uid = getCurrentUser()?.id;
  const r = await sbReq(
    `maint_tasks?id=eq.${encodeURIComponent(taskId)}`,
    'PATCH',
    { ...fields, updated_by: uid || null },
  );
  return r !== null;
}

/**
 * Brisanje šablona uklanja i celu istoriju (`maint_checks` FK ON DELETE CASCADE).
 * Preporučeno: koristi `patchMaintTask(id, { active: false })` umesto ovoga.
 * @param {string} taskId uuid
 * @returns {Promise<boolean>}
 */
export async function deleteMaintTask(taskId) {
  const r = await sbReq(
    `maint_tasks?id=eq.${encodeURIComponent(taskId)}`,
    'DELETE',
  );
  return r !== null;
}

/**
 * @param {string} machineCode
 * @param {{ limit?: number }} [opts]
 * @returns {Promise<Array<object>|null>}
 */
export async function fetchMaintIncidentsForMachine(machineCode, opts = {}) {
  const lim = opts.limit ?? 30;
  return await sbReq(
    `maint_incidents?select=id,title,severity,status,reported_at,assigned_to&machine_code=eq.${enc(machineCode)}&order=reported_at.desc&limit=${lim}`
  );
}

/**
 * @param {string} machineCode
 * @returns {Promise<object|null>}
 */
export async function fetchBigtehnMachineRow(machineCode) {
  const rows = await sbReq(
    `bigtehn_machines_cache?select=rj_code,name,no_procedure,department_id&rj_code=eq.${enc(machineCode)}&limit=1`
  );
  return Array.isArray(rows) && rows[0] ? rows[0] : null;
}

/**
 * @returns {Promise<Array<object>|null>}
 */
export async function fetchAllMaintProfiles() {
  return await sbReq('maint_user_profiles?select=*&order=full_name.asc&limit=500');
}

/**
 * @param {object} row
 * @returns {Promise<object|null>}
 */
export async function insertMaintProfile(row) {
  return await sbReq('maint_user_profiles', 'POST', row);
}

/**
 * @param {string} userId uuid
 * @param {object} fields
 * @returns {Promise<object|null>}
 */
export async function patchMaintProfile(userId, fields) {
  const r = await sbReq(`maint_user_profiles?user_id=eq.${encodeURIComponent(userId)}`, 'PATCH', fields);
  return r !== null;
}

/**
 * @param {{ task_id: string, machine_code: string, result: string, notes?: string|null }} payload
 * @returns {Promise<object|null>}
 */
export async function insertMaintCheck(payload) {
  const uid = getCurrentUser()?.id;
  if (!uid) return null;
  const body = {
    task_id: payload.task_id,
    machine_code: payload.machine_code,
    performed_by: uid,
    result: payload.result,
    notes: payload.notes || null,
    attachment_urls: [],
  };
  const rows = await sbReq('maint_checks', 'POST', body);
  return Array.isArray(rows) && rows[0] ? rows[0] : rows;
}

/**
 * @param {{ machine_code: string, title: string, description?: string|null, severity: string }} payload
 * @returns {Promise<object|null>}
 */
export async function insertMaintIncident(payload) {
  const uid = getCurrentUser()?.id;
  if (!uid) return null;
  const body = {
    machine_code: payload.machine_code,
    reported_by: uid,
    title: payload.title,
    description: payload.description || null,
    severity: payload.severity,
    status: 'open',
    attachment_urls: [],
  };
  const rows = await sbReq('maint_incidents', 'POST', body);
  return Array.isArray(rows) && rows[0] ? rows[0] : rows;
}

/**
 * @param {{ incident_id: string, event_type: string, comment?: string|null, from_value?: string|null, to_value?: string|null }} payload
 * @returns {Promise<object|null>}
 */
export async function insertMaintIncidentEvent(payload) {
  const uid = getCurrentUser()?.id;
  const body = {
    incident_id: payload.incident_id,
    actor: uid,
    event_type: payload.event_type,
    comment: payload.comment || null,
    from_value: payload.from_value ?? null,
    to_value: payload.to_value ?? null,
  };
  const rows = await sbReq('maint_incident_events', 'POST', body);
  return Array.isArray(rows) && rows[0] ? rows[0] : rows;
}

/**
 * @param {string} incidentId uuid
 * @returns {Promise<object|null>}
 */
export async function fetchIncidentById(incidentId) {
  const rows = await sbReq(`maint_incidents?select=*&id=eq.${encodeURIComponent(incidentId)}&limit=1`);
  return Array.isArray(rows) && rows[0] ? rows[0] : null;
}

/**
 * @param {string} incidentId uuid
 * @returns {Promise<Array<object>|null>}
 */
export async function fetchIncidentEvents(incidentId) {
  return await sbReq(
    `maint_incident_events?select=*&incident_id=eq.${encodeURIComponent(incidentId)}&order=at.asc`,
  );
}

/**
 * @param {string} incidentId uuid
 * @param {object} fields npr. status, assigned_to, updated_by, resolved_at, closed_at, resolution_notes
 * @returns {Promise<boolean>}
 */
export async function patchMaintIncident(incidentId, fields) {
  const r = await sbReq(`maint_incidents?id=eq.${encodeURIComponent(incidentId)}`, 'PATCH', fields);
  return r !== null;
}

/**
 * Lista za padajuće dodeljivanje (RPC `maint_assignable_users`; vidi add_maint_assignable_users_rpc.sql).
 * @returns {Promise<Array<{ user_id: string, full_name: string, maint_role: string }>|null>}
 */
export async function fetchAssignableMaintUsers() {
  const rows = await sbReq('rpc/maint_assignable_users', 'POST', {});
  return Array.isArray(rows) ? rows : null;
}

/**
 * @param {{ limit?: number }} [opts]
 * @returns {Promise<Array<object>|null>}
 */
export async function fetchMaintTaskDueDates(opts = {}) {
  const lim = opts.limit ?? 2000;
  return await sbReq(
    `v_maint_task_due_dates?select=task_id,machine_code,title,severity,interval_value,interval_unit,next_due_at,last_performed_at&order=next_due_at.asc&limit=${lim}`,
  );
}

/**
 * @param {string} machineCode
 * @param {{ limit?: number }} [opts]
 * @returns {Promise<Array<object>|null>}
 */
export async function fetchMaintMachineNotes(machineCode, opts = {}) {
  const lim = opts.limit ?? 100;
  return await sbReq(
    `maint_machine_notes?select=*&machine_code=eq.${enc(machineCode)}&deleted_at=is.null&order=pinned.desc,created_at.desc&limit=${lim}`,
  );
}

/**
 * @param {{ machine_code: string, content: string }} payload
 * @returns {Promise<object|null>}
 */
export async function insertMaintMachineNote(payload) {
  const uid = getCurrentUser()?.id;
  if (!uid) return null;
  const body = {
    machine_code: payload.machine_code,
    author: uid,
    content: payload.content,
  };
  const rows = await sbReq('maint_machine_notes', 'POST', body);
  return Array.isArray(rows) && rows[0] ? rows[0] : rows;
}

/**
 * @param {string} noteId uuid
 * @param {object} fields npr. content, pinned, deleted_at
 * @returns {Promise<boolean>}
 */
export async function patchMaintMachineNote(noteId, fields) {
  const r = await sbReq(`maint_machine_notes?id=eq.${encodeURIComponent(noteId)}`, 'PATCH', fields);
  return r !== null;
}

/**
 * Trenutni manuelni override (ako postoji i nije istekao).
 * @param {string} machineCode
 * @returns {Promise<object|null>}
 */
export async function fetchMaintMachineOverride(machineCode) {
  const rows = await sbReq(
    `maint_machine_status_override?select=*&machine_code=eq.${enc(machineCode)}&limit=1`,
  );
  return Array.isArray(rows) && rows[0] ? rows[0] : null;
}

/**
 * Upsert override-a. `valid_until` null znači trajno dok ručno ne skine.
 * Oslanja se na `Prefer: resolution=merge-duplicates` u `sbReq` za POST.
 * @param {{ machine_code: string, status: 'running'|'degraded'|'down'|'maintenance',
 *           reason: string, valid_until?: string|null }} payload
 * @returns {Promise<boolean>}
 */
export async function upsertMaintMachineOverride(payload) {
  const uid = getCurrentUser()?.id;
  if (!uid) return false;
  const body = {
    machine_code: payload.machine_code,
    status: payload.status,
    reason: payload.reason,
    set_by: uid,
    set_at: new Date().toISOString(),
    valid_until: payload.valid_until || null,
  };
  const r = await sbReq('maint_machine_status_override', 'POST', body);
  return r !== null;
}

/**
 * @param {string} machineCode
 * @returns {Promise<boolean>}
 */
export async function deleteMaintMachineOverride(machineCode) {
  const r = await sbReq(
    `maint_machine_status_override?machine_code=eq.${enc(machineCode)}`,
    'DELETE',
  );
  return r !== null;
}
