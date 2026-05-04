/**
 * Kadrovska — Tab Odsustva / sub-view "Pregled" (K3.5)
 *
 * Pivot tabela: 1 red = 1 zaposleni, 15 zbirnih kolona za izabrani period.
 * Klik na red prebacuje korisnika na Mesecni grid sa pre-filterom.
 * Excel export identičnog sadrzaja.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { daysInclusive } from '../../lib/date.js';
import { compareEmployeesByLastFirst, employeeDisplayName } from '../../lib/employeeNames.js';
import { getIsOnline } from '../../state/auth.js';
import { hasSupabaseConfig, SESSION_KEYS } from '../../lib/constants.js';
import { ssGet, ssSet } from '../../lib/storage.js';
import {
  kadrovskaState,
  kadrAbsencesState,
  kadrVacationState,
  kadrHolidaysState,
} from '../../state/kadrovska.js';
import {
  ensureEmployeesLoaded,
  ensureAbsencesLoaded,
  ensureVacationLoaded,
} from '../../services/kadrovska.js';
import { loadWorkHoursForPeriod } from '../../services/grid.js';
import { loadHolidaysForRange } from '../../services/holidays.js';
import { loadXlsx } from '../../lib/xlsx.js';

/* ─── module state ──────────────────────────────────────────────────────── */

let _panel = null;
let _onNavigateGrid = null;
let _computedRows = [];
let _loadingFlag = false;
let _sortState = { col: 'name', dir: 'asc' };
let _recomputeTimer = null;
let _dateDebounceTimer = null;
let _searchDebounceTimer = null;

/* ─── column defs ───────────────────────────────────────────────────────── */

const COLS = [
  { key: 'name',          label: 'Zaposleni',   title: 'Ime i prezime',                       numeric: false },
  { key: 'dept',          label: 'Odeljenje',   title: 'Odeljenje / firma',                   numeric: false },
  { key: 'workType',      label: 'Tip rada',    title: 'Tip rada (ugovor/praksa/...)',         numeric: false },
  { key: 'radnihDana',    label: 'RD',          title: 'Radnih dana (dani sa odrađenim satima)', numeric: true },
  { key: 'goDays',        label: 'GO',          title: 'Godisnji odmor — iskorisceno (dani)',  numeric: true },
  { key: 'goSaldo',       label: 'GO saldo',    title: 'Saldo godisnjeg odmora za godinu perioda', numeric: true },
  { key: 'bo65',          label: 'Bo 65%',      title: 'Bolovanje 65% (obicno)',               numeric: true },
  { key: 'bo100',         label: 'Bo 100%',     title: 'Bolovanje 100% (povreda/trudnoca)',    numeric: true },
  { key: 'slobodni',      label: 'Slobodni',    title: 'Slobodni placeni dani (svi razlozi)',  numeric: true },
  { key: 'slava',         label: 'Slava',       title: 'Krsna slava (subset slobodnih)',       numeric: true },
  { key: 'neplaceno',     label: 'Nepl.',       title: 'Neplaceno odsustvo',                   numeric: true },
  { key: 'terrDom',       label: 'Ter.D',       title: 'Tereni domaci (dani)',                 numeric: true },
  { key: 'terrIno',       label: 'Ter.I',       title: 'Tereni inostrani (dani)',              numeric: true },
  { key: 'praznici',      label: 'Pr.rad',      title: 'Praznici sa radom (dani)',             numeric: true },
  { key: 'ukupnoOdsutan', label: 'Ukupno ods.', title: 'Ukupno odsutan = GO+Bo+Slob.+Nepl.', numeric: true },
];

/* ─── date helpers ──────────────────────────────────────────────────────── */

function _isoToday() {
  const t = new Date();
  return `${t.getFullYear()}-${String(t.getMonth() + 1).padStart(2, '0')}-${String(t.getDate()).padStart(2, '0')}`;
}

