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
  loadMiniReports,
  publishKadrDashIntent,
} from '../../services/kadrovskaDashboard.js';
import {
  destroyChart,
  destroyMiniReportCharts,
  renderAbsencesByTypeChart,
  renderEmployeesByDepartmentChart,
  renderHoursPerDayChart,
} from './dashboardCharts.js';

/** Pre zamene panela (npr. promena taba) — sprečava curenje Chart.js instanci. */
export function teardownKadrovskaDashboard(panelEl) {
  if (!panelEl) return;
  destroyMiniReportCharts(panelEl);
}

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

function _setMiniReportsLoading(rootEl, loading) {
  rootEl.querySelectorAll('[data-kadr-chart-wrap]').forEach(el => {
    el.classList.toggle('kadr-chart-container--loading', loading);
  });
}

function _applyMiniReports(rootEl, mini) {
  const employeesCanvas = rootEl.querySelector('#chartEmployeesByDept');
  const hoursCanvas = rootEl.querySelector('#chartHoursPerDay');
  const absencesCanvas = rootEl.querySelector('#chartAbsencesByType');
  for (const c of [employeesCanvas, hoursCanvas, absencesCanvas]) {
    destroyChart(c);
  }

  const emp = mini?.employees_by_department;
  const hours = mini?.hours_per_day;
  const abs = mini?.absences_by_type;

  const setSlot = (canvas, emptyEl, data, render) => {
    if (!canvas || !emptyEl) return;
    if (!Array.isArray(data) || data.length === 0) {
      canvas.hidden = true;
      emptyEl.hidden = false;
      return;
    }
    emptyEl.hidden = true;
    canvas.hidden = false;
    render(canvas, data);
  };

  setSlot(employeesCanvas, rootEl.querySelector('[data-kadr-chart-empty="employees"]'), emp, renderEmployeesByDepartmentChart);
  setSlot(hoursCanvas, rootEl.querySelector('[data-kadr-chart-empty="hours"]'), hours, renderHoursPerDayChart);
  setSlot(absencesCanvas, rootEl.querySelector('[data-kadr-chart-empty="absences"]'), abs, renderAbsencesByTypeChart);
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
  _setMiniReportsLoading(rootEl, true);
  destroyMiniReportCharts(rootEl);
  try {
    const [kpi, actions, miniReports] = await Promise.all([
      loadDashboardKpis({ forceRefresh }),
      loadActionStack({ forceRefresh }),
      loadMiniReports({ forceRefresh }),
    ]);
    if (kpi && typeof kpi === 'object') {
      _applyKpi(rootEl, kpi);
    } else {
      showToast('⚠ KPI nisu učitani — proveri mrežu ili migraciju');
      _applyKpi(rootEl, null);
    }
    _renderActions(rootEl, Array.isArray(actions) ? actions : [], onOpenTab);
    _applyMiniReports(rootEl, miniReports && typeof miniReports === 'object' ? miniReports : null);
  } catch (e) {
    console.error('[kadrovska] dashboard hydrate', e);
    showToast('⚠ Greška pri učitavanju pregleda');
    _applyMiniReports(rootEl, null);
  } finally {
    _setKpiLoading(rootEl, false);
    _setMiniReportsLoading(rootEl, false);
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

      <section class="kadr-dashboard__mini-section" aria-label="Mini izveštaji">
        <h2 class="kadr-dashboard__section-title">Mini izveštaji</h2>
        <div class="kadr-dashboard__mini-reports">
          <div class="kadr-chart-container kadr-chart-container--loading" data-kadr-chart-wrap>
            <div class="kadr-chart-container__skeleton" aria-hidden="true"></div>
            <canvas id="chartEmployeesByDept"></canvas>
            <p class="kadr-chart-container__empty" data-kadr-chart-empty="employees" hidden>
              Nema podataka za prikaz
            </p>
          </div>
          <div class="kadr-chart-container kadr-chart-container--loading" data-kadr-chart-wrap>
            <div class="kadr-chart-container__skeleton" aria-hidden="true"></div>
            <canvas id="chartHoursPerDay"></canvas>
            <p class="kadr-chart-container__empty" data-kadr-chart-empty="hours" hidden>
              Nema podataka za prikaz
            </p>
          </div>
          <div class="kadr-chart-container kadr-chart-container--loading" data-kadr-chart-wrap>
            <div class="kadr-chart-container__skeleton" aria-hidden="true"></div>
            <canvas id="chartAbsencesByType"></canvas>
            <p class="kadr-chart-container__empty" data-kadr-chart-empty="absences" hidden>
              Nema podataka za prikaz
            </p>
          </div>
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
