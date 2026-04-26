/**
 * Dashboard tab — Pregled: empty state, 3 akciona widgeta, compact KPI, sekcije ispod.
 */

import { escHtml } from '../../lib/dom.js';
import { formatDate } from '../../lib/date.js';
import {
  loadDashboardStats, loadSastanci, loadNextPlaniranSastanak, loadUcesnici,
  SASTANAK_TIPOVI,
} from '../../services/sastanci.js';
import { loadAkcije } from '../../services/akcioniPlan.js';
import { loadPmTeme, TEMA_STATUS_BOJE } from '../../services/pmTeme.js';
import { loadProjektiLite } from '../../services/projekti.js';
import { getCurrentUser } from '../../state/auth.js';
import { SESSION_KEYS } from '../../lib/constants.js';
import { openCreateSastanakModal } from './createSastanakModal.js';
import { openQuickAddTemaModal } from './quickAddTemaButton.js';
import { navigateToSastanakDetalj } from './index.js';

let abortFlag = false;

function localYmdParts(ymd) {
  if (!ymd || typeof ymd !== 'string') return null;
  const m = ymd.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!m) return null;
  return { y: +m[1], mo: +m[2], d: +m[3] };
}

function rokDiffClass(rokYmd) {
  const p = localYmdParts(rokYmd);
  if (!p) return '';
  const today = new Date();
  const d0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const d1 = new Date(p.y, p.mo - 1, p.d);
  const diff = Math.round((d1 - d0) / 86400000);
  if (diff < 0 || diff <= 2) return 'akcija-rok-hitno';
  if (diff <= 7) return 'akcija-rok-uskoro';
  return 'akcija-rok-ok';
}

