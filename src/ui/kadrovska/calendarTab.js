/**
 * Kadrovska — Tab „Kalendar" (C3.3).
 *
 * Shared mesečni kalendar koji preklapa:
 *   - GO (godišnji odmor) — zeleno
 *   - Bolovanja — crveno
 *   - Plaćeno odsustvo / slobodan dan — žuto
 *   - Neplaćeno — sivo
 *   - Službeni put — plavo
 *   - Državni praznici — svetlo plavo (red)
 *   - Vikendi — siva pozadina
 *   - Rođendani — 🎂 marker
 *   - Lekarski/ugovor ističe — ⚠ marker (badge ispod imena)
 *
 * Format: red = zaposleni, kolona = dan u mesecu.
 *
 * UX:
 *   - Mesec/godina picker, filter odeljenje
 *   - Klik na ćeliju → modal sa detaljima (tip odsustva, period, napomena, link na tab)
 *   - Klik na ime → otvori zaposlenog
 *   - "Danas" je markiran tankim narandžastim border-om
 *   - Sticky prva kolona (ime) i prvi red (broj/dan)
 *   - Eksport u Excel (ista struktura kao prikaz)
 *
 * Source-of-truth: tabela `absences` (period sa tipom). Mesečni grid (work_hours
 * sa absence_code) NIJE source za ovo — kalendar je pogled na zvanične evidencije
 * odsustava, ne dnevne unose sati.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { formatDate } from '../../lib/date.js';
import {
  compareEmployeesByLastFirst,
  employeeDisplayName,
} from '../../lib/employeeNames.js';
import { canEditKadrovska } from '../../state/auth.js';
import { kadrovskaState, orgStructureState } from '../../state/kadrovska.js';
import {
  ensureEmployeesLoaded,
  ensureAbsencesLoaded,
  ensureOrgStructureLoaded,
  uniqueDepartments,
  employeeNameById,
} from '../../services/kadrovska.js';
import { kadrAbsencesState } from '../../state/kadrovska.js';
import { loadHolidaysForRange, isHolidayDate, holidayDateSet } from '../../services/holidays.js';
import { kadrHolidaysState } from '../../state/kadrovska.js';
import { renderSummaryChips } from './shared.js';
import { loadXlsx } from '../../lib/xlsx.js';

let panelRoot = null;
const state = {
  monthKey: _defaultMonthKey(),
  deptFilter: '',
  searchQuery: '',
  loaded: false,
};

const ABS_TONE = {
  godisnji:   'cal-abs-go',
  bolovanje:  'cal-abs-bo',
  sluzbeno:   'cal-abs-sp',
  slava:      'cal-abs-pl',
  placeno:    'cal-abs-pl',
  neplaceno:  'cal-abs-nop',
  slobodan:   'cal-abs-sl',
  ostalo:     'cal-abs-other',
};

const ABS_SHORT = {
  godisnji:   'GO',
  bolovanje:  'BO',
  sluzbeno:   'SP',
  slava:      'SL',
  placeno:    'PL',
  neplaceno:  'NP',
  slobodan:   'SL',
  ostalo:     '?',
};

const ABS_LABEL = {
  godisnji:   'Godišnji odmor',
  bolovanje:  'Bolovanje',
  sluzbeno:   'Službeni put',
  slava:      'Krsna slava',
  placeno:    'Plaćeno odsustvo',
  neplaceno:  'Neplaćeno odsustvo',
  slobodan:   'Slobodan dan',
  ostalo:     'Ostalo',
};

function _defaultMonthKey() {
  const t = new Date();
  return `${t.getFullYear()}-${String(t.getMonth() + 1).padStart(2, '0')}`;
}

function _daysInMonth(yyyymm) {
  if (!yyyymm) return [];
  const [y, m] = yyyymm.split('-').map(n => parseInt(n, 10));
  if (!y || !m) return [];
  const last = new Date(y, m, 0).getDate();
  const out = [];
  for (let d = 1; d <= last; d++) {
    const ymd = `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    const dt = new Date(y, m - 1, d);
    const dow = dt.getDay();
    out.push({
      day: d,
      ymd,
      dow,
      isWeekend: dow === 0 || dow === 6,
    });
  }
  return out;
}

function _todayIso() {
  const t = new Date();
  return `${t.getFullYear()}-${String(t.getMonth() + 1).padStart(2, '0')}-${String(t.getDate()).padStart(2, '0')}`;
}

function _isInRange(ymd, from, to) {
  if (!ymd || !from || !to) return false;
  return ymd >= from && ymd <= to;
}

/* ── PUBLIC API ──────────────────────────────────────────────────── */

