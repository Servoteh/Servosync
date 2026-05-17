/**
 * Lokacije delova — shell modula (dashboard, lokacije, stavke, sync).
 * SQL: sql/migrations/add_loc_module.sql
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { toggleTheme } from '../../lib/theme.js';
import {
  getLocationKind,
  getLocationKindLabel,
  getLocationTypeLabel,
} from '../../lib/lokacijeTypes.js';
import { logout } from '../../services/auth.js';
import { getAuth, canViewLokacijeSync, isAdmin, canEdit } from '../../state/auth.js';
import {
  loadLokacijeTabFromStorage,
  loadPredmetStateFromStorage,
  setLokacijeActiveTab,
  getLokacijeUiState,
  setBrowseFilter,
  setBrowseKindFilter,
  setBrowseHallId,
  setItemsFilter,
  setItemsPage,
  setItemsPageSize,
  setHistoryFilters,
  resetHistoryFilters,
  setHistoryPage,
  setHistoryPageSize,
  setReportFilters,
  resetReportFilters,
  setReportPage,
  setReportPageSize,
  toggleReportSort,
} from '../../state/lokacije.js';
import { filterLocationsHierarchical } from '../../lib/lokacijeFilters.js';
import { rowsToCsv, CSV_BOM } from '../../lib/csv.js';
import {
  fetchAllMovements,
  fetchAllPlacements,
  fetchLocations,
  fetchMovementsHistory,
  fetchPlacements,
  fetchRecentMovements,
  fetchSyncOutboundEvents,
  fetchLocReportPartsByLocations,
  fetchAllLocReportPartsByLocations,
  fetchBridgeSyncStatus,
  fetchLocSyncHealthSummary,
  fetchLocationDefinitionsAudit,
  fetchMovementsCountSince,
  fetchBigtehnIngestStatus,
  setBigtehnIngestArmed,
  runBigtehnIngestNow,
} from '../../services/lokacije.js';
import { loadUsersFromDb } from '../../services/users.js';
import { hasSupabaseConfig } from '../../services/supabase.js';
import {
  openItemHistoryModal,
  openLocationModal,
  openNewLocationModal,
  openQuickMoveModal,
  toggleLocationActive,
} from './modals.js';
import { openScanMoveModal } from './scanModal.js';
import {
  openShelfLabelsPrintPicker,
  openTechProcessLabelPrintModal,
  printTechProcessLabelWindow,
  barcodeForPlacementRow,
} from './labelsPrint.js';
import { renderPredmetTab } from './predmetTab.js';
import { renderLabelsPrintPage, resetLabelsPrintPageState } from './labelsPrintPage.js';
import { openTechProcedureModal } from '../planProizvodnje/techProcedureModal.js';

/* Jeftina provera može li kamera — bez uvoza barcode modula (koji vuče ZXing).
 * Barcode.js ima istu logiku; držimo je singleton-level za bundle splitting. */
function canUseCamera() {
  return (
    typeof navigator !== 'undefined' &&
    !!navigator.mediaDevices?.getUserMedia
  );
}

/* Ikone su semantički vezane za svaki tab — isti emoji set kao u Quick-action
 * karticama (Početna) i toolbar dugmadima, da kroz ceo modul postoji
 * dosledan vizuelni jezik. Ako se kasnije pređe na SVG, samo se ovde menja.
 * `type: 'group'` znači dropdown trigger sa `items` listom — sub-tabovi
 * zadržavaju iste `id` vrednosti kao da su flat (state, deep-link, history). */
const TABS = [
  { id: 'dashboard', label: 'Početna', icon: '🏠' },
  { id: 'predmet', label: 'Pregled predmeta', icon: '👁' },
  { id: 'browse', label: 'Lokacije', icon: '📍' },
  { id: 'items', label: 'Stavke', icon: '📦' },
  { id: 'report', label: 'Pregled po lokacijama', icon: '📊' },
  { id: 'labels', label: 'Štampa nalepnica', icon: '🏷' },
  {
    type: 'group',
    id: 'more',
    label: 'Više',
    icon: '⋯',
    items: [
      { id: 'definitions', label: 'Istorija definicija', icon: '🕘', manageOnly: true },
      { id: 'history', label: 'Istorija premeštanja', icon: '🔄' },
      { id: 'sync', label: 'Sync', icon: '🔁', adminOnly: true },
    ],
  },
];

const MOVEMENT_TYPE_LABELS = {
  INITIAL_PLACEMENT: 'Prvo zaduženje',
  TRANSFER: 'Premeštanje',
  RETURN: 'Povrat',
  INVENTORY_ADJUSTMENT: 'Inventar',
  REMOVAL: 'Uklonjeno',
};

/* CSS klase za type pills u „Poslednja premeštanja" tabeli — boje
 * preuzete iz postojećih status tokena (--status-done/-prog/-hold itd.). */
const MOVEMENT_TYPE_PILL = {
  INITIAL_PLACEMENT: 'loc-mov-pill--initial',
  TRANSFER: 'loc-mov-pill--move',
  RETURN: 'loc-mov-pill--return',
  INVENTORY_ADJUSTMENT: 'loc-mov-pill--inv',
  REMOVAL: 'loc-mov-pill--remove',
};

function movementTypePillClass(type) {
  return MOVEMENT_TYPE_PILL[type] || 'loc-mov-pill--other';
}

/**
 * Kartice NALEPNICA POLICE / NALEPNICA TP — isti sadržaj kao na Početnoj i u toolbar-u
 * (`locBtnLabels`, `locBtnTpLabel`) da `attachLocToolbar()` veže jedan skup handlera.
 * @returns {Array<{ id: string, icon: string, title: string, sub: string, primary?: boolean }>}
 */
function locLabelPrintActionCardDefs() {
  if (!canEdit()) return [];
  return [
    { id: 'locBtnLabels', icon: '🏷', title: 'NALEPNICA POLICE', sub: 'QR za regal' },
    { id: 'locBtnTpLabel', icon: '🧾', title: 'NALEPNICA TP', sub: 'Štampa za predmet' },
  ];
}

/** HTML za grid samo ove dve kartice (prazan ako nema prava). */
function locLabelPrintActionGridHtml() {
  const inner = locLabelPrintActionCardDefs()
    .map(
      c => `<button type="button" class="loc-action-card" id="${escHtml(c.id)}">
        <span class="loc-action-card-icon" aria-hidden="true">${c.icon}</span>
        <span class="loc-action-card-body">
          <span class="loc-action-card-title">${escHtml(c.title)}</span>
          <span class="loc-action-card-sub">${escHtml(c.sub)}</span>
        </span>
      </button>`,
    )
    .join('');
  if (!inner) return '';
  return `<div class="loc-action-grid" role="group" aria-label="Štampa nalepnica">${inner}</div>`;
}

/* Cache user-a (id → prikaz) — rekešira se pri svakom mount-u, ali ne per-render. */
let historyUsersCache = null;

let mountRef = null;
/** @type {HTMLElement|null} */
let locPanelHost = null;
/* Härd-4 (H11): disposers za document/window listenere koje registruje
 * `wireTabs`. `teardownLokacijeModule` ih izvršava, sprečavajući kumulaciju
 * pri SPA re-mount-u modula (povratak iz drugog hub-a u Lokacije). */
/** @type {Array<() => void>} */
let _lokDisposers = [];
/* UI state van state/lokacije.js jer je striktno vezan za trenutni mount. */
let showInactiveLocations = false;
/** @type {'table'|'tree'} */
let browseViewMode = 'table';

/**
 * Sync worker zdravstveni banner (Härd-3).
 *
 * Renderuje se na dashboard tabu paralelno sa `renderBridgeStaleBanner`. Prikazuje:
 *  - Crveno upozorenje ako bilo koji worker nije slao heartbeat duže od 10 min
 *    (`is_alive=false` iz `loc_sync_health_summary`).
 *  - Žuto upozorenje ako u `loc_sync_outbound_events` ima DEAD_LETTER stavki
 *    (sync događaja koji nisu stigli MSSQL strani posle 10 retry pokušaja).
 *  - Prazan string ako je sve OK ili migracija `add_loc_sync_health_monitor`
 *    još nije primenjena (`fetchLocSyncHealthSummary` tada vraća `{0, []}`).
 *
 * @param {{ dead_letter_count: number, workers: Array<{ worker_id: string, last_seen: string, age_seconds: number, is_alive: boolean }> }} summary
 */
function renderSyncWorkerBanner(summary) {
  if (!summary || typeof summary !== 'object') return '';
  const workers = Array.isArray(summary.workers) ? summary.workers : [];
  const deadCount = Number(summary.dead_letter_count) || 0;
  const downWorkers = workers.filter(w => w && w.is_alive === false);

  if (downWorkers.length === 0 && deadCount === 0) return '';

  const parts = [];
  if (downWorkers.length > 0) {
    const lines = downWorkers.map(w => {
      const ageMin = Math.round(Number(w.age_seconds) / 60);
      const ageStr = ageMin >= 60 ? `${Math.round(ageMin / 60)} h` : `${ageMin} min`;
      return `<li><strong>${escHtml(String(w.worker_id))}</strong> — heartbeat pre ${escHtml(ageStr)}</li>`;
    }).join('');
    parts.push(
      `<div style="margin-bottom:6px"><strong>Sync worker ne radi</strong> — premeštanja se i dalje beleže u Supabase, ali NE idu MSSQL strani dok worker ne bude restartovan.</div>`,
      `<ul style="margin:0 0 0 18px">${lines}</ul>`,
    );
  }
  if (deadCount > 0) {
    if (parts.length) parts.push('<div style="margin-top:8px"></div>');
    parts.push(
      `<div><strong>DEAD_LETTER:</strong> ${escHtml(String(deadCount))} sync događaja nije stiglo do MSSQL-a posle 10 pokušaja worker-a. Admin treba da pregleda <code>loc_sync_outbound_events</code> u Supabase Studio-u.</div>`,
    );
  }

  /* Klasa `loc-warn` se koristi i u BRIDGE banner-u — vizuelno usklađeno. */
  return `
    <div class="loc-warn" role="status" aria-live="polite" style="margin:8px 0">
      ${parts.join('')}
    </div>`;
}

/**
 * Banner upozorenje ako su BigTehn cache tabele zastarele.
 * Prag je 24h za work_orders/lines/tech_routing (sync na 15min) i 7 dana za
 * drawings (foto-sinhronizacija je rede). Ako je sve sveže — vraća prazan string.
 *
 * @param {Array<{ sync_job: string, last_finished: string }>} statusList
 */
function renderBridgeStaleBanner(statusList) {
  if (!Array.isArray(statusList) || !statusList.length) return '';
  const now = Date.now();
  const thresholds = {
    production_work_orders: 6 * 3600 * 1000,
    production_work_order_lines: 6 * 3600 * 1000,
    production_tech_routing: 6 * 3600 * 1000,
    catalog_items: 36 * 3600 * 1000,
    production_bigtehn_drawings: 7 * 24 * 3600 * 1000,
  };
  const labels = {
    production_work_orders: 'Radni nalozi',
    production_work_order_lines: 'Linije RN',
    production_tech_routing: 'Tehnološki postupci',
    catalog_items: 'Predmeti',
    production_bigtehn_drawings: 'Crteži (PDF)',
  };
  const stale = [];
  for (const it of statusList) {
    const limit = thresholds[it.sync_job];
    if (!limit) continue;
    const t = it.last_finished ? Date.parse(it.last_finished) : NaN;
    if (!Number.isFinite(t)) continue;
    const ageMs = now - t;
    if (ageMs > limit) {
      const days = Math.round(ageMs / (24 * 3600 * 1000));
      const hours = Math.round(ageMs / (3600 * 1000));
      const ageStr = days >= 1 ? `${days} dan${days === 1 ? '' : 'a'}` : `${hours} h`;
      stale.push(`<li><strong>${escHtml(labels[it.sync_job])}</strong> — poslednji sync pre ${escHtml(ageStr)}</li>`);
    }
  }
  if (!stale.length) return '';
  return `
    <div class="loc-warn" role="status" aria-live="polite" style="margin:8px 0">
      <div><strong>BRIDGE sync upozorenje</strong> — neki BigTehn cache nije svež. Pretrage RN/TP/predmeta i kolone u „Pregled” oslanjaju se na ove tabele.</div>
      <ul style="margin:6px 0 0 18px">${stale.join('')}</ul>
    </div>`;
}

/**
 * Quick-action grid za Početni tab (zameni `locToolbarHtml` samo na Početnoj —
 * ostali tabovi i dalje koriste običan toolbar). Koristi iste ID-jeve kao
 * toolbar, pa `attachLocToolbar()` može da veže iste click handler-e bez
 * dupliranja koda. Svaka kartica = velika action sa ikonom + naslovom +
 * podnaslovom; SKENIRAJ je primary (akcentovan).
 */
function locDashboardActionsHtml() {
  const cards = [];
  if (canUseCamera()) {
    cards.push({
      id: 'locBtnScanMove',
      icon: '📷',
      title: 'SKENIRAJ',
      sub: 'Premeštaj barkodom',
      primary: true,
    });
  }
  cards.push({
    id: 'locBtnQuickMove',
    icon: '🔀',
    title: 'BRZO PREMEŠTANJE',
    sub: 'Ručni unos',
  });
  if (canEdit()) {
    cards.push({
      id: 'locBtnNewLoc',
      icon: '📍',
      title: 'NOVA LOKACIJA',
      sub: 'Definiši mesto',
    });
    cards.push(...locLabelPrintActionCardDefs());
  }
  const inner = cards
    .map(
      c => `<button type="button" class="loc-action-card${c.primary ? ' is-primary' : ''}" id="${escHtml(c.id)}">
        <span class="loc-action-card-icon" aria-hidden="true">${c.icon}</span>
        <span class="loc-action-card-body">
          <span class="loc-action-card-title">${escHtml(c.title)}</span>
          <span class="loc-action-card-sub">${escHtml(c.sub)}</span>
        </span>
      </button>`,
    )
    .join('');
  return `<div class="loc-action-grid" role="group" aria-label="Brze akcije">${inner}</div>`;
}

function locToolbarHtml({ extra = '' } = {}) {
  const parts = [];
  if (canUseCamera()) {
    parts.push(
      `<button type="button" class="btn btn-primary" id="locBtnScanMove" title="Skeniraj barkod telefonom">📷 Skeniraj</button>`,
    );
  }
  parts.push(
    `<button type="button" class="btn" id="locBtnQuickMove">Brzo premeštanje</button>`,
  );
  /* "Predmet" je sad pun tab (vidi `TABS`), ne dugme. Pretraga po crtežu je
   * deo Predmet taba (filter „Broj crteža"). Globalna pretraga radnih naloga
   * (`openWorkOrderLookupModal`) ostaje u kodu kao dostupna utility funkcija
   * — može da zatreba kasnije, ali se više ne ekspanira u toolbar-u. */
  if (canEdit()) {
    parts.push(`<button type="button" class="btn" id="locBtnNewLoc">Nova lokacija</button>`);
    parts.push(
      `<button type="button" class="btn" id="locBtnLabels" title="Izaberi policu i štampaj nalepnicu (podrazumevano QR: LP…)">🏷 Nalepnica police</button>`,
    );
    parts.push(
      `<button type="button" class="btn" id="locBtnTpLabel" title="Štampa nalepnice za tehnološki postupak (RNZ / kratki barkod)">🏷 Nalepnica TP</button>`,
    );
  }
  if (extra) parts.push(extra);
  return `<div class="loc-toolbar">${parts.join('')}</div>`;
}

