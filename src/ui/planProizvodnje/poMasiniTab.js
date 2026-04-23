/**
 * Plan Proizvodnje — TAB "Po mašini".
 *
 * Šef bira mašinu, vidi sve OTVORENE operacije zadužene za nju (originalno
 * iz BigTehn-a + REASSIGNED IN, minus REASSIGNED OUT, minus ZAVRŠENE u
 * BigTehn-u, minus arhivirane overlay-e). Može da:
 *   - drag-drop reorder (postavlja shift_sort_order)
 *   - klik na status pill cycle: waiting → in_progress → blocked → waiting
 *   - inline edit napomene (textarea, save na blur)
 *   - REASSIGN na drugu mašinu (dropdown u koloni "Mašina")
 *   - osvežavanje dugmetom (real-time je later, MVP koristi refresh)
 *
 * Read-only kada !canEditPlanProizvodnje() (npr. leadpm, hr, viewer).
 *
 * Public API:
 *   renderPoMasiniTab(host, { canEdit, onMachineChange, lastMachine })
 *   teardownPoMasiniTab()
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { formatDate } from '../../lib/date.js';
import {
  loadMachines,
  loadOperationsForMachine,
  loadAllOpenOperations,
  upsertOverlay,
  reorderOverlays,
  summarizeByMachine,
  STATUS_CYCLE_NEXT,
  rokUrgencyClass,
  formatSecondsHm,
  plannedSeconds,
} from '../../services/planProizvodnje.js';
import {
  sanitizeDrawingNo,
  isPlaceholderDrawingNo,
  findExistingDrawings,
  resolveBigtehnDrawing,
  signBigtehnDrawingsStoragePath,
} from '../../services/drawings.js';
import { openDrawingManager } from './drawingManager.js';
import { openTechProcedureModal } from './techProcedureModal.js';
import {
  MACHINE_GROUPS_ROW_1,
  MACHINE_GROUPS_ROW_2,
  countMachinesPerGroup,
  filterMachinesByGroup,
  getMachineGroup,
  machineGroupLabel,
  sortMachinesByGroupOrder,
} from '../../lib/machineGroups.js';

/* ── Local state (po instanci taba — postoji jedan u svakom trenutku) ── */
const STORAGE_KEY_LAST_MACHINE = 'plan-proizvodnje:last-machine';
const STORAGE_KEY_MACHINE_GROUP = 'plan-proizvodnje:machine-group';

/**
 * View modovi:
 *   'all-flat'      — chip "Sve": flat tabela svih otvorenih operacija
 *                     iz cele firme (loadAllOpenOperations).
 *   'group-cards'   — chip != 'Sve' i mašina nije izabrana: grid kartica
 *                     mašina iz grupe (svaka kartica = mašina + brojač
 *                     otvorenih operacija).
 *   'machine-table' — chip != 'Sve' i mašina izabrana (klikom na karticu):
 *                     tabela operacija te mašine (postojeće ponašanje).
 */
const state = {
  host: null,
  canEdit: false,
  machines: [],          /* [{rj_code, name, no_procedure, department_id}] */
  selectedMachine: null, /* string rj_code (samo kad je mode=machine-table) */
  selectedGroup: 'all',  /* chip-bar filter */
  mode: 'all-flat',      /* 'all-flat' | 'group-cards' | 'machine-table' */
  rows: [],              /* operacije (smisao zavisi od mode-a) */
  machineSummary: [],    /* summarizeByMachine(allOpen) — za kartice */
  loading: false,
  error: null,
  /* drag-drop */
  dragRowKey: null,
};

/* ── Public ── */

export async function renderPoMasiniTab(host, { canEdit }) {
  state.host = host;
  state.canEdit = !!canEdit;

  state.selectedGroup =
    localStorage.getItem(STORAGE_KEY_MACHINE_GROUP) || 'all';

  /* Default mode izvedeno iz selectedGroup-a; mašinu vraćamo iz LS-a samo
     ako će da se prikaže (group != 'all'). */
  if (state.selectedGroup === 'all') {
    state.mode = 'all-flat';
    state.selectedMachine = null;
  } else {
    state.selectedMachine =
      state.selectedMachine
      || localStorage.getItem(STORAGE_KEY_LAST_MACHINE)
      || null;
    state.mode = state.selectedMachine ? 'machine-table' : 'group-cards';
  }

  /* Inicijalni HTML — chip-bar (2 reda) + breadcrumb + body. Brojač
     "X operacija" stoji u desnom ćošku iznad svega (zajednički za sve
     mode-ove). */
  host.innerHTML = `
    <div class="mg-chipbar mg-chipbar-multi" id="ppGroupChipbar" role="tablist" aria-label="Filter mašina po grupi">
      <div class="mg-chipbar-rows">
        <div class="mg-chipbar-row" id="ppGroupChipbarRow1">
          <span class="pp-cell-muted">Učitavanje grupa…</span>
        </div>
        <div class="mg-chipbar-row" id="ppGroupChipbarRow2"></div>
      </div>
      <div class="mg-chipbar-meta">
        <span class="mg-ops-counter" id="ppOpsCounter">— operacija</span>
        ${state.canEdit ? '' : '<span class="pp-readonly-badge">🔒 Read-only</span>'}
      </div>
    </div>

    <div class="pp-subbar" id="ppSubbar">
      <div class="pp-breadcrumb" id="ppBreadcrumb"></div>
      <div class="pp-toolbar-spacer"></div>
      <button class="pp-refresh-btn" id="ppRefreshBtn" title="Osveži podatke">
        <span aria-hidden="true">↻</span> Osveži
      </button>
    </div>

    <div id="ppErrorBox"></div>

    <div class="pp-body-wrap" id="ppBodyWrap">
      <div class="pp-state">
        <div class="pp-state-icon">⏳</div>
        <div class="pp-state-title">Učitavanje mašina…</div>
      </div>
    </div>
  `;

  host.querySelector('#ppRefreshBtn').addEventListener('click', () => {
    if (state.loading) return;
    void refreshForMode({ force: true });
  });

  /* Učitaj mašine + (po potrebi) sve operacije za mode all-flat / kartice */
  await loadMachinesAndPrime();
}

