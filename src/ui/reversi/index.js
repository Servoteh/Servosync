/**
 * Reversi modul — zaduženja alata, radne odeće, zaštitne obuće, LZO i kooperacija.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { STORAGE_KEYS } from '../../lib/constants.js';
import { ssGet, ssSet } from '../../lib/storage.js';
import { logout } from '../../services/auth.js';
import { toggleTheme } from '../../lib/theme.js';
import { hasSupabaseConfig } from '../../services/supabase.js';
import { getAuth, canManageReversi, canAccessReversi } from '../../state/auth.js';
import {
  fetchDocuments,
  fetchTools,
  fetchMyIssuedTools,
  getMagacinLocationId,
  fetchActiveLocations,
  fetchOpenRecipientCardinality,
  insertTool,
  initialPlacementForTool,
  clearMagacinLocationCache,
} from '../../services/reversiService.js';
import {
  openIssueReversalModal,
  openConfirmReturnModal,
  openAddToolModal,
  openDocumentDetailsModal,
  fmtDateShort,
  handleReversalPdfClick,
} from './modals.js';
import { renderReznialatTab, teardownReznialatTab } from './reznialat.js';
import {
  openCuttingToolIssueScannerModal,
  openCuttingToolReturnScannerModal,
} from './cuttingToolScannerModal.js';
import { renderMojaZaduzenjaTab, teardownMojaZaduzenjaTab } from './mojaZaduzenja.js';
import { renderMagacinTab, teardownMagacinTab } from './magacinTab.js';
import { teardownCuttingByViews } from './cuttingByViews.js';
import { openBulkPrintLabelsModal } from './bulkPrintLabelsModal.js';
import { openQuickIssueModal } from './quickIssueModal.js';
import { rowsToCsv, CSV_BOM, parseCsv } from '../../lib/csv.js';
import { formatRevAssetKind, parseRevAssetKindCsv, REV_ASSET_KIND_OPTIONS, REV_ASSET_KIND_LABEL } from '../../lib/revAssetKind.js';
import { ICON_REZNI_MACHINING } from './revMachiningIcon.js';
import { revIcon } from './revMockUi.js';

const ICON_TAB_ZAD = `<svg class="rev-tab-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M16 4h2a2 2 0 012 2v14a2 2 0 01-2 2H6a2 2 0 01-2-2V6a2 2 0 012-2h2"/><rect x="8" y="2" width="8" height="4" rx="1" ry="1"/><path d="M9 14h6"/><path d="M9 18h6"/></svg>`;
const ICON_TAB_INV = `<svg class="rev-tab-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z"/><path d="M3.27 6.96L12 12.01l8.73-5.05"/><path d="M12 22.08V12"/></svg>`;
const ICON_TAB_RZN = ICON_REZNI_MACHINING;
const ICON_TAB_MOJ = `<svg class="rev-tab-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>`;
const ICON_TAB_MAG = `<svg class="rev-tab-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 7l9-4 9 4v10l-9 4-9-4z"/><path d="M3 7l9 4 9-4"/><path d="M12 11v10"/></svg>`;

const TABS = [
  { id: 'moja', label: 'Moja zaduženja' },
  { id: 'magacin', label: 'Magacin' },
  { id: 'zaduzenja', label: 'Zaduženja' },
  { id: 'inventar', label: 'Inventar alata i opreme' },
  { id: 'rezni-alat', label: 'Rezni alat' },
];

let mountRoot = null;
let docsOffset = 0;
let toolsOffset = 0;
let accumulatedDocs = [];
let accumulatedTools = [];
const toolSelected = new Set();
const PAGE = 25;

function loadTab() {
  return ssGet(`sess:${STORAGE_KEYS.REVERSI_TAB}`, 'zaduzenja') || 'zaduzenja';
}
function saveTab(id) {
  ssSet(`sess:${STORAGE_KEYS.REVERSI_TAB}`, id);
}

function recipientLabel(d) {
  if (d.recipient_employee_name) return d.recipient_employee_name;
  if (d.recipient_department) return d.recipient_department;
  if (d.recipient_company_name) return d.recipient_company_name;
  return '—';
}

function initialsFromName(name) {
  if (!name || name === '—') return '?';
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function avatarHueClass(str) {
  const s = String(str || '');
  let h = 0;
  for (let i = 0; i < s.length; i += 1) h = (h + s.charCodeAt(i) * (i + 7)) % 360;
  const presets = [210, 145, 280, 25, 340, 95];
  const hue = presets[h % presets.length];
  return `style="--rev-av-h:${hue}"`;
}

function docStatusPresentation(st) {
  const m = {
    OPEN: { cls: 'rev-pill--blue', text: 'Aktivno' },
    PARTIALLY_RETURNED: { cls: 'rev-pill--amber', text: 'Delimično vraćeno' },
    RETURNED: { cls: 'rev-pill--green', text: 'Vraćeno' },
    CANCELLED: { cls: 'rev-pill--muted', text: 'Otkazano' },
  };
  return m[st] || { cls: 'rev-pill--muted', text: String(st || '—') };
}

function toolStatusPresentation(tool) {
  if (tool.status === 'scrapped') return { cls: 'rev-pill--muted', text: 'Otpisan' };
  if (tool.status === 'lost') return { cls: 'rev-pill--red', text: 'Izgubljen' };
  if (tool.status === 'active') return { cls: 'rev-pill--green', text: 'Aktivan' };
  return { cls: 'rev-pill--muted', text: tool.status || '—' };
}

/** Jedna red = jedna evidencijska jedinica (C1). HTML za kolonu zaduženja / lokacija. */
function toolIssuanceCellHtml(t) {
  const issued = !!t.issued_holder;
  if (!issued) {
    const loc = t.current_location_code
      ? `Magacin · ${t.current_location_code}`
      : 'U magacinu';
    return `<div class="rev-iss-line"><span class="rev-iss-free">Slobodan za izdavanje</span></div><div class="rev-loc-hint">${escHtml(loc)}</div>`;
  }
  const d = t.issued_holder?.doc;
  const num = d?.doc_number ? escHtml(String(d.doc_number)) : '—';
  let who = 'Primalac';
  if (d?.recipient_type === 'EMPLOYEE' && d.recipient_employee_name) who = d.recipient_employee_name;
  else if (d?.recipient_type === 'DEPARTMENT' && d.recipient_department) who = d.recipient_department;
  else if (d?.recipient_company_name) who = d.recipient_company_name;
  return `<div class="rev-iss-line"><span class="rev-iss-busy">Na reversu</span></div><div class="rev-loc-hint"><span class="rev-mono">${num}</span> · ${escHtml(who)}</div>`;
}

