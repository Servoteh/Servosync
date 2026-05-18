/**
 * Audit log modal za jednog zaposlenog.
 *
 * Otvara se iz Zaposleni taba (samo za admin) i prikazuje hronologiju izmena
 * koje su DB triggeri snimili u `v_kadr_audit_log` (zarade, ugovori, GO,
 * lekarski pregledi, sertifikati).
 *
 * Svaki red ima expand u kojem se prikazuje detaljan diff before → after,
 * polje po polje, ignorišući `created_at` / `updated_at`.
 *
 * Public API:
 *   openEmployeeAuditModal(employeeId)
 */

import { escHtml, showToast, renderSkeleton } from '../../lib/dom.js';
import { formatDate } from '../../lib/date.js';
import { isAdmin } from '../../state/auth.js';
import { employeeDisplayName } from '../../lib/employeeNames.js';
import { kadrovskaState } from '../../state/kadrovska.js';
import {
  AUDIT_TABLE_LABELS,
  loadAuditLog,
  diffAuditRow,
} from '../../services/auditLog.js';

const ID = 'empAuditModal';

const ACTION_LABELS = {
  INSERT: 'Dodato',
  UPDATE: 'Izmenjeno',
  DELETE: 'Obrisano',
};

const ACTION_CLASS = {
  INSERT: 't-godisnji',
  UPDATE: 't-sluzbeno',
  DELETE: 't-bolovanje',
};

/* Polja koja ne treba prikazivati u diff-u (interne/tehničke kolone). */
const HIDDEN_FIELDS = new Set([
  'id', 'created_by', 'updated_by',
]);

/** Lepa labela polja iz snake_case → "Lepa labela". */
function _fieldLabel(snake) {
  const map = {
    salary_type: 'Tip zarade',
    amount: 'Iznos',
    amount_type: 'Neto / Bruto',
    currency: 'Valuta',
    hourly_rate: 'Satnica',
    effective_from: 'Važi od',
    effective_to: 'Važi do',
    transport_allowance_rsd: 'Prevoz (RSD)',
    per_diem_rsd: 'Din. dnevnica',
    per_diem_eur: 'Dev. dnevnica',
    contract_ref: 'Ref. ugovora',
    note: 'Napomena',
    date_from: 'Od',
    date_to: 'Do',
    contract_type: 'Tip ugovora',
    number: 'Broj',
    position: 'Pozicija',
    is_active: 'Aktivan',
    days_total: 'Pravo (dana)',
    days_carried_over: 'Preneto (dana)',
    days_used: 'Iskorišćeno',
    days_remaining: 'Preostalo',
    year: 'Godina',
    exam_date: 'Datum pregleda',
    valid_until: 'Važi do',
    exam_type: 'Tip pregleda',
    cost_rsd: 'Trošak (RSD)',
    institution: 'Ustanova',
    cert_type: 'Tip sertifikata',
    cert_name: 'Naziv',
    issued_on: 'Izdat',
    expires_on: 'Ističe',
    advance_amount: 'I deo (akontacija)',
    advance_paid_on: 'I deo — datum',
    second_part_rsd: 'II deo',
    final_paid_on: 'II deo — datum',
    status: 'Status',
    hours_worked: 'Sati rada',
    fixed_salary: 'Fiksna plata',
    transport_rsd: 'Prevoz (RSD)',
    domestic_days: 'Domaći tereni',
    foreign_days: 'Ino tereni',
    total_rsd: 'Ukupno RSD',
    total_eur: 'Ukupno EUR',
  };
  return map[snake] || snake;
}

/** Formatiranje vrednosti za prikaz u diff redu. */
function _fmtValue(v) {
  if (v === null || v === undefined || v === '') return '<em class="emp-sub">—</em>';
  if (typeof v === 'boolean') return v ? '✓' : '✗';
  if (typeof v === 'object') return `<code>${escHtml(JSON.stringify(v))}</code>`;
  /* Datum YYYY-MM-DD → DD.MM.YYYY */
  if (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}/.test(v)) {
    return escHtml(formatDate(v.slice(0, 10)));
  }
  return escHtml(String(v));
}

function _fmtChangedAt(iso) {
  if (!iso) return '—';
  try {
    const d = new Date(iso);
    return `${formatDate(iso)} ${d.toLocaleTimeString('sr-RS', { hour: '2-digit', minute: '2-digit' })}`;
  } catch {
    return iso;
  }
}

function _close() {
  document.getElementById(ID)?.remove();
}

