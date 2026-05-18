/**
 * ERP modul × uloga matrica za UI (Podešavanja → Uloge i dozvole).
 * Sinhronizovano sa src/state/auth.js — ažurirati oba pri promeni pravila.
 */

import { ROLE_LABELS, ROLES } from './constants.js';

/** @typedef {'access'|'edit'|'none'} AccessLevel */

/**
 * @type {ReadonlyArray<{
 *   moduleId: string,
 *   label: string,
 *   access: readonly string[],
 *   edit?: readonly string[],
 *   note?: string,
 * }>}
 */
export const ERP_RBAC_MATRIX = Object.freeze([
  {
    moduleId: 'podesavanja',
    label: 'Podešavanja',
    access: ['admin', 'menadzment'],
    edit: ['admin'],
    note: 'Menadžment: Mašine, Održ. profili, Podeš. predmeta',
  },
  {
    moduleId: 'kadrovska',
    label: 'Kadrovska',
    access: ['admin', 'hr', 'menadzment'],
    edit: ['admin', 'hr', 'menadzment', 'pm', 'leadpm'],
    note: 'Zarade samo admin',
  },
  {
    moduleId: 'plan-montaze',
    label: 'Plan montaže',
    access: ['admin', 'leadpm', 'pm', 'menadzment', 'hr', 'viewer'],
    edit: ['admin', 'leadpm', 'pm', 'menadzment'],
  },
  {
    moduleId: 'plan-proizvodnje',
    label: 'Plan proizvodnje',
    access: ['admin', 'leadpm', 'pm', 'menadzment', 'hr', 'viewer', 'cnc_operater'],
    edit: ['admin', 'pm', 'menadzment'],
  },
  {
    moduleId: 'pracenje-proizvodnje',
    label: 'Praćenje proizvodnje',
    access: ['admin', 'leadpm', 'pm', 'menadzment', 'hr', 'viewer', 'cnc_operater'],
    edit: ['admin', 'pm', 'menadzment'],
  },
  {
    moduleId: 'projektni-biro',
    label: 'Projektni biro',
    access: ['admin', 'leadpm', 'pm', 'menadzment', 'hr', 'viewer'],
    edit: ['admin', 'leadpm', 'pm', 'menadzment'],
  },
  {
    moduleId: 'lokacije',
    label: 'Lokacije delova',
    access: ['admin', 'menadzment', 'pm', 'leadpm', 'magacioner'],
    edit: ['admin', 'menadzment', 'pm', 'leadpm', 'magacioner'],
  },
  {
    moduleId: 'reversi',
    label: 'Reversi',
    access: ROLES,
    edit: ['admin', 'menadzment', 'pm', 'leadpm', 'magacioner'],
  },
  {
    moduleId: 'sastanci',
    label: 'Sastanci',
    access: ['admin', 'leadpm', 'pm', 'menadzment', 'hr', 'viewer'],
    edit: ['admin', 'leadpm', 'pm', 'menadzment'],
  },
  {
    moduleId: 'maintenance',
    label: 'Održavanje mašina',
    access: ['admin', 'menadzment', 'pm', 'leadpm', 'viewer'],
    edit: ['admin', 'menadzment'],
    note: 'Operateri / chief — posebni maint profili',
  },
  {
    moduleId: 'moj-profil',
    label: 'Moj profil',
    access: ROLES,
    edit: ROLES,
  },
]);

/** Kolone u matrici (sve poznate uloge u ERP-u). */
export const RBAC_DISPLAY_ROLES = Object.freeze([
  'admin',
  'menadzment',
  'leadpm',
  'pm',
  'hr',
  'viewer',
  'magacioner',
]);

/**
 * @param {readonly string[]} allowed
 * @param {string} role
 * @returns {AccessLevel}
 */
export function rbacLevelForRole(allowed, editList, role) {
  if (editList?.includes(role)) return 'edit';
  if (allowed.includes(role)) return 'access';
  return 'none';
}

export function rbacRoleLabel(role) {
  return ROLE_LABELS[role] || role;
}
