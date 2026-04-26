/**
 * Mesečni kalendar sastanaka (pon–ned), bez spoljne biblioteke.
 */

import { escHtml } from '../../lib/dom.js';
import { SASTANAK_TIPOVI, SASTANAK_STATUSI } from '../../services/sastanci.js';
import { openFazaBPlaceholderModal } from './fazaBPlaceholder.js';

const MES = ['Januar', 'Februar', 'Mart', 'April', 'Maj', 'Jun', 'Jul', 'Avgust', 'Septembar', 'Oktobar', 'Novembar', 'Decembar'];
const DOWH = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];

function ymdKey(y, m, d) {
  return `${y}-${String(m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

/**
 * @param {HTMLElement} host
 * @param {object} p
 * @param {number} p.year
 * @param {number} p.month 0-11
 * @param {Map<string, import('../../services/sastanci.js').mapDbSastanak extends Function ? any : any[]>} p.byDay  key "YYYY-MM-DD" -> sastanci[]
 * @param {(y:number, m:number) => void} p.onNavMonth
 * @param {() => void} p.onToday
 * @param {(sastanak: object, action: string) => void} p.onRowAction
 * @param {boolean} p.canEdit
 */
export function renderSastanciCalendarView(host, p) {
  const { year, month, byDay, onNavMonth, onToday, onRowAction, canEdit } = p;
  const firstDow = new Date(year, month, 1).getDay();
  const startOffset = (firstDow + 6) % 7;
  const daysInMonth = new Date(year, month + 1, 0).getDate();

  const cells = [];
  for (let i = 0; i < startOffset; i++) {
    cells.push({ empty: true });
  }
  for (let d = 1; d <= daysInMonth; d++) {
    const k = ymdKey(year, month, d);
    const list = byDay.get(k) || [];
    cells.push({ day: d, key: k, list });
  }

  const title = `${MES[month]} ${year}`;

  host.innerHTML = `
    <div class="sast-cal">
      <div class="sast-cal-head">
        <button type="button" class="btn" data-cal="prev" aria-label="Prethodni mesec">←</button>
        <div class="sast-cal-title">${escHtml(title)}</div>
        <button type="button" class="btn" data-cal="next" aria-label="Sledeći mesec">→</button>
        <button type="button" class="btn btn-sm" data-cal="td">Danas</button>
      </div>
      <div class="sast-cal-dow">
        ${DOWH.map(h => `<div class="sast-cal-dowc">${h}</div>`).join('')}
      </div>
      <div class="sst-cal-grid" role="grid">
        ${cells.map(c => {
          if (c.empty) {
            return '<div class="sst-cal-day sst-cal-day--pad"></div>';
          }
          const n = c.list.length;
          const more = n > 3;
          const show = c.list.slice(0, 3);
          return `
            <div class="sst-cal-day" data-ymd="${c.key}" role="gridcell" tabindex="0">
              <div class="sst-cal-dayn">${c.day}</div>
              <div class="sst-cal-dots">
                ${show.map(s => {
                  const st = s.status || 'planiran';
                  return `<span class="sst-cal-dot sastanak-status-pill sastanak-status-${escHtml(st)}" title="${escHtml(s.naslov || '')}"></span>`;
                }).join('')}
                ${more ? `<span class="sst-cal-more">+${n - 3}</span>` : ''}
              </div>
            </div>
          `;
        }).join('')}
      </div>
    </div>
  `;

  host.querySelector('[data-cal=prev]')?.addEventListener('click', () => {
    let m2 = month - 1;
    let y2 = year;
    if (m2 < 0) { m2 = 11; y2 -= 1; }
    onNavMonth(y2, m2);
  });
  host.querySelector('[data-cal=next]')?.addEventListener('click', () => {
    let m2 = month + 1;
    let y2 = year;
    if (m2 > 11) { m2 = 0; y2 += 1; }
    onNavMonth(y2, m2);
  });
  host.querySelector('[data-cal=td]')?.addEventListener('click', () => onToday?.());

  host.querySelectorAll('.sst-cal-day[data-ymd]').forEach(el => {
    const open = () => {
      const ymd = el.dataset.ymd;
      const list = byDay.get(ymd) || [];
      if (!list.length) return;
      openDayDrawer(ymd, list, { onRowAction, canEdit });
    };
    el.addEventListener('click', open);
    el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(); }
    });
  });
}

function openDayDrawer(ymd, list, { onRowAction, canEdit }) {
  const overlay = document.createElement('div');
  overlay.className = 'sast-modal-overlay sst-cal-drawer-ov';
  const pretty = ymd.split('-').reverse().join('.');

  overlay.innerHTML = `
    <div class="sst-cal-drawer" role="dialog" aria-modal="true">
      <header class="sst-cal-dr-h">
        <h3>Sastanci — ${escHtml(pretty)}</h3>
        <button type="button" class="sast-modal-close" aria-label="Zatvori">✕</button>
      </header>
      <div class="sst-cal-dr-b">
        <table class="sast-table sast-table-compact">
          <thead><tr>
            <th>Vreme</th><th>Naslov</th><th>Status</th><th class="sast-th-actions">Akcije</th>
          </tr></thead>
          <tbody>
            ${list.map(s => {
              const st = s.status || 'planiran';
              return `
                <tr data-sid="${s.id}">
                  <td>${s.vreme ? escHtml(s.vreme.slice(0, 5)) : '—'}</td>
                  <td><strong>${escHtml(s.naslov)}</strong> <span class="sas-cal-tip">(${SASTANAK_TIPOVI[s.tip] || s.tip})</span></td>
                  <td><span class="sastanak-status-pill sastanak-status-${escHtml(st)}">${escHtml(SASTANAK_STATUSI[st] || st)}</span></td>
                  <td class="sast-td-actions" data-sid="${s.id}"></td>
                </tr>
              `;
            }).join('')}
          </tbody>
        </table>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);
  const close = () => overlay.remove();
  overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });
  overlay.querySelector('.sast-modal-close')?.addEventListener('click', close);

  list.forEach(s => {
    const host = overlay.querySelector(`tr[data-sid="${s.id}"] .sast-td-actions`);
    if (!host) return;
    const st = s.status || 'planiran';
    if (st === 'planiran') {
      addBtn(host, 'Pripremi', () => openFazaBPlaceholderModal('Pripremi sastanak'));
      addBtn(host, 'Uredi', () => { close(); onRowAction?.(s, 'open'); });
      if (canEdit) addBtn(host, 'Otkaži', () => { close(); onRowAction?.(s, 'delete'); });
    } else if (st === 'u_toku') {
      addBtn(host, 'Zapisnik', () => openFazaBPlaceholderModal('Zapisnik'));
    } else if (st === 'zavrsen') {
      addBtn(host, 'Otvori', () => { close(); onRowAction?.(s, 'open'); });
    } else if (st === 'zakljucan') {
      addBtn(host, 'Otvori', () => { close(); onRowAction?.(s, 'open'); });
      addBtn(host, 'Arhiva', () => openFazaBPlaceholderModal('Arhiviraj sastanak'));
    } else {
      addBtn(host, 'Otvori', () => { close(); onRowAction?.(s, 'open'); });
    }
  });
}

function addBtn(host, label, fn) {
  const b = document.createElement('button');
  b.type = 'button';
  b.className = 'btn btn-sm';
  b.textContent = label;
  b.addEventListener('click', (e) => { e.stopPropagation(); fn(); });
  host.appendChild(b);
}

/**
 * @param {object[]} sastanci
 * @returns {Map<string, object[]>}
 */
export function groupSastanciByYmd(sastanci) {
  const m = new Map();
  (sastanci || []).forEach(s => {
    const d = s.datum;
    if (!d) return;
    const k = d.slice(0, 10);
    if (!m.has(k)) m.set(k, []);
    m.get(k).push(s);
  });
  m.forEach((arr, k) => {
    arr.sort((a, b) => String(a.vreme || '').localeCompare(String(b.vreme || '')));
  });
  return m;
}
