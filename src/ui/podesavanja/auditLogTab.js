/**
 * Podešavanja → Audit log (user_roles, predmet_aktivacija).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  loadSettingsAuditLog,
  diffSettingsAuditRow,
  SETTINGS_AUDIT_TABLE_LABELS,
} from '../../services/settingsAuditLog.js';
import { getIsOnline } from '../../state/auth.js';

let _rows = [];
let _filter = { tableName: '', action: '', limit: 100 };

export async function refreshSettingsAuditLog() {
  if (!getIsOnline()) {
    _rows = [];
    return [];
  }
  const data = await loadSettingsAuditLog({
    tableName: _filter.tableName || undefined,
    action: _filter.action || undefined,
    limit: _filter.limit,
  });
  _rows = data || [];
  return _rows;
}

export function renderAuditLogTab() {
  return `
    <div class="set-page-header">
      <div class="set-page-header-icon">📜</div>
      <div>
        <h2 class="set-page-header-title">Audit log</h2>
        <p class="set-page-header-sub">Promene na korisnicima i aktivaciji predmeta</p>
      </div>
    </div>
    <div class="set-toolbar" id="auditToolbar">
      <div class="set-toolbar-field">
        <span class="set-toolbar-field-label">Tabela</span>
        <select class="form-input" id="auditTableFilter">
          <option value="">Sve</option>
          ${Object.entries(SETTINGS_AUDIT_TABLE_LABELS).map(([k, v]) =>
            `<option value="${escHtml(k)}"${_filter.tableName === k ? ' selected' : ''}>${escHtml(v)}</option>`,
          ).join('')}
        </select>
      </div>
      <div class="set-toolbar-field">
        <span class="set-toolbar-field-label">Akcija</span>
        <select class="form-input" id="auditActionFilter">
          <option value="">Sve</option>
          <option value="INSERT"${_filter.action === 'INSERT' ? ' selected' : ''}>INSERT</option>
          <option value="UPDATE"${_filter.action === 'UPDATE' ? ' selected' : ''}>UPDATE</option>
          <option value="DELETE"${_filter.action === 'DELETE' ? ' selected' : ''}>DELETE</option>
        </select>
      </div>
      <button type="button" class="btn btn-ghost" id="auditRefreshBtn">↻ Osveži</button>
    </div>
    <main class="kadrovska-main" style="padding:0" id="auditLogHost">${_tableHtml()}</main>
  `;
}

function _tableHtml() {
  if (!_rows.length) {
    return `<div class="kadrovska-empty" style="margin-top:16px">
      <div class="kadrovska-empty-title">Nema zapisa</div>
      <div style="margin-top:6px">Promene na <code>user_roles</code> i <code>predmet_aktivacija</code> se automatski beleže.</div>
    </div>`;
  }

  const rows = _rows.map(r => {
    const when = r.changedAt ? new Date(r.changedAt).toLocaleString('sr-RS') : '—';
    const tbl = SETTINGS_AUDIT_TABLE_LABELS[r.tableName] || r.tableName;
    const diff = diffSettingsAuditRow(r);
    const diffKeys = Object.keys(diff).slice(0, 6).join(', ') || (r.diffKeys?.join(', ') || '—');
    const email = r.oldData?.email || r.newData?.email || r.recordId || '—';
    return `<tr>
      <td style="font-size:11px;white-space:nowrap">${escHtml(when)}</td>
      <td>${escHtml(tbl)}</td>
      <td><span class="set-audit-action set-audit-action--${escHtml(r.action.toLowerCase())}">${escHtml(r.action)}</span></td>
      <td style="font-size:11px;font-family:var(--mono)">${escHtml(String(email).slice(0, 48))}</td>
      <td style="font-size:11px;color:var(--text2)">${escHtml(diffKeys)}</td>
      <td style="font-size:11px">${escHtml(r.actorEmail || '—')}</td>
    </tr>`;
  }).join('');

  return `
    <table class="kadrovska-table">
      <thead>
        <tr>
          <th>Vreme</th><th>Tabela</th><th>Akcija</th><th>Zapis</th><th>Polja</th><th>Ko</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>`;
}

export function wireAuditLogTab(root, { onRefresh } = {}) {
  const rerender = async () => {
    await refreshSettingsAuditLog();
    const host = root.querySelector('#auditLogHost');
    if (host) host.innerHTML = _tableHtml();
    onRefresh?.();
  };

  root.querySelector('#auditTableFilter')?.addEventListener('change', e => {
    _filter.tableName = e.target.value;
    rerender().catch(() => showToast('⚠ Greška učitavanja'));
  });
  root.querySelector('#auditActionFilter')?.addEventListener('change', e => {
    _filter.action = e.target.value;
    rerender().catch(() => showToast('⚠ Greška učitavanja'));
  });
  root.querySelector('#auditRefreshBtn')?.addEventListener('click', () => {
    rerender().then(() => showToast('✅ Audit osvežen')).catch(() => showToast('⚠ Greška'));
  });
}
