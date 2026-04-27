/**
 * Kadrovska — load & cache koordinator.
 *
 * Tanki layer iznad services/employees.js + absences.js + workHours.js +
 * contracts.js. Implementira load-then-cache pattern iz legacy/index.html
 * `ensureKadrovskaLoaded` / `ensureAbsencesLoaded` itd.
 *
 * Tok:
 *   1. Postavi state.items na cache iz localStorage (UI ima šta da prikaže odmah)
 *   2. Ako je online + ima Supabase config-a → fetch sa servera, override cache
 *   3. Postavi loaded=true, _schema=true/false na osnovu rezultata
 *
 * UI sloj NIKAD ne treba da zove sbReq direktno — uvek ide preko ovih ensure*.
 */

import {
  loadEmployeesFromDb,
} from './employees.js';
import {
  loadDepartments,
  loadSubDepartments,
  loadJobPositions,
} from './orgStructure.js';
import { loadAbsencesFromDb } from './absences.js';
import { loadWorkHoursFromDb } from './workHours.js';
import { loadContractsFromDb } from './contracts.js';
import {
  loadEntitlementsFromDb,
  loadBalancesFromDb,
} from './vacation.js';
import {
  loadChildrenForEmployee,
} from './employeeChildren.js';
import {
  loadCurrentSalariesFromDb,
  loadTermsForEmployee,
} from './salary.js';

import { getIsOnline, canViewEmployeePii, isAdmin } from '../state/auth.js';
import { hasSupabaseConfig } from '../lib/constants.js';
import {
  compareEmployeesByLastFirst,
  employeeDisplayName,
} from '../lib/employeeNames.js';
import {
  kadrovskaState,
  kadrAbsencesState,
  kadrWorkHoursState,
  kadrContractsState,
  kadrVacationState,
  kadrChildrenState,
  kadrSalaryState,
  orgStructureState,
  loadEmployeesCache,
  saveEmployeesCache,
  loadAbsencesCache,
  saveAbsencesCache,
  loadWorkHoursCache,
  saveWorkHoursCache,
  loadContractsCache,
  saveContractsCache,
} from '../state/kadrovska.js';

function normalizeEmployees(list) {
  return (list || [])
    .map(e => ({ ...e, fullName: employeeDisplayName(e) || e.fullName || '' }))
    .sort(compareEmployeesByLastFirst);
}

export async function ensureEmployeesLoaded(force = false) {
  if (kadrovskaState.loaded && !force) return;
  /* Force: ne puni in-memory stari mesečni keš (department bi ostao netačan). */
  if (force) {
    kadrovskaState.employees = [];
  } else {
    /* Cache prvi — UI brzo prikazuje; mreža ga prepisuje kad stigne. */
    kadrovskaState.employees = normalizeEmployees(loadEmployeesCache());
  }
  kadrovskaState.loaded = true;
  if (getIsOnline() && hasSupabaseConfig()) {
    const fresh = await loadEmployeesFromDb();
    if (fresh) {
      kadrovskaState.employees = normalizeEmployees(fresh);
      saveEmployeesCache(kadrovskaState.employees);
      kadrovskaState._schemaSupported = true;
    } else {
      if (force) {
        /* Posle slobodnog fetch-a, fallback na LS samo da UI nije prazan. */
        kadrovskaState.employees = normalizeEmployees(loadEmployeesCache());
      }
      kadrovskaState._schemaSupported = false;
    }
  }
}

export async function ensureAbsencesLoaded(force = false) {
  if (kadrAbsencesState.loaded && !force) return;
  kadrAbsencesState.items = loadAbsencesCache();
  kadrAbsencesState.loaded = true;
  if (getIsOnline() && hasSupabaseConfig()) {
    const fresh = await loadAbsencesFromDb();
    if (fresh) {
      kadrAbsencesState.items = fresh;
      saveAbsencesCache(fresh);
      kadrAbsencesState._schema = true;
    } else {
      kadrAbsencesState._schema = false;
    }
  }
}

export async function ensureWorkHoursLoaded(force = false) {
  if (kadrWorkHoursState.loaded && !force) return;
  kadrWorkHoursState.items = loadWorkHoursCache();
  kadrWorkHoursState.loaded = true;
  if (getIsOnline() && hasSupabaseConfig()) {
    const fresh = await loadWorkHoursFromDb();
    if (fresh) {
      kadrWorkHoursState.items = fresh;
      saveWorkHoursCache(fresh);
      kadrWorkHoursState._schema = true;
    } else {
      kadrWorkHoursState._schema = false;
    }
  }
}

export async function ensureContractsLoaded(force = false) {
  if (kadrContractsState.loaded && !force) return;
  kadrContractsState.items = loadContractsCache();
  kadrContractsState.loaded = true;
  if (getIsOnline() && hasSupabaseConfig()) {
    const fresh = await loadContractsFromDb();
    if (fresh) {
      kadrContractsState.items = fresh;
      saveContractsCache(fresh);
      kadrContractsState._schema = true;
    } else {
      kadrContractsState._schema = false;
    }
  }
}

