/**
 * Gantt tab — timeline po inženjeru, plan + ostvareni trake, drag datuma, selekcija kolone.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { openTaskEditorModal } from './shared.js';
import { canEditProjektniBiro } from '../../state/auth.js';
import { updatePbTask } from '../../services/pb.js';

/**
 * @param {object} task
 * @param {Date|string} startDate
 * @param {number} dayWidthPx
 * @returns {{ left: number, width: number } | null}
 */
export function ganttBarGeometry(task, startDate, dayWidthPx) {
  if (!task.datum_pocetka_plan || !task.datum_zavrsetka_plan) return null;
  const msPerDay = 86400000;
  const viewStart = new Date(startDate);
  viewStart.setHours(0, 0, 0, 0);
  const taskStart = new Date(String(task.datum_pocetka_plan).slice(0, 10) + 'T12:00:00');
  const taskEnd = new Date(String(task.datum_zavrsetka_plan).slice(0, 10) + 'T12:00:00');
  const ts = new Date(taskStart); ts.setHours(0, 0, 0, 0);
  const te = new Date(taskEnd); te.setHours(0, 0, 0, 0);
  const vs = viewStart.getTime();
  const leftDays = Math.max(0, Math.round((ts.getTime() - vs) / msPerDay));
  const spanDays = Math.max(1, Math.round((te.getTime() - ts.getTime()) / msPerDay) + 1);
  return {
    left: leftDays * dayWidthPx,
    width: Math.max(spanDays * dayWidthPx, 8),
  };
}

function parseYmd(s) {
  if (!s) return null;
  const d = new Date(String(s).slice(0, 10) + 'T12:00:00');
  return Number.isNaN(d.getTime()) ? null : d;
}

function addDays(dateStr, n) {
  const d = parseYmd(dateStr);
  if (!d) return dateStr;
  d.setDate(d.getDate() + n);
  return d.toISOString().slice(0, 10);
}

function firstOfMonth(d = new Date()) {
  const x = new Date(d.getFullYear(), d.getMonth(), 1);
  x.setHours(0, 0, 0, 0);
  return x;
}

function lastDayOfMonth(base, monthOffset) {
  const x = new Date(base.getFullYear(), base.getMonth() + monthOffset + 1, 0);
  x.setHours(0, 0, 0, 0);
  return x;
}

function eachDay(from, to) {
  const out = [];
  const c = new Date(from);
  c.setHours(0, 0, 0, 0);
  const end = new Date(to);
  end.setHours(0, 0, 0, 0);
  while (c <= end) {
    out.push(new Date(c));
    c.setDate(c.getDate() + 1);
  }
  return out;
}

function filterGanttTasks(tasks, search) {
  let list = tasks.slice();
  const q = (search || '').trim().toLowerCase();
  if (q) list = list.filter(t => String(t.naziv || '').toLowerCase().includes(q));
  return list;
}

function statusBarClass(status) {
  const s = String(status || '');
  if (s === 'Završeno') return 'pb-gantt-bar--done';
  if (s === 'Blokirano') return 'pb-gantt-bar--blocked';
  if (s === 'Pregled') return 'pb-gantt-bar--review';
  if (s === 'U toku') return 'pb-gantt-bar--progress';
  return 'pb-gantt-bar--new';
}

function groupTasks(tasks) {
  const byEng = new Map();
  const unassigned = [];
  for (const t of tasks) {
    if (!t.employee_id) {
      unassigned.push(t);
      continue;
    }
    const k = t.employee_id;
    if (!byEng.has(k)) byEng.set(k, []);
    byEng.get(k).push(t);
  }
  const engIds = Array.from(byEng.keys()).sort((a, b) => {
    const ta = tasks.find(x => x.employee_id === a);
    const tb = tasks.find(x => x.employee_id === b);
    return String(ta?.engineer_name || '').localeCompare(String(tb?.engineer_name || ''), 'sr');
  });
  for (const id of engIds) {
    byEng.get(id).sort((a, b) => {
      const da = a.datum_pocetka_plan || '';
      const db = b.datum_pocetka_plan || '';
      if (!da && !db) return 0;
      if (!da) return 1;
      if (!db) return -1;
      return da.localeCompare(db);
    });
  }
  unassigned.sort((a, b) => (a.datum_pocetka_plan || '').localeCompare(b.datum_pocetka_plan || ''));
  return { engIds, byEng, unassigned };
}