function _ymd(y, m1, d) {
  return `${y}-${String(m1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

/* ─── period state ──────────────────────────────────────────────────────── */

function _defaultPeriod() {
  const today = _isoToday();
  return { from: `${today.slice(0, 4)}-01-01`, to: today, preset: 'tekuca-godina' };
}

function _loadPeriod() {
  const raw = ssGet(SESSION_KEYS.KADR_ODSUSTVA_PERIOD, null);
  if (raw) try { return JSON.parse(raw); } catch { /* fall through */ }
  return _defaultPeriod();
}

function _savePeriod(p) {
  ssSet(SESSION_KEYS.KADR_ODSUSTVA_PERIOD, JSON.stringify(p));
}

function _presetToPeriod(preset) {
  const today = _isoToday();
  const y = new Date().getFullYear();
  const m = new Date().getMonth() + 1;
  if (preset === 'tekuca-godina')    return { from: `${y}-01-01`, to: today };
  if (preset === 'prethodna-godina') return { from: `${y - 1}-01-01`, to: `${y - 1}-12-31` };
  if (preset === 'tekuci-mesec')     return { from: _ymd(y, m, 1), to: today };
  if (preset === 'prethodni-mesec') {
    const pm = m === 1 ? 12 : m - 1;
    const py = m === 1 ? y - 1 : y;
    const last = new Date(py, pm, 0).getDate();
    return { from: _ymd(py, pm, 1), to: _ymd(py, pm, last) };
  }
  return null;
}

function _updatePresetButtons(preset) {
  _panel?.querySelectorAll('.kadr-preset-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.preset === preset);
  });
}

/* ─── sort + filter ─────────────────────────────────────────────────────── */

function _loadSort() {
  const raw = ssGet(SESSION_KEYS.KADR_ODSUSTVA_SORT, null);
  if (raw) try { return JSON.parse(raw); } catch { /* fall through */ }
  return { col: 'name', dir: 'asc' };
}

function _saveSort(s) {
  ssSet(SESSION_KEYS.KADR_ODSUSTVA_SORT, JSON.stringify(s));
}

function _sortRows(rows, sort) {
  const { col, dir } = sort;
  return rows.slice().sort((a, b) => {
    let va = a[col], vb = b[col];
    if (va == null) va = dir === 'asc' ? Infinity : -Infinity;
    if (vb == null) vb = dir === 'asc' ? Infinity : -Infinity;
    if (typeof va === 'string') {
      const c = va.localeCompare(vb, 'sr');
      return dir === 'asc' ? c : -c;
    }
    return dir === 'asc' ? va - vb : vb - va;
  });
}

function _filterRows(rows, q) {
  if (!q) return rows;
  const lq = q.toLowerCase();
  return rows.filter(r => r.name.toLowerCase().includes(lq) || r.dept.toLowerCase().includes(lq));
}

/* ─── aggregation ───────────────────────────────────────────────────────── */

function _clampDays(dateFrom, dateTo, periodFrom, periodTo) {
  if (!dateFrom || !dateTo) return 0;
  const f = dateFrom < periodFrom ? periodFrom : dateFrom;
  const t = dateTo > periodTo ? periodTo : dateTo;
  if (f > t) return 0;
  return daysInclusive(f, t);
}

function _computeRows(absList, whMap, entitlements, balances, holidaySet, employees, from, to) {
  const toYear = parseInt(to.slice(0, 4), 10);
  const rows = [];

  for (const emp of employees) {
    const empAbs = absList.filter(a => a.employeeId === emp.id);
    const empWH  = whMap.get(emp.id) || [];

    /* Radnih dana: dani sa bilo kojim satima */
    const radnihDana = empWH.filter(w =>
      (w.hours + w.overtimeHours + w.fieldHours + w.twoMachineHours) > 0
    ).length;

    /* Helper: zbir clamped dana po filteru */
    const sumDays = fn => empAbs
      .filter(fn)
      .reduce((s, a) => s + _clampDays(a.dateFrom, a.dateTo, from, to), 0);

    const goDays   = sumDays(a => a.type === 'godisnji');
    const bo65     = sumDays(a => a.type === 'bolovanje' &&
      (a.absenceSubtype === 'obicno' || a.absenceSubtype == null));
    const bo100    = sumDays(a => a.type === 'bolovanje' &&
      (a.absenceSubtype === 'povreda_na_radu' || a.absenceSubtype === 'odrzavanje_trudnoce'));
    const slobodni = sumDays(a => a.type === 'slobodan');
    const slava    = sumDays(a => a.type === 'slobodan' && a.slobodanReason === 'slava');
    const neplaceno = sumDays(a => a.type === 'neplaceno');

    /* GO saldo = days_total + days_carried_over - days_used za godinu perioda */
    const ent = entitlements.find(e => String(e.employeeId) === String(emp.id) && Number(e.year) === toYear);
    const bal = balances.find(b => String(b.employeeId) === String(emp.id));
    const goSaldo = ent != null
      ? (Number(ent.daysTotal || 0) + Number(ent.daysCarriedOver || 0)) - Number(bal?.daysUsed || 0)
      : null;

    /* Tereni: Set<ymd> po podtipu */
    const terrDomSet = new Set();
    const terrInoSet = new Set();
    empWH.forEach(w => {
      if (w.fieldHours > 0) {
        if (w.fieldSubtype === 'foreign') terrInoSet.add(w.workDate);
        else terrDomSet.add(w.workDate);
      }
    });

    /* Praznici sa radom */
    let praznici = 0;
    empWH.forEach(w => {
      if (holidaySet.has(w.workDate) &&
          (w.hours + w.overtimeHours + w.fieldHours + w.twoMachineHours) > 0) {
        praznici++;
      }
    });

    rows.push({
      empId: emp.id,
      name: employeeDisplayName(emp) || '—',
      dept: emp.department || '',
      workType: emp.work_type || emp.workType || '',
      radnihDana,
      goDays,
      goSaldo,
      bo65,
      bo100,
      slobodni,
      slava,
      neplaceno,
      terrDom: terrDomSet.size,
      terrIno: terrInoSet.size,
      praznici,
      ukupnoOdsutan: goDays + bo65 + bo100 + slobodni + neplaceno,
    });
  }
  return rows;
}

/* ─── table render ──────────────────────────────────────────────────────── */

function _renderTable(rows, sort) {
  if (!rows.length) {
    return '<div class="kadr-empty" style="padding:24px">Nema aktivnih zaposlenih za prikaz.</div>';
  }

  const thCells = COLS.map(c => {
    const isSorted = sort.col === c.key;
    const cls = ['kadr-col-sort', isSorted ? sort.dir : ''].filter(Boolean).join(' ');
    return `<th class="${cls}" data-sort="${c.key}" title="${escHtml(c.title)}">${escHtml(c.label)}</th>`;
  }).join('');

  const bodyRows = rows.map((r, i) => {
    const cells = COLS.map(c => {
      const v = r[c.key];
      const display = c.numeric
        ? (v == null ? '<span class="kadr-null">—</span>' : String(v))
        : escHtml(String(v || '—'));
      return `<td${c.numeric ? ' class="num"' : ''}>${display}</td>`;
    }).join('');
    return `<tr class="kadr-pregled-row" data-emp-id="${escHtml(r.empId)}" data-emp-name="${escHtml(r.name)}" title="Klikni za Mesecni grid → ${escHtml(r.name)}">
      <td class="num">${i + 1}</td>${cells}
    </tr>`;
  }).join('');

  /* Footer sums */
  const ftCells = COLS.map(c => {
    if (!c.numeric) return '<td></td>';
    const s = rows.reduce((acc, r) => acc + (Number(r[c.key]) || 0), 0);
    return `<td class="num">${s}</td>`;
  }).join('');

  return `
    <table class="kadr-table kadr-pregled-table">
      <thead><tr><th>#</th>${thCells}</tr></thead>
      <tbody>${bodyRows}</tbody>
      <tfoot><tr class="kadr-pregled-footer"><td>&#931;</td>${ftCells}</tr></tfoot>
    </table>`;
}

/* ─── refresh (sort + filter + render) ──────────────────────────────────── */

function _refreshTable() {
  const wrap = _panel?.querySelector('#pregledWrap');
  if (!wrap || _loadingFlag) return;

  const q = ssGet(SESSION_KEYS.KADR_ODSUSTVA_SEARCH, '');
  const filtered = _filterRows(_computedRows, q);
  const sorted   = _sortRows(filtered, _sortState);

  wrap.innerHTML = _renderTable(sorted, _sortState);

  /* Sort header clicks */
  wrap.querySelectorAll('th.kadr-col-sort').forEach(th => {
    th.style.cursor = 'pointer';
    th.addEventListener('click', () => {
      const col = th.dataset.sort;
      if (_sortState.col === col) {
        _sortState.dir = _sortState.dir === 'asc' ? 'desc' : 'asc';
      } else {
        _sortState.col = col;
        _sortState.dir = 'asc';
      }
      _saveSort(_sortState);
      _refreshTable();
    });
  });

  /* Row click → navigate to grid */
  wrap.querySelectorAll('.kadr-pregled-row').forEach(row => {
    row.style.cursor = 'pointer';
    row.addEventListener('click', () => {
      const empName = row.dataset.empName || '';
      const period = _loadPeriod();
      const yyyymm = (period.to || _isoToday()).slice(0, 7);
      ssSet(SESSION_KEYS.KADR_GRID_SEARCH, empName);
      if (_onNavigateGrid) _onNavigateGrid(empName, yyyymm);
    });
  });
}

/* ─── data load + compute ───────────────────────────────────────────────── */

async function _loadAndCompute(from, to, force = false) {
  const wrap = _panel?.querySelector('#pregledWrap');
  if (!wrap) return;
  wrap.innerHTML = '<div style="padding:24px;color:var(--text3);font-size:13px">Ucitavanje...</div>';
  _loadingFlag = true;

  try {
    await ensureEmployeesLoaded();
    await ensureAbsencesLoaded(force);

    const toYear = parseInt(to.slice(0, 4), 10);
    await ensureVacationLoaded(toYear, force);

    let whMap = new Map();
    const holidaySet = new Set();

    if (getIsOnline() && hasSupabaseConfig()) {
      await loadHolidaysForRange(from, to);
      whMap = await loadWorkHoursForPeriod(from, to);
    }

    kadrHolidaysState.byDate.forEach((h, ymd) => {
      if (!h.isWorkday && ymd >= from && ymd <= to) holidaySet.add(ymd);
    });

    /* Absences za period (clamp-ovanje se radi u _clampDays po redu) */
    const absList = kadrAbsencesState.items.filter(a =>
      a.dateTo >= from && a.dateFrom <= to
    );

    const employees = kadrovskaState.employees
      .filter(e => e.isActive)
      .slice()
      .sort(compareEmployeesByLastFirst);

    _computedRows = _computeRows(
      absList, whMap,
      kadrVacationState.entitlements,
      kadrVacationState.balances,
      holidaySet,
      employees,
      from, to
    );

    _loadingFlag = false;
    _refreshTable();
  } catch (err) {
    _loadingFlag = false;
    console.error('[pregled] load error', err);
    if (wrap) wrap.innerHTML = '<div class="kadr-empty" style="padding:24px">Greska pri ucitavanju — vidi konzolu.</div>';
  }
}

function _scheduleRecompute(force = false) {
  clearTimeout(_recomputeTimer);
  _recomputeTimer = setTimeout(async () => {
    const p = _loadPeriod();
    await _loadAndCompute(p.from, p.to, force);
  }, 80);
}

/* ─── Excel export ──────────────────────────────────────────────────────── */

async function _exportXlsx() {
  let XLSX;
  try { XLSX = await loadXlsx(); } catch { showToast('XLSX nedostupan'); return; }

  const p = _loadPeriod();
  const q = ssGet(SESSION_KEYS.KADR_ODSUSTVA_SEARCH, '');
  const visible = _sortRows(_filterRows(_computedRows, q), _sortState);

  const xlsHeader = [
    'Zaposleni', 'Odeljenje', 'Tip rada', 'Radnih dana',
    'GO iSk.', 'GO saldo', 'Bo 65%', 'Bo 100%',
    'Slobodni', 'Slava', 'Neplaceno',
    'Tereni D', 'Tereni I', 'Praznici rad', 'Ukupno ods.',
  ];

  const dataRows = visible.map(r => [
    r.name, r.dept, r.workType, r.radnihDana,
    r.goDays, r.goSaldo ?? '', r.bo65, r.bo100,
    r.slobodni, r.slava, r.neplaceno,
    r.terrDom, r.terrIno, r.praznici, r.ukupnoOdsutan,
  ]);

  const sumRow = [
    'Ukupno', '', '',
    visible.reduce((s, r) => s + r.radnihDana, 0),
    visible.reduce((s, r) => s + r.goDays, 0),
    visible.filter(r => r.goSaldo != null).reduce((s, r) => s + r.goSaldo, 0),
    visible.reduce((s, r) => s + r.bo65, 0),
    visible.reduce((s, r) => s + r.bo100, 0),
    visible.reduce((s, r) => s + r.slobodni, 0),
    visible.reduce((s, r) => s + r.slava, 0),
    visible.reduce((s, r) => s + r.neplaceno, 0),
    visible.reduce((s, r) => s + r.terrDom, 0),
    visible.reduce((s, r) => s + r.terrIno, 0),
    visible.reduce((s, r) => s + r.praznici, 0),
    visible.reduce((s, r) => s + r.ukupnoOdsutan, 0),
  ];

  const aoa = [
    [`Period: ${p.from} do ${p.to}`, `Generisano: ${_isoToday()}`],
    [],
    xlsHeader,
    ...dataRows,
    sumRow,
  ];

  const ws = XLSX.utils.aoa_to_sheet(aoa);
  ws['!cols'] = [
    { wch: 30 }, { wch: 18 }, { wch: 10 }, { wch: 8 },
    { wch: 8 },  { wch: 10 }, { wch: 8 },  { wch: 8 },
    { wch: 10 }, { wch: 8 },  { wch: 10 }, { wch: 8 },
    { wch: 8 },  { wch: 12 }, { wch: 12 },
  ];
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Pregled odsustava');
  const fname = `Pregled_odsustava_${p.from}_${p.to}.xlsx`;
  XLSX.writeFile(wb, fname);
  showToast('Izvezeno: ' + fname);
}

/* ─── public API ────────────────────────────────────────────────────────── */

export function renderOdsustvaPregledHtml() {
  return `
    <section class="kadr-pregled-panel" aria-label="Pregled odsustava">
      <div class="kadr-pregled-toolbar">
        <div class="kadr-pregled-presets" role="group" aria-label="Brzi period izbor">
          <button class="kadr-preset-btn" data-preset="tekuca-godina">Tekuca god.</button>
          <button class="kadr-preset-btn" data-preset="prethodna-godina">Preth. god.</button>
          <button class="kadr-preset-btn" data-preset="tekuci-mesec">Tekuci mes.</button>
          <button class="kadr-preset-btn" data-preset="prethodni-mesec">Preth. mes.</button>
          <button class="kadr-preset-btn" data-preset="custom">Custom</button>
        </div>
        <div class="kadr-pregled-period-row">
          <label class="kadr-field"><span>Od</span><input type="date" id="pregledFrom"></label>
          <label class="kadr-field"><span>Do</span><input type="date" id="pregledTo"></label>
          <button class="btn btn-ghost" id="pregledRefresh" title="Osvezi podatke">&#8635; Osvezi</button>
        </div>
      </div>
      <div class="kadrovska-toolbar kadr-pregled-search-row">
        <input type="search" class="kadrovska-filter kadr-pregled-search" id="pregledSearch"
               placeholder="Pretraga po imenu..." maxlength="100">
        <button class="btn btn-ghost" id="pregledSearchClear" title="Ocisti">X</button>
        <div class="kadrovska-toolbar-spacer"></div>
        <button class="btn btn-ghost" id="pregledExport" title="Izvoz u Excel">&#128202; Excel</button>
      </div>
      <div class="kadr-table-wrap kadr-pregled-wrap" id="pregledWrap">
        <div style="padding:24px;color:var(--text3);font-size:13px">Ucitavanje...</div>
      </div>
    </section>`;
}

export async function wireOdsustvaPregledTab(panelEl, onNavigateGrid) {
  _panel = panelEl;
  _onNavigateGrid = onNavigateGrid || null;

  /* Restore persisted state */
  const period = _loadPeriod();
  _sortState = _loadSort();
  const searchQ = ssGet(SESSION_KEYS.KADR_ODSUSTVA_SEARCH, '');

  const fromEl = panelEl.querySelector('#pregledFrom');
  const toEl   = panelEl.querySelector('#pregledTo');
  if (fromEl) fromEl.value = period.from;
  if (toEl)   toEl.value   = period.to;

  const searchEl = panelEl.querySelector('#pregledSearch');
  if (searchEl) searchEl.value = searchQ;

  _updatePresetButtons(period.preset);

  /* Preset buttons */
  panelEl.querySelectorAll('.kadr-preset-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const preset = btn.dataset.preset;
      if (preset === 'custom') {
        const cur = { from: fromEl?.value || period.from, to: toEl?.value || period.to, preset: 'custom' };
        _savePeriod(cur);
        _updatePresetButtons('custom');
        return;
      }
      const p = _presetToPeriod(preset);
      if (!p) return;
      if (fromEl) fromEl.value = p.from;
      if (toEl)   toEl.value   = p.to;
      _savePeriod({ ...p, preset });
      _updatePresetButtons(preset);
      _scheduleRecompute();
    });
  });

  /* Date pickers */
  const onDateChange = () => {
    clearTimeout(_dateDebounceTimer);
    _dateDebounceTimer = setTimeout(() => {
      let from = fromEl?.value || '';
      let to   = toEl?.value   || '';
      if (from && to && from > to) {
        [from, to] = [to, from];
        if (fromEl) fromEl.value = from;
        if (toEl)   toEl.value   = to;
        showToast('Datumi su zamenjeni jer je "Od" bio posle "Do"');
      }
      _savePeriod({ from, to, preset: 'custom' });
      _updatePresetButtons('custom');
      _scheduleRecompute();
    }, 300);
  };
  fromEl?.addEventListener('change', onDateChange);
  toEl?.addEventListener('change', onDateChange);

  /* Refresh button */
  panelEl.querySelector('#pregledRefresh')?.addEventListener('click', () => _scheduleRecompute(true));

  /* Search */
  searchEl?.addEventListener('input', () => {
    clearTimeout(_searchDebounceTimer);
    _searchDebounceTimer = setTimeout(() => {
      ssSet(SESSION_KEYS.KADR_ODSUSTVA_SEARCH, searchEl.value);
      _refreshTable();
    }, 150);
  });
  panelEl.querySelector('#pregledSearchClear')?.addEventListener('click', () => {
    if (searchEl) searchEl.value = '';
    ssSet(SESSION_KEYS.KADR_ODSUSTVA_SEARCH, '');
    _refreshTable();
  });

  /* Excel export */
  panelEl.querySelector('#pregledExport')?.addEventListener('click', () => {
    _exportXlsx().catch(err => {
      console.error('[pregled] xlsx error', err);
      showToast('Greska pri izvozu');
    });
  });

  /* Initial load */
  await _loadAndCompute(period.from, period.to);
}