export async function renderDashboardTab(host, { canEdit, onJumpToTab }) {
  abortFlag = false;
  const cu = getCurrentUser();
  const email = cu?.email;

  host.innerHTML = `
    <div class="sast-dashboard">
      <div id="sastEmptyTop" class="sast-empty-top" style="display:none" aria-live="polite"></div>
      <div class="sast-action-widgets" id="sastActionWidgets">
        <div class="sast-widget sast-widget--next" id="sastWNext"></div>
        <div class="sast-widget sast-widget--akc" id="sastWAk"></div>
        <div class="sast-widget sast-widget--teme" id="sastWTm"></div>
      </div>
      <div class="sast-kpi-compact" id="sastStats">
        <div class="sast-loading">Učitavam statistike…</div>
      </div>
      <div class="sast-dash-grid" id="sastDashGrid">
        <section class="sast-dash-card" id="sastUpcomingCard">
          <header><h3>📅 Nadolazeći sastanci</h3><a href="#" data-jump="sastanci" class="sast-link">Svi →</a></header>
          <div class="sast-dash-body" id="sastUpcoming">Učitavam…</div>
        </section>
        <section class="sast-dash-card" id="sastLateCard">
          <header><h3>⚠ Akcije koje kasne</h3><a href="#" data-jump="akcioni-plan" class="sast-link">Sve →</a></header>
          <div class="sast-dash-body" id="sastLate">Učitavam…</div>
        </section>
        <section class="sast-dash-card" id="sastTopicsCard">
          <header><h3>💡 PM teme — na čekanju</h3><a href="#" data-jump="pm-teme" class="sast-link">Sve →</a></header>
          <div class="sast-dash-body" id="sastTopics">Učitavam…</div>
        </section>
      </div>
    </div>
  `;

  host.querySelectorAll('[data-jump]').forEach(a => {
    a.addEventListener('click', (e) => {
      e.preventDefault();
      onJumpToTab?.(a.dataset.jump);
    });
  });

  const today = new Date().toISOString().slice(0, 10);
  const in14 = new Date(Date.now() + 14 * 86400000).toISOString().slice(0, 10);

  let stats, nextSast, mojeAkc, mojeTemeRaw, upcoming, late, topics, cachedProj;
  try {
    [stats, nextSast, mojeAkc, mojeTemeRaw, upcoming, late, topics, cachedProj] = await Promise.all([
      loadDashboardStats(),
      loadNextPlaniranSastanak(),
      email
        ? loadAkcije({ odgovoranEmail: email, openOnly: true, limit: 20 })
        : Promise.resolve([]),
      email
        ? loadPmTeme({
          predlozioEmail: email,
          excludeStatuses: ['zatvoreno', 'odbijeno'],
          limit: 30,
        })
        : Promise.resolve([]),
      loadSastanci({ status: 'planiran', fromDate: today, toDate: in14, limit: 10 }),
      loadAkcije({ effectiveStatus: 'kasni', limit: 8 }),
      loadPmTeme({ status: 'predlog', limit: 8 }),
      loadProjektiLite(),
    ]);
  } catch (e) {
    console.error('[Dashboard] Greška pri učitavanju', e);
    host.querySelector('#sastStats').innerHTML =
      '<span class="sast-empty">⚠ Greška pri učitavanju. Osvežite stranicu.</span>';
    ['#sastUpcoming', '#sastLate', '#sastTopics'].forEach(sel => {
      const el = host.querySelector(sel);
      if (el) el.innerHTML = '';
    });
    return;
  }

  if (abortFlag) return;

  const mojeTeme = mojeTemeRaw
    .sort((a, b) => (a.prioritet || 2) - (b.prioritet || 2))
    .slice(0, 5);

  const mojeAkcTop = (mojeAkc || [])
    .sort((a, b) => {
      const ar = a.rok || '9999-12-31';
      const br = b.rok || '9999-12-31';
      return ar.localeCompare(br);
    })
    .slice(0, 5);

  const hasGlobalEmpty = !nextSast && (mojeAkc || []).length === 0 && mojeTeme.length === 0;
  const emptyTop = host.querySelector('#sastEmptyTop');
  if (hasGlobalEmpty) {
    emptyTop.style.display = 'block';
    emptyTop.innerHTML = `
      <div class="sast-empty-hero">
        <p>Još nema sastanaka, akcija ni tema na koje te odnosi ovaj pregled.</p>
        <div class="sast-empty-hero-btns">
          ${canEdit ? `
            <button type="button" class="btn btn-primary sast-cta-prvi" data-cta="sastanak">📅 Zakaži prvi sastanak</button>
            <button type="button" class="btn sast-cta-tema" data-cta="tema">💡 Dodaj prvu temu</button>
          ` : '<p class="sast-hint">Pisanje: admin / PM / menadžment.</p>'}
        </div>
      </div>
    `;
    if (canEdit) {
      emptyTop.querySelector('[data-cta=sastanak]')?.addEventListener('click', () => {
        openCreateSastanakModal({ projekti: cachedProj || [], onCreated: () => onJumpToTab?.('sastanci') });
      });
      emptyTop.querySelector('[data-cta=tema]')?.addEventListener('click', () => {
        openQuickAddTemaModal({ canEdit, onAfterSave: () => {} });
      });
    }
  } else {
    emptyTop.style.display = 'none';
  }

  renderWidgetNext(host.querySelector('#sastWNext'), nextSast, canEdit, { onJumpToTab, cachedProj });
  renderWidgetAkc(host.querySelector('#sastWAk'), mojeAkcTop, canEdit, { onJumpToTab });
  renderWidgetTeme(host.querySelector('#sastWTm'), mojeTeme, { onJumpToTab });

  renderStatsCompact(host.querySelector('#sastStats'), stats, onJumpToTab);
  renderUpcoming(host.querySelector('#sastUpcoming'), upcoming);
  renderLate(host.querySelector('#sastLate'), late);
  renderTopics(host.querySelector('#sastTopics'), topics);
}

export function teardownDashboardTab() {
  abortFlag = true;
}

