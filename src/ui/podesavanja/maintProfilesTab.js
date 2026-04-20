/**
 * Podešavanja → Održavanje profili (maint_user_profiles).
 * Samo ERP admin (ulaz u modul već ograničen).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  fetchAllMaintProfiles,
  insertMaintProfile,
  patchMaintProfile,
} from '../../services/maintenance.js';

const ROLES = ['operator', 'technician', 'chief', 'management', 'admin'];

let _items = [];

export async function refreshMaintProfiles() {
  const rows = await fetchAllMaintProfiles();
  _items = Array.isArray(rows) ? rows : [];
  return _items;
}

export function renderMaintProfilesTab() {
  const rows = _items;
  if (!rows.length) {
    return `
      <div class="kadr-summary-strip"><span class="kadr-count">0 profila</span></div>
      <p class="mnt-muted" style="padding:12px 0">Nema redova. Dodaj prvi profil ispod.</p>
      <p><button type="button" class="btn" id="mntProfAddEmpty">+ Novi profil</button></p>`;
  }
  const body = rows
    .map(r => {
      const mc = Array.isArray(r.assigned_machine_codes) ? r.assigned_machine_codes.join(', ') : '';
      const uid = String(r.user_id || '');
      const uidShort = uid.length > 12 ? `${uid.slice(0, 8)}…` : uid;
      return `<tr>
        <td><code title="${escHtml(uid)}">${escHtml(uidShort)}</code></td>
        <td>${escHtml(r.full_name || '')}</td>
        <td>${escHtml(String(r.role || ''))}</td>
        <td>${escHtml(r.phone || '—')}</td>
        <td style="max-width:180px;overflow:hidden;text-overflow:ellipsis" title="${escHtml(mc)}">${escHtml(mc || '—')}</td>
        <td>${r.active ? 'da' : 'ne'}</td>
        <td><button type="button" class="kadr-action-btn" data-mnt-prof-edit="${escHtml(uid)}" title="Izmeni">✎</button></td>
      </tr>`;
    })
    .join('');
  return `
    <div class="kadr-summary-strip"><span class="kadr-count">${rows.length} profila</span></div>
    <p class="form-hint" style="margin-bottom:12px">UUID korisnika uzmi iz Supabase <strong>Authentication → Users</strong>. Dodela mašina: <code>rj_code</code> odvojeni zarezom.</p>
    <div class="mnt-table-wrap" style="margin-bottom:16px">
      <table class="mnt-table" style="font-size:13px">
        <thead><tr><th>user_id</th><th>Ime</th><th>Uloga</th><th>Telefon</th><th>Mašine</th><th>Akt.</th><th></th></tr></thead>
        <tbody>${body}</tbody>
      </table>
    </div>
    <p><button type="button" class="btn" id="mntProfAddBtn">+ Novi profil</button></p>`;
}

/**
 * @param {HTMLElement} root
 * @param {{ onChange?: () => void }} [opts]
 */
