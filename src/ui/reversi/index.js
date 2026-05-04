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
  fetchDocumentLines,
} from '../../services/reversiService.js';
import { openIssueReversalModal, openConfirmReturnModal, openAddToolModal, fmtDateShort } from './modals.js';

const TABS = [
  { id: 'zaduzenja', label: 'Zaduženja' },
  { id: 'inventar', label: 'Inventar alata' },
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

function statusBadgeCls(st) {
  const m = {
    OPEN: 'rev-badge--open',
    PARTIALLY_RETURNED: 'rev-badge--partial',
    RETURNED: 'rev-badge--done',
    CANCELLED: 'rev-badge--cancel',
  };
  return m[st] || 'rev-badge--muted';
}

function toolCardBadge(tool) {
  if (tool.status === 'scrapped') return { cls: 'rev-tb-scrapped', text: '⚫ Otpisan' };
  if (tool.status === 'lost') return { cls: 'rev-tb-lost', text: '⚫ Izgubljen' };
  const ih = tool.issued_holder;
  if (ih?.doc) {
    const rt = ih.doc.recipient_type;
    if (rt === 'EMPLOYEE') {
      return {
        cls: 'rev-tb-emp',
        text: `🔴 Zadužen: ${ih.doc.recipient_employee_name || 'Radnik'}`,
      };
    }
    if (rt === 'DEPARTMENT') {
      return { cls: 'rev-tb-dept', text: `🟡 Odeljenje: ${ih.doc.recipient_department || '—'}` };
    }
    return {
      cls: 'rev-tb-coop',
      text: `🟠 Kod kooperanta: ${ih.doc.recipient_company_name || '—'}`,
    };
  }
  const code = tool.current_location_code || '—';
  return { cls: 'rev-tb-mag', text: `🟢 U magacinu · ${code}` };
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

  let docFilters = { status: 'OPEN', recipient_search: '', doc_type: '' };
  let toolFilters = { status: 'active', search: '' };
  let docsTotal = null;
  let toolsTotal = null;
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

  function paintChrome() {
    const hub = root.querySelector('#revHubSlot');
    const auth = getAuth();
    hub.innerHTML = `
      <header class="kadrovska-header">
        <div class="kadrovska-header-left">
          <button type="button" class="btn-hub-back" id="revBackBtn"><span>←</span> Moduli</button>
          <div class="kadrovska-title"><span class="ktitle-mark">🔁</span> Reversi <span class="kadrovska-title-sub">Alati i zaduženja</span></div>
        </div>
        <div class="kadrovska-header-right">
          <button type="button" class="theme-toggle" id="revThemeBtn">🌙</button>
          <span class="role-indicator">${escHtml((auth.role || '').toUpperCase())}</span>
          <button type="button" class="hub-logout" id="revLogoutBtn">Odjavi se</button>
        </div>
      </header>
      <nav class="kadrovska-tabs rev-tabs" role="tablist">
        ${TABS.map(t => `<button type="button" role="tab" class="kadrovska-tab rev-tab ${activeTab === t.id ? 'active' : ''}" data-rev-tab="${escHtml(t.id)}">${escHtml(t.label)}</button>`).join('')}
      </nav>`;

    root.querySelector('#revBackBtn')?.addEventListener('click', () => onBackToHub?.());
    root.querySelector('#revThemeBtn')?.addEventListener('click', () => toggleTheme());
    root.querySelector('#revLogoutBtn')?.addEventListener('click', async () => {
      await logout();
      onLogout?.();
    });
    root.querySelectorAll('[data-rev-tab]').forEach(btn => {
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
      body.innerHTML = `<div class="rev-empty"><p>Supabase nije konfigurisan.</p></div>`;
      return;
    }

    body.innerHTML = `<div class="rev-loading">Učitavanje…</div>`;
    await ensureMeta();

    if (activeTab === 'zaduzenja') {
      await loadMyIssued();
      const dr = await fetchDocuments({
        ...docFilters,
        limit: PAGE,
        offset: docsOffset,
      });
      const batch = dr.ok && dr.data?.rows ? dr.data.rows : [];
      docsTotal = dr.ok ? dr.data?.total : null;
      if (docsOffset === 0) accumulatedDocs = batch;
      else accumulatedDocs = accumulatedDocs.concat(batch);
      const rows = accumulatedDocs;

      const myBlock =
        myIssued.length > 0
          ? `<details class="rev-my-issued" ${myIssuedOpen ? 'open' : ''}>
          <summary>Moja aktivna zaduženja (${myIssued.length})</summary>
          <ul class="rev-my-list">${myIssued.map(r => `<li>${escHtml(r.naziv)} (${escHtml(r.oznaka)}) — zadužena ${fmtDateShort(r.issued_at)}</li>`).join('')}</ul>
        </details>`
          : '';

      body.innerHTML = `
        <div class="rev-toolbar">
          ${canManageReversi() ? `<button type="button" class="btn btn-primary rev-btn-new" id="revBtnNewDoc">+ Novo zaduženje</button>` : ''}
        </div>
        <div class="rev-filters">
          <label>Status
            <select id="revDocStatus" class="input">
              <option value="OPEN" ${docFilters.status === 'OPEN' ? 'selected' : ''}>OPEN</option>
              <option value="ALL">Sve</option>
              <option value="PARTIALLY_RETURNED">PARTIALLY_RETURNED</option>
              <option value="RETURNED">RETURNED</option>
              <option value="CANCELLED">CANCELLED</option>
            </select>
          </label>
          <label>Primalac <input type="search" id="revDocRec" class="input" placeholder="Pretraga…" value="${escHtml(docFilters.recipient_search)}"/></label>
          <label>Tip
            <select id="revDocType" class="input">
              <option value="" ${docFilters.doc_type === '' ? 'selected' : ''}>Sve</option>
              <option value="TOOL" ${docFilters.doc_type === 'TOOL' ? 'selected' : ''}>Alat</option>
              <option value="COOPERATION_GOODS" ${docFilters.doc_type === 'COOPERATION_GOODS' ? 'selected' : ''}>Kooperaciona roba</option>
            </select>
          </label>
        </div>
        ${myBlock}
        <div id="revDocTableHost"></div>`;

      const dtHost = body.querySelector('#revDocTableHost');
      if (rows.length === 0) {
        dtHost.innerHTML = `<div class="rev-empty"><p>Nema dokumenata za prikaz.</p>${canManageReversi() ? '<p><button type="button" class="btn btn-primary" id="revEmptyNew">Kreiraj prvo zaduženje</button></p>' : ''}</div>`;
        body.querySelector('#revEmptyNew')?.addEventListener('click', () =>
          openIssueReversalModal({ onSuccess: () => void refreshBody() }),
        );
      } else {
        const today = new Date().toISOString().slice(0, 10);
        dtHost.innerHTML = `
          <div class="rev-table-wrap">
            <table class="rev-table rev-doc-table">
              <thead><tr>
                <th>Br. dokumenta</th><th>Primalac</th><th>Datum izdavanja</th><th>Rok povraćaja</th><th>Stavki</th><th>Status</th><th>Akcije</th>
              </tr></thead>
              <tbody>${rows
                .map(d => {
                  const overdue =
                    d.expected_return_date &&
                    d.status === 'OPEN' &&
                    String(d.expected_return_date) < today;
                  const rokCls = overdue ? 'rev-overdue' : '';
                  const canRet =
                    canManageReversi() &&
                    (d.status === 'OPEN' || d.status === 'PARTIALLY_RETURNED');
                  return `<tr data-doc-id="${escHtml(d.id)}">
                    <td>${escHtml(d.doc_number)}</td>
                    <td>${escHtml(recipientLabel(d))}</td>
                    <td>${fmtDateShort(d.issued_at)}</td>
                    <td class="${rokCls}">${d.expected_return_date ? fmtDateShort(d.expected_return_date) : '—'}</td>
                    <td>${escHtml(String(d.line_count ?? 0))}</td>
                    <td><span class="rev-badge ${statusBadgeCls(d.status)}">${escHtml(d.status)}</span></td>
                    <td class="rev-actions">
                      <button type="button" class="btn btn-sm" title="Detalji" data-act="det" data-id="${escHtml(d.id)}">👁</button>
                      ${canRet ? `<button type="button" class="btn btn-sm" title="Potvrdi povraćaj" data-act="ret" data-id="${escHtml(d.id)}">↩</button>` : ''}
                      <button type="button" class="btn btn-sm" disabled title="Dostupno u sledećoj verziji">📄</button>
                    </td>
                  </tr>`;
                })
                .join('')}
              </tbody>
            </table>
          </div>
          <div class="rev-pager">
            <span class="rev-muted">Prikazano ${rows.length}${docsTotal != null ? ` od ${docsTotal}` : ''}</span>
            ${docsOffset + rows.length < (docsTotal ?? Infinity) ? `<button type="button" class="btn" id="revDocMore">Učitaj još</button>` : ''}
          </div>`;

        dtHost.querySelectorAll('[data-act="det"]').forEach(btn => {
          btn.addEventListener('click', async () => {
            const did = btn.getAttribute('data-id');
            const lr = await fetchDocumentLines(did);
            const lines = lr.ok && Array.isArray(lr.data) ? lr.data : [];
            const html = lines
              .map(ln => {
                const tr = ln.rev_tools;
                const t = Array.isArray(tr) ? tr[0] : tr;
                const name = t ? `${t.oznaka} — ${t.naziv}` : ln.drawing_no || ln.part_name || '—';
                return `<tr><td>${escHtml(name)}</td><td>${escHtml(ln.napomena || '—')}</td><td>${escHtml(ln.line_status)}</td></tr>`;
              })
              .join('');
            const ov = document.createElement('div');
            ov.className = 'kadr-modal-overlay rev-modal-overlay';
            ov.innerHTML = `<div class="kadr-modal rev-modal"><div class="kadr-modal-header"><h2>Stavke dokumenta</h2><button type="button" class="kadr-modal-close" data-x>×</button></div>
              <div class="kadr-modal-body"><table class="rev-table"><thead><tr><th>Stavka</th><th>Pribor</th><th>Status</th></tr></thead><tbody>${html}</tbody></table></div></div>`;
            document.body.appendChild(ov);
            ov.querySelector('[data-x]')?.addEventListener('click', () => ov.remove());
            ov.addEventListener('click', e => {
              if (e.target === ov) ov.remove();
            });
          });
        });

        dtHost.querySelectorAll('[data-act="ret"]').forEach(btn => {
          btn.addEventListener('click', () => {
            const did = btn.getAttribute('data-id');
            const doc = rows.find(r => r.id === did);
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

      body.querySelector('#revDocStatus')?.addEventListener('change', e => {
        docFilters.status = e.target.value;
        docsOffset = 0;
        accumulatedDocs = [];
        void refreshBody();
      });
      body.querySelector('#revDocType')?.addEventListener('change', e => {
        docFilters.doc_type = e.target.value;
        docsOffset = 0;
        accumulatedDocs = [];
        void refreshBody();
      });
      body.querySelector('#revDocRec')?.addEventListener('input', e => {
        clearTimeout(docDeb);
        docDeb = setTimeout(() => {
          docFilters.recipient_search = e.target.value;
          docsOffset = 0;
          accumulatedDocs = [];
          void refreshBody();
        }, 300);
      });

      const det = body.querySelector('.rev-my-issued');
      det?.addEventListener('toggle', () => {
        myIssuedOpen = det.open;
      });

      return;
    }

    /* inventar */
    const tr = await fetchTools({
      status: toolFilters.status,
      search: toolFilters.search,
      limit: PAGE,
      offset: toolsOffset,
    });
    const batch = tr.ok && tr.data?.rows ? tr.data.rows : [];
    toolsTotal = tr.ok ? tr.data?.total : null;
    if (toolsOffset === 0) accumulatedTools = batch;
    else accumulatedTools = accumulatedTools.concat(batch);
    const trows = accumulatedTools;

    body.innerHTML = `
      <div class="rev-toolbar">
        ${canManageReversi() ? `<button type="button" class="btn btn-primary" id="revBtnAddTool">+ Dodaj alat</button>` : ''}
      </div>
      <div class="rev-filters">
        <label>Pretraga <input type="search" id="revToolSearch" class="input" placeholder="Oznaka / naziv" value="${escHtml(toolFilters.search)}"/></label>
        <label>Status alata
          <select id="revToolSt" class="input">
            <option value="active" ${toolFilters.status === 'active' ? 'selected' : ''}>Aktivni</option>
            <option value="scrapped" ${toolFilters.status === 'scrapped' ? 'selected' : ''}>Otpisani</option>
            <option value="lost" ${toolFilters.status === 'lost' ? 'selected' : ''}>Izgubljeni</option>
            <option value="all" ${toolFilters.status === 'all' ? 'selected' : ''}>Svi</option>
          </select>
        </label>
      </div>
      <div id="revToolGridHost"></div>`;

    const gh = body.querySelector('#revToolGridHost');
    if (trows.length === 0) {
      gh.innerHTML = `<div class="rev-empty"><p>Inventar alata je prazan.</p><p class="rev-muted">Dodajte alat ili pokrenite seed.</p></div>`;
    } else {
      gh.innerHTML = `
        <div class="rev-tool-grid">${trows
          .map(t => {
            const b = toolCardBadge(t);
            const issued = !!t.issued_holder;
            const showZaduži = canManageReversi() && !issued && t.status === 'active';
            return `<article class="rev-tool-card">
              <div class="rev-tool-oz">${escHtml(t.oznaka)}</div>
              <div class="rev-tool-name">${escHtml(t.naziv)}</div>
              <div class="rev-tool-badge ${b.cls}">${escHtml(b.text)}</div>
              <div class="rev-tool-actions">
                <button type="button" class="btn btn-sm" data-tool-det="${escHtml(t.id)}">Detalji</button>
                ${showZaduži ? `<button type="button" class="btn btn-sm btn-primary" data-tool-zad="${escHtml(t.id)}">Zaduži</button>` : ''}
              </div>
            </article>`;
          })
          .join('')}
        </div>
        <div class="rev-pager">
          <span class="rev-muted">Prikazano ${trows.length}${toolsTotal != null ? ` od ${toolsTotal}` : ''}</span>
          ${toolsOffset + trows.length < (toolsTotal ?? Infinity) ? `<button type="button" class="btn" id="revToolMore">Učitaj još</button>` : ''}
        </div>`;

      gh.querySelectorAll('[data-tool-det]').forEach(btn => {
        btn.addEventListener('click', () => {
          const tid = btn.getAttribute('data-tool-det');
          const t = trows.find(x => x.id === tid);
          showToast(t ? `${t.oznaka}: ${t.naziv}` : 'Alat');
        });
      });
      gh.querySelectorAll('[data-tool-zad]').forEach(btn => {
        btn.addEventListener('click', () => {
          const tid = btn.getAttribute('data-tool-zad');
          const t = trows.find(x => x.id === tid);
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
    body.querySelector('#revToolSt')?.addEventListener('change', e => {
      toolFilters.status = e.target.value;
      toolsOffset = 0;
      accumulatedTools = [];
      void refreshBody();
    });
    body.querySelector('#revToolSearch')?.addEventListener('input', e => {
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