export function renderCalendarTab() {
  return `
    <section class="kadr-panel-inner kadr-calendar-panel" aria-label="Kalendar">
      <div class="kadr-summary-strip" id="calSummary"></div>
      <div class="kadrovska-toolbar">
        <label class="kadrovska-filter" style="display:flex;gap:6px;align-items:center;">
          <span>Mesec</span>
          <input type="month" id="calMonth" value="${escHtml(state.monthKey)}">
        </label>
        <button type="button" class="btn btn-ghost" id="calPrevMonth" title="Prethodni mesec">‹</button>
        <button type="button" class="btn btn-ghost" id="calNextMonth" title="Sledeći mesec">›</button>
        <select class="kadrovska-filter" id="calDeptFilter">
          <option value="">Sva odeljenja</option>
        </select>
        <input type="search" class="kadrovska-search" id="calSearch" placeholder="Pretraga po imenu…">
        <div class="kadrovska-toolbar-spacer"></div>
        <button class="btn btn-ghost" id="calExport" title="Izvoz u Excel">📊 Excel</button>
        <span class="kadrovska-count" id="calCount">0 zaposlenih</span>
      </div>
      <div class="cal-legend" aria-label="Legenda">
        <span class="cal-legend-item"><span class="cal-legend-sw cal-abs-go"></span>Godišnji</span>
        <span class="cal-legend-item"><span class="cal-legend-sw cal-abs-bo"></span>Bolovanje</span>
        <span class="cal-legend-item"><span class="cal-legend-sw cal-abs-sp"></span>Službeno</span>
        <span class="cal-legend-item"><span class="cal-legend-sw cal-abs-pl"></span>Plaćeno / Slava</span>
        <span class="cal-legend-item"><span class="cal-legend-sw cal-abs-nop"></span>Neplaćeno</span>
        <span class="cal-legend-item"><span class="cal-legend-sw cal-abs-sl"></span>Slobodan dan</span>
        <span class="cal-legend-item"><span class="cal-legend-sw cal-holiday"></span>Državni praznik</span>
        <span class="cal-legend-item">🎂 Rođendan</span>
        <span class="cal-legend-item">⚠ Lekarski / ugovor ističe (mesec)</span>
      </div>
      <div id="calWrap" class="cal-wrap"></div>
      <div id="calEmpty" class="kadrovska-empty" style="display:none;margin-top:16px;">
        <div class="kadrovska-empty-title">Nema zaposlenih za izabrane filtere</div>
      </div>
    </section>`;
}

export async function wireCalendarTab(panelEl) {
  panelRoot = panelEl;

  panelEl.querySelector('#calMonth').addEventListener('change', (e) => {
    state.monthKey = e.target.value || _defaultMonthKey();
    void _reloadAndRender();
  });
  panelEl.querySelector('#calPrevMonth').addEventListener('click', () => _shiftMonth(-1));
  panelEl.querySelector('#calNextMonth').addEventListener('click', () => _shiftMonth(+1));
  panelEl.querySelector('#calDeptFilter').addEventListener('change', (e) => {
    state.deptFilter = e.target.value || '';
    _render();
  });
  panelEl.querySelector('#calSearch').addEventListener('input', (e) => {
    state.searchQuery = (e.target.value || '').trim().toLowerCase();
    _render();
  });
  panelEl.querySelector('#calExport').addEventListener('click', () => {
    void _exportToXlsx().catch(err => {
      console.error('[calendar] export', err);
      showToast('⚠ Greška pri izvozu');
    });
  });

  try {
    await Promise.all([
      ensureEmployeesLoaded(),
      ensureOrgStructureLoaded(),
      ensureAbsencesLoaded(true),
    ]);
  } catch (e) {
    console.warn('[calendar] load failed', e);
  }
  await _reloadAndRender();
}

function _shiftMonth(delta) {
  const [y, m] = state.monthKey.split('-').map(n => parseInt(n, 10));
  let ny = y, nm = m + delta;
  while (nm < 1) { nm += 12; ny -= 1; }
  while (nm > 12) { nm -= 12; ny += 1; }
  state.monthKey = `${ny}-${String(nm).padStart(2, '0')}`;
  if (panelRoot) panelRoot.querySelector('#calMonth').value = state.monthKey;
  void _reloadAndRender();
}

async function _reloadAndRender() {
  if (!panelRoot) return;
  const days = _daysInMonth(state.monthKey);
  if (days.length) {
    try {
      await loadHolidaysForRange(days[0].ymd, days[days.length - 1].ymd);
    } catch (e) {
      console.warn('[calendar] holidays load failed', e);
    }
  }
  state.loaded = true;
  _render();
}

