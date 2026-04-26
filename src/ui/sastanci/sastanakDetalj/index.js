/**
 * Sastanak detalj — full-page view na /sastanci/<uuid>.
 *
 * Shell sa zajedničkim headerom (naslov, status, učesnici, dugmad akcija)
 * i 4 interna taba: Priprema | Zapisnik | Akcije | Arhiva.
 *
 * Status machine:
 *   planiran  --[Počni]------> u_toku
 *   u_toku    --[Zaključaj]--> zakljucan
 *   zakljucan --[Otvori]--(admin/menadzment)--> u_toku
 *   zavrsen   -> prikaži kao zakljucan (legacy vrednost)
 */

import { escHtml } from '../../../lib/dom.js';
import { formatDate } from '../../../lib/date.js';
import { showToast } from '../../../lib/dom.js';
import {
  canEdit, canEditSastanci, getCurrentUser, isAdmin,
} from '../../../state/auth.js';
import { getSastDetaljTab, setSastDetaljTab } from '../../../state/sastanci.js';
import {
  getSastanakFull,
  pocniSastanak,
  zakljucajSaSapisanikom,
  otvojiPonovo,
} from '../../../services/sastanciDetalj.js';
import { SASTANAK_TIPOVI, SASTANAK_STATUSI, SASTANAK_STATUS_BOJE } from '../../../services/sastanci.js';
import { renderPripremiTab, teardownPripremiTab } from './pripremiTab.js';
import { renderZapisnikTab, teardownZapisnikTab } from './zapisnikTab.js';
import { renderAkcijeTab, teardownAkcijeTab } from './akcijeTab.js';
import { renderArhivaDetaljTab, teardownArhivaDetaljTab } from './arhivaTab.js';

const INTERNAL_TABS = [
  { id: 'pripremi',  label: 'Priprema',  icon: '📋' },
  { id: 'zapisnik',  label: 'Zapisnik',  icon: '📝' },
  { id: 'akcije',    label: 'Akcije',    icon: '✅' },
  { id: 'arhiva',    label: 'Arhiva',    icon: '🔒' },
];

let abortFlag = false;
let currentTabId = 'pripremi';

export async function renderSastanakDetalj(host, { sastanakId, onBack, onNavigate }) {
  abortFlag = false;
  currentTabId = getSastDetaljTab();

  host.innerHTML = `
    <div class="sast-detalj" id="sastDetaljRoot">
      <div class="sast-detalj-loading">Učitavam sastanak…</div>
    </div>
  `;

  let sastanak;
  try {
    sastanak = await getSastanakFull(sastanakId);
  } catch (e) {
    console.error('[SastanakDetalj] load error', e);
  }

  if (abortFlag) return;

  if (!sastanak) {
    host.innerHTML = `
      <div class="sast-detalj sast-detalj--error">
        <p>⚠ Sastanak nije pronađen ili nemate pristup.</p>
        <button type="button" class="btn" id="sdBack">← Nazad</button>
      </div>
    `;
    host.querySelector('#sdBack')?.addEventListener('click', () => onBack?.());
    return;
  }

  render(host, sastanak, { onBack, onNavigate });
}

function render(host, sastanak, { onBack, onNavigate }) {
  const canWrite = canEdit() && canEditSastanci();
  const admin = isAdmin();
  const cu = getCurrentUser();
  const isLocked = sastanak.status === 'zakljucan' || sastanak.status === 'zavrsen';
  const isReadOnly = isLocked || sastanak.status === 'otkazan';

  const statusColor = SASTANAK_STATUS_BOJE[sastanak.status] || '#888';
  const statusLabel = SASTANAK_STATUSI[sastanak.status] || sastanak.status;
  const tipLabel = SASTANAK_TIPOVI[sastanak.tip] || sastanak.tip;

  const ucesniciHtml = renderUcesniciAvatars(sastanak.ucesnici || []);
  const actionBtnsHtml = renderActionButtons(sastanak, canWrite, admin);
  const readOnlyBanner = isReadOnly ? `
    <div class="sast-detalj-readonly-banner">
      🔒 ${sastanak.status === 'zakljucan' || sastanak.status === 'zavrsen'
        ? 'Sastanak je zaključan — samo čitanje.'
        : 'Sastanak je otkazan.'}
    </div>
  ` : '';

  host.innerHTML = `
    <div class="sast-detalj" id="sastDetaljRoot">
      <div class="sast-detalj-header">
        <div class="sast-detalj-header-top">
          <button type="button" class="btn-hub-back sast-detalj-back" id="sdBackBtn">
            <span aria-hidden="true">←</span> Nazad
          </button>
          <div class="sast-detalj-meta">
            <h1 class="sast-detalj-title">${escHtml(sastanak.naslov)}</h1>
            <div class="sast-detalj-sub">
              <span class="sast-tip-badge">${escHtml(tipLabel)}</span>
              <span class="sastanak-status-pill" style="background:${statusColor}">${escHtml(statusLabel)}</span>
              <span class="sast-detalj-datum">${formatDate(sastanak.datum)}${sastanak.vreme ? ' · ' + sastanak.vreme.slice(0,5) : ''}</span>
              ${sastanak.mesto ? `<span class="sast-detalj-mesto">📍 ${escHtml(sastanak.mesto)}</span>` : ''}
            </div>
          </div>
          <div class="sast-detalj-actions" id="sdActionBtns">
            ${actionBtnsHtml}
          </div>
        </div>
        <div class="sast-detalj-ucesnici" id="sdUcesnici">${ucesniciHtml}</div>
        ${readOnlyBanner}
        <nav class="sast-internal-tabs" role="tablist" aria-label="Detalj tabovi">
          ${INTERNAL_TABS.map(t => `
            <button type="button" role="tab"
              class="sast-internal-tab${currentTabId === t.id ? ' is-active' : ''}"
              data-itab="${t.id}"
              aria-selected="${currentTabId === t.id}">
              <span aria-hidden="true">${t.icon}</span> ${escHtml(t.label)}
            </button>
          `).join('')}
        </nav>
      </div>
      <main class="sast-detalj-body" id="sdTabBody"></main>
    </div>
  `;

  host.querySelector('#sdBackBtn')?.addEventListener('click', () => onBack?.());

  wireActionButtons(host, sastanak, canWrite, admin, () => {
    renderSastanakDetalj(host, { sastanakId: sastanak.id, onBack, onNavigate });
  });

  host.querySelectorAll('button[data-itab]').forEach(btn => {
    btn.addEventListener('click', () => {
      const tabId = btn.dataset.itab;
      if (tabId === currentTabId) return;
      teardownCurrentTab();
      currentTabId = tabId;
      setSastDetaljTab(tabId);
      host.querySelectorAll('button[data-itab]').forEach(b => {
        b.classList.toggle('is-active', b.dataset.itab === tabId);
        b.setAttribute('aria-selected', b.dataset.itab === tabId ? 'true' : 'false');
      });
      renderCurrentTab(host.querySelector('#sdTabBody'), sastanak, { canWrite, isReadOnly, onNavigate });
    });
  });

  renderCurrentTab(host.querySelector('#sdTabBody'), sastanak, { canWrite, isReadOnly, onNavigate });
}

