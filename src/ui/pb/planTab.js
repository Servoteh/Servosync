/**
 * Tab Plan — statistike, alarmi, opterećenost (collapsible), filter toolbar, tabela.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  PB_TASK_STATUS,
  PB_TASK_VRSTA,
  PB_PRIORITET,
  statusBadgeClass,
  prioClass,
  openTaskEditorModal,
  openTextAreaModal,
  confirmDeletePbTask,
  loadPbState,
  syncPbModuleFilters,
} from './shared.js';
import { updatePbTask } from '../../services/pb.js';
import { canEditProjektniBiro } from '../../state/auth.js';

const IC_CHEVRON = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>';
const IC_REFRESH = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>';

let _loadOpen = false;

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

function fmtDate(s) {
  if (!s) return '—';
  const d = s.slice(0, 10);
  const parts = d.split('-');
  if (parts.length !== 3) return d;
  return `${parts[2]}.${parts[1]}.`;
}

function filterTasks(tasks, f) {
  let list = tasks.slice();
  const q = (f.search || '').trim().toLowerCase();
  if (q) list = list.filter(t => String(t.naziv || '').toLowerCase().includes(q));
  if (f.status && f.status !== 'all') list = list.filter(t => t.status === f.status);
  if (f.vrsta && f.vrsta !== 'all') list = list.filter(t => t.vrsta === f.vrsta);
  if (f.prioritet && f.prioritet !== 'all') list = list.filter(t => t.prioritet === f.prioritet);
  if (!f.showDone) list = list.filter(t => t.status !== 'Završeno');
  if (f.problemOnly) list = list.filter(t => String(t.problem || '').trim().length > 0);
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
    if (col === 'datumi') return m * (a.datum_zavrsetka_plan || '').localeCompare(b.datum_zavrsetka_plan || '');
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
    if (!done && planEnd) {
      const days = Math.round((startOfDay(planEnd) - today) / 86400000);
      if (days < 0) alarms.push({ level: 'red', text: `Rok prošao: ${t.naziv || '(bez naziva)'}` });
      else if (days <= 3) alarms.push({ level: 'yellow', text: `Rok za ≤3 dana: ${t.naziv || ''}` });
    }
    if (!done && planStart) {
      const ds = Math.round((startOfDay(planStart) - today) / 86400000);
      if (ds >= 0 && ds <= 3 && !t.employee_id) {
        alarms.push({ level: 'yellow', text: `Počinje za ≤3 dana, nema inženjera: ${t.naziv || ''}` });
      }
    }
    if (!done && planStart && startOfDay(planStart) < today && !t.employee_id) {
      alarms.push({ level: 'red', text: `Počelo bez inženjera: ${t.naziv || ''}` });
    }
  }
  const seenLoad = new Set();
  for (const r of loadRows || []) {
    if (Number(r.load_pct) > 100 && r.employee_id && !seenLoad.has(r.employee_id)) {
      seenLoad.add(r.employee_id);
      alarms.push({ level: 'red', text: `Prekoračenje kapaciteta (${r.load_pct}%): ${r.full_name || ''}` });
    }
  }
  return alarms;
}

/**
 * @param {HTMLElement} root
 * @param {{ tasks, projects, engineers, loadStats, onRefresh }} ctx
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

  function filtered() {
    return filterTasks(ctx.tasks || [], filters);
  }

  function paint() {
    const tasks = filtered();
    const sorted = sortTasks(tasks, sortCol, sortDir);
    const alarms = buildAlarms(ctx.tasks || [], ctx.loadStats || []);

    const total = tasks.length;
    const doneN = tasks.filter(t => t.status === 'Završeno').length;
    const pctDone = total ? Math.round((doneN / total) * 100) : 0;
    const blockedN = tasks.filter(t => t.status === 'Blokirano').length;
    const normSum = tasks
      .filter(t => t.status !== 'Završeno')
      .reduce((s, t) => s + (Number(t.norma_sati_dan) || 0), 0);

    /* ── Stat cards ── */
    const statsHtml = `
      <div class="pb-stats-grid">
        <div class="pb-stat-card">
          <span>Zadaci</span>
          <strong>${total}</strong>
          <small class="pb-stat-sub">u toku: ${tasks.filter(t => t.status === 'U toku').length}</small>
        </div>
        <div class="pb-stat-card">
          <span>Završeno</span>
          <strong>${pctDone}%</strong>
          <small class="pb-stat-sub">${doneN} / ${total}</small>
        </div>
        <div class="pb-stat-card">
          <span>Norma Σ (h/dan)</span>
          <strong>${normSum}</strong>
          <small class="pb-stat-sub">h dnevni prosek</small>
        </div>
        <div class="pb-stat-card pb-stat-card--alert">
          <span>Blokirano</span>
          <strong style="color:${blockedN > 0 ? 'var(--risk-high,#EB5757)' : 'inherit'}">${blockedN}</strong>
          <small class="pb-stat-sub">Akcije</small>
        </div>
      </div>`;

    /* ── Alarms ── */
    const alarmHtml = alarms.length
      ? `<div class="pb-alarm-box" role="alert">
          ${alarms.map(a => `<div class="pb-alarm pb-alarm--${escHtml(a.level)}">${escHtml(a.text)}</div>`).join('')}
        </div>`
      : '';

    /* ── Load section (collapsible) ── */
    const loadRowsHtml = (ctx.loadStats || []).map(r => {
      const p = Number(r.load_pct) || 0;
      let barCls = 'pb-load-bar__fill';
      if (p > 100) barCls += ' pb-load-bar__fill--danger';
      else if (p >= 80) barCls += ' pb-load-bar__fill--warn';
      else barCls += ' pb-load-bar__fill--ok';
      return `<div class="pb-load-row">
        <span class="pb-load-name">${escHtml(r.full_name || '')}</span>
        <div class="pb-load-bar" aria-hidden="true"><div class="${barCls}" style="width:${Math.min(p, 150)}%"></div></div>
        <span class="pb-load-pct">${p}%</span>
      </div>`;
    }).join('');

    const loadHtml = `
      <section class="pb-load-section" aria-label="Opterećenost inženjera">
        <button type="button" class="pb-load-header" id="pbLoadToggle">
          <span class="pb-load-header-title">Opterećenost narednih 20 radnih dana</span>
          <span class="pb-load-chevron ${_loadOpen ? 'open' : ''}">${IC_CHEVRON}</span>
        </button>
        <div class="pb-load-content ${_loadOpen ? 'open' : ''}">
          <div class="pb-load-inner">
            <div class="pb-load-grid">${loadRowsHtml || '<p class="pb-muted">Nema podataka</p>'}</div>
          </div>
        </div>
      </section>`;

    /* ── Filter toolbar ── */
    const hasActiveFilter = filters.status !== 'all' || filters.vrsta !== 'all'
      || filters.prioritet !== 'all' || filters.problemOnly || filters.showDone || filters.search;

    const filterHtml = `
      <div class="pb-filter-toolbar">
        <div class="pb-ft-field">
          <span class="pb-ft-label">Pretraga</span>
          <input type="search" class="pb-ft-search" id="pbSearch" placeholder="Pretraži naziv..." value="${escHtml(filters.search)}" />
        </div>
        <div class="pb-ft-field">
          <span class="pb-ft-label">Status</span>
          <select id="pbFStatus" class="pb-ft-select ${filters.status !== 'all' ? 'active' : ''}">
            <option value="all">Svi</option>
            ${PB_TASK_STATUS.map(s => `<option value="${escHtml(s)}" ${filters.status === s ? 'selected' : ''}>${escHtml(s)}</option>`).join('')}
          </select>
        </div>
        <div class="pb-ft-field">
          <span class="pb-ft-label">Prioritet</span>
          <select id="pbFPrio" class="pb-ft-select ${filters.prioritet !== 'all' ? 'active' : ''}">
            <option value="all">Svi</option>
            ${PB_PRIORITET.map(s => `<option value="${escHtml(s)}" ${filters.prioritet === s ? 'selected' : ''}>${escHtml(s)}</option>`).join('')}
          </select>
        </div>
        <div class="pb-ft-field">
          <span class="pb-ft-label">Vrsta</span>
          <select id="pbFVrsta" class="pb-ft-select ${filters.vrsta !== 'all' ? 'active' : ''}">
            <option value="all">Sve</option>
            ${PB_TASK_VRSTA.map(s => `<option value="${escHtml(s)}" ${filters.vrsta === s ? 'selected' : ''}>${escHtml(s)}</option>`).join('')}
          </select>
        </div>
        <div class="pb-ft-field">
          <span class="pb-ft-label">&nbsp;</span>
          <div class="pb-ft-toggles">
            <button type="button" class="pb-ft-toggle ${filters.problemOnly ? 'active' : ''}" id="pbFProb">⚠ Problemi</button>
            <button type="button" class="pb-ft-toggle ${filters.showDone ? 'active' : ''}" id="pbFDoneBtn">☐ Završeni</button>
          </div>
        </div>
        <div class="pb-ft-field">
          <span class="pb-ft-label">&nbsp;</span>
          <button type="button" class="pb-ft-refresh" id="pbRefreshBtn" title="Osveži">${IC_REFRESH}</button>
        </div>
        ${hasActiveFilter ? '<button type="button" class="pb-ft-reset" id="pbFReset">✕ Reset</button>' : ''}
      </div>`;

    /* ── Mobile cards ── */
    const cardsHtml = sorted.map(t => {
      const strike = t.status === 'Završeno' ? ' style="text-decoration:line-through;opacity:.85"' : '';
      const projLabel = [t.project_code, t.project_name].filter(Boolean).join(' — ');
      const wd = countWorkdaysBetween(t.datum_pocetka_plan, t.datum_zavrsetka_plan);
      const delay = delayRealEnd(t);
      return `
        <article class="pb-card">
          <div class="pb-card-head">
            <h3 class="pb-card-title"${strike}>${escHtml(t.naziv || '')}</h3>
            <span class="${statusBadgeClass(t.status)}">${escHtml(t.status || '')}</span>
          </div>
          <div class="pb-card-meta">${escHtml(projLabel)} · ${escHtml(t.vrsta || '')}</div>
          ${String(t.problem || '').trim() ? '<div class="pb-problem-badge">⚠ problem</div>' : ''}
          <div class="pb-card-engineer">
            <span class="pb-avatar">${escHtml((t.engineer_name || '?').slice(0, 1))}</span>
            <span>${escHtml(t.engineer_name || '—')}</span>
          </div>
          <div class="pb-card-dates">
            <span>Plan poč.</span><span>${escHtml(fmtDate(t.datum_pocetka_plan))}</span>
            <span>Plan rok</span><span>${escHtml(fmtDate(t.datum_zavrsetka_plan))}</span>
            <span>Ostvaren poč.</span><span>${escHtml(fmtDate(t.datum_pocetka_real))}</span>
            <span>Ostvaren zavr.</span><span>${escHtml(fmtDate(t.datum_zavrsetka_real))} ${delay ? `<em>+${delay}d</em>` : ''}</span>
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

    /* ── Desktop table ── */
    const th = (col, label) => {
      const active = sortCol === col;
      const arrow = active ? (sortDir === 'asc' ? ' ▲' : ' ▼') : '';
      return `<th scope="col"><button type="button" class="pb-th" data-sort="${escHtml(col)}">${escHtml(label)}${arrow}</button></th>`;
    };

    const rowsHtml = sorted.map((t, i) => {
      const wd = countWorkdaysBetween(t.datum_pocetka_plan, t.datum_zavrsetka_plan);
      const proj = [t.project_code, t.project_name].filter(Boolean).join(' ');
      const strike = t.status === 'Završeno' ? ' class="pb-done"' : '';
      const hasReal = t.datum_pocetka_real || t.datum_zavrsetka_real;
      const pct = Math.min(100, Number(t.procenat_zavrsenosti) || 0);
      const pctFillCls = t.status === 'Završeno' ? 'pb-pct-fill pb-pct-fill--done' : 'pb-pct-fill';
      return `<tr${strike}>
        <td>${i + 1}</td>
        <td>${escHtml(t.naziv || '')}</td>
        <td>${escHtml(proj)}</td>
        <td>${escHtml(t.engineer_name || '—')}</td>
        <td>${escHtml(t.vrsta || '')}</td>
        <td class="pb-td-dates">
          <div class="pb-td-dates-plan"><span class="pb-date-lbl">PLAN</span> ${escHtml(fmtDate(t.datum_pocetka_plan))} <span class="pb-date-sep">→</span> ${escHtml(fmtDate(t.datum_zavrsetka_plan))}</div>
          ${hasReal ? `<div class="pb-td-dates-real"><span class="pb-date-lbl pb-date-lbl--real">OSTVAREN</span> ${escHtml(fmtDate(t.datum_pocetka_real))} <span class="pb-date-sep">→</span> ${escHtml(fmtDate(t.datum_zavrsetka_real))}</div>` : ''}
        </td>
        <td>${wd != null ? wd : '—'}</td>
        <td><span class="${statusBadgeClass(t.status)}">${escHtml(t.status || '')}</span></td>
        <td class="pb-td-pct">
          <div class="pb-pct-wrap">
            <div class="pb-pct-bar"><div class="${pctFillCls}" style="width:${pct}%"></div></div>
            <span class="pb-pct-num">${pct}%</span>
          </div>
        </td>
        <td><span class="${prioClass(t.prioritet)}">${escHtml(t.prioritet || '')}</span></td>
        <td>${Number(t.norma_sati_dan) || 0}</td>
        <td class="pb-row-actions">
          ${canEdit ? `<button type="button" class="pb-icon-btn pb-act-edit" data-id="${escHtml(t.id)}" title="Izmeni">✏</button>` : ''}
          <button type="button" class="pb-icon-btn pb-act-desc" data-id="${escHtml(t.id)}" title="Opis">📄</button>
          ${canEdit ? `<button type="button" class="pb-icon-btn pb-act-prob" data-id="${escHtml(t.id)}" title="Problem">⚠</button>` : ''}
          ${canEdit ? `<button type="button" class="pb-icon-btn pb-icon-btn--danger pb-act-del" data-id="${escHtml(t.id)}" title="Briši">✕</button>` : ''}
        </td>
      </tr>`;
    }).join('');

    root.innerHTML = `
      ${statsHtml}
      ${alarmHtml}
      ${loadHtml}
      ${filterHtml}
      <div class="pb-plan-split">
        <div class="pb-cards-wrap">${cardsHtml || '<p class="pb-muted">Nema zadataka za filter.</p>'}</div>
        <div class="pb-table-wrap">
          <div class="pb-table-container">
            <table class="pb-table">
              <thead><tr>
                <th>#</th>
                ${th('naziv', 'Naziv zadatka')}
                ${th('project', 'Projekat')}
                ${th('engineer', 'Inženjer')}
                ${th('vrsta', 'Vrsta')}
                ${th('datumi', 'Datumi')}
                ${th('trajanje', 'Trajanje')}
                ${th('status', 'Status')}
                ${th('pct', '%')}
                ${th('prio', 'Prioritet')}
                ${th('norma', 'Norma')}
                <th></th>
              </tr></thead>
              <tbody>${rowsHtml || ''}</tbody>
            </table>
          </div>
        </div>
      </div>`;

    /* ── Event listeners ── */

    root.querySelector('#pbLoadToggle')?.addEventListener('click', () => {
      _loadOpen = !_loadOpen;
      const content = root.querySelector('.pb-load-content');
      const chevron = root.querySelector('.pb-load-chevron');
      content?.classList.toggle('open', _loadOpen);
      chevron?.classList.toggle('open', _loadOpen);
    });

    root.querySelector('#pbSearch')?.addEventListener('input', e => {
      filters.search = e.target.value;
      syncPbModuleFilters({ moduleSearch: filters.search });
      paint();
    });
    root.querySelector('#pbFStatus')?.addEventListener('change', e => { filters.status = e.target.value; paint(); });
    root.querySelector('#pbFVrsta')?.addEventListener('change', e => { filters.vrsta = e.target.value; paint(); });
    root.querySelector('#pbFPrio')?.addEventListener('change', e => { filters.prioritet = e.target.value; paint(); });
    root.querySelector('#pbFDoneBtn')?.addEventListener('click', () => {
      filters.showDone = !filters.showDone;
      syncPbModuleFilters({ moduleShowDone: filters.showDone });
      paint();
    });
    root.querySelector('#pbFProb')?.addEventListener('click', () => { filters.problemOnly = !filters.problemOnly; paint(); });
    root.querySelector('#pbFReset')?.addEventListener('click', () => {
      filters = { search: '', status: 'all', vrsta: 'all', prioritet: 'all', showDone: false, problemOnly: false };
      syncPbModuleFilters({ moduleSearch: '', moduleShowDone: false });
      paint();
    });
    root.querySelector('#pbRefreshBtn')?.addEventListener('click', () => ctx.onRefresh?.());

    root.querySelectorAll('.pb-th').forEach(btn => {
      btn.addEventListener('click', () => {
        const col = btn.getAttribute('data-sort');
        if (sortCol === col) sortDir = sortDir === 'asc' ? 'desc' : 'asc';
        else { sortCol = col; sortDir = 'asc'; }
        paint();
      });
    });

    const findTask = id => (ctx.tasks || []).find(x => x.id === id);

    root.querySelectorAll('.pb-act-edit').forEach(btn => {
      btn.addEventListener('click', () => {
        const task = findTask(btn.getAttribute('data-id'));
        if (!task) return;
        openTaskEditorModal({ task, projects: ctx.projects, engineers: ctx.engineers, canEdit, onSaved: () => ctx.onRefresh?.() });
      });
    });

    root.querySelectorAll('.pb-act-desc').forEach(btn => {
      btn.addEventListener('click', () => {
        const task = findTask(btn.getAttribute('data-id'));
        if (!task) return;
        openTextAreaModal({
          title: 'Opis zadatka',
          initial: task.opis || '',
          canEdit,
          onSave: async v => {
            if (!canEdit) return;
            const ok = await updatePbTask(task.id, { opis: v });
            if (ok) { showToast('Opis sačuvan'); ctx.onRefresh?.(); } else showToast('Greška');
          },
        });
      });
    });

    root.querySelectorAll('.pb-act-prob').forEach(btn => {
      btn.addEventListener('click', () => {
        const task = findTask(btn.getAttribute('data-id'));
        if (!task) return;
        openTextAreaModal({
          title: 'Problem / prepreka',
          initial: task.problem || '',
          hint: 'Ako postoji problem, razmotri status "Blokirano".',
          canEdit,
          onSave: async v => {
            if (!canEdit) return;
            const ok = await updatePbTask(task.id, { problem: v });
            if (ok) { showToast('Problem sačuvan'); ctx.onRefresh?.(); } else showToast('Greška');
          },
        });
      });
    });

    root.querySelectorAll('.pb-act-del').forEach(btn => {
      btn.addEventListener('click', () => {
        confirmDeletePbTask(btn.getAttribute('data-id'), () => ctx.onRefresh?.());
      });
    });
  }

  paint();
}
