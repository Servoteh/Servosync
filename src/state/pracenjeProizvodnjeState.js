/**
 * State za modul Praćenje proizvodnje.
 *
 * Jednostavan pub/sub kao u ostalim vanilla modulima. Podaci se pune iz dva
 * RPC-ja i drže u memoriji dok je modul otvoren.
 */

import {
  canEditPracenje,
  fetchOperativneAktivnostiRaw,
  fetchOperativniPlan,
  fetchPracenjeRn,
  listOdeljenja,
  listRadnici,
  setBlokirano,
  skiniBlokadu,
  upsertOperativnaAktivnost,
  zatvoriAktivnost,
} from '../services/pracenjeProizvodnje.js';

export const PRACENJE_TABS = ['po_pozicijama', 'operativni_plan'];

export const pracenjeState = {
  rnId: null,
  header: null,
  tab1Data: null,
  tab2Data: { activities: [] },
  dashboard: null,
  canEdit: false,
  activeTab: 'po_pozicijama',
  loading: false,
  saving: false,
  error: null,
  departments: [],
  radnici: [],
  filters: {
    search: '',
    odeljenje: '',
    status: '',
  },
};

const listeners = new Set();

export function subscribePracenje(callback) {
  listeners.add(callback);
  callback(snapshot());
  return () => listeners.delete(callback);
}

export function getPracenjeSnapshot() {
  return snapshot();
}

export function resetPracenjeState() {
  pracenjeState.rnId = null;
  pracenjeState.header = null;
  pracenjeState.tab1Data = null;
  pracenjeState.tab2Data = { activities: [] };
  pracenjeState.dashboard = null;
  pracenjeState.canEdit = false;
  pracenjeState.loading = false;
  pracenjeState.saving = false;
  pracenjeState.error = null;
  emit();
}

export function setActiveTab(tab) {
  if (!PRACENJE_TABS.includes(tab)) return;
  pracenjeState.activeTab = tab;
  emit();
}

export function setOperativniFilter(name, value) {
  if (!Object.prototype.hasOwnProperty.call(pracenjeState.filters, name)) return;
  pracenjeState.filters[name] = value || '';
  emit();
}

export async function loadPracenje(rnId) {
  if (!rnId) {
    pracenjeState.error = 'Unesi RN ID za učitavanje.';
    emit();
    return false;
  }
  pracenjeState.rnId = rnId;
  pracenjeState.loading = true;
  pracenjeState.error = null;
  emit();

  try {
    const [tab1, tab2, departments, radnici] = await Promise.all([
      fetchPracenjeRn(rnId),
      fetchOperativniPlan({ rnId }),
      listOdeljenja(),
      listRadnici(),
    ]);
    const rawActivities = await fetchOperativneAktivnostiRaw(rnId);
    const activities = mergeActivityDetails(tab2?.activities || [], rawActivities);
    const header = { ...(tab1?.header || {}), ...(tab2?.header || {}) };
    const canEdit = await canEditPracenje(header.projekat_id || null, rnId);

    pracenjeState.header = header;
    pracenjeState.tab1Data = tab1 || { positions: [], summary: {} };
    pracenjeState.tab2Data = { ...(tab2 || {}), activities };
    pracenjeState.dashboard = tab2?.dashboard || null;
    pracenjeState.departments = departments;
    pracenjeState.radnici = radnici;
    pracenjeState.canEdit = canEdit;
    pracenjeState.loading = false;
    pracenjeState.error = null;
    emit();
    return true;
  } catch (e) {
    pracenjeState.loading = false;
    pracenjeState.error = e?.message || String(e);
    emit();
    return false;
  }
}

export async function saveAktivnost(payload) {
  const before = cloneState();
  pracenjeState.saving = true;
  applyOptimisticActivity(payload);
  emit();
  try {
    await upsertOperativnaAktivnost(payload);
    await loadPracenje(pracenjeState.rnId);
    pracenjeState.saving = false;
    emit();
    return true;
  } catch (e) {
    restoreState(before, e);
    return false;
  }
}

export async function closeAktivnost(id, napomena) {
  const before = cloneState();
  pracenjeState.saving = true;
  patchActivity(id, {
    efektivni_status: 'zavrseno',
    status: 'zavrseno',
    zatvoren_napomena: napomena || '',
  });
  emit();
  try {
    await zatvoriAktivnost(id, napomena || '');
    await loadPracenje(pracenjeState.rnId);
    pracenjeState.saving = false;
    emit();
    return true;
  } catch (e) {
    restoreState(before, e);
    return false;
  }
}

