/**
 * Supabase Auth API klijent — bez framework-a, samo fetch.
 *
 * Sve metode rade KROZ state/auth.js da bi sbReq() i UI sloj automatski
 * dobili tačan token i online flag. Ovaj modul NIKAD ne dotiče DOM —
 * UI sloj (Faza 3) renderuje login formu i rukuje grešku.
 *
 * Bezbednost:
 *   - Password se NIKAD ne loguje, ne kešira, ne šalje nigde drugde.
 *   - Sesija (access + refresh token) ide u localStorage pod
 *     STORAGE_KEYS.AUTH (kompatibilno sa legacy fajlom — isti ključ!).
 */

import {
  SUPABASE_CONFIG,
  hasSupabaseConfig,
} from '../lib/constants.js';
import {
  setUser,
  setRole,
  setOnline,
  persistSession,
  loadPersistedSession,
  getCurrentUser,
} from '../state/auth.js';

/** Jedinstven refresh u toku (paralelni REST pozivi čekaju isti promise). */
let refreshInFlight = null;

function decodeJwtPayload(accessToken) {
  try {
    const parts = String(accessToken || '').split('.');
    if (parts.length < 2) return null;
    const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const pad = b64.length % 4 ? '='.repeat(4 - (b64.length % 4)) : '';
    return JSON.parse(atob(b64 + pad));
  } catch {
    return null;
  }
}

async function exchangeRefreshToken(refreshToken) {
  const refreshRes = await fetch(`${SUPABASE_CONFIG.url}/auth/v1/token?grant_type=refresh_token`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_CONFIG.anonKey,
    },
    body: JSON.stringify({ refresh_token: refreshToken }),
  });
  const refreshData = await refreshRes.json().catch(() => ({}));
  if (!refreshRes.ok || refreshData.error) {
    const msg =
      refreshData.error_description
      || refreshData.msg
      || refreshData.message
      || refreshData.error
      || 'refresh_failed';
    const err = new Error(msg);
    err.code = refreshData.error || 'refresh_failed';
    throw err;
  }
  return refreshData;
}

/**
 * Osveži access token iz refresh_token-a u localStorage i ažuriraj {@link setUser}.
 * @returns {Promise<boolean>}
 */
export async function refreshSessionNow() {
  const session = loadPersistedSession();
  if (!session?.refresh_token) return false;
  try {
    const refreshData = await exchangeRefreshToken(session.refresh_token);
    const user = refreshData.user;
    if (!user?.email || !refreshData.access_token) return false;
    persistSession({
      access_token: refreshData.access_token,
      refresh_token: refreshData.refresh_token || session.refresh_token,
      user: refreshData.user,
    });
    setUser({
      email: (user.email || '').toLowerCase(),
      emailRaw: String(user.email || '').trim(),
      id: user.id,
      _token: refreshData.access_token,
    });
    return true;
  } catch (e) {
    console.warn('[auth] refreshSessionNow failed', e);
    return false;
  }
}

/**
 * Pre REST poziva: ako je JWT blizu isteka ili istekao, osveži ga (refresh_token).
 */
export async function ensureSessionFresh() {
  if (!hasSupabaseConfig()) return;
  const user = getCurrentUser();
  if (!user?._token) return;
  const session = loadPersistedSession();
  if (!session?.refresh_token) return;

  const payload = decodeJwtPayload(user._token);
  const exp = payload?.exp;
  const now = Math.floor(Date.now() / 1000);
  const skewSec = 120;
  if (typeof exp === 'number' && now < exp - skewSec) return;

  if (!refreshInFlight) {
    refreshInFlight = refreshSessionNow().finally(() => {
      refreshInFlight = null;
    });
  }
  await refreshInFlight;
}

/**
 * Login email + password.
 * @returns {{ok:true,user:object}|{ok:false,error:string}}
 */
