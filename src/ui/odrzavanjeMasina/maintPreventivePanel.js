/**
 * CMMS Preventiva i kalendar rokova.
 */

import { escHtml } from '../../lib/dom.js';
import {
  fetchMaintMachines,
  fetchMaintMachineStatuses,
  fetchMaintTaskDueDates,
  fetchMaintUserProfile,
} from '../../services/maintenance.js';

const SEVERITIES = [
  { id: 'all', label: 'Sve ozbiljnosti' },
  { id: 'critical', label: 'Kritično' },
  { id: 'important', label: 'Važno' },
  { id: 'normal', label: 'Normalno' },
];

function startOfToday() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

function endOfDay(d) {
  const x = new Date(d);
  x.setHours(23, 59, 59, 999);
  return x;
}

function addDays(d, n) {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}

function fmtDateTime(iso) {
  return iso ? String(iso).replace('T', ' ').slice(0, 16) : '—';
}

function relDate(iso) {
  const t = new Date(iso);
  if (!Number.isFinite(t.getTime())) return '—';
  const today = startOfToday();
  const day = new Date(t);
  day.setHours(0, 0, 0, 0);
  const diff = Math.round((day.getTime() - today.getTime()) / 86400000);
  if (diff < 0) return `kasni ${Math.abs(diff)} d`;
  if (diff === 0) return 'danas';
  if (diff === 1) return 'sutra';
  return `za ${diff} d`;
}

function severityLabel(v) {
  if (v === 'critical') return 'Kritično';
  if (v === 'important') return 'Važno';
  return 'Normalno';
}

function severityBadge(v) {
  if (v === 'critical') return 'mnt-badge mnt-badge--down';
  if (v === 'important') return 'mnt-badge mnt-badge--degraded';
  return 'mnt-badge';
}

function machinePath(code) {
  return `/maintenance/machine/${encodeURIComponent(code)}/kontrole`;
}

function statusLabel(v) {
  if (v === 'down') return 'Zastoj';
  if (v === 'degraded') return 'Smetnja';
  if (v === 'maintenance') return 'Održavanje';
  return 'Radi';
}

function statusBadgeClass(v) {
  if (v === 'down') return 'mnt-badge mnt-badge--down';
  if (v === 'degraded') return 'mnt-badge mnt-badge--degraded';
  if (v === 'maintenance') return 'mnt-badge mnt-badge--maintenance';
  return 'mnt-badge mnt-badge--running';
}

function bucketDueDates(rows) {
  const sod = startOfToday();
  const eod = endOfDay(sod);
  const weekEnd = endOfDay(addDays(sod, 7));
  const monthEnd = endOfDay(addDays(sod, 30));
  const overdue = [];
  const today = [];
  const week = [];
  const later = [];
  for (const row of Array.isArray(rows) ? rows : []) {
    const t = new Date(row.next_due_at);
    if (!Number.isFinite(t.getTime())) continue;
    if (t < sod) overdue.push(row);
    else if (t <= eod) today.push(row);
    else if (t <= weekEnd) week.push(row);
    else if (t <= monthEnd) later.push(row);
  }
  return { overdue, today, week, later };
}

function normalizeDueRows(dues, machines, statuses) {
  const nameByCode = new Map((Array.isArray(machines) ? machines : []).map(m => [m.machine_code, m.name || m.machine_code]));
  const statusByCode = new Map((Array.isArray(statuses) ? statuses : []).map(s => [s.machine_code, s]));
  return (Array.isArray(dues) ? dues : []).map(d => {
    const status = statusByCode.get(d.machine_code) || {};
    return {
      ...d,
      display_name: nameByCode.get(d.machine_code) || d.machine_code,
      machine_status: status.status || 'running',
      override_reason: status.override_reason || null,
      override_valid_until: status.override_valid_until || null,
    };
  });
}

function applyFilters(rows, state) {
  const q = String(state.q || '').trim().toLowerCase();
  return rows.filter(r => {
    if (state.severity !== 'all' && r.severity !== state.severity) return false;
    if (state.bucket !== 'all') {
      const t = new Date(r.next_due_at);
      const sod = startOfToday();
      const eod = endOfDay(sod);
      const weekEnd = endOfDay(addDays(sod, 7));
      if (state.bucket === 'overdue' && !(t < sod)) return false;
      if (state.bucket === 'today' && !(t >= sod && t <= eod)) return false;
      if (state.bucket === 'week' && !(t > eod && t <= weekEnd)) return false;
    }
    if (!q) return true;
    return `${r.machine_code} ${r.display_name} ${r.title}`.toLowerCase().includes(q);
  });
}

