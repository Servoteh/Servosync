/**
 * Kadrovska — TAB Godišnji odmor (Faza K2 + Gantt redesign).
 *
 * Prikazi: tabela (default) i Gantt po odeljenjima.
 * Filteri: godina, pretraga, odeljenje (multi-select), status (aktivni/svi).
 * Stat kartice: Ukupno / Iskorišćeno / Preostalo / Prekoračilo.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { formatDate } from '../../lib/date.js';
import {
  compareEmployeesByLastFirst,
  employeeDisplayName,
} from '../../lib/employeeNames.js';
import { canEditKadrovska, canViewEmployeePii } from '../../state/auth.js';
import {
  kadrovskaState,
  kadrVacationState,
} from '../../state/kadrovska.js';
import {
  ensureEmployeesLoaded,
  ensureVacationLoaded,
  employeeNameById,
} from '../../services/kadrovska.js';
import {
  mapDbEntitlement,
  loadBalancesFromDb,
  saveEntitlementToDb,
} from '../../services/vacation.js';
import {
  countGoDaysByEmployeeForYear,
  latestGoSegmentForEmployeeYear,
  allGoSegmentsForYear,
} from '../../services/workHoursAbsenceReporting.js';
import { loadXlsx } from '../../lib/xlsx.js';

/* ── state ─────────────────────────────────────────────────────────── */

let panelRoot = null;
const vacGoCache = { year: null, byEmp: new Map() };
let _ganttSegments = new Map();
let _viewMode = 'table';
let _collapsedDepts = new Set();
let _deptDropOpen = false;
let _selectedDepts = new Set(); // empty = sve

/* ── dept color palette ─────────────────────────────────────────────── */

const DEPT_COLORS = [
  '#4F86C6', '#6BBF5A', '#E8A838', '#9B59B6',
  '#38B2C4', '#E06898', '#5AAA7A', '#C48038',
  '#688CC4', '#BF5A5A',
];

function deptColor(name) {
  if (!name) return '#888';
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0;
  return DEPT_COLORS[h % DEPT_COLORS.length];
}

/* ── year helpers ───────────────────────────────────────────────────── */

function daysInYear(year) {
  return (year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0)) ? 366 : 365;
}

function dayOfYearZero(ymd, year) {
  const d = new Date(ymd + 'T00:00:00');
  const s = new Date(year + '-01-01T00:00:00');
  return Math.max(0, Math.round((d - s) / 86400000));
}

function clampYmd(ymd, year) {
  const from = `${year}-01-01`;
  const to = `${year}-12-31`;
  if (ymd < from) return from;
  if (ymd > to) return to;
  return ymd;
}

/* ── HTML ─────────────────────────────────────────────────────────── */