export function teardownPoMasiniTab() {
  state.host = null;
  state.machines = [];
  state.rows = [];
  state.machineSummary = [];
  state.dragRowKey = null;
  state.error = null;
}

/* ── Mašine + chip-bar + render router ── */

async function loadMachinesAndPrime() {
  try {
    state.machines = await loadMachines();
  } catch (e) {
    console.error('[pp] loadMachines failed', e);
    state.machines = [];
    setError('Greška pri učitavanju mašina iz Supabase-a.');
  }

  if (state.machines.length === 0) {
    renderGroupChipbar();
    renderBreadcrumb();
    renderEmpty('Nijedna mašina nije pronađena u <code>bigtehn_machines_cache</code>.');
    setOpsCounter(0);
    return;
  }

  renderGroupChipbar();
  renderBreadcrumb();
  await refreshForMode();
}

/**
 * Refresh sadržaja po trenutnom mode-u. Force=true znači uvek povući svežu
 * porciju (ignoriši ev. cache).
 */
async function refreshForMode({ force = false } = {}) {
  if (state.mode === 'all-flat')      return refreshAllFlat({ force });
  if (state.mode === 'group-cards')   return refreshGroupCards({ force });
  if (state.mode === 'machine-table') return refreshMachineTable({ force });
}

async function refreshAllFlat() {
  state.loading = true;
  setError(null);
  setRefreshSpinner(true);
  try {
    const all = await loadAllOpenOperations();
    state.rows = Array.isArray(all) ? all : [];
    state.machineSummary = summarizeByMachine(state.rows);
    await annotateRowsWithPdfAvailability(state.rows);
  } catch (e) {
    console.error('[pp] loadAllOpenOperations failed', e);
    state.rows = [];
    state.machineSummary = [];
    setError('Greška pri učitavanju operacija (svih). Pogledaj konzolu (DevTools).');
  } finally {
    state.loading = false;
    setRefreshSpinner(false);
  }
  renderTable({ contextLabel: 'sve mašine' });
  setOpsCounter(state.rows.length);
}

async function refreshGroupCards({ force = false } = {}) {
  /* Za kartice nam treba summary po mašini iz svih otvorenih operacija.
     Ako smo u prethodnom koraku već povukli all (force=false i imamo
     summary) — preskoči mrežu. */
  state.loading = true;
  setError(null);
  setRefreshSpinner(true);
  try {
    if (force || !state.machineSummary.length) {
      const all = await loadAllOpenOperations();
      state.rows = Array.isArray(all) ? all : [];
      state.machineSummary = summarizeByMachine(state.rows);
    }
  } catch (e) {
    console.error('[pp] loadAllOpenOperations (cards) failed', e);
    state.machineSummary = [];
    setError('Greška pri učitavanju zauzetosti mašina.');
  } finally {
    state.loading = false;
    setRefreshSpinner(false);
  }
  renderGroupCards();
}

async function refreshMachineTable() {
  if (!state.selectedMachine) {
    /* Defenzivno — ako nema mašine, vrati se na kartice. */
    state.mode = 'group-cards';
    renderBreadcrumb();
    return refreshGroupCards();
  }
  state.loading = true;
  setError(null);
  setRefreshSpinner(true);
  try {
    state.rows = await loadOperationsForMachine(state.selectedMachine);
    await annotateRowsWithPdfAvailability(state.rows);
  } catch (e) {
    console.error('[pp] loadOperationsForMachine failed', e);
    state.rows = [];
    setError('Greška pri učitavanju operacija. Pogledaj konzolu (DevTools).');
  } finally {
    state.loading = false;
    setRefreshSpinner(false);
  }
  renderTable({ contextLabel: machineLabel(state.selectedMachine) });
  setOpsCounter(state.rows.length);
}

function machineLabel(rjCode) {
  const m = state.machines.find((x) => x.rj_code === rjCode);
  return m ? `${m.name} (${rjCode})` : rjCode;
}

/* ── Chip-bar (2 reda) ── */

function renderGroupChipbar() {
  renderChipbarRow(MACHINE_GROUPS_ROW_1, '#ppGroupChipbarRow1');
  renderChipbarRow(MACHINE_GROUPS_ROW_2, '#ppGroupChipbarRow2');
}

function renderChipbarRow(groups, sel) {
  const host = state.host?.querySelector(sel);
  if (!host) return;
  const counts = countMachinesPerGroup(state.machines);
  host.innerHTML = groups.map((g) => {
    const n = counts.get(g.id) || 0;
    const isActive = g.id === state.selectedGroup;
    return `
      <button type="button" role="tab"
              class="mg-chip${isActive ? ' is-active' : ''}"
              data-group-id="${escHtml(g.id)}"
              aria-selected="${isActive ? 'true' : 'false'}"
              title="${escHtml(g.label)} — ${n} mašina">
        ${escHtml(g.label)}<span class="mg-chip-count">${n}</span>
      </button>`;
  }).join('');
  host.querySelectorAll('button[data-group-id]').forEach((btn) => {
    btn.addEventListener('click', () => onSelectGroup(btn.dataset.groupId));
  });
}