function rowHtml(r) {
  const paused = !!r.override_reason;
  const pauseBadge = paused
    ? `<span class="${statusBadgeClass(r.machine_status)}" title="${escHtml(r.override_reason || '')}">PAUZA · ${escHtml(statusLabel(r.machine_status))}</span>`
    : '';
  return `<tr class="${paused ? 'mnt-preventive-paused' : ''}">
    <td>
      <button type="button" class="mnt-linkish" data-mnt-nav="${escHtml(machinePath(r.machine_code))}">${escHtml(r.display_name)}</button>
      <div class="mnt-muted">${escHtml(r.machine_code || '')}</div>
    </td>
    <td>
      <strong>${escHtml(r.title || '')}</strong>
      <div class="mnt-muted">${escHtml(String(r.interval_value || ''))} ${escHtml(r.interval_unit || '')} · grace ${escHtml(String(r.grace_period_days ?? 0))} d</div>
    </td>
    <td><span class="${severityBadge(r.severity)}">${escHtml(severityLabel(r.severity))}</span></td>
    <td>${escHtml(fmtDateTime(r.next_due_at))}<div class="mnt-muted">${escHtml(relDate(r.next_due_at))}</div></td>
    <td>${escHtml(fmtDateTime(r.last_performed_at))}</td>
    <td>${pauseBadge || `<span class="${statusBadgeClass(r.machine_status)}">${escHtml(statusLabel(r.machine_status))}</span>`}</td>
  </tr>`;
}

function kpiHtml(label, value, tone, bucket) {
  return `<button type="button" class="mnt-kpi ${tone} ${value ? '' : 'mnt-kpi--zero'}" data-mnt-preventive-bucket="${escHtml(bucket)}">
    <span class="mnt-kpi-label">${escHtml(label)}</span>
    <span class="mnt-kpi-val">${escHtml(String(value))}</span>
  </button>`;
}

/**
 * @param {HTMLElement} host
 * @param {{ onNavigateToPath?: (path:string)=>void }} opts
 */