export async function login(email, password) {
  if (!hasSupabaseConfig()) {
    return { ok: false, error: 'Supabase konfiguracija nije postavljena (proveri .env)' };
  }
  const cleanEmail = String(email || '').trim().toLowerCase();
  const cleanPass = String(password || '');
  if (!cleanEmail || !cleanPass) {
    return { ok: false, error: 'Unesi email i lozinku' };
  }
  try {
    const r = await fetch(SUPABASE_CONFIG.url + '/auth/v1/token?grant_type=password', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_CONFIG.anonKey,
      },
      body: JSON.stringify({ email: cleanEmail, password: cleanPass }),
    });
    const d = await r.json().catch(() => ({}));
    if (!r.ok || d.error) {
      return { ok: false, error: d.error_description || d.msg || d.message || d.error || 'Prijava nije uspela' };
    }
    if (!d.access_token) {
      return { ok: false, error: 'Supabase nije vratio access token. Proveri anon key i Auth podešavanja.' };
    }

    let authUser = d.user;
    if (!authUser?.email || !authUser?.id) {
      authUser = await fetchAuthUser(d.access_token);
    }
    if (!authUser?.email || !authUser?.id) {
      return { ok: false, error: 'Supabase nije vratio podatke korisnika. Proveri Auth konfiguraciju.' };
    }
    const user = {
      email: (authUser.email || cleanEmail).toLowerCase(),
      emailRaw: String(authUser.email || cleanEmail || '').trim(),
      id: authUser.id,
      _token: d.access_token,
    };
    setUser(user);
    setOnline(true);
    persistSession({
      access_token: d.access_token,
      refresh_token: d.refresh_token,
      user: authUser,
    });
    return { ok: true, user };
  } catch (e) {
    console.error('[auth] login error', e);
    return { ok: false, error: 'Greška pri prijavi' };
  }
}

async function fetchAuthUser(accessToken) {
  if (!accessToken) return null;
  try {
    const r = await fetch(SUPABASE_CONFIG.url + '/auth/v1/user', {
      headers: {
        apikey: SUPABASE_CONFIG.anonKey,
        Authorization: 'Bearer ' + accessToken,
      },
    });
    const d = await r.json().catch(() => ({}));
    return r.ok && !d.error ? d : null;
  } catch (e) {
    console.error('[auth] fetch user error', e);
    return null;
  }
}

/**
 * Pošalji "zaboravljena lozinka" email. Supabase šalje mail sa magic link-om
 * koji redirektuje na `redirectTo` sa `#access_token=...&type=recovery&...`
 * (implicit flow) ili `?code=...` (PKCE flow) iz kojeg naš reset ekran izvlači
 * token i poziva `updatePassword(...)`.
 *
 * @param {string} email
 * @param {string} redirectTo Apsolutni URL na koji Supabase vraća korisnika.
 * @returns {Promise<{ok:true}|{ok:false,error:string}>}
 */
export async function requestPasswordReset(email, redirectTo) {
  if (!hasSupabaseConfig()) {
    return { ok: false, error: 'Supabase konfiguracija nije postavljena' };
  }
  const cleanEmail = String(email || '').trim().toLowerCase();
  if (!cleanEmail) return { ok: false, error: 'Unesi email' };
  try {
    const url = new URL(SUPABASE_CONFIG.url + '/auth/v1/recover');
    if (redirectTo) url.searchParams.set('redirect_to', redirectTo);
    const r = await fetch(url.toString(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SUPABASE_CONFIG.anonKey,
      },
      body: JSON.stringify({ email: cleanEmail }),
    });
    if (!r.ok) {
      const d = await r.json().catch(() => ({}));
      return { ok: false, error: d.error_description || d.msg || d.error || 'Slanje nije uspelo' };
    }
    return { ok: true };
  } catch (e) {
    console.error('[auth] requestPasswordReset error', e);
    return { ok: false, error: 'Greška pri slanju email-a' };
  }
}

/**
 * Zameni lozinku trenutne sesije. Supabase zahteva validan access_token u
 * Authorization header-u (recovery token dobija isti format kao login token).
 *
 * @param {string} accessToken Recovery access token iz URL hash-a ili aktivne
 *   sesije (oba rade — `updateUser` u Supabase-u prihvata recovery token 1h).
 * @param {string} newPassword Minimum 6 karaktera (Supabase default).
 * @returns {Promise<{ok:true,user:object}|{ok:false,error:string}>}
 */
