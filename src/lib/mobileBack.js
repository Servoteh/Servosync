/**
 * Navigacija „nazad" iz punog ERP modula otvorenog iz mobilnog magacina (/m).
 */

import { SESSION_KEYS } from './constants.js';
import { ssGet, ssRemove, ssSet } from './storage.js';

export function enableMobileBack() {
  ssSet(`sess:${SESSION_KEYS.MOBILE_BACK}`, '1');
}

export function consumeMobileBack() {
  const on = ssGet(`sess:${SESSION_KEYS.MOBILE_BACK}`) === '1';
  if (on) ssRemove(`sess:${SESSION_KEYS.MOBILE_BACK}`);
  return on;
}

export function isMobileBackEnabled() {
  return ssGet(`sess:${SESSION_KEYS.MOBILE_BACK}`) === '1';
}