function monthSpans(days) {
  const spans = [];
  let i = 0;
  while (i < days.length) {
    const m = days[i].getMonth();
    let len = 0;
    while (i + len < days.length && days[i + len].getMonth() === m) len += 1;
    const label = days[i].toLocaleString('sr-Latn', { month: 'long', year: 'numeric' });
    spans.push({ label, len });
    i += len;
  }
  return spans;
}

/**
 * @param {HTMLElement} root
 * @param {{
 *   tasks: object[],
 *   projects: object[],
 *   engineers: object[],
 *   search: string,
 *   viewMonth: Date,
 *   onViewMonthChange: (d: Date) => void,
 *   onRefresh: () => void,
 * }} ctx
 */
export function renderGanttTab(root, ctx) {
  root._pbGanttAbort?.abort();
  const ac = new AbortController();
  root._pbGanttAbort = ac;
  const sig = ac.signal;

  const canEdit = canEditProjektniBiro();
  const mobile = window.matchMedia('(max-width: 767px)').matches;
  const dayW = mobile ? 20 : 28;
  const leftColW = mobile ? 130 : 180;

  const baseMonth = ctx.viewMonth ? new Date(ctx.viewMonth) : firstOfMonth();
  baseMonth.setDate(1);
  baseMonth.setHours(0, 0, 0, 0);

  const rangeStart = firstOfMonth(baseMonth);
  const rangeEnd = lastDayOfMonth(baseMonth, 1);
  const days = eachDay(rangeStart, rangeEnd);
  const totalW = days.length * dayW;
  const nDays = days.length;

  const list = filterGanttTasks(ctx.tasks || [], ctx.search);
  const { engIds, byEng, unassigned } = groupTasks(list);

  let tipTimer = null;
  let tipNode = null;

  // Column selection state
  let selectedCols = new Set();
  let shiftAnchor = null;

  function hideTip() {
    if (tipTimer) clearTimeout(tipTimer);
    tipTimer = null;
    tipNode?.remove();
    tipNode = null;
  }

  function showTip(html, clientX, clientY) {
    hideTip();
    tipNode = document.createElement('div');
    tipNode.className = 'pb-gantt-tip';
    tipNode.innerHTML = html;
    const x = Math.max(8, Math.min(clientX, window.innerWidth - 220));
    const y = clientY + 8;
    tipNode.style.left = `${x}px`;
    tipNode.style.top = `${y}px`;
    document.body.appendChild(tipNode);
    tipTimer = setTimeout(hideTip, 2000);
  }

  function tooltipHtml(task) {
    const pct = Math.min(100, Number(task.procenat_zavrsenosti) || 0);
    const dur =
      task.datum_pocetka_plan && task.datum_zavrsetka_plan
        ? Math.max(
          1,
          Math.round(
            (parseYmd(task.datum_zavrsetka_plan).getTime() - parseYmd(task.datum_pocetka_plan).getTime()) / 86400000,
          ) + 1,
        )
        : '—';
    return [
      `<strong>${escHtml(task.naziv || '')}</strong>`,
      `Projekat: ${escHtml(task.project_code || '—')}`,
      `Plan: ${escHtml((task.datum_pocetka_plan || '').slice(0, 10))} — ${escHtml((task.datum_zavrsetka_plan || '').slice(0, 10))}`,
      task.datum_pocetka_real ? `Ostvaren: ${escHtml((task.datum_pocetka_real || '').slice(0, 10))} — ${escHtml((task.datum_zavrsetka_real || '').slice(0, 10))}` : '',
      `Trajanje: ${dur} dana`,
      `Status: ${escHtml(task.status || '')}`,
      `Inženjer: ${escHtml(task.engineer_name || '—')}`,
      `Završenost: ${pct}%`,
    ].filter(Boolean).join('<br/>');
  }

  function barsHtml(task) {
    const geo = ganttBarGeometry(task, rangeStart, dayW);
    const pct = Math.min(100, Number(task.procenat_zavrsenosti) || 0);
    const cls = statusBarClass(task.status);
    let inner = '';
    if (geo) {
      // Plan bar (top)
      inner += `<div class="pb-gantt-bar pb-gantt-bar--plan ${cls}" data-task-id="${escHtml(task.id)}" data-drag-type="move" style="left:${geo.left}px;width:${geo.width}px" tabindex="0" title="Plan">
        <div class="pb-gantt-drag-l" data-task-id="${escHtml(task.id)}" data-drag-type="left"></div>
        <div class="pb-gantt-bar__prog" style="width:${pct}%"></div>
        <div class="pb-gantt-drag-r" data-task-id="${escHtml(task.id)}" data-drag-type="right"></div>
      </div>`;

      // Ostvareni bar (bottom)
      if (task.datum_pocetka_real && task.datum_zavrsetka_real) {
        const tReal = {
          ...task,
          datum_pocetka_plan: task.datum_pocetka_real,
          datum_zavrsetka_plan: task.datum_zavrsetka_real,
        };
        const g2 = ganttBarGeometry(tReal, rangeStart, dayW);
        if (g2) {
          inner += `<div class="pb-gantt-bar pb-gantt-bar--real" data-task-id="${escHtml(task.id)}" style="left:${g2.left}px;width:${g2.width}px" title="Ostvaren"></div>`;
        }
      }
    }
    return `<div class="pb-gantt-bar-host" style="width:${totalW}px">${inner}</div>`;
  }

  const spans = monthSpans(days);
  const monthRow = spans.map(s =>
    `<th class="pb-gantt-th-month" colspan="${s.len}" style="min-width:${s.len * dayW}px">${escHtml(s.label)}</th>`,
  ).join('');

  const today = new Date();
  const dayRow = days.map((d, idx) => {
    const dow = d.getDay();
    const isW = dow === 0 || dow === 6;
    const isToday =
      d.getDate() === today.getDate()
      && d.getMonth() === today.getMonth()
      && d.getFullYear() === today.getFullYear();
    let cls = 'pb-gantt-daycell';
    if (isW) cls += ' pb-gantt-daycell--wknd';
    if (isToday) cls += ' pb-gantt-daycell--today';
    return `<th class="${cls}" style="width:${dayW}px;min-width:${dayW}px" data-day-idx="${idx}" title="${d.toLocaleDateString('sr-Latn')}">${escHtml(String(d.getDate()).padStart(2, '0'))}</th>`;
  }).join('');

  let todayIdx = -1;
  days.forEach((d, i) => {
    if (
      d.getDate() === today.getDate()
      && d.getMonth() === today.getMonth()
      && d.getFullYear() === today.getFullYear()
    ) todayIdx = i;
  });

  const tbodyRows = [];

  for (const eid of engIds) {
    const ts = byEng.get(eid);
    const name = ts[0]?.engineer_name || '—';
    tbodyRows.push(`<tr class="pb-gantt-group">
      <td class="pb-gantt-label pb-gantt-label--grp pb-gantt-sticky-col">${escHtml(name)}</td>
      <td class="pb-gantt-track pb-gantt-track--grp" colspan="${nDays}" style="min-width:${totalW}px"></td>
    </tr>`);
    for (const t of ts) {
      tbodyRows.push(`<tr class="pb-gantt-task-row" data-task-id="${escHtml(t.id)}">
        <td class="pb-gantt-label pb-gantt-name pb-gantt-sticky-col">${escHtml(t.naziv || '')}</td>
        <td class="pb-gantt-track" colspan="${nDays}" style="min-width:${totalW}px">${barsHtml(t)}</td>
      </tr>`);
    }
  }

  if (unassigned.length) {
    tbodyRows.push(`<tr class="pb-gantt-group">
      <td class="pb-gantt-label pb-gantt-label--grp pb-gantt-sticky-col">Bez inženjera</td>
      <td class="pb-gantt-track pb-gantt-track--grp" colspan="${nDays}" style="min-width:${totalW}px"></td>
    </tr>`);
    for (const t of unassigned) {
      tbodyRows.push(`<tr class="pb-gantt-task-row" data-task-id="${escHtml(t.id)}">
        <td class="pb-gantt-label pb-gantt-name pb-gantt-sticky-col">${escHtml(t.naziv || '')}</td>
        <td class="pb-gantt-track" colspan="${nDays}" style="min-width:${totalW}px">${barsHtml(t)}</td>
      </tr>`);
    }
  }

  const navLabel = baseMonth.toLocaleString('sr-Latn', { month: 'long', year: 'numeric' });

  const legend = list.length ? `
    <div class="pb-gantt-legend">
      <span><span class="pb-gantt-dot pb-gantt-bar--new"></span> Nije počelo</span>
      <span><span class="pb-gantt-dot pb-gantt-bar--progress"></span> U toku</span>
      <span><span class="pb-gantt-dot pb-gantt-bar--review"></span> Pregled</span>
      <span><span class="pb-gantt-dot pb-gantt-bar--blocked"></span> Blokirano</span>
      <span><span class="pb-gantt-dot pb-gantt-bar--done"></span> Završeno (plan)</span>
      <span><span class="pb-gantt-dot pb-gantt-bar--real"></span> Ostvaren period</span>
      <span><span class="pb-gantt-today-mark"></span> Danas</span>
    </div>` : '';

  const empty = !list.length ? `
    <div class="pb-gantt-empty">
      <div class="pb-gantt-empty-icon" aria-hidden="true">📅</div>
      <p>Nema zadataka za prikaz</p>
      <p class="pb-muted">Promenite filtere ili dodajte novi zadatak.</p>
      ${canEdit ? '<button type="button" class="btn btn-primary" id="pbGanttNew">+ Novi zadatak</button>' : ''}
    </div>` : '';

  const scrollBlock = list.length ? `
    ${legend}
    <div class="pb-gantt-toolbar">
      <button type="button" class="btn btn-sm" id="pbGanttPrev">← Prethodni mesec</button>
      <strong id="pbGanttMonthLabel">${escHtml(navLabel)}</strong>
      <button type="button" class="btn btn-sm" id="pbGanttNext">Sledeći mesec →</button>
      <button type="button" class="btn btn-sm" id="pbGanttToday">Danas</button>
    </div>
    <div class="pb-gantt-scroll" style="--pb-gantt-left:${leftColW}px">
      <table class="pb-gantt-table">
        <thead>
          <tr>
            <th class="pb-gantt-corner pb-gantt-sticky-col" rowspan="2">Inženjer / Zadatak</th>
            ${monthRow}
          </tr>
          <tr>${dayRow}</tr>
        </thead>
        <tbody>${tbodyRows.join('')}</tbody>
      </table>
      ${todayIdx >= 0 ? `<div class="pb-gantt-today-line" style="left:calc(var(--pb-gantt-left) + ${todayIdx * dayW + dayW / 2}px)"></div>` : ''}
    </div>` : '';

  root.innerHTML = empty || scrollBlock;

  const scrollEl = root.querySelector('.pb-gantt-scroll');

  function taskById(id) {
    return list.find(x => x.id === id);
  }

  function openTaskEditor(task) {
    openTaskEditorModal({
      task,
      projects: ctx.projects,
      engineers: ctx.engineers,
      canEdit,
      onSaved: () => ctx.onRefresh?.(),
    });
  }

  // --- Column selection ---
  function renderColSelections() {
    if (!scrollEl) return;
    scrollEl.querySelectorAll('.pb-gantt-col-sel').forEach(el => el.remove());
    for (const idx of selectedCols) {
      const div = document.createElement('div');
      div.className = 'pb-gantt-col-sel';
      div.style.left = `${leftColW + idx * dayW}px`;
      div.style.width = `${dayW}px`;
      scrollEl.appendChild(div);
    }
  }

  root.querySelectorAll('.pb-gantt-daycell').forEach((th, idx) => {
    th.style.cursor = 'pointer';
    th.addEventListener('click', e => {
      if (e.shiftKey && shiftAnchor !== null) {
        const lo = Math.min(shiftAnchor, idx);
        const hi = Math.max(shiftAnchor, idx);
        selectedCols = new Set();
        for (let i = lo; i <= hi; i++) selectedCols.add(i);
      } else if (selectedCols.has(idx) && selectedCols.size === 1) {
        selectedCols.clear();
        shiftAnchor = null;
      } else {
        selectedCols = new Set([idx]);
        shiftAnchor = idx;
      }
      renderColSelections();
    }, { signal: sig });
  });

  // --- Drag to change dates ---
  if (canEdit && !mobile) {
    let dragState = null;

    function startDrag(e, taskId, dragType) {
      if (e.button !== 0) return;
      e.preventDefault();
      e.stopPropagation();
      const task = taskById(taskId);
      if (!task) return;

      const startX = e.clientX;
      const origStart = task.datum_pocetka_plan;
      const origEnd = task.datum_zavrsetka_plan;

      const barEl = root.querySelector(`.pb-gantt-bar--plan[data-task-id="${CSS.escape(taskId)}"]`);
      if (barEl) barEl.classList.add('dragging');

      dragState = { taskId, dragType, startX, origStart, origEnd, barEl };

      function onMove(ev) {
        if (!dragState) return;
        const dx = ev.clientX - startX;
        const deltaDays = Math.round(dx / dayW);
        if (deltaDays === 0) return;

        const task2 = taskById(dragState.taskId);
        if (!task2 || !dragState.barEl) return;

        let newStart = origStart;
        let newEnd = origEnd;

        if (dragType === 'move') {
          newStart = addDays(origStart, deltaDays);
          newEnd = addDays(origEnd, deltaDays);
        } else if (dragType === 'right') {
          newEnd = addDays(origEnd, deltaDays);
          if (newEnd < newStart) newEnd = newStart;
        } else if (dragType === 'left') {
          newStart = addDays(origStart, deltaDays);
          if (newStart > newEnd) newStart = newEnd;
        }

        const previewTask = { ...task2, datum_pocetka_plan: newStart, datum_zavrsetka_plan: newEnd };
        const g = ganttBarGeometry(previewTask, rangeStart, dayW);
        if (g) {
          dragState.barEl.style.left = `${g.left}px`;
          dragState.barEl.style.width = `${g.width}px`;
        }
      }

      async function onUp(ev) {
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
        if (!dragState) return;

        const dx = ev.clientX - startX;
        const deltaDays = Math.round(dx / dayW);
        dragState.barEl?.classList.remove('dragging');

        if (deltaDays !== 0) {
          let newStart = origStart;
          let newEnd = origEnd;
          if (dragType === 'move') {
            newStart = addDays(origStart, deltaDays);
            newEnd = addDays(origEnd, deltaDays);
          } else if (dragType === 'right') {
            newEnd = addDays(origEnd, deltaDays);
            if (newEnd < newStart) newEnd = newStart;
          } else if (dragType === 'left') {
            newStart = addDays(origStart, deltaDays);
            if (newStart > newEnd) newStart = newEnd;
          }
          try {
            await updatePbTask(dragState.taskId, {
              datum_pocetka_plan: newStart,
              datum_zavrsetka_plan: newEnd,
            });
            ctx.onRefresh?.();
          } catch (err) {
            showToast('Greška pri čuvanju datuma');
            ctx.onRefresh?.();
          }
        }
        dragState = null;
      }

      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    }

    root.addEventListener('mousedown', e => {
      const handle = e.target.closest('.pb-gantt-drag-l, .pb-gantt-drag-r');
      const bar = e.target.closest('.pb-gantt-bar--plan');
      if (handle) {
        const tid = handle.getAttribute('data-task-id');
        const dtype = handle.classList.contains('pb-gantt-drag-l') ? 'left' : 'right';
        startDrag(e, tid, dtype);
        return;
      }
      if (bar && !e.target.closest('.pb-gantt-drag-l, .pb-gantt-drag-r')) {
        const tid = bar.getAttribute('data-task-id');
        startDrag(e, tid, 'move');
      }
    }, { signal: sig });
  }

  // --- Navigation ---
  root.querySelector('#pbGanttPrev')?.addEventListener('click', () => {
    const d = new Date(baseMonth);
    d.setMonth(d.getMonth() - 1);
    ctx.onViewMonthChange?.(d);
  }, { signal: sig });

  root.querySelector('#pbGanttNext')?.addEventListener('click', () => {
    const d = new Date(baseMonth);
    d.setMonth(d.getMonth() + 1);
    ctx.onViewMonthChange?.(d);
  }, { signal: sig });

  root.querySelector('#pbGanttToday')?.addEventListener('click', () => {
    if (!scrollEl || todayIdx < 0) return;
    const target = Math.max(0, todayIdx * dayW - 4 * dayW);
    scrollEl.scrollTo({ left: target, behavior: 'smooth' });
  }, { signal: sig });

  root.querySelector('#pbGanttNew')?.addEventListener('click', () => {
    openTaskEditorModal({
      task: null,
      projects: ctx.projects,
      engineers: ctx.engineers,
      canEdit,
      onSaved: () => ctx.onRefresh?.(),
    });
  }, { signal: sig });

  // --- Click to open editor ---
  root.addEventListener('click', e => {
    if (e.target.closest('.pb-gantt-drag-l, .pb-gantt-drag-r')) return;
    const bar = e.target.closest('.pb-gantt-bar');
    const nameCell = e.target.closest('.pb-gantt-name');
    if (bar && !e.target.closest('.pb-gantt-drag-l, .pb-gantt-drag-r')) {
      const tid = bar.getAttribute('data-task-id');
      const task = tid ? taskById(tid) : null;
      if (task) { hideTip(); openTaskEditor(task); }
      return;
    }
    if (nameCell) {
      const tid = nameCell.closest('tr')?.getAttribute('data-task-id');
      const task = tid ? taskById(tid) : null;
      if (task) { hideTip(); openTaskEditor(task); }
    }
  }, { signal: sig });

  // --- Tooltip on hover ---
  root.addEventListener('mouseover', e => {
    const bar = e.target.closest('.pb-gantt-bar--plan');
    if (!bar) return;
    const tid = bar.getAttribute('data-task-id');
    const task = tid ? taskById(tid) : null;
    if (!task || mobile) return;
    showTip(tooltipHtml(task), e.clientX, e.clientY);
  }, { signal: sig });

  root.addEventListener('touchstart', e => {
    const bar = e.target.closest('.pb-gantt-bar--plan');
    if (!bar) return;
    const tid = bar.getAttribute('data-task-id');
    const task = tid ? taskById(tid) : null;
    if (!task) return;
    const touch = e.changedTouches?.[0];
    if (touch) showTip(tooltipHtml(task), touch.clientX, touch.clientY);
  }, { passive: true, signal: sig });
}