function attachLocToolbar() {
  const host = locPanelHost;
  if (!host) return;
  host.querySelector('#locBtnScanMove')?.addEventListener('click', () => {
    openScanMoveModal({ onSuccess: refreshLocPanel });
  });
  host.querySelector('#locBtnQuickMove')?.addEventListener('click', () => {
    openQuickMoveModal({ onSuccess: refreshLocPanel });
  });
  host.querySelector('#locBtnNewLoc')?.addEventListener('click', () => {
    openNewLocationModal({ onSuccess: refreshLocPanel });
  });
  host.querySelector('#locBtnLabels')?.addEventListener('click', () => {
    openShelfLabelsPrintPicker();
  });
  host.querySelector('#locBtnTpLabel')?.addEventListener('click', () => {
    openTechProcessLabelPrintModal();
  });
  const showInactiveCb = host.querySelector('#locBrowseShowInactive');
  if (showInactiveCb) {
    showInactiveCb.addEventListener('change', () => {
      showInactiveLocations = !!showInactiveCb.checked;
      refreshLocPanel();
    });
  }
}

/**
 * Veže click handlere za Edit/Toggle dugmad u browse tabu.
 * @param {object[]|null} locs
 */
function attachBrowseActions(locs) {
  const host = locPanelHost;
  if (!host || !Array.isArray(locs)) return;
  const byId = new Map(locs.map(l => [String(l.id), l]));

  host.querySelectorAll('[data-loc-edit]').forEach(btn => {
    btn.addEventListener('click', () => {
      const row = byId.get(btn.getAttribute('data-loc-edit') || '');
      if (!row) return;
      openLocationModal({ existing: row, onSuccess: refreshLocPanel });
    });
  });

  host.querySelectorAll('[data-loc-toggle]').forEach(btn => {
    btn.addEventListener('click', () => {
      const row = byId.get(btn.getAttribute('data-loc-toggle') || '');
      if (!row) return;
      toggleLocationActive(row, { onSuccess: refreshLocPanel });
    });
  });
}

/**
 * Render klasične tabele lokacija. Koristi `depth` za indentaciju.
 * @param {object[]|null} locs
 * @param {boolean} canEditLocs
 */
function renderLocationsTableHtml(locs, canEditLocs) {
  const colspan = canEditLocs ? 6 : 5;
  const rows = Array.isArray(locs)
    ? locs
        .map(r => {
          const d = Math.max(0, Math.min(Number(r.depth) || 0, 12));
          const pad = 10 + d * 14;
          const inactiveCls = r.is_active ? '' : ' loc-row-inactive';
          const businessType = getLocationKindLabel(r.location_type);
          const techType = getLocationTypeLabel(r.location_type);
          const actions = canEditLocs
            ? `<td class="loc-actions-cell">
                <button type="button" class="btn btn-xs" data-loc-edit="${escHtml(String(r.id))}">Izmeni</button>
                <button type="button" class="btn btn-xs" data-loc-toggle="${escHtml(String(r.id))}">${r.is_active ? 'Deaktiviraj' : 'Aktiviraj'}</button>
              </td>`
            : '';
          return `<tr class="${inactiveCls}"><td class="loc-code-cell" style="padding-left:${pad}px">${escHtml(r.location_code || '')}</td><td>${escHtml(r.name || '')}</td><td><span class="loc-kind-pill">${escHtml(businessType)}</span></td><td>${escHtml(techType)} <span class="loc-muted">(${escHtml(r.location_type || '')})</span></td><td class="loc-path">${escHtml(r.path_cached || '')}</td>${actions}</tr>`;
        })
        .join('')
      : '';
  const headActions = canEditLocs ? '<th>Akcije</th>' : '';
  return `
    <div class="loc-table-wrap">
      <table class="loc-table">
        <thead><tr><th>Šifra</th><th>Naziv</th><th>Poslovno</th><th>Tehnički tip</th><th>Putanja</th>${headActions}</tr></thead>
        <tbody>${rows || `<tr><td colspan="${colspan}" class="loc-muted">Nema lokacija. Unos master lokacija (admin/LeadPM/PM/menadžment) dolazi iz UI ili SQL.</td></tr>`}</tbody>
      </table>
    </div>`;
}

/**
 * Render hijerarhijskog stabla preko <details>/<summary>.
 * @param {object[]|null} locs flat lista (očekuje `parent_id`, `depth`)
 * @param {boolean} canEditLocs
 */
function renderLocationsTreeHtml(locs, canEditLocs) {
  if (!Array.isArray(locs) || locs.length === 0) {
    return `<p class="loc-muted" style="padding:16px 0">Nema lokacija za prikaz.</p>`;
  }
  const childrenByParent = new Map();
  for (const l of locs) {
    const k = l.parent_id || '__root__';
    if (!childrenByParent.has(k)) childrenByParent.set(k, []);
    childrenByParent.get(k).push(l);
  }

  const renderNode = node => {
    const kids = childrenByParent.get(node.id) || [];
    const code = escHtml(node.location_code || '');
    const name = escHtml(node.name || '');
    const type = escHtml(getLocationKindLabel(node.location_type));
    const techType = escHtml(node.location_type || '');
    const inactive = node.is_active ? '' : ' loc-tree-inactive';
    const actions = canEditLocs
      ? `<span class="loc-tree-actions">
          <button type="button" class="btn btn-xs" data-loc-edit="${escHtml(String(node.id))}">Izmeni</button>
          <button type="button" class="btn btn-xs" data-loc-toggle="${escHtml(String(node.id))}">${node.is_active ? 'Deaktiviraj' : 'Aktiviraj'}</button>
        </span>`
      : '';
    const head = `<span class="loc-tree-code">${code}</span>
      <span class="loc-tree-name">${name}</span>
      <span class="loc-tree-type">${type} · ${techType}</span>
      ${actions}`;

    if (kids.length === 0) {
      return `<li class="loc-tree-leaf${inactive}"><span class="loc-tree-bullet" aria-hidden="true">·</span>${head}</li>`;
    }
    /* open atribut za root nivo i 1. nivo, ostalo skupljeno. */
    const openAttr = (node.depth || 0) < 1 ? ' open' : '';
    return `<li class="loc-tree-node${inactive}">
      <details${openAttr}>
        <summary>${head}</summary>
        <ul class="loc-tree">${kids.map(renderNode).join('')}</ul>
      </details>
    </li>`;
  };

  const roots = childrenByParent.get('__root__') || [];
  return `<ul class="loc-tree loc-tree-root">${roots.map(renderNode).join('')}</ul>`;
}

function filterLocationsByKindHierarchical(locs, kind) {
  if (!Array.isArray(locs)) return [];
  if (!kind) return locs.slice();
  const byId = new Map(locs.map(l => [l.id, l]));
  const keep = new Set();
  for (const loc of locs) {
    if (getLocationKind(loc.location_type) !== kind) continue;
    let cur = loc;
    while (cur && !keep.has(cur.id)) {
      keep.add(cur.id);
      cur = cur.parent_id ? byId.get(cur.parent_id) : null;
    }
  }
  return locs.filter(l => keep.has(l.id));
}

/**
 * Suzi listu lokacija na izabranu HALU i sve njene potomke (rekurzivno).
 * Sama HALA ostaje u rezultatu da operater zna „odakle gleda".
 *
 * @param {Array<object>} locs flat lista
 * @param {string} hallId UUID lokacije tipa HALA; prazno = bez filtera
 * @returns {Array<object>}
 */
function filterLocationsBySubtree(locs, hallId) {
  if (!Array.isArray(locs)) return [];
  if (!hallId) return locs.slice();
  const childrenByParent = new Map();
  for (const l of locs) {
    const k = l.parent_id || '__root__';
    if (!childrenByParent.has(k)) childrenByParent.set(k, []);
    childrenByParent.get(k).push(l);
  }
  const keep = new Set();
  const stack = [hallId];
  while (stack.length) {
    const id = stack.pop();
    if (keep.has(id)) continue;
    keep.add(id);
    const kids = childrenByParent.get(id) || [];
    for (const k of kids) stack.push(k.id);
  }
  return locs.filter(l => keep.has(l.id));
}

/**
 * Sortira siblinge A-Z po `location_code` (natural — „A.10" posle „A.9"),
 * čuvajući redosled na nivou stabla. Rezultat je nova flat lista
 * gde su prvo svi root-ovi (po code-u), pa za svaki root njegova deca
 * rekurzivno — odgovara redosledu koji `renderLocationsTreeHtml` koristi
 * kroz `parent_id`/`depth`, ali sa naturalnim A-Z sort-om umesto
 * `path_cached`-a (koji slovi „R-A-10" pre „R-A-9").
 *
 * @param {Array<object>} locs flat lista
 * @returns {Array<object>}
 */
function sortLocationsAZNatural(locs) {
  if (!Array.isArray(locs) || locs.length === 0) return [];
  const childrenByParent = new Map();
  for (const l of locs) {
    const k = l.parent_id || '__root__';
    if (!childrenByParent.has(k)) childrenByParent.set(k, []);
    childrenByParent.get(k).push(l);
  }
  const cmp = (a, b) =>
    String(a.location_code || '').localeCompare(
      String(b.location_code || ''),
      undefined,
      { numeric: true, sensitivity: 'base' },
    );
  for (const arr of childrenByParent.values()) arr.sort(cmp);

  const result = [];
  const visit = node => {
    result.push(node);
    const kids = childrenByParent.get(node.id) || [];
    for (const k of kids) visit(k);
  };
  const roots = childrenByParent.get('__root__') || [];
  for (const r of roots) visit(r);
  return result;
}

function attachBrowseViewSwitch() {
  const host = locPanelHost;
  if (!host) return;
  host.querySelectorAll('[data-loc-view]').forEach(btn => {
    btn.addEventListener('click', () => {
      const mode = btn.getAttribute('data-loc-view');
      if (mode !== 'tree' && mode !== 'table') return;
      if (mode === browseViewMode) return;
      browseViewMode = mode;
      refreshLocPanel();
    });
  });
}

/**
 * Pretraga u browse tabu — debounced input + klijentski filter.
 * Debounce 180ms je dovoljan da se re-render ne pokreće na svakom pritisku tastera.
 */
function attachBrowseSearch() {
  const host = locPanelHost;
  if (!host) return;
  const input = host.querySelector('#locBrowseSearch');
  const kindSel = host.querySelector('#locBrowseKind');
  const hallSel = host.querySelector('#locBrowseHall');
  kindSel?.addEventListener('change', () => {
    setBrowseKindFilter(kindSel.value || '');
    refreshLocPanel();
  });
  hallSel?.addEventListener('change', () => {
    setBrowseHallId(hallSel.value || '');
    refreshLocPanel();
  });
  if (!input) return;
  let t = null;
  input.addEventListener('input', () => {
    clearTimeout(t);
    t = setTimeout(() => {
      setBrowseFilter(input.value);
      refreshLocPanel();
    }, 180);
  });
  /* Zadrži fokus posle refresh-a. */
  input.focus();
  input.setSelectionRange(input.value.length, input.value.length);
}

/**
 * Server-side pretraga u items tabu — šalje ILIKE upit nad `item_ref_id`/`item_ref_table`
 * celokupne `loc_item_placements`. Debounce 300ms zbog network trip-a.
 */
function attachReportTabHandlers() {
  const host = locPanelHost;
  if (!host) return;

  host.querySelector('#locRepApply')?.addEventListener('click', () => {
    setReportFilters({
      drawingNo: host.querySelector('#locRepDraw')?.value || '',
      orderNo: host.querySelector('#locRepOrder')?.value || '',
      tpNo: host.querySelector('#locRepTp')?.value || '',
      projectSearch: host.querySelector('#locRepProj')?.value || '',
      locationId: host.querySelector('#locRepLoc')?.value || '',
      locationQ: host.querySelector('#locRepLocQ')?.value || '',
    });
    refreshLocPanel();
  });

  host.querySelector('#locRepReset')?.addEventListener('click', () => {
    resetReportFilters();
    refreshLocPanel();
  });

  host.querySelector('#locRepLoc')?.addEventListener('change', e => {
    setReportFilters({ locationId: e.target.value });
    refreshLocPanel();
  });

  host.querySelectorAll('[data-report-sort]').forEach(btn => {
    btn.addEventListener('click', () => {
      const col = btn.getAttribute('data-report-sort');
      if (!col) return;
      toggleReportSort(col);
      refreshLocPanel();
    });
  });

  host.querySelector('#locRepPrev')?.addEventListener('click', () => {
    const { reportPage } = getLokacijeUiState();
    if (reportPage > 0) {
      setReportPage(reportPage - 1);
      refreshLocPanel();
    }
  });
  host.querySelector('#locRepNext')?.addEventListener('click', () => {
    const { reportPage } = getLokacijeUiState();
    setReportPage(reportPage + 1);
    refreshLocPanel();
  });
  host.querySelector('#locRepPageSize')?.addEventListener('change', e => {
    setReportPageSize(Number(e.target.value));
    refreshLocPanel();
  });

  host.querySelectorAll('[data-rep-item-table]').forEach(tr => {
    tr.addEventListener('click', ev => {
      if (ev.target.closest('button')) return;
      const itemRefTable = tr.getAttribute('data-rep-item-table') || '';
      const itemRefId = tr.getAttribute('data-rep-item-id') || '';
      const orderNo = tr.getAttribute('data-rep-order') || '';
      openItemHistoryModal({ itemRefTable, itemRefId, orderNo });
    });
  });

  host.querySelectorAll('[data-rep-open-tp]').forEach(btn => {
    btn.addEventListener('click', ev => {
      ev.stopPropagation();
      const id = Number(btn.getAttribute('data-wo-id'));
      if (Number.isFinite(id)) {
        void openTechProcedureModal({ work_order_id: id });
      }
    });
  });

  host.querySelectorAll('[data-rep-print-tp]').forEach(btn => {
    btn.addEventListener('click', ev => {
      ev.stopPropagation();
      const tr = btn.closest('tr');
      if (!tr) return;
      const p = {
        item_ref_table: tr.getAttribute('data-rep-item-table') || '',
        item_ref_id: tr.getAttribute('data-rep-item-id') || '',
        order_no: tr.getAttribute('data-rep-order') || '',
        drawing_no: tr.getAttribute('data-rep-drawing') || '',
      };
      const bc = barcodeForPlacementRow(p);
      if (!bc) {
        alert('Za ovaj red nema prepoznatljivog barkoda (RNZ / kratki format).');
        return;
      }
      const ident = p.order_no && p.item_ref_id
        ? `${p.order_no}/${p.item_ref_id}`
        : p.order_no || '';
      const today = new Date();
      const pad = n => String(n).padStart(2, '0');
      const datum = `${pad(today.getDate())}-${pad(today.getMonth() + 1)}-${String(today.getFullYear()).slice(-2)}`;
      const qty = tr.getAttribute('data-rep-qty') || '';
      const komRn = tr.getAttribute('data-rep-komrn') || '';
      const kolicinaStr = qty && komRn ? `${qty}/${komRn}` : qty || komRn || '';
      void printTechProcessLabelWindow({
        fields: {
          brojPredmeta: ident,
          komitent: tr.getAttribute('data-rep-customer') || '',
          nazivPredmeta: tr.getAttribute('data-rep-pname') || '',
          nazivDela: tr.getAttribute('data-rep-naziv') || '',
          brojCrteza: p.drawing_no,
          kolicina: kolicinaStr,
          materijal: tr.getAttribute('data-rep-materijal') || '',
          datum,
        },
        barcodeValue: bc,
      });
    });
  });

  const btnEx = host.querySelector('#locRepExport');
  if (btnEx) {
    btnEx.addEventListener('click', async () => {
      const orig = btnEx.textContent || 'Export CSV';
      btnEx.disabled = true;
      btnEx.textContent = 'Export… 0';
      try {
        const ui = getLokacijeUiState();
        const rf = ui.reportFilters;
        const { rows, total, truncated } = await fetchAllLocReportPartsByLocations(
          {
            drawingNo: rf.drawingNo,
            orderNo: rf.orderNo,
            tpNo: rf.tpNo,
            projectSearch: rf.projectSearch,
            locationId: rf.locationId || undefined,
            locationQ: rf.locationQ,
            sort: ui.reportSort,
            desc: ui.reportSortDesc,
          },
          {
            pageSize: 500,
            onProgress: ({ loaded, total: tot }) => {
              btnEx.textContent = tot != null ? `Export… ${loaded}/${tot}` : `Export… ${loaded}`;
            },
          },
        );
        if (!rows.length) {
          alert('Nema redova za export.');
          return;
        }
        const headers = [
          'Predmet kod',
          'Predmet naziv',
          'Kupac',
          'RN',
          'Crtež',
          'Naziv dela',
          'Materijal',
          'Dimenzija materijala',
          'Komada (RN)',
          'Težina obr (kg)',
          'Revizija',
          'Status RN',
          'Rok izrade',
          'TP ref',
          'Tabela',
          'Lokacija šifra',
          'Lokacija naziv',
          'Putanja',
          'Opis police',
          'Kol lok',
          'Ukupno bucket',
          'Status placement',
          'Poslednje',
        ];
        const data = rows.map(r => [
          r.project_code || '',
          r.project_name || '',
          r.customer_name || '',
          r.order_no || '',
          r.drawing_no || r.wo_broj_crteza || '',
          r.naziv_dela || '',
          r.materijal || '',
          r.dimenzija_materijala || '',
          r.komada_rn ?? '',
          r.tezina_obr ?? '',
          r.revizija || '',
          r.status_rn === true ? 'Zatvoren' : r.status_rn === false ? 'Otvoren' : '',
          r.rok_izrade ? String(r.rok_izrade).slice(0, 10) : '',
          r.item_ref_id || '',
          r.item_ref_table || '',
          r.location_code || '',
          r.location_name || '',
          r.location_path || '',
          r.shelf_note || '',
          r.qty_on_location ?? '',
          r.qty_total_for_bucket ?? '',
          r.placement_status || '',
          (r.last_moved_at || r.updated_at || '').replace('T', ' ').slice(0, 19),
        ]);
        const csv = CSV_BOM + rowsToCsv(headers, data);
        downloadCsv(csv, buildReportExportFilename());
        if (truncated) {
          alert(
            `Export prekinut na 50 000 redova. Ukupno u upitu: ${total ?? '?'}. Suzi filtere.`,
          );
        }
      } catch (err) {
        console.error('[lokacije/report] CSV export failed', err);
        alert(`Export neuspešan: ${err?.message || err}`);
      } finally {
        btnEx.disabled = false;
        btnEx.textContent = orig;
      }
    });
  }
}

