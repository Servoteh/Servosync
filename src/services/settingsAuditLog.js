/**
 * Audit log za Podešavanja — user_roles, predmet_aktivacija (view v_settings_audit_log).
 */

import { sbReq } from './supabase.js';
import { getIsOnline, isAdmin } from '../state/auth.js';

export const SETTINGS_AUDIT_TABLE_LABELS = {
  user_roles: 'Korisnici (uloge)',
  predmet_aktivacija: 'Podešavanje predmeta',
};

export function mapSettingsAuditRow(d) {
  return {
    id: d.id,
    tableName: d.table_name || '',
    recordId: d.record_id || '',
    action: d.action || '',
    actorEmail: d.actor_email || '',
    changedAt: d.changed_at || null,
    oldData: d.old_data || null,
    newData: d.new_data || null,
    diffKeys: Array.isArray(d.diff_keys) ? d.diff_keys : [],
  };
}

/**
 * @param {{ tableName?: string, action?: string, fromIso?: string, toIso?: string, limit?: number }} [filter]
 */
export async function loadSettingsAuditLog(filter = {}) {
  if (!getIsOnline() || !isAdmin()) return null;
  const params = ['select=*', 'order=changed_at.desc'];
  if (filter.tableName) params.push(`table_name=eq.${encodeURIComponent(filter.tableName)}`);
  if (filter.action) params.push(`action=eq.${encodeURIComponent(filter.action)}`);
  if (filter.fromIso) params.push(`changed_at=gte.${encodeURIComponent(filter.fromIso)}`);
  if (filter.toIso) params.push(`changed_at=lte.${encodeURIComponent(filter.toIso)}`);
  const limit = Math.min(Math.max(1, filter.limit || 100), 500);
  params.push(`limit=${limit}`);
  const data = await sbReq(`v_settings_audit_log?${params.join('&')}`);
  if (!data) return null;
  return data.map(mapSettingsAuditRow);
}

export function diffSettingsAuditRow(row) {
  const skip = new Set(['updated_at', 'created_at', 'updated_by']);
  const before = row.oldData || {};
  const after = row.newData || {};
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
