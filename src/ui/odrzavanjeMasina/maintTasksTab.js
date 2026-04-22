/**
 * Tab „Šabloni“ u detalju mašine (održavanje): CRUD nad `maint_tasks`.
 * RLS dozvoljava insert/update/delete samo ERP admin-u ili `chief`/`admin`
 * ulozi u `maint_user_profiles`.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { isAdminOrMenadzment } from '../../state/auth.js';
import {
  insertMaintTask,
  patchMaintTask,
  deleteMaintTask,
} from '../../services/maintenance.js';

const INTERVAL_UNITS = [
  { v: 'hours', l: 'sati' },
  { v: 'days', l: 'dani' },
  { v: 'weeks', l: 'nedelje' },
  { v: 'months', l: 'meseci' },
];
const SEVERITIES = [
  { v: 'normal', l: 'normal' },
  { v: 'important', l: 'important' },
  { v: 'critical', l: 'critical' },
];
const REQUIRED_ROLES = ['operator', 'technician', 'chief', 'management', 'admin'];

/**
 * Admin/šef iz održavanja ili ERP admin.
 * @param {object|null} prof maint_user_profiles ili null
 */
export function canManageMaintTasks(prof) {
  if (isAdminOrMenadzment()) return true;
  return prof?.role === 'chief' || prof?.role === 'admin';
}

/**
 * Render tab-a.
 * @param {Array<object>} tasks svi šabloni za mašinu (aktivni + neaktivni)
 * @param {object|null} prof
 * @returns {string}
 */
export function renderMaintTasksTab(tasks, prof) {
  const canEdit = canManageMaintTasks(prof);
  const rows = Array.isArray(tasks) ? tasks : [];
  const list = rows.length
    ? rows
        .map(t => {
          const sevBadge =
            t.severity === 'critical'
              ? 'mnt-badge mnt-badge--down'
              : t.severity === 'important'
                ? 'mnt-badge mnt-badge--degraded'
                : 'mnt-badge';
          const activeMark = t.active
            ? ''
            : ' <span class="mnt-badge" style="background:var(--surface3);color:var(--text2)">NEAKTIVAN</span>';
          const actions = canEdit
            ? `<button type="button" class="btn" style="padding:2px 8px;font-size:12px" data-mnt-task-edit="${escHtml(String(t.id))}">Izmeni</button>
               <button type="button" class="btn" style="padding:2px 8px;font-size:12px;background:var(--surface3)" data-mnt-task-toggle="${escHtml(String(t.id))}" data-mnt-task-active="${t.active ? '1' : '0'}">${t.active ? 'Arhiviraj' : 'Aktiviraj'}</button>`
            : '';
          return `<li data-mnt-task-li="${escHtml(String(t.id))}" style="padding:10px 0;border-bottom:1px solid var(--border)">
          <div style="display:flex;flex-wrap:wrap;gap:8px;align-items:center;justify-content:space-between">
            <div>
              <strong>${escHtml(t.title || '')}</strong>${activeMark}
              <div class="mnt-muted" style="font-size:12px">
                ${escHtml(String(t.interval_value))} ${escHtml(t.interval_unit || '')}
                · <span class="${sevBadge}">${escHtml(t.severity || '')}</span>
                · uloga: ${escHtml(t.required_role || 'operator')}
                · grace: ${escHtml(String(t.grace_period_days ?? 3))} dana
              </div>
              ${t.description ? `<div style="font-size:13px;margin-top:4px">${escHtml(t.description)}</div>` : ''}
            </div>
            <div style="display:flex;gap:6px;flex-wrap:wrap">${actions}</div>
          </div>
        </li>`;
        })
        .join('')
    : '<li class="mnt-muted">Nema šablona za ovu mašinu.</li>';

  const addBtn = canEdit
    ? `<p style="margin-top:12px"><button type="button" class="btn" id="mntTaskAddBtn">+ Novi šablon</button></p>`
    : `<p class="mnt-muted" style="margin-top:12px">CRUD nad šablonima dostupan je šefu ili administratoru.</p>`;

  return `<p class="mnt-muted">Preventivne kontrole (šabloni) za ovu mašinu. „Arhiviraj” postavlja <code>active = false</code> i zadržava istoriju kontrola.</p>
    <ul class="mnt-list" style="padding-left:0;list-style:none">${list}</ul>
    ${addBtn}`;
}