function buildReportExportFilename() {
  const now = new Date();
  const pad = n => String(n).padStart(2, '0');
  const ts =
    `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}` +
    `_${pad(now.getHours())}${pad(now.getMinutes())}`;
  return `lokacije_pregled_po_lokacijama_${ts}.csv`;
}

function attachItemsSearch() {
  const host = locPanelHost;
  if (!host) return;
  const input = host.querySelector('#locItemsSearch');
  if (!input) return;
  let t = null;
  input.addEventListener('input', () => {
    clearTimeout(t);
    t = setTimeout(() => {
      setItemsFilter(input.value);
      refreshLocPanel();
    }, 300);
  });
  input.focus();
  input.setSelectionRange(input.value.length, input.value.length);
}

/**
 * HTML za paginator (items / report tab).
 * @param {{ page: number, pageSize: number, total: number|null, loadedCount: number, idPrefix?: string, ariaLabel?: string }} p
 */
function renderLocPagerHtml({
  page,
  pageSize,
  total,
  loadedCount,
  idPrefix = 'locItems',
  ariaLabel = 'Paginacija',
}) {
  const from = total === 0 ? 0 : page * pageSize + 1;
  const to = page * pageSize + loadedCount;
  const totalLabel = total == null ? '?' : String(total);
  const isLast = total != null ? to >= total : loadedCount < pageSize;
  const rangeLabel = total === 0 ? '0–0' : `${from}–${to}`;

  const sizeOpts = [25, 50, 100, 250]
    .map(n => `<option value="${n}"${n === pageSize ? ' selected' : ''}>${n}</option>`)
    .join('');

  return `
    <div class="loc-pager" role="navigation" aria-label="${escHtml(ariaLabel)}">
      <div class="loc-pager-info">
        <span>${rangeLabel} od ${escHtml(totalLabel)}</span>
      </div>
      <div class="loc-pager-controls">
        <label class="loc-pager-size">
          <span>Po stranici:</span>
          <select id="${escHtml(idPrefix)}PageSize">${sizeOpts}</select>
        </label>
        <button type="button" class="btn btn-xs" id="${escHtml(idPrefix)}Prev" ${page === 0 ? 'disabled' : ''}>← Prethodna</button>
        <button type="button" class="btn btn-xs" id="${escHtml(idPrefix)}Next" ${isLast ? 'disabled' : ''}>Sledeća →</button>
      </div>
    </div>`;
}

/** @param {Parameters<typeof renderLocPagerHtml>[0]} p */
function renderItemsPager(p) {
  return renderLocPagerHtml({ ...p, idPrefix: 'locItems', ariaLabel: 'Paginacija stavki' });
}

function attachItemsPager() {
  const host = locPanelHost;
  if (!host) return;
  host.querySelector('#locItemsPrev')?.addEventListener('click', () => {
    const { itemsPage } = getLokacijeUiState();
    if (itemsPage > 0) {
      setItemsPage(itemsPage - 1);
      refreshLocPanel();
    }
  });
  host.querySelector('#locItemsNext')?.addEventListener('click', () => {
    const { itemsPage } = getLokacijeUiState();
    setItemsPage(itemsPage + 1);
    refreshLocPanel();
  });
  const sizeSel = host.querySelector('#locItemsPageSize');
  if (sizeSel) {
    sizeSel.addEventListener('change', () => {
      setItemsPageSize(Number(sizeSel.value));
      refreshLocPanel();
    });
  }
}

/**
 * Export celog trenutno filtriranog skupa placements u CSV (stream-ovan u batch-ovima).
 * Šalje `Content-Range` count=exact u prvom batch-u da bi progress prikaz imao tačan total.
 */
function attachItemsExport() {
  const host = locPanelHost;
  if (!host) return;
  const btn = host.querySelector('#locItemsExport');
  if (!btn) return;

  btn.addEventListener('click', async () => {
    const origLabel = btn.textContent || 'Export CSV';
    btn.disabled = true;
    btn.textContent = 'Export… 0';
    try {
      const ui = getLokacijeUiState();
      /* Lokacije trebaju samo radi resolve code/name/path — nezavisno od filtera. */
      const [{ rows: placements, total, truncated }, locs] = await Promise.all([
        fetchAllPlacements({
          search: ui.itemsFilter,
          pageSize: 500,
          onProgress: ({ loaded, total }) => {
            btn.textContent = total != null
              ? `Export… ${loaded}/${total}`
              : `Export… ${loaded}`;
          },
        }),
        fetchLocations({ activeOnly: false }),
      ]);

      if (!Array.isArray(placements) || placements.length === 0) {
        alert('Nema stavki koje odgovaraju trenutnoj pretrazi.');
        return;
      }

      const locIdx = locationIndex(locs);
      const headers = [
        'Nalog',
        'Tehnološki postupak (TP)',
        'Crtež',
        'Polica_kod',
        'Hala_kod',
        'Hala_naziv',
        'Tip_reda',
        'Putanja lokacije',
        'Količina',
        'Status',
        'Napomena',
        'Premeštena u',
        'Poslednja izmena',
      ];
      const dataRows = placements.map(p => {
        const loc = locIdx.get(p.location_id) || {};
        const par = loc.parent_id ? locIdx.get(String(loc.parent_id)) || {} : {};
        const tpVal =
          String(p.item_ref_table || '').toLowerCase() === 'bigtehn_rn'
            ? p.item_ref_id || ''
            : '';
        return [
          p.order_no || '',
          tpVal,
          p.drawing_no || '',
          loc.location_code || '',
          par.location_code || '',
          par.name || '',
          p.item_ref_table || '',
          loc.path_cached || '',
          p.quantity == null ? '' : p.quantity,
          p.placement_status || '',
          p.notes || '',
          p.placed_at || '',
          p.updated_at || '',
        ];
      });

      const csv = CSV_BOM + rowsToCsv(headers, dataRows);
      downloadCsv(csv, buildExportFilename(ui.itemsFilter));

      if (truncated) {
        alert(
          `Export prekinut na 50 000 zapisa radi sigurnosti. Ukupno u bazi: ${total ?? '?'}. ` +
            `Suzi pretragu za kompletniji izvoz.`,
        );
      }
    } catch (err) {
      console.error('[lokacije] CSV export failed', err);
      alert(`Export neuspešan: ${err?.message || err}`);
    } finally {
      btn.disabled = false;
      btn.textContent = origLabel;
    }
  });
}

/**
 * @param {string} search
 * @returns {string} — sanitizovano ime fajla sa timestampom
 */
function buildExportFilename(search) {
  const now = new Date();
  const pad = n => String(n).padStart(2, '0');
  const ts =
    `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}` +
    `_${pad(now.getHours())}${pad(now.getMinutes())}`;
  const q = (search || '').trim().toLowerCase().replace(/[^a-z0-9_-]+/g, '_').slice(0, 32);
  const suffix = q ? `_${q}` : '';
  return `lokacije_stavke_${ts}${suffix}.csv`;
}

/**
 * @param {string} text — CSV sadržaj (uključujući BOM)
 * @param {string} filename
 */
