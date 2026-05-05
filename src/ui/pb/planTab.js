/**
 * Tab Plan — kartice (mobilni) + tabela (desktop), statistike, alarmi, load meter.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  PB_TASK_STATUS,
  PB_TASK_VRSTA,
  PB_PRIORITET,
  statusBadgeClass,
  prioClass,
  engineerDotClass,
  prioDotClass,
  openTaskEditorModal,
  openTextAreaModal,
  confirmDeletePbTask,
  loadPbState,
  syncPbModuleFilters,
} from './shared.js';
import { updatePbTask } from '../../services/pb.js';
import { canEditProjektniBiro } from '../../state/auth.js';

function parseYmd(s) {
  if (!s) return null;
  const d = new Date(String(s).slice(0, 10) + 'T12:00:00');
  return Number.isNaN(d.getTime()) ? null : d;
}

function startOfDay(d) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

/** Broj radnih dana (pon–pet) između dva datuma uključujući krajeve. */
export function countWorkdaysBetween(a, b) {
  const da = parseYmd(a);
  const db = parseYmd(b);
  if (!da || !db) return null;
  let x = startOfDay(da <= db ? da : db);
  const end = startOfDay(da <= db ? db : da);
  let n = 0;
  while (x <= end) {
    const dow = x.getDay();
    if (dow !== 0 && dow !== 6) n += 1;
    x = new Date(x);
    x.setDate(x.getDate() + 1);
  }
  return n;
}

function delayRealEnd(task) {
  const planEnd = parseYmd(task.datum_zavrsetka_plan);
  const realEnd = parseYmd(task.datum_zavrsetka_real);
  if (!planEnd || !realEnd) return null;
  const diff = Math.round((startOfDay(realEnd) - startOfDay(planEnd)) / 86400000);
  return diff > 0 ? diff : null;
}

function filterTasks(tasks, f) {
  let list = tasks.slice();
  const q = (f.search || '').trim().toLowerCase();
  if (q) {
    list = list.filter(t => String(t.naziv || '').toLowerCase().includes(q));
  }
  if (f.status && f.status !== 'all') {
    list = list.filter(t => t.status === f.status);
  }
  if (f.vrsta && f.vrsta !== 'all') {
    list = list.filter(t => t.vrsta === f.vrsta);
  }
  if (f.prioritet && f.prioritet !== 'all') {
    list = list.filter(t => t.prioritet === f.prioritet);
  }
  if (!f.showDone) {
    list = list.filter(t => t.status !== 'Završeno');
  }
  if (f.problemOnly) {
    list = list.filter(t => String(t.problem || '').trim().length > 0);
  }
  return list;
}

function sortTasks(list, col, dir) {
  const m = dir === 'desc' ? -1 : 1;
  const cmp = (a, b) => {
    if (col === 'naziv') return m * String(a.naziv || '').localeCompare(String(b.naziv || ''), 'sr');
    if (col === 'project') {
      const pa = `${a.project_code || ''} ${a.project_name || ''}`;
      const pb = `${b.project_code || ''} ${b.project_name || ''}`;
      return m * pa.localeCompare(pb, 'sr');
    }
    if (col === 'engineer') return m * String(a.engineer_name || '').localeCompare(String(b.engineer_name || ''), 'sr');
    if (col === 'vrsta') return m * String(a.vrsta || '').localeCompare(String(b.vrsta || ''), 'sr');
    if (col === 'datumi') {
      const da = a.datum_zavrsetka_plan || '';
      const db = b.datum_zavrsetka_plan || '';
      return m * da.localeCompare(db);
    }
    if (col === 'trajanje') {
      const ta = countWorkdaysBetween(a.datum_pocetka_plan, a.datum_zavrsetka_plan) ?? -1;
      const tb = countWorkdaysBetween(b.datum_pocetka_plan, b.datum_zavrsetka_plan) ?? -1;
      return m * (ta - tb);
    }
    if (col === 'status') return m * String(a.status || '').localeCompare(String(b.status || ''), 'sr');
    if (col === 'pct') return m * ((Number(a.procenat_zavrsenosti) || 0) - (Number(b.procenat_zavrsenosti) || 0));
    if (col === 'prio') {
      const order = { Visok: 0, Srednji: 1, Nizak: 2 };
      return m * ((order[a.prioritet] ?? 9) - (order[b.prioritet] ?? 9));
    }
    if (col === 'norma') return m * ((Number(a.norma_sati_dan) || 0) - (Number(b.norma_sati_dan) || 0));
    return 0;
  };
  return list.slice().sort(cmp);
}