export async function renderMaintPreventivePanel(host, opts = {}) {
  host.innerHTML = `<div class="mnt-panel"><p class="mnt-muted">Učitavam preventivne rokove…</p></div>`;
  const [dues, machines, statuses, prof] = await Promise.all([
    fetchMaintTaskDueDates(),
    fetchMaintMachines(),
    fetchMaintMachineStatuses(),
    fetchMaintUserProfile(),
  ]);
  if (!host.isConnected) return;
  if (dues === null) {
    host.innerHTML = `<div class="mnt-panel"><p class="mnt-muted">Ne mogu da učitam rokove. Proveri migraciju ili RLS.</p></div>`;
    return;
  }
  const rows = normalizeDueRows(dues, machines, statuses);
  const state = { q: '', severity: 'all', bucket: 'all' };

  const render = () => {
    const buckets = bucketDueDates(rows);
    const filtered = applyFilters(rows, state);
    const severityOpts = SEVERITIES.map(s => `<option value="${escHtml(s.id)}"${state.severity === s.id ? ' selected' : ''}>${escHtml(s.label)}</option>`).join('');
    host.innerHTML = `
      <div class="mnt-assets-head">
        <div>
          <h3 style="font-size:16px;margin:0 0 4px">Preventiva</h3>
          <p class="mnt-muted" style="margin:0">Operativni pregled preventivnih kontrola iz aktivnih šablona po mašinama.</p>
        </div>
        <button type="button" class="mnt-catalog-link" data-mnt-nav="/maintenance/calendar">Kalendar →</button>
      </div>
      ${prof ? '' : '<p class="mnt-info-banner"><span class="mnt-info-banner-ico">i</span><span class="mnt-info-banner-body"><strong>Nema profila održavanja</strong>Prikaz zavisi od RLS vidljivosti mašina.</span></p>'}
      <div class="mnt-kpi-row">
        ${kpiHtml('Kasni rokovi', buckets.overdue.length, 'mnt-kpi--late', 'overdue')}
        ${kpiHtml('Danas', buckets.today.length, 'mnt-kpi--today', 'today')}
        ${kpiHtml('Narednih 7 dana', buckets.week.length, 'mnt-kpi--maintenance', 'week')}
        ${kpiHtml('Do 30 dana', buckets.later.length, '', 'all')}
      </div>
      <div class="mnt-preventive-toolbar">
        <input class="form-input" id="mntPreventiveSearch" value="${escHtml(state.q)}" placeholder="Pretraga mašine ili kontrole…">
        <select class="form-input" id="mntPreventiveSeverity">${severityOpts}</select>
        <select class="form-input" id="mntPreventiveBucket">
          <option value="all"${state.bucket === 'all' ? ' selected' : ''}>Svi rokovi</option>
          <option value="overdue"${state.bucket === 'overdue' ? ' selected' : ''}>Kasni</option>
          <option value="today"${state.bucket === 'today' ? ' selected' : ''}>Danas</option>
          <option value="week"${state.bucket === 'week' ? ' selected' : ''}>Narednih 7 dana</option>
        </select>
        <span class="mnt-muted">${filtered.length} od ${rows.length}</span>
      </div>
      <div class="mnt-table-wrap">
        <table class="mnt-table">
          <thead><tr><th>Mašina</th><th>Kontrola</th><th>Ozbiljnost</th><th>Rok</th><th>Poslednje</th><th>Status</th></tr></thead>
          <tbody>${filtered.length ? filtered.map(rowHtml).join('') : '<tr><td colspan="6" class="mnt-muted">Nema stavki za izabrane filtere.</td></tr>'}</tbody>
        </table>
      </div>`;
    host.querySelector('#mntPreventiveSearch')?.addEventListener('input', e => {
      state.q = e.target.value || '';
      render();
    });
    host.querySelector('#mntPreventiveSeverity')?.addEventListener('change', e => {
      state.severity = e.target.value || 'all';
      render();
    });
    host.querySelector('#mntPreventiveBucket')?.addEventListener('change', e => {
      state.bucket = e.target.value || 'all';
      render();
    });
    host.querySelectorAll('[data-mnt-preventive-bucket]').forEach(btn => {
      btn.addEventListener('click', () => {
        state.bucket = btn.getAttribute('data-mnt-preventive-bucket') || 'all';
        render();
      });
    });
    host.querySelectorAll('[data-mnt-nav]').forEach(btn => {
      btn.addEventListener('click', () => {
        const path = btn.getAttribute('data-mnt-nav');
        if (path) opts.onNavigateToPath?.(path);
      });
    });
  };
  render();
}

function sameDate(a, b) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function monthTitle(d) {
  return d.toLocaleDateString('sr-Latn-RS', { month: 'long', year: 'numeric' });
}

function calendarDayHtml(day, rows, month) {
  const inMonth = day.getMonth() === month.getMonth();
  const dayRows = rows.filter(r => sameDate(new Date(r.next_due_at), day)).slice(0, 4);
  return `<div class="mnt-cal-day ${inMonth ? '' : 'mnt-cal-day--muted'}">
    <div class="mnt-cal-date">${day.getDate()}</div>
    <div class="mnt-cal-items">
      ${dayRows.map(r => `<button type="button" class="mnt-cal-item mnt-cal-item--${escHtml(r.severity || 'normal')}" data-mnt-nav="${escHtml(machinePath(r.machine_code))}" title="${escHtml(r.display_name + ' · ' + r.title)}">${escHtml(r.display_name)} · ${escHtml(r.title || '')}</button>`).join('')}
      ${rows.filter(r => sameDate(new Date(r.next_due_at), day)).length > 4 ? '<span class="mnt-muted">+ još</span>' : ''}
    </div>
  </div>`;
}

/**
 * @param {HTMLElement} host
 * @param {{ onNavigateToPath?: (path:string)=>void }} opts
 */
