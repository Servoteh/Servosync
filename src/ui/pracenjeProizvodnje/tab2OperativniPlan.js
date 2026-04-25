import { escHtml } from '../../lib/dom.js';
import {
  getFilteredActivities,
  setOperativniFilter,
} from '../../state/pracenjeProizvodnjeState.js';
import { priorityBadgeHtml, statusBadgeHtml } from './statusBadge.js';
import { openAktivnostModal } from './aktivnostModal.js';
import { dashboardFooterHtml } from './dashboardFooter.js';

export function tab2OperativniPlanHtml(state) {
  const activities = getFilteredActivities();
  return `
    <section class="form-card" style="margin-bottom:14px">
      <div class="pp-toolbar" style="margin:0">
        <label class="pp-rn-filter">
          <span>Pretraga</span>
          <input type="search" id="oaSearch" value="${escHtml(state.filters.search)}" placeholder="Naziv, TP, odgovoran…">
        </label>
        <label class="pp-rn-filter">
          <span>Odeljenje</span>
          <select id="oaDeptFilter">
            <option value="">Sva</option>
            ${departmentOptions(state)}
          </select>
        </label>
        <label class="pp-rn-filter">
          <span>Status</span>
          <select id="oaStatusFilter">
            ${statusOptions(state.filters.status)}
          </select>
        </label>
        <div class="pp-toolbar-spacer"></div>
        ${state.canEdit ? '<button type="button" class="pp-refresh-btn" id="newAktivnostBtn">+ Nova aktivnost</button>' : '<span class="pp-readonly-badge">read-only</span>'}
        <button type="button" class="pp-refresh-btn" disabled title="Dolazi u sledećem inkrementu">Iz akcione tačke</button>
        <button type="button" class="pp-refresh-btn" disabled title="Dolazi u sledećem inkrementu">Excel export</button>
      </div>
    </section>
    ${activities.length ? tableHtml(activities) : emptyHtml(state)}
    ${dashboardFooterHtml(state)}
  `;
}

export function wireTab2OperativniPlan(root, state, onChange) {
  root.querySelector('#oaSearch')?.addEventListener('input', (ev) => {
    setOperativniFilter('search', ev.target.value || '');
    onChange?.();
  });
  root.querySelector('#oaDeptFilter')?.addEventListener('change', (ev) => {
    setOperativniFilter('odeljenje', ev.target.value || '');
    onChange?.();
  });
  root.querySelector('#oaStatusFilter')?.addEventListener('change', (ev) => {
    setOperativniFilter('status', ev.target.value || '');
    onChange?.();
  });
  root.querySelector('#newAktivnostBtn')?.addEventListener('click', () => {
    openAktivnostModal({ state, activity: null, onSaved: onChange });
  });
  root.querySelectorAll('[data-activity-id]').forEach(row => {
    row.addEventListener('click', () => {
      const id = row.dataset.activityId;
      const activity = (state.tab2Data?.activities || []).find(a => a.id === id);
      if (activity) openAktivnostModal({ state, activity, onSaved: onChange });
    });
  });
}

function tableHtml(activities) {
  return `
    <section class="pp-table-wrap">
      <table class="pp-table">
        <thead>
          <tr>
            <th>RB</th><th>Odeljenje</th><th>Aktivnost</th><th>Br. TP</th><th>Količina</th>
            <th>Plan. početak</th><th>Plan. završetak</th><th>Odgovoran</th><th>Zavisi od</th>
            <th>Status</th><th>Prioritet</th><th>Rizik</th><th class="pp-cell-num">Rezerva</th><th>Kasni</th>
          </tr>
        </thead>
        <tbody>
          ${activities.map(a => `
            <tr data-activity-id="${escHtml(a.id)}" style="cursor:pointer" class="${a.kasni ? 'is-urgent is-urgent-overdue' : ''}">
              <td class="pp-cell-num">${escHtml(a.rb ?? '')}</td>
              <td>${escHtml(a.odeljenje || a.odeljenje_naziv || '—')}</td>
              <td>
                <div class="pp-cell-strong">${escHtml(a.naziv_aktivnosti || '—')}</div>
                ${a.opis ? `<div class="form-hint">${escHtml(a.opis)}</div>` : ''}
              </td>
              <td>${escHtml(a.broj_tp || '—')}</td>
              <td>${escHtml(a.kolicina_text || '—')}</td>
              <td>${escHtml(a.planirani_pocetak || '—')}</td>
              <td>${escHtml(a.planirani_zavrsetak || '—')}</td>
              <td>${escHtml(a.odgovoran || a.odgovoran_label || '—')}</td>
              <td>${escHtml(a.zavisi_od || a.zavisi_od_text || '—')}</td>
              <td>${statusBadgeHtml(a, { button: false })}</td>
              <td>${priorityBadgeHtml(a.prioritet)}</td>
              <td class="pp-cell-clip">${escHtml(a.rizik_napomena || '—')}</td>
              <td class="pp-cell-num">${escHtml(a.rezerva_dani ?? '—')}</td>
              <td>${a.kasni ? '<span class="pp-rok urgency-overdue">Da</span>' : '<span class="pp-rok urgency-ok">Ne</span>'}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    </section>
  `;
}

function emptyHtml(state) {
  const hasAny = (state.tab2Data?.activities || []).length > 0;
  return `
    <div class="pp-state">
      <div class="pp-state-icon">...</div>
      <div class="pp-state-title">${hasAny ? 'Nema rezultata za filtere' : 'Nema operativnih aktivnosti'}</div>
      <div class="pp-state-desc">${hasAny ? 'Promeni filtere da vidiš aktivnosti.' : 'Dodaj prvu aktivnost kroz dugme Nova aktivnost.'}</div>
    </div>
  `;
}

function departmentOptions(state) {
  const selected = state.filters.odeljenje || '';
  const names = new Set();
  (state.departments || []).forEach(d => names.add(d.naziv));
  (state.tab2Data?.activities || []).forEach(a => names.add(a.odeljenje || a.odeljenje_naziv));
  return [...names].filter(Boolean).sort((a, b) => a.localeCompare(b, 'sr')).map(name =>
    `<option value="${escHtml(name)}"${name === selected ? ' selected' : ''}>${escHtml(name)}</option>`,
  ).join('');
}

function statusOptions(selected) {
  const opts = [
    ['', 'Svi'],
    ['nije_krenulo', 'Nije krenulo'],
    ['u_toku', 'U toku'],
    ['blokirano', 'Blokirano'],
    ['zavrseno', 'Završeno'],
  ];
  return opts.map(([value, label]) =>
    `<option value="${escHtml(value)}"${value === selected ? ' selected' : ''}>${escHtml(label)}</option>`,
  ).join('');
}