export function renderVacationTab() {
  const curYear = new Date().getFullYear();
  return `
    <div class="vac-stat-cards" id="vacStatCards"></div>
    <div class="kadrovska-toolbar vac-toolbar">
      <label class="kadrovska-filter" style="display:flex;gap:6px;align-items:center;">
        <span>Godina</span>
        <input type="number" id="vacYear" min="2000" max="2100" step="1" value="${curYear}" style="max-width:90px">
      </label>
      <input type="text" class="kadrovska-search" id="vacSearch" placeholder="Pretraga po imenu…">
      <div class="vac-dept-wrap" id="vacDeptWrap">
        <button class="btn btn-ghost vac-dept-btn" id="vacDeptBtn" type="button">Odeljenja ▾</button>
        <div class="vac-dept-panel" id="vacDeptPanel" style="display:none;">
          <div class="vac-dept-actions">
            <button class="btn btn-ghost" id="vacDeptAll" style="font-size:11px;padding:3px 8px;">Odaberi sve</button>
            <button class="btn btn-ghost" id="vacDeptNone" style="font-size:11px;padding:3px 8px;">Poništi</button>
          </div>
          <div id="vacDeptList" class="vac-dept-list"></div>
        </div>
      </div>
      <select class="kadrovska-filter" id="vacStatusFilter">
        <option value="active" selected>Samo aktivni</option>
        <option value="all">Svi</option>
      </select>
      <div class="kadrovska-toolbar-spacer"></div>
      <div class="vac-view-toggle">
        <button class="btn vac-view-btn active" id="vacViewTable" title="Tabela">☰ Tabela</button>
        <button class="btn vac-view-btn" id="vacViewGantt" title="Gantt">▦ Gantt</button>
      </div>
      <button class="btn btn-ghost" id="vacExport">📊 Excel</button>
      <button class="btn btn-ghost" id="vacPrintGantt" style="display:none;">🖨 Štampa Gantt-a</button>
      <span class="kadrovska-count" id="vacCount">0 zaposlenih</span>
    </div>
    <main class="kadrovska-main" id="vacMain">
      <table class="kadrovska-table" id="vacTable">
        <thead>
          <tr>
            <th>Zaposleni</th>
            <th class="col-hide-sm">Odeljenje</th>
            <th>Dana pravo</th>
            <th>Preneto</th>
            <th>Iskorišćeno</th>
            <th>Preostalo</th>
            <th class="col-actions">Rešenje</th>
          </tr>
        </thead>
        <tbody id="vacTbody"></tbody>
      </table>
      <div class="vac-gantt" id="vacGantt" style="display:none;"></div>
      <div class="kadrovska-empty" id="vacEmpty" style="display:none;margin-top:16px;">
        <div class="kadrovska-empty-title">Nema zaposlenih</div>
        <div>Dodaj zaposlene u tabu <strong>Zaposleni</strong>.</div>
      </div>
    </main>
    <div class="vac-tooltip" id="vacTooltip" style="display:none;"></div>`;
}

export async function wireVacationTab(panelEl) {
  panelRoot = panelEl;
  panelEl.querySelector('#vacYear').addEventListener('change', refreshVacationTab);
  panelEl.querySelector('#vacSearch').addEventListener('input', _applyFiltersAndRender);
  panelEl.querySelector('#vacStatusFilter').addEventListener('change', _applyFiltersAndRender);
  panelEl.querySelector('#vacExport').addEventListener('click', exportToExcel);
  panelEl.querySelector('#vacPrintGantt').addEventListener('click', _printGantt);

  panelEl.querySelector('#vacViewTable').addEventListener('click', () => _toggleView('table'));
  panelEl.querySelector('#vacViewGantt').addEventListener('click', () => _toggleView('gantt'));

  panelEl.querySelector('#vacDeptBtn').addEventListener('click', _toggleDeptDropdown);
  panelEl.querySelector('#vacDeptAll').addEventListener('click', () => { _selectedDepts.clear(); _closeDeptDropdown(); _applyFiltersAndRender(); });
  panelEl.querySelector('#vacDeptNone').addEventListener('click', () => {
    const depts = _allDepts();
    _selectedDepts = new Set(depts);
    _closeDeptDropdown();
    _applyFiltersAndRender();
  });

  document.addEventListener('click', (e) => {
    if (!panelEl.querySelector('#vacDeptWrap')?.contains(e.target)) {
      _closeDeptDropdown();
    }
  });

  await ensureEmployeesLoaded();
  await refreshVacationTab();
}

export async function refreshVacationTab() {
  if (!panelRoot) return;
  const year = Number(panelRoot.querySelector('#vacYear').value || new Date().getFullYear());
  await ensureVacationLoaded(year, true);
  vacGoCache.year = year;
  vacGoCache.byEmp = await countGoDaysByEmployeeForYear(year);
  _ganttSegments = await allGoSegmentsForYear(year);
  _rebuildDeptList();
  _applyFiltersAndRender();
}

/* ── dept dropdown ──────────────────────────────────────────────────── */

function _allDepts() {
  const set = new Set();
  for (const e of kadrovskaState.employees) {
    if (e.department) set.add(e.department);
  }
  return [...set].sort((a, b) => a.localeCompare(b, 'sr'));
}

