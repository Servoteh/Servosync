import { escHtml, showToast } from '../../../lib/dom.js';
import { formatDate } from '../../../lib/date.js';
import {
  loadOdlukeBySastanak, saveOdluka, deleteOdluka, ODLUKA_STATUSI,
} from '../../../services/sastanciOdluke.js';
import { renderEmptyStateHtml } from '../emptyState.js';

let abortFlag = false;

export async function renderOdlukeTab(host, { sastanak, canWrite, isReadOnly }) {
  abortFlag = false;
  const locked = isReadOnly || !canWrite;
  host.innerHTML = '<div class="sast-loading">Učitavam odluke…</div>';

  let rows;
  try {
    rows = await loadOdlukeBySastanak(sastanak.id);
  } catch (e) {
    host.innerHTML = renderEmptyStateHtml({ title: 'Greška pri učitavanju odluka.' });
    return;
  }
  if (abortFlag) return;

  host.innerHTML = `
    <div class="sast-odluke">
      ${!locked ? '<button type="button" class="btn btn-primary" id="odAdd">+ Nova odluka</button>' : ''}
      <div id="odTableWrap" class="sast-table-wrap">
        ${rows.length ? renderTable(rows, locked) : renderEmptyStateHtml({ title: 'Nema zabeleženih odluka.' })}
      </div>
    </div>
  `;

  if (!locked) {
    host.querySelector('#odAdd')?.addEventListener('click', async () => {
      const created = await saveOdluka({
        sastanakId: sastanak.id,
        naslov: 'Nova odluka',
        rb: rows.length + 1,
        status: 'na_snazi',
      });
      if (created) {
        rows.push(created);
        host.querySelector('#odTableWrap').innerHTML = renderTable(rows, locked);
        wireRows(host, rows, sastanak, locked);
        showToast('✅ Dodata odluka');
      } else showToast('⚠ Nije uspelo');
    });
  }
  wireRows(host, rows, sastanak, locked);
}

function renderTable(rows, locked) {
  return `
    <table class="sast-table sast-odluke-table">
      <thead><tr>
        <th>RB</th><th>Naslov</th><th>Odlučio</th><th>Datum</th><th>Status</th>
        ${!locked ? '<th></th>' : ''}
      </tr></thead>
      <tbody>
        ${rows.map(o => `
          <tr data-id="${escHtml(o.id)}">
            <td><input type="number" class="input input-sm od-rb" value="${o.rb ?? ''}" ${locked ? 'disabled' : ''}></td>
            <td><input type="text" class="input od-naslov" value="${escHtml(o.naslov)}" ${locked ? 'disabled' : ''}></td>
            <td><input type="text" class="input input-sm od-odlucio" value="${escHtml(o.odlucioLabel || o.odlucioEmail || '')}" ${locked ? 'disabled' : ''}></td>
            <td><input type="date" class="input input-sm od-datum" value="${escHtml(o.odlukaDatum || '')}" ${locked ? 'disabled' : ''}></td>
            <td>
              <select class="input input-sm od-status" ${locked ? 'disabled' : ''}>
                ${Object.entries(ODLUKA_STATUSI).map(([k, v]) =>
    `<option value="${k}"${o.status === k ? ' selected' : ''}>${escHtml(v)}</option>`).join('')}
              </select>
            </td>
            ${!locked ? `<td><button type="button" class="btn btn-sm btn-danger-ghost od-del">🗑</button></td>` : ''}
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;
}

function wireRows(host, rows, sastanak, locked) {
  if (locked) return;
  host.querySelectorAll('tbody tr[data-id]').forEach(tr => {
    const id = tr.dataset.id;
    const o = rows.find(x => x.id === id);
    if (!o) return;

    const persist = async () => {
      const saved = await saveOdluka({
        ...o,
        sastanakId: sastanak.id,
        rb: Number(tr.querySelector('.od-rb')?.value) || null,
        naslov: tr.querySelector('.od-naslov')?.value || '',
        odlucioLabel: tr.querySelector('.od-odlucio')?.value || '',
        odlukaDatum: tr.querySelector('.od-datum')?.value || null,
        status: tr.querySelector('.od-status')?.value || 'na_snazi',
      });
      if (!saved) showToast('⚠ Čuvanje nije uspelo');
    };

    tr.querySelectorAll('input,select').forEach(el => {
      el.addEventListener('change', () => void persist());
      el.addEventListener('blur', () => void persist());
    });

    tr.querySelector('.od-del')?.addEventListener('click', async () => {
      if (!confirm('Obrisati odluku?')) return;
      if (await deleteOdluka(id)) {
        tr.remove();
        const i = rows.findIndex(x => x.id === id);
        if (i >= 0) rows.splice(i, 1);
      }
    });
  });
}

export function teardownOdlukeTab() {
  abortFlag = true;
}
