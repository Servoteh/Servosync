import { escHtml } from '../../lib/dom.js';
import { formatDate } from '../../lib/date.js';
import { getCurrentUser } from '../../state/auth.js';
import { loadAkcije, AKCIJA_STATUSI } from '../../services/akcioniPlan.js';
import { loadPmTeme, TEMA_STATUSI } from '../../services/pmTeme.js';
import { loadSastanciForUcesnik, SASTANAK_TIPOVI } from '../../services/sastanci.js';
import { navigateToSastanakDetalj } from './index.js';
import { renderStatusBadge } from './statusBadge.js';
import { renderEmptyStateHtml } from './emptyState.js';

let abortFlag = false;
const filters = { rok: '', status: '' };

const ROK_CHIPS = [
  { id: '', label: 'Svi rokovi' },
  { id: 'overdue', label: 'Kasni' },
  { id: 'week', label: 'Ova nedelja' },
  { id: 'month', label: 'Ovaj mesec' },
];

export async function renderMojRadTab(host) {
  abortFlag = false;
  const email = getCurrentUser()?.email?.toLowerCase();
  if (!email) {
    host.innerHTML = renderEmptyStateHtml({ title: 'Niste prijavljeni.' });
    return;
  }

  host.innerHTML = `
    <div class="sast-section sast-moj-rad">
      <div class="sast-mr-chips" role="group" aria-label="Filteri">
        ${ROK_CHIPS.map(c => `
          <button type="button" class="sast-chip${filters.rok === c.id ? ' is-on' : ''}" data-rok="${c.id}">${escHtml(c.label)}</button>
        `).join('')}
        <select id="mrFiltStatus" class="sast-input sast-mr-status-sel">
          <option value="">Svi statusi</option>
          ${Object.entries(AKCIJA_STATUSI).map(([k, v]) => `<option value="${k}">${escHtml(v)}</option>`).join('')}
        </select>
      </div>
      <div id="mrBody"></div>
    </div>
  `;

  host.querySelector('#mrFiltStatus').value = filters.status;
  host.querySelectorAll('[data-rok]').forEach(btn => {
    btn.addEventListener('click', () => {
      filters.rok = btn.dataset.rok;
      host.querySelectorAll('[data-rok]').forEach(b => b.classList.toggle('is-on', b === btn));
      void loadAll(host, email);
    });
  });
  host.querySelector('#mrFiltStatus').addEventListener('change', (e) => {
    filters.status = e.target.value;
    void loadAll(host, email);
  });

  await loadAll(host, email);
}

export function teardownMojRadTab() {
  abortFlag = true;
}

async function loadSastanciZaUcesnika(email) {
  return loadSastanciForUcesnik(email, { excludeLocked: true, limit: 50 });
}

function matchRokFilter(akcija) {
  if (!filters.rok) return true;
  const rok = akcija.rok;
  if (!rok) return filters.rok !== 'overdue';
  const d = new Date(rok);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  if (filters.rok === 'overdue') {
    return d < today && ['otvoren', 'u_toku', 'kasni'].includes(akcija.effectiveStatus || akcija.status);
  }
  if (filters.rok === 'week') {
    const end = new Date(today);
    end.setDate(end.getDate() + 7);
    return d >= today && d <= end;
  }
  if (filters.rok === 'month') {
    const end = new Date(today.getFullYear(), today.getMonth() + 1, 0);
    return d >= today && d <= end;
  }
  return true;
}

async function loadAll(host, email) {
  const body = host.querySelector('#mrBody');
  body.innerHTML = '<div class="sast-loading">Učitavam…</div>';

  const [akcije, teme, pozvani] = await Promise.all([
    loadAkcije({ odgovoranEmail: email, openOnly: false, limit: 300 }),
    loadPmTeme({ predlozioEmail: email, limit: 200 }),
    loadSastanciZaUcesnika(email),
  ]);

  if (abortFlag) return;

  let myAkcije = akcije.filter(a => ['otvoren', 'u_toku', 'kasni'].includes(a.effectiveStatus || a.status));
  if (filters.status) {
    myAkcije = myAkcije.filter(a => (a.effectiveStatus || a.status) === filters.status);
  }
  myAkcije = myAkcije.filter(matchRokFilter);

  const mojeTeme = teme.filter(t => t.status === 'predlog' || t.status === 'usvojeno');

  body.innerHTML = `
    <section class="sast-mr-block">
      <h3>✅ Moje akcije (${myAkcije.length})</h3>
      ${myAkcije.length ? renderAkcijeTable(myAkcije) : renderEmptyStateHtml({ title: 'Nema akcija sa filterom.' })}
    </section>
    <section class="sast-mr-block">
      <h3>📅 Sastanci gde sam pozvan (${pozvani.length})</h3>
      ${pozvani.length ? renderSastanciTable(pozvani) : renderEmptyStateHtml({ title: 'Nema aktivnih poziva.' })}
    </section>
    <section class="sast-mr-block">
      <h3>💡 Moji predlozi teme (${mojeTeme.length})</h3>
      ${mojeTeme.length ? renderTemeTable(mojeTeme) : renderEmptyStateHtml({ title: 'Nema predloga tema.' })}
    </section>
  `;

  body.querySelectorAll('tr[data-sid]').forEach(tr => {
    const sid = tr.dataset.sid;
    if (!sid) return;
    tr.addEventListener('click', () => navigateToSastanakDetalj(sid));
  });
}

function renderAkcijeTable(rows) {
  return `
    <table class="sast-table sast-table-clickable">
      <thead><tr><th>Zadatak</th><th>Rok</th><th>Status</th></tr></thead>
      <tbody>
        ${rows.map(a => `
          <tr data-sid="${escHtml(a.sastanakId || '')}">
            <td><strong>${escHtml(a.naslov)}</strong></td>
            <td>${escHtml(formatDate(a.rok) || a.rokText || '—')}</td>
            <td>${renderStatusBadge(a.effectiveStatus || a.status, { kind: 'akcija' })}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;
}

function renderSastanciTable(rows) {
  return `
    <table class="sast-table sast-table-clickable">
      <thead><tr><th>Datum</th><th>Naslov</th><th>Tip</th><th>Status</th></tr></thead>
      <tbody>
        ${rows.map(s => `
          <tr data-sid="${escHtml(s.id)}">
            <td>${escHtml(formatDate(s.datum))}</td>
            <td>${escHtml(s.naslov)}</td>
            <td>${escHtml(SASTANAK_TIPOVI[s.tip] || s.tip)}</td>
            <td>${renderStatusBadge(s.status, { kind: 'sastanak' })}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;
}

function renderTemeTable(rows) {
  return `
    <table class="sast-table">
      <thead><tr><th>Naslov</th><th>Status</th></tr></thead>
      <tbody>
        ${rows.map(t => `
          <tr>
            <td>${escHtml(t.naslov)}</td>
            <td>${escHtml(TEMA_STATUSI[t.status] || t.status)}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;
}