function _rebuildDeptList() {
  if (!panelRoot) return;
  const list = panelRoot.querySelector('#vacDeptList');
  if (!list) return;
  const depts = _allDepts();
  list.innerHTML = depts.map(d => {
    const checked = !_selectedDepts.has(d);
    const col = deptColor(d);
    return `<label class="vac-dept-item">
      <input type="checkbox" data-dept="${escHtml(d)}" ${checked ? 'checked' : ''}>
      <span class="vac-dept-dot" style="background:${col};"></span>
      <span>${escHtml(d)}</span>
    </label>`;
  }).join('');
  list.querySelectorAll('input[type=checkbox]').forEach(cb => {
    cb.addEventListener('change', () => {
      const dept = cb.dataset.dept;
      if (cb.checked) _selectedDepts.delete(dept);
      else _selectedDepts.add(dept);
      _updateDeptBtnLabel();
      _applyFiltersAndRender();
    });
  });
  _updateDeptBtnLabel();
}

function _updateDeptBtnLabel() {
  if (!panelRoot) return;
  const btn = panelRoot.querySelector('#vacDeptBtn');
  if (!btn) return;
  const total = _allDepts().length;
  const hidden = _selectedDepts.size;
  if (hidden === 0 || hidden === total) {
    btn.textContent = 'Odeljenja ▾';
  } else {
    btn.textContent = `Odeljenja (${total - hidden}/${total}) ▾`;
  }
}

function _toggleDeptDropdown() {
  _deptDropOpen = !_deptDropOpen;
  if (panelRoot) {
    const panel = panelRoot.querySelector('#vacDeptPanel');
    if (panel) panel.style.display = _deptDropOpen ? 'block' : 'none';
  }
}

function _closeDeptDropdown() {
  _deptDropOpen = false;
  if (panelRoot) {
    const panel = panelRoot.querySelector('#vacDeptPanel');
    if (panel) panel.style.display = 'none';
  }
}

/* ── view toggle ────────────────────────────────────────────────────── */

function _toggleView(mode) {
  _viewMode = mode;
  if (!panelRoot) return;
  panelRoot.querySelector('#vacViewTable').classList.toggle('active', mode === 'table');
  panelRoot.querySelector('#vacViewGantt').classList.toggle('active', mode === 'gantt');
  panelRoot.querySelector('#vacTable').style.display = mode === 'table' ? '' : 'none';
  panelRoot.querySelector('#vacGantt').style.display = mode === 'gantt' ? '' : 'none';
  panelRoot.querySelector('#vacExport').style.display = mode === 'table' ? '' : 'none';
  panelRoot.querySelector('#vacPrintGantt').style.display = mode === 'gantt' ? '' : 'none';
  if (mode === 'gantt') renderGantt();
}

/* ── core data ──────────────────────────────────────────────────────── */

function computeRows() {
  const year = Number(panelRoot.querySelector('#vacYear').value || new Date().getFullYear());
  const statusF = panelRoot.querySelector('#vacStatusFilter').value;
  const q = (panelRoot.querySelector('#vacSearch').value || '').trim().toLowerCase();

  const entByEmp = new Map();
  for (const e of kadrVacationState.entitlements) {
    if (e.year === year) entByEmp.set(e.employeeId, e);
  }
  const balByEmp = new Map();
  for (const b of kadrVacationState.balances) {
    if (b.year === year) balByEmp.set(b.employeeId, b);
  }

  const emps = kadrovskaState.employees.filter(e => {
    if (statusF === 'active' && !e.isActive) return false;
    if (_selectedDepts.has(e.department || '')) return false;
    if (q) {
      const hay = [employeeDisplayName(e), e.firstName, e.lastName, e.department, e.team].join(' ').toLowerCase();
      if (!hay.includes(q)) return false;
    }
    return true;
  });

  return emps.sort(compareEmployeesByLastFirst).map(emp => {
    const ent = entByEmp.get(emp.id);
    const bal = balByEmp.get(emp.id);
    const daysTotal = ent ? ent.daysTotal : 20;
    const daysCarried = ent ? ent.daysCarriedOver : 0;
    let daysUsed = bal ? bal.daysUsed : 0;
    if (!bal) {
      daysUsed = vacGoCache.year === year ? (vacGoCache.byEmp.get(emp.id) ?? 0) : 0;
    }
    const daysRemaining = daysTotal + daysCarried - daysUsed;
    return { emp, ent, year, daysTotal, daysCarried, daysUsed, daysRemaining };
  });
}