function buildAlarms(tasks, loadRows) {
  const alarms = [];
  const today = startOfDay(new Date());

  for (const t of tasks) {
    const done = t.status === 'Završeno';
    const planEnd = parseYmd(t.datum_zavrsetka_plan);
    const planStart = parseYmd(t.datum_pocetka_plan);
    const tid = String(t.id || '');
    if (!done && planEnd) {
      const days = Math.round((startOfDay(planEnd) - today) / 86400000);
      const proj = [t.project_code, t.project_name].filter(Boolean).join(' · ');
      const eng = String(t.engineer_name || '').trim() || '—';
      if (days < 0) {
        alarms.push({
          key: `due_${tid}`,
          level: 'red',
          title: 'Rok je istekao',
          meta: `${proj} · ${t.naziv || '(bez naziva)'} · ${eng}`,
        });
      } else if (days <= 3) {
        const title = days === 0 ? 'Rok ističe danas' : `Rok ističe za ${days}d`;
        alarms.push({
          key: `soon_${tid}`,
          level: 'yellow',
          title,
          meta: `${proj} · ${t.naziv || ''} · ${eng}`,
        });
      }
    }
    if (!done && planStart) {
      const ds = Math.round((startOfDay(planStart) - today) / 86400000);
      if (ds >= 0 && ds <= 3 && !t.employee_id) {
        alarms.push({
          key: `nostart_${tid}`,
          level: 'yellow',
          title: `Počinje za ≤3 dana, nema inženjera`,
          meta: `${t.naziv || ''}`,
        });
      }
    }
    if (!done && planStart && startOfDay(planStart) < today && !t.employee_id) {
      alarms.push({
        key: `nobeg_${tid}`,
        level: 'red',
        title: `Počelo bez inženjera`,
        meta: `${t.naziv || ''}`,
      });
    }
  }

  const seenLoad = new Set();
  for (const r of loadRows || []) {
    if (Number(r.load_pct) > 100 && r.employee_id && !seenLoad.has(r.employee_id)) {
      seenLoad.add(r.employee_id);
      alarms.push({
        key: `cap_${r.employee_id}`,
        level: 'red',
        title: `Prekoračenje kapaciteta (${r.load_pct}%)`,
        meta: `${r.full_name || ''}`,
      });
    }
  }

  return alarms;
}

const PB_ALARM_DISMISS_KEY = 'pb_plan_alarm_dismiss_v1';

function loadDismissedAlarmKeys() {
  try {
    const raw = sessionStorage.getItem(PB_ALARM_DISMISS_KEY);
    const a = raw ? JSON.parse(raw) : [];
    return Array.isArray(a) ? a.map(String) : [];
  } catch {
    return [];
  }
}

function saveDismissedAlarmKeys(keys) {
  sessionStorage.setItem(PB_ALARM_DISMISS_KEY, JSON.stringify(keys));
}

const PB_LOAD_OPEN_KEY = 'pb_load_section_open_v1';

function initialsFromName(name) {
  const p = String(name || '').trim().split(/\s+/).filter(Boolean);
  if (!p.length) return '?';
  if (p.length === 1) return p[0].slice(0, 2).toUpperCase();
  return (p[0][0] + p[p.length - 1][0]).toUpperCase();
}

/**
 * @param {HTMLElement} root
 * @param {{
 *   tasks: object[],
 *   projects: object[],
 *   engineers: object[],
 *   loadStats: object[],
 *   onRefresh: () => void,
 * }} ctx
 */