function renderCurrentTab(tabHost, sastanak, { canWrite, isReadOnly, onNavigate }) {
  if (!tabHost) return;
  if (currentTabId === 'pripremi') {
    renderPripremiTab(tabHost, { sastanak, canWrite, isReadOnly });
  } else if (currentTabId === 'zapisnik') {
    renderZapisnikTab(tabHost, { sastanak, canWrite, isReadOnly });
  } else if (currentTabId === 'akcije') {
    renderAkcijeTab(tabHost, { sastanak, canWrite });
  } else if (currentTabId === 'arhiva') {
    renderArhivaDetaljTab(tabHost, { sastanak, canWrite });
  }
}

function teardownCurrentTab() {
  if (currentTabId === 'pripremi') teardownPripremiTab();
  else if (currentTabId === 'zapisnik') teardownZapisnikTab();
  else if (currentTabId === 'akcije') teardownAkcijeTab();
  else if (currentTabId === 'arhiva') teardownArhivaDetaljTab();
}

export function teardownSastanakDetalj() {
  abortFlag = true;
  teardownCurrentTab();
}

/* ── Header helpers ── */

function renderUcesniciAvatars(ucesnici) {
  if (!ucesnici.length) return '<span class="sast-ucesnici-empty">Nema učesnika</span>';
  const MAX = 5;
  const shown = ucesnici.slice(0, MAX);
  const rest = ucesnici.length - MAX;
  const html = shown.map(u => {
    const initials = getInitials(u.label || u.email);
    const cls = u.prisutan ? 'sast-avatar sast-avatar--prisutan' : 'sast-avatar';
    return `<span class="${cls}" title="${escHtml(u.label || u.email)}">${escHtml(initials)}</span>`;
  }).join('');
  const more = rest > 0 ? `<span class="sast-avatar sast-avatar--more" title="${rest} više">+${rest}</span>` : '';
  return `<div class="sast-avatars">${html}${more}</div>`;
}

function getInitials(name) {
  const parts = String(name || '?').trim().split(/[\s@]+/);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return parts[0].slice(0, 2).toUpperCase();
}

function renderActionButtons(sastanak, canWrite, admin) {
  if (!canWrite) return '';
  const s = sastanak.status;
  if (s === 'planiran') {
    return `
      <button type="button" class="btn btn-primary sast-action-btn" data-action="pocni">▶ Počni sastanak</button>
    `;
  }
  if (s === 'u_toku') {
    return `
      <button type="button" class="btn btn-success sast-action-btn" data-action="zakljucaj">🔒 Zaključaj</button>
    `;
  }
  if ((s === 'zakljucan' || s === 'zavrsen') && (admin || isAdmin())) {
    return `
      <button type="button" class="btn sast-action-btn" data-action="otvori">🔓 Otvori ponovo</button>
    `;
  }
  return '';
}

function wireActionButtons(host, sastanak, canWrite, admin, onReload) {
  host.querySelectorAll('[data-action]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const action = btn.dataset.action;
      btn.disabled = true;

      if (action === 'pocni') {
        const ok = await pocniSastanak(sastanak.id);
        if (ok) { showToast('✅ Sastanak je počeo'); onReload(); }
        else { showToast('⚠ Nije uspelo'); btn.disabled = false; }

      } else if (action === 'zakljucaj') {
        if (!confirm('Zaključaj sastanak? Ovo kreira snapshot zapisnika.')) {
          btn.disabled = false; return;
        }
        const ok = await zakljucajSaSapisanikom(sastanak.id);
        if (ok) { showToast('🔒 Sastanak zaključan'); onReload(); }
        else { showToast('⚠ Nije uspelo'); btn.disabled = false; }

      } else if (action === 'otvori') {
        if (!confirm('Otvoriti sastanak ponovo? Status se vraća na "U toku".')) {
          btn.disabled = false; return;
        }
        const ok = await otvojiPonovo(sastanak.id);
        if (ok) { showToast('🔓 Sastanak otvoren ponovo'); onReload(); }
        else { showToast('⚠ Nije uspelo'); btn.disabled = false; }
      }
    });
  });
}