export async function renderMaintCalendarPanel(host, opts = {}) {
  host.innerHTML = `<div class="mnt-panel"><p class="mnt-muted">Učitavam kalendar…</p></div>`;
  const [dues, machines, statuses] = await Promise.all([
    fetchMaintTaskDueDates({ limit: 3000 }),
    fetchMaintMachines(),
    fetchMaintMachineStatuses(),
  ]);
  if (!host.isConnected) return;
  if (dues === null) {
    host.innerHTML = `<div class="mnt-panel"><p class="mnt-muted">Ne mogu da učitam kalendar rokova.</p></div>`;
    return;
  }
  const rows = normalizeDueRows(dues, machines, statuses);
  const state = { month: new Date() };
  state.month.setDate(1);
  state.month.setHours(0, 0, 0, 0);

  const render = () => {
    const first = new Date(state.month);
    const start = new Date(first);
    const weekday = (start.getDay() + 6) % 7;
    start.setDate(start.getDate() - weekday);
    const days = Array.from({ length: 42 }, (_, i) => addDays(start, i));
    const monthRows = rows.filter(r => {
      const t = new Date(r.next_due_at);
      return t.getFullYear() === state.month.getFullYear() && t.getMonth() === state.month.getMonth();
    });
    const lateRows = rows.filter(r => new Date(r.next_due_at) < startOfToday()).slice(0, 8);
    host.innerHTML = `
      <div class="mnt-assets-head">
        <div>
          <h3 style="font-size:16px;margin:0 0 4px">Kalendar održavanja</h3>
          <p class="mnt-muted" style="margin:0">Mesečni prikaz preventivnih rokova. Klik na stavku otvara kontrole mašine.</p>
        </div>
        <button type="button" class="mnt-catalog-link" data-mnt-nav="/maintenance/preventive">Preventiva →</button>
      </div>
      <div class="mnt-cal-layout">
        <section class="mnt-dash-card">
          <div class="mnt-cal-head">
            <button type="button" class="btn btn-xs" id="mntCalPrev">←</button>
            <h3>${escHtml(monthTitle(state.month))}</h3>
            <button type="button" class="btn btn-xs" id="mntCalNext">→</button>
          </div>
          <div class="mnt-cal-weekdays"><span>Pon</span><span>Uto</span><span>Sre</span><span>Čet</span><span>Pet</span><span>Sub</span><span>Ned</span></div>
          <div class="mnt-cal-grid">${days.map(day => calendarDayHtml(day, rows, state.month)).join('')}</div>
        </section>
        <aside class="mnt-dash-card">
          <div class="mnt-att-head"><h3>U ovom mesecu</h3><span class="mnt-muted">${monthRows.length}</span></div>
          <ul class="mnt-dash-mini-list">${monthRows.slice(0, 12).map(r => `<li class="mnt-dash-mini-row">
            <button type="button" class="mnt-linkish" data-mnt-nav="${escHtml(machinePath(r.machine_code))}">${escHtml(r.display_name)}</button>
            <span>${escHtml(r.title || '')}</span>
            <span class="mnt-muted">${escHtml(relDate(r.next_due_at))}</span>
          </li>`).join('') || '<li class="mnt-muted">Nema rokova u mesecu.</li>'}</ul>
          <div class="mnt-att-head" style="margin-top:16px"><h3>Kasni</h3><span class="mnt-muted">${lateRows.length}</span></div>
          <ul class="mnt-dash-mini-list">${lateRows.map(r => `<li class="mnt-dash-mini-row">
            <button type="button" class="mnt-linkish" data-mnt-nav="${escHtml(machinePath(r.machine_code))}">${escHtml(r.display_name)}</button>
            <span>${escHtml(r.title || '')}</span>
            <span class="mnt-muted">${escHtml(relDate(r.next_due_at))}</span>
          </li>`).join('') || '<li class="mnt-muted">Nema kašnjenja.</li>'}</ul>
        </aside>
      </div>`;
    host.querySelector('#mntCalPrev')?.addEventListener('click', () => {
      state.month.setMonth(state.month.getMonth() - 1);
      render();
    });
    host.querySelector('#mntCalNext')?.addEventListener('click', () => {
      state.month.setMonth(state.month.getMonth() + 1);
      render();
    });
    host.querySelectorAll('[data-mnt-nav]').forEach(btn => {
      btn.addEventListener('click', () => {
        const path = btn.getAttribute('data-mnt-nav');
        if (path) opts.onNavigateToPath?.(path);
      });
    });
  };
  render();
}
