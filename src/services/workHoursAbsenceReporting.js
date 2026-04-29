/**
 * Izveštaji / saldo GO — izvor: work_hours (mesečni grid), ne tabela absences.
 */

import { hasSupabaseConfig, sbReq } from './supabase.js';
import { mapDbWorkHour } from './workHours.js';
import { daysInclusive, ymdAddDays } from '../lib/date.js';

/**
 * @param {'bo'|'go'} code
 * @param {string} fromYmd  '' = bez donje granice
 * @param {string} toYmd    '' = bez gornje granice (oba prazna = sva istorija za šifru)
 */
export async function loadWorkHourRowsForAbsenceCode(code, fromYmd, toYmd) {
  if (!hasSupabaseConfig()) return [];
  const c = String(code || '').toLowerCase();
  let path = `work_hours?absence_code=eq.${encodeURIComponent(c)}&select=*`;
  if (fromYmd && toYmd) {
    path = 'work_hours'
      + `?work_date=gte.${encodeURIComponent(fromYmd)}`
      + `&work_date=lte.${encodeURIComponent(toYmd)}`
      + `&absence_code=eq.${encodeURIComponent(c)}`
      + '&select=*';
  }
  const data = await sbReq(path);
  return Array.isArray(data) ? data.map(mapDbWorkHour) : [];
}

/**
 * Uzastopni datumi istog zaposlenog + istog absenceSubtype.
 */
export function mergeConsecutiveWorkHourDays(rows, noteExtraFn) {
  const byEmp = new Map();
  for (const r of rows) {
    if (!r.employeeId || !r.workDate) continue;
    if (!byEmp.has(r.employeeId)) byEmp.set(r.employeeId, []);
    byEmp.get(r.employeeId).push(r);
  }
  const out = [];
  const extras = noteExtraFn || (() => '');

  for (const [empId, list] of byEmp) {
    list.sort((a, b) => String(a.workDate).localeCompare(String(b.workDate)));
    let cur = null;
    for (const r of list) {
      const ymd = r.workDate;
      const sub = (r.absenceSubtype || '').toLowerCase();
      const note = ['Mesečni grid', extras(r)].filter(Boolean).join(' · ');
      const contiguous = cur
        && (cur._sub || '') === sub
        && ymdAddDays(cur.dateTo, 1) === ymd;
      if (contiguous) {
        cur.dateTo = ymd;
      } else {
        if (cur) {
          out.push({
            employeeId: empId,
            dateFrom: cur.dateFrom,
            dateTo: cur.dateTo,
            daysCount: daysInclusive(cur.dateFrom, cur.dateTo),
            note: cur.note,
          });
        }
        cur = { dateFrom: ymd, dateTo: ymd, _sub: sub, note };
      }
    }
    if (cur) {
      out.push({
        employeeId: empId,
        dateFrom: cur.dateFrom,
        dateTo: cur.dateTo,
        daysCount: daysInclusive(cur.dateFrom, cur.dateTo),
        note: cur.note,
      });
    }
  }
  return out;
}

/** Zapisi u istom obliku kao absences (tip bolovanje) za izveštaj. */
export async function bolovanjeListFromWorkHours(fromYmd, toYmd) {
  const rows = await loadWorkHourRowsForAbsenceCode('bo', fromYmd, toYmd);
  const merged = mergeConsecutiveWorkHourDays(rows, (r) => {
    const sub = r.absenceSubtype ? String(r.absenceSubtype).trim().toLowerCase() : '';
    return sub ? `bolovanje: ${sub}` : '';
  });
  return merged.map(m => ({ ...m, type: 'bolovanje' }));
}

/** Broj dana GO u godini po employee_id (iz work_hours). */
export async function countGoDaysByEmployeeForYear(year) {
  const map = new Map();
  if (!year || !hasSupabaseConfig()) return map;
  const from = `${year}-01-01`;
  const to = `${year}-12-31`;
  const data = await sbReq(
    `work_hours?work_date=gte.${encodeURIComponent(from)}`
    + `&work_date=lte.${encodeURIComponent(to)}`
    + '&absence_code=eq.go'
    + '&select=employee_id',
  );
  if (!Array.isArray(data)) return map;
  for (const r of data) {
    const id = r.employee_id;
    if (!id) continue;
    map.set(id, (map.get(id) || 0) + 1);
  }
  return map;
}

export async function goSegmentsForEmployeeYear(empId, year) {
  if (!empId || !year || !hasSupabaseConfig()) return [];
  const from = `${year}-01-01`;
  const to = `${year}-12-31`;
  const data = await sbReq(
    `work_hours?employee_id=eq.${encodeURIComponent(empId)}`
    + `&work_date=gte.${encodeURIComponent(from)}`
    + `&work_date=lte.${encodeURIComponent(to)}`
    + '&absence_code=eq.go'
    + '&select=*',
  );
  const rows = Array.isArray(data) ? data.map(mapDbWorkHour) : [];
  return mergeConsecutiveWorkHourDays(rows, () => '');
}

export async function latestGoSegmentForEmployeeYear(empId, year) {
  const segs = await goSegmentsForEmployeeYear(empId, year);
  if (!segs.length) return null;
  segs.sort((a, b) => String(b.dateFrom).localeCompare(String(a.dateFrom)));
  return segs[0];
}