function renderWidgetNext(host, s, canEdit, { onJumpToTab, cachedProj = [] }) {
  if (!s) {
    host.innerHTML = `
      <h4>Sledeći sastanak</h4>
      <p class="sast-widget-empty">Nema zakazanih sastanaka.</p>
      ${canEdit ? '<button type="button" class="btn btn-sm btn-primary sast-widget-cta" data-cta="zakazi">Zakaži</button>' : ''}
    `;
    if (canEdit) {
      host.querySelector('[data-cta=zakazi]')?.addEventListener('click', () => {
        openCreateSastanakModal({ projekti: cachedProj, onCreated: () => onJumpToTab?.('sastanci') });
      });
    }
    return;
  }
  host.innerHTML = '<h4>Sledeći sastanak</h4><div class="sast-loading sast-inline-load">Učitavam…</div>';
  loadUcesnici(s.id).then(uce => {
    if (abortFlag) return;
    const invited = uce.length;
    const pris = uce.filter(u => u.prisutan).length;
    const tipL = SASTANAK_TIPOVI[s.tip] || s.tip;
    host.innerHTML = `
      <h4>Sledeći sastanak</h4>
      <div class="sast-widget-body">
        <div class="sast-widget-t">${escHtml(formatDate(s.datum))} ${s.vreme ? escHtml(s.vreme.slice(0, 5)) : ''}</div>
        <div class="sast-widget-title"><span class="sast-tip-badge sast-tip-${escHtml(s.tip)}">${escHtml(tipL)}</span> ${escHtml(s.naslov)}</div>
        <div class="sast-widget-meta">👥 ${pris} / ${invited} učesnika</div>
      </div>
      <div class="sast-widget-actions">
        <button type="button" class="btn btn-sm btn-primary" data-a="pripremi">Pripremi</button>
        <button type="button" class="btn btn-sm" data-a="sast">Sastanci</button>
      </div>
    `;
    host.querySelector('[data-a=pripremi]')?.addEventListener('click', () => {
      navigateToSastanakDetalj(s.id, 'pripremi');
    });
    host.querySelector('[data-a=sast]')?.addEventListener('click', () => onJumpToTab?.('sastanci'));
  });
}

function renderWidgetAkc(host, rows, canEdit, { onJumpToTab }) {
  if (!rows.length) {
    host.innerHTML = `
      <h4>Moje akcije</h4>
      <p class="sast-widget-empty">Nemaš otvorenih akcija.</p>
    `;
    return;
  }
  host.innerHTML = `
    <h4>Moje akcije</h4>
    <ul class="sast-widget-list">
      ${rows.map(a => `
        <li class="sast-widget-li">
          <span class="sast-wdot ${escHtml(rokDiffClass(a.rok))}"></span>
          <div>
            <div class="sast-wtit">${escHtml(a.naslov)}</div>
            <div class="sast-wsub">${a.rok ? `Rok: ${escHtml(formatDate(a.rok))}` : '—'}</div>
          </div>
        </li>
      `).join('')}
    </ul>
    <button type="button" class="sast-widget-link" data-a="vidsve">Vidi sve →</button>
  `;
  host.querySelector('[data-a=vidsve]')?.addEventListener('click', () => {
    sessionStorage.setItem(SESSION_KEYS.SAST_INTENT_AKCIJONI_MOJE, '1');
    onJumpToTab?.('akcioni-plan');
  });
}

function renderWidgetTeme(host, rows, { onJumpToTab }) {
  if (!rows.length) {
    host.innerHTML = `<h4>Moje teme</h4><p class="sast-widget-empty">Nema aktivnih tema koje si predložio.</p>`;
    return;
  }
  host.innerHTML = `
    <h4>Moje teme</h4>
        <ul class="sast-widget-tlist">
      ${rows.map(t => `
        <li><span class="sast-tpri">P${t.prioritet || 2}</span> ${escHtml(t.naslov)} <small>· ${escHtml(t.status)}</small></li>
      `).join('')}
    </ul>
    <button type="button" class="sast-widget-link" data-t="moje">Vidi sve →</button>
  `;
  host.querySelector('[data-t=moje]')?.addEventListener('click', () => {
    sessionStorage.setItem(SESSION_KEYS.SAST_INTENT_PM_MOJE, '1');
    onJumpToTab?.('pm-teme');
  });
}