function _populateDeptFilter() {
  if (!panelRoot) return;
  const sel = panelRoot.querySelector('#calDeptFilter');
  if (!sel) return;
  const curr = sel.value;
  const depts = uniqueDepartments();
  const opts = ['<option value="">Sva odeljenja</option>']
    .concat(depts.map(d => `<option value="${escHtml(String(d.id ?? d.name))}">${escHtml(d.name)}</option>`));
  sel.innerHTML = opts.join('');
  if (curr && Array.from(sel.options).some(o => o.value === curr)) sel.value = curr;
}

function _filteredEmployees() {
  const dept = state.deptFilter;
  const q = state.searchQuery;
  return kadrovskaState.employees.filter(e => {
    if (!e.isActive) return false;
    if (dept) {
      const deptId = parseInt(dept, 10);
      if (orgStructureState.departments.length && !isNaN(deptId)) {
        if (e.departmentId !== deptId) return false;
      } else if (e.department !== dept) return false;
    }
    if (q) {
      const hay = [employeeDisplayName(e), e.firstName, e.lastName, e.department, e.team].join(' ').toLowerCase();
      if (!hay.includes(q)) return false;
    }
    return true;
  }).sort(compareEmployeesByLastFirst);
}

/* Vraća: Map<empId, Array<absence>> samo za zapise koji se preklapaju sa mesecom. */
function _absencesByEmpForMonth(monthKey) {
  const [y, m] = monthKey.split('-').map(n => parseInt(n, 10));
  const mStart = `${y}-${String(m).padStart(2, '0')}-01`;
  const mEnd = `${y}-${String(m).padStart(2, '0')}-${new Date(y, m, 0).getDate()}`;
  const byEmp = new Map();
  for (const a of kadrAbsencesState.items) {
    if (!a.dateFrom || !a.dateTo) continue;
    if (a.dateTo < mStart || a.dateFrom > mEnd) continue;
    if (!byEmp.has(a.employeeId)) byEmp.set(a.employeeId, []);
    byEmp.get(a.employeeId).push(a);
  }
  return byEmp;
}

/** Vraća {label, tone} ako u datom mesecu zaposleni ima rođendan, lekarski koji ističe, ili sl. */
function _empMonthBadges(emp, monthKey) {
  const out = [];
  const mm = monthKey.split('-')[1];
  /* Rođendan */
  if (emp.birthDate) {
    const bm = emp.birthDate.slice(5, 7);
    if (bm === mm) {
      const day = parseInt(emp.birthDate.slice(8, 10), 10);
      out.push({ icon: '🎂', tone: 'bday', title: `Rođendan ${day}.${parseInt(mm, 10)}.` });
    }
  }
  /* Lekarski ističe u ovom mesecu */
  if (emp.medicalExamExpires) {
    const em = emp.medicalExamExpires.slice(0, 7);
    if (em === monthKey) {
      out.push({ icon: '⚠', tone: 'med', title: `Lekarski ističe ${formatDate(emp.medicalExamExpires)}` });
    }
  }
  return out;
}