/* ── render stat cards ──────────────────────────────────────────────── */

function renderStatCards(rows) {
  const host = panelRoot.querySelector('#vacStatCards');
  if (!host) return;
  const totalTotal = rows.reduce((s, r) => s + r.daysTotal + r.daysCarried, 0);
  const totalUsed = rows.reduce((s, r) => s + r.daysUsed, 0);
  const totalRemaining = rows.reduce((s, r) => s + Math.max(0, r.daysRemaining), 0);
  const overCount = rows.filter(r => r.daysRemaining < 0).length;

  const cards = [
    { label: 'Ukupno dana', value: totalTotal, icon: '📅', color: 'var(--blue-bar, #4F86C6)' },
    { label: 'Iskorišćeno', value: totalUsed, icon: '✅', color: 'var(--accent)' },
    { label: 'Preostalo', value: totalRemaining, icon: '⏳', color: 'var(--green-light, #6BBF5A)' },
    { label: 'Prekoračilo', value: overCount, icon: '⚠', color: overCount > 0 ? 'var(--accent)' : 'var(--text3)' },
  ];

  host.innerHTML = cards.map(c => `
    <div class="vac-stat-card">
      <div class="vac-stat-icon">${c.icon}</div>
      <div class="vac-stat-body">
        <div class="vac-stat-value" style="color:${c.color};">${c.value}</div>
        <div class="vac-stat-label">${escHtml(c.label)}</div>
      </div>
    </div>`).join('');
}

/* ── table render ───────────────────────────────────────────────────── */

function _applyFiltersAndRender() {
  if (!panelRoot) return;
  const rows = computeRows();
  renderStatCards(rows);
  _updateCountBadge(rows.length);
  if (_viewMode === 'table') renderRows(rows);
  else renderGantt();
}

function _updateCountBadge(n) {
  const countEl = panelRoot.querySelector('#vacCount');
  if (countEl) countEl.textContent = `${n} ${n === 1 ? 'zaposleni' : 'zaposlenih'}`;
  const badge = document.getElementById('kadrTabCountVacation');
  if (badge) badge.textContent = String(n);
}

function renderRows(rows) {
  if (!panelRoot) return;
  rows = rows || computeRows();
  const tbody = panelRoot.querySelector('#vacTbody');
  const empty = panelRoot.querySelector('#vacEmpty');

  if (!rows.length) {
    tbody.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  const edit = canEditKadrovska();
  tbody.innerHTML = rows.map(r => {
    const remCls = r.daysRemaining < 0 ? 'warn' : (r.daysRemaining < 3 ? 'accent' : 'ok');
    const entId = r.ent?.id || '';
    const col = deptColor(r.emp.department || '');
    const deptBadge = r.emp.department
      ? `<span class="vac-dept-badge" style="background:${col}22;color:${col};border-color:${col}44;">${escHtml(r.emp.department)}</span>`
      : '—';
    return `<tr data-emp-id="${escHtml(r.emp.id)}" data-ent-id="${escHtml(entId)}">
      <td><div class="emp-name">${escHtml(employeeDisplayName(r.emp) || '—')}</div></td>
      <td class="col-hide-sm">${deptBadge}</td>
      <td>
        <input type="number" class="vac-inp vac-total" min="0" max="365" step="1" value="${r.daysTotal}" ${edit ? '' : 'disabled'}>
      </td>
      <td>
        <input type="number" class="vac-inp vac-carry" min="0" max="365" step="1" value="${r.daysCarried}" ${edit ? '' : 'disabled'}>
      </td>
      <td><span style="font-family:var(--mono);font-weight:600;">${r.daysUsed}</span></td>
      <td><span class="kadr-type-badge t-${remCls}" style="font-family:var(--mono);font-weight:700;">${r.daysRemaining}</span></td>
      <td class="col-actions">
        <button class="btn-row-act" data-act="resenje" data-emp-id="${escHtml(r.emp.id)}">📄 Rešenje</button>
      </td>
    </tr>`;
  }).join('');

  tbody.querySelectorAll('tr').forEach(tr => {
    const empId = tr.dataset.empId;
    const totalEl = tr.querySelector('.vac-total');
    const carryEl = tr.querySelector('.vac-carry');
    const year = Number(panelRoot.querySelector('#vacYear').value);
    let to;
    const save = () => {
      clearTimeout(to);
      to = setTimeout(() => persistEntitlement(empId, year, {
        daysTotal: parseInt(totalEl.value, 10) || 0,
        daysCarriedOver: parseInt(carryEl.value, 10) || 0,
      }, tr), 500);
    };
    totalEl?.addEventListener('change', save);
    carryEl?.addEventListener('change', save);
  });

  tbody.querySelectorAll('button[data-act="resenje"]').forEach(b => {
    b.addEventListener('click', () => openResenjePrint(b.dataset.empId));
  });
}

/* ── Gantt render ───────────────────────────────────────────────────── */

const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'Maj', 'Jun', 'Jul', 'Avg', 'Sep', 'Okt', 'Nov', 'Dec'];