export function renderPlanTab(root, ctx) {
  const canEdit = canEditProjektniBiro();
  const pbMod = loadPbState();
  let filters = {
    search: pbMod.moduleSearch ?? '',
    status: 'all',
    vrsta: 'all',
    prioritet: 'all',
    showDone: pbMod.moduleShowDone ?? false,
    problemOnly: false,
  };
  let sortCol = 'datumi';
  let sortDir = 'asc';
  let loadOpen = (() => {
    try {
      return sessionStorage.getItem(PB_LOAD_OPEN_KEY) !== '0';
    } catch {
      return true;
    }
  })();

  function filtered() {
    return filterTasks(ctx.tasks || [], filters);
  }

  function paint() {
    const tasks = filtered();
    const sorted = sortTasks(tasks, sortCol, sortDir);
    const allAlarms = buildAlarms(ctx.tasks || [], ctx.loadStats || []);
    const dismissed = new Set(loadDismissedAlarmKeys());
    const alarms = allAlarms.filter(a => !dismissed.has(a.key));

    const total = tasks.length;
    const doneN = tasks.filter(t => t.status === 'Završeno').length;
    const pctDone = total ? Math.round((doneN / total) * 100) : 0;
    const inProg = tasks.filter(t => t.status === 'U toku' || t.status === 'Pregled').length;
    const blockedN = tasks.filter(t => t.status === 'Blokirano').length;
    const activeForNorm = tasks.filter(t => t.status !== 'Završeno').length;
    const normSum = activeForNorm
      ? tasks
        .filter(t => t.status !== 'Završeno')
        .reduce((s, t) => s + (Number(t.norma_sati_dan) || 0), 0) / activeForNorm
      : 0;
    const normRounded = Math.round(normSum * 10) / 10;

    const alarmHtml = alarms.slice(0, 6).map(a => `
      <div class="pb-alert-strip pb-alert-strip--${escHtml(a.level)}" role="alert" data-alarm-key="${escHtml(a.key)}">
        <span class="pb-alert-dot" aria-hidden="true"></span>
        <div class="pb-alert-body">
          <strong class="pb-alert-title">${escHtml(a.title)}</strong>
          <div class="pb-alert-meta">${escHtml(a.meta)}</div>
        </div>
        <button type="button" class="pb-alert-close" data-dismiss-alarm="${escHtml(a.key)}" aria-label="Zatvori upozorenje">✕</button>
      </div>`).join('');

    const loadRows = ctx.loadStats || [];
    const loadHtml = loadRows.map(r => {
      const p = Number(r.load_pct) || 0;
      const th = Number(r.total_hours);
      const mh = Number(r.max_hours);
      const hoursTxt = Number.isFinite(th) && Number.isFinite(mh)
        ? `${Math.round(th)}h/${Math.round(mh)}h`
        : '';
      let segClass = 'pb-load-seg pb-load-seg--ok';
      if (p >= 50 && p <= 80) segClass = 'pb-load-seg pb-load-seg--warn';
      if (p > 80) segClass = 'pb-load-seg pb-load-seg--danger';
      const dotClass = engineerDotClass(r.full_name);
      return `
        <div class="pb-load-row">
          <div class="pb-load-person">
            <span class="pb-load-avatar ${dotClass}">${escHtml(initialsFromName(r.full_name))}</span>
            <span class="pb-load-name">${escHtml(r.full_name || '')}</span>
          </div>
          <div class="pb-load-track-wrap">
            <div class="pb-load-track" aria-hidden="true">
              <div class="${segClass}" style="width:${Math.min(p, 150)}%"></div>
            </div>
          </div>
          <div class="pb-load-right">
            <span class="pb-load-pct-num">${p}%</span>
            ${hoursTxt ? `<span class="pb-load-hours">${escHtml(hoursTxt)}</span>` : ''}
          </div>
        </div>`;
    }).join('');

    const today = new Date();
    const end = new Date(today);
    end.setDate(end.getDate() + 30);
    const fmt = d => `${d.getDate()}/${d.getMonth() + 1}`;
    const loadMetaBits = [];
    if (loadRows.length) {
      const mx = Math.max(...loadRows.map(r => Number(r.load_pct) || 0), 0);
      const totH = loadRows.reduce((s, r) => s + (Number(r.total_hours) || 0), 0);
      const maxH = loadRows[0] != null ? Number(loadRows[0].max_hours) : null;
      loadMetaBits.push(`${fmt(today)} — ${fmt(end)}`);
      if (Number.isFinite(maxH)) loadMetaBits.push(`MAX ${Math.round(maxH)}H`);
      loadMetaBits.push(`max ${mx}%`);
    }

    const statsHtml = `
      <div class="pb-stats-grid">
        <div class="pb-stat-card pb-stat-card--accent">
          <span class="pb-stat-label">Zadaci</span>
          <div class="pb-stat-value">${total}</div>
          <div class="pb-stat-sub">${inProg} u toku</div>
        </div>
        <div class="pb-stat-card">
          <span class="pb-stat-label">Završeno</span>
          <div class="pb-stat-value">${doneN}</div>
          <div class="pb-stat-sub">${pctDone}%</div>
        </div>
        <div class="pb-stat-card">
          <span class="pb-stat-label">Norma (h/dan)</span>
          <div class="pb-stat-value">${Number.isFinite(normRounded) ? normRounded : 0}</div>
          <div class="pb-stat-sub">h dnevno prosek</div>
        </div>
        <div class="pb-stat-card pb-stat-card--danger">
          <span class="pb-stat-label">Blokirano</span>
          <div class="pb-stat-value pb-stat-value--danger">${blockedN}</div>
          <div class="pb-stat-sub pb-stat-sub--danger">${blockedN ? 'Akcija!' : '—'}</div>
        </div>
      </div>`;

    const filterHtml = `
      <div class="pb-filter-toolbar">
        <div class="pb-filter-row pb-filter-row--search">
          <label class="pb-filter-grow">
            <span class="pb-filter-lbl">Pretraga</span>
            <span class="pb-search-wrap">
              <span class="pb-search-ic" aria-hidden="true"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg></span>
              <input type="search" class="pb-search" placeholder="Pretraga…" id="pbSearch" value="${escHtml(filters.search)}" />
            </span>
          </label>
          <button type="button" class="btn btn-outline btn-sm" id="pbFReset">✕ Reset</button>
        </div>
        <div class="pb-filter-row pb-filter-row--filters">
          <label class="pb-filter-field"><span class="pb-filter-lbl">Status</span>
            <select id="pbFStatus" class="pb-select-sm">
              <option value="all">Svi</option>
              ${PB_TASK_STATUS.map(s => `<option value="${escHtml(s)}" ${filters.status === s ? 'selected' : ''}>${escHtml(s)}</option>`).join('')}
            </select>
          </label>
          <label class="pb-filter-field"><span class="pb-filter-lbl">Prioritet</span>
            <select id="pbFPrio" class="pb-select-sm">
              <option value="all">Svi</option>
              ${PB_PRIORITET.map(s => `<option value="${escHtml(s)}" ${filters.prioritet === s ? 'selected' : ''}>${escHtml(s)}</option>`).join('')}
            </select>
          </label>
          <label class="pb-filter-field"><span class="pb-filter-lbl">Vrsta</span>
            <select id="pbFVrsta" class="pb-select-sm">
              <option value="all">Sve</option>
              ${PB_TASK_VRSTA.map(s => `<option value="${escHtml(s)}" ${filters.vrsta === s ? 'selected' : ''}>${escHtml(s)}</option>`).join('')}
            </select>
          </label>
          <button type="button" class="btn btn-sm ${filters.problemOnly ? 'pb-toggle-on' : 'btn-outline'}" id="pbFProb">⚠ Problemi</button>
          <label class="pb-filter-check"><input type="checkbox" id="pbFDone" ${filters.showDone ? 'checked' : ''} /><span>☐ Završeni</span></label>
        </div>
      </div>`;

    const cardsHtml = sorted.map(t => {
      const strike = t.status === 'Završeno' ? ' style="text-decoration:line-through;opacity:.85"' : '';
      const projLabel = [t.project_code, t.project_name].filter(Boolean).join(' — ');
      const wd = countWorkdaysBetween(t.datum_pocetka_plan, t.datum_zavrsetka_plan);
      const delay = delayRealEnd(t);
      const delayTxt = delay ? `+${delay}d` : '';
      return `
        <article class="pb-card">
          <div class="pb-card-head">
            <h3 class="pb-card-title"${strike}>${escHtml(t.naziv || '')}</h3>
            <span class="${statusBadgeClass(t.status)}">${escHtml(t.status || '')}</span>
          </div>
          <div class="pb-card-meta">${escHtml(projLabel)} · ${escHtml(t.vrsta || '')}</div>
          ${String(t.problem || '').trim() ? `<div class="pb-problem-badge">⚠ problem</div>` : ''}
          <div class="pb-card-engineer">
            <span class="pb-avatar ${engineerDotClass(t.engineer_name)}">${escHtml(initialsFromName(t.engineer_name))}</span>
            <span>${escHtml(t.engineer_name || '—')}</span>
          </div>
          <div class="pb-card-dates">
            <span>Plan poč.</span><span>${escHtml((t.datum_pocetka_plan || '').slice(0, 10) || '—')}</span>
            <span>Plan rok</span><span>${escHtml((t.datum_zavrsetka_plan || '').slice(0, 10) || '—')}</span>
            <span>Real poč.</span><span>${escHtml((t.datum_pocetka_real || '').slice(0, 10) || '—')}</span>
            <span>Real zavr.</span><span>${escHtml((t.datum_zavrsetka_real || '').slice(0, 10) || '—')} ${delayTxt ? `<em>${escHtml(delayTxt)}</em>` : ''}</span>
          </div>
          <div class="pb-card-metrics">
            <span>Trajanje</span><strong>${wd != null ? wd + ' rd' : '—'}</strong>
            <span>Norma</span><strong>${Number(t.norma_sati_dan) || 0} h/d</strong>
            <span class="${prioClass(t.prioritet)}">${escHtml(t.prioritet || '')}</span>
          </div>
          <div class="pb-progress"><div class="pb-progress-fill" style="width:${Math.min(100, Number(t.procenat_zavrsenosti) || 0)}%"></div></div>
          <div class="pb-card-actions">
            ${canEdit ? `<button type="button" class="btn btn-sm pb-act-edit" data-id="${escHtml(t.id)}">✏ Izmeni</button>` : ''}
            <button type="button" class="btn btn-sm pb-act-desc" data-id="${escHtml(t.id)}">📄 Opis</button>
            ${canEdit ? `<button type="button" class="btn btn-sm pb-act-prob" data-id="${escHtml(t.id)}">⚠ Problem</button>` : ''}
            ${canEdit ? `<button type="button" class="btn btn-sm pb-act-del" data-id="${escHtml(t.id)}">✕ Briši</button>` : ''}
          </div>
        </article>`;
    }).join('');

    const th = (col, label) => {
      const active = sortCol === col;
      const arrow = active ? (sortDir === 'asc' ? ' ▲' : ' ▼') : '';
      return `<th scope="col" class="pb-th-wrap"><button type="button" class="pb-th" data-sort="${escHtml(col)}">${escHtml(label)}${arrow}</button></th>`;
    };

    const rowsHtml = sorted.map((t, i) => {
      const wd = countWorkdaysBetween(t.datum_pocetka_plan, t.datum_zavrsetka_plan);
      const proj = [t.project_code, t.project_name].filter(Boolean).join(' ');
      const strike = t.status === 'Završeno' ? ' pb-done' : '';
      const pct = Math.min(100, Number(t.procenat_zavrsenosti) || 0);
      const hasOpis = String(t.opis || '').trim().length > 0;
      const ini = initialsFromName(t.engineer_name);
      const engDot = engineerDotClass(t.engineer_name);
      const planStart = (t.datum_pocetka_plan || '').slice(0, 10) || '—';
      const planEnd = (t.datum_zavrsetka_plan || '').slice(0, 10) || '—';
      const realStart = (t.datum_pocetka_real || '').slice(0, 10);
      const realEnd = (t.datum_zavrsetka_real || '').slice(0, 10);
      const realLine = [realStart || '—', realEnd || '—'].join(' → ');
      return `<tr class="pb-table-row${strike}">
        <td class="pb-cell-num">${i + 1}</td>
        <td class="pb-cell-name">
          <div class="pb-name-main">${escHtml(t.naziv || '')}</div>
          <div class="pb-name-actions">
            ${canEdit ? `<button type="button" class="pb-chip-act pb-chip-act--muted pb-act-edit" data-id="${escHtml(t.id)}">— Izmeni</button>` : ''}
            <button type="button" class="pb-chip-act pb-chip-act--desc ${hasOpis ? 'pb-chip-act--has-desc' : ''} pb-act-desc" data-id="${escHtml(t.id)}"><span class="pb-act-desc-dot" aria-hidden="true"></span>📄 Opis</button>
            ${canEdit ? `<button type="button" class="pb-chip-act pb-chip-act--warn pb-act-prob" data-id="${escHtml(t.id)}">⚠ Problem</button>` : ''}
            ${canEdit ? `<button type="button" class="pb-chip-act pb-chip-act--danger pb-act-del" data-id="${escHtml(t.id)}">✕ Briši</button>` : ''}
          </div>
        </td>
        <td>${escHtml(proj)}</td>
        <td><span class="pb-td-eng"><span class="pb-td-avatar ${engDot}">${escHtml(ini)}</span><span class="pb-td-eng-name">${escHtml(t.engineer_name || '—')}</span></span></td>
        <td><span class="pb-vrsta-pill">${escHtml(t.vrsta || '')}</span></td>
        <td class="pb-cell-dates">
          <div class="pb-date-block"><span class="pb-date-lbl">PLAN</span> <span class="pb-date-range">${escHtml(planStart)} → ${escHtml(planEnd)}</span></div>
          <div class="pb-date-block pb-date-block--real"><span class="pb-date-lbl">OSTVARENO</span> <span class="pb-date-real">${escHtml(realLine)}</span></div>
        </td>
        <td>${wd != null ? wd : '—'}</td>
        <td><span class="${statusBadgeClass(t.status)}">${escHtml(t.status || '')}</span></td>
        <td class="pb-cell-pct"><div class="pb-mini-bar-wrap" aria-hidden="true"><div class="pb-mini-bar" style="width:${pct}%"></div></div><span class="pb-pct-txt">${pct}%</span></td>
        <td><span class="pb-prio-cell"><span class="${prioDotClass(t.prioritet)}" aria-hidden="true"></span><span>${escHtml(t.prioritet || '')}</span></span></td>
        <td>${Number(t.norma_sati_dan) || 0}</td>
      </tr>`;
    }).join('');

    root.innerHTML = `
      ${statsHtml}
      ${alarmHtml ? `<div class="pb-alert-stack">${alarmHtml}</div>` : ''}
      <section class="pb-load-collapsible ${loadOpen ? 'is-open' : ''}" id="pbLoadSection" aria-label="Opterećenje">
        <button type="button" class="pb-load-head" id="pbLoadToggle" aria-expanded="${loadOpen}">
          <span class="pb-load-head-text">
            <span class="pb-load-head-title">OPTEREĆENOST ZA NAREDNIH 30 DANA</span>
            ${loadMetaBits.length ? `<span class="pb-load-head-meta">(${escHtml(loadMetaBits.join(' — '))})</span>` : ''}
          </span>
          <span class="pb-load-chevron" aria-hidden="true">▾</span>
        </button>
        <div class="pb-load-panel">
          <div class="pb-load-list">${loadHtml || '<p class="pb-muted">Nema podataka</p>'}</div>
        </div>
      </section>
      ${filterHtml}
      ${canEdit ? `<button type="button" class="pb-add-wide" id="pbWideAdd">+ Novi zadatak</button>` : ''}
      <div class="pb-plan-split">
        <div class="pb-cards-wrap">${cardsHtml || '<p class="pb-muted">Nema zadataka za filter.</p>'}</div>
        <div class="pb-table-wrap">
          <table class="pb-table pb-table--plan">
            <thead><tr>
              <th scope="col" class="pb-th-num">#</th>
              ${th('naziv', 'Naziv')}
              ${th('project', 'Projekat')}
              ${th('engineer', 'Inženjer')}
              ${th('vrsta', 'Vrsta')}
              ${th('datumi', 'Datumi')}
              ${th('trajanje', 'Trajanje')}
              ${th('status', 'Status')}
              ${th('pct', '%')}
              ${th('prio', 'Prioritet')}
              ${th('norma', 'Norma')}
            </tr></thead>
            <tbody>${rowsHtml || ''}</tbody>
          </table>
        </div>
      </div>`;

    root.querySelector('#pbSearch')?.addEventListener('input', e => {
      filters.search = e.target.value;
      syncPbModuleFilters({ moduleSearch: filters.search });
      paint();
    });
    root.querySelector('#pbFStatus')?.addEventListener('change', e => {
      filters.status = e.target.value;
      paint();
    });
    root.querySelector('#pbFVrsta')?.addEventListener('change', e => {
      filters.vrsta = e.target.value;
      paint();
    });
    root.querySelector('#pbFPrio')?.addEventListener('change', e => {
      filters.prioritet = e.target.value;
      paint();
    });
    root.querySelector('#pbFDone')?.addEventListener('change', e => {
      filters.showDone = e.target.checked;
      syncPbModuleFilters({ moduleShowDone: filters.showDone });
      paint();
    });
    root.querySelector('#pbFProb')?.addEventListener('click', () => {
      filters.problemOnly = !filters.problemOnly;
      paint();
    });
    root.querySelector('#pbFReset')?.addEventListener('click', () => {
      filters = { search: '', status: 'all', vrsta: 'all', prioritet: 'all', showDone: false, problemOnly: false };
      syncPbModuleFilters({ moduleSearch: '', moduleShowDone: false });
      paint();
    });

    root.querySelector('#pbWideAdd')?.addEventListener('click', () => {
      openTaskEditorModal({
        task: null,
        projects: ctx.projects,
        engineers: ctx.engineers,
        canEdit,
        onSaved: () => ctx.onRefresh?.(),
      });
    });

    root.querySelector('#pbLoadToggle')?.addEventListener('click', () => {
      loadOpen = !loadOpen;
      try {
        sessionStorage.setItem(PB_LOAD_OPEN_KEY, loadOpen ? '1' : '0');
      } catch { /* ignore */ }
      const sec = root.querySelector('#pbLoadSection');
      const btn = root.querySelector('#pbLoadToggle');
      if (sec) sec.classList.toggle('is-open', loadOpen);
      if (btn) btn.setAttribute('aria-expanded', String(loadOpen));
    });

    root.querySelectorAll('[data-dismiss-alarm]').forEach(btn => {
      btn.addEventListener('click', e => {
        e.stopPropagation();
        const k = btn.getAttribute('data-dismiss-alarm');
        if (!k) return;
        const next = loadDismissedAlarmKeys();
        if (!next.includes(k)) next.push(k);
        saveDismissedAlarmKeys(next);
        const row = btn.closest('.pb-alert-strip');
        row?.classList.add('pb-alert-strip--out');
        setTimeout(() => {
          row?.remove();
        }, 220);
      });
    });

    root.querySelectorAll('.pb-th').forEach(btn => {
      btn.addEventListener('click', () => {
        const col = btn.getAttribute('data-sort');
        if (sortCol === col) sortDir = sortDir === 'asc' ? 'desc' : 'asc';
        else {
          sortCol = col;
          sortDir = 'asc';
        }
        paint();
      });
    });

    const findTask = id => (ctx.tasks || []).find(x => x.id === id);

    root.querySelectorAll('.pb-act-edit').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        const task = findTask(id);
        if (!task) return;
        openTaskEditorModal({
          task,
          projects: ctx.projects,
          engineers: ctx.engineers,
          canEdit,
          onSaved: () => ctx.onRefresh?.(),
        });
      });
    });

    root.querySelectorAll('.pb-act-desc').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        const task = findTask(id);
        if (!task) return;
        openTextAreaModal({
          title: 'Opis zadatka',
          initial: task.opis || '',
          canEdit,
          onSave: async v => {
            if (!canEdit) return;
            const ok = await updatePbTask(id, { opis: v });
            if (ok) {
              showToast('Opis sačuvan');
              ctx.onRefresh?.();
            } else showToast('Greška');
          },
        });
      });
    });

    root.querySelectorAll('.pb-act-prob').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        const task = findTask(id);
        if (!task) return;
        openTextAreaModal({
          title: 'Problem / prepreka',
          initial: task.problem || '',
          hint: 'Ako postoji problem, razmotri status „Blokirano".',
          canEdit,
          onSave: async v => {
            if (!canEdit) return;
            const ok = await updatePbTask(id, { problem: v });
            if (ok) {
              showToast('Problem sačuvan');
              ctx.onRefresh?.();
            } else showToast('Greška');
          },
        });
      });
    });

    root.querySelectorAll('.pb-act-del').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        confirmDeletePbTask(id, () => ctx.onRefresh?.());
      });
    });
  }

  paint();
}