function onSelectGroup(groupId) {
  if (!groupId || groupId === state.selectedGroup) return;
  state.selectedGroup = groupId;
  state.selectedMachine = null;
  try { localStorage.setItem(STORAGE_KEY_MACHINE_GROUP, groupId); }
  catch { /* SSR/private mode safe */ }
  state.mode = groupId === 'all' ? 'all-flat' : 'group-cards';
  renderGroupChipbar();
  renderBreadcrumb();
  void refreshForMode();
}

/* ── Breadcrumb ── */

function renderBreadcrumb() {
  const host = state.host?.querySelector('#ppBreadcrumb');
  if (!host) return;
  const groupLbl = machineGroupLabel(state.selectedGroup);
  if (state.mode === 'all-flat') {
    host.innerHTML = `<span class="pp-bc-current">📋 ${escHtml(groupLbl)} · sve operacije</span>`;
    return;
  }
  if (state.mode === 'group-cards') {
    host.innerHTML = `<span class="pp-bc-current">🛠 ${escHtml(groupLbl)} · izaberi mašinu</span>`;
    return;
  }
  /* machine-table */
  host.innerHTML = `
    <button type="button" class="pp-bc-link" id="ppBcBack" title="Nazad na listu mašina u grupi">
      ← ${escHtml(groupLbl)}
    </button>
    <span class="pp-bc-sep">›</span>
    <span class="pp-bc-current">${escHtml(machineLabel(state.selectedMachine))}</span>
  `;
  host.querySelector('#ppBcBack')?.addEventListener('click', () => {
    state.selectedMachine = null;
    state.rows = [];
    state.mode = 'group-cards';
    renderBreadcrumb();
    void refreshForMode();
  });
}

/* ── Kartice mašina (mode group-cards) ── */

function renderGroupCards() {
  const wrap = state.host?.querySelector('#ppBodyWrap');
  if (!wrap) return;
  const inGroup = sortMachinesByGroupOrder(
    filterMachinesByGroup(state.machines, state.selectedGroup),
  );
  if (inGroup.length === 0) {
    wrap.innerHTML = `
      <div class="pp-state">
        <div class="pp-state-icon">🛠</div>
        <div class="pp-state-title">Nema mašina u grupi „${escHtml(machineGroupLabel(state.selectedGroup))}"</div>
        <div class="pp-state-hint">Izaberi drugu grupu iz chip-bar-a.</div>
      </div>`;
    setOpsCounter(0);
    return;
  }
  /* Brojači po mašini iz machineSummary (ako je učitan); fallback 0. */
  const summaryByCode = new Map(
    (state.machineSummary || []).map((s) => [s.machineCode, s]),
  );
  let totalOps = 0;
  const cardsHtml = inGroup.map((m) => {
    const s = summaryByCode.get(m.rj_code);
    const ops = s?.totalOps || 0;
    const overdue = s?.overdueOps || 0;
    const today = s?.todayOps || 0;
    const soon = s?.soonOps || 0;
    totalOps += ops;
    const urgentBadges = [];
    if (overdue) urgentBadges.push(`<span class="pp-card-badge pp-badge-overdue" title="Kasni">${overdue}</span>`);
    if (today)   urgentBadges.push(`<span class="pp-card-badge pp-badge-today" title="Rok danas">${today}</span>`);
    if (soon)    urgentBadges.push(`<span class="pp-card-badge pp-badge-soon" title="Rok ≤3 dana">${soon}</span>`);
    return `
      <button type="button" class="pp-machine-card${ops === 0 ? ' is-empty' : ''}"
              data-machine="${escHtml(m.rj_code)}"
              title="${escHtml(m.name)} (${escHtml(m.rj_code)})">
        <div class="pp-card-head">
          <span class="pp-card-code">${escHtml(m.rj_code)}</span>
          ${m.no_procedure ? '<span class="pp-card-tag">no-proc</span>' : ''}
        </div>
        <div class="pp-card-name">${escHtml(m.name || '')}</div>
        <div class="pp-card-foot">
          <span class="pp-card-ops"><strong>${ops}</strong> ${plural(ops, 'operacija', 'operacije', 'operacija')}</span>
          <span class="pp-card-badges">${urgentBadges.join('')}</span>
        </div>
      </button>`;
  }).join('');
  wrap.innerHTML = `<div class="pp-machine-grid">${cardsHtml}</div>`;
  wrap.querySelectorAll('button[data-machine]').forEach((btn) => {
    btn.addEventListener('click', () => onPickMachine(btn.dataset.machine));
  });
  /* "X operacija" za grupu = suma operacija po mašinama u grupi. */
  setOpsCounter(totalOps);
}

function onPickMachine(rjCode) {
  if (!rjCode) return;
  state.selectedMachine = rjCode;
  try { localStorage.setItem(STORAGE_KEY_LAST_MACHINE, rjCode); }
  catch { /* ignore */ }
  state.mode = 'machine-table';
  renderBreadcrumb();
  void refreshForMode();
}

function renderEmpty(htmlMsg) {
  const wrap = state.host?.querySelector('#ppBodyWrap');
  if (!wrap) return;
  wrap.innerHTML = `
    <div class="pp-state">
      <div class="pp-state-icon">🛠</div>
      <div class="pp-state-title">Nema operacija za prikaz</div>
      <div class="pp-state-hint">${htmlMsg}</div>
    </div>`;
}