function _render() {
  if (!panelRoot) return;
  _populateDeptFilter();
  const wrap = panelRoot.querySelector('#calWrap');
  const empty = panelRoot.querySelector('#calEmpty');
  const countEl = panelRoot.querySelector('#calCount');

  const days = _daysInMonth(state.monthKey);
  const emps = _filteredEmployees();
  const absByEmp = _absencesByEmpForMonth(state.monthKey);
  const holSet = holidayDateSet();
  const today = _todayIso();

  if (countEl) {
    countEl.textContent = `${emps.length} ${emps.length === 1 ? 'zaposleni' : 'zaposlenih'}`;
  }

  /* Update tab badge */
  const badge = document.getElementById('kadrTabCountCalendar');
  if (badge) badge.textContent = String(emps.length);

  /* Summary chips: ko je trenutno na odsustvu danas, ovaj mesec broj GO/BO… */
  _renderSummaryStrip(emps, absByEmp, days);

  if (!emps.length) {
    wrap.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  /* HEAD: dva reda (broj + slovo dana) */
  const dayLetters = ['N', 'P', 'U', 'S', 'Č', 'P', 'S'];
  let html = '<table class="cal-table" aria-label="Kalendarski prikaz odsustava"><thead><tr>';
  html += '<th class="cal-th-name" rowspan="2">Zaposleni</th>';
  for (const d of days) {
    const cls = [];
    if (d.isWeekend) cls.push('cal-cell-weekend');
    if (d.dow === 0) cls.push('cal-cell-sun');
    if (d.dow === 6) cls.push('cal-cell-sat');
    if (holSet.has(d.ymd)) cls.push('cal-cell-holiday');
    if (d.ymd === today) cls.push('cal-cell-today');
    html += `<th class="cal-th-day ${cls.join(' ')}" title="${escHtml(d.ymd)}">${d.day}</th>`;
  }
  html += '</tr><tr class="cal-row-letters">';
  for (const d of days) {
    const cls = [];
    if (d.isWeekend) cls.push('cal-cell-weekend');
    if (holSet.has(d.ymd)) cls.push('cal-cell-holiday');
    html += `<th class="${cls.join(' ')}">${dayLetters[d.dow]}</th>`;
  }
  html += '</tr></thead><tbody>';

  for (const emp of emps) {
    const empAbsences = absByEmp.get(emp.id) || [];
    const badges = _empMonthBadges(emp, state.monthKey);
    const badgesHtml = badges.length
      ? `<span class="cal-emp-badges">${badges.map(b => `<span class="cal-emp-badge tone-${b.tone}" title="${escHtml(b.title)}">${b.icon}</span>`).join('')}</span>`
      : '';
    const deptLine = emp.department
      ? `<div class="cal-emp-meta">${escHtml(emp.department)}</div>`
      : '';
    html += `<tr data-emp-id="${escHtml(emp.id)}">
      <td class="cal-td-name">
        <div class="cal-emp-name">${escHtml(employeeDisplayName(emp) || '—')}${badgesHtml}</div>
        ${deptLine}
      </td>`;

    for (const d of days) {
      const cls = ['cal-td-day'];
      if (d.isWeekend) cls.push('cal-cell-weekend');
      if (d.dow === 0) cls.push('cal-cell-sun');
      if (d.dow === 6) cls.push('cal-cell-sat');
      if (holSet.has(d.ymd)) cls.push('cal-cell-holiday');
      if (d.ymd === today) cls.push('cal-cell-today');

      const hit = empAbsences.find(a => _isInRange(d.ymd, a.dateFrom, a.dateTo));
      let inner = '';
      let title = '';
      if (hit) {
        const toneCls = ABS_TONE[hit.type] || 'cal-abs-other';
        cls.push(toneCls);
        inner = `<span class="cal-cell-mark">${ABS_SHORT[hit.type] || '·'}</span>`;
        const lbl = ABS_LABEL[hit.type] || hit.type;
        title = `${lbl}: ${formatDate(hit.dateFrom)} – ${formatDate(hit.dateTo)}${hit.note ? '\n' + hit.note : ''}`;
      } else if (holSet.has(d.ymd)) {
        const h = kadrHolidaysState.byDate.get(d.ymd);
        title = h ? h.name : 'Državni praznik';
      } else if (d.ymd === today) {
        title = 'Danas';
      }
      html += `<td class="${cls.join(' ')}" data-ymd="${d.ymd}" data-emp-id="${escHtml(emp.id)}" ${title ? `title="${escHtml(title)}"` : ''}>${inner}</td>`;
    }
    html += '</tr>';
  }
  html += '</tbody></table>';
  wrap.innerHTML = html;

  /* Click on cell — open detail modal if it has an absence */
  wrap.querySelectorAll('td.cal-td-day').forEach(td => {
    td.addEventListener('click', () => {
      const empId = td.dataset.empId;
      const ymd = td.dataset.ymd;
      _openCellDetail(empId, ymd);
    });
  });
}

function _renderSummaryStrip(emps, absByEmp, days) {
  const today = _todayIso();
  let onLeaveToday = 0;
  let goTotal = 0, boTotal = 0, otherTotal = 0;
  const absentToday = new Set();
  for (const emp of emps) {
    const list = absByEmp.get(emp.id) || [];
    for (const a of list) {
      if (_isInRange(today, a.dateFrom, a.dateTo)) absentToday.add(emp.id);
      if (a.type === 'godisnji') goTotal++;
      else if (a.type === 'bolovanje') boTotal++;
      else otherTotal++;
    }
  }
  onLeaveToday = absentToday.size;
  const holidaysCount = days.filter(d => isHolidayDate(d.ymd)).length;

  renderSummaryChips('calSummary', [
    { label: 'Aktivni', value: emps.length, tone: 'accent' },
    { label: 'Danas na odsustvu', value: onLeaveToday, tone: onLeaveToday > 0 ? 'warn' : 'muted' },
    { label: 'GO (mesec)', value: goTotal, tone: goTotal > 0 ? 'ok' : 'muted' },
    { label: 'Bolovanja (mesec)', value: boTotal, tone: boTotal > 0 ? 'warn' : 'muted' },
    { label: 'Ostala odsustva', value: otherTotal, tone: otherTotal > 0 ? 'accent' : 'muted' },
    { label: 'Praznici', value: holidaysCount, tone: 'muted' },
  ]);
}

/* ── CELL DETAIL MODAL ───────────────────────────────────────────── */

function _openCellDetail(empId, ymd) {
  const emp = kadrovskaState.employees.find(e => e.id === empId);
  if (!emp) return;
  const absences = (kadrAbsencesState.items || []).filter(a =>
    a.employeeId === empId && _isInRange(ymd, a.dateFrom, a.dateTo)
  );
  const holiday = kadrHolidaysState.byDate.get(ymd);
  const isToday = ymd === _todayIso();

  document.getElementById('calCellModal')?.remove();
  const wrap = document.createElement('div');

  const absBlock = absences.length
    ? absences.map(a => {
        const lbl = ABS_LABEL[a.type] || a.type;
        return `<div class="cal-detail-row">
          <span class="kadr-type-badge t-${escHtml(a.type)}">${escHtml(lbl)}</span>
          <span class="cal-detail-range">${formatDate(a.dateFrom)} – ${formatDate(a.dateTo)} (${a.daysCount || ''}d)</span>
          ${a.note ? `<div class="cal-detail-note">${escHtml(a.note)}</div>` : ''}
        </div>`;
      }).join('')
    : '<div class="emp-sub" style="padding:8px 0">Nema upisanog odsustva za ovaj dan.</div>';

  wrap.innerHTML = `
    <div class="kadr-modal-overlay" id="calCellModal" role="dialog" aria-modal="true">
      <div class="kadr-modal">
        <div class="kadr-modal-title">${escHtml(employeeDisplayName(emp) || '—')}</div>
        <div class="kadr-modal-subtitle">${formatDate(ymd)}${isToday ? ' (danas)' : ''}${holiday ? ` · 🇷🇸 ${escHtml(holiday.name)}` : ''}</div>
        <div class="cal-detail-body">
          ${absBlock}
        </div>
        <div class="kadr-modal-actions">
          <button type="button" class="btn" id="calCellClose">Zatvori</button>
        </div>
      </div>
    </div>`;
  document.body.appendChild(wrap.firstElementChild);
  const modal = document.getElementById('calCellModal');
  modal.querySelector('#calCellClose').addEventListener('click', () => modal.remove());
  modal.addEventListener('click', e => { if (e.target === modal) modal.remove(); });
}

/* ── EXPORT ──────────────────────────────────────────────────────── */

async function _exportToXlsx() {
  const days = _daysInMonth(state.monthKey);
  const emps = _filteredEmployees();
  if (!emps.length) { showToast('Nema podataka za izvoz'); return; }
  showToast('⏳ Učitavam XLSX…');
  const XLSX = await loadXlsx();
  const absByEmp = _absencesByEmpForMonth(state.monthKey);
  const holSet = holidayDateSet();
  const dayLetters = ['N', 'P', 'U', 'S', 'Č', 'P', 'S'];

  const aoa = [];
  aoa.push(['Kalendar ' + state.monthKey]);
  aoa.push([]);
  const header = ['Zaposleni', 'Odeljenje'].concat(days.map(d => String(d.day)));
  aoa.push(header);
  aoa.push(['', ''].concat(days.map(d => dayLetters[d.dow])));

  for (const emp of emps) {
    const list = absByEmp.get(emp.id) || [];
    const row = [employeeDisplayName(emp) || '', emp.department || ''];
    for (const d of days) {
      const hit = list.find(a => _isInRange(d.ymd, a.dateFrom, a.dateTo));
      if (hit) row.push(ABS_SHORT[hit.type] || '?');
      else if (holSet.has(d.ymd)) row.push('PR');
      else if (d.isWeekend) row.push('');
      else row.push('');
    }
    aoa.push(row);
  }

  const ws = XLSX.utils.aoa_to_sheet(aoa);
  ws['!cols'] = [{ wch: 28 }, { wch: 20 }].concat(days.map(() => ({ wch: 4 })));
  ws['!merges'] = [{ s: { r: 0, c: 0 }, e: { r: 0, c: days.length + 1 } }];
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Kalendar ' + state.monthKey);
  XLSX.writeFile(wb, `Kalendar_${state.monthKey}.xlsx`);
  showToast('📊 Izvezeno');
}
