/**
 * Audit log (Faza K8) — read-only iz `v_kadr_audit_log` (samo admin).
 *
 * UI prikazuje šta je ko menjao na osetljivim tabelama (zarade, ugovori, GO,
 * lekarski pregledi, sertifikati). DB-triggers automatski upisuju zapise.
 */

import { sbReq } from './supabase.js';
import { getIsOnline, isAdmin } from '../state/auth.js';

export const AUDIT_TABLE_LABELS = {
  salary_terms:           'Uslovi zarade',
  salary_payroll:         'Mesečni obračun',
  contracts:              'Ugovori',
  vacation_entitlements:  'Pravo na GO',
  vacation_balances:      'Saldo GO',
  kadr_medical_exams:     'Lekarski pregledi',
  kadr_certificates:      'Sertifikati',
};

export function mapDbAuditRow(d) {
  return {
    id: d.id,
    actorUserId: d.actor_user_id || '',
    actorEmail: d.actor_email || '',
    action: d.action || '',
    tableName: d.table_name || '',
    rowId: d.row_id || '',
    employeeId: d.employee_id || '',
    employeeName: d.employee_name || '',
    beforeData: d.before_data || null,
    afterData: d.after_data || null,
    changedAt: d.changed_at || null,
  };
}

/**
 * Učitaj audit zapise sa filterom.
 *  - filter.tableName — npr. 'salary_payroll'
 *  - filter.employeeId — UUID
 *  - filter.action — 'INSERT' | 'UPDATE' | 'DELETE'
 *  - filter.fromIso / filter.toIso — vremenski opseg
 *  - filter.limit — default 100, max 500
 */
export async function loadAuditLog(filter = {}) {
  if (!getIsOnline() || !isAdmin()) return null;
  const params = ['select=*', 'order=changed_at.desc'];
  if (filter.tableName)  params.push(`table_name=eq.${encodeURIComponent(filter.tableName)}`);
  if (filter.employeeId) params.push(`employee_id=eq.${encodeURIComponent(filter.employeeId)}`);
  if (filter.action)     params.push(`action=eq.${encodeURIComponent(filter.action)}`);
  if (filter.fromIso)    params.push(`changed_at=gte.${encodeURIComponent(filter.fromIso)}`);
  if (filter.toIso)      params.push(`changed_at=lte.${encodeURIComponent(filter.toIso)}`);
  const limit = Math.min(Math.max(1, filter.limit || 100), 500);
  params.push(`limit=${limit}`);
  const data = await sbReq(`v_kadr_audit_log?${params.join('&')}`);
  if (!data) return null;
  return data.map(mapDbAuditRow);
}

/**
 * Diff before/after — vraća { fieldName: { before, after } } samo za promenjena polja.
 * Ignoriše tehnička polja (updated_at, created_at).
 */
export function diffAuditRow(row) {
  const skip = new Set(['updated_at', 'created_at']);
  const before = row.beforeData || {};
  const after = row.afterData || {};
  const allKeys = new Set([...Object.keys(before), ...Object.keys(after)]);
  const out = {};
  for (const k of allKeys) {
    if (skip.has(k)) continue;
    const a = before[k];
    const b = after[k];
    if (JSON.stringify(a) !== JSON.stringify(b)) {
      out[k] = { before: a, after: b };
    }
  }
  return out;
}
