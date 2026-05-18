/**
 * user_roles CRUD service (admin only).
 *
 * Bezbednosna odluka (port iz legacy/index.html, 2026-04-18):
 *   - INSERT iz UI-ja je SVESNO ONEMOGUĆEN. Razlog: dodeljivanje role pre
 *     nego što Auth nalog postoji znači da bi taj email — kad/ako se Auth
 *     nalog kasnije napravi — odmah dobio dodeljenu rolu (npr. admin).
 *     Ovaj rizik se uklanja tako što se nove uloge dodaju iz Supabase SQL
 *     Editor-a (audit trail). RLS politika dodatno blokira INSERT preko
 *     non-admin tokena.
 *   - Edit i Delete za POSTOJEĆE redove ostaju — admin može menjati rolu,
 *     deaktivirati nalog, brisati red.
 *
 * Mapping: DB snake_case (email, full_name, project_id, is_active,
 * must_change_password, created_at, updated_at, created_by) → JS camelCase.
 */

import { sbReq, getSupabaseUrl, getSupabaseHeaders } from './supabase.js';
import { canManageUsers, getCurrentUser } from '../state/auth.js';
import { showToast } from '../lib/dom.js';
import { hasSupabaseConfig } from '../lib/constants.js';

export function mapDbUser(d) {
  const managedIds = Array.isArray(d.managed_sub_department_ids)
    ? d.managed_sub_department_ids.map(Number).filter(n => Number.isFinite(n))
    : [];
  return {
    id: d.id,
    email: String(d.email || '').toLowerCase().trim(),
    fullName: d.full_name || '',
    team: d.team || '',
    role: String(d.role || 'viewer').toLowerCase(),
    projectId: d.project_id || null,
    isActive: d.is_active !== false,
    mustChangePassword: d.must_change_password === true,
    managedSubDepartmentIds: managedIds.length ? managedIds : null,
    createdAt: d.created_at || null,
    updatedAt: d.updated_at || null,
    createdBy: d.created_by || '',
  };
}

export function buildUserPayload(u) {
  const cu = getCurrentUser();
  const p = {
    email: String(u.email || '').toLowerCase().trim(),
    role: String(u.role || 'viewer').toLowerCase(),
    project_id: u.projectId || null,
    is_active: u.isActive !== false,
    full_name: u.fullName || '',
    team: u.team || '',
    updated_at: new Date().toISOString(),
    created_by: String(cu?.email || '').toLowerCase(),
  };
  if (u.id) p.id = u.id;
  if (u.role === 'menadzment' || String(u.role || '').toLowerCase() === 'menadzment') {
    const ids = u.managedSubDepartmentIds;
    p.managed_sub_department_ids =
      Array.isArray(ids) && ids.length ? ids.map(Number).filter(n => Number.isFinite(n)) : null;
  } else {
    p.managed_sub_department_ids = null;
  }
  return p;
}

/** SELECT svih user_roles redova. Vraća null ako request padne. */
export async function loadUsersFromDb() {
  return await sbReq('user_roles?select=*&order=role.asc,email.asc');
}

/**
 * UPDATE postojeceg user_role reda. INSERT je svesno blokiran u UI-ju —
 * ako se prosledi `u` bez `id`, vraćamo null + console.warn.
 */
export async function saveUserToDb(u) {
  if (!canManageUsers()) return null;
  const payload = buildUserPayload(u);
  if (u.id) {
    return await sbReq(
      `user_roles?id=eq.${encodeURIComponent(u.id)}`,
      'PATCH',
      payload,
    );
  }
  console.warn('[saveUserToDb] INSERT blocked from UI. Add new roles via Supabase SQL Editor.');
  showToast('ℹ Nove uloge se dodaju isključivo kroz Supabase SQL Editor.');
  return null;
}

/** DELETE user_role reda. Vraća true/false. */
export async function deleteUserRoleFromDb(id) {
  if (!canManageUsers()) return false;
  return (await sbReq(`user_roles?id=eq.${encodeURIComponent(id)}`, 'DELETE')) !== null;
}

/**
 * Admin RPC: user_roles ako Auth nalog već postoji.
 * @returns {Promise<{ ok: boolean, userRole?: object, code?: string, message?: string }|null>}
 */
export async function inviteUserRoleViaRpc(payload) {
  if (!canManageUsers()) return null;
  const body = {
    p_email: payload.email,
    p_role: payload.role,
    p_full_name: payload.fullName || '',
    p_team: payload.team || '',
    p_project_id: payload.projectId || null,
    p_managed_sub_department_ids:
      payload.role === 'menadzment' && Array.isArray(payload.managedSubDepartmentIds)
        ? payload.managedSubDepartmentIds
        : null,
    p_send_recovery: true,
  };
  const res = await sbReq('rpc/admin_invite_user_role', 'POST', body, { upsert: false });
  if (!res || typeof res !== 'object') return null;
  if (res.ok && res.user_role) {
    return { ok: true, userRole: mapDbUser(res.user_role) };
  }
  return {
    ok: false,
    code: res.code || 'error',
    message: res.message || 'Pozivnica nije uspela',
  };
}

/**
 * Edge Function: kreira Auth + user_roles (service role na serveru).
 * @returns {Promise<{ ok: boolean, userRole?: object, temporaryPassword?: string, error?: string }|null>}
 */
export async function inviteUserViaEdge(payload) {
  if (!canManageUsers() || !hasSupabaseConfig()) return null;
  const url = `${getSupabaseUrl()}/functions/v1/admin-invite-user`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        ...getSupabaseHeaders(),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: payload.email,
        role: payload.role,
        full_name: payload.fullName || '',
        team: payload.team || '',
        project_id: payload.projectId || null,
        managed_sub_department_ids:
          payload.role === 'menadzment' ? payload.managedSubDepartmentIds || null : null,
        password: payload.password || undefined,
      }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data?.ok) {
      return {
        ok: false,
        error: data?.error || data?.detail || `HTTP ${res.status}`,
      };
    }
    return {
      ok: true,
      userRole: data.user_role ? mapDbUser(data.user_role) : null,
      temporaryPassword: data.temporary_password || null,
    };
  } catch (e) {
    console.error('[users] invite edge', e);
    return { ok: false, error: String(e?.message || e) };
  }
}
