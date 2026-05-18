/**
 * Tab Plan — alarmi, opterećenost (collapsible), filter toolbar, tabela.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  PB_TASK_STATUS,
  PB_TASK_VRSTA,
  PB_PRIORITET,
  PB_BUILTIN_VIEWS,
  statusBadgeClass,
  prioClass,
  openTaskEditorModal,
  openTextAreaModal,
  confirmDeletePbTask,
  loadPbState,
  syncPbModuleFilters,
  loadPbViews,
  savePbView,
  deletePbView,
  pbErrorMessage,
  savePbPlanLoadSectionOpen,
} from './shared.js';
import {
  updatePbTask,
  bulkUpdatePbTasks,
  bulkSoftDeletePbTasks,
} from '../../services/pb.js';
import { downloadCsv } from '../../lib/csv.js';
import { canEditProjektniBiro } from '../../state/auth.js';
import { positionFloatingMenu } from './menuPosition.js';

const IC_CHEVRON = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>';
const IC_REFRESH = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>';

/* Inicijalno stanje panela "Opterećenost" — učitava se iz PB state-a pri prvom render-u. */
let _loadOpen = false;
let _loadOpenLoaded = false;
/* Alarm box je default zatvoren — vidi se samo summary badge ("⚠ 3 alarma"). */
let _alarmsOpen = false;

/** Jednokratno vezivanje resize/scroll/Escape; callback se ažurira svakim paint() (renderPlanTab se ponovo poziva pri svakom ulasku u Plan tab). */
let _pbPlanFloatViewportWired = false;
let _pbPlanFloatScrollRoot = /** @type {HTMLElement|null} */ (null);
let _pbPlanFloatLatestRoot = /** @type {HTMLElement|null} */ (null);
let _pbPlanFloatReposition = /** @type {null | (() => void)} */ (null);
let _pbPlanFloatOnEscape = /** @type {null | (() => void)} */ (null);
let _pbPlanEscapeWired = false;

function wirePbPlanFloatingViewport() {
  if (_pbPlanFloatViewportWired) return;
  _pbPlanFloatViewportWired = true;
  const run = () => {
    if (!_pbPlanFloatLatestRoot?.isConnected) return;
    _pbPlanFloatReposition?.();
  };
  window.addEventListener('resize', run);
  window.addEventListener('scroll', run, { passive: true });
}

function wirePbPlanFloatingScrollRoot(/** @type {HTMLElement} */ scrollRoot) {
  if (_pbPlanFloatScrollRoot === scrollRoot) return;
  _pbPlanFloatScrollRoot = scrollRoot;
  const run = () => {
    if (!_pbPlanFloatLatestRoot?.isConnected) return;
    _pbPlanFloatReposition?.();
  };
  scrollRoot.addEventListener('scroll', run, { passive: true });
}

function wirePbPlanFloatingEscape() {
  if (_pbPlanEscapeWired) return;
  _pbPlanEscapeWired = true;
  document.addEventListener('keydown', e => {
    if (e.key !== 'Escape') return;
    _pbPlanFloatOnEscape?.();
  });
}

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
  if (f.unassignedOnly) list = list.filter(t => !t.employee_id);
  return list;
}

function sortTasks(list, col, dir) {
  const m = dir === 'desc' ? -1 : 1;
  const PRIO_ORDER = { Visok: 0, Srednji: 1, Nizak: 2 };
  const decorated = list.map(t => ({
    t,
    workdays: col === 'trajanje'
      ? (countWorkdaysBetween(t.datum_pocetka_plan, t.datum_zavrsetka_plan) ?? -1)
      : 0,
  }));
  const cmp = (a, b) => {
    const ta = a.t, tb = b.t;
    if (col === 'naziv') return m * String(ta.naziv || '').localeCompare(String(tb.naziv || ''), 'sr');
    if (col === 'project') {
      const pa = `${ta.project_code || ''} ${ta.project_name || ''}`;
      const pb = `${tb.project_code || ''} ${tb.project_name || ''}`;
      return m * pa.localeCompare(pb, 'sr');
    }
    if (col === 'engineer') return m * String(ta.engineer_name || '').localeCompare(String(tb.engineer_name || ''), 'sr');
    if (col === 'vrsta') return m * String(ta.vrsta || '').localeCompare(String(tb.vrsta || ''), 'sr');
    if (col === 'datumi') return m * (ta.datum_zavrsetka_plan || '').localeCompare(tb.datum_zavrsetka_plan || '');
    if (col === 'trajanje') return m * (a.workdays - b.workdays);
    if (col === 'status') return m * String(ta.status || '').localeCompare(String(tb.status || ''), 'sr');
    if (col === 'pct') return m * ((Number(ta.procenat_zavrsenosti) || 0) - (Number(tb.procenat_zavrsenosti) || 0));
    if (col === 'prio') return m * ((PRIO_ORDER[ta.prioritet] ?? 9) - (PRIO_ORDER[tb.prioritet] ?? 9));
    if (col === 'norma') return m * ((Number(ta.norma_sati_dan) || 0) - (Number(tb.norma_sati_dan) || 0));
    return 0;
  };
  return decorated.sort(cmp).map(d => d.t);
}

