/**
 * Mobilni Reversi — perzistencija izabrane mašine i operatera između ekrana.
 */

import { STORAGE_KEYS } from './constants.js';
import { ssGet, ssSet, ssRemove } from './storage.js';

const MKEY = `sess:${STORAGE_KEYS.MOB_REV_MACHINE}`;
const OKEY = `sess:${STORAGE_KEYS.MOB_REV_OPERATOR}`;

/** @returns {{ rj_code: string, name?: string } | null} */
export function getMobileRevMachine() {
  try {
    const raw = ssGet(MKEY, '');
    if (!raw) return null;
    const o = JSON.parse(raw);
    if (!o?.rj_code) return null;
    return { rj_code: String(o.rj_code), name: o.name ? String(o.name) : '' };
  } catch {
    return null;
  }
}

/** @param {{ rj_code: string, name?: string } | null} m */
export function setMobileRevMachine(m) {
  if (!m?.rj_code) {
    ssRemove(MKEY);
    return;
  }
  ssSet(MKEY, JSON.stringify({ rj_code: m.rj_code, name: m.name || '' }));
}

/** @returns {{ id: string, full_name: string, department?: string } | null} */
export function getMobileRevOperator() {
  try {
    const raw = ssGet(OKEY, '');
    if (!raw) return null;
    const o = JSON.parse(raw);
    if (!o?.id) return null;
    return {
      id: String(o.id),
      full_name: String(o.full_name || ''),
      department: o.department ? String(o.department) : '',
    };
  } catch {
    return null;
  }
}

/** @param {{ id: string, full_name: string, department?: string } | null} op */
export function setMobileRevOperator(op) {
  if (!op?.id) {
    ssRemove(OKEY);
    return;
  }
  ssSet(
    OKEY,
    JSON.stringify({
      id: op.id,
      full_name: op.full_name || '',
      department: op.department || '',
    }),
  );
}
