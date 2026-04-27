/**
 * CMMS izveštaji i analitika.
 */

import { rowsToCsv, CSV_BOM } from '../../lib/csv.js';
import { escHtml, showToast } from '../../lib/dom.js';
import {
  fetchMaintIncidents,
  fetchMaintMachineStatuses,
  fetchMaintMachines,
  fetchMaintTaskDueDates,
  fetchMaintWorkOrders,
} from '../../services/maintenance.js';

const PERIODS = [
  { id: '30', label: '30 dana', days: 30 },
  { id: '90', label: '90 dana', days: 90 },
  { id: '365', label: '12 meseci', days: 365 },
  { id: 'all', label: 'Sve', days: null },
];

function dt(iso) {
  const d = new Date(iso);
  return Number.isFinite(d.getTime()) ? d : null;
}

function inPeriod(row, field, period) {
  if (!period?.days) return true;
  const d = dt(row?.[field]);
  if (!d) return false;
  return d >= new Date(Date.now() - period.days * 86400000);
}

function fmtNum(v) {
  return new Intl.NumberFormat('sr-Latn-RS').format(Number(v) || 0);
}

function severityLabel(v) {
  if (v === 'critical') return 'Kritično';
  if (v === 'major') return 'Veći';
  if (v === 'minor') return 'Manji';
  return v || '—';
}

function statusLabel(v) {
  const m = {
    open: 'Otvoren',
    triage: 'Trijaža',
    in_progress: 'U radu',
    resolved: 'Rešen',
    closed: 'Zatvoren',
    novi: 'Novi',
    potvrden: 'Potvrđen',
    dodeljen: 'Dodeljen',
    u_radu: 'U radu',
    ceka_deo: 'Čeka deo',
    ceka_dobavljaca: 'Čeka dobavljača',
    ceka_korisnika: 'Čeka korisnika',
    kontrola: 'Kontrola',
    zavrsen: 'Završen',
    otkazan: 'Otkazan',
    running: 'Radi',
    degraded: 'Smetnja',
    down: 'Zastoj',
    maintenance: 'Održavanje',
  };
  return m[v] || v || '—';
}

function countBy(rows, keyFn) {
  const m = new Map();
  for (const row of rows) {
    const k = keyFn(row);
    if (!k) continue;
    m.set(k, (m.get(k) || 0) + 1);
  }
  return [...m.entries()].sort((a, b) => b[1] - a[1]);
}

function sumBy(rows, keyFn, valFn) {
  const m = new Map();
  for (const row of rows) {
    const k = keyFn(row);
    if (!k) continue;
    m.set(k, (m.get(k) || 0) + (Number(valFn(row)) || 0));
  }
  return [...m.entries()].sort((a, b) => b[1] - a[1]);
}

function machinePath(code) {
  return `/maintenance/machine/${encodeURIComponent(code)}/pregled`;
}

