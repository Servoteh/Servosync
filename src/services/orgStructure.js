/**
 * Org struktura — CRUD za departments / sub_departments / job_positions.
 * Čitanje: svi authenticated korisnici.
 * Pisanje: samo admin (enforced RLS na DB strani + guard ovde).
 */

import { sbReq } from './supabase.js';
import { isAdmin, getIsOnline } from '../state/auth.js';

/* ── LOAD ──────────────────────────────────────────────────────────── */

export async function loadDepartments() {
  if (!getIsOnline()) return null;
  return await sbReq('departments?select=*&order=sort_order.asc,name.asc');
}

export async function loadSubDepartments() {
  if (!getIsOnline()) return null;
  return await sbReq('sub_departments?select=*&order=department_id.asc,sort_order.asc,name.asc');
}

export async function loadJobPositions() {
  if (!getIsOnline()) return null;
  return await sbReq('job_positions?select=*&order=department_id.asc,sort_order.asc,name.asc');
}

/* ── DEPARTMENTS ───────────────────────────────────────────────────── */

export async function saveDepartment({ name, sort_order = 0 }) {
  if (!getIsOnline() || !isAdmin()) return null;
  return await sbReq('departments', 'POST', { name: name.trim(), sort_order });
}

export async function updateDepartment(id, { name, sort_order }) {
  if (!getIsOnline() || !isAdmin() || !id) return null;
  const patch = {};
  if (name !== undefined)       patch.name = name.trim();
  if (sort_order !== undefined) patch.sort_order = sort_order;
  return await sbReq(`departments?id=eq.${id}`, 'PATCH', patch);
}

export async function deleteDepartment(id) {
  if (!getIsOnline() || !isAdmin() || !id) return false;
  const res = await sbReq(`departments?id=eq.${id}`, 'DELETE');
  return res !== null;
}

/* ── SUB-DEPARTMENTS ───────────────────────────────────────────────── */

export async function saveSubDepartment({ department_id, name, sort_order = 0 }) {
  if (!getIsOnline() || !isAdmin()) return null;
  return await sbReq('sub_departments', 'POST', { department_id, name: name.trim(), sort_order });
}

export async function updateSubDepartment(id, { name, sort_order }) {
  if (!getIsOnline() || !isAdmin() || !id) return null;
  const patch = {};
  if (name !== undefined)       patch.name = name.trim();
  if (sort_order !== undefined) patch.sort_order = sort_order;
  return await sbReq(`sub_departments?id=eq.${id}`, 'PATCH', patch);
}

export async function deleteSubDepartment(id) {
  if (!getIsOnline() || !isAdmin() || !id) return false;
  const res = await sbReq(`sub_departments?id=eq.${id}`, 'DELETE');
  return res !== null;
}

/* ── JOB POSITIONS ─────────────────────────────────────────────────── */

export async function saveJobPosition({ department_id, sub_department_id = null, name, sort_order = 0 }) {
  if (!getIsOnline() || !isAdmin()) return null;
  return await sbReq('job_positions', 'POST', {
    department_id,
    sub_department_id: sub_department_id || null,
    name: name.trim(),
    sort_order,
  });
}

export async function updateJobPosition(id, { name, sort_order }) {
  if (!getIsOnline() || !isAdmin() || !id) return null;
  const patch = {};
  if (name !== undefined)       patch.name = name.trim();
  if (sort_order !== undefined) patch.sort_order = sort_order;
  return await sbReq(`job_positions?id=eq.${id}`, 'PATCH', patch);
}

export async function deleteJobPosition(id) {
  if (!getIsOnline() || !isAdmin() || !id) return false;
  const res = await sbReq(`job_positions?id=eq.${id}`, 'DELETE');
  return res !== null;
}