function buildAlarms(tasks, loadRows) {
  const alarms = [];
  const today = startOfDay(new Date());
  for (const t of tasks) {
    const done = t.status === 'Završeno';
    const planEnd = parseYmd(t.datum_zavrsetka_plan);
    const planStart = parseYmd(t.datum_pocetka_plan);
    const realEnd = parseYmd(t.datum_zavrsetka_real);
    const naziv = t.naziv || '(bez naziva)';
    const noEng = !t.employee_id;

    const reasons = [];
    let level = null;

    if (!done && planEnd) {
      const days = Math.round((startOfDay(planEnd) - today) / 86400000);
      if (days < 0) {
        reasons.push('rok prošao');
        level = 'red';
      } else if (days <= 3) {
        reasons.push(`rok za ≤${days}d`);
        level = level || 'yellow';
      }
    }
    if (!done && planStart) {
      const ds = Math.round((startOfDay(planStart) - today) / 86400000);
      if (startOfDay(planStart) < today && noEng) {
        reasons.push('počelo bez inženjera');
        level = 'red';
      } else if (ds >= 0 && ds <= 3 && noEng) {
        reasons.push('nema inženjera');
        level = level || 'yellow';
      }
    }
    if (done && realEnd && planEnd) {
      const onTime = startOfDay(realEnd) <= startOfDay(planEnd);
      const realEndDay = startOfDay(realEnd);
      // Zeleni alarm samo dan-završetka i prvi sledeći radni dan (preskoči vikend).
      const isToday = realEndDay.getTime() === today.getTime();
      const wd = countWorkdaysBetween(realEndDay, today);
      const isNextWorkday = !isToday && wd != null && wd <= 2 && realEndDay < today;
      if (onTime && (isToday || isNextWorkday)) {
        reasons.push('završen u roku');
        level = 'green';
      }
    }

    if (reasons.length) {
      alarms.push({ level, text: `${naziv} — ${reasons.join(', ')}` });
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
 * @param {{ tasks, projects, engineers, loadStats, teamLoadStats?, onRefresh }} ctx
 */
export function renderPlanTab(root, ctx) {
  const canEdit = canEditProjektniBiro();
  const pbMod = loadPbState();
  if (!_loadOpenLoaded) {
    _loadOpen = pbMod.planLoadSectionOpen ?? false;
    _loadOpenLoaded = true;
  }
  let filters = {
    search: pbMod.moduleSearch ?? '',
    status: pbMod.moduleStatus ?? 'all',
    vrsta: pbMod.moduleVrsta ?? 'all',
    prioritet: pbMod.modulePrioritet ?? 'all',
    showDone: pbMod.moduleShowDone ?? false,
    problemOnly: pbMod.moduleProblemOnly ?? false,
    unassignedOnly: pbMod.moduleUnassignedOnly ?? false,
  };
  let sortCol = 'datumi';
  let sortDir = 'asc';
  let _searchDebounceTimer = null;
  let _delegationAttached = false;
  /** @type {Set<string>} Selektovani task ID-evi za bulk operacije. */
  const _selectedIds = new Set();
  /** @type {null|'status'|'prio'|'engineer'} Otvoreni bulk-action menu. */
  let _bulkMenu = null;
  /** True kad je "Pregledi" dropdown otvoren. */
  let _viewsOpen = false;
  const _mqMobile = window.matchMedia('(max-width: 767px)');
  let _isMobile = _mqMobile.matches;
  const _mqListener = e => {
    if (!root.isConnected) {
      _mqMobile.removeEventListener('change', _mqListener);
      return;
    }
    _isMobile = e.matches;
    paint();
  };
  _mqMobile.addEventListener('change', _mqListener);

  function repositionOpenFloatingMenus() {
    if (!root.isConnected) return;
    if (_viewsOpen) {
      const trigger = root.querySelector('#pbViewsBtn');
      const menu = root.querySelector('.pb-views-menu');
      if (trigger instanceof HTMLElement && menu instanceof HTMLElement) {
        positionFloatingMenu(trigger, menu, 'left');
      }
    }
    const bulkPairs = {
      status: ['#pbBulkStatus', '#pbBulkMenuStatus'],
      prio: ['#pbBulkPrio', '#pbBulkMenuPrio'],
      engineer: ['#pbBulkEng', '#pbBulkMenuEng'],
    };
    if (_bulkMenu && bulkPairs[_bulkMenu]) {
      const [selT, selM] = bulkPairs[_bulkMenu];
      const trig = root.querySelector(selT);
      const menuEl = root.querySelector(selM);
      if (trig instanceof HTMLElement && menuEl instanceof HTMLElement) {
        positionFloatingMenu(trig, menuEl, 'left');
      }
    }
  }

  function filtered() {
    return filterTasks(ctx.tasks || [], filters);
  }

  /** Sačuvaj focus + cursor pozicija pre re-rendera, vrati posle. */
  function preserveFocus(renderFn) {
    const active = document.activeElement;
    const activeId = active?.id;
    const cursorPos = active && 'selectionStart' in active ? active.selectionStart : null;
    const cursorEnd = active && 'selectionEnd' in active ? active.selectionEnd : null;
    renderFn();
    if (activeId) {
      const restored = root.querySelector(`#${activeId}`);
      if (restored) {
        restored.focus();
        if (cursorPos != null && 'setSelectionRange' in restored) {
          try { restored.setSelectionRange(cursorPos, cursorEnd ?? cursorPos); } catch {}
        }
      }
    }
  }

  /** Body HTML (mobile cards ILI desktop table sadržaj .pb-plan-split). */
  function buildBodyHtml(sorted) {
    const cardsHtml = !_isMobile ? '' : sorted.map(t => {
      const strike = t.status === 'Završeno' ? ' style="text-decoration:line-through;opacity:.85"' : '';
      const projLabel = [t.project_code, t.project_name].filter(Boolean).join(' — ');
      const wd = countWorkdaysBetween(t.datum_pocetka_plan, t.datum_zavrsetka_plan);
      const delay = delayRealEnd(t);
      const checked = _selectedIds.has(t.id) ? ' checked' : '';
      const cardSelCls = _selectedIds.has(t.id) ? ' pb-card--selected' : '';
      return `
        <article class="pb-card${cardSelCls}">
          <div class="pb-card-head">
            ${canEdit ? `<input type="checkbox" class="pb-sel" data-id="${escHtml(t.id)}"${checked} aria-label="Selektuj" />` : ''}
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
            ${canEdit ? `<button type="button" class="btn btn-sm pb-act-prob ${String(t.problem || '').trim() ? 'pb-act-prob--active' : ''}" data-id="${escHtml(t.id)}">⚠ Problem</button>` : ''}
            ${canEdit ? `<button type="button" class="btn btn-sm pb-act-del" data-id="${escHtml(t.id)}">✕ Briši</button>` : ''}
          </div>
        </article>`;
    }).join('');

    const th = (col, label, unit) => {
      const active = sortCol === col;
      const arrow = active ? (sortDir === 'asc' ? ' ▲' : ' ▼') : '';
      const unitHtml = unit ? `<small class="pb-th-unit">${escHtml(unit)}</small>` : '';
      return `<th scope="col"><button type="button" class="pb-th" data-sort="${escHtml(col)}"><span class="pb-th-label">${escHtml(label)}${arrow}</span>${unitHtml}</button></th>`;
    };

    const rowsHtml = _isMobile ? '' : sorted.map((t, i) => {
      const wd = countWorkdaysBetween(t.datum_pocetka_plan, t.datum_zavrsetka_plan);
      const proj = [t.project_code, t.project_name].filter(Boolean).join(' ');
      const isSel = _selectedIds.has(t.id);
      const trCls = (t.status === 'Završeno' ? 'pb-done' : '') + (isSel ? ' pb-row--selected' : '');
      const trAttr = trCls.trim() ? ` class="${trCls.trim()}"` : '';
      const hasReal = t.datum_pocetka_real || t.datum_zavrsetka_real;
      const pct = Math.min(100, Number(t.procenat_zavrsenosti) || 0);
      const pctFillCls = t.status === 'Završeno' ? 'pb-pct-fill pb-pct-fill--done' : 'pb-pct-fill';
      const selCell = canEdit
        ? `<td class="pb-td-sel"><input type="checkbox" class="pb-sel" data-id="${escHtml(t.id)}"${isSel ? ' checked' : ''} aria-label="Selektuj" /></td>`
        : '';
      return `<tr${trAttr}>
        ${selCell}
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
        <td>${Number(t.norma_sati_dan) || 0}</td>
        <td><span class="${statusBadgeClass(t.status)}">${escHtml(t.status || '')}</span></td>
        <td class="pb-td-pct">
          <div class="pb-pct-wrap">
            <div class="pb-pct-bar"><div class="${pctFillCls}" style="width:${pct}%"></div></div>
            <span class="pb-pct-num">${pct}%</span>
          </div>
        </td>
        <td><span class="${prioClass(t.prioritet)}">${escHtml(t.prioritet || '')}</span></td>
        <td class="pb-row-actions">
          ${canEdit ? `<button type="button" class="pb-icon-btn pb-act-edit" data-id="${escHtml(t.id)}" title="Izmeni">✏</button>` : ''}
          <button type="button" class="pb-icon-btn pb-act-desc" data-id="${escHtml(t.id)}" title="Opis">📄</button>
          ${canEdit ? `<button type="button" class="pb-icon-btn pb-act-prob ${String(t.problem || '').trim() ? 'pb-act-prob--active' : ''}" data-id="${escHtml(t.id)}" title="${String(t.problem || '').trim() ? 'Problem aktivan' : 'Problem'}">⚠</button>` : ''}
          ${canEdit ? `<button type="button" class="pb-icon-btn pb-icon-btn--danger pb-act-del" data-id="${escHtml(t.id)}" title="Briši">✕</button>` : ''}
        </td>
      </tr>`;
    }).join('');

    const mobileBody = _isMobile
      ? `<div class="pb-cards-wrap">${cardsHtml || '<p class="pb-muted">Nema zadataka za filter.</p>'}</div>`
      : '';
    const visibleIds = sorted.map(t => t.id);
    const allVisibleSelected = visibleIds.length > 0
      && visibleIds.every(id => _selectedIds.has(id));
    const someVisibleSelected = !allVisibleSelected
      && visibleIds.some(id => _selectedIds.has(id));
    const masterAttr = allVisibleSelected ? ' checked'
      : (someVisibleSelected ? ' data-indeterminate="1"' : '');
    const masterHeader = canEdit
      ? `<th class="pb-th-sel"><input type="checkbox" id="pbSelAll" aria-label="Selektuj sve"${masterAttr} /></th>`
      : '';
    // Header cells u nizu — colspan se računa iz dužine, ne iz magičnog broja.
    const headerCells = [
      masterHeader,
      '<th>#</th>',
      th('naziv', 'Naziv zadatka'),
      th('project', 'Projekat'),
      th('engineer', 'Inženjer'),
      th('vrsta', 'Vrsta'),
      th('datumi', 'Datumi'),
      th('trajanje', 'Trajanje', 'dan'),
      th('norma', 'Norma', 'h/dan'),
      th('status', 'Status'),
      th('pct', '%'),
      th('prio', 'Prioritet'),
      '<th></th>',
    ].filter(Boolean);
    const colCount = headerCells.length;
    const desktopBody = !_isMobile
      ? `<div class="pb-table-wrap">
          <div class="pb-table-container">
            <table class="pb-table">
              <thead><tr>${headerCells.join('')}</tr></thead>
              <tbody>${rowsHtml || `<tr><td colspan="${colCount}" class="pb-muted" style="text-align:center;padding:20px">Nema zadataka za filter.</td></tr>`}</tbody>
            </table>
          </div>
        </div>`
      : '';
    return mobileBody + desktopBody;
  }

  /** Targeted update — samo body. Ne menja filter toolbar. */
  function paintBody() {
    const split = root.querySelector('.pb-plan-split');
    if (!split) { paint(); return; }
    const tasks = filtered();
    const sorted = sortTasks(tasks, sortCol, sortDir);
    split.innerHTML = buildBodyHtml(sorted);
    refreshBulkBar();
    // Re-attach sort listenere (jer su .pb-th elementi novi posle innerHTML zamene).
    attachSortListeners();
  }

  /** Bulk action bar — prikazuje se kad je _selectedIds.size > 0. */
  function buildBulkBarHtml() {
    const n = _selectedIds.size;
    if (!canEdit || n === 0) return '<div class="pb-bulk-bar" hidden></div>';
    const statusMenu = _bulkMenu === 'status'
      ? `<div class="pb-bulk-menu" id="pbBulkMenuStatus">
          ${PB_TASK_STATUS.map(s => `<button type="button" class="pb-bulk-menu-item" data-bulk-status="${escHtml(s)}">${escHtml(s)}</button>`).join('')}
        </div>` : '';
    const prioMenu = _bulkMenu === 'prio'
      ? `<div class="pb-bulk-menu" id="pbBulkMenuPrio">
          ${PB_PRIORITET.map(p => `<button type="button" class="pb-bulk-menu-item" data-bulk-prio="${escHtml(p)}">${escHtml(p)}</button>`).join('')}
        </div>` : '';
    const engMenu = _bulkMenu === 'engineer'
      ? `<div class="pb-bulk-menu pb-bulk-menu--wide" id="pbBulkMenuEng">
          <button type="button" class="pb-bulk-menu-item" data-bulk-eng="">— ukloni inženjera —</button>
          ${(ctx.engineers || []).map(e => `<button type="button" class="pb-bulk-menu-item" data-bulk-eng="${escHtml(e.id)}">${escHtml(e.full_name || '')}</button>`).join('')}
        </div>` : '';
    return `
      <div class="pb-bulk-bar" role="region" aria-label="Bulk akcije">
        <span class="pb-bulk-count"><strong>${n}</strong> selektovano</span>
        <div class="pb-bulk-actions">
          <div class="pb-bulk-action">
            <button type="button" class="btn btn-sm pb-bulk-btn" id="pbBulkStatus">Status ▾</button>
            ${statusMenu}
          </div>
          <div class="pb-bulk-action">
            <button type="button" class="btn btn-sm pb-bulk-btn" id="pbBulkPrio">Prioritet ▾</button>
            ${prioMenu}
          </div>
          <div class="pb-bulk-action">
            <button type="button" class="btn btn-sm pb-bulk-btn" id="pbBulkEng">Inženjer ▾</button>
            ${engMenu}
          </div>
          <button type="button" class="btn btn-sm pb-bulk-btn pb-bulk-btn--danger" id="pbBulkDel">✕ Briši</button>
          <button type="button" class="btn btn-sm pb-bulk-btn pb-bulk-btn--ghost" id="pbBulkClear">Otkaži</button>
        </div>
      </div>`;
  }

  /** Replace bulk bar in-place bez full paint-a. */
  function refreshBulkBar() {
    const old = root.querySelector('.pb-bulk-bar');
    if (!old) return;
    const wrap = document.createElement('div');
    wrap.innerHTML = buildBulkBarHtml();
    const fresh = wrap.firstElementChild;
    if (fresh) {
      old.replaceWith(fresh);
      attachBulkBarListeners();
    }
    applyMasterIndeterminate();
    requestAnimationFrame(() => repositionOpenFloatingMenus());
  }

  function applyMasterIndeterminate() {
    const m = /** @type {HTMLInputElement|null} */ (root.querySelector('#pbSelAll'));
    if (!m) return;
    m.indeterminate = m.getAttribute('data-indeterminate') === '1';
  }

  async function runBulkUpdate(patch, successMsg) {
    if (!canEdit || _selectedIds.size === 0) return;
    const ids = Array.from(_selectedIds);
    try {
      const r = await bulkUpdatePbTasks(ids, patch);
      if (r.ok === r.requested) {
        showToast(`${successMsg} (${r.ok})`);
      } else {
        showToast(`Izmenjeno ${r.ok}/${r.requested} — proveri dozvole`);
      }
      _selectedIds.clear();
      _bulkMenu = null;
      ctx.onRefresh?.();
    } catch (e) {
      showToast(pbErrorMessage(e) || 'Greška pri bulk izmeni');
    }
  }

  async function runBulkDelete() {
    if (!canEdit || _selectedIds.size === 0) return;
    const n = _selectedIds.size;
    if (!confirm(`Obrisati ${n} ${n === 1 ? 'zadatak' : 'zadatka'} (soft delete)?`)) return;
    const ids = Array.from(_selectedIds);
    try {
      const r = await bulkSoftDeletePbTasks(ids);
      if (r.ok === r.requested) {
        showToast(`Obrisano ${r.ok}`);
      } else {
        showToast(`Obrisano ${r.ok}/${r.requested} — proveri dozvole`);
      }
      _selectedIds.clear();
      _bulkMenu = null;
      ctx.onRefresh?.();
    } catch (e) {
      showToast(pbErrorMessage(e) || 'Brisanje nije uspelo');
    }
  }

  function attachBulkBarListeners() {
    const toggleMenu = (name) => {
      _bulkMenu = _bulkMenu === name ? null : name;
      refreshBulkBar();
    };
    root.querySelector('#pbBulkStatus')?.addEventListener('click', () => toggleMenu('status'));
    root.querySelector('#pbBulkPrio')?.addEventListener('click', () => toggleMenu('prio'));
    root.querySelector('#pbBulkEng')?.addEventListener('click', () => toggleMenu('engineer'));
    root.querySelector('#pbBulkDel')?.addEventListener('click', runBulkDelete);
    root.querySelector('#pbBulkClear')?.addEventListener('click', () => {
      _selectedIds.clear();
      _bulkMenu = null;
      paintBody();
    });
    root.querySelectorAll('[data-bulk-status]').forEach(btn => {
      btn.addEventListener('click', () => {
        runBulkUpdate({ status: btn.getAttribute('data-bulk-status') }, 'Status izmenjen');
      });
    });
    root.querySelectorAll('[data-bulk-prio]').forEach(btn => {
      btn.addEventListener('click', () => {
        runBulkUpdate({ prioritet: btn.getAttribute('data-bulk-prio') }, 'Prioritet izmenjen');
      });
    });
    root.querySelectorAll('[data-bulk-eng]').forEach(btn => {
      btn.addEventListener('click', () => {
        const v = btn.getAttribute('data-bulk-eng') || null;
        runBulkUpdate({ employee_id: v }, v ? 'Inženjer dodeljen' : 'Inženjer uklonjen');
      });
    });
  }

  function attachSortListeners() {
    root.querySelectorAll('.pb-th').forEach(btn => {
      btn.addEventListener('click', () => {
        const col = btn.getAttribute('data-sort');
        if (sortCol === col) sortDir = sortDir === 'asc' ? 'desc' : 'asc';
        else { sortCol = col; sortDir = 'asc'; }
        paintBody();
      });
    });
  }

  function paint() {
    const tasks = filtered();
    const sorted = sortTasks(tasks, sortCol, sortDir);
    const alarms = buildAlarms(ctx.tasks || [], ctx.loadStats || []);

    /* ── Alarms (collapsible — default zatvoren, summary badge pokazuje broj) ── */
    let alarmHtml = '';
    if (alarms.length) {
      const counts = { red: 0, yellow: 0, green: 0 };
      for (const a of alarms) {
        if (a.level in counts) counts[a.level] += 1;
      }
      const summary = [
        counts.red ? `<span class="pb-alarm-pill pb-alarm-pill--red">${counts.red} kritično</span>` : '',
        counts.yellow ? `<span class="pb-alarm-pill pb-alarm-pill--yellow">${counts.yellow} upozorenja</span>` : '',
        counts.green ? `<span class="pb-alarm-pill pb-alarm-pill--green">${counts.green} završeno</span>` : '',
      ].filter(Boolean).join(' ');
      alarmHtml = `
        <div class="pb-alarm-box ${_alarmsOpen ? 'pb-alarm-box--open' : ''}" role="alert">
          <button type="button" class="pb-alarm-toggle" id="pbAlarmsToggle" aria-expanded="${_alarmsOpen ? 'true' : 'false'}">
            <span class="pb-alarm-summary">⚠ ${alarms.length} ${alarms.length === 1 ? 'alarm' : 'alarma'}</span>
            <span class="pb-alarm-pills">${summary}</span>
            <span class="pb-alarm-chevron ${_alarmsOpen ? 'open' : ''}">${IC_CHEVRON}</span>
          </button>
          ${_alarmsOpen ? `<div class="pb-alarm-list">
            ${alarms.map(a => `<div class="pb-alarm pb-alarm--${escHtml(a.level)}">${escHtml(a.text)}</div>`).join('')}
          </div>` : ''}
        </div>`;
    }

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

    /* Team load — agregat po pod-odeljenju (kad postoji RPC). */
    const teamRowsHtml = (ctx.teamLoadStats || []).map(r => {
      const p = Number(r.avg_load_pct) || 0;
      let barCls = 'pb-load-bar__fill';
      if (p > 100) barCls += ' pb-load-bar__fill--danger';
      else if (p >= 80) barCls += ' pb-load-bar__fill--warn';
      else barCls += ' pb-load-bar__fill--ok';
      const label = `${r.sub_department_name || '—'}`
        + (r.member_count ? ` <small style="opacity:.7">(${r.member_count})</small>` : '');
      return `<div class="pb-load-row">
        <span class="pb-load-name">${label}</span>
        <div class="pb-load-bar" aria-hidden="true"><div class="${barCls}" style="width:${Math.min(p, 150)}%"></div></div>
        <span class="pb-load-pct">${p}% <small style="opacity:.6">max ${Number(r.max_load_pct) || 0}%</small></span>
      </div>`;
    }).join('');

    const teamSection = (ctx.teamLoadStats || []).length
      ? `<div class="pb-load-team">
          <div class="pb-load-team-title">Po timu</div>
          <div class="pb-load-grid">${teamRowsHtml}</div>
        </div>`
      : '';

    const loadHtml = `
      <section class="pb-load-section" aria-label="Opterećenost inženjera">
        <button type="button" class="pb-load-header" id="pbLoadToggle">
          <span class="pb-load-header-title">Opterećenost narednih 20 radnih dana</span>
          <span class="pb-load-chevron ${_loadOpen ? 'open' : ''}">${IC_CHEVRON}</span>
        </button>
        <div class="pb-load-content ${_loadOpen ? 'open' : ''}">
          <div class="pb-load-inner">
            <div class="pb-load-grid">${loadRowsHtml || '<p class="pb-muted">Nema podataka</p>'}</div>
            ${teamSection}
          </div>
        </div>
      </section>`;

    /* ── Filter toolbar ── */
    const hasActiveFilter = filters.status !== 'all' || filters.vrsta !== 'all'
      || filters.prioritet !== 'all' || filters.problemOnly || filters.unassignedOnly
      || filters.showDone || filters.search;

    const filterHtml = `
      <div class="pb-filter-toolbar">
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
            <button type="button" class="pb-ft-toggle ${filters.unassignedOnly ? 'active' : ''}" id="pbFUnassigned">⊘ Ne dodeljeni</button>
            <button type="button" class="pb-ft-toggle ${filters.showDone ? 'active' : ''}" id="pbFDoneBtn">☐ Završeni</button>
          </div>
        </div>
        <div class="pb-ft-field pb-ft-views">
          <span class="pb-ft-label">&nbsp;</span>
          <button type="button" class="pb-ft-toggle" id="pbViewsBtn" aria-haspopup="true" aria-expanded="${_viewsOpen ? 'true' : 'false'}">⭐ Pregledi ▾</button>
          ${_viewsOpen ? buildViewsMenuHtml() : ''}
        </div>
        <div class="pb-ft-field">
          <span class="pb-ft-label">&nbsp;</span>
          <div class="pb-ft-icons">
            <button type="button" class="pb-ft-refresh" id="pbRefreshBtn" title="Osveži">${IC_REFRESH}</button>
            <button type="button" class="pb-ft-refresh" id="pbExportBtn" title="Izvoz u CSV (Excel)">⤓</button>
          </div>
        </div>
        ${hasActiveFilter ? '<button type="button" class="pb-ft-reset" id="pbFReset">✕ Reset</button>' : ''}
      </div>`;

    preserveFocus(() => {
      root.innerHTML = `
        ${alarmHtml}
        ${loadHtml}
        ${filterHtml}
        ${buildBulkBarHtml()}
        <div class="pb-plan-split">${buildBodyHtml(sorted)}</div>`;
    });

    applyMasterIndeterminate();

    /* ── Event listeners ── */

    root.querySelector('#pbLoadToggle')?.addEventListener('click', () => {
      _loadOpen = !_loadOpen;
      savePbPlanLoadSectionOpen(_loadOpen);
      const content = root.querySelector('.pb-load-content');
      const chevron = root.querySelector('.pb-load-chevron');
      content?.classList.toggle('open', _loadOpen);
      chevron?.classList.toggle('open', _loadOpen);
    });
    root.querySelector('#pbAlarmsToggle')?.addEventListener('click', () => {
      _alarmsOpen = !_alarmsOpen;
      paint();
    });

    // #pbSearch je preseljen u chrome (index.js); listener više nije potreban.
    root.querySelector('#pbFStatus')?.addEventListener('change', e => {
      filters.status = e.target.value;
      syncPbModuleFilters({ moduleStatus: filters.status });
      paint();
    });
    root.querySelector('#pbFVrsta')?.addEventListener('change', e => {
      filters.vrsta = e.target.value;
      syncPbModuleFilters({ moduleVrsta: filters.vrsta });
      paint();
    });
    root.querySelector('#pbFPrio')?.addEventListener('change', e => {
      filters.prioritet = e.target.value;
      syncPbModuleFilters({ modulePrioritet: filters.prioritet });
      paint();
    });
    root.querySelector('#pbFDoneBtn')?.addEventListener('click', () => {
      filters.showDone = !filters.showDone;
      syncPbModuleFilters({ moduleShowDone: filters.showDone });
      paint();
    });
    root.querySelector('#pbFProb')?.addEventListener('click', () => {
      filters.problemOnly = !filters.problemOnly;
      syncPbModuleFilters({ moduleProblemOnly: filters.problemOnly });
      paint();
    });
    root.querySelector('#pbFUnassigned')?.addEventListener('click', () => {
      filters.unassignedOnly = !filters.unassignedOnly;
      syncPbModuleFilters({ moduleUnassignedOnly: filters.unassignedOnly });
      paint();
    });
    root.querySelector('#pbFReset')?.addEventListener('click', () => {
      filters = { search: '', status: 'all', vrsta: 'all', prioritet: 'all', showDone: false, problemOnly: false, unassignedOnly: false };
      syncPbModuleFilters({
        moduleSearch: '',
        moduleShowDone: false,
        moduleStatus: 'all',
        modulePrioritet: 'all',
        moduleVrsta: 'all',
        moduleProblemOnly: false,
        moduleUnassignedOnly: false,
      });
      paint();
    });
    root.querySelector('#pbRefreshBtn')?.addEventListener('click', () => ctx.onRefresh?.());
    root.querySelector('#pbExportBtn')?.addEventListener('click', () => exportCurrentViewToCsv());

    attachSortListeners();
    attachBulkBarListeners();
    attachViewsListeners();

    if (!_delegationAttached) {
      attachRootDelegation();
      _delegationAttached = true;
    }

    requestAnimationFrame(() => repositionOpenFloatingMenus());

    _pbPlanFloatLatestRoot = root;
    _pbPlanFloatReposition = repositionOpenFloatingMenus;
    _pbPlanFloatOnEscape = () => {
      if (!root.isConnected) return;
      if (!root.querySelector('.pb-plan-split')) return;
      let needPaint = false;
      if (_viewsOpen) {
        _viewsOpen = false;
        needPaint = true;
      }
      if (_bulkMenu) {
        _bulkMenu = null;
        needPaint = true;
      }
      if (needPaint) paint();
    };
    wirePbPlanFloatingViewport();
    wirePbPlanFloatingScrollRoot(root);
    wirePbPlanFloatingEscape();
  }

  const _emptyFilters = {
    search: '', status: 'all', vrsta: 'all', prioritet: 'all',
    showDone: false, problemOnly: false, unassignedOnly: false,
  };

  /** Vraća filter snapshot bez sessionStorage-only polja. */
  function currentFilterSnapshot() {
    return {
      search: filters.search,
      status: filters.status,
      vrsta: filters.vrsta,
      prioritet: filters.prioritet,
      showDone: filters.showDone,
      problemOnly: filters.problemOnly,
      unassignedOnly: filters.unassignedOnly,
    };
  }

  /** Primeni filter snapshot — kreće od pravog default-a, prekrij sa snapshot-om. */
  function applyView(viewFilters) {
    filters = { ..._emptyFilters, ...viewFilters };
    syncPbModuleFilters({
      moduleSearch: filters.search,
      moduleStatus: filters.status,
      moduleVrsta: filters.vrsta,
      modulePrioritet: filters.prioritet,
      moduleShowDone: filters.showDone,
      moduleProblemOnly: filters.problemOnly,
      moduleUnassignedOnly: filters.unassignedOnly,
    });
    _viewsOpen = false;
    paint();
  }

  function saveCurrentView() {
    const name = prompt('Naziv pregleda:');
    if (!name) return;
    const ok = savePbView(name, currentFilterSnapshot());
    if (ok) {
      showToast(`Pregled "${name}" sačuvan`);
      _viewsOpen = false;
      paint();
    } else {
      showToast('Greška pri čuvanju pregleda');
    }
  }

  function buildViewsMenuHtml() {
    const userViews = loadPbViews();
    const builtinHtml = PB_BUILTIN_VIEWS.map((v, i) => `
      <button type="button" class="pb-views-item" data-view-builtin="${i}">
        <span class="pb-views-item-icon">★</span>
        <span class="pb-views-item-name">${escHtml(v.name)}</span>
      </button>`).join('');
    const userHtml = userViews.length
      ? userViews.map((v, i) => `
          <div class="pb-views-item-row">
            <button type="button" class="pb-views-item" data-view-user="${i}">
              <span class="pb-views-item-icon">◆</span>
              <span class="pb-views-item-name">${escHtml(v.name)}</span>
            </button>
            <button type="button" class="pb-views-del" data-view-del="${escHtml(v.name)}" title="Obriši pregled" aria-label="Obriši">✕</button>
          </div>`).join('')
      : '<div class="pb-views-empty">Nema sačuvanih pregleda</div>';
    return `
      <div class="pb-views-menu" role="menu">
        <div class="pb-views-section-label">Pripremljeni</div>
        ${builtinHtml}
        <div class="pb-views-divider"></div>
        <div class="pb-views-section-label">Moji pregledi</div>
        ${userHtml}
        <div class="pb-views-divider"></div>
        <button type="button" class="pb-views-save" id="pbViewsSave">＋ Sačuvaj trenutni pregled…</button>
      </div>`;
  }

  function attachViewsListeners() {
    root.querySelector('#pbViewsBtn')?.addEventListener('click', e => {
      e.stopPropagation();
      _viewsOpen = !_viewsOpen;
      paint();
    });
    root.querySelector('#pbViewsSave')?.addEventListener('click', saveCurrentView);
    root.querySelectorAll('[data-view-builtin]').forEach(btn => {
      btn.addEventListener('click', () => {
        const i = Number(btn.getAttribute('data-view-builtin'));
        const v = PB_BUILTIN_VIEWS[i];
        if (v) applyView(v.filters);
      });
    });
    root.querySelectorAll('[data-view-user]').forEach(btn => {
      btn.addEventListener('click', () => {
        const i = Number(btn.getAttribute('data-view-user'));
        const v = loadPbViews()[i];
        if (v) applyView(v.filters);
      });
    });
    root.querySelectorAll('[data-view-del]').forEach(btn => {
      btn.addEventListener('click', e => {
        e.stopPropagation();
        const name = btn.getAttribute('data-view-del');
        if (!name) return;
        if (!confirm(`Obrisati pregled "${name}"?`)) return;
        deletePbView(name);
        paint();
      });
    });
  }

  /** Izvoz trenutno filtriranih+sortiranih taskova u CSV (otvoreno u Excel-u). */
  function exportCurrentViewToCsv() {
    const tasks = filtered();
    const sorted = sortTasks(tasks, sortCol, sortDir);
    const headers = [
      '#', 'Naziv', 'Projekat (šifra)', 'Projekat (naziv)', 'Inženjer',
      'Vrsta', 'Prioritet', 'Status',
      'Plan početak', 'Plan rok', 'Ostvaren početak', 'Ostvaren završetak',
      'Trajanje (rd)', 'Norma (h/dan)', 'Završenost %',
      'Kašnjenje (d)', 'Problem',
    ];
    const rows = sorted.map((t, i) => {
      const wd = countWorkdaysBetween(t.datum_pocetka_plan, t.datum_zavrsetka_plan);
      const delay = delayRealEnd(t);
      return [
        i + 1,
        t.naziv || '',
        t.project_code || '',
        t.project_name || '',
        t.engineer_name || '',
        t.vrsta || '',
        t.prioritet || '',
        t.status || '',
        (t.datum_pocetka_plan || '').slice(0, 10),
        (t.datum_zavrsetka_plan || '').slice(0, 10),
        (t.datum_pocetka_real || '').slice(0, 10),
        (t.datum_zavrsetka_real || '').slice(0, 10),
        wd ?? '',
        Number(t.norma_sati_dan) || 0,
        Number(t.procenat_zavrsenosti) || 0,
        delay ?? '',
        (t.problem || '').replace(/\s+/g, ' ').slice(0, 500),
      ];
    });
    const today = new Date().toISOString().slice(0, 10);
    downloadCsv(`pb-plan-${today}.csv`, headers, rows);
    showToast(`Izvezeno ${rows.length} ${rows.length === 1 ? 'red' : 'redova'}`);
  }

  /** Event delegation za sve dugmad u tabeli/karticama — postavlja se jednom. */
  function attachRootDelegation() {
    const findTask = id => (ctx.tasks || []).find(x => x.id === id);

    // Click izvan views menija ga zatvara (dokument-level, jednom).
    document.addEventListener('click', e => {
      if (!_viewsOpen || !root.isConnected) return;
      if (e.target.closest('.pb-views-menu') || e.target.closest('#pbViewsBtn')) return;
      _viewsOpen = false;
      paint();
    });

    root.addEventListener('change', e => {
      const cb = e.target.closest('input.pb-sel');
      if (cb && root.contains(cb)) {
        const id = cb.getAttribute('data-id');
        if (!id) return;
        if (cb.checked) _selectedIds.add(id);
        else _selectedIds.delete(id);
        // Mark row/card vizuelno + ažuriraj master + bulk bar.
        const tr = cb.closest('tr');
        if (tr) tr.classList.toggle('pb-row--selected', cb.checked);
        const card = cb.closest('.pb-card');
        if (card) card.classList.toggle('pb-card--selected', cb.checked);
        refreshBulkBar();
        // Ažuriraj master da odražava stanje.
        const master = /** @type {HTMLInputElement|null} */ (root.querySelector('#pbSelAll'));
        if (master) {
          const all = root.querySelectorAll('input.pb-sel');
          let n = 0, sel = 0;
          all.forEach(x => { n += 1; if (/** @type {HTMLInputElement} */(x).checked) sel += 1; });
          master.checked = n > 0 && sel === n;
          master.indeterminate = sel > 0 && sel < n;
        }
        return;
      }
      const m = e.target.closest('#pbSelAll');
      if (m && root.contains(m)) {
        const want = /** @type {HTMLInputElement} */ (m).checked;
        root.querySelectorAll('input.pb-sel').forEach(x => {
          const inp = /** @type {HTMLInputElement} */ (x);
          inp.checked = want;
          const id = inp.getAttribute('data-id');
          if (!id) return;
          if (want) _selectedIds.add(id);
          else _selectedIds.delete(id);
          const tr = inp.closest('tr');
          if (tr) tr.classList.toggle('pb-row--selected', want);
          const card = inp.closest('.pb-card');
          if (card) card.classList.toggle('pb-card--selected', want);
        });
        /** @type {HTMLInputElement} */ (m).indeterminate = false;
        refreshBulkBar();
      }
    });

    root.addEventListener('click', e => {
      const btn = e.target.closest('button[data-id]');
      if (!btn || !root.contains(btn)) return;
      const taskId = btn.getAttribute('data-id');
      const task = findTask(taskId);
      if (!task) return;

      if (btn.classList.contains('pb-act-edit')) {
        openTaskEditorModal({ task, projects: ctx.projects, engineers: ctx.engineers, canEdit, onSaved: () => ctx.onRefresh?.() });
      } else if (btn.classList.contains('pb-act-desc')) {
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
      } else if (btn.classList.contains('pb-act-prob')) {
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
      } else if (btn.classList.contains('pb-act-del')) {
        confirmDeletePbTask(taskId, () => ctx.onRefresh?.());
      }
    });
  }

  paint();
}