/* ── Operacije: anotacija PDF availability (deli mode all-flat i machine-table) ── */

async function annotateRowsWithPdfAvailability(rows) {
  if (!Array.isArray(rows) || rows.length === 0) return;
  const sanitizedList = rows
    .map(r => sanitizeDrawingNo(r.broj_crteza))
    .filter(Boolean);
  if (sanitizedList.length === 0) {
    rows.forEach(r => { r._hasPdf = false; });
    return;
  }
  let existing;
  try {
    existing = await findExistingDrawings(sanitizedList);
  } catch (e) {
    console.warn('[pp] findExistingDrawings failed → fail-open (prikazuje PDF dugme svuda)', e);
    rows.forEach(r => {
      r._hasPdf = !isPlaceholderDrawingNo(r.broj_crteza);
    });
    return;
  }
  for (const r of rows) {
    const san = sanitizeDrawingNo(r.broj_crteza);
    r._hasPdf = !!san && existing.has(san);
  }
}

function renderTable({ contextLabel = '' } = {}) {
  const wrap = state.host?.querySelector('#ppBodyWrap');
  if (!wrap) return;

  if (state.rows.length === 0) {
    const msg = state.mode === 'all-flat'
      ? 'Trenutno nema otvorenih operacija u celoj firmi (ili Bridge još nije sinhronizovao podatke).'
      : `Sve operacije za ${escHtml(contextLabel || 'ovu mašinu')} su završene ili još nisu kreirane u BigTehn-u.<br>Pokušaj <strong>Osveži</strong> ili izaberi drugu mašinu.`;
    renderEmpty(msg);
    return;
  }

  /* NAPOMENA o vidljivim kolonama (po dogovoru sa korisnikom):
   *  - „Op" i „Opis" su SAKRIVENI iz glavne tabele (više mesta za ostale).
   *    Te informacije su i dalje dostupne u 📋 Tehnološki postupak modalu
   *    (tamo se ne dira ništa).
   *  - „Kupac" ima `min-width: 140px` (CSS) da se ne wrap-uje u 3 reda.
   *  - „Crtež" prikazuje broj u prvom redu i klikabilnu 📄 ikonu ispod
   *    (u drugom redu) — vidi `pp-drawing-cell` blok u rowHtml.
   */
  /* U mode "all-flat" drag-drop nema smisla (mešali bi se RN-ovi različitih
     mašina), pa se onemogući. Takođe sortiramo po roku da bude pregledno. */
  const allowDrag = state.canEdit && state.mode === 'machine-table';
  const rowsToRender = state.mode === 'all-flat'
    ? state.rows.slice().sort((a, b) => {
        /* overdue najpre, onda najraniji rok, pa po RN identbroju */
        const ra = a.rok_izrade ? Date.parse(a.rok_izrade) : 8.64e15;
        const rb = b.rok_izrade ? Date.parse(b.rok_izrade) : 8.64e15;
        if (ra !== rb) return ra - rb;
        return String(a.rn_ident_broj || '').localeCompare(String(b.rn_ident_broj || ''), 'sr', { numeric: true });
      })
    : state.rows;

  wrap.innerHTML = `
    <div class="pp-table-wrap">
      <table class="pp-table" data-readonly="${allowDrag ? 'false' : 'true'}">
        <thead>
          <tr>
            ${allowDrag ? '<th title="Drag-drop redosled" style="width:28px"></th>' : '<th style="width:0;padding:0"></th>'}
            <th title="Prioritet (drag-drop)" style="width:48px">Pri</th>
            <th>RN</th>
            <th>Crtež</th>
            <th>Deo</th>
            <th class="pp-col-customer">Kupac</th>
            <th>Rok</th>
            <th class="pp-cell-num" title="Urađeno / Ukupno komada">Done / Plan</th>
            <th class="pp-cell-num" title="Tehnološko / Stvarno vreme">T / R</th>
            <th>Status</th>
            <th style="min-width:200px">Šefova napomena</th>
            <th title="Skice / slike">📎</th>
            <th>Mašina</th>
          </tr>
        </thead>
        <tbody>
          ${rowsToRender.map((r) => rowHtml(r, { allowDrag })).join('')}
        </tbody>
      </table>
    </div>
  `;

  wireRows(wrap);
}

function rowKey(r) {
  return `${r.work_order_id}-${r.line_id}`;
}

