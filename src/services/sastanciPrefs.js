/**
 * Servis za per-user podešavanja notifikacija (sastanci_notification_prefs).
 *
 * Eksportuje:
 *   getMyPrefs()        → Promise<PrefsRow | null>
 *   updateMyPrefs(patch) → Promise<PrefsRow | null>
 */

import { sbReq } from './supabase.js';
import { getIsOnline } from '../state/auth.js';

/**
 * @typedef {Object} PrefsRow
 * @property {string} email
 * @property {boolean} on_new_akcija
 * @property {boolean} on_change_akcija
 * @property {boolean} on_meeting_invite
 * @property {boolean} on_meeting_locked
 * @property {boolean} on_action_reminder
 * @property {boolean} on_meeting_reminder
 * @property {string|null} email_address
 * @property {string} updated_at
 */

/**
 * Učitava (ili kreira default) prefs red za ulogovanog korisnika.
 * Koristi SECURITY DEFINER RPC koji zaobilazi RLS INSERT check.
 * @returns {Promise<PrefsRow | null>}
 */
export async function getMyPrefs() {
  if (!getIsOnline()) return null;
  const data = await sbReq('rpc/sastanci_get_or_create_my_prefs', 'POST', {});
  return data && !Array.isArray(data) ? data : (Array.isArray(data) && data.length ? data[0] : null);
}

/**
 * Ažurira prefs polja za ulogovanog korisnika.
 * @param {Partial<PrefsRow>} patch
 * @returns {Promise<PrefsRow | null>}
 */
export async function updateMyPrefs(patch) {
  if (!getIsOnline() || !patch) return null;

  const safeFields = [
    'on_new_akcija', 'on_change_akcija', 'on_meeting_invite',
    'on_meeting_locked', 'on_action_reminder', 'on_meeting_reminder',
  ];

  const payload = {};
  safeFields.forEach(f => {
    if (f in patch) payload[f] = !!patch[f];
  });

  if (!Object.keys(payload).length) return null;

  payload.updated_at = new Date().toISOString();

  const cu = await getMyPrefs();
  if (!cu) return null;

  const data = await sbReq(
    `sastanci_notification_prefs?email=eq.${encodeURIComponent(cu.email)}`,
    'PATCH',
    payload,
  );

  return Array.isArray(data) && data.length ? data[0] : null;
}
