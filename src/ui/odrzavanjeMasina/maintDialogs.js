/**
 * Modali za potvrdu kontrole i prijavu incidenta (kadr-modal stil).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  insertMaintCheck,
  insertMaintIncident,
} from '../../services/maintenance.js';

function removeIfExists(id) {
  document.getElementById(id)?.remove();
}

/**
 * @param {{ machineCode: string, tasks: Array<{ id: string, title?: string }>, preselectTaskId?: string|null, onSaved?: () => void }} opts
 */
export function openConfirmCheckModal(opts) {
  const { machineCode, tasks, preselectTaskId, onSaved } = opts;
  removeIfExists('mntDlgCheck');

  const taskOpts = (tasks || [])
    .map(t => {
      const sel = t.id === preselectTaskId ? ' selected' : '';
      return `<option value="${escHtml(String(t.id))}"${sel}>${escHtml(t.title || t.id)}</option>`;
    })
    .join('');

  const wrap = document.createElement('div');
  wrap.id = 'mntDlgCheck';
  wrap.className = 'kadr-modal-overlay';
  wrap.setAttribute('role', 'dialog');
  wrap.setAttribute('aria-modal', 'true');
  wrap.innerHTML = `
    <div class="kadr-modal" style="max-width:440px">
      <div class="kadr-modal-title">Potvrdi preventivnu kontrolu</div>
      <div class="kadr-modal-subtitle">Mašina <code>${escHtml(machineCode)}</code></div>
      <div class="kadr-modal-err" id="mntDlgCheckErr"></div>
      <form id="mntDlgCheckForm">
        <label class="form-label">Kontrola (task)</label>
        <select class="form-input" id="mntDlgCheckTask" required>${taskOpts || '<option value="">— Nema aktivnih taskova —</option>'}</select>
        <label class="form-label">Rezultat</label>
        <select class="form-input" id="mntDlgCheckResult">
          <option value="ok">OK</option>
          <option value="warning">Zamerka (warning)</option>
          <option value="fail">Ne prolazi (fail)</option>
          <option value="skipped">Preskočeno</option>
        </select>
        <label class="form-label">Napomena (opciono)</label>
        <textarea class="form-input" id="mntDlgCheckNotes" rows="3" placeholder=""></textarea>
        <div class="kadr-modal-actions" style="margin-top:16px">
          <button type="button" class="btn btn-secondary" id="mntDlgCheckCancel">Otkaži</button>
          <button type="submit" class="btn" id="mntDlgCheckSave">Sačuvaj</button>
        </div>
      </form>
    </div>`;
  document.body.appendChild(wrap);

  const close = () => wrap.remove();
  wrap.addEventListener('click', e => {
    if (e.target === wrap) close();
  });
  wrap.querySelector('#mntDlgCheckCancel')?.addEventListener('click', close);

  wrap.querySelector('#mntDlgCheckForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const errEl = wrap.querySelector('#mntDlgCheckErr');
    if (errEl) errEl.textContent = '';
    const taskId = wrap.querySelector('#mntDlgCheckTask')?.value;
    if (!taskId) {
      if (errEl) errEl.textContent = 'Izaberi kontrolu.';
      return;
    }
    const result = wrap.querySelector('#mntDlgCheckResult')?.value || 'ok';
    const notes = wrap.querySelector('#mntDlgCheckNotes')?.value?.trim() || null;
    const btn = wrap.querySelector('#mntDlgCheckSave');
    if (btn) btn.disabled = true;
    const row = await insertMaintCheck({ task_id: taskId, machine_code: machineCode, result, notes });
    if (btn) btn.disabled = false;
    if (!row) {
      if (errEl) errEl.textContent = 'Snimanje nije uspelo (RLS ili mreža).';
      showToast('⚠ Kontrola nije sačuvana');
      return;
    }
    showToast('✅ Kontrola zabeležena');
    close();
    onSaved?.();
  });

  setTimeout(() => wrap.querySelector('#mntDlgCheckTask')?.focus(), 50);
}

/**
 * @param {{ machineCode: string, onSaved?: () => void }} opts
 */
export function openReportIncidentModal(opts) {
  const { machineCode, onSaved } = opts;
  removeIfExists('mntDlgInc');

  const wrap = document.createElement('div');
  wrap.id = 'mntDlgInc';
  wrap.className = 'kadr-modal-overlay';
  wrap.setAttribute('role', 'dialog');
  wrap.setAttribute('aria-modal', 'true');
  wrap.innerHTML = `
    <div class="kadr-modal" style="max-width:480px">
      <div class="kadr-modal-title">Prijavi incident</div>
      <div class="kadr-modal-subtitle">Mašina <code>${escHtml(machineCode)}</code></div>
      <div class="kadr-modal-err" id="mntDlgIncErr"></div>
      <form id="mntDlgIncForm">
        <label class="form-label">Naslov *</label>
        <input type="text" class="form-input" id="mntDlgIncTitle" required maxlength="200" placeholder="Kratak opis kvara">
        <label class="form-label">Ozbiljnost</label>
        <select class="form-input" id="mntDlgIncSev">
          <option value="minor">Manje (minor)</option>
          <option value="major">Veće (major)</option>
          <option value="critical">Kritično (critical)</option>
        </select>
        <label class="form-label">Opis</label>
        <textarea class="form-input" id="mntDlgIncDesc" rows="4" placeholder="Detalji, šta se dešava…"></textarea>
        <div class="kadr-modal-actions" style="margin-top:16px">
          <button type="button" class="btn btn-secondary" id="mntDlgIncCancel">Otkaži</button>
          <button type="submit" class="btn" id="mntDlgIncSave">Prijavi</button>
        </div>
      </form>
    </div>`;
  document.body.appendChild(wrap);

  const close = () => wrap.remove();
  wrap.addEventListener('click', e => {
    if (e.target === wrap) close();
  });
  wrap.querySelector('#mntDlgIncCancel')?.addEventListener('click', close);

  wrap.querySelector('#mntDlgIncForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const errEl = wrap.querySelector('#mntDlgIncErr');
    if (errEl) errEl.textContent = '';
    const title = wrap.querySelector('#mntDlgIncTitle')?.value?.trim();
    if (!title) {
      if (errEl) errEl.textContent = 'Naslov je obavezan.';
      return;
    }
    const severity = wrap.querySelector('#mntDlgIncSev')?.value || 'minor';
    const description = wrap.querySelector('#mntDlgIncDesc')?.value?.trim() || null;
    const btn = wrap.querySelector('#mntDlgIncSave');
    if (btn) btn.disabled = true;
    const inc = await insertMaintIncident({ machine_code: machineCode, title, description, severity });
    if (btn) btn.disabled = false;
    if (!inc?.id) {
      if (errEl) errEl.textContent = 'Prijava nije uspela (RLS ili mreža).';
      showToast('⚠ Incident nije prijavljen');
      return;
    }
    /* 'created' događaj upisuje DB trigger maint_incidents_audit (vidi add_maint_incidents_policies_v2.sql) */
    showToast('✅ Incident prijavljen');
    close();
    onSaved?.();
  });

  setTimeout(() => wrap.querySelector('#mntDlgIncTitle')?.focus(), 50);
}