function downloadCsv(text, filename) {
  const blob = new Blob([text], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function kpi(label, value, hint, tone = '') {
  return `<div class="mnt-kpi ${tone} ${Number(value) ? '' : 'mnt-kpi--zero'}">
    <span class="mnt-kpi-label">${escHtml(label)}</span>
    <span class="mnt-kpi-val">${escHtml(fmtNum(value))}</span>
    ${hint ? `<span class="mnt-muted">${escHtml(hint)}</span>` : ''}
  </div>`;
}

function barRows(entries, total, opts = {}) {
  const max = Math.max(...entries.map(e => Number(e[1]) || 0), 1);
  return entries.length
    ? entries.map(([label, value]) => {
        const pct = Math.round(((Number(value) || 0) / max) * 100);
        const share = total ? ` · ${Math.round(((Number(value) || 0) / total) * 100)}%` : '';
        const name = opts.labelFn ? opts.labelFn(label) : label;
        const link = opts.pathFn ? `<button type="button" class="mnt-linkish" data-mnt-nav="${escHtml(opts.pathFn(label))}">${escHtml(name)}</button>` : escHtml(name);
        return `<li class="mnt-report-bar-row">
          <div class="mnt-report-bar-head"><span>${link}</span><strong>${escHtml(fmtNum(value))}${escHtml(share)}</strong></div>
          <div class="mnt-report-bar"><span style="width:${pct}%"></span></div>
        </li>`;
      }).join('')
    : '<li class="mnt-muted">Nema podataka za izabrani period.</li>';
}

function tableRows(rows, nameByCode) {
  return rows.slice(0, 20).map(i => {
    const name = nameByCode.get(i.machine_code) || i.machine_code || '—';
    return `<tr>
      <td><button type="button" class="mnt-linkish" data-mnt-nav="${escHtml(machinePath(i.machine_code || ''))}">${escHtml(name)}</button><div class="mnt-muted">${escHtml(i.machine_code || '')}</div></td>
      <td>${escHtml(i.title || '')}</td>
      <td>${escHtml(severityLabel(i.severity))}</td>
      <td>${escHtml(statusLabel(i.status))}</td>
      <td>${escHtml(String(i.reported_at || '').replace('T', ' ').slice(0, 16))}</td>
      <td>${escHtml(fmtNum(i.downtime_minutes || 0))}</td>
    </tr>`;
  }).join('');
}

/**
 * @param {HTMLElement} host
 * @param {{ onNavigateToPath?: (path:string)=>void }} opts
 */
export async function renderMaintReportsPanel(host, opts = {}) {
  host.innerHTML = `<div class="mnt-panel"><p class="mnt-muted">Učitavam izveštaje…</p></div>`;
  const [incidents, workOrders, dues, statuses, machines] = await Promise.all([
    fetchMaintIncidents({ limit: 2000 }),
    fetchMaintWorkOrders({ limit: 1000 }),
    fetchMaintTaskDueDates({ limit: 3000 }),
    fetchMaintMachineStatuses({ limit: 1000 }),
    fetchMaintMachines({ limit: 3000 }),
  ]);
  if (!host.isConnected) return;
  if (!Array.isArray(incidents) || !Array.isArray(workOrders) || !Array.isArray(dues)) {
    host.innerHTML = `<div class="mnt-panel"><p class="mnt-muted">Ne mogu da učitam izveštaje. Proveri RLS ili migracije.</p></div>`;
    return;
  }

  const nameByCode = new Map((Array.isArray(machines) ? machines : []).map(m => [m.machine_code, m.name || m.machine_code]));
  const state = { period: '90' };

  const render = () => {
    const period = PERIODS.find(p => p.id === state.period) || PERIODS[1];
    const inc = incidents.filter(r => inPeriod(r, 'reported_at', period));
    const wo = workOrders.filter(r => inPeriod(r, 'created_at', period));
    const openInc = inc.filter(i => !['resolved', 'closed'].includes(String(i.status || '').toLowerCase()));
    const activeWo = wo.filter(w => !['zavrsen', 'otkazan'].includes(String(w.status || '').toLowerCase()));
    const downtime = inc.reduce((sum, i) => sum + (Number(i.downtime_minutes) || 0), 0);
    const overdueDue = dues.filter(d => dt(d.next_due_at) && dt(d.next_due_at) < new Date());
    const statusRows = Array.isArray(statuses) ? statuses : [];
    const downMachines = statusRows.filter(s => s.status === 'down').length;
    const degradedMachines = statusRows.filter(s => s.status === 'degraded').length;
    const byMachine = countBy(inc, i => i.machine_code).slice(0, 10);
    const downtimeByMachine = sumBy(inc, i => i.machine_code, i => i.downtime_minutes).slice(0, 10);
    const bySeverity = countBy(inc, i => i.severity);
    const woByStatus = countBy(wo, w => w.status);
    const woByPriority = countBy(wo, w => w.priority);
    const periodOpts = PERIODS.map(p => `<option value="${escHtml(p.id)}"${state.period === p.id ? ' selected' : ''}>${escHtml(p.label)}</option>`).join('');

    host.innerHTML = `
      <div class="mnt-assets-head">
        <div>
          <h3 style="font-size:16px;margin:0 0 4px">Izveštaji održavanja</h3>
          <p class="mnt-muted" style="margin:0">Kvarovi, zastoji, radni nalozi i preventiva za izabrani period.</p>
        </div>
        <div class="mnt-report-actions">
          <select class="form-input" id="mntReportPeriod">${periodOpts}</select>
          <button type="button" class="btn btn-xs" id="mntReportCsv">Export CSV</button>
        </div>
      </div>
      <div class="mnt-kpi-row">
        ${kpi('Incidenti', inc.length, `${openInc.length} otvoreno`, 'mnt-kpi--degraded')}
        ${kpi('Downtime min', downtime, 'zbir prijavljenog zastoja', 'mnt-kpi--down')}
        ${kpi('Aktivni WO', activeWo.length, `${wo.length} ukupno`, 'mnt-kpi--maintenance')}
        ${kpi('Kasni preventive', overdueDue.length, 'trenutni rokovi', 'mnt-kpi--late')}
        ${kpi('Mašine u zastoju', downMachines, `${degradedMachines} smetnje`, 'mnt-kpi--down')}
      </div>
      <div class="mnt-report-grid">
        <section class="mnt-dash-card">
          <div class="mnt-att-head"><h3>Top mašine po kvarovima</h3><span class="mnt-muted">${inc.length}</span></div>
          <ul class="mnt-report-bar-list">${barRows(byMachine, inc.length, { labelFn: c => nameByCode.get(c) || c, pathFn: machinePath })}</ul>
        </section>
        <section class="mnt-dash-card">
          <div class="mnt-att-head"><h3>Top downtime</h3><span class="mnt-muted">minuti</span></div>
          <ul class="mnt-report-bar-list">${barRows(downtimeByMachine, downtime, { labelFn: c => nameByCode.get(c) || c, pathFn: machinePath })}</ul>
        </section>
        <section class="mnt-dash-card">
          <div class="mnt-att-head"><h3>Incidenti po ozbiljnosti</h3></div>
          <ul class="mnt-report-bar-list">${barRows(bySeverity, inc.length, { labelFn: severityLabel })}</ul>
        </section>
        <section class="mnt-dash-card">
          <div class="mnt-att-head"><h3>WO statusi / prioriteti</h3></div>
          <ul class="mnt-report-bar-list">${barRows(woByStatus, wo.length, { labelFn: statusLabel })}</ul>
          <hr class="mnt-report-sep">
          <ul class="mnt-report-bar-list">${barRows(woByPriority, wo.length)}</ul>
        </section>
      </div>
      <section class="mnt-dash-card" style="margin-top:16px">
        <div class="mnt-att-head"><h3>Poslednji incidenti u periodu</h3><span class="mnt-muted">${inc.length}</span></div>
        <div class="mnt-table-wrap">
          <table class="mnt-table">
            <thead><tr><th>Mašina</th><th>Naslov</th><th>Ozbiljnost</th><th>Status</th><th>Prijava</th><th>Downtime min</th></tr></thead>
            <tbody>${tableRows(inc, nameByCode) || '<tr><td colspan="6" class="mnt-muted">Nema incidenata.</td></tr>'}</tbody>
          </table>
        </div>
      </section>`;

    host.querySelector('#mntReportPeriod')?.addEventListener('change', e => {
      state.period = e.target.value || '90';
      render();
    });
    host.querySelector('#mntReportCsv')?.addEventListener('click', () => {
      const headers = ['machine_code', 'machine_name', 'title', 'severity', 'status', 'reported_at', 'downtime_minutes', 'work_order'];
      const rows = inc.map(i => [
        i.machine_code,
        nameByCode.get(i.machine_code) || '',
        i.title,
        severityLabel(i.severity),
        statusLabel(i.status),
        i.reported_at,
        i.downtime_minutes || 0,
        i.maint_work_orders?.wo_number || '',
      ]);
      downloadCsv(CSV_BOM + rowsToCsv(headers, rows), `odrzavanje_izvestaj_${period.id}_${new Date().toISOString().slice(0, 10)}.csv`);
      showToast('✅ CSV izvezen');
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