export function wireMaintProfilesTab(root, opts = {}) {
  const onChange = opts.onChange || null;

  const openModal = (existing = null) => {
    document.getElementById('mntProfDlg')?.remove();
    const isEdit = !!existing;
    const wrap = document.createElement('div');
    wrap.id = 'mntProfDlg';
    wrap.className = 'kadr-modal-overlay';
    wrap.innerHTML = `
      <div class="kadr-modal" style="max-width:480px">
        <div class="kadr-modal-title">${isEdit ? 'Izmeni profil održavanja' : 'Novi profil održavanja'}</div>
        <div class="kadr-modal-err" id="mntProfDlgErr"></div>
        <form id="mntProfDlgForm">
          <label class="form-label">User ID (UUID) *</label>
          <input class="form-input" name="user_id" id="mntProfUid" required ${isEdit ? 'readonly' : ''} value="${escHtml(existing?.user_id || '')}">
          <label class="form-label">Puno ime *</label>
          <input class="form-input" name="full_name" id="mntProfName" required value="${escHtml(existing?.full_name || '')}">
          <label class="form-label">Uloga</label>
          <select class="form-input" id="mntProfRole" name="role">
            ${ROLES.map(
              role =>
                `<option value="${role}"${String(existing?.role) === role ? ' selected' : ''}>${escHtml(role)}</option>`,
            ).join('')}
          </select>
          <label class="form-label">Telefon — WhatsApp (E.164)</label>
          <input class="form-input" id="mntProfPhone" value="${escHtml(existing?.phone || '')}" placeholder="+38163123456">
          <p class="form-hint" style="margin-top:-6px;font-size:12px">Format <code>+ZemljaBroj</code> bez razmaka. Worker za WhatsApp Business notifikacije čita ovo polje.</p>
          <label class="form-label">Telegram chat id (pauzirano)</label>
          <input class="form-input" id="mntProfTg" value="${escHtml(existing?.telegram_chat_id || '')}" placeholder="">
          <label class="form-label">Dodeljene mašine (rj_code, zarez)</label>
          <input class="form-input" id="mntProfMc" value="${escHtml(Array.isArray(existing?.assigned_machine_codes) ? existing.assigned_machine_codes.join(', ') : '')}" placeholder="8.3, 10.1">
          <label class="form-label" style="display:flex;align-items:center;gap:8px;margin-top:8px">
            <input type="checkbox" id="mntProfActive" ${existing && existing.active === false ? '' : 'checked'}> Aktivan
          </label>
          <div class="kadr-modal-actions" style="margin-top:16px">
            <button type="button" class="btn" id="mntProfDlgCancel" style="background:var(--surface3)">Otkaži</button>
            <button type="submit" class="btn" id="mntProfDlgSave">${isEdit ? 'Sačuvaj' : 'Dodaj'}</button>
          </div>
        </form>
      </div>`;
    document.body.appendChild(wrap);

    const close = () => wrap.remove();
    wrap.addEventListener('click', e => {
      if (e.target === wrap) close();
    });
    wrap.querySelector('#mntProfDlgCancel')?.addEventListener('click', close);

    wrap.querySelector('#mntProfDlgForm')?.addEventListener('submit', async e => {
      e.preventDefault();
      const errEl = wrap.querySelector('#mntProfDlgErr');
      if (errEl) errEl.textContent = '';
      const userId = wrap.querySelector('#mntProfUid')?.value?.trim();
      const fullName = wrap.querySelector('#mntProfName')?.value?.trim();
      const role = wrap.querySelector('#mntProfRole')?.value;
      const telegram = wrap.querySelector('#mntProfTg')?.value?.trim() || null;
      const phoneRaw = wrap.querySelector('#mntProfPhone')?.value?.trim() || '';
      let phone = phoneRaw || null;
      if (phone && !/^\+\d{6,15}$/.test(phone)) {
        if (errEl) errEl.textContent = 'Telefon mora biti u E.164 formatu, npr. +38163123456.';
        return;
      }
      const mcRaw = wrap.querySelector('#mntProfMc')?.value || '';
      const assigned_machine_codes = mcRaw
        .split(',')
        .map(s => s.trim())
        .filter(Boolean);
      const active = !!wrap.querySelector('#mntProfActive')?.checked;
      if (!userId || !fullName) {
        if (errEl) errEl.textContent = 'UUID i ime su obavezni.';
        return;
      }
      const btn = wrap.querySelector('#mntProfDlgSave');
      if (btn) btn.disabled = true;
      let ok = false;
      if (isEdit) {
        const res = await patchMaintProfile(userId, {
          full_name: fullName,
          role,
          telegram_chat_id: telegram,
          phone,
          assigned_machine_codes,
          active,
        });
        ok = res !== null;
      } else {
        const res = await insertMaintProfile({
          user_id: userId,
          full_name: fullName,
          role,
          telegram_chat_id: telegram,
          phone,
          assigned_machine_codes,
          active,
        });
        ok = res !== null;
      }
      if (btn) btn.disabled = false;
      if (!ok) {
        if (errEl) errEl.textContent = 'Operacija nije uspela (duplikat UUID ili RLS).';
        showToast('⚠ Greška pri snimanju');
        return;
      }
      showToast(isEdit ? '✏️ Profil ažuriran' : '✅ Profil dodat');
      close();
      await refreshMaintProfiles();
      onChange?.();
    });
  };

  root.querySelector('#mntProfAddBtn')?.addEventListener('click', () => openModal(null));
  root.querySelector('#mntProfAddEmpty')?.addEventListener('click', () => openModal(null));
  root.querySelectorAll('[data-mnt-prof-edit]').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-mnt-prof-edit');
      const row = _items.find(x => String(x.user_id) === id);
      if (row) openModal(row);
    });
  });
}