function rowHtml(r, opts = {}) {
  const allowDrag = opts.allowDrag !== false && state.canEdit;
  const urgency = rokUrgencyClass(r.rok_izrade);
  const rokLabel = r.rok_izrade ? formatDate(r.rok_izrade) : '—';
  const status = r.local_status || 'waiting';
  const planSec = plannedSeconds(r);
  const isReassigned = !!r.assigned_machine_code
    && r.assigned_machine_code !== r.original_machine_code;
  const customerLabel =
    r.customer_short || r.customer_name || (r.customer_id ? `#${r.customer_id}` : '—');

  /* Broj crteža: BigTehn često ima garbage/dirty vrednosti (`.`, `..`,
     `1109245.` sa trailing tačkom itd.). Sanitizujemo za prikaz, a
     `_hasPdf` (set u `annotateRowsWithPdfAvailability` posle učitavanja)
     odlučuje da li uopšte prikazati 📄 PDF dugme. Tako korisnik vidi
     dugme SAMO za crteže koji realno imaju PDF u Bridge keš-u. */
  const brojRaw = r.broj_crteza || '';
  const brojSan = sanitizeDrawingNo(brojRaw);
  const showPdfBtn = !!r._hasPdf;
  const brojDisplay = brojSan || (brojRaw && brojRaw.trim() ? brojRaw : '—');
  const brojTooltip = brojSan && brojSan !== brojRaw.trim()
    ? `${brojSan} (BigTehn: "${brojRaw}")`
    : brojDisplay;

  const noteVal = r.shift_note || '';
  const noteId = `note-${r.work_order_id}-${r.line_id}`;

  const sortVal = r.shift_sort_order;
  const priCell = sortVal != null
    ? `<span class="pp-pri">${escHtml(String(sortVal))}</span>`
    : `<span class="pp-pri is-empty" title="Nije rangirano">–</span>`;

  /* F.5c: HITNE pozicije — overdue (kasni) i today (rok je danas) dobijaju
     crveni leftborder, suptilno crveni background i ⚠ ikonu pre prioriteta.
     ⚠ je pravi DOM <span> sa title/aria-label (ranije je bio CSS ::before
     pseudo-element, koji ne prima tooltip — bug fix). */
  const isUrgent = (urgency === 'overdue' || urgency === 'today');
  const urgentClass = isUrgent
    ? (urgency === 'overdue' ? ' is-urgent is-urgent-overdue' : ' is-urgent is-urgent-today')
    : '';
  const urgentTitle = urgency === 'overdue'
    ? `Rok je istekao (${rokLabel}) — hitno!`
    : urgency === 'today'
      ? `Rok je danas (${rokLabel})!`
      : '';
  const urgentBadgeHtml = isUrgent
    ? `<span class="pp-urgent-badge ${urgency === 'overdue' ? 'pp-urgent-overdue' : 'pp-urgent-today'}" title="${escHtml(urgentTitle)}" aria-label="${escHtml(urgentTitle)}">⚠</span>`
    : '';

  return `
    <tr
      data-key="${escHtml(rowKey(r))}"
      data-wo="${r.work_order_id}"
      data-line="${r.line_id}"
      class="${r.is_non_machining ? 'is-non-machining' : ''}${isReassigned ? ' is-reassigned' : ''}${urgentClass}"
      ${allowDrag ? 'draggable="true"' : ''}>
      ${allowDrag
        ? `<td class="pp-drag-handle" title="Prevuci za prioritet">⠿</td>`
        : '<td style="width:0;padding:0"></td>'}
      <td class="pp-cell-center">${urgentBadgeHtml}${priCell}</td>
      <td class="pp-cell-strong" title="RN ${escHtml(r.rn_ident_broj || '')}">
        ${escHtml(r.rn_ident_broj || '—')}
        <button type="button"
                class="pp-tech-procedure-btn"
                data-action="open-tech-procedure"
                title="Otvori kompletan tehnološki postupak ovog RN-a">📋</button>
      </td>
      <td class="pp-cell-muted pp-cell-drawing" title="${escHtml(brojTooltip)}">
        <div class="pp-drawing-cell">
          <span class="pp-drawing-no">${escHtml(brojDisplay)}</span>
          ${showPdfBtn
            ? `<button type="button"
                       class="pp-drawing-pdf-icon"
                       data-action="open-bigtehn-drawing"
                       data-broj="${escHtml(brojSan)}"
                       data-broj-raw="${escHtml(brojRaw)}"
                       title="Otvori PDF crtež ${escHtml(brojSan)} u novom tab-u">
                 📄 PDF
               </button>`
            : ''}
        </div>
      </td>
      <td class="pp-cell-clip" title="${escHtml(r.naziv_dela || '')}">${escHtml(r.naziv_dela || '—')}</td>
      <td class="pp-cell-muted pp-col-customer" title="${escHtml(r.customer_name || '')}">${escHtml(customerLabel)}</td>
      <td>
        <span class="pp-rok urgency-${urgency || 'none'}" title="${rokLabel}">
          ${escHtml(rokLabel)}
        </span>
      </td>
      <td class="pp-cell-num">
        <span class="pp-cell-strong">${escHtml(String(r.komada_done ?? 0))}</span>
        <span class="pp-cell-muted"> / ${escHtml(String(r.komada_total ?? 0))}</span>
      </td>
      <td class="pp-cell-num pp-cell-muted" title="Tehnološko / Stvarno vreme">
        ${escHtml(formatSecondsHm(planSec))}
        <span class="pp-cell-sep">/</span>
        <span style="color:#86efac">${escHtml(formatSecondsHm(r.real_seconds))}</span>
      </td>
      <td>
        <button type="button"
                class="pp-status s-${status}"
                data-action="cycle-status"
                ${state.canEdit ? '' : 'disabled'}
                title="${state.canEdit ? 'Klikni za sledeći status' : 'Edit dostupan samo za pm/admin'}">
          ${statusLabel(status)}
        </button>
      </td>
      <td>
        <textarea
          id="${noteId}"
          class="pp-note-input"
          rows="1"
          placeholder="${state.canEdit ? 'Napomena…' : '—'}"
          data-action="edit-note"
          ${state.canEdit ? '' : 'disabled'}>${escHtml(noteVal)}</textarea>
        <span class="pp-note-saved" data-saved-for="${noteId}">✓ sačuvano</span>
      </td>
      <td class="pp-cell-center">
        <button type="button"
                class="pp-drawings-btn ${(r.drawings_count || 0) > 0 ? 'has-files' : ''}"
                data-action="open-drawings"
                title="${(r.drawings_count || 0) > 0
                  ? `Pogledaj ${r.drawings_count} skic${r.drawings_count === 1 ? 'u' : 'a'}`
                  : (state.canEdit ? 'Dodaj skicu/sliku' : 'Nema skica')}">
          📎 <span class="pp-drawings-num">${r.drawings_count || 0}</span>
        </button>
      </td>
      <td>
        <div class="pp-machine-cell">
          <span class="pp-machine-current ${isReassigned ? 'is-reassigned' : ''}"
                title="${isReassigned ? 'REASSIGNED iz BigTehn-a' : 'Originalna mašina iz BigTehn-a'}">
            ${escHtml(r.assigned_machine_code || r.original_machine_code || '—')}
          </span>
          ${isReassigned
            ? `<span class="pp-machine-original is-overridden" title="Originalno iz BigTehn-a">
                 (orig: ${escHtml(r.original_machine_code || '—')})
               </span>`
            : ''}
          <button type="button"
                  class="pp-reassign-btn"
                  data-action="reassign-open"
                  ${state.canEdit ? '' : 'disabled'}>
            ${isReassigned ? '↩ Vrati na original' : '⇄ Premesti'}
          </button>
        </div>
      </td>
    </tr>
  `;
}

