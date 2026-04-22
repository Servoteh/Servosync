/**
 * Modal: manuelni override statusa mašine (`maint_machine_status_override`).
 * RLS dozvoljava upsert/delete samo chief/admin maint ili ERP admin.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { isAdminOrMenadzment } from '../../state/auth.js';
import {
  upsertMaintMachineOverride,
  deleteMaintMachineOverride,
} from '../../services/maintenance.js';

const STATUSES = [
  { v: 'running', l: 'Radi' },
  { v: 'degraded', l: 'Degradirano' },
  { v: 'down', l: 'Ne radi' },
  { v: 'maintenance', l: 'U održavanju' },
];

/**
 * @param {object|null} prof maint_user_profiles ili null
 */
export function canManageMaintOverride(prof) {
  if (isAdminOrMenadzment()) return true;
  return prof?.role === 'chief' || prof?.role === 'admin';
}

/**
 * ISO → "YYYY-MM-DDTHH:mm" za datetime-local input (lokalna TZ).
 * @param {string|null} iso
 */
function toLocalInputValue(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/**
 * Lokalna datetime-local string → ISO (UTC).
 * @param {string} localStr
 */
function fromLocalInputValue(localStr) {
  if (!localStr) return null;
  const d = new Date(localStr);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

/**
 * @param {{ machineCode: string, existing: object|null, onSaved?: () => void }} opts
 */
export function openMaintOverrideModal(opts) {
  const { machineCode, existing = null, onSaved } = opts;
  document.getElementById('mntOvrDlg')?.remove();

  const isEdit = !!existing;
  const statusOpts = STATUSES.map(
    s =>
      `<option value="${s.v}"${String(existing?.status || 'maintenance') === s.v ? ' selected' : ''}>${s.l}</option>`,
  ).join('');

  const validUntilLocal = toLocalInputValue(existing?.valid_until || null);
  const isPerm = !existing?.valid_until;

  const wrap = document.createElement('div');
  wrap.id = 'mntOvrDlg';
  wrap.className = 'kadr-modal-overlay';
  wrap.innerHTML = `
    <div class="kadr-modal" style="max-width:460px">
      <div class="kadr-modal-title">${isEdit ? 'Izmeni override statusa' : 'Postavi override statusa'}</div>
      <div class="kadr-modal-subtitle">Mašina <code>${escHtml(machineCode)}</code></div>
      <div class="kadr-modal-err" id="mntOvrDlgErr"></div>
      <form id="mntOvrDlgForm">
        <label class="form-label">Status *</label>
        <select class="form-input" id="mntOvrStatus" required>${statusOpts}</select>
        <label class="form-label">Razlog *</label>
        <textarea class="form-input" id="mntOvrReason" rows="3" required maxlength="500" placeholder="Zašto je postavljen override (vidljivo svima)">${escHtml(existing?.reason || '')}</textarea>
        <label class="form-label" style="display:flex;align-items:center;gap:8px;margin-top:8px">
          <input type="checkbox" id="mntOvrPerm" ${isPerm ? 'checked' : ''}> Trajno (dok ručno ne skineš)
        </label>
        <label class="form-label">Važi do (lokalno vreme)</label>
        <input type="datetime-local" class="form-input" id="mntOvrUntil" value="${escHtml(validUntilLocal)}" ${isPerm ? 'disabled' : ''}>
        <div class="kadr-modal-actions" style="margin-top:16px;display:flex;gap:8px;flex-wrap:wrap">
          ${isEdit ? `<button type="button" class="btn" id="mntOvrDelete" style="background:var(--red-bg);color:var(--red)">Ukloni override</button>` : ''}
          <span style="flex:1"></span>
          <button type="button" class="btn" id="mntOvrDlgCancel" style="background:var(--surface3)">Otkaži</button>
          <button type="submit" class="btn" id="mntOvrDlgSave">Sačuvaj</button>
        </div>
      </form>
    </div>`;
  document.body.appendChild(wrap);

  const close = () => wrap.remove();
  wrap.addEventListener('click', e => {
    if (e.target === wrap) close();
  });
  wrap.querySelector('#mntOvrDlgCancel')?.addEventListener('click', close);

  const permChk = wrap.querySelector('#mntOvrPerm');
  const untilEl = wrap.querySelector('#mntOvrUntil');
  permChk?.addEventListener('change', () => {
    if (!(untilEl instanceof HTMLInputElement)) return;
    untilEl.disabled = !!permChk.checked;
    if (permChk.checked) untilEl.value = '';
  });

  wrap.querySelector('#mntOvrDlgForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const errEl = wrap.querySelector('#mntOvrDlgErr');
    if (errEl) errEl.textContent = '';
    const status = wrap.querySelector('#mntOvrStatus')?.value;
    const reason = wrap.querySelector('#mntOvrReason')?.value?.trim();
    const perm = !!permChk?.checked;
    const untilRaw = untilEl instanceof HTMLInputElement ? untilEl.value : '';
    if (!status || !reason) {
      if (errEl) errEl.textContent = 'Status i razlog su obavezni.';
      return;
    }
    let valid_until = null;
    if (!perm) {
      valid_until = fromLocalInputValue(untilRaw);
      if (!valid_until) {
        if (errEl) errEl.textContent = 'Unesi datum-vreme do kada važi, ili označi „Trajno”.';
        return;
      }
      if (new Date(valid_until).getTime() <= Date.now()) {
        if (errEl) errEl.textContent = 'Vreme mora biti u budućnosti.';
        return;
      }
    }

    const btn = wrap.querySelector('#mntOvrDlgSave');
    if (btn) btn.disabled = true;
    const ok = await upsertMaintMachineOverride({
      machine_code: machineCode,
      status,
      reason,
      valid_until,
    });
    if (btn) btn.disabled = false;
    if (!ok) {
      if (errEl) errEl.textContent = 'Snimanje nije uspelo (RLS ili mreža).';
      showToast('⚠ Greška');
      return;
    }
    showToast('✅ Override sačuvan');
    close();
    onSaved?.();
  });

  wrap.querySelector('#mntOvrDelete')?.addEventListener('click', async () => {
    const confirmed = window.confirm('Ukloniti override? Status se vraća na automatski izračunat.');
    if (!confirmed) return;
    const ok = await deleteMaintMachineOverride(machineCode);
    if (!ok) {
      showToast('⚠ Uklanjanje nije uspelo');
      return;
    }
    showToast('🗑 Override uklonjen');
    close();
    onSaved?.();
  });
}