/**
 * Godišnji odmor — entitlements + saldo (po godini).
 * Parametar `year` je obavezan za saldo; entitlements se uvek učitavaju svi.
 * Re-run kada se promeni godina u UI-u.
 */
export async function ensureVacationLoaded(year, force = false) {
  const sameYear = kadrVacationState.loadedYear === Number(year);
  if (kadrVacationState.loaded && sameYear && !force) return;
  if (!getIsOnline() || !hasSupabaseConfig()) {
    kadrVacationState.loaded = true;
    kadrVacationState.loadedYear = Number(year) || null;
    return;
  }
  const [ent, bal] = await Promise.all([
    loadEntitlementsFromDb(),
    loadBalancesFromDb(year),
  ]);
  kadrVacationState.entitlements = ent || [];
  kadrVacationState.balances = bal || [];
  kadrVacationState.loadedYear = Number(year) || null;
  kadrVacationState.loaded = true;
  kadrVacationState._schema = !!(ent !== null && bal !== null);
}

/**
 * Deca jednog zaposlenog — lazy per-employee.
 * Ako pozivalac nije admin → `null` (RLS bi ionako zabranio).
 */
export async function ensureChildrenLoaded(employeeId, force = false) {
  if (!employeeId) return [];
  if (!canViewEmployeePii()) return null;
  if (kadrChildrenState.byEmp.has(employeeId) && !force) {
    return kadrChildrenState.byEmp.get(employeeId);
  }
  if (!getIsOnline() || !hasSupabaseConfig()) {
    kadrChildrenState.byEmp.set(employeeId, []);
    return [];
  }
  const list = await loadChildrenForEmployee(employeeId);
  kadrChildrenState.byEmp.set(employeeId, list || []);
  return list || [];
}

/**
 * Aktuelne zarade svih zaposlenih (iz view-a). Samo admin.
 * Istorija po zaposlenom je lazy preko `ensureTermsForEmployee`.
 */
export async function ensureCurrentSalariesLoaded(force = false) {
  if (!isAdmin()) return;
  if (kadrSalaryState.loaded && !force) return;
  if (!getIsOnline() || !hasSupabaseConfig()) {
    kadrSalaryState.loaded = true;
    return;
  }
  const rows = await loadCurrentSalariesFromDb();
  kadrSalaryState.current = rows || [];
  kadrSalaryState.loaded = true;
  kadrSalaryState._schema = rows !== null;
}

export async function ensureTermsForEmployee(employeeId, force = false) {
  if (!isAdmin() || !employeeId) return null;
  if (kadrSalaryState.termsByEmp.has(employeeId) && !force) {
    return kadrSalaryState.termsByEmp.get(employeeId);
  }
  if (!getIsOnline() || !hasSupabaseConfig()) {
    kadrSalaryState.termsByEmp.set(employeeId, []);
    return [];
  }
  const list = await loadTermsForEmployee(employeeId);
  kadrSalaryState.termsByEmp.set(employeeId, list || []);
  return list || [];
}

/** Helper za jedan call koji učita SVE (npr. pri prvom otvaranju modula). */
export async function ensureAllKadrovskaLoaded(force = false) {
  await ensureEmployeesLoaded(force);
  /* Ostale liste se lazy-učitavaju kad se njihov tab otvori. */
}

/** Helper: pronađi ime zaposlenog po ID-u (fallback '—'). */
export function employeeNameById(id) {
  const e = kadrovskaState.employees.find(x => x.id === id);
  return e ? (employeeDisplayName(e) || '—') : '—';
}

/**
 * Lista odeljenja kao { id, name } objekti, sortirani po sort_order.
 * Koristi referentne tabele kada su učitane; fallback na tekst iz zaposlenih.
 */
export function uniqueDepartments() {
  if (orgStructureState.departments.length) {
    return [...orgStructureState.departments].sort((a, b) => a.sort_order - b.sort_order || a.name.localeCompare(b.name, 'sr'));
  }
  const set = new Set();
  for (const e of kadrovskaState.employees) {
    if (e.department && String(e.department).trim()) set.add(String(e.department).trim());
  }
  return Array.from(set)
    .sort((a, b) => a.localeCompare(b, 'sr'))
    .map(name => ({ id: null, name }));
}

/** Učitaj i kešuj org strukturu (odeljenja / pododeljenja / radna mesta). */
export async function ensureOrgStructureLoaded(force = false) {
  if (orgStructureState.loaded && !force) return;
  if (!getIsOnline() || !hasSupabaseConfig()) { orgStructureState.loaded = true; return; }
  const [depts, subDepts, positions] = await Promise.all([
    loadDepartments(),
    loadSubDepartments(),
    loadJobPositions(),
  ]);
  orgStructureState.departments    = depts     || [];
  orgStructureState.subDepartments = subDepts  || [];
  orgStructureState.jobPositions   = positions || [];
  orgStructureState.loaded = true;
}
