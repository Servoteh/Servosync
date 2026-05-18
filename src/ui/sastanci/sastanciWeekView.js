import { escHtml } from '../../lib/dom.js';
import { SASTANAK_TIPOVI } from '../../services/sastanci.js';
import { renderStatusBadge } from './statusBadge.js';

function mondayOfWeek(d) {
  const x = new Date(d);
  const day = x.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  x.setDate(x.getDate() + diff);
  x.setHours(0, 0, 0, 0);
  return x;
}

export function renderSastanciWeekView(host, { weekStart, rows, onOpen }) {
  const start = mondayOfWeek(weekStart);
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(start);
    d.setDate(d.getDate() + i);
    return d;
  });
  const ymd = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  const byDay = new Map(days.map(d => [ymd(d), []]));
  rows.forEach(s => {
    if (s.datum && byDay.has(s.datum)) byDay.get(s.datum).push(s);
  });

  host.innerHTML = `
    <div class="sast-week-grid">
      ${days.map(d => {
        const key = ymd(d);
        const items = byDay.get(key) || [];
        return `
          <div class="sast-week-col">
            <div class="sast-week-col-head">${escHtml(d.toLocaleDateString('sr-RS', { weekday: 'short', day: 'numeric', month: 'short' }))}</div>
            <div class="sast-week-col-body">
              ${items.length ? items.map(s => `
                <button type="button" class="sast-week-card" data-id="${escHtml(s.id)}">
                  <span class="sast-week-card-title">${escHtml(s.naslov)}</span>
                  ${renderStatusBadge(s.status, { kind: 'sastanak', className: 'sast-week-pill' })}
                  <small>${escHtml(SASTANAK_TIPOVI[s.tip] || s.tip)}</small>
                </button>
              `).join('') : '<span class="sast-week-empty">—</span>'}
            </div>
          </div>
        `;
      }).join('')}
    </div>
  `;

  host.querySelectorAll('.sast-week-card').forEach(btn => {
    btn.addEventListener('click', () => onOpen?.(btn.dataset.id));
  });
}