function statusLabel(s) {
  switch (s) {
    case 'waiting':     return 'Čeka';
    case 'in_progress': return 'U radu';
    case 'blocked':     return 'Blokirano';
    case 'completed':   return 'Završeno';
    default:            return s;
  }
}

/* ── Wire događaji u tabeli ── */

function wireRows(wrap) {
  /* Status cycle */
  wrap.querySelectorAll('button[data-action="cycle-status"]').forEach(btn => {
    btn.addEventListener('click', () => onCycleStatus(btn));
  });

  /* Note save na blur */
  wrap.querySelectorAll('textarea[data-action="edit-note"]').forEach(ta => {
    let originalVal = ta.value;
    ta.addEventListener('focus', () => { originalVal = ta.value; });
    ta.addEventListener('blur',  () => onSaveNote(ta, originalVal));
  });

  /* REASSIGN */
  wrap.querySelectorAll('button[data-action="reassign-open"]').forEach(btn => {
    btn.addEventListener('click', () => onReassign(btn));
  });

  /* Drawings (📎) */
  wrap.querySelectorAll('button[data-action="open-drawings"]').forEach(btn => {
    btn.addEventListener('click', () => onOpenDrawings(btn));
  });

  /* BigTehn PDF crtež (📄) — otvori u novom tab-u */
  wrap.querySelectorAll('button[data-action="open-bigtehn-drawing"]').forEach(btn => {
    btn.addEventListener('click', () => onOpenBigtehnDrawing(btn));
  });

  /* Tehnološki postupak (📋) — otvori modal sa svim operacijama */
  wrap.querySelectorAll('button[data-action="open-tech-procedure"]').forEach(btn => {
    btn.addEventListener('click', () => onOpenTechProcedure(btn));
  });

  /* Drag-drop */
  if (state.canEdit) {
    wireDragDrop(wrap);
  }
}

async function onOpenDrawings(btn) {
  const tr = btn.closest('tr');
  if (!tr) return;
  const woId   = Number(tr.dataset.wo);
  const lineId = Number(tr.dataset.line);
  const row = state.rows.find(r => r.work_order_id === woId && r.line_id === lineId);
  if (!row) return;

  const opTitle =
    `RN ${row.rn_ident_broj || '?'} · op ${row.operacija || '?'} · ${row.naziv_dela || ''}`.trim();

  await openDrawingManager({
    work_order_id: woId,
    line_id:       lineId,
    opTitle,
    canEdit:       state.canEdit,
    onChange:      (newCount) => {
      /* Optimistic UI ažuriranje brojača bez full reload-a */
      row.drawings_count = newCount;
      const numEl = btn.querySelector('.pp-drawings-num');
      if (numEl) numEl.textContent = String(newCount);
      btn.classList.toggle('has-files', newCount > 0);
      btn.title = newCount > 0
        ? `Pogledaj ${newCount} skic${newCount === 1 ? 'u' : 'a'}`
        : (state.canEdit ? 'Dodaj skicu/sliku' : 'Nema skica');
    },
  });
}

/**
 * Klik na 📄 kod broja crteža → otvori PDF iz BigTehn-a u novom tab-u.
 *
 * Pop-up blocker workaround: prvo otvorimo prazan window u user-gesture
 * sinhrono, pa async fetch-ujemo signed URL i postavimo location na otvoreni
 * window. Ako fetch ne uspe, zatvori window i prikaži toast.
 */