function buildModalHtml(machineCode, existing) {
  const isEdit = !!existing;
  const unitOpts = INTERVAL_UNITS.map(
    u => `<option value="${u.v}"${String(existing?.interval_unit || 'days') === u.v ? ' selected' : ''}>${u.l}</option>`,
  ).join('');
  const sevOpts = SEVERITIES.map(
    s => `<option value="${s.v}"${String(existing?.severity || 'normal') === s.v ? ' selected' : ''}>${s.l}</option>`,
  ).join('');
  const roleOpts = REQUIRED_ROLES.map(
    r =>
      `<option value="${r}"${String(existing?.required_role || 'operator') === r ? ' selected' : ''}>${r}</option>`,
  ).join('');
  return `
    <div class="kadr-modal" style="max-width:520px">
      <div class="kadr-modal-title">${isEdit ? 'Izmeni šablon' : 'Novi šablon kontrole'}</div>
      <div class="kadr-modal-subtitle">Mašina <code>${escHtml(machineCode)}</code></div>
      <div class="kadr-modal-err" id="mntTaskDlgErr"></div>
      <form id="mntTaskDlgForm">
        <label class="form-label">Naslov *</label>
        <input type="text" class="form-input" id="mntTaskTitle" required maxlength="200" value="${escHtml(existing?.title || '')}">
        <label class="form-label">Opis</label>
        <textarea class="form-input" id="mntTaskDesc" rows="2">${escHtml(existing?.description || '')}</textarea>
        <label class="form-label">Uputstvo (korake)</label>
        <textarea class="form-input" id="mntTaskInstr" rows="3">${escHtml(existing?.instructions || '')}</textarea>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px">
          <div>
            <label class="form-label">Interval vrednost *</label>
            <input type="number" min="1" class="form-input" id="mntTaskIv" required value="${escHtml(String(existing?.interval_value ?? 7))}">
          </div>
          <div>
            <label class="form-label">Jedinica *</label>
            <select class="form-input" id="mntTaskIu" required>${unitOpts}</select>
          </div>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:8px">
          <div>
            <label class="form-label">Ozbiljnost</label>
            <select class="form-input" id="mntTaskSev">${sevOpts}</select>
          </div>
          <div>
            <label class="form-label">Min. uloga izvršioca</label>
            <select class="form-input" id="mntTaskRole">${roleOpts}</select>
          </div>
        </div>
        <label class="form-label" style="margin-top:8px">Grace period (dana)</label>
        <input type="number" min="0" class="form-input" id="mntTaskGrace" value="${escHtml(String(existing?.grace_period_days ?? 3))}">
        <label class="form-label" style="display:flex;align-items:center;gap:8px;margin-top:8px">
          <input type="checkbox" id="mntTaskActive" ${existing && existing.active === false ? '' : 'checked'}> Aktivan
        </label>
        <div class="kadr-modal-actions" style="margin-top:16px;display:flex;gap:8px;flex-wrap:wrap">
          ${isEdit ? `<button type="button" class="btn" id="mntTaskDelete" style="background:var(--red-bg);color:var(--red)">Obriši zauvek</button>` : ''}
          <span style="flex:1"></span>
          <button type="button" class="btn" id="mntTaskDlgCancel" style="background:var(--surface3)">Otkaži</button>
          <button type="submit" class="btn" id="mntTaskDlgSave">${isEdit ? 'Sačuvaj' : 'Dodaj'}</button>
        </div>
      </form>
    </div>`;
}

/**
 * Otvara modal za kreiranje ili izmenu šablona.
 * @param {{ machineCode: string, existing?: object|null, onSaved?: () => void }} opts
 */
export function openMaintTaskModal(opts) {
  const { machineCode, existing = null, onSaved } = opts;
  document.getElementById('mntTaskDlg')?.remove();
  const wrap = document.createElement('div');
  wrap.id = 'mntTaskDlg';
  wrap.className = 'kadr-modal-overlay';
  wrap.innerHTML = buildModalHtml(machineCode, existing);
  document.body.appendChild(wrap);
  const close = () => wrap.remove();
  wrap.addEventListener('click', e => {
    if (e.target === wrap) close();
  });
  wrap.querySelector('#mntTaskDlgCancel')?.addEventListener('click', close);

  wrap.querySelector('#mntTaskDlgForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const errEl = wrap.querySelector('#mntTaskDlgErr');
    if (errEl) errEl.textContent = '';
    const title = wrap.querySelector('#mntTaskTitle')?.value?.trim();
    if (!title) {
      if (errEl) errEl.textContent = 'Naslov je obavezan.';
      return;
    }
    const intervalVal = Number(wrap.querySelector('#mntTaskIv')?.value);
    if (!Number.isFinite(intervalVal) || intervalVal <= 0) {
      if (errEl) errEl.textContent = 'Interval mora biti pozitivan broj.';
      return;
    }
    const payload = {
      machine_code: machineCode,
      title,
      description: wrap.querySelector('#mntTaskDesc')?.value?.trim() || null,
      instructions: wrap.querySelector('#mntTaskInstr')?.value?.trim() || null,
      interval_value: intervalVal,
      interval_unit: wrap.querySelector('#mntTaskIu')?.value || 'days',
      severity: wrap.querySelector('#mntTaskSev')?.value || 'normal',
      required_role: wrap.querySelector('#mntTaskRole')?.value || 'operator',
      grace_period_days: Number(wrap.querySelector('#mntTaskGrace')?.value) || 0,
      active: !!wrap.querySelector('#mntTaskActive')?.checked,
    };
    const btn = wrap.querySelector('#mntTaskDlgSave');
    if (btn) btn.disabled = true;
    let ok = false;
    if (existing?.id) {
      ok = await patchMaintTask(existing.id, payload);
    } else {
      const row = await insertMaintTask(payload);
      ok = !!row;
    }
    if (btn) btn.disabled = false;
    if (!ok) {
      if (errEl) errEl.textContent = 'Snimanje nije uspelo (RLS ili nevalidne vrednosti).';
      showToast('⚠ Greška');
      return;
    }
    showToast(existing ? '✅ Šablon ažuriran' : '✅ Šablon dodat');
    close();
    onSaved?.();
  });

  wrap.querySelector('#mntTaskDelete')?.addEventListener('click', async () => {
    if (!existing?.id) return;
    const confirmed = window.confirm(
      'Brisanje šablona BRIŠE i celu istoriju kontrola za ovaj šablon. ' +
        'Preporuka: umesto brisanja samo arhiviraj (active = false). Sigurno nastavljaš?',
    );
    if (!confirmed) return;
    const ok = await deleteMaintTask(existing.id);
    if (!ok) {
      showToast('⚠ Brisanje nije uspelo');
      return;
    }
    showToast('🗑 Šablon obrisan');
    close();
    onSaved?.();
  });
}
