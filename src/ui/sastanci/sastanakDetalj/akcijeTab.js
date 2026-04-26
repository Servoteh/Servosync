/**
 * Akcije tab — akcioni plan filtriran po sastanak_id.
 * Wrapper oko akcioniPlanTab logike sa pre-set filterom.
 */

import { escHtml, showToast } from '../../../lib/dom.js';
import { formatDate } from '../../../lib/date.js';
import {
  loadAkcije, saveAkcija, deleteAkcija, updateAkcijaStatus,
  mapDbAkcija, AKCIJA_STATUSI, AKCIJA_STATUS_BOJE,
} from '../../../services/akcioniPlan.js';
import { loadProjektiLite } from '../../../services/projekti.js';

let abortFlag = false;

export async function renderAkcijeTab(host, { sastanak, canWrite }) {
  abortFlag = false;
  host.innerHTML = '<div class="sast-loading">Učitavam akcije…</div>';

  let akcije, projekti;
  try {
    [akcije, projekti] = await Promise.all([
      loadAkcije({ sastanakId: sastanak.id, limit: 200 }),
      canWrite ? loadProjektiLite() : Promise.resolve([]),
    ]);
  } catch (e) {
    console.error('[AkcijeTab] load error', e);
    host.innerHTML = '<div class="sast-empty">⚠ Greška pri učitavanju.</div>';
    return;
  }

  if (abortFlag) return;
  renderContent(host, akcije, projekti, sastanak, canWrite);
}

function renderContent(host, akcije, projekti, sastanak, canWrite) {
  const sorted = [...akcije].sort((a, b) => {
    const ar = a.rok || '9999-12-31';
    const br = b.rok || '9999-12-31';
    return ar.localeCompare(br);
  });

  host.innerHTML = `
    <div class="sast-akcije-tab">
      <div class="sast-akcije-toolbar">
        <span class="sast-akcije-count">${sorted.length} akcija</span>
        ${canWrite ? `<button type="button" class="btn btn-primary btn-sm" id="sdNovaAkcija">+ Nova akcija</button>` : ''}
      </div>
      <div id="sdAkcijeList">
        ${sorted.length ? renderAkcijeTable(sorted, canWrite) : '<p class="sast-empty-inline">Nema akcija za ovaj sastanak.</p>'}
      </div>
    </div>
  `;

  if (canWrite) {
    host.querySelector('#sdNovaAkcija')?.addEventListener('click', () => {
      openAkcijaModal(host, null, projekti, sastanak, canWrite, () => {
        renderAkcijeTab(host, { sastanak, canWrite });
      });
    });
  }

  wireAkcijeActions(host, sorted, projekti, sastanak, canWrite);
}

function renderAkcijeTable(akcije, canWrite) {
  return `
    <table class="sast-table sast-akcije-table">
      <thead>
        <tr>
          <th>Naslov</th>
          <th>Odgovoran</th>
          <th>Rok</th>
          <th>Status</th>
          ${canWrite ? '<th></th>' : ''}
        </tr>
      </thead>
      <tbody>
        ${akcije.map(a => `
          <tr data-akcija-id="${escHtml(a.id)}" class="sast-akcija-row">
            <td>
              <span class="sast-akcija-naslov">${escHtml(a.naslov)}</span>
              ${a.opis ? `<br><small class="sast-txt2">${escHtml(a.opis.slice(0, 80))}${a.opis.length > 80 ? '…' : ''}</small>` : ''}
            </td>
            <td>${escHtml(a.odgLabel || a.odgText || a.odgEmail || '—')}</td>
            <td class="${rokClass(a.rok)}">${a.rok ? formatDate(a.rok) : '—'}</td>
            <td>
              <span class="sast-akcija-status" style="color:${AKCIJA_STATUS_BOJE[a.status] || '#888'}">
                ${escHtml(AKCIJA_STATUSI[a.status] || a.status)}
              </span>
            </td>
            ${canWrite ? `
              <td class="sast-akcija-btns">
                <button type="button" class="btn btn-sm" data-edit="${escHtml(a.id)}">✏</button>
                <button type="button" class="btn btn-sm btn-danger-ghost" data-del="${escHtml(a.id)}">🗑</button>
              </td>
            ` : ''}
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;
}

function rokClass(rok) {
  if (!rok) return '';
  const today = new Date().toISOString().slice(0, 10);
  const diff = (new Date(rok) - new Date(today)) / 86400000;
  if (diff < 0) return 'akcija-rok-kasni';
  if (diff <= 2) return 'akcija-rok-hitno';
  if (diff <= 7) return 'akcija-rok-uskoro';
  return '';
}