async function onOpenBigtehnDrawing(btn) {
  const brojRaw = btn.dataset.brojRaw || '';
  const broj = (btn.dataset.broj && sanitizeDrawingNo(btn.dataset.broj)) || sanitizeDrawingNo(brojRaw) || btn.dataset.broj;
  if (!broj) return;
  console.log('[pp-pdf] klik', { broj, brojRaw: brojRaw || undefined, ver: typeof __APP_VERSION__ !== 'undefined' ? __APP_VERSION__ : '?' });
  const tab = window.open('about:blank', '_blank');
  if (!tab) {
    showToast('Pop-up blokiran. Dozvoli pop-up za ovaj sajt.');
    return;
  }
  try {
    const resolved = await resolveBigtehnDrawing(broj);
    console.log('[pp-pdf] resolve', { broj, ok: !!resolved?.storagePath, path: resolved?.storagePath });
    if (!resolved?.storagePath) {
      tab.close();
      const cleaned = brojRaw && brojRaw.trim() !== broj
        ? ` (BigTehn: "${brojRaw}", traženo: "${broj}")`
        : '';
      showToast(
        `PDF crtež "${broj}"${cleaned} nije u Bridge keš-u. ` +
        `Pokreni Bridge sync ili proveri da li PDF postoji u PDM-u.`,
      );
      return;
    }
    const url = await signBigtehnDrawingsStoragePath(resolved.storagePath);
    console.log('[pp-pdf] sign', { ok: !!url });
    if (!url) {
      tab.close();
      showToast(
        'Storage nije mogao da potpiše PDF (proveri da si prijavljen, ili prava na bucket bigtehn-drawings). ' +
        'U konzoli (F12) uključi sve nivoe poruka i traži: pp-pdf ili drawings.sign',
      );
      return;
    }
    tab.location.href = url;
  } catch (e) {
    tab.close();
    showToast('Greška pri otvaranju PDF-a.');
    console.error('[onOpenBigtehnDrawing]', e);
  }
}

/**
 * Klik na 📋 pored RN-a → modal sa kompletnim tehnološkim postupkom
 * (sve operacije + sve prijave radnika za taj RN).
 */
async function onOpenTechProcedure(btn) {
  const tr = btn.closest('tr');
  if (!tr) return;
  const woId = Number(tr.dataset.wo);
  const lineId = Number(tr.dataset.line);
  const row = state.rows.find(r => r.work_order_id === woId && r.line_id === lineId);
  const opTitle = row
    ? `RN ${row.rn_ident_broj || '?'} · ${row.naziv_dela || ''}`.trim()
    : `RN #${woId}`;
  await openTechProcedureModal({ work_order_id: woId, opTitle });
}

/* ── Status cycle ── */

async function onCycleStatus(btn) {
  if (!state.canEdit) return;
  const tr = btn.closest('tr');
  const woId = Number(tr?.dataset.wo);
  const lineId = Number(tr?.dataset.line);
  const row = state.rows.find(r => r.work_order_id === woId && r.line_id === lineId);
  if (!row) return;

  const cur = row.local_status || 'waiting';
  const next = STATUS_CYCLE_NEXT[cur] || 'waiting';

  /* Optimistic UI */
  btn.disabled = true;
  const prevClass = btn.className;
  btn.className = `pp-status s-${next}`;
  btn.textContent = statusLabel(next);

  const res = await upsertOverlay({
    work_order_id: woId,
    line_id: lineId,
    patch: { local_status: next },
  });

  if (res === null) {
    /* Revert na grešci */
    btn.className = prevClass;
    btn.textContent = statusLabel(cur);
    btn.disabled = false;
    showToast('⚠ Status nije sačuvan (proveri konekciju ili rolu)');
    return;
  }

  row.local_status = next;
  btn.disabled = false;
}

/* ── Napomena ── */

async function onSaveNote(ta, originalVal) {
  if (!state.canEdit) return;
  const newVal = ta.value;
  if (newVal === originalVal) return; /* nije izmenjeno */
  const tr = ta.closest('tr');
  const woId = Number(tr?.dataset.wo);
  const lineId = Number(tr?.dataset.line);
  const row = state.rows.find(r => r.work_order_id === woId && r.line_id === lineId);
  if (!row) return;

  ta.disabled = true;
  const res = await upsertOverlay({
    work_order_id: woId,
    line_id: lineId,
    patch: { shift_note: newVal },
  });
  ta.disabled = false;

  if (res === null) {
    ta.value = originalVal;
    showToast('⚠ Napomena nije sačuvana');
    return;
  }
  row.shift_note = newVal;

  /* Mali "✓ sačuvano" indikator pored polja */
  const indicator = ta.parentElement.querySelector('.pp-note-saved');
  if (indicator) {
    indicator.classList.add('is-visible');
    setTimeout(() => indicator.classList.remove('is-visible'), 1400);
  }
}

/* ── REASSIGN ── */

async function onReassign(btn) {
  if (!state.canEdit) return;
  const tr = btn.closest('tr');
  const woId = Number(tr?.dataset.wo);
  const lineId = Number(tr?.dataset.line);
  const row = state.rows.find(r => r.work_order_id === woId && r.line_id === lineId);
  if (!row) return;

  /* Ako je već REASSIGNED → klik znači "vrati na original" */
  const isReassigned = !!row.assigned_machine_code
    && row.assigned_machine_code !== row.original_machine_code;
  if (isReassigned) {
    btn.disabled = true;
    const res = await upsertOverlay({
      work_order_id: woId,
      line_id: lineId,
      patch: { assigned_machine_code: null },
    });
    btn.disabled = false;
    if (res === null) {
      showToast('⚠ Vraćanje na originalnu mašinu nije uspelo');
      return;
    }
    showToast('✓ Vraćeno na originalnu mašinu — operacija će nestati iz ove liste');
    /* Operacija sada ne pripada izabranoj mašini → refresh */
    void refreshForMode({ force: true });
    return;
  }

  /* Prikazi inline select */
  const cell = tr.querySelector('.pp-machine-cell');
  if (!cell) return;
  if (cell.querySelector('.pp-reassign-select')) return; /* već otvoren */

  const select = document.createElement('select');
  select.className = 'pp-reassign-select';
  select.innerHTML = `
    <option value="">— izaberi mašinu —</option>
    ${state.machines
      .filter(m => m.rj_code !== row.original_machine_code)
      .map(m => `<option value="${escHtml(m.rj_code)}">${escHtml(m.name)} (${escHtml(m.rj_code)})</option>`)
      .join('')}
  `;
  cell.appendChild(select);
  select.focus();

  select.addEventListener('change', async () => {
    const newMachine = select.value || null;
    select.disabled = true;
    if (!newMachine) {
      select.remove();
      return;
    }
    const res = await upsertOverlay({
      work_order_id: woId,
      line_id: lineId,
      patch: { assigned_machine_code: newMachine },
    });
    select.disabled = false;
    if (res === null) {
      showToast('⚠ Premestanje nije uspelo');
      select.remove();
      return;
    }
    showToast(`✓ Operacija premeštena na ${newMachine}`);
    /* Operacija sada pripada drugoj mašini → nestaje iz trenutne liste */
    void refreshForMode({ force: true });
  });
  /* Click anywhere else cancels */
  select.addEventListener('blur', () => {
    /* Mali timeout da change uhvati prvi */
    setTimeout(() => select.parentElement && select.remove(), 150);
  });
}

