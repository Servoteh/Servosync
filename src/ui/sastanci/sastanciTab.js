/**
 * Sastanci tab — lista / kalendar, filteri, akcije (placeholder Faza B gde treba)
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { formatDate } from '../../lib/date.js';
import {
  loadSastanci, deleteSastanak, loadUcesniciForMany,
  SASTANAK_TIPOVI, SASTANAK_STATUSI,
} from '../../services/sastanci.js';
import { loadProjektiLite } from '../../services/projekti.js';
import { openCreateSastanakModal } from './createSastanakModal.js';
import { openTemplatesModal } from './templatesModal.js';
import { navigateToSastanakDetalj } from './index.js';
import { renderSastanciCalendarView, groupSastanciByYmd } from './sastanciCalendar.js';
import { SESSION_KEYS } from '../../lib/constants.js';
import { getSastSastanView } from '../../state/sastanci.js';

let abortFlag = false;
let cachedSastanci = [];
let cachedProjekti = [];
const filters = { tip: '', status: '', projekatId: '', fromDate: '', toDate: '' };

let calYear;
let calMonth;
function getOrInitCalMonth() {
  const t = new Date();
  if (calYear == null) calYear = t.getFullYear();
  if (calMonth == null) calMonth = t.getMonth();
  return { y: calYear, m: calMonth };
}
function toYmd(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function setView(v) {
  sessionStorage.setItem(SESSION_KEYS.SAST_SASTANCI_VIEW, v);
}

export async function renderSastanciTab(host, { canEdit }) {
  abortFlag = false;
  cachedProjekti = await loadProjektiLite();
  const view = getSastSastanView();

  host.innerHTML = `
    <div class="sast-section" id="sstRoot">
      <div class="sst-view-bar">
        <div class="sst-toggle" role="group" aria-label="Prikaz">
          <button type="button" class="sst-tgl-btn${view === 'lista' ? ' is-on' : ''}" data-v="lista" title="Lista">📋 Lista</button>
          <button type="button" class="sst-tgl-btn${view === 'kalendar' ? ' is-on' : ''}" data-v="kalendar" title="Kalendar">📅 Kalendar</button>
        </div>
        <div class="sst-toolbar-actions sst-ttpl">
          ${canEdit ? '<button type="button" class="btn" id="sstOpenTpl">📋 Templati</button>' : ''}
          ${canEdit ? '<button class="btn btn-primary" id="newSastanakBtn">+ Novi sastanak</button>' : ''}
        </div>
      </div>
      <div class="sst-toolbar-2">
        <div class="sst-filters">
          <select id="ssFiltTip" class="sast-input">
            <option value="">Svi tipovi</option>
            ${Object.entries(SASTANAK_TIPOVI).map(([k, v]) => `<option value="${k}">${escHtml(v)}</option>`).join('')}
          </select>
          <select id="ssFiltStatus" class="sast-input">
            <option value="">Svi statusi</option>
            ${Object.entries(SASTANAK_STATUSI).map(([k, v]) => `<option value="${k}">${escHtml(v || k)}</option>`).join('')}
          </select>
          <select id="ssFiltProjekat" class="sast-input">
            <option value="">Svi projekti</option>
            ${cachedProjekti.map(p => `<option value="${p.id}">${escHtml(p.label)}</option>`).join('')}
          </select>
          <input type="date" id="ssFiltFrom" class="sast-input" title="Od datuma" value="${filters.fromDate}">
          <input type="date" id="ssFiltTo" class="sast-input" title="Do datuma" value="${filters.toDate}">
        </div>
      </div>
      <div id="ssBody" class="sast-table-wrap sst-body-host"></div>
    </div>
  `;

  if (canEdit) {
    host.querySelector('#newSastanakBtn')?.addEventListener('click', () => {
      openCreateSastanakModal({
        projekti: cachedProjekti,
        onCreated: (sast) => {
          openSastanakModal({
            sastanakId: sast.id,
            canEdit,
            onClose: () => renderAll(host, canEdit),
          });
        },
      });
    });
    host.querySelector('#sstOpenTpl')?.addEventListener('click', () => {
      openTemplatesModal({
        canEdit: true,
        onInstantiated: () => { renderAll(host, canEdit); },
      });
    });
  }

  host.querySelector('#ssFiltTip').value = filters.tip;
  host.querySelector('#ssFiltStatus').value = filters.status;
  host.querySelector('#ssFiltProjekat').value = filters.projekatId;

  ['ssFiltTip', 'ssFiltStatus', 'ssFiltProjekat', 'ssFiltFrom', 'ssFiltTo'].forEach(id => {
    host.querySelector('#' + id).addEventListener('change', (e) => {
      const key = id.replace('ssFilt', '').toLowerCase();
      const map = { tip: 'tip', status: 'status', projekat: 'projekatId', from: 'fromDate', to: 'toDate' };
      filters[map[key]] = e.target.value;
      void renderAll(host, canEdit);
    });
  });

  host.querySelectorAll('.sst-tgl-btn').forEach(b => {
    b.addEventListener('click', () => {
      setView(b.dataset.v);
      host.querySelectorAll('.sst-tgl-btn').forEach(x => x.classList.toggle('is-on', x === b));
      void renderAll(host, canEdit);
    });
  });

  await renderAll(host, canEdit);
}

async function renderAll(host, canEdit) {
  if (getSastSastanView() === 'kalendar') return renderCal(host, canEdit);
  return renderRowsTable(host, canEdit);
}

export function teardownSastanciTab() {
  abortFlag = true;
}

async function renderCal(host, canEdit) {
  const body = host.querySelector('#ssBody');
  body.innerHTML = '<div class="sst-loading">Učitavam kalendar…</div>';
  const { y, m } = getOrInitCalMonth();
  const d0 = new Date(y, m, 1);
  const d1 = new Date(y, m + 1, 0);
  const fromStr = toYmd(d0);
  const toStr = toYmd(d1);
  const rows = await loadSastanci({
    tip: filters.tip || null,
    status: filters.status || null,
    projekatId: filters.projekatId || null,
    fromDate: fromStr,
    toDate: toStr,
    limit: 2000,
  });
  if (abortFlag) return;
  const byD = groupSastanciByYmd(rows);
  renderSastanciCalendarView(body, {
    year: y,
    month: m,
    byDay: byD,
    canEdit,
    onNavMonth: (yn, mn) => {
      calYear = yn;
      calMonth = mn;
      renderCal(host, canEdit);
    },
    onToday: () => {
      const t = new Date();
      calYear = t.getFullYear();
      calMonth = t.getMonth();
      renderCal(host, canEdit);
    },
    onRowAction: (s, act) => {
      handleRowAction(s, act, host, canEdit);
    },
  });
  cachedSastanci = rows;
}

async function renderRowsTable(host, canEdit) {
  const body = host.querySelector('#ssBody');
  body.innerHTML = '<div class="sst-loading">Učitavam sastanke…</div>';

  cachedSastanci = await loadSastanci({
    tip: filters.tip || null,
    status: filters.status || null,
    projekatId: filters.projekatId || null,
    fromDate: filters.fromDate || null,
    toDate: filters.toDate || null,
    limit: 500,
  });

  if (abortFlag) return;

  const uMap = await loadUcesniciForMany(cachedSastanci.map(s => s.id));

  if (!cachedSastanci.length) {
    body.innerHTML = '<div class="sast-empty">Nema sastanaka sa zadatim filterima.</div>';
    return;
  }

  body.innerHTML = `
    <table class="sast-table sst-table-sast sast-table-clickable">
      <thead>
        <tr>
          <th>Datum & vreme</th>
          <th>Naslov</th>
          <th>Tip</th>
          <th>Mesto</th>
          <th>Učesnici</th>
          <th>Status</th>
          <th class="sast-th-actions">Akcije</th>
        </tr>
      </thead>
      <tbody>
        ${cachedSastanci.map(s => {
          const u = uMap.get(s.id) || [];
          const nU = u.length;
          const nP = u.filter(x => x.prisutan).length;
          return renderSastanakRow(s, canEdit, nP, nU);
        }).join('')}
      </tbody>
    </table>
  `;

  body.querySelectorAll('tr[data-id]').forEach(tr => {
    tr.addEventListener('click', (e) => {
      if (e.target.closest('[data-action]')) return;
      navigateToSastanakDetalj(tr.dataset.id);
    });
  });

  body.querySelectorAll('.sst-rowact').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const id = btn.dataset.id;
      const sast = cachedSastanci.find(s => s.id === id);
      if (!sast) return;
      const act = btn.dataset.action;
      if (act === 'open') {
        navigateToSastanakDetalj(id);
        return;
      }
      if (act === 'delete') {
        if (sast.status === 'zakljucan') { showToast('🔒 Zaključan se ne može obrisati'); return; }
        if (!confirm(`Obriši sastanak "${sast.naslov}"?`)) return;
        deleteSastanak(id).then(ok => { if (ok) { showToast('Obrisano'); renderAll(host, canEdit); } });
        return;
      }
      if (act === 'pripremi') {
        navigateToSastanakDetalj(id, 'pripremi');
        return;
      }
      if (act === 'zap') {
        navigateToSastanakDetalj(id, 'zapisnik');
        return;
      }
      if (act === 'arh') {
        navigateToSastanakDetalj(id, 'arhiva');
      }
    });
  });
}

function handleRowAction(s, act, host, canEdit) {
  if (act === 'open') { navigateToSastanakDetalj(s.id); return; }
  if (act === 'pripremi') { navigateToSastanakDetalj(s.id, 'pripremi'); return; }
  if (act === 'zap') { navigateToSastanakDetalj(s.id, 'zapisnik'); return; }
  if (act === 'arh') { navigateToSastanakDetalj(s.id, 'arhiva'); return; }
  if (act === 'delete') {
    if (s.status === 'zakljucan') { showToast('🔒 Zaključan se ne može obrisati'); return; }
    if (!confirm(`Obriši sastanak "${s.naslov}"?`)) return;
    deleteSastanak(s.id).then(ok => { if (ok) { showToast('Obrisano'); renderAll(host, canEdit); } });
  }
}

function renderSastanakRow(s, canEdit, nP, nU) {
  const tipLabel = SASTANAK_TIPOVI[s.tip] || s.tip;
  const st = s.status || 'planiran';
  const stLabel = SASTANAK_STATUSI[st] || st;
  const projekat = cachedProjekti.find(p => p.id === s.projekatId);
  const projLabel = projekat ? escHtml(projekat.code || projekat.name) : '';

  const statusSpan = `<span class="sastanak-status-pill sastanak-status-${escHtml(st)}">${escHtml(stLabel)}</span>`;
  const actions = [];
  if (st === 'planiran') {
    actions.push(`<button type="button" class="btn btn-sm sst-rowact" data-action="pripremi" data-id="${s.id}">Pripremi</button>`);
    if (canEdit) {
      actions.push(`<button type="button" class="btn btn-sm sst-rowact" data-action="open" data-id="${s.id}">Uredi</button>`);
      actions.push(`<button type="button" class="btn btn-sm sst-rowact" data-action="delete" data-id="${s.id}">Otkaži</button>`);
    }
  } else if (st === 'u_toku') {
    actions.push(`<button type="button" class="btn btn-sm sst-rowact" data-action="zap" data-id="${s.id}">Otvori zapisnik</button>`);
  } else if (st === 'zavrsen' || st === 'zakljucan') {
    actions.push(`<button type="button" class="btn btn-sm sst-rowact" data-action="open" data-id="${s.id}">Otvori</button>`);
    if (st === 'zakljucan' && canEdit) {
      actions.push(`<button type="button" class="btn btn-sm sst-rowact" data-action="arh" data-id="${s.id}">Arhiviraj</button>`);
    }
  } else {
    actions.push(`<button type="button" class="btn btn-sm sst-rowact" data-action="open" data-id="${s.id}">Otvori</button>`);
  }

  return `
    <tr data-id="${s.id}">
      <td>
        <strong>${escHtml(formatDate(s.datum))}</strong>
        ${s.vreme ? `<br><small class="sst-ttm">${escHtml(s.vreme.slice(0, 5))}</small>` : ''}
      </td>
      <td><strong>${escHtml(s.naslov)}</strong>${projLabel ? `<div class="sst-sub">${projLabel}</div>` : ''}</td>
      <td><span class="sast-tip-badge sast-tip-${escHtml(s.tip)}">${escHtml(tipLabel)}</span></td>
      <td>${escHtml(s.mesto || '—')}</td>
      <td class="sst-ucn">${nU ? `${nP} / ${nU}` : '—'}</td>
      <td>${statusSpan}</td>
      <td class="sas-ta-wrap">${actions.join(' ')}</td>
    </tr>
  `;
}
