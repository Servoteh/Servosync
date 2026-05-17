/**
 * Kadrovska — tab „Pregled” (KPI + action stack).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  getAuth,
  getCurrentUser,
  getCurrentRole,
  getManagedDepartments,
} from '../../state/auth.js';
import { visibleSubmodules } from './shared.js';
import {
  loadDashboardKpis,
  loadActionStack,
  publishKadrDashIntent,
} from '../../services/kadrovskaDashboard.js';

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

function _setKpiLoading(rootEl, loading) {
  rootEl.querySelectorAll('[data-kpi-card]').forEach(el => {
    el.classList.toggle('kadr-dashboard__kpi-card--loading', loading);
  });
}

function _applyKpi(rootEl, kpi) {
  const v = (key, fallback = '—') => {
    if (!kpi || kpi[key] == null) return fallback;
    return String(kpi[key]);
  };
  const el = id => rootEl.querySelector(`[data-kpi="${id}"]`);
  const a = el('active_employees');
  const o = el('on_absence_today');
  const p = el('pending_vac_requests');
  const g = el('grid_fill_percent');
  if (a) a.textContent = v('active_employees', '0');
  if (o) o.textContent = v('on_absence_today', '0');
  if (p) p.textContent = v('pending_vac_requests', '0');
  if (g) {
    const n = Number(kpi?.grid_fill_percent);
    g.textContent = Number.isFinite(n) ? `${n}%` : v('grid_fill_percent', '—');
  }
}

function _renderActions(rootEl, items, onOpenTab) {
  const ul = rootEl.querySelector('#kadrDashActionStack');
  if (!ul) return;
  ul.innerHTML = '';
  if (!items || !items.length) {
    const li = document.createElement('li');
    li.className = 'kadr-dashboard__action-item--empty';
    li.textContent = 'Nema stavki za prikaz';
    ul.appendChild(li);
    return;
  }
  for (const it of items) {
    const li = document.createElement('li');
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'kadr-dashboard__action-item';
    btn.textContent = it.title + (it.subtitle ? ` — ${it.subtitle}` : '');
    btn.addEventListener('click', () => {
      if (it.deepLink && typeof onOpenTab === 'function') {
        publishKadrDashIntent(it.deepLink);
        onOpenTab(it.deepLink.tab);
      }
    });
    li.appendChild(btn);
    ul.appendChild(li);
  }
}

async function _hydrate(rootEl, opts, { forceRefresh } = { forceRefresh: false }) {
  const onOpenTab = opts.onOpenTab;
  _setKpiLoading(rootEl, true);
  try {
    const [kpi, actions] = await Promise.all([
      loadDashboardKpis({ forceRefresh }),
      loadActionStack({ forceRefresh }),
    ]);
    if (kpi && typeof kpi === 'object') {
      _applyKpi(rootEl, kpi);
    } else {
      showToast('⚠ KPI nisu učitani — proveri mrežu ili migraciju');
      _applyKpi(rootEl, null);
    }
    _renderActions(rootEl, Array.isArray(actions) ? actions : [], onOpenTab);
  } catch (e) {
    console.error('[kadrovska] dashboard hydrate', e);
    showToast('⚠ Greška pri učitavanju pregleda');
  } finally {
    _setKpiLoading(rootEl, false);
  }
}

/**
 * @param {HTMLElement} rootEl
 * @param {{ onOpenTab?: (tabId: string) => void }} [opts]
 * @returns {Promise<void>}
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
          <div class="kadr-dashboard__hero-tools">
            <button type="button" class="btn btn-ghost kadr-dashboard__refresh" id="kadrDashRefresh"
              title="Osveži KPI i stek akcija">📊 Osveži</button>
          </div>
          <div class="kadr-dashboard__hero-name">${escHtml(_displayName())}</div>
          <div class="kadr-dashboard__hero-role">${escHtml(roleUpper)}</div>
          ${_managedLineHtml()}
        </div>
      </section>

      <section class="kadr-dashboard__kpi-strip" aria-label="Kratke statistike">
        <article class="kadr-dashboard__kpi-card kadr-dashboard__kpi-card--loading" data-kpi-card>
          <span class="kadr-dashboard__kpi-icon" aria-hidden="true">👥</span>
          <div class="kadr-dashboard__kpi-body">
            <div class="kadr-dashboard__kpi-label">Aktivni zaposleni</div>
            <div class="kadr-dashboard__kpi-value" data-kpi="active_employees">—</div>
          </div>
        </article>
        <article class="kadr-dashboard__kpi-card kadr-dashboard__kpi-card--loading" data-kpi-card>
          <span class="kadr-dashboard__kpi-icon" aria-hidden="true">🏠</span>
          <div class="kadr-dashboard__kpi-body">
            <div class="kadr-dashboard__kpi-label">Trenutno na odsustvu</div>
            <div class="kadr-dashboard__kpi-value" data-kpi="on_absence_today">—</div>
          </div>
        </article>
        <article class="kadr-dashboard__kpi-card kadr-dashboard__kpi-card--loading" data-kpi-card>
          <span class="kadr-dashboard__kpi-icon" aria-hidden="true">✋</span>
          <div class="kadr-dashboard__kpi-body">
            <div class="kadr-dashboard__kpi-label">Otvoreni zahtevi GO</div>
            <div class="kadr-dashboard__kpi-value" data-kpi="pending_vac_requests">—</div>
          </div>
        </article>
        <article class="kadr-dashboard__kpi-card kadr-dashboard__kpi-card--loading" data-kpi-card>
          <span class="kadr-dashboard__kpi-icon" aria-hidden="true">📊</span>
          <div class="kadr-dashboard__kpi-body">
            <div class="kadr-dashboard__kpi-label">Mesečni grid popunjenost</div>
            <div class="kadr-dashboard__kpi-value" data-kpi="grid_fill_percent">—</div>
          </div>
        </article>
      </section>

      <section class="kadr-dashboard__actions" aria-label="Šta čeka mene">
        <h2 class="kadr-dashboard__section-title">Šta čeka mene</h2>
        <ul class="kadr-dashboard__action-stack" id="kadrDashActionStack">
          <li class="kadr-dashboard__action-item--empty">Učitavanje…</li>
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
          <div class="kadr-dashboard__mini-report-placeholder">Sprint 3.3 — mini grafikon odeljenja</div>
          <div class="kadr-dashboard__mini-report-placeholder">Sprint 3.3 — sati po danu (trenutni mesec)</div>
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

  rootEl.querySelectorAll('.kadr-dashboard__submodule-open').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-kadr-dash-tab');
      if (id && typeof onOpenTab === 'function') onOpenTab(id);
    });
  });

  const refreshBtn = rootEl.querySelector('#kadrDashRefresh');
  if (refreshBtn) {
    refreshBtn.addEventListener('click', () => {
      void _hydrate(rootEl, opts, { forceRefresh: true });
    });
  }

  return _hydrate(rootEl, opts, { forceRefresh: false });
}