/* ── Drag-drop reorder ── */

function wireDragDrop(wrap) {
  const tbody = wrap.querySelector('tbody');
  if (!tbody) return;

  tbody.addEventListener('dragstart', e => {
    const tr = e.target.closest('tr[draggable="true"]');
    if (!tr) return;
    state.dragRowKey = tr.dataset.key;
    tr.classList.add('is-dragging');
    e.dataTransfer.effectAllowed = 'move';
    /* Firefox kompat: postaviti dataTransfer */
    e.dataTransfer.setData('text/plain', state.dragRowKey);
  });

  tbody.addEventListener('dragend', () => {
    tbody.querySelectorAll('tr.is-dragging').forEach(t => t.classList.remove('is-dragging'));
    tbody.querySelectorAll('.drop-target-above,.drop-target-below').forEach(t => {
      t.classList.remove('drop-target-above', 'drop-target-below');
    });
    state.dragRowKey = null;
  });

  tbody.addEventListener('dragover', e => {
    if (!state.dragRowKey) return;
    const tr = e.target.closest('tr');
    if (!tr || tr.dataset.key === state.dragRowKey) return;
    e.preventDefault();
    /* Markiraj iznad ili ispod (zavisno od kursora) */
    tbody.querySelectorAll('.drop-target-above,.drop-target-below').forEach(t => {
      t.classList.remove('drop-target-above', 'drop-target-below');
    });
    const rect = tr.getBoundingClientRect();
    const mid = rect.top + rect.height / 2;
    if (e.clientY < mid) tr.classList.add('drop-target-above');
    else                 tr.classList.add('drop-target-below');
  });

  tbody.addEventListener('drop', async e => {
    e.preventDefault();
    if (!state.dragRowKey) return;
    const targetTr = e.target.closest('tr');
    if (!targetTr || targetTr.dataset.key === state.dragRowKey) {
      state.dragRowKey = null;
      return;
    }

    const draggedKey = state.dragRowKey;
    state.dragRowKey = null;

    const before = targetTr.classList.contains('drop-target-above');
    tbody.querySelectorAll('.drop-target-above,.drop-target-below').forEach(t => {
      t.classList.remove('drop-target-above', 'drop-target-below');
    });

    /* Promeni state.rows i pošalji bulk update */
    const fromIdx = state.rows.findIndex(r => rowKey(r) === draggedKey);
    let toIdx = state.rows.findIndex(r => rowKey(r) === targetTr.dataset.key);
    if (fromIdx === -1 || toIdx === -1) return;
    if (!before) toIdx += 1;
    /* Ako pomeramo dole, indeks se pomera za 1 jer je pomeren element izvađen */
    if (fromIdx < toIdx) toIdx -= 1;

    const arr = state.rows.slice();
    const [moved] = arr.splice(fromIdx, 1);
    arr.splice(toIdx, 0, moved);
    state.rows = arr;

    /* Optimistic re-render */
    renderTable();

    /* Pošalji bulk reorder */
    const res = await reorderOverlays(
      state.rows.map(r => ({ work_order_id: r.work_order_id, line_id: r.line_id })),
    );
    if (res === null) {
      showToast('⚠ Redosled nije sačuvan — osvežavam');
      void refreshForMode({ force: true });
      return;
    }
    /* Sinhronizuj sort vrednosti u state-u */
    state.rows.forEach((r, i) => { r.shift_sort_order = i + 1; });
    renderTable();
  });
}

/* ── Toolbar helpers ── */

function setOpsCounter(n) {
  const el = state.host?.querySelector('#ppOpsCounter');
  if (!el) return;
  if (n == null) el.textContent = '— operacija';
  else el.textContent = `${n} ${plural(n, 'operacija', 'operacije', 'operacija')}`;
}

function plural(n, one, two, more) {
  const m10 = n % 10;
  const m100 = n % 100;
  if (m10 === 1 && m100 !== 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return two;
  return more;
}

function setError(msg) {
  state.error = msg || null;
  const box = state.host?.querySelector('#ppErrorBox');
  if (!box) return;
  box.innerHTML = msg ? `<div class="pp-error">⚠ ${escHtml(msg)}</div>` : '';
}

function setRefreshSpinner(on) {
  const btn = state.host?.querySelector('#ppRefreshBtn');
  if (!btn) return;
  btn.disabled = !!on;
  btn.querySelector('span').textContent = on ? '↻' : '↻';
  if (on) btn.querySelector('span').classList.add('pp-spin');
  else    btn.querySelector('span').classList.remove('pp-spin');
}