export async function blockAktivnost(id, razlog) {
  const before = cloneState();
  pracenjeState.saving = true;
  patchActivity(id, {
    efektivni_status: 'blokirano',
    manual_override_status: 'blokirano',
    blokirano_razlog: razlog,
  });
  emit();
  try {
    await setBlokirano(id, razlog);
    await loadPracenje(pracenjeState.rnId);
    pracenjeState.saving = false;
    emit();
    return true;
  } catch (e) {
    restoreState(before, e);
    return false;
  }
}

export async function unblockAktivnost(id, napomena) {
  const before = cloneState();
  pracenjeState.saving = true;
  patchActivity(id, {
    manual_override_status: null,
    blokirano_razlog: null,
  });
  emit();
  try {
    await skiniBlokadu(id, napomena || '');
    await loadPracenje(pracenjeState.rnId);
    pracenjeState.saving = false;
    emit();
    return true;
  } catch (e) {
    restoreState(before, e);
    return false;
  }
}

export function getFilteredActivities() {
  const f = pracenjeState.filters;
  const search = String(f.search || '').trim().toLowerCase();
  return (pracenjeState.tab2Data?.activities || [])
    .filter(a => {
      if (search) {
        const hay = [
          a.naziv_aktivnosti,
          a.opis,
          a.broj_tp,
          a.kolicina_text,
          a.odgovoran,
          a.odgovoran_label,
          a.rizik_napomena,
        ].join(' ').toLowerCase();
        if (!hay.includes(search)) return false;
      }
      if (f.odeljenje && String(a.odeljenje || a.odeljenje_naziv || '') !== f.odeljenje) return false;
      if (f.status && String(a.efektivni_status || a.status || '') !== f.status) return false;
      return true;
    })
    .sort((a, b) => Number(a.rb || 0) - Number(b.rb || 0));
}

function mergeActivityDetails(rpcActivities, rawActivities) {
  const rawById = new Map((rawActivities || []).map(a => [a.id, a]));
  return (rpcActivities || []).map(a => {
    const raw = rawById.get(a.id) || {};
    return {
      ...raw,
      ...a,
      odeljenje_id: raw.odeljenje_id || a.odeljenje_id || null,
      odeljenje: a.odeljenje || raw.odeljenje_naziv || raw.dashboard_odeljenje || '',
      efektivni_status: a.efektivni_status || raw.efektivni_status || raw.status || 'nije_krenulo',
      status_is_auto: Boolean(a.status_is_auto ?? raw.status_is_auto),
      status_detail: a.status_detail || raw.status_detail || '',
      blokirano_razlog: raw.blokirano_razlog || a.blokirano_razlog || '',
    };
  });
}

function applyOptimisticActivity(payload) {
  const id = payload.id || `temp-${Date.now()}`;
  const dept = pracenjeState.departments.find(d => d.id === payload.odeljenje_id);
  const next = {
    ...payload,
    id,
    odeljenje: dept?.naziv || payload.odeljenje || '',
    efektivni_status: payload.status || 'nije_krenulo',
    status_is_auto: payload.status_mode && payload.status_mode !== 'manual',
  };
  const list = pracenjeState.tab2Data.activities || [];
  const idx = list.findIndex(a => a.id === id);
  if (idx >= 0) list[idx] = { ...list[idx], ...next };
  else list.push(next);
}

function patchActivity(id, patch) {
  const list = pracenjeState.tab2Data.activities || [];
  const idx = list.findIndex(a => a.id === id);
  if (idx >= 0) list[idx] = { ...list[idx], ...patch };
}

function cloneState() {
  return JSON.parse(JSON.stringify({
    tab2Data: pracenjeState.tab2Data,
    dashboard: pracenjeState.dashboard,
    error: pracenjeState.error,
  }));
}

function restoreState(before, err) {
  pracenjeState.tab2Data = before.tab2Data;
  pracenjeState.dashboard = before.dashboard;
  pracenjeState.saving = false;
  pracenjeState.error = err?.message || String(err);
  emit();
}

function snapshot() {
  return {
    ...pracenjeState,
    filters: { ...pracenjeState.filters },
    departments: [...pracenjeState.departments],
    radnici: [...pracenjeState.radnici],
    tab2Data: {
      ...pracenjeState.tab2Data,
      activities: [...(pracenjeState.tab2Data?.activities || [])],
    },
  };
}

function emit() {
  const s = snapshot();
  for (const fn of listeners) {
    try { fn(s); } catch (e) { console.error('[pracenje-state] listener error', e); }
  }
}
