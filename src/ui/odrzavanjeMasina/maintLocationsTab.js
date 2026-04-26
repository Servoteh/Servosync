/**
 * Tab „Lokacije” (hijerarhija `maint_locations`).
 * URL: /maintenance/locations
 *
 * Čitanje: `maint_has_floor_read_access()` (široka fabrika).
 * Pisanje: šef/admin održavanja ili ERP admin (isto kao katalog mašina).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  fetchMaintLocations,
  insertMaintLocation,
  patchMaintLocation,
} from '../../services/maintenance.js';
import { canManageMaintCatalog } from './maintCatalogTab.js';

function escAttr(v) {
  return escHtml(v == null ? '' : String(v)).replace(/"/g, '&quot;');
}

/**
 * @param {object|null} prof
 */
export function canManageMaintLocations(prof) {
  return canManageMaintCatalog(prof);
}

/**
 * @param {HTMLElement} host
 * @param {{ prof: object|null, onNavigateToPath?: (p: string) => void }} opts
 */
export async function renderMaintLocationsPanel(host, opts) {
  const { prof } = opts;
  const canEdit = canManageMaintLocations(prof);

  host.innerHTML = `<div class="mnt-panel"><p class="mnt-muted">Učitavam lokacije…</p></div>`;

  const rows = await fetchMaintLocations();
  if (rows === null) {
    host.innerHTML = `<div class="mnt-panel"><p class="mnt-muted">Ne mogu da učitam lokacije (migracija ili prava).</p></div>`;
    return;
  }

  const nameById = new Map((rows || []).map(r => [r.location_id, r.name || '']));

  const parentOptions = (excludeId) => {
    const list = [...(rows || [])].filter(r => r.location_id !== excludeId);
    list.sort((a, b) => String(a.name || '').localeCompare(String(b.name || ''), 'sr'));
    return list
      .map(
        r =>
          `<option value="${escHtml(r.location_id)}">${escHtml(r.name || r.location_id)}</option>`,
      )
      .join('');
  };

  const rowHtml = r => {
    const parentName = r.parent_location_id
      ? nameById.get(r.parent_location_id) || '—'
      : '—';
    const act = r.active === false ? '<span class="mnt-muted">Neaktivno</span>' : 'Da';
    const actions = canEdit
      ? `<button type="button" class="mnt-btn mnt-btn--small" data-mnt-loc-edit="${escAttr(r.location_id)}">Izmeni</button>
         <button type="button" class="mnt-btn mnt-btn--small" data-mnt-loc-toggle="${escAttr(r.location_id)}" data-mnt-loc-active="${r.active === false ? '0' : '1'}">${r.active === false ? 'Aktiviraj' : 'Deaktiviraj'}</button>`
      : '';
    return `<tr>
      <td>${escHtml(r.name || '')}</td>
      <td>${escHtml(r.code || '')}</td>
      <td>${escHtml(r.location_type || '')}</td>
      <td class="mnt-muted">${escHtml(parentName)}</td>
      <td>${act}</td>
      <td>${actions}</td>
    </tr>`;
  };

  const table = (rows || []).length
    ? `<table class="mnt-table">
        <thead><tr><th>Naziv</th><th>Šifra</th><th>Tip</th><th>Pod lokacija</th><th>Aktivno</th><th></th></tr></thead>
        <tbody>${(rows || []).map(rowHtml).join('')}</tbody>
      </table>`
    : '<p class="mnt-muted">Nema unetih lokacija.</p>';

  const form = canEdit
    ? `<div class="mnt-loc-form" style="margin-bottom:20px;padding:12px;border:1px solid var(--border, #3336);border-radius:8px">
        <h3 class="mnt-h3" style="margin:0 0 8px">Nova lokacija</h3>
        <div class="mnt-row" style="display:flex;flex-wrap:wrap;gap:8px;align-items:flex-end">
          <label style="display:flex;flex-direction:column;gap:2px">Naziv *
            <input type="text" id="mntLocNewName" class="mnt-input" maxlength="500" required />
          </label>
          <label style="display:flex;flex-direction:column;gap:2px">Šifra
            <input type="text" id="mntLocNewCode" class="mnt-input" maxlength="200" />
          </label>
          <label style="display:flex;flex-direction:column;gap:2px">Tip
            <input type="text" id="mntLocNewType" class="mnt-input" value="lokacija" maxlength="80" />
          </label>
          <label style="display:flex;flex-direction:column;gap:2px">Podređena
            <select id="mntLocNewParent" class="mnt-input"><option value="">— nema —</option>${parentOptions(null)}</select>
          </label>
          <button type="button" class="mnt-btn" id="mntLocAddBtn">Dodaj</button>
        </div>
      </div>`
    : '<p class="mnt-muted" style="margin-bottom:12px">Pregled samo. Izmenu rade šef/admin održavanja ili ERP admin.</p>';

  host.innerHTML = `<div class="mnt-panel">
    <h2 class="mnt-h2">Lokacije (hijerarhija)</h2>
    <p class="mnt-muted" style="margin:4px 0 16px">Kasnije se mogu vezati na sredstva u <code>maint_assets</code> (npr. mašine, vozila).</p>
    ${form}
    ${table}
  </div>`;

  if (canEdit) {
    host.querySelector('#mntLocAddBtn')?.addEventListener('click', async () => {
      const name = host.querySelector('#mntLocNewName')?.value?.trim() || '';
      if (!name) {
        showToast('⚠ Unesi naziv');
        return;
      }
      const code = host.querySelector('#mntLocNewCode')?.value?.trim() || null;
      const location_type = host.querySelector('#mntLocNewType')?.value?.trim() || 'lokacija';
      const psel = host.querySelector('#mntLocNewParent')?.value || '';
      const parent_location_id = psel || null;
      const created = await insertMaintLocation({
        name,
        code,
        location_type,
        parent_location_id,
      });
      if (!created) {
        showToast('⚠ Snimanje nije uspelo (proveri prava ili podatke).');
        return;
      }
      showToast('✅ Lokacija dodata');
      await renderMaintLocationsPanel(host, opts);
    });
  }

  host.querySelectorAll('[data-mnt-loc-toggle]').forEach(btn => {
    btn.addEventListener('click', async () => {
      if (!canEdit) return;
      const id = btn.getAttribute('data-mnt-loc-toggle');
      const was = btn.getAttribute('data-mnt-loc-active') === '1';
      const ok = await patchMaintLocation(id, { active: !was });
      if (!ok) {
        showToast('⚠ Izmena nije dozvoljena');
        return;
      }
      showToast('✅ Ažurirano');
      await renderMaintLocationsPanel(host, opts);
    });
  });

  const parentSelectHtml = (excludeId, currentParentId) => {
    const list = [...(rows || [])].filter(x => x.location_id !== excludeId);
    list.sort((a, b) => String(a.name || '').localeCompare(String(b.name || ''), 'sr'));
    let s = '<option value="">— nema —</option>';
    for (const o of list) {
      const selected = o.location_id === currentParentId ? ' selected' : '';
      s += `<option value="${escHtml(o.location_id)}"${selected}>${escHtml(o.name || o.location_id)}</option>`;
    }
    if (!currentParentId) {
      s = s.replace(/<option value="">/, '<option value="" selected>');
    }
    return s;
  };

  host.querySelectorAll('[data-mnt-loc-edit]').forEach(btn => {
    btn.addEventListener('click', () => {
      if (!canEdit) return;
      const id = btn.getAttribute('data-mnt-loc-edit');
      const r = (rows || []).find(x => x.location_id === id);
      if (!r) return;
      const n = r.name == null ? '' : String(r.name);
      const c = r.code == null ? '' : String(r.code);
      const t = r.location_type == null ? '' : String(r.location_type);

      const dlg = document.createElement('div');
      dlg.className = 'kadr-modal-overlay';
      dlg.innerHTML = `<div class="kadr-modal" style="max-width:520px" role="dialog" aria-modal="true">
        <div class="kadr-modal-title">Izmeni lokaciju</div>
        <div class="kadr-modal-subtitle mnt-muted">Hijerarhija: podređena lokacija mora postojati u listi.</div>
        <div style="display:grid;gap:10px;margin-top:8px">
          <div><label class="form-label" for="mntLocEname">Naziv *</label>
            <input class="form-input" id="mntLocEname" value="${escAttr(n)}" maxlength="500" required /></div>
          <div><label class="form-label" for="mntLocEcode">Šifra</label>
            <input class="form-input" id="mntLocEcode" value="${escAttr(c)}" maxlength="200" /></div>
          <div><label class="form-label" for="mntLocEtype">Tip</label>
            <input class="form-input" id="mntLocEtype" value="${escAttr(t || 'lokacija')}" maxlength="80" /></div>
          <div><label class="form-label" for="mntLocEpar">Podređena</label>
            <select class="form-input" id="mntLocEpar">${parentSelectHtml(id, r.parent_location_id || null)}</select></div>
        </div>
        <div class="kadr-modal-actions" style="margin-top:16px;display:flex;gap:8px;flex-wrap:wrap;justify-content:flex-end">
          <button type="button" class="btn" id="mntLocEcancel" style="background:var(--surface3)">Otkaži</button>
          <button type="button" class="btn" id="mntLocEok">Sačuvaj</button>
        </div>
      </div>`;
      document.body.appendChild(dlg);
      const close = () => {
        dlg.remove();
      };
      dlg.querySelector('#mntLocEcancel')?.addEventListener('click', close);
      dlg.addEventListener('click', e => {
        if (e.target === dlg) close();
      });
      dlg.querySelector('#mntLocEok')?.addEventListener('click', async () => {
        const name = dlg.querySelector('#mntLocEname')?.value?.trim() || '';
        if (!name) {
          showToast('⚠ Naziv je obavezan');
          return;
        }
        const codeRaw = dlg.querySelector('#mntLocEcode')?.value?.trim();
        const code = codeRaw || null;
        const location_type = dlg.querySelector('#mntLocEtype')?.value?.trim() || 'lokacija';
        const psel = dlg.querySelector('#mntLocEpar')?.value || '';
        const parent_location_id = psel || null;
        const ok = await patchMaintLocation(id, {
          name,
          code,
          location_type,
          parent_location_id,
        });
        if (!ok) {
          showToast('⚠ Snimanje nije uspelo');
          return;
        }
        close();
        showToast('✅ Sačuvano');
        await renderMaintLocationsPanel(host, opts);
      });
    });
  });
}