function downloadCsv(text, filename) {
  const blob = new Blob([text], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.style.display = 'none';
  document.body.appendChild(a);
  a.click();
  setTimeout(() => {
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }, 100);
}

/** Klik po redu u `items` tabu → istorija premeštanja tog (crtež, nalog) bucketa. */
function attachItemsActions() {
  const host = locPanelHost;
  if (!host) return;
  host.querySelectorAll('[data-loc-item-table]').forEach(tr => {
    tr.addEventListener('click', () => {
      const itemRefTable = tr.getAttribute('data-loc-item-table') || '';
      const itemRefId = tr.getAttribute('data-loc-item-id') || '';
      /* data-loc-item-order sadrži `''` za "bez naloga" — razlikujemo od
       * "svi nalozi" (undefined). Ovde uvek prosleđujemo string. */
      const orderNo = tr.getAttribute('data-loc-item-order') || '';
      openItemHistoryModal({ itemRefTable, itemRefId, orderNo });
    });
  });
}

async function refreshLocPanel() {
  if (!locPanelHost) return;
  await renderPanel(locPanelHost, getLokacijeUiState().activeTab);
}

/** @param {object[]|null|undefined} locs */
function locationIndex(locs) {
  const m = new Map();
  if (!Array.isArray(locs)) return m;
  for (const l of locs) {
    if (l?.id) m.set(l.id, l);
  }
  return m;
}

/** Prikaz lokacije u tabu Stavke: POLICA − šifra roditeljske hale (<code>parent_id</code> → <code>loc_locations</code>). */
function formatPlacementLocationHtml(loc, locIdx) {
  if (!loc) return '';
  const sc = escHtml(loc.location_code || '');
  const sn = loc.name ? escHtml(loc.name) : '';
  const pid = loc.parent_id ? String(loc.parent_id) : '';
  const parent = pid ? locIdx.get(pid) : null;
  if (parent) {
    const hallCode =
      parent.location_code != null && String(parent.location_code).trim()
        ? escHtml(String(parent.location_code).trim())
        : escHtml(pid.slice(0, 8)) + '…';
    const pn = parent.name ? escHtml(String(parent.name)) : '';
    return `<span class="loc-code-strong">${sc}</span><span class="loc-muted"> − </span><span>${hallCode}</span>${pn ? `<span class="loc-muted"> · ${pn}</span>` : ''}`;
  }
  return `<span class="loc-code-strong">${sc}</span>${sn ? `<span class="loc-muted"> · ${sn}</span>` : ''}`;
}

/** @param {string|null|undefined} id @param {Map<string, object>} idx */
function formatLocBrief(id, idx) {
  if (!id) return '—';
  const l = idx.get(id);
  if (!l) return `${escHtml(String(id).slice(0, 8))}…`;
  const code = escHtml(l.location_code || '');
  return l.name ? `${code} · ${escHtml(l.name)}` : code;
}

function fmtAuditWhen(iso) {
  return (iso || '').replace('T', ' ').slice(0, 16);
}

function auditLocLabel(row, locIdx) {
  const data = row?.new_data || row?.old_data || {};
  const id = row?.record_id || data.id;
  const loc = id ? locIdx.get(id) : null;
  const code = loc?.location_code || data.location_code || String(id || '').slice(0, 8);
  const name = loc?.name || data.name || '';
  const kind = getLocationKindLabel(loc?.location_type || data.location_type || '');
  return `${code}${name ? ' · ' + name : ''} (${kind})`;
}

function auditFieldValue(data, key) {
  if (!data || !(key in data)) return '—';
  const v = data[key];
  if (v === null || v === undefined || v === '') return '—';
  return String(v);
}

function auditDiffSummary(row) {
  const action = row?.action || '';
  if (action === 'INSERT') return 'Kreirano';
  if (action === 'DELETE') return 'Obrisano';
  const keys = Array.isArray(row?.diff_keys) ? row.diff_keys.filter(k => k !== 'updated_at') : [];
  if (!keys.length) return 'Bez vidljivih promena';
  return keys.map(k => {
    const before = auditFieldValue(row.old_data, k);
    const after = auditFieldValue(row.new_data, k);
    return `${k}: ${before} -> ${after}`;
  }).join('; ');
}

function definitionAuditRowsHtml(rows, locIdx) {
  if (!Array.isArray(rows)) {
    return '<tr><td colspan="6" class="loc-muted">Istorija definicija nije dostupna.</td></tr>';
  }
  if (!rows.length) {
    return '<tr><td colspan="6" class="loc-muted">Još nema zabeleženih izmena definicija hala/polica.</td></tr>';
  }
  return rows.map(row => {
    const who = row.actor_email || (row.actor_uid ? String(row.actor_uid).slice(0, 8) + '…' : '—');
    const changed = Array.isArray(row.diff_keys) && row.diff_keys.length
      ? row.diff_keys.filter(k => k !== 'updated_at').join(', ')
      : row.action === 'INSERT'
        ? 'sva polja'
        : '—';
    return `<tr>
      <td class="loc-mov-when">${escHtml(fmtAuditWhen(row.changed_at))}</td>
      <td>${escHtml(who)}</td>
      <td><span class="loc-mov-type">${escHtml(row.action || '')}</span></td>
      <td>${escHtml(auditLocLabel(row, locIdx))}</td>
      <td class="loc-path">${escHtml(changed)}</td>
      <td class="loc-path">${escHtml(auditDiffSummary(row).slice(0, 300))}</td>
    </tr>`;
  }).join('');
}

function headerHtml() {
  const auth = getAuth();
  return `
    <header class="kadrovska-header">
      <div class="kadrovska-header-left">
        <button type="button" class="btn-hub-back" id="locBackBtn" title="Nazad na listu modula" aria-label="Nazad na module">
          <span class="back-icon" aria-hidden="true">←</span>
          <span>Moduli</span>
        </button>
        <div class="kadrovska-title">
          <span class="ktitle-mark" aria-hidden="true">📍</span>
          <span>Lokacije delova</span>
        </div>
      </div>
      <div class="kadrovska-header-right">
        <button type="button" class="theme-toggle" id="locThemeToggle" title="Promeni temu" aria-label="Promeni temu">
          <span class="theme-icon-dark">🌙</span>
          <span class="theme-icon-light">☀️</span>
        </button>
        <span class="role-indicator ${isAdmin() ? 'role-pm' : 'role-viewer'}" id="locRoleLabel">${escHtml((auth.role || 'viewer').toUpperCase())}</span>
        <button type="button" class="hub-logout" id="locLogoutBtn">Odjavi se</button>
      </div>
    </header>`;
}

function tabsHtml(activeId) {
  const isAllowed = t => {
    if (t.adminOnly && !canViewLokacijeSync()) return false;
    if (t.manageOnly && !canEdit()) return false;
    return true;
  };
  const renderLeaf = t => `
    <button type="button" role="tab" class="kadrovska-tab loc-tab${t.id === activeId ? ' active' : ''}"
      data-loc-tab="${escHtml(t.id)}" aria-selected="${t.id === activeId ? 'true' : 'false'}">
      ${t.icon ? `<span class="loc-tab-icon" aria-hidden="true">${t.icon}</span>` : ''}<span class="loc-tab-label">${escHtml(t.label)}</span>
    </button>`;

  const renderGroup = g => {
    const items = (g.items || []).filter(isAllowed);
    if (!items.length) return ''; /* nema čime da se popuni meni — ne renderuj */
    const groupActive = items.some(it => it.id === activeId);
    const activeItem = items.find(it => it.id === activeId);
    /* Kad je sub-tab aktivan, na samom trigger-u prikaži njegov naziv i ikonu
     * (umesto generičkog „Više") — operater vidi gde se nalazi. */
    const triggerIcon = activeItem?.icon || g.icon;
    const triggerLabel = activeItem?.label || g.label;
    return `
      <div class="loc-tab-group" data-loc-tab-group>
        <button type="button" class="kadrovska-tab loc-tab loc-tab-trigger${groupActive ? ' active' : ''}"
          aria-haspopup="menu" aria-expanded="false" aria-label="${escHtml(g.label)} — više opcija">
          ${triggerIcon ? `<span class="loc-tab-icon" aria-hidden="true">${triggerIcon}</span>` : ''}<span class="loc-tab-label">${escHtml(triggerLabel)}</span>
          <span class="loc-tab-caret" aria-hidden="true">▾</span>
        </button>
        <div class="loc-tab-menu" role="menu" hidden>
          ${items
            .map(
              it => `
            <button type="button" role="menuitem" class="loc-tab-menuitem${it.id === activeId ? ' is-current' : ''}"
              data-loc-tab="${escHtml(it.id)}">
              ${it.icon ? `<span class="loc-tab-icon" aria-hidden="true">${it.icon}</span>` : ''}<span>${escHtml(it.label)}</span>
            </button>`,
            )
            .join('')}
        </div>
      </div>`;
  };

  const html = TABS
    .map(t => {
      if (t.type === 'group') return renderGroup(t);
      if (!isAllowed(t)) return '';
      return renderLeaf(t);
    })
    .filter(Boolean)
    .join('');

  return `
    <nav class="kadrovska-tabs loc-tabs" role="tablist" aria-label="Lokacije — sekcije">
      ${html}
    </nav>`;
}

async function renderPanel(host, tabId) {
  if (!hasSupabaseConfig()) {
    host.innerHTML = `<div class="kadr-panel active loc-panel"><p class="loc-muted">Supabase nije konfigurisan (VITE_SUPABASE_URL / ANON KEY).</p></div>`;
    return;
  }

  if (tabId === 'dashboard') {
    /* Datumi za KPI count-ove — lokalno YYYY-MM-DD. */
    const _today = new Date();
    const _ymd = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    const todayYMD = _ymd(_today);
    const weekAgo = new Date(_today);
    weekAgo.setDate(weekAgo.getDate() - 6); /* uključi i današnji dan = 7 kalendarskih dana */
    const weekAgoYMD = _ymd(weekAgo);

    const [locs, plac, movs, syncStatus, syncHealth, users, movsTodayN, movsWeekN] = await Promise.all([
      fetchLocations(),
      fetchPlacements({ limit: 500 }),
      fetchRecentMovements(12),
      fetchBridgeSyncStatus().catch(() => []),
      /* Härd-3: sync worker zdravlje + DEAD_LETTER count. Tih fallback ako
       * migracija nije primenjena ili helper baci. */
      fetchLocSyncHealthSummary().catch(() => ({ dead_letter_count: 0, workers: [] })),
      /* Users za prikaz „Korisnik" kolone — tih fallback ako endpoint nije dostupan. */
      loadUsersFromDb().catch(() => []),
      fetchMovementsCountSince(todayYMD).catch(() => null),
      fetchMovementsCountSince(weekAgoYMD).catch(() => null),
    ]);
    const locN = Array.isArray(locs) ? locs.length : '—';
    const plN = Array.isArray(plac) ? plac.length : '—';
    const todayN = movsTodayN == null ? '—' : String(movsTodayN);
    const weekN = movsWeekN == null ? '—' : String(movsWeekN);
    const locIdx = locationIndex(locs);
    const userIdx = new Map(
      (Array.isArray(users) ? users : []).map(u => [String(u.id).toLowerCase(), u.label]),
    );
    const recentList = Array.isArray(movs) ? movs.slice(0, 12) : [];
    const recentCount = recentList.length;
    const recent = recentList.length
      ? recentList
          .map(m => {
            const type = m.movement_type || '';
            const pillCls = movementTypePillClass(type);
            const pillLabel = MOVEMENT_TYPE_LABELS[type] || type;
            const item = m.item_ref_id
              ? `<span class="loc-mov-item">${escHtml(m.item_ref_table || '')}<span class="loc-muted">:</span>${escHtml(m.item_ref_id || '')}</span>`
              : '<span class="loc-muted">—</span>';
            const fromCode = m.from_location_id
              ? `<span class="loc-mov-code">${escHtml(locIdx.get(m.from_location_id)?.location_code || '')}</span>`
              : '<span class="loc-muted">—</span>';
            const toCode = m.to_location_id
              ? `<span class="loc-mov-code loc-mov-code-to">${escHtml(locIdx.get(m.to_location_id)?.location_code || '')}</span>`
              : '<span class="loc-muted">—</span>';
            const toName = m.to_location_id
              ? escHtml(locIdx.get(m.to_location_id)?.name || '')
              : type === 'REMOVAL'
                ? 'Uklonjen sa lokacije'
                : '';
            const whoRaw = String(m.moved_by || '').toLowerCase();
            const who = userIdx.get(whoRaw);
            const whoLabel = who
              ? escHtml(who)
              : whoRaw
                ? `<span class="loc-muted">${escHtml(whoRaw.slice(0, 8))}…</span>`
                : '<span class="loc-muted">—</span>';
            const when = escHtml((m.moved_at || '').replace('T', ' ').slice(0, 16));
            return `<tr>
              <td><span class="loc-mov-pill ${pillCls}">${escHtml(pillLabel)}</span></td>
              <td class="loc-mov-cell-item">${item}</td>
              <td class="loc-mov-cell-flow">${fromCode} <span class="loc-mov-arrow" aria-hidden="true">→</span> ${toCode}</td>
              <td>${toName ? `<span class="loc-mov-target">${toName}</span>` : '<span class="loc-muted">—</span>'}</td>
              <td>${whoLabel}</td>
              <td class="loc-mov-when">${when}</td>
            </tr>`;
          })
          .join('')
      : '';

    const err =
      locs === null && plac === null
        ? `<p class="loc-warn">Ne mogu da učitam podatke. Proveri da li je u Supabase-u primenjena migracija <code>add_loc_module.sql</code> i da li si ulogovan.</p>`
        : '';

    /* First-run state — baza je prazna. Nema smisla prikazati "0 lokacija, 0 stavki"
     * bez ikakvog konteksta; dajemo jasan CTA da korisnik zna šta da klikne. */
    const isEmptyFirstRun =
      Array.isArray(locs) && locs.length === 0 && Array.isArray(plac) && plac.length === 0;
    const firstRunHtml = isEmptyFirstRun && canEdit()
      ? `<div class="loc-firstrun" role="note">
           <div class="loc-firstrun-title">Dobrodošao u Lokacije delova</div>
           <p class="loc-firstrun-sub">Baza je trenutno prazna. Da bi modul zaživeo:</p>
           <ol class="loc-firstrun-steps">
             <li>Klikni <strong>Nova lokacija</strong> i dodaj bar jednu master lokaciju (npr. <code>MAG-1</code> — Centralni magacin).</li>
             <li>Otvori karticu <strong>Lokacije</strong> da pregledaš/doteraš hijerarhiju.</li>
             <li>Klikni <strong>Brzo premeštanje</strong> da evidentiraš prvu stavku (INITIAL_PLACEMENT).</li>
           </ol>
         </div>`
      : isEmptyFirstRun
        ? `<p class="loc-muted" style="padding:12px 0">Nema još master lokacija. Korisnici sa ulogom za uređivanje mogu da ih dodaju (admin, LeadPM, PM, menadžment).</p>`
        : '';

    const bridgeBanner = renderBridgeStaleBanner(syncStatus);
    const syncWorkerBanner = renderSyncWorkerBanner(syncHealth);

    /* Kad je first-run (sve prazno), KPI grid i tabela poslednjih premeštanja
     * nemaju šta da pokažu — sakrivamo ih da ne bi bili „0 svuda". Quick-actions
     * i first-run CTA ostaju kao primarni vodič. */
    const showStats = !isEmptyFirstRun;

    host.innerHTML = `
      <div class="kadr-panel active loc-panel loc-panel--dashboard">
        ${err}
        ${locDashboardActionsHtml()}
        ${bridgeBanner}
        ${syncWorkerBanner}
        ${firstRunHtml}
        ${showStats ? `<div class="loc-kpi-row loc-kpi-row--dashboard">
          <div class="loc-kpi loc-kpi--blue">
            <span class="loc-kpi-icon" aria-hidden="true">📍</span>
            <span class="loc-kpi-body">
              <span class="loc-kpi-label">Aktivnih lokacija</span>
              <span class="loc-kpi-val">${escHtml(String(locN))}</span>
              <span class="loc-kpi-sub">definisanih mesta</span>
            </span>
          </div>
          <div class="loc-kpi loc-kpi--violet">
            <span class="loc-kpi-icon" aria-hidden="true">📦</span>
            <span class="loc-kpi-body">
              <span class="loc-kpi-label">Placements</span>
              <span class="loc-kpi-val">${escHtml(String(plN))}</span>
              <span class="loc-kpi-sub">stavki sa lokacijom</span>
            </span>
          </div>
          <div class="loc-kpi loc-kpi--green">
            <span class="loc-kpi-icon" aria-hidden="true">🔄</span>
            <span class="loc-kpi-body">
              <span class="loc-kpi-label">Premeštanja danas</span>
              <span class="loc-kpi-val">${escHtml(todayN)}</span>
              <span class="loc-kpi-sub">poslednjih 24h</span>
            </span>
          </div>
          <div class="loc-kpi loc-kpi--amber">
            <span class="loc-kpi-icon" aria-hidden="true">📊</span>
            <span class="loc-kpi-body">
              <span class="loc-kpi-label">Aktivnost (7 dana)</span>
              <span class="loc-kpi-val">${escHtml(weekN)}</span>
              <span class="loc-kpi-sub">izmena ukupno</span>
            </span>
          </div>
        </div>
        <div class="loc-recent-card">
          <div class="loc-recent-head">
            <h3 class="loc-subh loc-recent-title">
              <span class="loc-section-icon" aria-hidden="true">🔄</span>Poslednja premeštanja
              <span class="loc-count-pill" aria-label="Broj prikazanih premeštanja">${recentCount}</span>
            </h3>
            <button type="button" class="loc-link-btn" id="locRecentFilterLink">Filtriraj →</button>
          </div>
          ${recent
            ? `<div class="loc-table-wrap loc-recent-tablewrap">
                <table class="loc-table loc-recent-table">
                  <thead>
                    <tr>
                      <th>Tip</th>
                      <th>Predmet / Stavka</th>
                      <th>Premeštanje</th>
                      <th>Lokacija (cilj)</th>
                      <th>Korisnik</th>
                      <th>Vreme</th>
                    </tr>
                  </thead>
                  <tbody>${recent}</tbody>
                </table>
              </div>`
            : `<div class="loc-recent-empty">
                <div class="loc-recent-empty-icon" aria-hidden="true">📭</div>
                <div class="loc-recent-empty-title">Nema skorašnjih premeštanja</div>
                <p class="loc-recent-empty-sub">Skeniraj barkod ili klikni „Brzo premeštanje" da evidentiraš prvu izmenu.</p>
              </div>`}
        </div>` : ''}
      </div>`;
    attachLocToolbar();
    host.querySelector('#locRecentFilterLink')?.addEventListener('click', () => {
      const tabBtn = mountRef?.querySelector('[data-loc-tab="history"]');
      if (tabBtn instanceof HTMLElement) tabBtn.click();
    });
    return;
  }

  if (tabId === 'predmet') {
    /* Predmet tab je samodovoljan modul — sopstveni renderer u
     * `predmetTab.js` kontroliše ceo host. Ne zovemo locToolbarHtml ovde
     * jer Predmet tab ima sopstvene akcije (Promeni predmet / Print / PDF / CSV);
     * korisnik svejedno može da koristi ostale tabove kroz tab navigaciju iznad. */
    await renderPredmetTab(host, { onRefresh: refreshLocPanel });
    return;
  }

  if (tabId === 'labels') {
    /* Ulaz = isti izbor kao Početna (Police / TP); batch ostaje pod „Otvori batch režim". */
    const hub = locLabelPrintActionGridHtml();
    host.innerHTML = `
      <div class="kadr-panel active loc-panel">
        <h2 class="loc-subh" style="margin:0 0 6px"><span class="loc-section-icon" aria-hidden="true">🏷</span>Štampa nalepnica</h2>
        <p class="loc-muted" style="margin:0 0 16px">Izaberi tip nalepnice — isto kao brze akcije na Početnoj.</p>
        ${
          hub
            ? hub
            : `<p class="loc-muted" style="margin:0 0 16px">Za nalepnice polica i TP (stranica po koracima) potrebna je uloga sa pravom izmene lokacija.</p>`
        }
        <div class="loc-labels-batch" style="margin-top:28px;padding-top:20px;border-top:1px solid var(--border2,#ddd)">
          <h3 class="loc-subh" style="margin:0 0 8px">Batch štampa</h3>
          <p class="loc-muted" style="margin:0 0 12px">Više predmeta i TP-ova u jednom otisku (TSC).</p>
          <button type="button" class="btn btn-primary" id="locBtnLabelsBatch">Otvori batch režim</button>
        </div>
      </div>`;
    attachLocToolbar();
    host.querySelector('#locBtnLabelsBatch')?.addEventListener('click', async () => {
      await renderLabelsPrintPage(host, { onRefresh: refreshLocPanel });
    });
    return;
  }

  if (tabId === 'browse') {
    const locs = await fetchLocations({ activeOnly: !showInactiveLocations });
    const canEditLocs = canEdit();
    const err = locs === null ? `<p class="loc-warn">Učitavanje neuspešno.</p>` : '';
    const { browseFilter, browseKindFilter, browseHallId } = getLokacijeUiState();
    /* Hall-subtree filter prvo (suzi domen na izabranu halu), pa text/kind,
     * pa A-Z natural sort siblinga na svim nivoima. */
    const hallScoped = filterLocationsBySubtree(locs, browseHallId);
    const textFiltered = filterLocationsHierarchical(hallScoped, browseFilter);
    const kindFiltered = filterLocationsByKindHierarchical(textFiltered, browseKindFilter);
    const filtered = sortLocationsAZNatural(kindFiltered);
    const matchCount = browseFilter
      ? `<span class="loc-muted loc-filter-hint">Pogodaka: ${Array.isArray(locs) ? filtered.length : 0} / ${Array.isArray(locs) ? locs.length : 0}</span>`
      : '';
    const kindOptions = [
      ['', 'Sve lokacije'],
      ['hall', 'Samo HALE'],
      ['shelf', 'Samo POLICE'],
      ['machine', 'Samo MAŠINE'],
      ['other', 'Ostalo'],
    ]
      .map(([v, label]) => `<option value="${escHtml(v)}"${browseKindFilter === v ? ' selected' : ''}>${escHtml(label)}</option>`)
      .join('');

    /* HALE dropdown — sve aktivne i (ako je „Prikaži neaktivne" čekirano) neaktivne
     * hale iz trenutno učitanog `locs` skupa. Sort A-Z po location_code (natural). */
    const halls = Array.isArray(locs)
      ? locs
          .filter(l => getLocationKind(l.location_type) === 'hall')
          .slice()
          .sort((a, b) =>
            String(a.location_code || '').localeCompare(
              String(b.location_code || ''),
              undefined,
              { numeric: true, sensitivity: 'base' },
            ),
          )
      : [];
    const hallOptions = [`<option value="">Sve hale</option>`]
      .concat(
        halls.map(
          h =>
            `<option value="${escHtml(h.id)}"${h.id === browseHallId ? ' selected' : ''}>${escHtml(h.location_code || '')}${h.name ? ` · ${escHtml(h.name)}` : ''}</option>`,
        ),
      )
      .join('');

    const extraToolbar = `
      <div class="loc-master-heading">
        <strong><span class="loc-section-icon" aria-hidden="true">📍</span>Šifarnik hala i polica</strong>
        <span>HALA je veći prostor; POLICA je konkretno mesto unutar hale. Sve izmene se čuvaju kroz istoriju definicija.</span>
      </div>
      <div class="loc-view-switch" role="group" aria-label="Prikaz">
        <button type="button" class="btn btn-xs${browseViewMode === 'table' ? ' is-active' : ''}" data-loc-view="table">Tabela</button>
        <button type="button" class="btn btn-xs${browseViewMode === 'tree' ? ' is-active' : ''}" data-loc-view="tree">Stablo</button>
      </div>
      <label class="loc-inline-check">
        <span>Hala:</span>
        <select id="locBrowseHall">${hallOptions}</select>
      </label>
      <label class="loc-inline-check">
        <span>Tip:</span>
        <select id="locBrowseKind">${kindOptions}</select>
      </label>
      <label class="loc-inline-check">
        <input type="checkbox" id="locBrowseShowInactive" ${showInactiveLocations ? 'checked' : ''}>
        <span>Prikaži neaktivne</span>
      </label>
      <div class="loc-search">
        <input type="search" id="locBrowseSearch" class="loc-search-input" placeholder="Pretraga po šifri, nazivu ili putanji…" value="${escHtml(browseFilter)}" autocomplete="off" />
        ${matchCount}
      </div>`;

    const content =
      browseViewMode === 'tree'
        ? renderLocationsTreeHtml(filtered, canEditLocs)
        : renderLocationsTableHtml(filtered, canEditLocs);

    host.innerHTML = `
      <div class="kadr-panel active loc-panel">
        ${err}
        ${locToolbarHtml({ extra: extraToolbar })}
        ${content}
      </div>`;
    attachLocToolbar();
    attachBrowseActions(filtered);
    attachBrowseViewSwitch();
    attachBrowseSearch();
    return;
  }

  if (tabId === 'items') {
    const ui = getLokacijeUiState();
    const pageSize = ui.itemsPageSize;
    const page = ui.itemsPage;
    const offset = page * pageSize;
    const search = ui.itemsFilter;

    const [placRes, locs] = await Promise.all([
      fetchPlacements({ limit: pageSize, offset, wantCount: true, search }),
      fetchLocations(),
    ]);
    /* placRes = { rows, total } zbog wantCount=true */
    const plac = placRes?.rows ?? null;
    const total = typeof placRes?.total === 'number' ? placRes.total : null;
    const locIdx = locationIndex(locs);

    /* Redosled: kao u Supabase-u (`updated_at DESC`) — bez klijentskog sortiranja po crtežu,
     * jer prazni stringovi u poređenju ostaju „ispred“ pravih vrednosti i zbunjuju prikaz. */
    const rows = Array.isArray(plac)
      ? plac
          .map(r => {
            const loc = r.location_id != null ? locIdx.get(String(r.location_id)) : null;
            const locCell = loc
              ? formatPlacementLocationHtml(loc, locIdx)
              : `<span class="loc-path">${escHtml(String(r.location_id || '').slice(0, 8))}…</span>`;
            const itemTableRaw = String(r.item_ref_table || '');
            const itemTableAttr = escHtml(itemTableRaw);
            const itemIdAttr = escHtml(String(r.item_ref_id || ''));
            const isBigtehn = itemTableRaw.toLowerCase() === 'bigtehn_rn';
            const tpCell = isBigtehn
              ? `<span class="loc-code-strong">${escHtml(String(r.item_ref_id || '').trim())}</span>`
              : '<span class="loc-muted" title="Samo za bigtehn_rn postoji broj TP">—</span>';
            const drawCell =
              r.drawing_no != null && String(r.drawing_no).trim()
                ? escHtml(String(r.drawing_no).trim())
                : '<span class="loc-muted">—</span>';
            const ord = escHtml(r.order_no || '');
            const orderCell = r.order_no
              ? `<strong>${ord}</strong>`
              : '<span class="loc-muted">—</span>';
            const qty = r.quantity == null ? '' : escHtml(String(r.quantity));
            return `<tr class="loc-row-click" data-loc-item-table="${itemTableAttr}" data-loc-item-id="${itemIdAttr}" data-loc-item-order="${ord}" title="Klik za istoriju premeštanja"><td>${orderCell}</td><td>${tpCell}</td><td>${drawCell}</td><td>${locCell}</td><td class="loc-qty-cell">${qty}</td><td>${escHtml(r.placement_status || '')}</td></tr>`;
          })
          .join('')
      : '';
    const err = plac === null ? `<p class="loc-warn">Učitavanje neuspešno.</p>` : '';
    const pagerHtml = renderItemsPager({
      page,
      pageSize,
      total,
      loadedCount: Array.isArray(plac) ? plac.length : 0,
    });
    const searchHint = search
      ? `<span class="loc-muted loc-filter-hint">Pretraga: celokupna baza (ILIKE <code>${escHtml(search)}</code>).</span>`
      : `<span class="loc-muted loc-filter-hint">Pretraga ide na server, sortirana po poslednjoj izmeni.</span>`;
    const searchHtml = `
      <div class="loc-search loc-items-search">
        <input type="search" id="locItemsSearch" class="loc-search-input" placeholder="Pretraga: nalog · TP · crtež · tip stavke (ceo skup)…" value="${escHtml(search)}" autocomplete="off" />
        <button type="button" class="btn btn-xs" id="locItemsExport" title="Preuzmi CSV koji odgovara trenutnoj pretrazi">Export CSV</button>
        ${searchHint}
      </div>`;

    host.innerHTML = `
      <div class="kadr-panel active loc-panel">
        ${err}
        ${locToolbarHtml({ extra: searchHtml })}
        <p class="loc-muted">Klik na red otvara istoriju premeštanja. <strong>Nalog</strong> = broj predmeta (<code>order_no</code>). <strong>Tehnološki postupak</strong> = broj TP iz placement-a za <code>bigtehn_rn</code>. <strong>Crtež</strong> = <code>drawing_no</code> iz placement-a (prazno prikazuje „—“ dok se ne upiše). <strong>Lokacija</strong> = šifra police − šifra hale roditelja (<code>parent_id</code>). Isti crtež može imati više redova (različite police).</p>
        <div class="loc-table-wrap">
          <table class="loc-table">
            <thead><tr><th>Nalog</th><th>Tehnološki postupak</th><th>Crtež</th><th>Lokacija</th><th class="loc-qty-cell">Količina</th><th>Status</th></tr></thead>
            <tbody>${rows || `<tr><td colspan="6" class="loc-muted" style="padding:18px 12px">
              <div><strong>Nema evidentiranih stavki na lokacijama.</strong></div>
              <div style="margin-top:6px">Tabela <code>loc_item_placements</code> je prazna ili filter nema pogodaka. Da bi se ovde pojavili podaci:</div>
              <ul style="margin:6px 0 0 22px">
                <li>Otvori tab <strong>Pregled predmeta</strong> da pregledaš sve TP-ove jednog predmeta i vidiš da li već imaju lokaciju.</li>
                <li>Klikni <strong>Brzo premeštanje</strong> da evidentiraš prvu lokaciju (zaduženje) za neku stavku.</li>
                <li>Skenirani RNZ barkod automatski pravi <em>placement</em>.</li>
              </ul>
            </td></tr>`}</tbody>
          </table>
        </div>
        ${pagerHtml}
      </div>`;
    attachLocToolbar();
    attachItemsActions();
    attachItemsSearch();
    attachItemsPager();
    attachItemsExport();
    return;
  }

  if (tabId === 'report') {
    const ui = getLokacijeUiState();
    const { reportFilters: rf, reportSort, reportSortDesc, reportPage, reportPageSize } = ui;
    const offset = reportPage * reportPageSize;

    const [repRes, locs] = await Promise.all([
      fetchLocReportPartsByLocations({
        drawingNo: rf.drawingNo,
        orderNo: rf.orderNo,
        tpNo: rf.tpNo,
        projectSearch: rf.projectSearch,
        locationId: rf.locationId || undefined,
        locationQ: rf.locationQ,
        sort: reportSort,
        desc: reportSortDesc,
        limit: reportPageSize,
        offset,
      }),
      fetchLocations({ activeOnly: false }),
    ]);

    const locIdx = locationIndex(locs);
    const total = repRes?.total ?? null;
    const rows = repRes?.rows ?? null;
    const err =
      repRes === null
        ? `<p class="loc-warn">Ne mogu da učitam pregled. Proveri da li je primenjena migracija <code>add_loc_report_by_locations_rpc.sql</code> i RLS prava.</p>`
        : '';

    const locOptions = (Array.isArray(locs) ? locs : [])
      .sort((a, b) => (a.location_code || '').localeCompare(b.location_code || ''))
      .map(
        l =>
          `<option value="${escHtml(l.id)}"${l.id === rf.locationId ? ' selected' : ''}>${escHtml(l.location_code || '')} — ${escHtml(l.name || '')}</option>`,
      )
      .join('');

    const sortMark = col => {
      if (reportSort !== col) return '';
      return reportSortDesc ? ' ▼' : ' ▲';
    };
    const thSort = (col, label) =>
      `<th><button type="button" class="btn btn-xs loc-sort-th${reportSort === col ? ' is-active' : ''}" data-report-sort="${escHtml(col)}">${escHtml(label)}${sortMark(col)}</button></th>`;

    const bodyRows = Array.isArray(rows)
      ? rows
          .map(r => {
            const rawTbl = String(r.item_ref_table || '');
            const rawIid = String(r.item_ref_id || '');
            const rawOrd = String(r.order_no || '');
            const rawDr = String(r.drawing_no || '');
            const tbl = escHtml(rawTbl);
            const iid = escHtml(rawIid);
            const ord = escHtml(rawOrd);
            const locCell = r.location_code
              ? `<strong>${escHtml(r.location_code)}</strong><span class="loc-muted"> · ${escHtml(r.location_name || '')}</span>`
              : formatLocBrief(r.location_id, locIdx);
            const proj = [r.project_code, r.project_name].filter(Boolean).join(' — ');
            const woId = r.work_order_id != null ? String(r.work_order_id) : '';
            const naziv = String(r.naziv_dela || '').slice(0, 40);
            const matCell = [r.materijal, r.dimenzija_materijala]
              .filter(s => s != null && String(s).trim() !== '')
              .join(' · ');
            const rok = r.rok_izrade
              ? String(r.rok_izrade).slice(0, 10)
              : '';
            const tezina = r.tezina_obr != null && Number(r.tezina_obr) > 0
              ? Number(r.tezina_obr).toFixed(2)
              : '';
            const detailsBtn = woId
              ? `<button type="button" class="btn btn-xs" data-rep-open-tp data-wo-id="${escHtml(woId)}" title="Otvori tehnološki postupak (operacije + prijave)">📋 RN/TP</button>`
              : '';
            return `<tr class="loc-row-click" title="Klik za istoriju"
              data-rep-item-table="${tbl}" data-rep-item-id="${iid}" data-rep-order="${ord}" data-rep-drawing="${escHtml(rawDr)}"
              data-rep-customer="${escHtml(String(r.customer_name || ''))}"
              data-rep-naziv="${escHtml(String(r.naziv_dela || ''))}"
              data-rep-materijal="${escHtml(String(r.materijal || ''))}"
              data-rep-pname="${escHtml(String(r.project_name || ''))}"
              data-rep-qty="${escHtml(String(r.qty_on_location ?? ''))}"
              data-rep-komrn="${escHtml(String(r.komada_rn ?? ''))}">
              <td>${escHtml(proj || '—')}</td>
              <td>${escHtml(String(r.customer_name || '—'))}</td>
              <td>${rawOrd ? `<strong>${ord}</strong>` : '<span class="loc-muted">—</span>'}</td>
              <td>${escHtml(String(r.drawing_no || r.wo_broj_crteza || '—'))}${naziv ? `<br><span class="loc-muted">${escHtml(naziv)}</span>` : ''}</td>
              <td>${iid}</td>
              <td>${locCell}</td>
              <td class="loc-muted">${escHtml(matCell)}${tezina ? `<br><span class="loc-muted">${tezina} kg</span>` : ''}</td>
              <td class="loc-qty-cell">${escHtml(String(r.qty_on_location ?? ''))}</td>
              <td class="loc-qty-cell">${escHtml(String(r.qty_total_for_bucket ?? ''))}</td>
              <td>${escHtml(String(r.placement_status || ''))}</td>
              <td>${escHtml(rok)}</td>
              <td class="loc-actions-cell">
                ${detailsBtn}
                <button type="button" class="btn btn-xs" data-rep-print-tp title="Nalepnica TP (barkod)">TP</button>
              </td>
            </tr>`;
          })
          .join('')
      : '';

    const pagerHtml = renderLocPagerHtml({
      page: reportPage,
      pageSize: reportPageSize,
      total,
      loadedCount: Array.isArray(rows) ? rows.length : 0,
      idPrefix: 'locRep',
      ariaLabel: 'Paginacija pregleda',
    });

    host.innerHTML = `
      <div class="kadr-panel active loc-panel">
        ${err}
        ${locToolbarHtml({ extra: '' })}
        <div class="loc-history-filters" role="group" aria-label="Filteri pregleda po lokacijama">
          <label class="loc-filter-field"><span>Broj crteža</span>
            <input type="text" id="locRepDraw" class="loc-search-input" value="${escHtml(rf.drawingNo)}" maxlength="40" />
          </label>
          <label class="loc-filter-field"><span>Broj RN</span>
            <input type="text" id="locRepOrder" class="loc-search-input" value="${escHtml(rf.orderNo)}" maxlength="40" />
          </label>
          <label class="loc-filter-field"><span>Broj TP</span>
            <input type="text" id="locRepTp" class="loc-search-input" value="${escHtml(rf.tpNo)}" maxlength="12" inputmode="numeric" />
          </label>
          <label class="loc-filter-field"><span>Predmet / projekat</span>
            <input type="search" id="locRepProj" class="loc-search-input" value="${escHtml(rf.projectSearch)}" placeholder="Kod ili naziv…" />
          </label>
          <label class="loc-filter-field"><span>Lokacija (master)</span>
            <select id="locRepLoc" class="loc-search-input"><option value="">Sve</option>${locOptions}</select>
          </label>
          <label class="loc-filter-field"><span>Pretraga police</span>
            <input type="search" id="locRepLocQ" class="loc-search-input" value="${escHtml(rf.locationQ)}" placeholder="Šifra ili naziv…" />
          </label>
          <div class="loc-filter-actions">
            <button type="button" class="btn btn-xs" id="locRepApply">Primeni filtere</button>
            <button type="button" class="btn btn-xs" id="locRepReset">Resetuj</button>
            <button type="button" class="btn btn-xs" id="locRepExport" title="CSV trenutnog skupa filtera">Export CSV</button>
          </div>
        </div>
        <p class="loc-muted">Klik na red otvara istoriju. „📋 RN/TP“ otvara tehnološki postupak (operacije + prijave) iz BigTehn cache-a. „TP“ štampa nalepnicu ako postoji prepoznatljiv barkod. Isti crtež može imati više redova (različite police / količine po smeštaju).</p>
        <div class="loc-table-wrap">
          <table class="loc-table">
            <thead><tr>
              ${thSort('project_code', 'Predmet')}
              ${thSort('customer_name', 'Kupac')}
              ${thSort('order_no', 'RN')}
              ${thSort('drawing_no', 'Crtež / naziv')}
              ${thSort('item_ref_id', 'TP / ref')}
              ${thSort('location_code', 'Lokacija')}
              <th>Materijal · dimenzija</th>
              ${thSort('qty_on_location', 'Kol. lok.')}
              <th>Ukupno</th>
              <th>Status</th>
              ${thSort('rok_izrade', 'Rok')}
              <th>Akcije</th>
            </tr></thead>
            <tbody>${bodyRows || `<tr><td colspan="12" class="loc-muted" style="padding:18px 12px">
              <div><strong>Nema redova za zadate filtere.</strong></div>
              <div style="margin-top:6px">Pregled spaja <code>loc_item_placements</code> sa BigTehn cache-om i filtrira po predmetu/RN/crtežu/lokaciji. Ako baza placement-a još nije puna, otvori tab <strong>Pregled predmeta</strong> da vidiš sve TP-ove jednog predmeta — i tamo ćeš videti koji još nemaju lokaciju.</div>
            </td></tr>`}</tbody>
          </table>
        </div>
        ${pagerHtml}
      </div>`;
    attachLocToolbar();
    attachReportTabHandlers();
    return;
  }

  if (tabId === 'definitions') {
    const [auditRows, locs] = await Promise.all([
      fetchLocationDefinitionsAudit({ limit: 150 }),
      fetchLocations({ activeOnly: false }),
    ]);
    const locIdx = locationIndex(locs);
    const err = auditRows === null
      ? `<p class="loc-warn">Ne mogu da učitam istoriju definicija. Proveri da li je primenjena migracija za audit lokacija.</p>`
      : '';
    host.innerHTML = `
      <div class="kadr-panel active loc-panel">
        ${err}
        ${locToolbarHtml()}
        <div class="loc-master-heading">
          <strong><span class="loc-section-icon" aria-hidden="true">🕘</span>Istorija definicija hala i polica</strong>
          <span>Prikazuje ko je i kada dodao, promenio ili deaktivirao red u šifarniku <code>loc_locations</code>. Ovo nije istorija premeštanja stavki.</span>
        </div>
        <div class="loc-table-wrap">
          <table class="loc-table loc-history-table">
            <thead><tr>
              <th>Vreme</th>
              <th>Korisnik</th>
              <th>Akcija</th>
              <th>Lokacija</th>
              <th>Promenjeno</th>
              <th>Detalj</th>
            </tr></thead>
            <tbody>${definitionAuditRowsHtml(auditRows, locIdx)}</tbody>
          </table>
        </div>
      </div>`;
    attachLocToolbar();
    return;
  }

  if (tabId === 'history') {
    await renderHistoryTab(host);
    return;
  }

  if (tabId === 'sync') {
    if (!canViewLokacijeSync()) {
      host.innerHTML = `<div class="kadr-panel active loc-panel"><p class="loc-warn">Sync monitor je dostupan samo administratorima.</p></div>`;
      return;
    }
    await renderSyncTab(host);
  }
}

/* ══════════════════════════════════════════════════════════════════════════
   Sync tab — admin only
   ──────────────────────────────────────────────────────────────────────────
   Dva panela:
     1. BigTehn ingest worker (Faza 2A/2B) — armed flag, watermark,
        last_run_summary samples, dugmad ARM/DISARM/POKRENI SADA.
     2. Sync outbound events (MSSQL write-back) — postojeća tabela.
   ══════════════════════════════════════════════════════════════════════════ */

async function renderSyncTab(host) {
  const [ingestStatus, ev] = await Promise.all([
    fetchBigtehnIngestStatus(),
    fetchSyncOutboundEvents(100),
  ]);

  const ingestHtml = renderBigtehnIngestPanelHtml(ingestStatus);

  const outboundRows = Array.isArray(ev)
    ? ev
        .map(
          r =>
            `<tr><td>${escHtml(String(r.status || ''))}</td><td>${escHtml(String(r.source_record_id || '').slice(0, 8))}…</td><td>${escHtml((r.created_at || '').replace('T', ' ').slice(0, 19))}</td><td class="loc-path">${escHtml((r.last_error || '—').slice(0, 80))}</td></tr>`,
        )
        .join('')
    : '';
  const outboundErr = ev === null ? `<p class="loc-warn">Nema pristupa ili tabela nije kreirana.</p>` : '';

  host.innerHTML = `
    <div class="kadr-panel active loc-panel">
      ${ingestHtml}

      <h3 style="margin:24px 0 8px;font-size:15px">Outbound sync (MSSQL write-back)</h3>
      ${outboundErr}
      <p class="loc-muted">Redovi čekaju Node worker na infrastrukturi (MSSQL write-back).</p>
      <div class="loc-table-wrap">
        <table class="loc-table">
          <thead><tr><th>Status</th><th>Movement ID</th><th>Kreirano</th><th>Greška</th></tr></thead>
          <tbody>${outboundRows || '<tr><td colspan="4" class="loc-muted">Nema događaja.</td></tr>'}</tbody>
        </table>
      </div>
    </div>`;

  attachBigtehnIngestHandlers(host);
}

/**
 * HTML za BigTehn ingest worker panel. Render-uje:
 *   - Status badge (ARMED / DRY-RUN) + heartbeat indikator (zelena tačka ako
 *     je worker pulsirao u poslednjih 10 min).
 *   - Stat kartice (last_run_at, watermark, processed, armed_executed).
 *   - by_action histogram (compact pills).
 *   - Samples tabela (do 25 redova iz `last_run_summary.samples`).
 *   - Dugmad: ARM/DISARM toggle, „Pokreni dry-run sada", Refresh.
 *
 * @param {object|null} statusRes  rezultat `fetchBigtehnIngestStatus()`.
 */
function renderBigtehnIngestPanelHtml(statusRes) {
  const headerBase = `<h3 style="margin:0 0 8px;font-size:15px">BigTehn ingest worker</h3>`;

  if (!statusRes) {
    return `${headerBase}<p class="loc-warn">Učitavanje statusa worker-a nije uspelo (mreža?).</p>`;
  }
  if (statusRes.ok === false) {
    const code = String(statusRes.error || 'unknown');
    const hint = code === 'state_missing'
      ? ' Primeni migraciju <code>add_loc_phase2a_bigtehn_ingest_dryrun.sql</code>.'
      : code === 'not_admin'
        ? ' Samo administratori vide ovaj panel.'
        : '';
    return `${headerBase}<p class="loc-warn">Status worker-a: <code>${escHtml(code)}</code>.${hint}</p>`;
  }

  const state = statusRes.state || {};
  const hb = statusRes.heartbeat || null;
  const armed = !!state.armed;
  const summary = state.last_run_summary || {};
  const byAction = summary.by_action || {};
  const samples = Array.isArray(summary.samples) ? summary.samples : [];

  const armedBadge = armed
    ? `<span class="lp-pill lp-pill--green" style="font-size:12px;padding:3px 10px">ARMED — auto TRANSFER aktivan</span>`
    : `<span class="lp-pill" style="background:#fef3c7;color:#92400e;font-size:12px;padding:3px 10px">DRY-RUN — samo loguje</span>`;

  const hbDot = (() => {
    if (!hb) return `<span style="color:var(--lp-text2);font-size:12px">heartbeat: —</span>`;
    const ageMin = Math.max(0, Math.round(Number(hb.age_seconds || 0) / 60));
    const isAlive = !!hb.is_alive;
    const dot = `<span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:${isAlive ? '#16a34a' : '#dc2626'};margin-right:6px"></span>`;
    return `<span style="font-size:12px;color:var(--lp-text2)">${dot}heartbeat pre ${escHtml(String(ageMin))} min ${isAlive ? '' : '(WORKER NE RADI)'}</span>`;
  })();

  const lastRun = state.last_run_at ? formatRelativeAge(state.last_run_at) : '—';
  const watermark = state.watermark != null ? String(state.watermark) : '0';
  const processedTotal = summary.processed_total != null ? String(summary.processed_total) : '0';
  const armedExecuted = byAction.armed_executed != null ? String(byAction.armed_executed) : '0';
  const armedErrors = byAction.armed_errors != null ? Number(byAction.armed_errors) : 0;
  const parserFallback = byAction.parser_fallback != null ? Number(byAction.parser_fallback) : 0;

  const statsHtml = `
    <div class="loc-ingest-stats">
      <div class="loc-ingest-stat"><span class="lbl">Poslednje pokretanje</span><span class="val">${escHtml(lastRun)}</span></div>
      <div class="loc-ingest-stat"><span class="lbl">Watermark (signal id)</span><span class="val">${escHtml(watermark)}</span></div>
      <div class="loc-ingest-stat"><span class="lbl">Obrađeno u poslednjem run-u</span><span class="val">${escHtml(processedTotal)}</span></div>
      <div class="loc-ingest-stat"><span class="lbl">Armed executed / errors</span><span class="val">${escHtml(armedExecuted)} <span style="color:${armedErrors > 0 ? '#dc2626' : 'var(--lp-text2)'};font-size:12px">/ ${escHtml(String(armedErrors))}</span></span></div>
    </div>`;

  const actionPills = renderByActionPillsHtml(byAction);
  const fallbackWarn = parserFallback > 0
    ? `<p class="loc-muted" style="margin-top:4px;font-size:12px">⚠ Parser fallback: ${parserFallback} ident-i nisu mečovali aktivan predmet u keš-u (split 1 / split 2 fallback). Pogledaj sample-ove dole.</p>`
    : '';

  const samplesHtml = renderIngestSamplesHtml(samples);

  const armBtnLabel = armed ? 'DISARM (vrati u dry-run)' : 'ARM (aktiviraj auto TRANSFER)';
  const armBtnClass = armed ? 'btn' : 'btn btn-primary';
  const armBtnConfirm = armed
    ? 'Sigurno da gasiš worker? Auto-generisanje TRANSFER pokreta će prestati.'
    : 'Sigurno da aktiviraš worker? Od ovog trenutka će automatski praviti TRANSFER pokrete iz BigTehn prijava.';

  return `
    ${headerBase}
    <div class="loc-ingest-panel" style="border:1px solid var(--lp-border,#e5e7eb);border-radius:8px;padding:14px;margin-bottom:8px">
      <div style="display:flex;flex-wrap:wrap;align-items:center;gap:12px;margin-bottom:10px">
        ${armedBadge}
        ${hbDot}
        <div style="flex:1"></div>
        <button type="button" class="btn btn-xs" id="locIngestRefresh">↻ Osveži</button>
        <button type="button" class="btn btn-xs" id="locIngestRunNow" title="Ručno pokreni worker odmah (umesto da čekaš 5-min pg_cron)">▶ Pokreni sada</button>
        <button type="button" class="${armBtnClass} btn-xs" id="locIngestArmToggle"
          data-armed="${armed ? '1' : '0'}"
          data-confirm="${escHtml(armBtnConfirm)}">${escHtml(armBtnLabel)}</button>
      </div>

      ${statsHtml}

      <div style="margin-top:10px">
        <div style="font-size:12px;color:var(--lp-text2);margin-bottom:4px">Klasifikacija prijava (by_action):</div>
        ${actionPills || '<span class="loc-muted">— bez podataka, worker još nije pokrenut —</span>'}
        ${fallbackWarn}
      </div>

      <div style="margin-top:14px">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px">
          <strong style="font-size:13px">Sample-ovi iz poslednjeg run-a (do 25)</strong>
          <span class="loc-muted" style="font-size:11px">izvor: <code>loc_bigtehn_ingest_state.last_run_summary.samples</code></span>
        </div>
        ${samplesHtml}
      </div>
    </div>`;
}

function renderByActionPillsHtml(byAction) {
  if (!byAction || typeof byAction !== 'object') return '';
  const order = [
    ['initial_placement', 'initial', 'lp-pill--blue'],
    ['chain_transfer',    'chain',   'lp-pill--blue'],
    ['shelf_transfer',    'shelf→m', 'lp-pill--blue'],
    ['skip_already',      'skip:tu', null],
    ['skip_zero_qty',     'skip:qty=0', null],
    ['skip_bad_ident',    'skip:ident', null],
    ['no_machine_loc',    'no loc',  null],
    ['no_rn_in_cache',    'no RN',   null],
    ['too_old',           'staro',   null],
    ['armed_executed',    'exec ✓',  'lp-pill--green'],
    ['armed_errors',      'errors',  null],
    ['parser_fallback',   'fb parser', null],
  ];
  const parts = [];
  for (const [key, label, cls] of order) {
    const v = Number(byAction[key] || 0);
    if (v === 0) continue;
    const klass = cls || (key === 'armed_errors' || key === 'parser_fallback' ? '' : '');
    const colorStyle = key === 'armed_errors'
      ? 'background:#fee2e2;color:#991b1b'
      : key === 'parser_fallback'
        ? 'background:#fef3c7;color:#92400e'
        : '';
    const styleAttr = colorStyle ? ` style="${colorStyle};font-size:11px;padding:2px 8px;margin:2px"` : ` style="font-size:11px;padding:2px 8px;margin:2px"`;
    parts.push(`<span class="lp-pill ${klass}"${styleAttr}>${escHtml(label)}: <strong>${v}</strong></span>`);
  }
  return parts.join(' ');
}

function renderIngestSamplesHtml(samples) {
  if (!Array.isArray(samples) || samples.length === 0) {
    return `<div class="loc-muted" style="padding:8px 0">Nema sample-ova — worker još nije pokrenut, ili nije bilo novih prijava od poslednjeg watermark-a.</div>`;
  }
  const rows = samples.map(s => {
    const action = String(s.action || '');
    const actionPill = (() => {
      if (action === 'initial_placement') return `<span class="lp-pill lp-pill--blue" style="font-size:11px">initial</span>`;
      if (action === 'chain_transfer')   return `<span class="lp-pill lp-pill--blue" style="font-size:11px">chain</span>`;
      if (action === 'shelf_transfer')   return `<span class="lp-pill lp-pill--blue" style="font-size:11px">shelf→m</span>`;
      if (action === 'skip_already_there') return `<span class="lp-pill" style="background:#e5e7eb;color:#374151;font-size:11px">skip: već tu</span>`;
      if (action && action.startsWith('skip_'))
        return `<span class="lp-pill" style="background:#e5e7eb;color:#374151;font-size:11px">${escHtml(action)}</span>`;
      if (action === 'no_machine_loc' || action === 'no_rn_in_cache' || action === 'too_old')
        return `<span class="lp-pill" style="background:#fee2e2;color:#991b1b;font-size:11px">${escHtml(action)}</span>`;
      return `<span class="lp-pill" style="font-size:11px">${escHtml(action || '—')}</span>`;
    })();
    const armed = s.armed_executed === true
      ? `<span class="lp-pill lp-pill--green" style="font-size:11px">✓</span>`
      : '';
    const armedErr = s.armed_error
      ? `<br><span style="color:#dc2626;font-size:11px">${escHtml(String(s.armed_error).slice(0, 80))}</span>`
      : '';
    const fb = s.parser_fallback ? ` <span style="color:#92400e;font-size:11px" title="parser fallback">⚠fb</span>` : '';
    const fromCell = s.from_loc
      ? `${escHtml(String(s.from_loc))}${s.from_type ? `<br><span style="color:var(--lp-text2);font-size:10px">${escHtml(String(s.from_type))}</span>` : ''}`
      : '<span class="loc-muted">—</span>';
    const qtyCell = s.transfer_qty != null
      ? `<strong>${escHtml(String(s.transfer_qty))}</strong>${s.rn_total != null ? `<span style="color:var(--lp-text2);font-size:11px"> / ${escHtml(String(s.rn_total))}</span>` : ''}`
      : '<span class="loc-muted">—</span>';
    const started = s.started_at ? formatRelativeAge(s.started_at) : '—';
    return `<tr>
      <td class="loc-mov-when">${escHtml(String(s.signal_id != null ? s.signal_id : ''))}</td>
      <td class="loc-path">${escHtml(String(s.ident || ''))}${fb}<br><span style="font-size:11px;color:var(--lp-text2)">${escHtml(String(s.predmet || ''))} / ${escHtml(String(s.tp || ''))}</span></td>
      <td>${escHtml(String(s.op || ''))}</td>
      <td>${escHtml(String(s.machine || ''))}</td>
      <td>${fromCell}</td>
      <td class="loc-qty-cell">${qtyCell}</td>
      <td>${actionPill} ${armed}${armedErr}</td>
      <td style="font-size:11px;color:var(--lp-text2)">${escHtml(started)}</td>
    </tr>`;
  }).join('');

  return `<div class="loc-table-wrap" style="max-height:360px;overflow:auto">
    <table class="loc-table" style="font-size:12px">
      <thead><tr>
        <th>Sig #</th>
        <th>Ident → predmet / tp</th>
        <th>Op</th>
        <th>Mašina</th>
        <th>Trenutna lok.</th>
        <th class="loc-qty-cell">Qty</th>
        <th>Akcija</th>
        <th>Prijavljeno</th>
      </tr></thead>
      <tbody>${rows}</tbody>
    </table>
  </div>`;
}

function attachBigtehnIngestHandlers(host) {
  host.querySelector('#locIngestRefresh')?.addEventListener('click', () => {
    void renderSyncTab(host);
  });

  host.querySelector('#locIngestRunNow')?.addEventListener('click', async ev => {
    const btn = ev.currentTarget;
    btn.disabled = true;
    const prev = btn.textContent;
    btn.textContent = '⏳ Pokrećem…';
    try {
      const res = await runBigtehnIngestNow();
      if (!res || res.ok === false) {
        showToast(`Worker greška: ${escHtml(res?.error || 'unknown')}`, 'error');
      } else {
        const proc = res.processed != null ? res.processed : 0;
        const mode = res.mode || (res.armed ? 'armed' : 'dry-run');
        showToast(`Worker pokrenut (${mode}) — obrađeno ${proc}.`, 'success');
      }
    } catch (err) {
      showToast(`Greška: ${escHtml(err?.message || String(err))}`, 'error');
    } finally {
      btn.disabled = false;
      btn.textContent = prev;
      await renderSyncTab(host);
    }
  });

  host.querySelector('#locIngestArmToggle')?.addEventListener('click', async ev => {
    const btn = ev.currentTarget;
    const currentlyArmed = btn.getAttribute('data-armed') === '1';
    const confirmMsg = btn.getAttribute('data-confirm') || 'Potvrdi promenu armed flag-a.';
    if (!window.confirm(confirmMsg)) return;
    btn.disabled = true;
    const prev = btn.textContent;
    btn.textContent = '⏳…';
    try {
      const next = !currentlyArmed;
      const res = await setBigtehnIngestArmed(next);
      if (!res || res.ok === false) {
        showToast(`Toggle greška: ${escHtml(res?.error || 'unknown')}`, 'error');
      } else {
        showToast(next ? 'Worker je AKTIVIRAN (armed=TRUE).' : 'Worker je vraćen u dry-run (armed=FALSE).', 'success');
      }
    } catch (err) {
      showToast(`Greška: ${escHtml(err?.message || String(err))}`, 'error');
    } finally {
      btn.disabled = false;
      btn.textContent = prev;
      await renderSyncTab(host);
    }
  });
}

/**
 * „pre 2h", „pre 3 min", „pre 4 dana" — formati za panel.
 * @param {string} iso
 */
function formatRelativeAge(iso) {
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return '—';
  const diffMs = Date.now() - t;
  const sec = Math.max(0, Math.round(diffMs / 1000));
  if (sec < 60) return `pre ${sec} s`;
  const min = Math.round(sec / 60);
  if (min < 60) return `pre ${min} min`;
  const h = Math.round(min / 60);
  if (h < 24) return `pre ${h} h`;
  const d = Math.round(h / 24);
  return `pre ${d} dan${d === 1 ? '' : 'a'}`;
}

/**
 * Učitaj listu korisnika za user filter. Za obične korisnike RLS vraća samo
 * njihov red — tada filter nije koristan i sakrivamo ga.
 */
async function loadHistoryUsers() {
  if (historyUsersCache !== null) return historyUsersCache;
  try {
    const rows = await loadUsersFromDb();
    if (!Array.isArray(rows) || rows.length <= 1) {
      historyUsersCache = [];
    } else {
      historyUsersCache = rows
        .map(r => ({
          id: r.id,
          label: r.full_name || r.email || String(r.id).slice(0, 8),
        }))
        .sort((a, b) => a.label.localeCompare(b.label));
    }
  } catch {
    historyUsersCache = [];
  }
  return historyUsersCache;
}

function historyRowsHtml(movs, locIdx, userIdx) {
  if (!Array.isArray(movs) || movs.length === 0) {
    return '<tr><td colspan="9" class="loc-muted">Nema premeštanja za zadate filtere.</td></tr>';
  }
  return movs
    .map(m => {
      const when = escHtml((m.moved_at || '').replace('T', ' ').slice(0, 19));
      const who = userIdx.get(String(m.moved_by || '').toLowerCase());
      const whoLabel = who ? escHtml(who) : `<span class="loc-muted">${escHtml(String(m.moved_by || '').slice(0, 8))}…</span>`;
      const type = escHtml(MOVEMENT_TYPE_LABELS[m.movement_type] || m.movement_type || '');
      const qty = m.quantity == null ? '' : escHtml(String(m.quantity));
      const from = formatLocBrief(m.from_location_id, locIdx);
      const to = formatLocBrief(m.to_location_id, locIdx);
      const item = `${escHtml(m.item_ref_table || '')} · ${escHtml(m.item_ref_id || '')}`;
      const ord = m.order_no
        ? `<strong>${escHtml(m.order_no)}</strong>`
        : '<span class="loc-muted">—</span>';
      const note = escHtml((m.notes || '').slice(0, 80));
      return `<tr>
        <td class="loc-mov-when">${when}</td>
        <td>${whoLabel}</td>
        <td>${type}</td>
        <td class="loc-qty-cell">${qty}</td>
        <td class="loc-path">${from}</td>
        <td class="loc-path">${to}</td>
        <td>${item}</td>
        <td>${ord}</td>
        <td>${note}</td>
      </tr>`;
    })
    .join('');
}

function renderHistoryPager({ page, pageSize, total, loadedCount }) {
  const from = total === 0 ? 0 : page * pageSize + 1;
  const to = page * pageSize + loadedCount;
  const totalLabel = total == null ? '?' : String(total);
  const isLast = total != null ? to >= total : loadedCount < pageSize;
  const rangeLabel = total === 0 ? '0–0' : `${from}–${to}`;
  const sizeOpts = [25, 50, 100, 250]
    .map(n => `<option value="${n}"${n === pageSize ? ' selected' : ''}>${n}</option>`)
    .join('');
  return `
    <div class="loc-pager" role="navigation" aria-label="Paginacija istorije">
      <div class="loc-pager-info"><span>${rangeLabel} od ${escHtml(totalLabel)}</span></div>
      <div class="loc-pager-controls">
        <label class="loc-pager-size">
          <span>Po stranici:</span>
          <select id="locHistPageSize">${sizeOpts}</select>
        </label>
        <button type="button" class="btn btn-xs" id="locHistPrev" ${page === 0 ? 'disabled' : ''}>← Prethodna</button>
        <button type="button" class="btn btn-xs" id="locHistNext" ${isLast ? 'disabled' : ''}>Sledeća →</button>
      </div>
    </div>`;
}

async function renderHistoryTab(host) {
  const ui = getLokacijeUiState();
  const { historyFilters: f, historyPage, historyPageSize } = ui;
  const offset = historyPage * historyPageSize;

  const [movsRes, locs, users] = await Promise.all([
    fetchMovementsHistory({
      ...f,
      limit: historyPageSize,
      offset,
      wantCount: true,
    }),
    fetchLocations({ activeOnly: false }),
    loadHistoryUsers(),
  ]);

  const movs = movsRes?.rows ?? null;
  const total = typeof movsRes?.total === 'number' ? movsRes.total : null;
  const locIdx = locationIndex(locs);
  const userIdx = new Map((users || []).map(u => [String(u.id).toLowerCase(), u.label]));

  const err = movs === null ? `<p class="loc-warn">Učitavanje neuspešno.</p>` : '';

  const locOptions = (Array.isArray(locs) ? locs : [])
    .sort((a, b) => (a.location_code || '').localeCompare(b.location_code || ''))
    .map(
      l => `<option value="${escHtml(l.id)}"${l.id === f.locationId ? ' selected' : ''}>${escHtml(l.location_code || '')} — ${escHtml(l.name || '')}</option>`,
    )
    .join('');

  const userOptions = (users || [])
    .map(
      u => `<option value="${escHtml(u.id)}"${u.id === f.userId ? ' selected' : ''}>${escHtml(u.label)}</option>`,
    )
    .join('');
  const userFilterHtml = (users || []).length
    ? `<label class="loc-filter-field">
        <span>Korisnik</span>
        <select id="locHistUser"><option value="">Svi</option>${userOptions}</select>
      </label>`
    : '';

  const typeOptions = Object.entries(MOVEMENT_TYPE_LABELS)
    .map(
      ([v, lbl]) => `<option value="${v}"${v === f.movementType ? ' selected' : ''}>${escHtml(lbl)}</option>`,
    )
    .join('');

  const filtersHtml = `
    <div class="loc-history-filters" role="group" aria-label="Filteri istorije">
      <label class="loc-filter-field">
        <span>Pretraga (crtež ili nalog)</span>
        <input type="search" id="locHistSearch" class="loc-search-input" value="${escHtml(f.search)}" autocomplete="off" placeholder="npr. 1084924 ili 9000" />
      </label>
      <label class="loc-filter-field">
        <span>Samo nalog</span>
        <input type="text" id="locHistOrder" class="loc-search-input" value="${escHtml(f.orderNo)}" autocomplete="off" placeholder="npr. 9000" maxlength="40" />
      </label>
      <label class="loc-filter-field">
        <span>Lokacija (od ili do)</span>
        <select id="locHistLocation"><option value="">Sve</option>${locOptions}</select>
      </label>
      ${userFilterHtml}
      <label class="loc-filter-field">
        <span>Tip</span>
        <select id="locHistType"><option value="">Svi</option>${typeOptions}</select>
      </label>
      <label class="loc-filter-field">
        <span>Od</span>
        <input type="date" id="locHistFrom" value="${escHtml(f.dateFrom)}" />
      </label>
      <label class="loc-filter-field">
        <span>Do</span>
        <input type="date" id="locHistTo" value="${escHtml(f.dateTo)}" />
      </label>
      <div class="loc-filter-actions">
        <button type="button" class="btn btn-xs" id="locHistReset">Resetuj</button>
        <button type="button" class="btn btn-xs" id="locHistExport" title="Preuzmi CSV koji odgovara trenutnim filterima">Export CSV</button>
      </div>
    </div>`;

  const pagerHtml = renderHistoryPager({
    page: historyPage,
    pageSize: historyPageSize,
    total,
    loadedCount: Array.isArray(movs) ? movs.length : 0,
  });

  host.innerHTML = `
    <div class="kadr-panel active loc-panel">
      ${err}
      ${locToolbarHtml({ extra: '' })}
      ${filtersHtml}
      <div class="loc-table-wrap">
        <table class="loc-table loc-history-table">
          <thead><tr>
            <th>Vreme</th>
            <th>Korisnik</th>
            <th>Tip</th>
            <th class="loc-qty-cell">Količina</th>
            <th>Sa lokacije</th>
            <th>Na lokaciju</th>
            <th>Stavka</th>
            <th>Nalog</th>
            <th>Napomena</th>
          </tr></thead>
          <tbody>${historyRowsHtml(movs, locIdx, userIdx)}</tbody>
        </table>
      </div>
      ${pagerHtml}
    </div>`;

  attachLocToolbar();
  attachHistoryFilters();
  attachHistoryPager();
  attachHistoryExport(locs, users);
}

function attachHistoryFilters() {
  const host = locPanelHost;
  if (!host) return;

  const apply = () => refreshLocPanel();

  /* Debounce samo na text input-ima; dropdown-ovi i date reaguju odmah. */
  let t = null;
  let tOrd = null;
  const onInput = () => {
    const el = host.querySelector('#locHistSearch');
    if (!el) return;
    clearTimeout(t);
    t = setTimeout(() => {
      setHistoryFilters({ search: el.value });
      apply();
    }, 300);
  };
  host.querySelector('#locHistSearch')?.addEventListener('input', onInput);
  host.querySelector('#locHistOrder')?.addEventListener('input', () => {
    const el = host.querySelector('#locHistOrder');
    if (!el) return;
    clearTimeout(tOrd);
    tOrd = setTimeout(() => {
      setHistoryFilters({ orderNo: el.value });
      apply();
    }, 300);
  });

  host.querySelector('#locHistLocation')?.addEventListener('change', e => {
    setHistoryFilters({ locationId: e.target.value });
    apply();
  });
  host.querySelector('#locHistUser')?.addEventListener('change', e => {
    setHistoryFilters({ userId: e.target.value });
    apply();
  });
  host.querySelector('#locHistType')?.addEventListener('change', e => {
    setHistoryFilters({ movementType: e.target.value });
    apply();
  });
  host.querySelector('#locHistFrom')?.addEventListener('change', e => {
    setHistoryFilters({ dateFrom: e.target.value });
    apply();
  });
  host.querySelector('#locHistTo')?.addEventListener('change', e => {
    setHistoryFilters({ dateTo: e.target.value });
    apply();
  });

  host.querySelector('#locHistReset')?.addEventListener('click', () => {
    resetHistoryFilters();
    apply();
  });
}

function attachHistoryPager() {
  const host = locPanelHost;
  if (!host) return;
  host.querySelector('#locHistPrev')?.addEventListener('click', () => {
    const { historyPage } = getLokacijeUiState();
    if (historyPage > 0) {
      setHistoryPage(historyPage - 1);
      refreshLocPanel();
    }
  });
  host.querySelector('#locHistNext')?.addEventListener('click', () => {
    const { historyPage } = getLokacijeUiState();
    setHistoryPage(historyPage + 1);
    refreshLocPanel();
  });
  const sel = host.querySelector('#locHistPageSize');
  if (sel) {
    sel.addEventListener('change', () => {
      setHistoryPageSize(Number(sel.value));
      refreshLocPanel();
    });
  }
}

function attachHistoryExport(locs, users) {
  const host = locPanelHost;
  if (!host) return;
  const btn = host.querySelector('#locHistExport');
  if (!btn) return;

  const locIdx = locationIndex(locs);
  const userIdx = new Map((users || []).map(u => [String(u.id).toLowerCase(), u.label]));

  btn.addEventListener('click', async () => {
    const orig = btn.textContent || 'Export CSV';
    btn.disabled = true;
    btn.textContent = 'Export… 0';
    try {
      const { historyFilters } = getLokacijeUiState();
      const { rows, total, truncated } = await fetchAllMovements({
        ...historyFilters,
        pageSize: 500,
        onProgress: ({ loaded, total }) => {
          btn.textContent = total != null
            ? `Export… ${loaded}/${total}`
            : `Export… ${loaded}`;
        },
      });

      if (!Array.isArray(rows) || rows.length === 0) {
        alert('Nema zapisa koji odgovaraju trenutnim filterima.');
        return;
      }

      const headers = [
        'Vreme',
        'Korisnik',
        'Tip',
        'Količina',
        'Sa lokacije',
        'Sa putanje',
        'Na lokaciju',
        'Na putanju',
        'Tabela',
        'Crtež',
        'Nalog',
        'Napomena',
      ];
      const fmtLoc = id => {
        if (!id) return { code: '', path: '' };
        const l = locIdx.get(id);
        return { code: l?.location_code || '', path: l?.path_cached || '' };
      };

      const data = rows.map(m => {
        const from = fmtLoc(m.from_location_id);
        const to = fmtLoc(m.to_location_id);
        const who = userIdx.get(String(m.moved_by || '').toLowerCase()) || '';
        return [
          (m.moved_at || '').replace('T', ' ').slice(0, 19),
          who,
          MOVEMENT_TYPE_LABELS[m.movement_type] || m.movement_type || '',
          m.quantity == null ? '' : m.quantity,
          from.code,
          from.path,
          to.code,
          to.path,
          m.item_ref_table || '',
          m.item_ref_id || '',
          m.order_no || '',
          m.notes || '',
        ];
      });

      const csv = CSV_BOM + rowsToCsv(headers, data);
      downloadCsv(csv, buildHistoryExportFilename());

      if (truncated) {
        alert(
          `Export prekinut na 50 000 zapisa radi sigurnosti. Ukupno u bazi: ${total ?? '?'}. ` +
            `Suzi filtere za kompletniji izvoz.`,
        );
      }
    } catch (err) {
      console.error('[lokacije/history] CSV export failed', err);
      alert(`Export neuspešan: ${err?.message || err}`);
    } finally {
      btn.disabled = false;
      btn.textContent = orig;
    }
  });
}

function buildHistoryExportFilename() {
  const now = new Date();
  const pad = n => String(n).padStart(2, '0');
  const ts =
    `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}` +
    `_${pad(now.getHours())}${pad(now.getMinutes())}`;
  return `lokacije_istorija_${ts}.csv`;
}

/* Flat lista svih leaf tab-ova (top-level + group items) — koristi se za
 * permission checks i lookup-e gde nas ne zanima grupisanje. */
function flatTabs() {
  const out = [];
  for (const t of TABS) {
    if (t.type === 'group') {
      for (const it of (t.items || [])) out.push(it);
    } else {
      out.push(t);
    }
  }
  return out;
}

function wireTabs(container, initialTabId) {
  const host = container.querySelector('#locPanelHost');
  locPanelHost = host;

  /** Vraća trenutno aktivni `<nav>` element (re-renderuje se na promenu taba). */
  const getNav = () => container.querySelector('.loc-tabs');

  /** Postavi `top`/`left` na `position: fixed` meni — anker desno-uz-trigger,
   *  clamp na viewport (8px margin), prebaci na vrh trigger-a ako ne staje
   *  dole. Garantuje vidljivost čak i kad trigger wrap-uje u drugi red ili
   *  je u sticky/fixed kontejneru. */
  const positionMenu = (trigger, menu) => {
    /* Privremeno učini meni vidljivim ali nevidljiv (visibility) da bismo
     * izmerili stvarnu širinu/visinu — display:none ne može da se izmeri. */
    const wasHidden = menu.hasAttribute('hidden');
    menu.style.visibility = 'hidden';
    menu.removeAttribute('hidden');
    const tr = trigger.getBoundingClientRect();
    const menuW = menu.offsetWidth || 240;
    const menuH = menu.offsetHeight || 200;
    if (wasHidden) menu.setAttribute('hidden', '');
    menu.style.visibility = '';

    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const margin = 8;
    /* Default: desni rub menija = desni rub trigger-a (prirodno za poslednji tab). */
    let left = Math.round(tr.right - menuW);
    if (left < margin) left = margin;
    if (left + menuW > vw - margin) left = Math.max(margin, vw - menuW - margin);
    /* Default: ispod trigger-a; ako ne staje, iznad. */
    let top = Math.round(tr.bottom + 2);
    if (top + menuH > vh - margin) {
      top = Math.max(margin, Math.round(tr.top - menuH - 2));
    }
    menu.style.left = `${left}px`;
    menu.style.top = `${top}px`;
  };

  const closeMenu = () => {
    const open = container.querySelector('.loc-tab-group .loc-tab-menu:not([hidden])');
    if (!open) return;
    open.setAttribute('hidden', '');
    const trigger = open.parentElement?.querySelector('.loc-tab-trigger');
    trigger?.setAttribute('aria-expanded', 'false');
  };

  /** Re-pozicioniraj otvoreni meni (resize/scroll). */
  const repositionOpenMenu = () => {
    const open = container.querySelector('.loc-tab-group .loc-tab-menu:not([hidden])');
    if (!open) return;
    const trigger = open.parentElement?.querySelector('.loc-tab-trigger');
    if (trigger instanceof HTMLElement) positionMenu(trigger, open);
  };

  const toggleMenu = trigger => {
    const group = trigger.closest('.loc-tab-group');
    const menu = group?.querySelector('.loc-tab-menu');
    if (!menu) return;
    const isOpen = !menu.hasAttribute('hidden');
    closeMenu(); /* zatvori bilo koji drugi otvoreni meni */
    if (!isOpen) {
      positionMenu(trigger, menu);
      menu.removeAttribute('hidden');
      trigger.setAttribute('aria-expanded', 'true');
    }
  };

  const switchTab = async id => {
    if (!id) return;
    setLokacijeActiveTab(id);
    closeMenu();
    /* Re-renderuj tab strip da group trigger pravilno prikaže aktivni sub-tab. */
    const nav = getNav();
    if (nav) {
      const tmp = document.createElement('div');
      tmp.innerHTML = tabsHtml(id).trim();
      const fresh = tmp.firstElementChild;
      if (fresh) nav.replaceWith(fresh);
    }
    host.innerHTML = `<div class="kadr-panel active loc-panel"><p class="loc-muted">Učitavam…</p></div>`;
    await renderPanel(host, id);
  };

  /* Delegirani click — pokriva i leaf tabove i menuitem-e i group trigger.
   * Posle re-render-a tab strip-a, isti listener i dalje radi (na container-u). */
  container.addEventListener('click', ev => {
    const target = ev.target;
    if (!(target instanceof Element)) return;
    const trigger = target.closest('.loc-tab-trigger');
    if (trigger && container.contains(trigger)) {
      ev.preventDefault();
      toggleMenu(trigger);
      return;
    }
    const tabBtn = target.closest('[data-loc-tab]');
    if (tabBtn && container.contains(tabBtn)) {
      const id = tabBtn.getAttribute('data-loc-tab');
      void switchTab(id);
      return;
    }
  });

  /* Outside click + Escape — zatvaranje dropdown menija.
   * Härd-4 (H11): listenere se NE registrujemo direktno — kroz `_lokDisposers`
   * niz, da `teardownLokacijeModule` može da ih makne pri re-mount-u modula. */
  const onDocMouseDown = ev => {
    const t = ev.target;
    if (!(t instanceof Element)) return;
    if (t.closest('.loc-tab-group')) return; /* klik unutar group-a obrađen iznad */
    closeMenu();
  };
  document.addEventListener('mousedown', onDocMouseDown);
  _lokDisposers.push(() => document.removeEventListener('mousedown', onDocMouseDown));

  const onDocKeyDown = ev => {
    if (ev.key === 'Escape') closeMenu();
  };
  document.addEventListener('keydown', onDocKeyDown);
  _lokDisposers.push(() => document.removeEventListener('keydown', onDocKeyDown));

  /* Resize / scroll — `position: fixed` koordinata se ne menja automatski
   * pri scroll-u dokumenta, a wrap tab strip-a pomera trigger pri resize-u.
   * Re-pozicioniramo otvoren meni; passive da ne usporava scroll. */
  window.addEventListener('resize', repositionOpenMenu);
  _lokDisposers.push(() => window.removeEventListener('resize', repositionOpenMenu));

  window.addEventListener('scroll', repositionOpenMenu, { passive: true });
  _lokDisposers.push(() => window.removeEventListener('scroll', repositionOpenMenu));

  renderPanel(host, initialTabId);
}

/**
 * @param {HTMLElement} mountEl
 * @param {{ onBackToHub?: () => void, onLogout?: () => void }} options
 */
export function renderLokacijeModule(mountEl, { onBackToHub, onLogout } = {}) {
  loadLokacijeTabFromStorage();
  loadPredmetStateFromStorage();
  let { activeTab: tabId } = getLokacijeUiState();
  /* Permission guard: sync/definitions su sad unutar „Više" group-a, pa
   * TABS.find ne hvata leaf entry-je. `flatTabs()` vraća sve leaf tabove
   * (top-level + group items) — tačan lookup za adminOnly/manageOnly. */
  const currentLeaf = flatTabs().find(t => t.id === tabId);
  if (currentLeaf?.adminOnly && !canViewLokacijeSync()) {
    tabId = 'dashboard';
    setLokacijeActiveTab(tabId);
  } else if (currentLeaf?.manageOnly && !canEdit()) {
    tabId = 'dashboard';
    setLokacijeActiveTab(tabId);
  }

  mountRef = mountEl;
  mountEl.innerHTML = '';
  const wrap = document.createElement('section');
  wrap.className = 'kadrovska-section';
  wrap.id = 'module-lokacije';
  wrap.setAttribute('aria-label', 'Modul Lokacije delova');
  wrap.innerHTML = `
    ${headerHtml()}
    ${tabsHtml(tabId)}
    <div id="locPanelHost"></div>
  `;
  mountEl.appendChild(wrap);

  wrap.querySelector('#locBackBtn')?.addEventListener('click', () => onBackToHub?.());
  wrap.querySelector('#locThemeToggle')?.addEventListener('click', () => toggleTheme());
  wrap.querySelector('#locLogoutBtn')?.addEventListener('click', async () => {
    await logout();
    onLogout?.();
  });

  wireTabs(wrap, tabId);
}

export function teardownLokacijeModule() {
  /* Härd-4 (H11): ukloni sve document/window listenere koje je `wireTabs`
   * registrovao. Bez ovog, svaki SPA re-mount modula bi duplirao listenere
   * (mousedown, keydown, resize, scroll). */
  for (const dispose of _lokDisposers) {
    try {
      dispose();
    } catch (e) {
      console.warn('[lokacije] disposer threw', e);
    }
  }
  _lokDisposers = [];

  mountRef = null;
  locPanelHost = null;
  historyUsersCache = null;
  /* In-memory queue za štampu nalepnica nestaje pri logout-u modula. */
  resetLabelsPrintPageState();
}
