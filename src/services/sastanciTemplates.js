/**
 * Templati sastanaka — CRUD + instanciranje u `sastanci` + `sastanak_ucesnici`.
 * Nova šema: sastanci_templates, sastanci_template_ucesnici
 */

import { sbReq } from './supabase.js';
import { getCurrentUser, getIsOnline } from '../state/auth.js';
import { saveSastanak, saveUcesnici, loadSastanak } from './sastanci.js';

function toLocalYMD(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/**
 * Izračunava sledeći slot datuma lokalne zone (samo kalendar, bez vremenske zone drift-a).
 * @param {object} t — mapirani template (createdAt = anchor za biweekly)
 * @param {Date} [fromDate]
 */
export function nextOccurrence(t, fromDate = new Date()) {
  if (!t || t.cadence === 'none') {
    return toLocalYMD(fromDate);
  }
  const from = new Date(fromDate.getFullYear(), fromDate.getMonth(), fromDate.getDate());

  if (t.cadence === 'daily') {
    const n = new Date(from);
    n.setDate(n.getDate() + 1);
    return toLocalYMD(n);
  }

  if (t.cadence === 'monthly' && t.cadenceDom != null) {
    let y = from.getFullYear();
    let m = from.getMonth();
    const dom = Math.min(Math.max(1, t.cadenceDom), 31);
    let tryDate = new Date(y, m, dom);
    if (tryDate < from) {
      m += 1;
      if (m > 11) { m = 0; y += 1; }
      tryDate = new Date(y, m, dom);
    }
    while (tryDate.getMonth() !== m) {
      m += 1;
      if (m > 11) { m = 0; y += 1; }
      tryDate = new Date(y, m, dom);
    }
    return toLocalYMD(tryDate);
  }

  const targetDow = t.cadenceDow != null ? t.cadenceDow : 1;

  function addDays(d, n) {
    const x = new Date(d);
    x.setDate(x.getDate() + n);
    return x;
  }

  let cur = new Date(from);
  for (let i = 0; i < 400; i++) {
    if (cur.getDay() === targetDow) break;
    cur = addDays(cur, 1);
  }

  if (t.cadence === 'weekly') {
    return toLocalYMD(cur);
  }

  if (t.cadence === 'biweekly') {
    const anchor = t.createdAt ? new Date(t.createdAt) : new Date(2024, 0, 1);
    const anchor0 = new Date(anchor.getFullYear(), anchor.getMonth(), anchor.getDate());
    const aDay = Math.floor(anchor0.getTime() / 86400000);
    let cur2 = new Date(from);
    for (let j = 0; j < 500; j++) {
      if (cur2.getDay() === targetDow) {
        const cDay = Math.floor(new Date(
          cur2.getFullYear(), cur2.getMonth(), cur2.getDate(),
        ).getTime() / 86400000);
        if (Math.floor((cDay - aDay) / 7) % 2 === 0) return toLocalYMD(cur2);
        cur2 = addDays(cur2, 7);
        continue;
      }
      cur2 = addDays(cur2, 1);
    }
  }

  return toLocalYMD(cur);
}

function mapRow(d) {
  if (!d) return null;
  return {
    id: d.id,
    naziv: d.naziv || '',
    tip: d.tip || 'sedmicni',
    mesto: d.mesto || '',
    vodioEmail: d.vodio_email || '',
    zapisnicarEmail: d.zapisnicar_email || '',
    cadence: d.cadence || 'none',
    cadenceDow: d.cadence_dow,
    cadenceDom: d.cadence_dom,
    vreme: d.vreme || null,
    napomena: d.napomena || null,
    isActive: d.is_active !== false,
    createdByEmail: d.created_by_email || '',
    createdAt: d.created_at || null,
    updatedAt: d.updated_at || null,
  };
}

/**
 * Učitaj šablone sa učesnicima (email + label).
 */
export async function listTemplates() {
  if (!getIsOnline()) return [];
  const cols = 'id,naziv,tip,mesto,vodio_email,zapisnicar_email,cadence,cadence_dow,cadence_dom,vreme,napomena,is_active,created_by_email,created_at,updated_at';
  const data = await sbReq(`sastanci_templates?select=${cols}&order=created_at.desc`);
  if (!Array.isArray(data) || !data.length) return [];
  const ids = data.map(r => r.id);
  const ures = await sbReq(
    `sastanci_template_ucesnici?template_id=in.(${ids.join(',')})&select=template_id,email,label&order=email.asc&limit=200`,
  );
  const byT = new Map();
  (Array.isArray(ures) ? ures : []).forEach(r => {
    const id = r.template_id;
    if (!byT.has(id)) byT.set(id, []);
    byT.get(id).push({ email: String(r.email || '').toLowerCase().trim(), label: r.label || '' });
  });
  return data.map(r => ({ ...mapRow(r), ucesnici: byT.get(r.id) || [] }));
}

function buildTemplatePayload(s, { forInsert } = {}) {
  const cu = getCurrentUser();
  const p = {
    naziv: s.naziv,
    tip: s.tip || 'sedmicni',
    mesto: s.mesto || null,
    vodio_email: s.vodioEmail || null,
    zapisnicar_email: s.zapisnicarEmail || null,
    cadence: s.cadence || 'none',
    cadence_dow: s.cadenceDow != null ? s.cadenceDow : null,
    cadence_dom: s.cadenceDom != null ? s.cadenceDom : null,
    vreme: s.vreme || null,
    napomena: s.napomena || null,
    is_active: s.isActive !== false,
    updated_at: new Date().toISOString(),
  };
  if (forInsert) p.created_by_email = s.createdByEmail || cu?.email || null;
  return p;
}

export async function createTemplate(s, ucesnici = []) {
  if (!getIsOnline()) return null;
  const payload = buildTemplatePayload(s, { forInsert: true });
  const data = await sbReq('sastanci_templates', 'POST', payload, { upsert: false });
  const row = Array.isArray(data) && data[0] ? data[0] : null;
  if (!row) return null;
  const id = row.id;
  if (ucesnici?.length) {
    const up = ucesnici.map(u => ({
      template_id: id,
      email: String(u.email || '').toLowerCase().trim(),
      label: u.label || null,
    }));
    const inserted = await sbReq('sastanci_template_ucesnici', 'POST', up);
    if (inserted === null) {
      console.error('[sastanciTemplates] createTemplate: insert učesnika nije uspeo', id);
      return null;
    }
  }
  return { ...mapRow(row), ucesnici: ucesnici || [] };
}

export async function updateTemplate(id, s, ucesnici = []) {
  if (!id || !getIsOnline()) return null;
  const payload = buildTemplatePayload(s, { forInsert: false });
  const data = await sbReq(
    `sastanci_templates?id=eq.${encodeURIComponent(id)}`,
    'PATCH',
    payload,
  );
  const row = Array.isArray(data) && data[0] ? data[0] : null;
  if (!row) return null;

  const deleted = await sbReq(`sastanci_template_ucesnici?template_id=eq.${encodeURIComponent(id)}`, 'DELETE');
  if (deleted === null) {
    console.error('[sastanciTemplates] updateTemplate: delete učesnika nije uspeo', id);
    return null;
  }
  if (ucesnici?.length) {
    const up = ucesnici.map(u => ({
      template_id: id,
      email: String(u.email || '').toLowerCase().trim(),
      label: u.label || null,
    }));
    const inserted = await sbReq('sastanci_template_ucesnici', 'POST', up);
    if (inserted === null) {
      console.error('[sastanciTemplates] updateTemplate: insert učesnika nije uspeo', id);
      return null;
    }
  }
  return row ? { ...mapRow(row), ucesnici: ucesnici || [] } : null;
}

export async function deleteTemplate(id) {
  if (!id || !getIsOnline()) return false;
  return (await sbReq(`sastanci_templates?id=eq.${encodeURIComponent(id)}`, 'DELETE')) !== null;
}

/**
 * Kreira sastanak + učesnike (trenutni korisnik uvek u listi radi RLS).
 */
export async function instantiateTemplate(tpl) {
  if (!getIsOnline() || !tpl?.id) return null;
  const cols = 'id,naziv,tip,mesto,vodio_email,zapisnicar_email,cadence,cadence_dow,cadence_dom,vreme,napomena,is_active,created_by_email,created_at,updated_at';
  const rows = await sbReq(
    `sastanci_templates?id=eq.${encodeURIComponent(tpl.id)}&select=${cols},sastanci_template_ucesnici(email,label)&limit=1`,
  );
  const row = Array.isArray(rows) && rows[0];
  const full = row
    ? { ...mapRow(row), ucesnici: (row.sastanci_template_ucesnici || []).map(u => ({ email: String(u.email || '').toLowerCase().trim(), label: u.label || '' })) }
    : tpl;
  const datum = nextOccurrence(full);
  const cu = getCurrentUser();
  const ucesEmails = new Map();
  (full.ucesnici || []).forEach(u => {
    ucesEmails.set(u.email, u.label || u.email);
  });
  if (cu?.email) {
    const em = String(cu.email).toLowerCase();
    if (!ucesEmails.has(em)) ucesEmails.set(em, cu.email);
  }
  const created = await saveSastanak({
    tip: full.tip || 'sedmicni',
    naslov: full.naziv,
    datum,
    vreme: full.vreme,
    mesto: full.mesto || '',
    status: 'planiran',
    vodioEmail: full.vodioEmail,
    zapisnicarEmail: full.zapisnicarEmail,
    napomena: full.napomena || null,
  });
  if (!created?.id) return null;
  const bulk = Array.from(ucesEmails.entries()).map(([email, label]) => ({
    email,
    label: label || email,
    prisutan: true,
    pozvan: true,
    napomena: null,
  }));
  await saveUcesnici(created.id, bulk);
  return loadSastanak(created.id);
}