export async function openEmployeeAuditModal(employeeId) {
  if (!isAdmin()) {
    showToast('⚠ Audit log je dostupan samo administratoru');
    return;
  }
  if (!employeeId) return;

  _close();
  const emp = kadrovskaState.employees.find(e => e.id === employeeId);
  const empName = employeeDisplayName(emp) || '—';

  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="emp-modal-overlay" id="${ID}" role="dialog" aria-modal="true">
      <div class="emp-modal emp-modal-wide">
        <div class="emp-modal-title">📒 Istorija izmena — ${escHtml(empName)}</div>
        <div class="emp-modal-subtitle">Hronologija svih izmena nad osetljivim tabelama (zarade, ugovori, GO, lekarski, sertifikati). Klikni red za detalje.</div>
        <div id="empAuditList">${renderSkeleton({ variant: 'list', rows: 6 })}</div>
        <div class="emp-modal-actions">
          <button type="button" class="btn" id="empAuditClose">Zatvori</button>
        </div>
      </div>
    </div>`;
  document.body.appendChild(wrap.firstElementChild);

  const modal = document.getElementById(ID);
  modal.querySelector('#empAuditClose').addEventListener('click', _close);
  modal.addEventListener('click', (e) => { if (e.target === modal) _close(); });

  const rows = await loadAuditLog({ employeeId, limit: 200 });
  _renderList(rows);
}

function _renderList(rows) {
  const host = document.querySelector(`#${ID} #empAuditList`);
  if (!host) return;
  if (rows === null) {
    host.innerHTML = '<div class="kadr-empty" style="padding:20px 0">⚠ Audit log nije dostupan — provera RLS / migracije.</div>';
    return;
  }
  if (!rows.length) {
    host.innerHTML = '<div class="kadr-empty" style="padding:20px 0">Nema audit zapisa za ovog zaposlenog.</div>';
    return;
  }
  host.innerHTML = `
    <table class="emp-children-table emp-audit-table">
      <thead>
        <tr>
          <th style="width:36px"></th>
          <th>Kada</th>
          <th>Tabela</th>
          <th>Akcija</th>
          <th>Korisnik</th>
        </tr>
      </thead>
      <tbody>
        ${rows.map((r, i) => {
          const tableLabel = AUDIT_TABLE_LABELS[r.tableName] || r.tableName;
          const actCls = ACTION_CLASS[r.action] || '';
          const actLbl = ACTION_LABELS[r.action] || r.action;
          return `
          <tr data-row-idx="${i}" class="emp-audit-row">
            <td><span class="emp-audit-chev" aria-hidden="true">▸</span></td>
            <td><span style="font-family:var(--mono);font-size:.85rem">${escHtml(_fmtChangedAt(r.changedAt))}</span></td>
            <td>${escHtml(tableLabel)}</td>
            <td><span class="kadr-type-badge ${actCls}">${escHtml(actLbl)}</span></td>
            <td><span class="emp-sub">${escHtml(r.actorEmail || r.actorUserId || '—')}</span></td>
          </tr>
          <tr class="emp-audit-detail" data-detail-idx="${i}" hidden>
            <td colspan="5">${_renderDiffHtml(r)}</td>
          </tr>`;
        }).join('')}
      </tbody>
    </table>`;

  host.querySelectorAll('.emp-audit-row').forEach(tr => {
    tr.addEventListener('click', () => {
      const idx = tr.dataset.rowIdx;
      const detail = host.querySelector(`.emp-audit-detail[data-detail-idx="${idx}"]`);
      if (!detail) return;
      const open = !detail.hidden;
      if (open) {
        detail.hidden = true;
        tr.querySelector('.emp-audit-chev').textContent = '▸';
      } else {
        detail.hidden = false;
        tr.querySelector('.emp-audit-chev').textContent = '▾';
      }
    });
  });
}

function _renderDiffHtml(row) {
  if (row.action === 'INSERT') {
    const data = row.afterData || {};
    return _renderSnapshotHtml('Dodate vrednosti', data);
  }
  if (row.action === 'DELETE') {
    const data = row.beforeData || {};
    return _renderSnapshotHtml('Obrisane vrednosti (poslednje stanje)', data);
  }
  /* UPDATE — diff before/after */
  const diff = diffAuditRow(row);
  const keys = Object.keys(diff).filter(k => !HIDDEN_FIELDS.has(k));
  if (!keys.length) {
    return '<div class="emp-sub" style="padding:8px 4px">Nema vidljivih promena (tehničke kolone su izostavljene).</div>';
  }
  const rowsHtml = keys.map(k => `
    <tr>
      <td><strong>${escHtml(_fieldLabel(k))}</strong></td>
      <td class="emp-audit-before">${_fmtValue(diff[k].before)}</td>
      <td class="emp-audit-arrow">→</td>
      <td class="emp-audit-after">${_fmtValue(diff[k].after)}</td>
    </tr>`).join('');
  return `
    <div class="emp-audit-diff">
      <table class="emp-audit-diff-table">
        <thead><tr><th>Polje</th><th>Pre</th><th></th><th>Posle</th></tr></thead>
        <tbody>${rowsHtml}</tbody>
      </table>
    </div>`;
}

function _renderSnapshotHtml(title, data) {
  const keys = Object.keys(data || {}).filter(k => !HIDDEN_FIELDS.has(k) && data[k] !== null && data[k] !== '');
  if (!keys.length) {
    return `<div class="emp-sub" style="padding:8px 4px">${escHtml(title)} — bez vidljivih polja.</div>`;
  }
  const rowsHtml = keys.map(k => `
    <tr>
      <td><strong>${escHtml(_fieldLabel(k))}</strong></td>
      <td>${_fmtValue(data[k])}</td>
    </tr>`).join('');
  return `
    <div class="emp-audit-diff">
      <div class="emp-sub" style="margin-bottom:6px">${escHtml(title)}</div>
      <table class="emp-audit-diff-table">
        <tbody>${rowsHtml}</tbody>
      </table>
    </div>`;
}