/** ISO opseg za `issued_at` iz vrednosti `<input type="month">` (YYYY-MM). */
function issuedRangeFromMonth(ym) {
  const s = String(ym || '').trim();
  if (!/^\d{4}-\d{2}$/.test(s)) return {};
  const [ys, ms] = s.split('-');
  const y = Number(ys);
  const mo = Number(ms);
  if (!y || !mo || mo > 12) return {};
  const start = new Date(Date.UTC(y, mo - 1, 1, 0, 0, 0, 0));
  const end = new Date(Date.UTC(y, mo, 0, 23, 59, 59, 999));
  return { issued_from: start.toISOString(), issued_to: end.toISOString() };
}

function downloadCsv(filename, csvBody) {
  const blob = new Blob([CSV_BOM + csvBody], { type: 'text/csv;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
  URL.revokeObjectURL(a.href);
}

function docFetchParamsFromUi(f) {
  const range = issuedRangeFromMonth(f.issuedMonth);
  const base = { doc_type: f.doc_type || '', search: f.search || '', ...range };
  switch (f.uiStatus) {
    case 'aktivno':
      return { ...base, statuses: ['OPEN', 'PARTIALLY_RETURNED'] };
    case 'vraceno':
      return { ...base, status: 'RETURNED' };
    case 'prekoraceno':
      return { ...base, overdue: true };
    case 'otkazano':
      return { ...base, status: 'CANCELLED' };
    default:
      return { ...base, status: 'ALL' };
  }
}

/** Zajednički period / pretraga / tip za KPI (bez segmenta statusa u toolbaru). */
function docListContextFilters(f) {
  const range = issuedRangeFromMonth(f.issuedMonth);
  return {
    ...range,
    doc_type: f.doc_type || '',
    search: f.search || '',
  };
}

function normCsvHeader(s) {
  return String(s || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '_')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

function csvPickColumn(headers, aliases) {
  const hs = headers.map(normCsvHeader);
  for (const a of aliases) {
    const i = hs.indexOf(normCsvHeader(a));
    if (i >= 0) return i;
  }
  return -1;
}

export function teardownReversiModule() {
  mountRoot = null;
  teardownReznialatTab();
  teardownMojaZaduzenjaTab();
  teardownMagacinTab();
  teardownCuttingByViews();
}

/**
 * @param {HTMLElement} root
 * @param {{ onBackToHub: () => void, onLogout: () => void }} opts
 */
export function renderReversiModule(root, { onBackToHub, onLogout } = {}) {
  if (!canAccessReversi()) {
    showToast('Prijavi se da otvoriš Reversi');
    onBackToHub?.();
    return;
  }

  mountRoot = root;
  let activeTab = loadTab();
  if (!TABS.find((t) => t.id === activeTab)) activeTab = 'moja';
  let magacinId = null;
  let locations = [];

  let docFilters = {
    uiStatus: 'sve',
    search: '',
    doc_type: '',
    issuedMonth: ssGet(`sess:${STORAGE_KEYS.REVERSI_ISSUED_MONTH}`, '') || '',
  };
  let toolFilters = { status: 'active', search: '', asset_kind: 'ALL' };
  let docsTotal = null;
  let toolsTotal = null;
  let tabCountZ = null;
  let tabCountI = null;
  let tabCountR = null;
  let myIssued = [];
  let myIssuedOpen = true;

  let docDeb = null;
  let toolDeb = null;

  root.innerHTML = `
    <div class="kadrovska-layout module-reversi" id="revShell">
      <div id="revHubSlot"></div>
      <main class="kadrovska-main rev-main">
        <div id="revTabBody"></div>
      </main>
    </div>`;

  function toolExportRow(t) {
    const st = toolStatusPresentation(t);
    let zad = '';
    if (!t.issued_holder) {
      zad = t.current_location_code ? `Slobodan, magacin ${t.current_location_code}` : 'Slobodan u magacinu';
    } else {
      const d = t.issued_holder?.doc;
      const num = d?.doc_number != null ? String(d.doc_number) : '';
      zad = num ? `Na reversu ${num}` : 'Na reversu';
    }
    return [t.oznaka, formatRevAssetKind(t.asset_kind), t.naziv, st.text, zad];
  }

  async function runToolCsvImport(text) {
    const { headers, rows } = parseCsv(text);
    if (!headers.length || rows.length === 0) {
      showToast('CSV nema podatnih redova');
      return;
    }
    const iOz = csvPickColumn(headers, ['oznaka', 'šifra', 'sifra', 'code']);
    const iNz = csvPickColumn(headers, ['naziv', 'name', 'opis']);
    if (iOz < 0 || iNz < 0) {
      showToast('CSV mora imati kolone oznaka i naziv (zaglavlje prvog reda)');
      return;
    }
    const iSn = csvPickColumn(headers, ['serijski_broj', 'serijski broj', 'sn', 'serial']);
    const iDt = csvPickColumn(headers, ['datum_kupovine', 'datum kupovine']);
    const iNo = csvPickColumn(headers, ['napomena', 'note']);
    const iKind = csvPickColumn(headers, ['asset_kind', 'klasa', 'vrsta', 'kategorija', 'tip_stavke']);
    let ok = 0;
    let fail = 0;
    const magId = magacinId || (await getMagacinLocationId());
    for (const r of rows) {
      const oz = r[iOz]?.trim();
      const nz = r[iNz]?.trim();
      if (!oz || !nz) {
        fail += 1;
        continue;
      }
      const row = {
        oznaka: oz,
        naziv: nz,
        asset_kind: parseRevAssetKindCsv(iKind >= 0 ? r[iKind] : ''),
        serijski_broj: iSn >= 0 ? r[iSn]?.trim() || null : null,
        datum_kupovine: iDt >= 0 ? r[iDt]?.trim() || null : null,
        napomena: iNo >= 0 ? r[iNo]?.trim() || null : null,
        status: 'active',
      };
      const ins = await insertTool(row);
      if (!ins.ok) {
        fail += 1;
        continue;
      }
      if (magId) {
        const pl = await initialPlacementForTool(ins.data.loc_item_ref_id, magId);
        if (!pl.ok) {
          fail += 1;
          continue;
        }
      }
      ok += 1;
    }
    clearMagacinLocationCache();
    showToast(`Uvoz završen: ${ok} uspešno, ${fail} preskočeno ili greška`);
    void refreshBody();
  }

  function countLabel(n) {
    return n == null ? '…' : String(n);
  }

  function paintChrome() {
    const hub = root.querySelector('#revHubSlot');
    const auth = getAuth();
    hub.innerHTML = `
      <header class="rev-top-header">
        <div class="rev-top-header-inner">
          <div class="rev-top-left">
            <button type="button" class="rev-btn-back" id="revBackBtn">
              <span class="rev-back-arrow">←</span> Moduli
            </button>
            <div class="rev-brand">
              <div class="rev-brand-icon" aria-hidden="true">${revIcon('rotate', 22, 'rev-ic')}</div>
              <div class="rev-brand-text">
                <h1 class="rev-brand-title">Reversi</h1>
                <span class="rev-brand-sub">Alat, radna odeća, cipele i zaštitna oprema</span>
              </div>
            </div>
          </div>
          <div class="rev-top-right">
            <button type="button" class="rev-icon-btn" id="revThemeBtn" title="Tema">🌙</button>
            <div class="rev-user-block">
              <span class="rev-role-pill">${escHtml((auth.role || '').toUpperCase())}</span>
              <button type="button" class="rev-logout" id="revLogoutBtn">Odjavi se</button>
            </div>
          </div>
        </div>
      </header>
      <nav class="rev-tab-strip" role="tablist">
        ${TABS.map(
          (t) => {
            const icon = t.id === 'zaduzenja' ? ICON_TAB_ZAD
              : t.id === 'inventar' ? ICON_TAB_INV
              : t.id === 'rezni-alat' ? ICON_TAB_RZN
              : t.id === 'magacin' ? ICON_TAB_MAG
              : ICON_TAB_MOJ;
            const cnt = t.id === 'zaduzenja' ? tabCountZ
              : t.id === 'inventar' ? tabCountI
              : t.id === 'rezni-alat' ? tabCountR
              : null;
            return `
          <button type="button" role="tab" class="rev-strip-tab ${activeTab === t.id ? 'is-active' : ''}" data-rev-tab="${escHtml(t.id)}">
            ${icon}
            <span class="rev-strip-label">${escHtml(t.label)}</span>
            <span class="rev-strip-count ${activeTab === t.id ? 'is-active' : ''}" data-rev-tab-count="${escHtml(t.id)}">${escHtml(countLabel(cnt))}</span>
          </button>`;
          },
        ).join('')}
      </nav>`;

    root.querySelector('#revBackBtn')?.addEventListener('click', () => onBackToHub?.());
    root.querySelector('#revThemeBtn')?.addEventListener('click', () => toggleTheme());
    root.querySelector('#revLogoutBtn')?.addEventListener('click', async () => {
      await logout();
      onLogout?.();
    });
    root.querySelectorAll('[data-rev-tab]').forEach((btn) => {
      btn.addEventListener('click', () => {
        activeTab = btn.getAttribute('data-rev-tab') || 'zaduzenja';
        saveTab(activeTab);
        docsOffset = 0;
        toolsOffset = 0;
        accumulatedDocs = [];
        accumulatedTools = [];
        paintChrome();
        void refreshBody();
      });
    });
  }

  function setTabCounts(z, i, rcnt) {
    if (z != null) tabCountZ = z;
    if (i != null) tabCountI = i;
    if (rcnt != null) tabCountR = rcnt;
    const ez = root.querySelector('[data-rev-tab-count="zaduzenja"]');
    const ei = root.querySelector('[data-rev-tab-count="inventar"]');
    const er = root.querySelector('[data-rev-tab-count="rezni-alat"]');
    if (z != null && ez) ez.textContent = countLabel(z);
    if (i != null && ei) ei.textContent = countLabel(i);
    if (rcnt != null && er) er.textContent = countLabel(rcnt);
  }

  async function ensureMeta() {
    magacinId = await getMagacinLocationId();
    const locRes = await fetchActiveLocations();
    locations = locRes.ok && Array.isArray(locRes.data) ? locRes.data : [];
  }

  async function loadMyIssued() {
    const r = await fetchMyIssuedTools();
    myIssued = r.ok && Array.isArray(r.data) ? r.data : [];
  }

  async function refreshBody() {
    const body = root.querySelector('#revTabBody');
    if (!body) return;

    if (!hasSupabaseConfig()) {
      body.innerHTML = `<div class="rev-empty-card"><p>Supabase nije konfigurisan.</p></div>`;
      return;
    }

    body.innerHTML = `<div class="rev-loading-card">Učitavanje…</div>`;

    if (activeTab === 'moja') {
      await renderMojaZaduzenjaTab(body);
      return;
    }

    if (activeTab === 'magacin') {
      await renderMagacinTab(body);
      return;
    }

    await ensureMeta();

    if (activeTab === 'rezni-alat') {
      await renderReznialatTab(body, {
        onIssueScan: () => {
          openCuttingToolIssueScannerModal({ onSuccess: () => void refreshBody() });
        },
        onReturnScan: () => {
          openCuttingToolReturnScannerModal({ onSuccess: () => void refreshBody() });
        },
      });
      return;
    }

    if (activeTab === 'zaduzenja') {
      await loadMyIssued();

      const ctx = docListContextFilters(docFilters);
      const [cOpen, cPart, cRet, cOver, cCan, recip] = await Promise.all([
        fetchDocuments({ status: 'OPEN', limit: 1, offset: 0, ...ctx }),
        fetchDocuments({ status: 'PARTIALLY_RETURNED', limit: 1, offset: 0, ...ctx }),
        fetchDocuments({ status: 'RETURNED', limit: 1, offset: 0, ...ctx }),
        fetchDocuments({ overdue: true, limit: 1, offset: 0, ...ctx }),
        fetchDocuments({ status: 'CANCELLED', limit: 1, offset: 0, ...ctx }),
        fetchOpenRecipientCardinality({ ...ctx, cap: 2500 }),
      ]);
      const nOpen = cOpen.ok ? cOpen.data?.total ?? 0 : 0;
      const nPart = cPart.ok ? cPart.data?.total ?? 0 : 0;
      const nAkt = nOpen + nPart;
      const nRet = cRet.ok ? cRet.data?.total ?? 0 : 0;
      const nOver = cOver.ok ? cOver.data?.total ?? 0 : 0;
      const nCan = cCan.ok ? cCan.data?.total ?? 0 : 0;
      const nRecip = recip.ok ? recip.data?.count ?? 0 : 0;
      const nRecipTrunc = !!(recip.ok && recip.data?.truncated);

      const invHead = await fetchTools({ status: 'active', limit: 1, offset: 0, search: '' });
      const invTotal = invHead.ok ? invHead.data?.total ?? null : null;
      setTabCounts(nAkt, invTotal != null ? invTotal : undefined);

      const fetchP = { ...docFetchParamsFromUi(docFilters), limit: PAGE, offset: docsOffset };
      const dr = await fetchDocuments(fetchP);
      const batch = dr.ok && dr.data?.rows ? dr.data.rows : [];
      docsTotal = dr.ok ? dr.data?.total : null;
      if (docsOffset === 0) accumulatedDocs = batch;
      else accumulatedDocs = accumulatedDocs.concat(batch);
      const rows = accumulatedDocs;

      const myBlock =
        myIssued.length > 0
          ? `<details class="rev-my-panel" ${myIssuedOpen ? 'open' : ''}>
          <summary>Moja trenutna zaduženja <span class="rev-my-panel-badge">${myIssued.length}</span></summary>
          <ul class="rev-my-list">${myIssued.map((r) => `<li><strong>${escHtml(r.naziv)}</strong> <span class="rev-muted">(${escHtml(r.oznaka)})</span> · zadužio ${fmtDateShort(r.issued_at)}</li>`).join('')}</ul>
        </details>`
          : '';

      body.innerHTML = `
        <div class="rev-print-area">
        <p class="rev-module-hint">Pregled <strong>revers dokumenata</strong>: izdavanje alata i robe kooperantu uz rok povraćaja. Jedan dokument može sadržati više stavki (alatki).</p>
        <div class="rev-stat-grid rev-stat-grid--kpi-zad">
          <div class="rev-stat-card rev-stat-card--primary">
            <div class="rev-stat-label">Aktivna zaduženja</div>
            <div class="rev-stat-value">${nAkt}</div>
            <div class="rev-stat-hint">dokumenti u radu (otvoreni ili delimično vraćeni), u skladu sa filterom ispod</div>
          </div>
          <div class="rev-stat-card ${nOver > 0 ? 'rev-stat-card--alert' : ''}">
            <div class="rev-stat-label">Prekoračen rok</div>
            <div class="rev-stat-value">${nOver}</div>
            <div class="rev-stat-hint">${nOver > 0 ? 'Rok je istekao, revers još nije zatvoren' : 'Nema aktivnih dokumenata sa isteklim rokom'}</div>
          </div>
          <div class="rev-stat-card rev-stat-card--ok">
            <div class="rev-stat-label">Uspešno vraćeno</div>
            <div class="rev-stat-value">${nRet}</div>
            <div class="rev-stat-hint">dokumenti zatvoreni povraćajem</div>
          </div>
          <div class="rev-stat-card">
            <div class="rev-stat-label">Otkazano</div>
            <div class="rev-stat-value">${nCan}</div>
            <div class="rev-stat-hint">poništeni dokumenti pre zatvaranja</div>
          </div>
          <div class="rev-stat-card rev-stat-card--teal">
            <div class="rev-stat-label">Primaoci (aktivno)</div>
            <div class="rev-stat-value">${nRecip}${nRecipTrunc ? '+' : ''}</div>
            <div class="rev-stat-hint">${
              nRecipTrunc
                ? 'Različiti primaoci u uzorku; stvarni broj može biti veći'
                : 'Različiti primaoci na aktivnim reversima (otvoreno / delimično)'
            }</div>
          </div>
        </div>

        <div class="rev-panel rev-toolbar-panel">
          <div class="rev-field rev-field--grow">
            <label class="rev-field-label">Pretraga</label>
            <input type="search" id="revDocSearch" class="rev-input rev-input--search" placeholder="Broj dokumenta ili ime primaoca…" value="${escHtml(docFilters.search)}"/>
          </div>
          <div class="rev-field rev-field--month">
            <label class="rev-field-label">Mesec izdavanja</label>
            <div class="rev-month-row">
              <input type="month" id="revIssuedMonth" class="rev-input" value="${escHtml(docFilters.issuedMonth)}"/>
              <button type="button" class="rev-btn rev-btn--secondary" id="revIssuedMonthAll" title="Prikaži sve mesece">Svi</button>
            </div>
          </div>
          <div class="rev-field">
            <label class="rev-field-label">Status dokumenta</label>
            <div class="rev-seg" role="group">
              ${(
                [
                  ['sve', 'Sve'],
                  ['aktivno', 'U toku'],
                  ['prekoraceno', 'Rok istekao'],
                  ['vraceno', 'Završeno'],
                  ['otkazano', 'Otkazano'],
                ] 
              )
                .map(
                  ([id, lab]) => `
                <button type="button" class="rev-seg-btn ${docFilters.uiStatus === id ? 'is-on' : ''}" data-rev-doc-st="${id}">${lab}</button>`,
                )
                .join('')}
            </div>
          </div>
          <div class="rev-field">
            <label class="rev-field-label">Tip dokumenta</label>
            <select id="revDocType" class="rev-select">
              <option value="" ${docFilters.doc_type === '' ? 'selected' : ''}>Svi tipovi</option>
              <option value="TOOL" ${docFilters.doc_type === 'TOOL' ? 'selected' : ''}>Revers alata</option>
              <option value="COOPERATION_GOODS" ${docFilters.doc_type === 'COOPERATION_GOODS' ? 'selected' : ''}>Kooperaciona roba</option>
            </select>
          </div>
          <div class="rev-toolbar-actions">
            <button type="button" class="rev-btn rev-btn--secondary" id="revBtnExportDocsCsv">Export CSV</button>
            <button type="button" class="rev-btn rev-btn--secondary" id="revBtnPrintZad">Štampa prikaza</button>
            ${canManageReversi() ? `<button type="button" class="rev-btn rev-btn--primary" id="revBtnQuickIssue">+ Quick Issue</button>` : ''}
            ${canManageReversi() ? `<button type="button" class="rev-btn rev-btn--primary" id="revBtnNewDoc">+ Novo zaduženje</button>` : ''}
          </div>
        </div>
        <button type="button" class="rev-quick-fab rev-btn rev-btn--primary" id="revZadQuickIssueFab">+ Quick Issue</button>
        ${myBlock}
        <div id="revDocTableHost"></div>
        </div>`;

      const dtHost = body.querySelector('#revDocTableHost');
      if (rows.length === 0) {
        dtHost.innerHTML = `<div class="rev-empty-card"><p>Nema revers dokumenata koji odgovaraju filteru.</p><p class="rev-muted">Pokušajte „Sve“ ili drugu pretragu.</p>${canManageReversi() ? '<p><button type="button" class="rev-btn rev-btn--primary" id="revEmptyNew">Kreiraj prvi dokument</button></p>' : ''}</div>`;
        body.querySelector('#revEmptyNew')?.addEventListener('click', () =>
          openIssueReversalModal({ onSuccess: () => void refreshBody() }),
        );
      } else {
        const today = new Date().toISOString().slice(0, 10);
        dtHost.innerHTML = `
          <div class="rev-table-shell">
            <table class="rev-data-table">
              <thead><tr>
                <th>Br. dokumenta</th><th>Datum izdavanja</th><th>Primalac</th><th class="rev-th-num">Stavki</th><th>Rok povraćaja</th><th>Status</th><th class="rev-th-actions">Akcije</th>
              </tr></thead>
              <tbody>${rows
                .map((d) => {
                  const overdue =
                    d.expected_return_date &&
                    (d.status === 'OPEN' || d.status === 'PARTIALLY_RETURNED') &&
                    String(d.expected_return_date) < today;
                  const rl = recipientLabel(d);
                  const ini = initialsFromName(rl);
                  const av = avatarHueClass(rl);
                  const canRet =
                    canManageReversi() && (d.status === 'OPEN' || d.status === 'PARTIALLY_RETURNED');
                  const st = docStatusPresentation(d.status);
                  return `<tr data-doc-id="${escHtml(d.id)}" class="${overdue ? 'is-overdue' : ''}">
                    <td><span class="rev-mono rev-linkish">${escHtml(d.doc_number)}</span></td>
                    <td class="rev-td-muted">${fmtDateShort(d.issued_at)}</td>
                    <td>
                      <div class="rev-person">
                        <span class="rev-avatar" ${av}>${escHtml(ini)}</span>
                        <span class="rev-person-name">${escHtml(rl)}</span>
                      </div>
                    </td>
                    <td class="rev-td-center"><span class="rev-count-pill">${escHtml(String(d.line_count ?? 0))}</span></td>
                    <td class="${overdue ? 'rev-td-warn' : ''}">${d.expected_return_date ? fmtDateShort(d.expected_return_date) : '—'}${overdue ? ' <span class="rev-warn-icon" title="Prekoračen rok">!</span>' : ''}</td>
                    <td><span class="rev-pill ${st.cls}">${escHtml(st.text)}</span></td>
                    <td class="rev-td-actions">
                      <button type="button" class="rev-act-btn" title="Detalji" data-act="det" data-id="${escHtml(d.id)}">👁</button>
                      ${canRet ? `<button type="button" class="rev-act-btn" title="Potvrdi povraćaj" data-act="ret" data-id="${escHtml(d.id)}">↩</button>` : ''}
                      <button type="button" class="rev-act-btn" title="Potpisnica PDF" data-act="pdf" data-pdf-btn="${escHtml(d.id)}" data-num="${escHtml(d.doc_number)}">📄</button>
                    </td>
                  </tr>`;
                })
                .join('')}
              </tbody>
            </table>
          </div>
          <div class="rev-pager">
            <span class="rev-muted">Prikazano ${rows.length}${docsTotal != null ? ` od ${docsTotal} dokumenata` : ''}</span>
            ${docsOffset + rows.length < (docsTotal ?? Infinity) ? `<button type="button" class="rev-btn rev-btn--secondary" id="revDocMore">Učitaj još</button>` : ''}
          </div>`;

        dtHost.querySelectorAll('[data-act="det"]').forEach((btn) => {
          btn.addEventListener('click', () => {
            const did = btn.getAttribute('data-id');
            const doc = rows.find((r) => r.id === did);
            if (!doc) return;
            openDocumentDetailsModal({
              document: doc,
              onPdfSuccess: () => void refreshBody(),
            });
          });
        });

        dtHost.querySelectorAll('[data-act="pdf"]').forEach((btn) => {
          btn.addEventListener('click', async () => {
            const did = btn.getAttribute('data-pdf-btn');
            const num = btn.getAttribute('data-num');
            const doc = rows.find((r) => r.id === did);
            btn.disabled = true;
            btn.textContent = '⏳';
            try {
              await handleReversalPdfClick({ docId: did, docNumber: num, docRow: doc });
            } catch (e) {
              showToast(`Greška pri generisanju PDF-a: ${e instanceof Error ? e.message : String(e)}`, 'error');
            } finally {
              btn.disabled = false;
              btn.textContent = '📄';
            }
          });
        });
        dtHost.querySelectorAll('[data-act="ret"]').forEach((btn) => {
          btn.addEventListener('click', () => {
            const did = btn.getAttribute('data-id');
            const doc = rows.find((r) => r.id === did);
            if (!doc) return;
            openConfirmReturnModal({
              document: doc,
              magacinLocationId: magacinId,
              locations,
              onSuccess: () => void refreshBody(),
            });
          });
        });

        dtHost.querySelector('#revDocMore')?.addEventListener('click', () => {
          docsOffset += PAGE;
          void refreshBody();
        });
      }

      const openQiZad = () => openQuickIssueModal({ onSuccess: () => void refreshBody() });
      body.querySelector('#revBtnQuickIssue')?.addEventListener('click', openQiZad);
      body.querySelector('#revZadQuickIssueFab')?.addEventListener('click', openQiZad);
      body.querySelector('#revBtnNewDoc')?.addEventListener('click', () =>
        openIssueReversalModal({ onSuccess: () => void refreshBody() }),
      );
      body.querySelector('#revBtnExportDocsCsv')?.addEventListener('click', () => {
        if (accumulatedDocs.length === 0) {
          showToast('Nema redova za izvoz');
          return;
        }
        const headers = ['Broj dokumenta', 'Datum izdavanja', 'Primalac', 'Stavki', 'Rok povraćaja', 'Status'];
        const data = accumulatedDocs.map((d) => {
          const st = docStatusPresentation(d.status);
          return [
            d.doc_number,
            fmtDateShort(d.issued_at),
            recipientLabel(d),
            d.line_count ?? 0,
            d.expected_return_date ? fmtDateShort(d.expected_return_date) : '',
            st.text,
          ];
        });
        const slug = (docFilters.issuedMonth || 'svi-meseci').replace(/-/g, '');
        downloadCsv(`reversi-dokumenti-${slug}.csv`, rowsToCsv(headers, data));
      });

      body.querySelector('#revIssuedMonth')?.addEventListener('change', (e) => {
        const t = e.target;
        docFilters.issuedMonth = t && 'value' in t ? String(t.value || '') : '';
        ssSet(`sess:${STORAGE_KEYS.REVERSI_ISSUED_MONTH}`, docFilters.issuedMonth);
        docsOffset = 0;
        accumulatedDocs = [];
        void refreshBody();
      });
      body.querySelector('#revIssuedMonthAll')?.addEventListener('click', () => {
        docFilters.issuedMonth = '';
        const inp = body.querySelector('#revIssuedMonth');
        if (inp && 'value' in inp) inp.value = '';
        ssSet(`sess:${STORAGE_KEYS.REVERSI_ISSUED_MONTH}`, '');
        docsOffset = 0;
        accumulatedDocs = [];
        void refreshBody();
      });

      body.querySelector('#revBtnPrintZad')?.addEventListener('click', () => window.print());

      body.querySelectorAll('[data-rev-doc-st]').forEach((btn) => {
        btn.addEventListener('click', () => {
          docFilters.uiStatus = btn.getAttribute('data-rev-doc-st') || 'sve';
          docsOffset = 0;
          accumulatedDocs = [];
          void refreshBody();
        });
      });
      body.querySelector('#revDocType')?.addEventListener('change', (e) => {
        docFilters.doc_type = e.target.value;
        docsOffset = 0;
        accumulatedDocs = [];
        void refreshBody();
      });
      body.querySelector('#revDocSearch')?.addEventListener('input', (e) => {
        clearTimeout(docDeb);
        docDeb = setTimeout(() => {
          docFilters.search = e.target.value;
          docsOffset = 0;
          accumulatedDocs = [];
          void refreshBody();
        }, 300);
      });

      const det = body.querySelector('.rev-my-panel');
      det?.addEventListener('toggle', () => {
        myIssuedOpen = det.open;
      });

      return;
    }

    /* inventar */
    const ctxTab = docListContextFilters(docFilters);
    const [invStats, tr, cOpenTab, cPartTab] = await Promise.all([
      fetchTools({ status: 'active', limit: 2000, offset: 0, search: '' }),
      fetchTools({
        status: toolFilters.status,
        search: toolFilters.search,
        asset_kind: toolFilters.asset_kind,
        limit: PAGE,
        offset: toolsOffset,
      }),
      fetchDocuments({ status: 'OPEN', limit: 1, offset: 0, ...ctxTab }),
      fetchDocuments({ status: 'PARTIALLY_RETURNED', limit: 1, offset: 0, ...ctxTab }),
    ]);
    const nAktTab =
      (cOpenTab.ok ? cOpenTab.data?.total ?? 0 : 0) + (cPartTab.ok ? cPartTab.data?.total ?? 0 : 0);

    let nMag = 0;
    let nZad = 0;
    let nActTotal = 0;
    if (invStats.ok && invStats.data?.rows) {
      const r0 = invStats.data.rows;
      nActTotal = invStats.data.total ?? r0.length;
      nZad = r0.filter((t) => t.issued_holder).length;
      nMag = r0.length - nZad;
    }
    const cScrap = await fetchTools({ status: 'scrapped', limit: 1, offset: 0, search: '' });
    const nScrap = cScrap.ok ? cScrap.data?.total ?? 0 : 0;

    const invTabTotal = invStats.ok ? invStats.data?.total : null;
    setTabCounts(nAktTab, invTabTotal != null ? invTabTotal : undefined);

    const batch = tr.ok && tr.data?.rows ? tr.data.rows : [];
    toolsTotal = tr.ok ? tr.data?.total : null;
    if (toolsOffset === 0) accumulatedTools = batch;
    else accumulatedTools = accumulatedTools.concat(batch);
    const trows = accumulatedTools;

    const moreThanSample = invStats.ok && (invStats.data?.total ?? 0) > (invStats.data?.rows?.length ?? 0);

    const sampleN = invStats.data?.rows?.length ?? 0;
    const statCardHintMagZad = moreThanSample
      ? `Procena iz prvih ${sampleN} jedinica; ukupno aktivnih u bazi: ${nActTotal}.`
      : 'Kompletan skup aktivnih jedinica u bazi.';

    body.innerHTML = `
      <div class="rev-print-area">
      <p class="rev-module-hint"><strong>Inventar</strong>: svaki red u tabeli je <strong>jedna evidencijska jedinica</strong> (jedan fizički komad alata). Ista oznaka može se pojaviti u više redova ako postoji više primeraka.</p>
      <div class="rev-stat-grid">
        <div class="rev-stat-card rev-stat-card--primary">
          <div class="rev-stat-label">Aktivne jedinice</div>
          <div class="rev-stat-value">${nActTotal}</div>
          <div class="rev-stat-hint">Ukupan broj alata u statusu „aktivan” (svaki komad = jedna stavka)</div>
        </div>
        <div class="rev-stat-card rev-stat-card--ok">
          <div class="rev-stat-label">Slobodno u magacinu</div>
          <div class="rev-stat-value">${nMag}${moreThanSample ? '+' : ''}</div>
          <div class="rev-stat-hint">${statCardHintMagZad} Nije na aktivnom reversu.</div>
        </div>
        <div class="rev-stat-card rev-stat-card--amber">
          <div class="rev-stat-label">Na reversu</div>
          <div class="rev-stat-value">${nZad}${moreThanSample ? '+' : ''}</div>
          <div class="rev-stat-hint">${statCardHintMagZad} Trenutno izdato aktivnim dokumentom.</div>
        </div>
        <div class="rev-stat-card ${nScrap > 0 ? 'rev-stat-card--alert' : ''}">
          <div class="rev-stat-label">Otpisano (rashod)</div>
          <div class="rev-stat-value">${nScrap}</div>
          <div class="rev-stat-hint">Jedinice u statusu otpisan — više se ne izdaju</div>
        </div>
      </div>

      <div class="rev-panel rev-toolbar-panel">
        <div class="rev-field rev-field--grow">
          <label class="rev-field-label">Pretraga po oznaci ili nazivu</label>
          <input type="search" id="revToolSearch" class="rev-input rev-input--search" placeholder="npr. AL-001 ili naziv alata…" value="${escHtml(toolFilters.search)}"/>
        </div>
        <div class="rev-field">
          <label class="rev-field-label">Klasa stavke</label>
          <select id="revToolKind" class="rev-select">
            <option value="ALL" ${toolFilters.asset_kind === 'ALL' || !toolFilters.asset_kind ? 'selected' : ''}>Sve</option>
            ${REV_ASSET_KIND_OPTIONS.map(
              (k) =>
                `<option value="${escHtml(k)}" ${toolFilters.asset_kind === k ? 'selected' : ''}>${escHtml(REV_ASSET_KIND_LABEL[k])}</option>`,
            ).join('')}
          </select>
        </div>
        <div class="rev-field">
          <label class="rev-field-label">Status u evidenciji</label>
          <select id="revToolSt" class="rev-select">
            <option value="active" ${toolFilters.status === 'active' ? 'selected' : ''}>Aktivan (može se izdati)</option>
            <option value="scrapped" ${toolFilters.status === 'scrapped' ? 'selected' : ''}>Otpisan</option>
            <option value="lost" ${toolFilters.status === 'lost' ? 'selected' : ''}>Izgubljen</option>
            <option value="all" ${toolFilters.status === 'all' ? 'selected' : ''}>Svi zapisi</option>
          </select>
        </div>
        <div class="rev-toolbar-actions rev-toolbar-actions--wide">
          ${
            canManageReversi()
              ? `<button type="button" class="rev-btn rev-btn--primary rev-quick-issue-btn" id="revInvQuickIssue">+ Quick Issue</button>`
              : ''
          }
          ${
            canManageReversi()
              ? `<div class="rev-split" id="revInvAddSplit">
            <div class="rev-split-main">
              <button type="button" class="rev-btn rev-btn--primary rev-split-primary" id="revBtnAddTool">+ Nova jedinica</button>
              <button type="button" class="rev-btn rev-btn--primary rev-split-caret" id="revInvAddCaret" aria-expanded="false" aria-haspopup="true" title="Još akcija za unos">▾</button>
            </div>
            <div class="rev-split-dropdown" id="revInvAddMenu" role="menu">
              <button type="button" class="rev-split-item" role="menuitem" id="revToolCsvImportBtn">Uvoz CSV…</button>
              <button type="button" class="rev-split-item" role="menuitem" id="revToolCatalogStub">Iz kataloga…</button>
            </div>
          </div>`
              : ''
          }
          <button type="button" class="rev-btn rev-btn--secondary" id="revBtnExportToolsCsv">Export CSV</button>
        </div>
      </div>
      <input type="file" id="revToolCsvFile" accept=".csv,text/csv" hidden />
      ${
        canManageReversi() && toolSelected.size > 0
          ? `<div class="rev-bulk-bar">
        <span>${toolSelected.size} odabrano</span>
        <button type="button" class="rev-btn rev-btn--primary" id="revInvBulkPrint">Štampa nalepnica (${toolSelected.size})</button>
        <button type="button" class="rev-btn rev-btn--secondary" id="revInvBulkClear">Poništi izbor</button>
      </div>`
          : ''
      }
      <button type="button" class="rev-quick-fab rev-btn rev-btn--primary" id="revInvQuickIssueFab">+ Quick Issue</button>
      <div id="revToolGridHost"></div>
      </div>`;

    const gh = body.querySelector('#revToolGridHost');
    if (trows.length === 0) {
      gh.innerHTML = `<div class="rev-empty-card"><p>Nema jedinica koje odgovaraju filteru.</p><p class="rev-muted">Proširite pretragu ili izaberite „Svi zapisi“ u statusu.</p>${canManageReversi() ? '<p class="rev-muted">Novi komad unosite kao posebnu jedinicu u evidenciji.</p>' : ''}</div>`;
    } else {
      gh.innerHTML = `
        <div class="rev-table-shell">
          <table class="rev-data-table">
            <thead><tr>
              ${canManageReversi() ? '<th class="rev-th-cb"><input type="checkbox" id="revInvSelAll"/></th>' : ''}
              <th>Oznaka</th><th>Klasa</th><th>Naziv / opis</th><th>Zaduženje i lokacija</th><th>Status jedinice</th><th class="rev-th-actions">Akcije</th>
            </tr></thead>
            <tbody>${trows
              .map((t) => {
                const issued = !!t.issued_holder;
                const st = toolStatusPresentation(t);
                const iss = toolIssuanceCellHtml(t);
                const showZaduži = canManageReversi() && !issued && t.status === 'active';
                const sel = toolSelected.has(t.id);
                return `<tr class="${sel ? 'rev-data-row--selected' : ''}">
                  ${
                    canManageReversi()
                      ? `<td class="rev-td-cb"><input type="checkbox" data-rev-inv-select="${escHtml(t.id)}" ${sel ? 'checked' : ''} ${t.barcode ? '' : 'disabled title="Nema barkoda"'}/></td>`
                      : ''
                  }
                  <td class="rev-mono rev-strong">${escHtml(t.oznaka)}${t.barcode ? `<div class="rev-mono rev-muted rev-rzn-barcode">${escHtml(t.barcode)}</div>` : ''}</td>
                  <td><span class="rev-pill rev-pill--muted rev-pill--sm">${escHtml(formatRevAssetKind(t.asset_kind))}</span></td>
                  <td>${escHtml(t.naziv)}</td>
                  <td>${iss}</td>
                  <td><span class="rev-pill ${st.cls} rev-pill--sm">${escHtml(st.text)}</span></td>
                  <td class="rev-td-actions">
                    <button type="button" class="rev-act-btn" data-tool-det="${escHtml(t.id)}" title="Pregled jedinice">👁</button>
                    ${showZaduži ? `<button type="button" class="rev-act-btn rev-act-btn--primary" data-tool-zad="${escHtml(t.id)}" title="Izdaj na revers">+</button>` : ''}
                  </td>
                </tr>`;
              })
              .join('')}
            </tbody>
          </table>
        </div>
        <div class="rev-pager">
          <span class="rev-muted">Prikazano ${trows.length}${toolsTotal != null ? ` od ${toolsTotal} jedinica` : ''}</span>
          ${toolsOffset + trows.length < (toolsTotal ?? Infinity) ? `<button type="button" class="rev-btn rev-btn--secondary" id="revToolMore">Učitaj još</button>` : ''}
        </div>`;

      gh.querySelectorAll('[data-tool-det]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const tid = btn.getAttribute('data-tool-det');
          const t = trows.find((x) => x.id === tid);
          showToast(t ? `${t.oznaka}: ${t.naziv}` : 'Alat');
        });
      });
      gh.querySelectorAll('[data-tool-zad]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const tid = btn.getAttribute('data-tool-zad');
          const t = trows.find((x) => x.id === tid);
          if (t) openIssueReversalModal({ preselectedTool: t, onSuccess: () => void refreshBody() });
        });
      });
      gh.querySelector('#revToolMore')?.addEventListener('click', () => {
        toolsOffset += PAGE;
        void refreshBody();
      });
    }

    const openQiInv = () => openQuickIssueModal({ onSuccess: () => void refreshBody() });
    body.querySelector('#revInvQuickIssue')?.addEventListener('click', openQiInv);
    body.querySelector('#revInvQuickIssueFab')?.addEventListener('click', openQiInv);
    body.querySelector('#revInvSelAll')?.addEventListener('change', (e) => {
      if (e.target.checked) trows.forEach((t) => { if (t.barcode) toolSelected.add(t.id); });
      else toolSelected.clear();
      void refreshBody();
    });
    body.querySelectorAll('[data-rev-inv-select]').forEach((cb) => {
      cb.addEventListener('change', () => {
        const id = cb.getAttribute('data-rev-inv-select');
        if (cb.checked) toolSelected.add(id);
        else toolSelected.delete(id);
        void refreshBody();
      });
    });
    body.querySelector('#revInvBulkClear')?.addEventListener('click', () => {
      toolSelected.clear();
      void refreshBody();
    });
    body.querySelector('#revInvBulkPrint')?.addEventListener('click', () => {
      const picked = trows
        .filter((t) => toolSelected.has(t.id))
        .map((t) => ({
          grupa: 'HAND',
          kind: 'HAND',
          item_id: t.id,
          barcode: t.barcode,
          oznaka: t.oznaka,
          naziv: t.naziv,
          asset_kind: t.asset_kind,
          serijski_broj: t.serijski_broj,
        }));
      openBulkPrintLabelsModal({ rows: picked });
    });

    body.querySelector('#revBtnAddTool')?.addEventListener('click', () =>
      openAddToolModal({ onSuccess: () => void refreshBody() }),
    );

    const invSplit = body.querySelector('#revInvAddSplit');
    const invMenu = body.querySelector('#revInvAddMenu');
    const invCaret = body.querySelector('#revInvAddCaret');
    const closeInvSplit = () => {
      invSplit?.classList.remove('rev-split--open');
      invCaret?.setAttribute('aria-expanded', 'false');
    };
    invCaret?.addEventListener('click', (ev) => {
      ev.stopPropagation();
      const on = invSplit?.classList.toggle('rev-split--open');
      invCaret?.setAttribute('aria-expanded', on ? 'true' : 'false');
    });
    body.querySelector('#revToolCsvImportBtn')?.addEventListener('click', () => {
      closeInvSplit();
      body.querySelector('#revToolCsvFile')?.click();
    });
    body.querySelector('#revToolCatalogStub')?.addEventListener('click', () => {
      closeInvSplit();
      showToast('Uvoz iz kataloga uskoro.');
    });
    body.querySelector('#revToolCsvFile')?.addEventListener('change', async (ev) => {
      const input = ev.target;
      const f = input && 'files' in input ? input.files?.[0] : null;
      if (input && 'value' in input) input.value = '';
      if (!f) return;
      const text = await f.text();
      await runToolCsvImport(text);
    });

    body.querySelector('#revBtnExportToolsCsv')?.addEventListener('click', () => {
      if (trows.length === 0) {
        showToast('Nema redova za izvoz');
        return;
      }
      const headers = ['Oznaka', 'Klasa', 'Naziv', 'Status jedinice', 'Zaduženje / lokacija'];
      const data = trows.map((t) => toolExportRow(t));
      const st = toolFilters.status || 'svi';
      downloadCsv(`reversi-inventar-${st}.csv`, rowsToCsv(headers, data));
    });
    body.querySelector('#revToolSt')?.addEventListener('change', (e) => {
      toolFilters.status = e.target.value;
      toolsOffset = 0;
      accumulatedTools = [];
      void refreshBody();
    });
    body.querySelector('#revToolKind')?.addEventListener('change', (e) => {
      toolFilters.asset_kind = e.target.value;
      toolsOffset = 0;
      accumulatedTools = [];
      void refreshBody();
    });
    body.querySelector('#revToolSearch')?.addEventListener('input', (e) => {
      clearTimeout(toolDeb);
      toolDeb = setTimeout(() => {
        toolFilters.search = e.target.value;
        toolsOffset = 0;
        accumulatedTools = [];
        void refreshBody();
      }, 300);
    });
  }

  if (!root.dataset.revSplitCloseBound) {
    root.dataset.revSplitCloseBound = '1';
    root.addEventListener('click', (ev) => {
      const sp = root.querySelector('#revInvAddSplit');
      if (!sp?.classList.contains('rev-split--open')) return;
      if (!ev.target.closest('#revInvAddSplit')) {
        sp.classList.remove('rev-split--open');
        root.querySelector('#revInvAddCaret')?.setAttribute('aria-expanded', 'false');
      }
    });
  }

  paintChrome();
  void refreshBody();
}