export async function updatePassword(accessToken, newPassword) {
  if (!hasSupabaseConfig()) {
    return { ok: false, error: 'Supabase konfiguracija nije postavljena' };
  }
  if (!accessToken) return { ok: false, error: 'Token nije dostupan (link je možda istekao).' };
  const p = String(newPassword || '');
  if (p.length < 6) return { ok: false, error: 'Lozinka mora imati najmanje 6 karaktera.' };
  try {
    const r = await fetch(SUPABASE_CONFIG.url + '/auth/v1/user', {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        apikey: SUPABASE_CONFIG.anonKey,
        Authorization: 'Bearer ' + accessToken,
      },
      body: JSON.stringify({ password: p }),
    });
    const d = await r.json().catch(() => ({}));
    if (!r.ok || d.error) {
      return { ok: false, error: d.error_description || d.msg || d.error || 'Izmena nije uspela' };
    }
    return { ok: true, user: d };
  } catch (e) {
    console.error('[auth] updatePassword error', e);
    return { ok: false, error: 'Greška pri izmeni lozinke' };
  }
}

/**
 * PKCE exchange — Supabase vraća `?code=...` posle click-a na magic link kad
 * je projekat u PKCE flow-u. Razmenimo code za access/refresh token.
 *
 * @param {string} code
 * @returns {Promise<{ok:true, session:{access_token:string, refresh_token:string, user:object}}|{ok:false,error:string}>}
 */
export async function exchangeCodeForSession(code) {
  if (!hasSupabaseConfig()) {
    return { ok: false, error: 'Supabase konfiguracija nije postavljena' };
  }
  if (!code) return { ok: false, error: 'Link nije validan (nema code).' };
  try {
    const r = await fetch(SUPABASE_CONFIG.url + '/auth/v1/token?grant_type=pkce', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SUPABASE_CONFIG.anonKey,
      },
      body: JSON.stringify({ auth_code: code }),
    });
    const d = await r.json().catch(() => ({}));
    if (!r.ok || d.error) {
      return { ok: false, error: d.error_description || d.msg || d.error || 'Razmena tokena nije uspela' };
    }
    return {
      ok: true,
      session: {
        access_token: d.access_token,
        refresh_token: d.refresh_token,
        user: d.user,
      },
    };
  } catch (e) {
    console.error('[auth] exchangeCodeForSession error', e);
    return { ok: false, error: 'Greška pri razmeni koda' };
  }
}

/** Brisanje sesije lokalno + best-effort REST logout. */
export async function logout() {
  const session = loadPersistedSession();
  const token = session?.access_token;
  if (hasSupabaseConfig() && token) {
    try {
      await fetch(SUPABASE_CONFIG.url + '/auth/v1/logout', {
        method: 'POST',
        headers: { 'Authorization': 'Bearer ' + token },
      });
    } catch (e) { /* ignore — server logout je best-effort */ }
  }
  setUser(null);
  setRole('viewer');
  setOnline(false);
  persistSession(null);
}

/**
 * Pokušaj povraćaja sesije iz localStorage (refresh token).
 * @returns {Promise<boolean>} true ako je sesija uspešno restaurirana
 */
export async function restoreSession() {
  if (!hasSupabaseConfig()) return false;
  const session = loadPersistedSession();
  if (!session?.refresh_token && !session?.access_token) return false;
  try {
    let accessToken = session.access_token;
    let user = session.user || null;
    if (session.refresh_token) {
      const refreshData = await exchangeRefreshToken(session.refresh_token);
      accessToken = refreshData.access_token;
      user = refreshData.user;
      persistSession({
        access_token: refreshData.access_token,
        refresh_token: refreshData.refresh_token || session.refresh_token,
        user: refreshData.user,
      });
    } else if (accessToken) {
      const userRes = await fetch(SUPABASE_CONFIG.url + '/auth/v1/user', {
        headers: {
          'apikey': SUPABASE_CONFIG.anonKey,
          'Authorization': 'Bearer ' + accessToken,
        },
      });
      if (!userRes.ok) throw new Error('user_restore_failed');
      user = await userRes.json();
    }
    if (!user?.email || !accessToken) throw new Error('invalid_session');

    setUser({
      email: (user.email || '').toLowerCase(),
      emailRaw: String(user?.email || '').trim(),
      id: user.id,
      _token: accessToken,
    });
    setOnline(true);
    return true;
  } catch (e) {
    console.warn('[auth] restoreSession failed', e);
    persistSession(null);
    setUser(null);
    setRole('viewer');
    setOnline(false);
    return false;
  }
}