function wireAkcijeActions(host, akcije, projekti, sastanak, canWrite) {
  if (!canWrite) return;
  host.querySelectorAll('[data-edit]').forEach(btn => {
    const id = btn.dataset.edit;
    const a = akcije.find(x => x.id === id);
    if (!a) return;
    btn.addEventListener('click', () => {
      openAkcijaModal(host, a, projekti, sastanak, canWrite, () => {
        renderAkcijeTab(host, { sastanak, canWrite });
      });
    });
  });

  host.querySelectorAll('[data-del]').forEach(btn => {
    btn.addEventListener('click', async () => {
      if (!confirm('Obrisati akciju?')) return;
      const ok = await deleteAkcija(btn.dataset.del);
      if (ok) {
        showToast('Akcija obrisana');
        renderAkcijeTab(host, { sastanak, canWrite });
      } else {
        showToast('⚠ Nije uspelo');
      }
    });
  });
}

function openAkcijaModal(host, akcija, projekti, sastanak, canWrite, onSaved) {
  const isNew = !akcija;
  const a = akcija || {};
  const overlay = document.createElement('div');
  overlay.className = 'sast-modal-overlay';
  overlay.innerHTML = `
    <div class="sast-modal" role="dialog" aria-modal="true">
      <header class="sast-modal-header">
        <h3>${isNew ? 'Nova akcija' : 'Uredi akciju'}</h3>
        <button type="button" class="sast-modal-close" aria-label="Zatvori">✕</button>
      </header>
      <div class="sast-modal-body">
        <label class="sast-form-label">Naslov *
          <input type="text" class="input" id="aaNaslov" value="${escHtml(a.naslov || '')}" required>
        </label>
        <label class="sast-form-label">Opis
          <textarea class="input" id="aaOpis" rows="2">${escHtml(a.opis || '')}</textarea>
        </label>
        <div class="sast-form-row2">
          <label class="sast-form-label">Odgovoran
            <input type="text" class="input" id="aaOdg" value="${escHtml(a.odgLabel || a.odgText || '')}">
          </label>
          <label class="sast-form-label">Rok
            <input type="date" class="input" id="aaRok" value="${escHtml(a.rok || '')}">
          </label>
        </div>
        <label class="sast-form-label">Status
          <select class="input" id="aaStatus">
            ${Object.entries(AKCIJA_STATUSI).map(([v, l]) =>
              `<option value="${v}"${(a.status || 'otvoren') === v ? ' selected' : ''}>${escHtml(l)}</option>`
            ).join('')}
          </select>
        </label>
        <label class="sast-form-label">Projekat
          <select class="input" id="aaProjekat">
            <option value="">— bez projekta —</option>
            ${projekti.map(p => `<option value="${escHtml(p.id)}"${a.projekatId === p.id ? ' selected' : ''}>${escHtml(p.label)}</option>`).join('')}
          </select>
        </label>
      </div>
      <footer class="sast-modal-footer">
        <button type="button" class="btn btn-primary" id="aaSave">Sačuvaj</button>
        <button type="button" class="btn" data-action="close">Otkaži</button>
      </footer>
    </div>
  `;
  document.body.appendChild(overlay);
  const close = () => overlay.remove();
  overlay.addEventListener('click', e => { if (e.target === overlay) close(); });
  overlay.querySelector('.sast-modal-close')?.addEventListener('click', close);
  overlay.querySelector('[data-action=close]')?.addEventListener('click', close);

  overlay.querySelector('#aaSave')?.addEventListener('click', async () => {
    const naslov = overlay.querySelector('#aaNaslov').value.trim();
    if (!naslov) { showToast('⚠ Naslov je obavezan'); return; }
    const payload = {
      ...(a.id ? { id: a.id } : {}),
      naslov,
      opis: overlay.querySelector('#aaOpis').value.trim() || null,
      odgText: overlay.querySelector('#aaOdg').value.trim() || null,
      odgLabel: overlay.querySelector('#aaOdg').value.trim() || null,
      rok: overlay.querySelector('#aaRok').value || null,
      status: overlay.querySelector('#aaStatus').value,
      projekatId: overlay.querySelector('#aaProjekat').value || null,
      sastanakId: sastanak.id,
    };
    const saved = await saveAkcija(payload);
    if (saved) {
      showToast(isNew ? '✅ Akcija kreirana' : '✅ Sačuvano');
      close();
      onSaved();
    } else {
      showToast('⚠ Nije uspelo');
    }
  });
}

export function teardownAkcijeTab() {
  abortFlag = true;
}
