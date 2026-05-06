/**
 * Lokacije — tab „Pregled predmeta".
 *
 * Tok:
 *   1. Ako predmet nije izabran → searchable lista BigTehn predmeta (Ekran 1).
 *   2. Ako je predmet izabran → hero kartica + stat kartice + filteri + tabela TP-ova (Ekran 2).
 *
 * Ne piše u bazu. Klik na red otvara `openTechProcedureModal` iz Plan Proizvodnje.
 * PDF ikonica uz crtež otvara signed URL iz Supabase Storage bucket-a.
 */

import { escHtml } from '../../lib/dom.js';
import { rowsToCsv, CSV_BOM } from '../../lib/csv.js';
import {
  searchBigtehnItems,
  fetchTpsForPredmet,
} from '../../services/lokacije.js';
import { openDrawingPdf } from '../../services/drawings.js';
import {
  getLokacijeUiState,
  setPredmetSelected,
  clearPredmetSelected,
  setPredmetFilters,
  resetPredmetFilters,
  setPredmetPage,
  setPredmetPageSize,
} from '../../state/lokacije.js';
import { openTechProcedureModal } from '../planProizvodnje/techProcedureModal.js';

const PAGE_SIZE_OPTIONS = [50, 100, 200, 500];

/* SVG ikone (inline, bez eksterne zavisnosti) */
const ICO = {
  search: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>`,
  hash: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" y1="9" x2="20" y2="9"/><line x1="4" y1="15" x2="20" y2="15"/><line x1="10" y1="3" x2="8" y2="21"/><line x1="16" y1="3" x2="14" y2="21"/></svg>`,
  hash20: `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" y1="9" x2="20" y2="9"/><line x1="4" y1="15" x2="20" y2="15"/><line x1="10" y1="3" x2="8" y2="21"/><line x1="16" y1="3" x2="14" y2="21"/></svg>`,
  briefcase: `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="20" height="14" rx="2" ry="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/></svg>`,
  file: `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>`,
  arrowRight: `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>`,
  mapPin: `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>`,
  mapPin16: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>`,
  package: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="16.5" y1="9.4" x2="7.5" y2="4.21"/><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>`,
  eye: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>`,
  alert: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`,
  filter: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/></svg>`,
  reset: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 .49-3.5"/></svg>`,
  printer: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="6" y="14" width="12" height="8"/></svg>`,
  filePdf: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>`,
  fileCsv: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="8" y1="13" x2="16" y2="13"/><line x1="8" y1="17" x2="16" y2="17"/></svg>`,
  chevLeft: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>`,
  chevRight: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>`,
  externalLink: `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>`,
  dotGreen: `<span style="display:inline-block;width:7px;height:7px;border-radius:50%;background:#4ade80;flex-shrink:0"></span>`,
};

/**
 * Glavni ulaz — render-uje ceo Predmet tab u dati host element.
 * @param {HTMLElement} host
 * @param {{ onRefresh: () => void|Promise<void> }} [opts]
 */
export async function renderPredmetTab(host, { onRefresh } = {}) {
  if (!host) return;
  const ui = getLokacijeUiState();
  const refresh = typeof onRefresh === 'function' ? onRefresh : () => renderPredmetTab(host, { onRefresh });

  if (!ui.predmetSelected) {
    await renderPickerView(host, refresh);
    return;
  }
  await renderDataView(host, refresh);
}

/* ═══════════════════════════════════════════════════════════════════════════
   EKRAN 1 — Picker view: izbor predmeta
   ═══════════════════════════════════════════════════════════════════════════ */

async function renderPickerView(host, refresh) {
  host.innerHTML = `
    <div class="lp-wrap">
      <!-- Intro kartica -->
      <div class="lp-card">
        <div class="lp-card-body">
          <div class="lp-intro-row">
            <div class="lp-intro-icon">${ICO.search.replace('width="16" height="16"', 'width="20" height="20"')}</div>
            <div class="lp-intro-text">
              <h3>Izaberi predmet</h3>
              <p>Lista uključuje samo otvorene predmete iz BigTehn-a (status „U TOKU"). Posle izbora videćeš sve njegove TP-ove sa lokacijama.</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Search kartica -->
      <div class="lp-card">
        <div class="lp-card-body">
          <div class="lp-field-label" style="margin-bottom:8px">PRETRAGA</div>
          <div class="lp-search-wrap">
            <span class="lp-search-icon">${ICO.search}</span>
            <input type="search" id="lpPickerQ" class="lp-search-input"
              placeholder="Broj predmeta, naziv, klijent ili narudžbenica..."
              autocomplete="off" />
          </div>
          <div class="lp-search-meta">
            <span id="lpPickerCount" style="color:var(--lp-text2);font-size:12px"></span>
            <button type="button" id="lpPickerReset" class="lp-reset-link" style="display:none">Resetuj pretragu</button>
          </div>
        </div>
      </div>

      <!-- Lista rezultata -->
      <div class="lp-card">
        <div class="lp-card-header">
          <span class="lp-card-header-label">Otvoreni predmeti</span>
          <span class="lp-card-header-hint">Klikni za izbor</span>
        </div>
        <div id="lpPickerList" class="lp-picker-list">
          <div class="lp-empty"><span class="lp-empty-icon">⏳</span><span class="lp-empty-title">Učitavam predmete…</span></div>
        </div>
      </div>
    </div>`;

  const inputEl = host.querySelector('#lpPickerQ');
  const listEl = host.querySelector('#lpPickerList');
  const countEl = host.querySelector('#lpPickerCount');
  const resetBtn = host.querySelector('#lpPickerReset');

  let lastReqId = 0;

  async function refreshList(q) {
    const reqId = ++lastReqId;
    listEl.innerHTML = `<div class="lp-empty"><span class="lp-empty-icon">⏳</span><span class="lp-empty-title">Učitavam predmete…</span></div>`;
    countEl.textContent = '';
    let rows;
    try {
      rows = await searchBigtehnItems(q, 200);
    } catch (err) {
      if (reqId !== lastReqId) return;
      listEl.innerHTML = `<div class="lp-empty"><span class="lp-empty-title" style="color:#f87171">Greška pretrage: ${escHtml(err?.message || String(err))}</span></div>`;
      return;
    }
    if (reqId !== lastReqId) return;
    if (!Array.isArray(rows) || rows.length === 0) {
      const msg = q ? 'Nema rezultata' : 'Nema otvorenih predmeta';
      const sub = q ? 'Pokušaj sa drugačijim terminom' : 'Nema predmeta sa statusom „U TOKU"';
      listEl.innerHTML = `<div class="lp-empty">
        <span class="lp-empty-icon" style="color:var(--lp-text2)">${ICO.search.replace('width="16" height="16"', 'width="32" height="32"')}</span>
        <span class="lp-empty-title">${escHtml(msg)}</span>
        <span class="lp-empty-sub">${escHtml(sub)}</span>
      </div>`;
      countEl.textContent = '0 rezultata';
      return;
    }
    countEl.textContent = `${rows.length} rezultata`;
    listEl.innerHTML = rows.map(renderPickerItemHtml).join('');
    listEl.querySelectorAll('[data-pick-id]').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = Number(btn.getAttribute('data-pick-id'));
        const it = rows.find(r => r.id === id);
        if (!it) return;
        setPredmetSelected({
          id: it.id,
          broj_predmeta: it.broj_predmeta,
          naziv_predmeta: it.naziv_predmeta,
          customer_name: it.customer_name,
          broj_narudzbenice: it.broj_narudzbenice,
        });
        void refresh();
      });
    });
  }

  resetBtn.addEventListener('click', () => {
    inputEl.value = '';
    resetBtn.style.display = 'none';
    void refreshList('');
    inputEl.focus();
  });

  let debTimer = null;
  inputEl.addEventListener('input', () => {
    const q = inputEl.value;
    resetBtn.style.display = q ? 'inline' : 'none';
    clearTimeout(debTimer);
    debTimer = setTimeout(() => refreshList(q), 180);
  });

  inputEl.focus();
  await refreshList('');
}

function renderPickerItemHtml(item) {
  const code = escHtml(item.broj_predmeta || '');
  const naz = escHtml(item.naziv_predmeta || '');
  const cust = item.customer_name ? escHtml(item.customer_name) : '';
  const nar = item.broj_narudzbenice ? escHtml(item.broj_narudzbenice) : '';
  const custHtml = cust
    ? `<span class="lp-picker-sub-item" style="display:inline-flex;align-items:center;gap:4px">${ICO.briefcase} ${cust}</span>`
    : '';
  const narHtml = nar
    ? `<span class="lp-picker-sub-item lp-mono">${ICO.file} NAR ${nar}</span>`
    : '';
  return `<button type="button" class="lp-picker-item" data-pick-id="${escHtml(String(item.id))}">
    <span class="lp-picker-icon">${ICO.hash}</span>
    <span class="lp-picker-main">
      <span class="lp-picker-title">${code} <span style="font-weight:400;color:var(--lp-text2)">· ${naz}</span></span>
      <span class="lp-picker-sub">${custHtml}${narHtml}</span>
    </span>
    <span class="lp-picker-right">
      <span class="lp-pill lp-pill--green">${ICO.dotGreen} U TOKU</span>
      <span class="lp-picker-arrow">${ICO.arrowRight}</span>
    </span>
  </button>`;
}

/* ═══════════════════════════════════════════════════════════════════════════
   EKRAN 2 — Data view: izabrani predmet + tabela
   ═══════════════════════════════════════════════════════════════════════════ */

async function renderDataView(host, refresh) {
  const ui = getLokacijeUiState();
  const sel = ui.predmetSelected;
  const f = ui.predmetFilters;
  const page = ui.predmetPage;
  const pageSize = ui.predmetPageSize;

  /* Prikaži shell odmah — korisnik vidi UI bez čekanja na fetch */
  host.innerHTML = `
    <div class="lp-wrap">
      ${renderHeroHtml(sel)}
      <div id="lpStatGrid" class="lp-stat-grid">${renderStatSkeletonHtml()}</div>
      ${renderFilterCardHtml(f)}
      <div class="lp-card" id="lpTableCard">
        <div id="lpSummaryBar" class="lp-summary-bar">
          <span style="color:var(--lp-text2)">Učitavam…</span>
        </div>
        <div style="overflow-x:auto">
          <table class="lp-table">
            <thead><tr>
              <th title="Pun ident broj radnog naloga: Predmet/TP">RN (Predmet/TP)</th>
              <th title="Broj tehnološkog postupka">TP #</th>
              <th title="Broj crteža iz BigTehn baze">Crtež</th>
              <th title="Naziv dela / pozicije">Naziv dela</th>
              <th class="lp-td-center" title="Količina na lokaciji / ukupno po RN-u">Količina (lok / RN)</th>
              <th title="Lokacija dela">Lokacija</th>
              <th title="Materijal i dimenzija">Materijal</th>
              <th></th>
            </tr></thead>
            <tbody id="lpRows">
              <tr><td colspan="8" class="lp-empty" style="padding:32px;text-align:center;color:var(--lp-text2)">Učitavam tehnološke postupke…</td></tr>
            </tbody>
          </table>
        </div>
        <div id="lpPager"></div>
      </div>
    </div>`;

  attachHeroHandlers(host, refresh);
  attachFilterHandlers(host, refresh);

  /* 3 paralelna fetcha: glavna stranica + count sa lokacijom + count bez lokacije */
  const baseOpts = {
    onlyOpen: true,
    includeAssembled: f.includeAssembled,
    tpNo: f.tpNo,
    drawingNo: f.drawingNo,
  };

  let res, resWith, resWithout;
  try {
    [res, resWith, resWithout] = await Promise.all([
      fetchTpsForPredmet(sel.id, { ...baseOpts, locationFilter: f.locationFilter, limit: pageSize, offset: page * pageSize }),
      fetchTpsForPredmet(sel.id, { ...baseOpts, locationFilter: 'with', limit: 1, offset: 0 }),
      fetchTpsForPredmet(sel.id, { ...baseOpts, locationFilter: 'without', limit: 1, offset: 0 }),
    ]);
  } catch (err) {
    console.error('[predmetTab] fetchTpsForPredmet failed', err);
    host.querySelector('#lpRows').innerHTML =
      `<tr><td colspan="8" style="padding:18px;color:#f87171;text-align:center">Greška pri učitavanju: ${escHtml(err?.message || String(err))}</td></tr>`;
    host.querySelector('#lpSummaryBar').textContent = '';
    host.querySelector('#lpStatGrid').innerHTML = renderStatSkeletonHtml();
    return;
  }

  const rows = res?.rows || [];
  const total = res?.total ?? 0;
  const totalWith = resWith?.total ?? 0;
  const totalWithout = resWithout?.total ?? 0;
  const totalAll = totalWith + totalWithout;

  host.querySelector('#lpStatGrid').innerHTML = renderStatCardsHtml({ totalAll, totalWith, totalWithout, totalShown: total });
  host.querySelector('#lpRows').innerHTML = renderTpRowsHtml(rows);
  host.querySelector('#lpSummaryBar').innerHTML = renderSummaryBarHtml({ sel, total, page, pageSize, rowsLen: rows.length, filters: f });
  host.querySelector('#lpPager').innerHTML = renderPagerHtml({ page, pageSize, total });

  attachTableRowClicks(host);
  attachPagerHandlers(host, refresh);
  attachExportPrintHandlers(host, sel, f);
}

/* ——— Hero kartica ——— */
function renderHeroHtml(sel) {
  const nar = sel.broj_narudzbenice
    ? `<span class="lp-hero-meta-item lp-mono">${ICO.file} NAR ${escHtml(sel.broj_narudzbenice)}</span>`
    : '';
  const cust = sel.customer_name
    ? `<span class="lp-hero-meta-item">${ICO.briefcase} ${escHtml(sel.customer_name)}</span>`
    : '';
  return `
    <div class="lp-card">
      <div class="lp-card-body">
        <div class="lp-hero">
          <div class="lp-hero-icon">${ICO.hash20}</div>
          <div class="lp-hero-body">
            <div class="lp-hero-label">Izabrani predmet</div>
            <div class="lp-hero-title">${escHtml(sel.broj_predmeta || '')} <span style="font-weight:400;color:var(--lp-text2);font-size:18px">· ${escHtml(sel.naziv_predmeta || '')}</span></div>
            <div class="lp-hero-meta">
              ${cust}${nar}
              <span class="lp-pill lp-pill--green">${ICO.dotGreen} U TOKU</span>
            </div>
          </div>
          <div style="flex-shrink:0">
            <button type="button" class="lp-btn lp-btn--secondary" id="lpChangePredmet">↻ Promeni predmet</button>
          </div>
        </div>
      </div>
    </div>`;
}

/* ——— Stat kartice ——— */
function renderStatSkeletonHtml() {
  return Array(4).fill(0).map(() => `
    <div class="lp-stat-card">
      <div style="height:80px;background:color-mix(in srgb, var(--lp-border) 40%, transparent);border-radius:6px;animation:pulse 1.4s infinite"></div>
    </div>`).join('');
}

function renderStatCardsHtml({ totalAll, totalWith, totalWithout, totalShown }) {
  const pct = totalAll > 0 ? Math.round((totalWith / totalAll) * 100) : 0;
  const withoutColor = totalWithout > 0 ? 'amber' : 'gray';
  const withoutHint = totalWithout > 0 ? 'potrebno definisati' : 'sve sređeno';
  return `
    <div class="lp-stat-card">
      <div class="lp-stat-icon-row">
        <div class="lp-stat-icon lp-stat-icon--gray">${ICO.package}</div>
        <div class="lp-stat-label">Ukupno stavki</div>
      </div>
      <div class="lp-stat-value">${totalAll}</div>
      <p class="lp-stat-hint">aktivnih u predmetu</p>
    </div>
    <div class="lp-stat-card">
      <div class="lp-stat-icon-row">
        <div class="lp-stat-icon lp-stat-icon--green">${ICO.mapPin16}</div>
        <div class="lp-stat-label">Sa lokacijom</div>
      </div>
      <div class="lp-stat-value lp-stat-value--green">${totalWith}</div>
      <p class="lp-stat-hint">${pct}% identifikovano</p>
    </div>
    <div class="lp-stat-card">
      <div class="lp-stat-icon-row">
        <div class="lp-stat-icon lp-stat-icon--${withoutColor}">${ICO.alert}</div>
        <div class="lp-stat-label">Bez lokacije</div>
      </div>
      <div class="lp-stat-value lp-stat-value--${withoutColor}">${totalWithout}</div>
      <p class="lp-stat-hint">${withoutHint}</p>
    </div>
    <div class="lp-stat-card">
      <div class="lp-stat-icon-row">
        <div class="lp-stat-icon lp-stat-icon--coral">${ICO.eye}</div>
        <div class="lp-stat-label">Prikazano</div>
      </div>
      <div class="lp-stat-value lp-stat-value--coral">${totalShown}</div>
      <p class="lp-stat-hint">po trenutnim filterima</p>
    </div>`;
}

/* ——— Filter kartica ——— */
function renderFilterCardHtml(f) {
  const lf = f.locationFilter;
  return `
    <div class="lp-card">
      <div class="lp-filter-row">
        <div class="lp-field lp-field--grow">
          <label class="lp-field-label" for="lpFiltTp">Broj TP</label>
          <div class="lp-input-wrap">
            <span class="lp-input-icon">${ICO.hash}</span>
            <input type="text" id="lpFiltTp" class="lp-input" value="${escHtml(f.tpNo)}" maxlength="12" inputmode="numeric"
              placeholder="npr. 10, 100, 101..." />
          </div>
        </div>
        <div class="lp-field lp-field--grow">
          <label class="lp-field-label" for="lpFiltDr">Broj crteža</label>
          <div class="lp-input-wrap">
            <span class="lp-input-icon">${ICO.file}</span>
            <input type="text" id="lpFiltDr" class="lp-input" value="${escHtml(f.drawingNo)}" maxlength="40"
              placeholder="npr. 1084924, 1084925..." />
          </div>
        </div>
        <div class="lp-field lp-field--grow">
          <label class="lp-field-label" for="lpFiltLoc">Lokacija</label>
          <div class="lp-input-wrap">
            <span class="lp-input-icon">${ICO.mapPin}</span>
            <select id="lpFiltLoc" class="lp-select">
              <option value="all"${lf === 'all' ? ' selected' : ''}>Svi (sa i bez lokacije)</option>
              <option value="with"${lf === 'with' ? ' selected' : ''}>Samo sa lokacijom</option>
              <option value="without"${lf === 'without' ? ' selected' : ''}>Samo BEZ lokacije</option>
            </select>
          </div>
        </div>
        <label class="lp-check-row">
          <input type="checkbox" id="lpFiltAssembled" ${f.includeAssembled ? 'checked' : ''}>
          <span>Prikaži ugrađene / otpisane</span>
        </label>
        <div class="lp-check-row" style="color:var(--lp-text2);opacity:0.7;cursor:default" title="Pregled uvek koristi ručnu MES listu aktivnih RN-ova.">
          <input type="checkbox" checked disabled style="accent-color:var(--lp-primary)">
          <span>Samo aktivni RN</span>
        </div>
      </div>
      <div class="lp-filter-actions">
        <div class="lp-filter-actions-left">
          <button type="button" class="lp-btn lp-btn--primary" id="lpApply">${ICO.filter} Primeni filtere</button>
          <button type="button" class="lp-btn lp-btn--secondary" id="lpReset">${ICO.reset} Resetuj</button>
        </div>
        <div class="lp-filter-actions-right">
          <button type="button" class="lp-btn lp-btn--secondary" id="lpPrint" style="color:var(--lp-primary)">${ICO.printer} Štampa</button>
          <button type="button" class="lp-btn lp-btn--pdf" id="lpExportPdf">${ICO.filePdf} Export PDF</button>
          <button type="button" class="lp-btn lp-btn--csv" id="lpExportCsv">${ICO.fileCsv} Export CSV</button>
        </div>
      </div>
    </div>`;
}

/* ——— Summary bar ——— */
function renderSummaryBarHtml({ sel, total, page, pageSize, rowsLen, filters }) {
  const from = total === 0 ? 0 : page * pageSize + 1;
  const to = page * pageSize + rowsLen;
  const activePills = [];
  if (filters.tpNo) activePills.push(`TP: ${escHtml(filters.tpNo)}`);
  if (filters.drawingNo) activePills.push(`crtež: ${escHtml(filters.drawingNo)}`);
  if (filters.locationFilter === 'with') activePills.push('samo sa lokacijom');
  if (filters.locationFilter === 'without') activePills.push('samo BEZ lokacije');
  activePills.push('aktivni RN');
  if (filters.includeAssembled) activePills.push('+ ugrađeni');

  const pillsHtml = activePills.map(p => `<span class="lp-pill lp-pill--blue" style="font-size:11px">${escHtml(p)}</span>`).join('');

  return `
    <div class="lp-summary-left">
      <span>Predmet <strong>${escHtml(sel.broj_predmeta || '')}</strong>${sel.customer_name ? ` · komitent <strong>${escHtml(sel.customer_name)}</strong>` : ''}</span>
      <span style="color:var(--lp-text2)">· prikazano <strong>${total === 0 ? '0–0' : `${from}–${to}`}</strong> od <strong>${total}</strong></span>
    </div>
    <div class="lp-summary-right">${pillsHtml}</div>`;
}

/* ——— Tabela ——— */
function renderTpRowsHtml(rows) {
  if (!Array.isArray(rows) || rows.length === 0) {
    return `<tr><td colspan="8"><div class="lp-empty" style="padding:40px;text-align:center">
      <span class="lp-empty-icon">${ICO.package.replace('width="16" height="16"', 'width="28" height="28"')}</span>
      <span class="lp-empty-title">Nema tehnoloških postupaka</span>
      <span class="lp-empty-sub">Pokušaj sa drugačijim filterima</span>
    </div></td></tr>`;
  }
  return rows.map(renderTpRowHtml).join('');
}

function renderTpRowHtml(r) {
  const ident = escHtml(r.wo_ident_broj || '');
  const tpNo = escHtml(r.tp_no || '');
  const crRaw = r.wo_broj_crteza || '';
  const cr = escHtml(crRaw);
  const nz = escHtml(String(r.naziv_dela || '').slice(0, 80));
  const komRn = r.komada_rn != null ? Number(r.komada_rn) : null;
  const placed = r.qty_total_placed != null ? Number(r.qty_total_placed) : 0;
  const qtyOnLoc = r.qty_on_location != null ? Number(r.qty_on_location) : null;
  const woId = r.work_order_id != null ? String(r.work_order_id) : '';
  const isAssembled = r.location_type === 'ASSEMBLY' || r.location_type === 'SCRAPPED';

  /* Količina pill */
  let qtyPillClass = 'lp-qty-pill--none';
  let qtyText = '—';
  if (qtyOnLoc != null) {
    if (komRn != null && qtyOnLoc >= komRn) qtyPillClass = 'lp-qty-pill--ok';
    else if (qtyOnLoc > 0) qtyPillClass = 'lp-qty-pill--partial';
    qtyText = String(qtyOnLoc);
  }
  const allPlaced = komRn != null && placed > 0 && placed >= komRn;
  const qtyCell = `<span class="lp-qty-pill ${qtyPillClass}">${escHtml(qtyText)}</span>${komRn != null ? `<span style="color:var(--lp-text2);font-size:12px;margin-left:4px">/ ${escHtml(String(komRn))}</span>` : ''}${allPlaced ? `<br><span style="font-size:11px;color:#4ade80">✓ raspoređeno</span>` : ''}`;

  /* Lokacija ćelija */
  let locCell;
  if (r.location_code) {
    locCell = `<div class="lp-loc-cell">
      <span class="lp-pill lp-pill--coral">${ICO.mapPin} <span class="lp-mono">${escHtml(r.location_code)}</span></span>
      ${r.location_name ? `<span class="lp-loc-name">${escHtml(r.location_name)}</span>` : ''}
    </div>`;
  } else {
    locCell = `<span class="lp-td-muted">— bez lokacije —</span>`;
  }

  /* PDF dugme */
  const pdfBtn = (crRaw && r.has_pdf === true)
    ? ` <button type="button" class="lp-pdf-btn" data-pdf-drawing="${cr}"
        title="Otvori PDF crteža ${cr}" aria-label="PDF">📄</button>`
    : '';

  /* Materijal */
  const matCell = `${escHtml(r.materijal || '')}${r.dimenzija_materijala ? ` <span class="lp-mono" style="color:var(--lp-text2)">${escHtml(r.dimenzija_materijala)}</span>` : ''}`;

  return `<tr class="${isAssembled ? 'lp-row--assembled' : ''}" data-wo-id="${escHtml(woId)}" style="cursor:pointer">
    <td class="lp-td-rn">${ident}</td>
    <td class="lp-td-mono">${tpNo}</td>
    <td class="lp-td-mono">${cr ? `${cr}${pdfBtn}` : '<span class="lp-td-muted">—</span>'}</td>
    <td>${nz || '<span class="lp-td-muted">—</span>'}</td>
    <td class="lp-td-center">${qtyCell}</td>
    <td>${locCell}</td>
    <td class="lp-td-mono" style="font-size:12px">${matCell || '<span class="lp-td-muted">—</span>'}</td>
    <td><button type="button" class="lp-ext-btn" title="Otvori TP modal">${ICO.externalLink}</button></td>
  </tr>`;
}

/* ——— Pagination ——— */
function renderPagerHtml({ page, pageSize, total }) {
  const isLast = (page + 1) * pageSize >= total;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const sizeOpts = PAGE_SIZE_OPTIONS
    .map(n => `<option value="${n}"${n === pageSize ? ' selected' : ''}>${n}</option>`)
    .join('');
  return `
    <div class="lp-pager">
      <span>Strana ${page + 1} od ${totalPages}</span>
      <div class="lp-pager-controls">
        <div class="lp-pager-size">
          <span style="font-size:12px">Po stranici:</span>
          <select id="lpPageSize" class="lp-pager-select">${sizeOpts}</select>
        </div>
        <button type="button" class="lp-btn lp-btn--secondary" id="lpPrev" style="padding:6px 10px" ${page === 0 ? 'disabled' : ''}>${ICO.chevLeft} Prethodna</button>
        <button type="button" class="lp-btn lp-btn--secondary" id="lpNext" style="padding:6px 10px" ${isLast ? 'disabled' : ''}>Sledeća ${ICO.chevRight}</button>
      </div>
    </div>`;
}

/* ══════════════════════════════════════════════════════════════════════════
   Event handleri
   ══════════════════════════════════════════════════════════════════════════ */

function attachHeroHandlers(host, refresh) {
  host.querySelector('#lpChangePredmet')?.addEventListener('click', () => {
    clearPredmetSelected();
    void refresh();
  });
}

function attachFilterHandlers(host, refresh) {
  const apply = () => {
    setPredmetFilters({
      tpNo: host.querySelector('#lpFiltTp')?.value || '',
      drawingNo: host.querySelector('#lpFiltDr')?.value || '',
      locationFilter: host.querySelector('#lpFiltLoc')?.value || 'all',
      includeAssembled: !!host.querySelector('#lpFiltAssembled')?.checked,
      onlyOpen: true,
    });
    void refresh();
  };

  host.querySelector('#lpApply')?.addEventListener('click', apply);
  host.querySelector('#lpReset')?.addEventListener('click', () => {
    resetPredmetFilters();
    void refresh();
  });

  host.querySelector('#lpFiltTp')?.addEventListener('keydown', e => { if (e.key === 'Enter') apply(); });
  host.querySelector('#lpFiltDr')?.addEventListener('keydown', e => { if (e.key === 'Enter') apply(); });
  host.querySelector('#lpFiltLoc')?.addEventListener('change', apply);
  host.querySelector('#lpFiltAssembled')?.addEventListener('change', apply);
}

function attachTableRowClicks(host) {
  host.querySelectorAll('#lpRows [data-pdf-drawing]').forEach(btn => {
    btn.addEventListener('click', ev => {
      ev.stopPropagation();
      ev.preventDefault();
      const drawing = btn.getAttribute('data-pdf-drawing') || '';
      if (drawing) void openDrawingPdf(drawing);
    });
  });

  host.querySelectorAll('#lpRows [data-wo-id]').forEach(tr => {
    tr.addEventListener('click', () => {
      const id = Number(tr.getAttribute('data-wo-id'));
      if (Number.isFinite(id) && id > 0) {
        void openTechProcedureModal({ work_order_id: id });
      }
    });
  });
}

function attachPagerHandlers(host, refresh) {
  host.querySelector('#lpPrev')?.addEventListener('click', () => {
    const ui = getLokacijeUiState();
    if (ui.predmetPage > 0) {
      setPredmetPage(ui.predmetPage - 1);
      void refresh();
    }
  });
  host.querySelector('#lpNext')?.addEventListener('click', () => {
    const ui = getLokacijeUiState();
    setPredmetPage(ui.predmetPage + 1);
    void refresh();
  });
  host.querySelector('#lpPageSize')?.addEventListener('change', e => {
    setPredmetPageSize(Number(e.target.value));
    void refresh();
  });
}

/* ══════════════════════════════════════════════════════════════════════════
   Print / Export PDF / Export CSV
   ══════════════════════════════════════════════════════════════════════════ */

function attachExportPrintHandlers(host, sel, filters) {
  host.querySelector('#lpExportCsv')?.addEventListener('click', async ev => {
    const btn = ev.currentTarget;
    if (!(btn instanceof HTMLButtonElement)) return;
    const orig = btn.innerHTML;
    btn.disabled = true;
    btn.textContent = 'Export…';
    try {
      const all = await fetchAllFiltered(sel, filters, p => {
        btn.textContent = `Export… ${p.loaded}/${p.total ?? '?'}`;
      });
      if (!all.rows.length) { alert('Nema redova za export sa trenutnim filterima.'); return; }
      const csv = CSV_BOM + buildCsvText(all.rows);
      downloadBlob(csv, buildExportFilename(sel, 'csv'), 'text/csv;charset=utf-8');
    } catch (err) {
      console.error('[predmetTab] CSV export failed', err);
      alert(`Export neuspešan: ${err?.message || err}`);
    } finally {
      btn.disabled = false;
      btn.innerHTML = orig;
    }
  });

  const printOrPdf = async (mode) => {
    const btnId = mode === 'pdf' ? '#lpExportPdf' : '#lpPrint';
    const btn = host.querySelector(btnId);
    if (!(btn instanceof HTMLButtonElement)) return;
    const orig = btn.innerHTML;
    btn.disabled = true;
    btn.textContent = mode === 'pdf' ? 'Pripremam PDF…' : 'Pripremam…';
    try {
      const all = await fetchAllFiltered(sel, filters, p => {
        btn.textContent = `${mode === 'pdf' ? 'PDF' : 'Štampa'}… ${p.loaded}/${p.total ?? '?'}`;
      });
      openPrintWindow({ rows: all.rows, total: all.total, sel, filters, mode });
    } catch (err) {
      console.error('[predmetTab] print/pdf failed', err);
      alert(`Greška: ${err?.message || err}`);
    } finally {
      btn.disabled = false;
      btn.innerHTML = orig;
    }
  };
  host.querySelector('#lpPrint')?.addEventListener('click', () => printOrPdf('print'));
  host.querySelector('#lpExportPdf')?.addEventListener('click', () => printOrPdf('pdf'));
}

async function fetchAllFiltered(sel, filters, onProgress) {
  const PAGE = 1000;
  const MAX_ROWS = 50000;
  const all = [];
  let offset = 0;
  let total = null;
  while (true) {
    const res = await fetchTpsForPredmet(sel.id, {
      onlyOpen: true,
      includeAssembled: filters.includeAssembled,
      tpNo: filters.tpNo,
      drawingNo: filters.drawingNo,
      locationFilter: filters.locationFilter,
      limit: PAGE,
      offset,
    });
    if (!res || !Array.isArray(res.rows)) break;
    if (total == null) total = res.total ?? null;
    all.push(...res.rows);
    if (typeof onProgress === 'function') onProgress({ loaded: all.length, total });
    if (res.rows.length < PAGE) break;
    offset += PAGE;
    if (all.length >= MAX_ROWS) break;
    if (total != null && all.length >= total) break;
  }
  return { rows: all, total: total ?? all.length };
}

function buildCsvText(rows) {
  const headers = [
    'RN (Predmet/TP)', 'Broj TP', 'Broj crteža', 'Naziv dela', 'Materijal',
    'Dimenzija materijala', 'Komada (RN)', 'Količina na lokaciji', 'Ukupno raspoređeno',
    'Lokacija šifra', 'Lokacija naziv', 'Putanja lokacije', 'Tip lokacije',
    'Status placement', 'Status RN', 'Revizija', 'Rok izrade', 'Težina obr (kg)',
  ];
  const data = rows.map(r => [
    r.wo_ident_broj || '', r.tp_no || '', r.wo_broj_crteza || '', r.naziv_dela || '',
    r.materijal || '', r.dimenzija_materijala || '', r.komada_rn ?? '',
    r.qty_on_location ?? '', r.qty_total_placed ?? '', r.location_code || '',
    r.location_name || '', r.location_path || '', r.location_type || '',
    r.placement_status || '',
    r.status_rn === true ? 'Zatvoren' : r.status_rn === false ? 'Otvoren' : '',
    r.revizija || '',
    r.rok_izrade ? String(r.rok_izrade).slice(0, 10) : '',
    r.tezina_obr != null && Number(r.tezina_obr) > 0 ? Number(r.tezina_obr).toFixed(2) : '',
  ]);
  return rowsToCsv(headers, data);
}

function buildExportFilename(sel, ext) {
  const now = new Date();
  const pad = n => String(n).padStart(2, '0');
  const ts = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}`;
  const code = (sel?.broj_predmeta || 'predmet').toString().replace(/[^a-zA-Z0-9_-]+/g, '_').slice(0, 30);
  return `lokacije_predmet_${code}_${ts}.${ext}`;
}

function downloadBlob(text, filename, mime) {
  const blob = new Blob([text], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.style.display = 'none';
  document.body.appendChild(a);
  a.click();
  setTimeout(() => { document.body.removeChild(a); URL.revokeObjectURL(url); }, 100);
}

function openPrintWindow({ rows, total, sel, filters, mode }) {
  const win = window.open('', '_blank', 'width=1200,height=900');
  if (!win) {
    alert('Pop-up blocker je sprečio otvaranje prozora za štampu. Dozvoli pop-up za ovaj sajt.');
    return;
  }

  const now = new Date();
  const pad = n => String(n).padStart(2, '0');
  const dateLabel = `${pad(now.getDate())}.${pad(now.getMonth() + 1)}.${now.getFullYear()} ${pad(now.getHours())}:${pad(now.getMinutes())}`;

  const filtChips = [];
  if (filters.tpNo) filtChips.push(`TP: ${escHtml(filters.tpNo)}`);
  if (filters.drawingNo) filtChips.push(`Crtež: ${escHtml(filters.drawingNo)}`);
  if (filters.locationFilter === 'with') filtChips.push('Samo sa lokacijom');
  else if (filters.locationFilter === 'without') filtChips.push('Samo BEZ lokacije');
  filtChips.push('Samo aktivni RN');
  if (filters.includeAssembled) filtChips.push('Uključeni ugrađeni/otpisani');

  const tableBody = rows.map(r => {
    const qtyLoc = r.qty_on_location != null ? r.qty_on_location : '';
    const qtyRn = r.komada_rn != null ? r.komada_rn : '';
    const loc = r.location_code
      ? `${escHtml(r.location_code)}${r.location_name ? ` — ${escHtml(r.location_name)}` : ''}`
      : '<span class="muted">— bez lokacije —</span>';
    const status = r.status_rn === true ? 'Zatvoren' : r.status_rn === false ? 'Otvoren' : '';
    return `<tr>
      <td><strong>${escHtml(r.wo_ident_broj || '')}</strong></td>
      <td>${escHtml(r.wo_broj_crteza || '')}</td>
      <td>${escHtml(String(r.naziv_dela || '').slice(0, 80))}</td>
      <td class="num">${escHtml(String(qtyLoc))}${qtyRn !== '' ? ` <span class="muted">/ ${escHtml(String(qtyRn))}</span>` : ''}</td>
      <td>${loc}</td>
      <td>${escHtml(String(r.materijal || ''))}${r.dimenzija_materijala ? ` <span class="muted">${escHtml(r.dimenzija_materijala)}</span>` : ''}</td>
      <td>${escHtml(status)}</td>
    </tr>`;
  }).join('');

  const html = `<!doctype html>
<html lang="sr"><head>
<meta charset="utf-8" />
<title>Predmet ${escHtml(sel.broj_predmeta || '')} — lokacije TP</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; margin: 18mm 12mm 14mm; color: #111; font-size: 11px; }
  h1 { margin: 0 0 4px; font-size: 16px; } h2 { margin: 0 0 10px; font-size: 13px; font-weight: 500; color: #333; }
  .meta { margin: 6px 0 12px; font-size: 11px; color: #444; }
  .filt { margin: 6px 0 12px; font-size: 11px; color: #333; padding: 6px 8px; background: #f3f4f6; border-radius: 4px; }
  table { width: 100%; border-collapse: collapse; font-size: 10.5px; }
  thead th { background: #e5e7eb; text-align: left; padding: 6px 8px; border: 1px solid #9ca3af; font-weight: 600; }
  tbody td { padding: 5px 8px; border: 1px solid #d1d5db; vertical-align: top; }
  tbody tr:nth-child(even) td { background: #f9fafb; }
  td.num { text-align: right; } .muted { color: #6b7280; }
  .actions { margin: 0 0 12px; } .actions button { font-size: 12px; padding: 6px 12px; cursor: pointer; }
  @media print { .actions { display: none !important; } body { margin: 12mm 8mm 10mm; } thead { display: table-header-group; } tr { page-break-inside: avoid; } }
</style></head><body>
  <div class="actions">
    <button type="button" onclick="window.print()">${mode === 'pdf' ? 'Sačuvaj kao PDF' : 'Štampaj'}</button>
    <button type="button" onclick="window.close()">Zatvori</button>
    ${mode === 'pdf' ? '<span class="muted" style="margin-left:8px">U dijalogu štampe izaberi „Sačuvaj kao PDF".</span>' : ''}
  </div>
  <h1>Predmet ${escHtml(sel.broj_predmeta || '')} — ${escHtml(sel.naziv_predmeta || '')}</h1>
  ${sel.customer_name ? `<h2>Komitent: ${escHtml(sel.customer_name)}</h2>` : ''}
  <div class="meta">Datum: ${escHtml(dateLabel)} · Ukupno redova: ${escHtml(String(total))}</div>
  <div class="filt"><strong>Filteri:</strong> ${filtChips.length ? filtChips.join(' · ') : 'nema'}</div>
  <table>
    <thead><tr><th>RN (Predmet/TP)</th><th>Crtež</th><th>Naziv dela</th><th class="num">Količina (lok / RN)</th><th>Lokacija</th><th>Materijal</th><th>Status RN</th></tr></thead>
    <tbody>${tableBody || '<tr><td colspan="7" class="muted" style="text-align:center;padding:14px">Nema redova.</td></tr>'}</tbody>
  </table>
  <script>window.addEventListener('load', () => { ${mode === 'pdf' ? 'setTimeout(() => window.print(), 250);' : ''} });<\/script>
</body></html>`;

  win.document.open();
  win.document.write(html);
  win.document.close();
  if (mode === 'print') {
    setTimeout(() => { try { win.print(); } catch { /* ignore */ } }, 200);
  }
}
