/**
 * Podešavanja → Uloge i dozvole (read-only matrica modul × uloga).
 */

import { escHtml } from '../../lib/dom.js';
import {
  ERP_RBAC_MATRIX,
  RBAC_DISPLAY_ROLES,
  rbacLevelForRole,
  rbacRoleLabel,
} from '../../lib/erpRbacMatrix.js';
import { ROLE_LABELS } from '../../lib/constants.js';

function _cellHtml(level) {
  if (level === 'edit') {
    return '<span class="set-rbac-cell set-rbac-cell--edit" title="Pun pristup / izmene">✎</span>';
  }
  if (level === 'access') {
    return '<span class="set-rbac-cell set-rbac-cell--read" title="Pristup">◉</span>';
  }
  return '<span class="set-rbac-cell set-rbac-cell--none" aria-hidden="true">·</span>';
}

export function renderUlogeTab() {
  const roleHeaders = RBAC_DISPLAY_ROLES.map(
    r => `<th class="set-rbac-role-col">${escHtml(rbacRoleLabel(r))}</th>`,
  ).join('');

  const rows = ERP_RBAC_MATRIX.map(m => {
    const cells = RBAC_DISPLAY_ROLES.map(role =>
      `<td class="set-rbac-td">${_cellHtml(rbacLevelForRole(m.access, m.edit, role))}</td>`,
    ).join('');
    const noteHtml = m.note ? `<div class="set-rbac-note">${escHtml(m.note)}</div>` : '';
    return `<tr>
      <td class="set-rbac-module"><strong>${escHtml(m.label)}</strong>${noteHtml}</td>
      ${cells}
    </tr>`;
  }).join('');

  const roleLegend = Object.entries(ROLE_LABELS)
    .map(([k, v]) => `<strong>${escHtml(k)}</strong> — ${escHtml(v)}`)
    .join(' · ');

  return `
    <div class="set-page-header">
      <div class="set-page-header-icon">🛡</div>
      <div>
        <h2 class="set-page-header-title">Uloge i dozvole</h2>
        <p class="set-page-header-sub">Pregled pristupa po modulima</p>
      </div>
    </div>
    <p class="form-hint" style="margin-bottom:12px">
      Legenda: <span class="set-rbac-cell set-rbac-cell--edit">✎</span> izmene &nbsp;
      <span class="set-rbac-cell set-rbac-cell--read">◉</span> pristup &nbsp;
      <span class="set-rbac-cell set-rbac-cell--none">·</span> nema pristupa.
      RLS: <code>docs/RBAC_MATRIX.md</code>.
    </p>
    <div class="set-rbac-wrap">
      <table class="kadrovska-table set-rbac-table">
        <thead><tr><th>Modul</th>${roleHeaders}</tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
    <div class="kadrovska-empty" style="margin-top:16px;font-size:12px"><div>Uloge: ${roleLegend}</div></div>
  `;
}

export function wireUlogeTab() {}
