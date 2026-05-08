/**
 * Sertifikati / licence / obuke (Faza K7) — CRUD nad `kadr_certificates`.
 * RLS: samo HR/admin.
 */

import { sbReq } from './supabase.js';
import { getIsOnline, canEditKadrovska } from '../state/auth.js';

export const CERT_TYPE_LABELS = {
  driver_license: 'Vozačka dozvola',
  forklift:       'Viljuškar',
  welding:        'Varenje',
  znr:            'ZNR (zaštita na radu)',
  iso:            'ISO sertifikat',
  electrical:     'Elektro licenca',
  height:         'Rad na visini',
  other:          'Ostalo',
};

export function mapDbCertificate(d) {
  return {
    id: d.id,
    employeeId: d.employee_id,
    employeeName: d.employee_name || '',
    employeeFirstName: d.employee_first_name || '',
    employeeLastName: d.employee_last_name || '',
    employeePosition: d.employee_position || '',
    employeeDepartment: d.employee_department || '',
    employeeActive: d.employee_active != null ? !!d.employee_active : true,
    certType: d.cert_type || 'other',
    certName: d.cert_name || '',
    issuer: d.issuer || '',
    documentNo: d.document_no || '',
    issuedOn: d.issued_on || '',
    expiresOn: d.expires_on || '',
    costRsd: Number(d.cost_rsd || 0),
    documentUrl: d.document_url || '',
    note: d.note || '',
    status: d.status || null,
    daysToExpiry: d.days_to_expiry == null ? null : Number(d.days_to_expiry),
    createdBy: d.created_by || '',
    createdAt: d.created_at || null,
    updatedAt: d.updated_at || null,
  };
}

export function buildCertificatePayload(r) {
  const p = {
    employee_id: r.employeeId,
    cert_type: r.certType || 'other',
    cert_name: r.certName,
    issuer: r.issuer || null,
    document_no: r.documentNo || null,
    issued_on: r.issuedOn,
    expires_on: r.expiresOn || null,
    cost_rsd: Number(r.costRsd || 0),
    document_url: r.documentUrl || null,
    note: r.note || null,
    updated_at: new Date().toISOString(),
  };
  if (r.id) p.id = r.id;
  return p;
}

export async function loadCertificatesForEmployee(employeeId) {
  if (!getIsOnline() || !employeeId) return null;
  const data = await sbReq(
    `kadr_certificates?employee_id=eq.${encodeURIComponent(employeeId)}`
    + '&select=*&order=issued_on.desc,created_at.desc',
  );
  if (!data) return null;
  return data.map(mapDbCertificate);
}

/** Svi sertifikati (sa view-a koji ima status). Za izveštaje. */
export async function loadAllCertificateStatus() {
  if (!getIsOnline()) return null;
  const data = await sbReq(
    'v_kadr_certificate_status?select=*&order=days_to_expiry.asc.nullslast',
  );
  if (!data) return null;
  return data.map(mapDbCertificate);
}

export async function saveCertificate(r) {
  if (!getIsOnline() || !canEditKadrovska()) return null;
  const payload = buildCertificatePayload(r);
  if (r.id) {
    const { id, ...rest } = payload;
    const res = await sbReq(
      `kadr_certificates?id=eq.${encodeURIComponent(r.id)}`,
      'PATCH', rest,
    );
    if (!res || !res.length) return null;
    return mapDbCertificate(res[0]);
  }
  const res = await sbReq('kadr_certificates', 'POST', payload);
  if (!res || !res.length) return null;
  return mapDbCertificate(res[0]);
}

export async function deleteCertificate(id) {
  if (!getIsOnline() || !canEditKadrovska() || !id) return false;
  const res = await sbReq(
    `kadr_certificates?id=eq.${encodeURIComponent(id)}`,
    'DELETE',
  );
  return res !== null;
}
