/**
 * Keširani lookup pododeljenja (session) za Kadrovska UI — imena iz ID-jeva scope-a.
 */

import { sbReq } from './supabase.js';
import { getIsOnline } from '../state/auth.js';

let cachedSubDepartments = null;

export async function loadSubDepartments() {
  if (cachedSubDepartments) return cachedSubDepartments;
  if (!getIsOnline()) {
    cachedSubDepartments = [];
    return cachedSubDepartments;
  }
  const rows = await sbReq(
    'sub_departments?select=id,name,department_id,sort_order&order=sort_order.asc,name.asc',
  );
  cachedSubDepartments = Array.isArray(rows) ? rows : [];
  return cachedSubDepartments;
}

/** Ime redosledom kao u kešu (sort_order / name). */
export function getSubDepartmentNames(ids) {
  if (!ids || !Array.isArray(ids) || ids.length === 0) return [];
  const idSet = new Set(ids.map(x => Number(x)).filter(n => Number.isFinite(n)));
  return (cachedSubDepartments ?? [])
    .filter(sd => idSet.has(Number(sd.id)))
    .map(sd => sd.name);
}

export function clearSubDepartmentsLookupCache() {
  cachedSubDepartments = null;
}
