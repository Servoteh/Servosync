/**
 * Kadrovska — tab „Pregled” (dashboard skelet, Sprint 3.2 povezuje podatke).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  getAuth,
  getCurrentUser,
  getCurrentRole,
  getManagedDepartments,
} from '../../state/auth.js';
import { visibleSubmodules } from './shared.js';

const DOC_HREF =
  'https://github.com/Servoteh/Servosync/blob/main/docs/Kadrovska_modul.md';

function _monthSubtitle() {
  try {
    return new Date().toLocaleDateString('sr-Latn-RS', {
      month: 'long',
      year: 'numeric',
    });
  } catch (_) {
    const d = new Date();
    return `${d.getMonth() + 1}. ${d.getFullYear()}.`;
  }
}

function _displayName() {
  const u = getCurrentUser();
  const raw = (u?.email || u?.emailRaw || '').trim();
  if (!raw) return '—';
  const at = raw.indexOf('@');
  return at > 0 ? raw.slice(0, at) : raw;
}

function _managedLineHtml() {
  if (getCurrentRole() !== 'menadzment') return '';
  const managed = getManagedDepartments();
  let text;
  if (managed == null) {
    text = 'Pokrivate odeljenja: sva odeljenja (nije podešen skup)';
  } else if (managed.length === 0) {
    text = 'Pokrivate odeljenja: nema dodeljenih odeljenja (prazan skup)';
  } else {
    text = `Pokrivate odeljenja: ${managed.map(d => escHtml(String(d))).join(', ')}`;
  }
  return `<div class="kadr-dashboard__hero-managed">${text}</div>`;
}

function _submoduleCardsHtml() {
  return visibleSubmodules()
    .map(
      s => `
    <article class="kadr-dashboard__submodule-card">
      <div class="kadr-dashboard__submodule-card-head">
        <span class="kadr-dashboard__submodule-icon" aria-hidden="true">${escHtml(s.icon)}</span>
        <div>
          <h3 class="kadr-dashboard__submodule-title">${escHtml(s.label)}</h3>
          <p class="kadr-dashboard__submodule-desc">${escHtml(s.description)}</p>
        </div>
      </div>
      <button type="button" class="btn kadr-dashboard__submodule-open" data-kadr-dash-tab="${escHtml(s.tabId)}">
        Otvori
      </button>
    </article>`,
    )
    .join('');
}

/**
 * @param {HTMLElement} rootEl
 * @param {{ onOpenTab?: (tabId: string) => void }} [opts]
 */
export function renderKadrovskaDashboard(rootEl, opts = {}) {
  const auth = getAuth();
  const roleUpper = (auth.role || 'viewer').toUpperCase();
  const onOpenTab = opts.onOpenTab;

  rootEl.innerHTML = `
    <div class="kadr-dashboard">
      <section class="kadr-dashboard__hero" aria-label="Pregled Kadrovska">
        <div class="kadr-dashboard__hero-main">
          <h1 class="kadr-dashboard__hero-title">Kadrovska</h1>
          <p class="kadr-dashboard__hero-sub">${escHtml(_monthSubtitle())}</p>
        </div>
        <div class="kadr-dashboard__hero-user">
          <div class="kadr-dashboard__hero-name">${escHtml(_displayName())}</div>
          <div class="kadr-dashboard__hero-role">${escHtml(roleUpper)}</div>
          ${_managedLineHtml()}
        </div>
      </section>

      <section class="kadr-dashboard__kpi-strip" aria-label="Kratke statistike">
        <article class="kadr-dashboard__kpi-card">
          <span class="kadr-dashboard__kpi-icon" aria-hidden="true">👥</span>
          <div class="kadr-dashboard__kpi-body">
            <div class="kadr-dashboard__kpi-label">Aktivni zaposleni</div>
            <div class="kadr-dashboard__kpi-value">47</div>
          </div>
        </article>
        <article class="kadr-dashboard__kpi-card">
          <span class="kadr-dashboard__kpi-icon" aria-hidden="true">🏠</span>
          <div class="kadr-dashboard__kpi-body">
            <div class="kadr-dashboard__kpi-label">Trenutno na odsustvu</div>
            <div class="kadr-dashboard__kpi-value">3</div>
          </div>
        </article>
        <article class="kadr-dashboard__kpi-card">
          <span class="kadr-dashboard__kpi-icon" aria-hidden="true">✋</span>
          <div class="kadr-dashboard__kpi-body">
            <div class="kadr-dashboard__kpi-label">Otvoreni zahtevi GO</div>
            <div class="kadr-dashboard__kpi-value">5</div>
          </div>
        </article>
        <article class="kadr-dashboard__kpi-card">
          <span class="kadr-dashboard__kpi-icon" aria-hidden="true">📊</span>
          <div class="kadr-dashboard__kpi-body">
            <div class="kadr-dashboard__kpi-label">Mesečni grid popunjenost</div>
            <div class="kadr-dashboard__kpi-value">78%</div>
          </div>
        </article>
      </section>

      <section class="kadr-dashboard__actions" aria-label="Šta čeka mene">
        <h2 class="kadr-dashboard__section-title">Šta čeka mene</h2>
        <ul class="kadr-dashboard__action-stack">
          <li><button type="button" class="kadr-dashboard__action-item">⚠ Lekarski pregled ističe za 12 dana — Marko Marković</button></li>
          <li><button type="button" class="kadr-dashboard__action-item">📋 4 zahteva za odobravanje GO</button></li>
          <li><button type="button" class="kadr-dashboard__action-item">🎂 Rođendan ove nedelje — Ana Anić</button></li>
        </ul>
      </section>

      <section class="kadr-dashboard__submodules" aria-label="Podmoduli">
        <h2 class="kadr-dashboard__section-title">Podmoduli</h2>
        <div class="kadr-dashboard__submodule-grid">
          ${_submoduleCardsHtml()}
        </div>
      </section>

      <section class="kadr-dashboard__mini-reports" aria-label="Izveštaji (uskoro)">
        <h2 class="kadr-dashboard__section-title kadr-dashboard__section-title--muted">Mini izveštaji</h2>
        <div class="kadr-dashboard__mini-reports-row">
          <div class="kadr-dashboard__mini-report-placeholder">Sprint 3.2 — mini grafikon odeljenja</div>
          <div class="kadr-dashboard__mini-report-placeholder">Sprint 3.2 — sati po danu (trenutni mesec)</div>
        </div>
      </section>

      <footer class="kadr-dashboard__footer">
        <div class="kadr-dashboard__footer-row">
          <span class="kadr-dashboard__footer-version">Servoteh ERP · modul Kadrovska</span>
          <a class="kadr-dashboard__footer-link" href="${DOC_HREF}" target="_blank" rel="noopener noreferrer">
            Dokumentacija (Kadrovska_modul.md)
          </a>
        </div>
        <div class="kadr-dashboard__footer-copy">© Servoteh</div>
      </footer>
    </div>
  `;

  rootEl.querySelectorAll('.kadr-dashboard__action-item').forEach(btn => {
    btn.addEventListener('click', () => {
      showToast('ℹ Sprint 3.2 — biće povezano sa filterima tabova');
    });
  });

  rootEl.querySelectorAll('.kadr-dashboard__submodule-open').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-kadr-dash-tab');
      if (id && typeof onOpenTab === 'function') onOpenTab(id);
    });
  });
}
