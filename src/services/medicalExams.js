/**
 * Lekarski pregledi (Faza K6) — CRUD nad `kadr_medical_exams`.
 *
 * RLS: samo HR/admin.
 * Skalarna polja `employees.medical_exam_date` / `medical_exam_expires` se
 * automatski sinhronizuju kroz DB trigger (kadr_medical_exams_sync_employee)
 * — UI ne treba da ih ručno postavlja.
 */

import { sbReq } from './supabase.js';
import { getIsOnline, canEditKadrovska } from '../state/auth.js';
import { kadrEnqueue } from './kadrOfflineQueue.js';

export function mapDbMedExam(d) {
  return {
    id: d.id,
    employeeId: d.employee_id,
    examDate: d.exam_date || '',
    validUntil: d.valid_until || '',
    examType: d.exam_type || 'redovan',
    institution: d.institution || '',
    costRsd: Number(d.cost_rsd || 0),
    documentUrl: d.document_url || '',
    note: d.note || '',
    createdBy: d.created_by || '',
    createdAt: d.created_at || null,
    updatedAt: d.updated_at || null,
  };
}

export function buildMedExamPayload(r) {
  const p = {
    employee_id: r.employeeId,
    exam_date: r.examDate,
    valid_until: r.validUntil || null,
    exam_type: r.examType || 'redovan',
    institution: r.institution || null,
    cost_rsd: Number(r.costRsd || 0),
    document_url: r.documentUrl || null,
    note: r.note || null,
    updated_at: new Date().toISOString(),
  };
  if (r.id) p.id = r.id;
  return p;
}

export async function loadMedExamsForEmployee(employeeId) {
  if (!getIsOnline() || !employeeId) return null;
  const data = await sbReq(
    `kadr_medical_exams?employee_id=eq.${encodeURIComponent(employeeId)}`
    + '&select=*&order=exam_date.desc,created_at.desc',
  );
  if (!data) return null;
  return data.map(mapDbMedExam);
}

/** Status pregleda za sve aktivne zaposlene (view v_kadr_medical_exam_status). */
export async function loadAllMedExamStatus() {
  if (!getIsOnline()) return null;
  const data = await sbReq('v_kadr_medical_exam_status?select=*');
  if (!data) return null;
  return data.map(d => ({
    employeeId: d.employee_id,
    employeeName: d.employee_name || '',
    employeeFirstName: d.employee_first_name || '',
    employeeLastName: d.employee_last_name || '',
    employeePosition: d.employee_position || '',
    employeeDepartment: d.employee_department || '',
    employeeActive: d.employee_active != null ? !!d.employee_active : true,
    medicalExamDate: d.medical_exam_date || '',
    medicalExamExpires: d.medical_exam_expires || '',
    status: d.status || 'never',
    daysToExpiry: d.days_to_expiry == null ? null : Number(d.days_to_expiry),
  }));
}

export async function saveMedExam(r) {
  if (!canEditKadrovska()) return null;
  const payload = buildMedExamPayload(r);

  /* Offline-first: ako nema mreže, ENQUEUE i vrati optimistički rezultat.
     Auto-flush će poslati zapis kad se vrati WiFi. POST se enqueue-uje samo
     za update (PATCH/idempotentno) — novi unos čeka online jer treba ID. */
  if (!getIsOnline()) {
    if (r.id) {
      const { id, ...rest } = payload;
      kadrEnqueue({
        kind: 'PATCH',
        path: `kadr_medical_exams?id=eq.${encodeURIComponent(r.id)}`,
        body: rest,
        label: `medExam UPDATE ${r.id.slice(0, 8)}`,
      });
      /* Vraćamo "kao da je sačuvano" — UI re-render očekuje object. */
      return { ...r, _pending: true };
    }
    /* Bez ID-a — ne možemo da garantujemo idempotentnost. Reci korisniku. */
    return null;
  }

  if (r.id) {
    const { id, ...rest } = payload;
    const res = await sbReq(
      `kadr_medical_exams?id=eq.${encodeURIComponent(r.id)}`,
      'PATCH', rest,
    );
    if (!res || !res.length) return null;
    return mapDbMedExam(res[0]);
  }
  const res = await sbReq('kadr_medical_exams', 'POST', payload);
  if (!res || !res.length) return null;
  return mapDbMedExam(res[0]);
}

export async function deleteMedExam(id) {
  if (!canEditKadrovska() || !id) return false;
  if (!getIsOnline()) {
    /* DELETE je idempotentan — bezbedno enqueue-ovati. */
    kadrEnqueue({
      kind: 'DELETE',
      path: `kadr_medical_exams?id=eq.${encodeURIComponent(id)}`,
      label: `medExam DELETE ${String(id).slice(0, 8)}`,
    });
    return true;
  }
  const res = await sbReq(
    `kadr_medical_exams?id=eq.${encodeURIComponent(id)}`,
    'DELETE',
  );
  return res !== null;
}
