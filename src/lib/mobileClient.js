/**
 * Detekcija mobilnog browsera (Safari iOS, Chrome Android) — ne Capacitor APK.
 */

/** @returns {boolean} */
export function isCapacitorNative() {
  try {
    return !!window.Capacitor?.isNativePlatform?.();
  } catch {
    return false;
  }
}

/** @returns {boolean} */
export function isMobileUserAgent() {
  if (typeof navigator === 'undefined') return false;
  const ua = navigator.userAgent || '';
  return /iPhone|iPod|iPad|Android|Mobile/i.test(ua);
}

/** @returns {boolean} */
export function isCoarsePointerMobile() {
  if (typeof window === 'undefined' || !window.matchMedia) return false;
  return window.matchMedia('(pointer: coarse)').matches && window.innerWidth < 900;
}

/** Korisnik eksplicitno želi desktop ERP (hub, /reversi tabela). */
export function isDesktopForced() {
  try {
    if (new URLSearchParams(window.location.search).get('desktop') === '1') return true;
    return sessionStorage.getItem('erp_force_desktop') === '1';
  } catch {
    return false;
  }
}

export function setDesktopForced(on) {
  try {
    if (on) sessionStorage.setItem('erp_force_desktop', '1');
    else sessionStorage.removeItem('erp_force_desktop');
  } catch {
    /* ignore */
  }
}

/**
 * Mobilni Safari / telefon u browseru (ne native app).
 * @returns {boolean}
 */
export function isMobileWebClient() {
  if (isCapacitorNative()) return false;
  if (isDesktopForced()) return false;
  return isMobileUserAgent() || isCoarsePointerMobile();
}

/**
 * Da li treba koristiti mobilni shell (/m) umesto desktop modula.
 * @returns {boolean}
 */
export function shouldPreferMobileShell() {
  return isMobileWebClient() || isCapacitorNative();
}
