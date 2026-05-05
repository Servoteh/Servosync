/**
 * Reversi modul — zaduženja alata / kooperacija.
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
} from '../../services/reversiService.js';
import {
  openIssueReversalModal,
  openConfirmReturnModal,
  openAddToolModal,
  openDocumentDetailsModal,
  fmtDateShort,
  handleReversalPdfClick,
} from './modals.js';

const TABS = [
  { id: 'zaduzenja', label: 'Zaduženja' },
  { id: 'inventar', label: 'Inventar alata i opreme' },
];

let mountRoot = null;
let docsOffset = 0;
let toolsOffset = 0;
let accumulatedDocs = [];
let accumulatedTools = [];
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

function docFetchParamsFromUi(f) {
  const base = { doc_type: f.doc_type || '', search: f.search || '' };
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

export function teardownReversiModule() {
  mountRoot = null;
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
  let magacinId = null;
  let locations = [];

  let docFilters = { uiStatus: 'sve', search: '', doc_type: '' };
  let toolFilters = { status: 'active', search: '' };
  let docsTotal = null;
  let toolsTotal = null;
  let tabCountZ = null;
  let tabCountI = null;
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
              <div class="rev-brand-icon" aria-hidden="true">↻</div>
              <div class="rev-brand-text">
                <h1 class="rev-brand-title">Reversi</h1>
                <span class="rev-brand-sub">Alati i oprema</span>
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
          (t) => `
          <button type="button" role="tab" class="rev-strip-tab ${activeTab === t.id ? 'is-active' : ''}" data-rev-tab="${escHtml(t.id)}">
            <span class="rev-strip-label">${escHtml(t.label)}</span>
            <span class="rev-strip-count ${activeTab === t.id ? 'is-active' : ''}" data-rev-tab-count="${escHtml(t.id)}">${escHtml(
              countLabel(t.id === 'zaduzenja' ? tabCountZ : tabCountI),
            )}</span>
          </button>`,
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

  function setTabCounts(z, i) {
    if (z != null) tabCountZ = z;
    if (i != null) tabCountI = i;
    const ez = root.querySelector('[data-rev-tab-count="zaduzenja"]');
    const ei = root.querySelector('[data-rev-tab-count="inventar"]');
    if (z != null && ez) ez.textContent = countLabel(z);
    if (i != null && ei) ei.textContent = countLabel(i);
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
    await ensureMeta();

    if (activeTab === 'zaduzenja') {
      await loadMyIssued();

      const [cOpen, cPart, cRet, cOver, cCan] = await Promise.all([
        fetchDocuments({ status: 'OPEN', limit: 1, offset: 0 }),
        fetchDocuments({ status: 'PARTIALLY_RETURNED', limit: 1, offset: 0 }),
        fetchDocuments({ status: 'RETURNED', limit: 1, offset: 0 }),
        fetchDocuments({ overdue: true, limit: 1, offset: 0 }),
        fetchDocuments({ status: 'CANCELLED', limit: 1, offset: 0 }),
      ]);
      const nOpen = cOpen.ok ? cOpen.data?.total ?? 0 : 0;
      const nPart = cPart.ok ? cPart.data?.total ?? 0 : 0;
      const nAkt = nOpen + nPart;
      const nRet = cRet.ok ? cRet.data?.total ?? 0 : 0;
      const nOver = cOver.ok ? cOver.data?.total ?? 0 : 0;
      const nCan = cCan.ok ? cCan.data?.total ?? 0 : 0;

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
          <summary>Moja aktivna zaduženja <span class="rev-my-panel-badge">${myIssued.length}</span></summary>
          <ul class="rev-my-list">${myIssued.map((r) => `<li><strong>${escHtml(r.naziv)}</strong> <span class="rev-muted">(${escHtml(r.oznaka)})</span> — ${fmtDateShort(r.issued_at)}</li>`).join('')}</ul>
        </details>`
          : '';

      body.innerHTML = `
        <div class="rev-print-area">
        <div class="rev-stat-grid">
          <div class="rev-stat-card rev-stat-card--primary">
            <div class="rev-stat-label">Aktivna zaduženja</div>
            <div class="rev-stat-value">${nAkt}</div>
            <div class="rev-stat-hint">otvoreno + delimično vraćeno</div>
          </div>
          <div class="rev-stat-card ${nOver > 0 ? 'rev-stat-card--alert' : ''}">
            <div class="rev-stat-label">Prekoračeni rokovi</div>
            <div class="rev-stat-value">${nOver}</div>
            <div class="rev-stat-hint">${nOver > 0 ? 'Potrebna akcija' : 'Nema prekoračenja'}</div>
          </div>
          <div class="rev-stat-card rev-stat-card--ok">
            <div class="rev-stat-label">Vraćeno</div>
            <div class="rev-stat-value">${nRet}</div>
            <div class="rev-stat-hint">zatvorena zaduženja</div>
          </div>
          <div class="rev-stat-card">
            <div class="rev-stat-label">Otkazano</div>
            <div class="rev-stat-value">${nCan}</div>
            <div class="rev-stat-hint">ukupno otkazanih</div>
          </div>
        </div>

        <div class="rev-panel rev-toolbar-panel">
          <div class="rev-field rev-field--grow">
            <label class="rev-field-label">Pretraga</label>
            <input type="search" id="revDocSearch" class="rev-input rev-input--search" placeholder="Broj dokumenta ili primalac…" value="${escHtml(docFilters.search)}"/>
          </div>
          <div class="rev-field">
            <label class="rev-field-label">Status</label>
            <div class="rev-seg" role="group">
              ${(
                [
                  ['sve', 'Sve'],
                  ['aktivno', 'Aktivna'],
                  ['prekoraceno', 'Prekoračena'],
                  ['vraceno', 'Vraćena'],
                  ['otkazano', 'Otkaz.'],
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
            <label class="rev-field-label">Tip</label>
            <select id="revDocType" class="rev-select">
              <option value="" ${docFilters.doc_type === '' ? 'selected' : ''}>Sve</option>
              <option value="TOOL" ${docFilters.doc_type === 'TOOL' ? 'selected' : ''}>Alat</option>
              <option value="COOPERATION_GOODS" ${docFilters.doc_type === 'COOPERATION_GOODS' ? 'selected' : ''}>Kooperacija</option>
            </select>
          </div>
          <div class="rev-toolbar-actions">
            <button type="button" class="rev-btn rev-btn--secondary" id="revBtnPrintZad">Štampa</button>
            ${canManageReversi() ? `<button type="button" class="rev-btn rev-btn--primary" id="revBtnNewDoc">+ Novo zaduženje</button>` : ''}
          </div>
        </div>
        ${myBlock}
        <div id="revDocTableHost"></div>
        </div>`;

      const dtHost = body.querySelector('#revDocTableHost');
      if (rows.length === 0) {
        dtHost.innerHTML = `<div class="rev-empty-card"><p>Nema dokumenata za prikaz.</p>${canManageReversi() ? '<p><button type="button" class="rev-btn rev-btn--primary" id="revEmptyNew">Kreiraj prvo zaduženje</button></p>' : ''}</div>`;
        body.querySelector('#revEmptyNew')?.addEventListener('click', () =>
          openIssueReversalModal({ onSuccess: () => void refreshBody() }),
        );
      } else {
        const today = new Date().toISOString().slice(0, 10);
        dtHost.innerHTML = `
          <div class="rev-table-shell">
            <table class="rev-data-table">
              <thead><tr>
                <th>Br. dokumenta</th><th>Datum</th><th>Primalac</th><th class="rev-th-num">Stavki</th><th>Rok vraćanja</th><th>Status</th><th class="rev-th-actions">Akcije</th>
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
            <span class="rev-muted">Prikazano ${rows.length}${docsTotal != null ? ` od ${docsTotal}` : ''}</span>
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

      body.querySelector('#revBtnNewDoc')?.addEventListener('click', () =>
        openIssueReversalModal({ onSuccess: () => void refreshBody() }),
      );
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
    const [invStats, tr, cOpenTab, cPartTab] = await Promise.all([
      fetchTools({ status: 'active', limit: 2000, offset: 0, search: '' }),
      fetchTools({
        status: toolFilters.status,
        search: toolFilters.search,
        limit: PAGE,
        offset: toolsOffset,
      }),
      fetchDocuments({ status: 'OPEN', limit: 1, offset: 0 }),
      fetchDocuments({ status: 'PARTIALLY_RETURNED', limit: 1, offset: 0 }),
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

    body.innerHTML = `
      <div class="rev-print-area">
      <div class="rev-stat-grid">
        <div class="rev-stat-card rev-stat-card--primary">
          <div class="rev-stat-label">Ukupno aktivnih</div>
          <div class="rev-stat-value">${nActTotal}</div>
          <div class="rev-stat-hint">alata u sistemu</div>
        </div>
        <div class="rev-stat-card rev-stat-card--ok">
          <div class="rev-stat-label">U magacinu</div>
          <div class="rev-stat-value">${nMag}${moreThanSample ? '+' : ''}</div>
          <div class="rev-stat-hint">${moreThanSample ? 'na osnovu prvih ' + (invStats.data?.rows?.length ?? 0) + ' stavki' : 'dostupno za zaduženje'}</div>
        </div>
        <div class="rev-stat-card rev-stat-card--amber">
          <div class="rev-stat-label">Trenutno zaduženo</div>
          <div class="rev-stat-value">${nZad}${moreThanSample ? '+' : ''}</div>
          <div class="rev-stat-hint">kod primalaca</div>
        </div>
        <div class="rev-stat-card ${nScrap > 0 ? 'rev-stat-card--alert' : ''}">
          <div class="rev-stat-label">Otpisano</div>
          <div class="rev-stat-value">${nScrap}</div>
          <div class="rev-stat-hint">rashodovane stavke</div>
        </div>
      </div>

      <div class="rev-panel rev-toolbar-panel">
        <div class="rev-field rev-field--grow">
          <label class="rev-field-label">Pretraga</label>
          <input type="search" id="revToolSearch" class="rev-input rev-input--search" placeholder="Oznaka ili naziv…" value="${escHtml(toolFilters.search}"/>
        </div>
        <div class="rev-field">
          <label class="rev-field-label">Status alata</label>
          <select id="revToolSt" class="rev-select">
            <option value="active" ${toolFilters.status === 'active' ? 'selected' : ''}>Aktivni</option>
            <option value="scrapped" ${toolFilters.status === 'scrapped' ? 'selected' : ''}>Otpisani</option>
            <option value="lost" ${toolFilters.status === 'lost' ? 'selected' : ''}>Izgubljeni</option>
            <option value="all" ${toolFilters.status === 'all' ? 'selected' : ''}>Svi</option>
          </select>
        </div>
        <div class="rev-toolbar-actions">
          ${canManageReversi() ? `<button type="button" class="rev-btn rev-btn--primary" id="revBtnAddTool">+ Dodaj alat</button>` : ''}
        </div>
      </div>
      <div id="revToolGridHost"></div>
      </div>`;

    const gh = body.querySelector('#revToolGridHost');
    if (trows.length === 0) {
      gh.innerHTML = `<div class="rev-empty-card"><p>Inventar je prazan za izabrane filtere.</p><p class="rev-muted">${canManageReversi() ? 'Dodajte alat ili proverite seed.' : ''}</p></div>`;
    } else {
      gh.innerHTML = `
        <div class="rev-table-shell">
          <table class="rev-data-table">
            <thead><tr>
              <th>Oznaka</th><th>Naziv</th><th>Tip</th><th class="rev-th-num">Kom.</th><th class="rev-th-num">Dostupno</th><th class="rev-th-num">Zaduženo</th><th>Status / lokacija</th><th class="rev-th-actions">Akcije</th>
            </tr></thead>
            <tbody>${trows
              .map((t) => {
                const issued = !!t.issued_holder;
                const dost = issued ? 0 : 1;
                const zad = issued ? 1 : 0;
                const st = toolStatusPresentation(t);
                let locHint = 'U magacinu';
                if (issued && t.issued_holder?.doc) {
                  const d = t.issued_holder.doc;
                  locHint =
                    d.recipient_type === 'EMPLOYEE'
                      ? `Kod: ${d.recipient_employee_name || 'radnik'}`
                      : d.recipient_type === 'DEPARTMENT'
                        ? `Odelj.: ${d.recipient_department || '—'}`
                        : `Kooperant: ${d.recipient_company_name || '—'}`;
                } else if (t.current_location_code) {
                  locHint = `Mag. · ${t.current_location_code}`;
                }
                const showZaduži = canManageReversi() && !issued && t.status === 'active';
                return `<tr>
                  <td class="rev-mono rev-strong">${escHtml(t.oznaka)}</td>
                  <td>${escHtml(t.naziv)}</td>
                  <td><span class="rev-pill rev-pill--blue rev-pill--sm">Alat</span></td>
                  <td class="rev-td-center">1</td>
                  <td class="rev-td-center ${dost ? 'rev-num-ok' : 'rev-num-zero'}">${dost}</td>
                  <td class="rev-td-center ${zad ? 'rev-num-warn' : ''}">${zad}</td>
                  <td>
                    <span class="rev-pill ${st.cls} rev-pill--sm">${escHtml(st.text)}</span>
                    <div class="rev-loc-hint">${escHtml(locHint)}</div>
                  </td>
                  <td class="rev-td-actions">
                    <button type="button" class="rev-act-btn" data-tool-det="${escHtml(t.id)}" title="Detalji">👁</button>
                    ${showZaduži ? `<button type="button" class="rev-act-btn rev-act-btn--primary" data-tool-zad="${escHtml(t.id)}" title="Zaduži">+</button>` : ''}
                  </td>
                </tr>`;
              })
              .join('')}
            </tbody>
          </table>
        </div>
        <div class="rev-pager">
          <span class="rev-muted">Prikazano ${trows.length}${toolsTotal != null ? ` od ${toolsTotal}` : ''}</span>
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

    body.querySelector('#revBtnAddTool')?.addEventListener('click', () =>
      openAddToolModal({ onSuccess: () => void refreshBody() }),
    );
    body.querySelector('#revToolSt')?.addEventListener('change', (e) => {
      toolFilters.status = e.target.value;
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

  paintChrome();
  void refreshBody();
}