function renderGantt() {
  if (!panelRoot) return;
  const rows = computeRows();
  const ganttEl = panelRoot.querySelector('#vacGantt');
  const empty = panelRoot.querySelector('#vacEmpty');
  if (!ganttEl) return;

  if (!rows.length) {
    ganttEl.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  const year = rows[0]?.year || new Date().getFullYear();
  const totalDays = daysInYear(year);
  const today = new Date().toISOString().slice(0, 10);
  const todayDoy = dayOfYearZero(today, year);
  const todayPct = (todayDoy / totalDays) * 100;
  const isCurrentYear = today.startsWith(String(year));

  /* Group by dept */
  const deptMap = new Map();
  for (const r of rows) {
    const dept = r.emp.department || '(bez odeljenja)';
    if (!deptMap.has(dept)) deptMap.set(dept, []);
    deptMap.get(dept).push(r);
  }
  const depts = [...deptMap.keys()].sort((a, b) => a.localeCompare(b, 'sr'));

  /* Month header */
  const monthCols = MONTH_NAMES.map((name, i) => {
    const start = new Date(year, i, 1);
    const end = new Date(year, i + 1, 0);
    const startDoy = dayOfYearZero(start.toISOString().slice(0, 10), year);
    const endDoy = dayOfYearZero(end.toISOString().slice(0, 10), year);
    const left = (startDoy / totalDays) * 100;
    const width = ((endDoy - startDoy + 1) / totalDays) * 100;
    return `<div class="vac-gantt-month" style="left:${left.toFixed(3)}%;width:${width.toFixed(3)}%;">${name}</div>`;
  }).join('');

  /* Dept groups */
  const groupsHtml = depts.map(dept => {
    const dRows = deptMap.get(dept);
    const isCollapsed = _collapsedDepts.has(dept);
    const col = deptColor(dept === '(bez odeljenja)' ? '' : dept);

    const empRowsHtml = dRows.map(r => {
      const segs = _ganttSegments.get(r.emp.id) || [];
      const barsHtml = segs.map(seg => {
        const cFrom = clampYmd(seg.dateFrom, year);
        const cTo = clampYmd(seg.dateTo, year);
        const startDoy = dayOfYearZero(cFrom, year);
        const endDoy = dayOfYearZero(cTo, year);
        const left = (startDoy / totalDays) * 100;
        const width = Math.max(0.2, ((endDoy - startDoy + 1) / totalDays) * 100);
        const isOver = r.daysRemaining < 0;
        const barCls = isOver ? 'vac-bar-over' : 'vac-bar-used';
        const tip = `${employeeDisplayName(r.emp)}: ${seg.dateFrom} → ${seg.dateTo} (${seg.daysCount} dana)`;
        return `<div class="vac-gantt-bar ${barCls}" style="left:${left.toFixed(3)}%;width:${width.toFixed(3)}%;" data-tip="${escHtml(tip)}"></div>`;
      }).join('');

      const remCls = r.daysRemaining < 0 ? 'vac-bal-over' : (r.daysRemaining < 3 ? 'vac-bal-warn' : 'vac-bal-ok');
      return `<div class="vac-gantt-emp-row">
        <div class="vac-gantt-emp-name">
          <span class="vac-gantt-name-txt">${escHtml(employeeDisplayName(r.emp) || '—')}</span>
          <span class="vac-gantt-bal ${remCls}">${r.daysRemaining}d</span>
        </div>
        <div class="vac-gantt-timeline">
          ${barsHtml}
          ${isCurrentYear ? `<div class="vac-gantt-today" style="left:${todayPct.toFixed(3)}%;"></div>` : ''}
        </div>
      </div>`;
    }).join('');

    return `<div class="vac-gantt-dept" data-dept="${escHtml(dept)}">
      <div class="vac-gantt-dept-hdr" data-collapse="${escHtml(dept)}">
        <span class="vac-gantt-dept-arrow">${isCollapsed ? '▶' : '▼'}</span>
        <span class="vac-gantt-dept-dot" style="background:${col};"></span>
        <span class="vac-gantt-dept-name">${escHtml(dept)}</span>
        <span class="vac-gantt-dept-count">${dRows.length} zap.</span>
      </div>
      <div class="vac-gantt-dept-body" ${isCollapsed ? 'style="display:none;"' : ''}>
        <div class="vac-gantt-emp-row vac-gantt-header-row">
          <div class="vac-gantt-emp-name"></div>
          <div class="vac-gantt-timeline vac-gantt-months">
            ${monthCols}
            ${isCurrentYear ? `<div class="vac-gantt-today vac-gantt-today-hdr" style="left:${todayPct.toFixed(3)}%;"></div>` : ''}
          </div>
        </div>
        ${empRowsHtml}
      </div>
    </div>`;
  }).join('');

  ganttEl.innerHTML = `
    <div class="vac-gantt-legend">
      <span class="vac-leg-item"><span class="vac-leg-swatch vac-bar-used"></span>Iskorišćeno GO</span>
      <span class="vac-leg-item"><span class="vac-leg-swatch vac-bar-over"></span>Prekoračenje</span>
      ${isCurrentYear ? '<span class="vac-leg-item"><span class="vac-leg-swatch" style="background:var(--accent);width:2px;height:14px;display:inline-block;"></span>Danas</span>' : ''}
    </div>
    <div class="vac-gantt-groups" id="vacGanttGroups">
      ${groupsHtml}
    </div>`;

  /* Wire collapse toggles */
  ganttEl.querySelectorAll('[data-collapse]').forEach(hdr => {
    hdr.addEventListener('click', () => {
      const dept = hdr.dataset.collapse;
      if (_collapsedDepts.has(dept)) _collapsedDepts.delete(dept);
      else _collapsedDepts.add(dept);
      renderGantt();
    });
  });

  /* Tooltip via mousemove */
  const tooltip = panelRoot.querySelector('#vacTooltip') || document.getElementById('vacTooltip');
  if (tooltip) {
    ganttEl.querySelectorAll('[data-tip]').forEach(bar => {
      bar.addEventListener('mouseenter', (e) => {
        tooltip.textContent = bar.dataset.tip;
        tooltip.style.display = 'block';
      });
      bar.addEventListener('mousemove', (e) => {
        const rect = panelRoot.getBoundingClientRect();
        tooltip.style.left = (e.clientX - rect.left + 12) + 'px';
        tooltip.style.top = (e.clientY - rect.top + 12) + 'px';
      });
      bar.addEventListener('mouseleave', () => {
        tooltip.style.display = 'none';
      });
    });
  }
}

/* ── print Gantt ────────────────────────────────────────────────────── */

function _printGantt() {
  window.print();
}

/* ── persist entitlement ────────────────────────────────────────────── */

async function persistEntitlement(employeeId, year, patch, tr) {
  if (!canEditKadrovska()) return;
  const entId = tr?.dataset.entId || null;
  const payload = {
    id: entId || undefined,
    employeeId,
    year,
    daysTotal: patch.daysTotal,
    daysCarriedOver: patch.daysCarriedOver,
  };
  const res = await saveEntitlementToDb(payload);
  if (!res || !res.length) {
    showToast('⚠ Čuvanje nije uspelo');
    return;
  }
  const saved = mapDbEntitlement(res[0]);
  const list = kadrVacationState.entitlements.filter(e => !(e.employeeId === employeeId && e.year === year));
  list.push(saved);
  kadrVacationState.entitlements = list;

  const bal = await loadBalancesFromDb(year);
  if (bal) kadrVacationState.balances = bal;

  if (tr) tr.dataset.entId = saved.id;
  _applyFiltersAndRender();
  showToast('✅ Sačuvano');
}

/* ── rešenje o GO ───────────────────────────────────────────────────── */

function openResenjePrint(employeeId) {
  void openResenjePrintAsync(employeeId);
}

async function openResenjePrintAsync(employeeId) {
  const emp = kadrovskaState.employees.find(e => e.id === employeeId);
  if (!emp) { showToast('⚠ Zaposleni nije pronađen'); return; }

  const year = Number(panelRoot.querySelector('#vacYear').value);
  const seg = await latestGoSegmentForEmployeeYear(employeeId, year);

  let dateFrom = seg?.dateFrom || '';
  let dateTo = seg?.dateTo || '';
  let days = seg?.daysCount || 0;

  if (!seg) {
    const inFrom = prompt(`Unesi datum početka GO (YYYY-MM-DD) za ${employeeDisplayName(emp)}:`, '');
    if (!inFrom) return;
    const inTo = prompt('Unesi datum kraja GO (YYYY-MM-DD):', '');
    if (!inTo) return;
    dateFrom = inFrom; dateTo = inTo;
    days = Math.round((new Date(inTo) - new Date(inFrom)) / 86400000) + 1;
  }

  const nowDay = new Date();
  const protocol = `GO-${year}-${String(emp.id).slice(0, 8).toUpperCase()}`;
  const fromStr = dateFrom ? formatDate(dateFrom) : '';
  const toStr = dateTo ? formatDate(dateTo) : '';
  const today = formatDate(nowDay.toISOString().slice(0, 10));

  const html = `<!DOCTYPE html>
<html lang="sr">
<head>
<meta charset="utf-8">
<title>Rešenje o godišnjem odmoru — ${escHtml(employeeDisplayName(emp) || '')}</title>
<style>
  @page { size: A4; margin: 2.2cm 2cm; }
  body { font-family: 'Times New Roman', Georgia, serif; color:#111; font-size: 12pt; line-height: 1.55; }
  .doc-head { text-align: right; margin-bottom: 28px; font-size: 11pt; color:#333; }
  .doc-head .company { font-weight: 700; font-size: 13pt; color:#000; }
  h1 { text-align:center; font-size: 15pt; margin: 8px 0 6px; text-transform: uppercase; letter-spacing: 0.5px; }
  h2 { text-align:center; font-size: 12pt; font-weight: 400; margin: 0 0 24px; color:#333; }
  p { margin: 10px 0; text-align: justify; }
  .meta { font-size: 11pt; color:#333; margin-bottom: 18px; }
  .meta-row { display:flex; justify-content:space-between; }
  table.pts { margin: 14px 0 0 14px; }
  table.pts td { padding: 3px 8px 3px 0; vertical-align: top; }
  .signs { margin-top: 48px; display:flex; justify-content: space-between; }
  .sign-box { width: 45%; text-align:center; }
  .sign-line { border-top:1px solid #333; padding-top:4px; font-size:10pt; color:#555; margin-top:40px; }
  .print-actions { margin: 20px 0; text-align:center; }
  .print-actions button { padding: 8px 20px; font-size: 12pt; cursor:pointer; }
  @media print { .print-actions { display:none; } }
</style>
</head>
<body>
  <div class="print-actions">
    <button onclick="window.print()">🖨 Štampaj</button>
    <button onclick="window.close()">Zatvori</button>
  </div>
  <div class="doc-head">
    <div class="company">SERVOTEH d.o.o.</div>
    <div>Dobanovci · Kruševac</div>
    <div>Broj: <strong>${escHtml(protocol)}</strong></div>
    <div>Datum: ${escHtml(today)}</div>
  </div>
  <h1>Rešenje</h1>
  <h2>o korišćenju godišnjeg odmora za ${escHtml(String(year))}. godinu</h2>

  <div class="meta">
    <div class="meta-row"><span>Zaposleni:</span><strong>${escHtml(employeeDisplayName(emp) || '')}</strong></div>
    ${emp.position ? `<div class="meta-row"><span>Radno mesto:</span><span>${escHtml(emp.position)}</span></div>` : ''}
    ${emp.department ? `<div class="meta-row"><span>Odeljenje:</span><span>${escHtml(emp.department)}</span></div>` : ''}
    ${emp.personalId && canViewEmployeePii() ? `<div class="meta-row"><span>JMBG:</span><span>${escHtml(emp.personalId)}</span></div>` : ''}
  </div>

  <p>
    Na osnovu člana 68–73. Zakona o radu („Sl. glasnik RS", br. 24/2005 i dr.)
    i odluke poslodavca, imenovanom se odobrava korišćenje godišnjeg odmora za
    <strong>${escHtml(String(year))}. godinu</strong> u trajanju od
    <strong>${escHtml(String(days || ''))} ${days === 1 ? 'dan' : 'dana'}</strong>,
    ${fromStr && toStr
      ? `u periodu od <strong>${escHtml(fromStr)}</strong> do <strong>${escHtml(toStr)}</strong>.`
      : `u periodu koji će biti naknadno utvrđen.`}
  </p>

  <p>
    Zaposleni je dužan da po isteku godišnjeg odmora, najkasnije prvog narednog
    radnog dana, pristupi izvršenju svojih redovnih radnih obaveza.
  </p>

  <p>
    Ovo rešenje stupa na snagu danom donošenja, a uručuje se zaposlenom, HR
    službi i finansijskoj službi.
  </p>

  <table class="pts">
    <tr><td>•</td><td>Osnov: član 68. Zakona o radu</td></tr>
    <tr><td>•</td><td>Ukupan broj dana GO za ${escHtml(String(year))}: prema evidenciji</td></tr>
  </table>

  <div class="signs">
    <div class="sign-box">
      <div class="sign-line">Zaposleni</div>
      <div>${escHtml(employeeDisplayName(emp) || '')}</div>
    </div>
    <div class="sign-box">
      <div class="sign-line">Direktor / ovlašćeno lice</div>
      <div>&nbsp;</div>
    </div>
  </div>
</body>
</html>`;

  const w = window.open('', '_blank', 'width=900,height=1200,scrollbars=1');
  if (!w) { showToast('⚠ Pop-up blocker je sprečio prozor'); return; }
  w.document.open();
  w.document.write(html);
  w.document.close();
}

/* ── Excel export ───────────────────────────────────────────────────── */

async function exportToExcel() {
  const rows = computeRows();
  if (!rows.length) { showToast('Nema podataka za izvoz'); return; }
  const XLSX = await loadXlsx();
  const year = Number(panelRoot.querySelector('#vacYear').value);
  const data = [
    ['Zaposleni', 'Odeljenje', 'Dana pravo', 'Preneto', 'Iskorišćeno', 'Preostalo'],
    ...rows.map(r => [
      employeeDisplayName(r.emp) || '',
      r.emp.department || '',
      r.daysTotal,
      r.daysCarried,
      r.daysUsed,
      r.daysRemaining,
    ]),
  ];
  const wb = XLSX.utils.book_new();
  const ws = XLSX.utils.aoa_to_sheet(data);
  XLSX.utils.book_append_sheet(wb, ws, `GO ${year}`);
  XLSX.writeFile(wb, `Godisnji_odmor_${year}.xlsx`);
}