function renderStatsCompact(host, stats, onJumpToTab) {
  if (!stats) {
    host.innerHTML = '<div class="sast-empty">Nije moguće učitati statistike.</div>';
    return;
  }
  const items = [
    { id: 'sastanci', value: stats.sastancUpcoming, label: 'Sast. 14d', title: 'Sastanaka u 14 dana' },
    { id: 'sastanci', value: stats.sastancUToku, label: 'U toku', title: 'Sastanci u toku' },
    { id: 'akcioni-plan', value: stats.akcijeOtvoreno, label: 'Akcija otv.', title: 'Otvorenih akcija' },
    { id: 'akcioni-plan', value: stats.akcijeKasni, label: 'Kasne', title: 'Akcija koje kasne' },
    { id: 'pm-teme', value: stats.pmTemeNaCekanju, label: 'PM teme', title: 'PM teme na čekanju' },
  ];
  host.innerHTML = `
    <div class="sast-kpi-inner">
      ${items.map(c => `
        <button type="button" class="sast-kpi-mini" data-jump="${c.id}" title="${escHtml(c.title)}">
          <span class="sast-kpi-mv">${c.value}</span>
          <span class="sast-kpi-ml">${escHtml(c.label)}</span>
        </button>
      `).join('')}
    </div>
  `;
  host.querySelectorAll('[data-jump]').forEach(b => {
    b.addEventListener('click', () => onJumpToTab?.(b.dataset.jump));
  });
}

function renderUpcoming(host, sastanci) {
  if (!sastanci || !sastanci.length) {
    host.innerHTML = '<div class="sast-empty">Nema zakazanih sastanaka u sledećih 14 dana.</div>';
    return;
  }
  host.innerHTML = `
    <ul class="sast-list">
      ${sastanci.map(s => `
        <li class="sast-list-item">
          <div class="sast-list-date">
            <div class="sast-list-day">${formatDate(s.datum)}</div>
            ${s.vreme ? `<div class="sast-list-time">${escHtml(s.vreme.slice(0, 5))}</div>` : ''}
          </div>
          <div class="sast-list-main">
            <div class="sast-list-title">
              <span class="sast-tip-badge sast-tip-${escHtml(s.tip)}">${s.tip === 'projektni' ? 'Projektni' : 'Sedmični'}</span>
              ${escHtml(s.naslov)}
            </div>
            <div class="sast-list-meta">${s.vodioLabel ? '👤 ' + escHtml(s.vodioLabel) : ''} ${s.mesto ? ' · 📍 ' + escHtml(s.mesto) : ''}</div>
          </div>
        </li>
      `).join('')}
    </ul>
  `;
}

function renderLate(host, akcije) {
  if (!akcije || !akcije.length) {
    host.innerHTML = '<div class="sast-empty">🎉 Nema akcija koje kasne.</div>';
    return;
  }
  host.innerHTML = `
    <ul class="sast-list">
      ${akcije.map(a => `
        <li class="sast-list-item">
          <div class="sast-list-status" style="background:#ef4444">⚠</div>
          <div class="sast-list-main">
            <div class="sast-list-title">${escHtml(a.naslov)}</div>
            <div class="sast-list-meta">
              ${a.odgovoranLabel || a.odgovoranText || a.odgovoranEmail ? '👤 ' + escHtml(a.odgovoranLabel || a.odgovoranText || a.odgovoranEmail) : ''}
              ${a.rok ? ' · 📅 Rok: ' + escHtml(formatDate(a.rok)) + (a.danaDoRoka != null ? ` (${a.danaDoRoka < 0 ? 'kasni ' + Math.abs(a.danaDoRoka) + 'd' : ''})` : '') : ''}
            </div>
          </div>
        </li>
      `).join('')}
    </ul>
  `;
}

function renderTopics(host, teme) {
  if (!teme || !teme.length) {
    host.innerHTML = '<div class="sast-empty">Nema tema na čekanju.</div>';
    return;
  }
  host.innerHTML = `
    <ul class="sast-list">
      ${teme.map(t => `
        <li class="sast-list-item">
          <div class="sast-list-status" style="background:${TEMA_STATUS_BOJE[t.status] || '#666'}">${t.prioritet === 1 ? '!' : ''}</div>
          <div class="sast-list-main">
            <div class="sast-list-title">${escHtml(t.naslov)}</div>
            <div class="sast-list-meta">${escHtml(t.predlozioLabel || t.predlozioEmail || '—')} · ${escHtml(t.oblast)}</div>
          </div>
        </li>
      `).join('')}
    </ul>
  `;
}
