/**
 * Kadrovska — TAB Zahtevi GO (Faza K5).
 *
 * HR/admin/menadžment/leadpm/pm pregled i odobravanje zahteva za GO.
 * Tabela: svi zahtevi sortirani po datumu kreiranja (noviji gore).
 * Filter: status (svi / na čekanju / odobreni / odbijeni) + pretraga po imenu.
 * Akcije: Odobri / Odbij (za pending zahteve).
 *
 * Badge na tabu prikazuje broj pending zahteva.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { formatDate, daysInclusive } from '../../lib/date.js';
import {
  canManageVacationRequests,
  getIsOnline,
} from '../../state/auth.js';
import { hasSupabaseConfig } from '../../lib/constants.js';
import { kadrovskaState } from '../../state/kadrovska.js';
import { kadrVacReqState } from '../../state/kadrovska.js';
import {
  loadAllVacationRequestsFromDb,
  updateVacationRequestStatusInDb,
  deleteVacationRequestFromDb,
  queueVacationNotification,
  mapDbVacReq,
} from '../../services/vacationRequests.js';
import { mapDbAbsence, saveAbsenceToDb } from '../../services/absences.js';
import { ensureEmployeesLoaded, employeeNameById } from '../../services/kadrovska.js';
import { renderSummaryChips } from './shared.js';

let panelRoot = null;

const STATUS_LABEL = { pending: 'Na čekanju', approved: 'Odobreno', rejected: 'Odbijeno' };
const STATUS_CLASS = { pending: 't-sluzbeno', approved: 't-godisnji', rejected: 't-bolovanje' };

/* ── HTML ────────────────────────────────────────────────────────── */

export function renderVacationRequestsTab() {
  return `
    <div class="kadr-summary-strip" id="vacReqSummary"></div>
    <div class="kadrovska-toolbar">
      <select class="kadrovska-filter" id="vacReqStatusFilter">
        <option value="">Svi statusi</option>
        <option value="pending" selected>Na čekanju</option>
        <option value="approved">Odobreni</option>
        <option value="rejected">Odbijeni</option>
      </select>
      <input type="text" class="kadrovska-search" id="vacReqSearch" placeholder="Pretraga po imenu…">
      <input type="number" class="kadrovska-filter" id="vacReqYear" min="2020" max="2100"
             value="${new Date().getFullYear()}" style="max-width:80px;" title="Godina">
      <div class="kadrovska-toolbar-spacer"></div>
      <span class="kadrovska-count" id="vacReqCount">0 zahteva</span>
    </div>
    <main class="kadrovska-main">
      <table class="kadrovska-table" id="vacReqTable">
        <thead>
          <tr>
            <th>Zaposleni</th>
            <th class="col-hide-sm">Odeljenje</th>
            <th>Od</th>
            <th>Do</th>
            <th>Dana</th>
            <th>Status</th>
            <th class="col-hide-sm">Podneo/la</th>
            <th class="col-hide-sm">Napomena</th>
            <th class="col-actions">Akcije</th>
          </tr>
        </thead>
        <tbody id="vacReqTbody"></tbody>
      </table>
      <div class="kadrovska-empty" id="vacReqEmpty" style="display:none;margin-top:16px;">
        <div class="kadrovska-empty-title">Nema zahteva</div>
        <div>Zaposleni podnose zahteve iz modula <strong>Moj profil</strong>.</div>
      </div>
    </main>`;
}

/* ── Wire ────────────────────────────────────────────────────────── */

export async function wireVacationRequestsTab(panelEl) {
  panelRoot = panelEl;
  panelEl.querySelector('#vacReqStatusFilter').addEventListener('change', _renderRows);
  panelEl.querySelector('#vacReqSearch').addEventListener('input', _renderRows);
  panelEl.querySelector('#vacReqYear').addEventListener('change', _renderRows);

  await ensureEmployeesLoaded();
  await _loadRequests(true);
}

async function _loadRequests(force = false) {
  if (kadrVacReqState.loaded && !force) { _renderRows(); return; }
  if (!getIsOnline() || !hasSupabaseConfig()) {
    kadrVacReqState.loaded = true;
    _renderRows();
    return;
  }
  const data = await loadAllVacationRequestsFromDb();
  if (data !== null) {
    kadrVacReqState.items = data;
    kadrVacReqState.loaded = true;
    kadrVacReqState._schema = true;
  } else {
    kadrVacReqState._schema = false;
    showToast('⚠ Tabela vacation_requests nije pronađena — pokrenite migraciju K5');
  }
  _renderRows();
}

/* ── Render ──────────────────────────────────────────────────────── */

function _applyFilters() {
  if (!panelRoot) return kadrVacReqState.items;
  const statusF = panelRoot.querySelector('#vacReqStatusFilter')?.value || '';
  const yearF   = Number(panelRoot.querySelector('#vacReqYear')?.value || new Date().getFullYear());
  const q       = (panelRoot.querySelector('#vacReqSearch')?.value || '').trim().toLowerCase();

  return kadrVacReqState.items.filter(r => {
    if (statusF && r.status !== statusF) return false;
    if (yearF && r.year !== yearF) return false;
    if (q) {
      const empName = employeeNameById(r.employeeId).toLowerCase();
      const subBy   = (r.submittedBy || '').toLowerCase();
      if (!empName.includes(q) && !subBy.includes(q)) return false;
    }
    return true;
  });
}

function _renderRows() {
  if (!panelRoot) return;

  const tbody   = panelRoot.querySelector('#vacReqTbody');
  const empty   = panelRoot.querySelector('#vacReqEmpty');
  const countEl = panelRoot.querySelector('#vacReqCount');

  const filtered = _applyFilters();
  const total    = kadrVacReqState.items.length;
  const pending  = kadrVacReqState.items.filter(r => r.status === 'pending').length;
  const approved = kadrVacReqState.items.filter(r => r.status === 'approved').length;
  const rejected = kadrVacReqState.items.filter(r => r.status === 'rejected').length;

  /* Badge na tabu */
  const badge = document.getElementById('kadrTabCountVacReq');
  if (badge) badge.textContent = pending > 0 ? String(pending) : '0';

  if (countEl) {
    countEl.textContent = filtered.length === total
      ? `${total} ${total === 1 ? 'zahtev' : 'zahteva'}`
      : `${filtered.length} / ${total} zahteva`;
  }

  renderSummaryChips('vacReqSummary', [
    { label: 'Na čekanju', value: pending,  tone: pending  > 0 ? 'warn'   : 'muted' },
    { label: 'Odobreno',   value: approved, tone: approved > 0 ? 'ok'     : 'muted' },
    { label: 'Odbijeno',   value: rejected, tone: rejected > 0 ? 'accent' : 'muted' },
    { label: 'Ukupno',     value: total,    tone: 'muted' },
  ]);

  if (!filtered.length) {
    tbody.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  const canManage = canManageVacationRequests();
  tbody.innerHTML = filtered.map(r => {
    const emp  = kadrovskaState.employees.find(e => e.id === r.employeeId);
    const days = r.daysCount || daysInclusive(r.dateFrom, r.dateTo);
    const stClass = STATUS_CLASS[r.status] || '';
    const stLabel = STATUS_LABEL[r.status] || r.status;
    const id = escHtml(r.id);
    return `<tr data-id="${id}" data-status="${escHtml(r.status)}">
      <td><div class="emp-name">${escHtml(employeeNameById(r.employeeId))}</div></td>
      <td class="col-hide-sm">${escHtml(emp?.department || '—')}</td>
      <td>${r.dateFrom ? formatDate(r.dateFrom) : '—'}</td>
      <td>${r.dateTo   ? formatDate(r.dateTo)   : '—'}</td>
      <td style="font-family:var(--mono);font-weight:600;">${days}</td>
      <td><span class="kadr-type-badge ${stClass}">${escHtml(stLabel)}</span></td>
      <td class="col-hide-sm" style="font-size:.82rem;color:var(--text2);">${escHtml(r.submittedBy || '—')}</td>
      <td class="col-hide-sm">${escHtml(r.note || '—')}</td>
      <td class="col-actions" style="white-space:nowrap;">
        ${r.status === 'pending' && canManage ? `
          <button class="btn-row-act" data-act="approve" data-id="${id}" title="Odobri zahtev">✔ Odobri</button>
          <button class="btn-row-act danger" data-act="reject"  data-id="${id}" title="Odbij zahtev">✘ Odbij</button>
        ` : ''}
        ${canManage && r.status !== 'pending' ? `
          <button class="btn-row-act" style="opacity:.6;" data-act="delete" data-id="${id}" title="Obriši zahtev">Obriši</button>
        ` : ''}
        ${!canManage ? '<span style="color:var(--text3,var(--text2));font-size:.8rem;">—</span>' : ''}
      </td>
    </tr>`;
  }).join('');

  tbody.querySelectorAll('button[data-act="approve"]').forEach(b => {
    b.addEventListener('click', () => _approveRequest(b.dataset.id));
  });
  tbody.querySelectorAll('button[data-act="reject"]').forEach(b => {
    b.addEventListener('click', () => _openRejectModal(b.dataset.id));
  });
  tbody.querySelectorAll('button[data-act="delete"]').forEach(b => {
    b.addEventListener('click', () => _deleteRequest(b.dataset.id));
  });
}

/* ── Odobri ──────────────────────────────────────────────────────── */

async function _approveRequest(id) {
  if (!canManageVacationRequests()) return;
  const req = kadrVacReqState.items.find(r => r.id === id);
  if (!req) return;

  if (!confirm(`Odobriti zahtev za GO zaposlenog ${employeeNameById(req.employeeId)} (${formatDate(req.dateFrom)} – ${formatDate(req.dateTo)})?`)) return;

  const res = await updateVacationRequestStatusInDb(id, 'approved', '');
  if (!res) { showToast('⚠ Greška pri odobravanju'); return; }

  /* Automatski kreiraj unos u absences tabeli */
  if (getIsOnline() && hasSupabaseConfig()) {
    const absPayload = {
      employeeId: req.employeeId,
      type: 'godisnji',
      dateFrom: req.dateFrom,
      dateTo: req.dateTo,
      daysCount: req.daysCount || daysInclusive(req.dateFrom, req.dateTo),
      note: `Odobreno iz zahteva GO (${req.submittedBy || ''})`,
    };
    await saveAbsenceToDb(absPayload);
  }

  /* Notifikacija zaposlenom (email + WhatsApp ako ima kontakt) */
  queueVacationNotification(id, 'approved', '');

  const idx = kadrVacReqState.items.findIndex(r => r.id === id);
  if (idx >= 0) kadrVacReqState.items[idx] = { ...kadrVacReqState.items[idx], status: 'approved' };
  _renderRows();
  showToast('✅ Zahtev odobren — odsustvo dodato u evidenciju');
}

/* ── Odbij modal ─────────────────────────────────────────────────── */

function _openRejectModal(id) {
  const req = kadrVacReqState.items.find(r => r.id === id);
  if (!req) return;

  document.getElementById('vacReqRejectModal')?.remove();

  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay" id="vacReqRejectModal" role="dialog" aria-modal="true">
      <div class="kadr-modal">
        <div class="kadr-modal-title">Odbij zahtev za GO</div>
        <div class="kadr-modal-subtitle">
          ${escHtml(employeeNameById(req.employeeId))} — ${req.dateFrom ? formatDate(req.dateFrom) : ''} do ${req.dateTo ? formatDate(req.dateTo) : ''}
        </div>
        <div class="kadr-modal-err" id="vacReqRejectErr"></div>
        <div class="emp-form-grid" style="margin-top:12px;">
          <div class="emp-field col-full">
            <label for="vacReqRejectNote">Razlog odbijanja *</label>
            <textarea id="vacReqRejectNote" maxlength="300" rows="3" required
              placeholder="Unesite razlog (npr. period korisnički zauzet, nedostatak kadra…)"></textarea>
          </div>
        </div>
        <div class="kadr-modal-actions">
          <button type="button" class="btn" id="vacReqRejectCancelBtn">Otkaži</button>
          <button type="button" class="btn btn-danger-soft" id="vacReqRejectConfirmBtn">Odbij zahtev</button>
        </div>
      </div>
    </div>`;
  document.body.appendChild(wrap.firstElementChild);

  const modal = document.getElementById('vacReqRejectModal');
  modal.querySelector('#vacReqRejectCancelBtn').addEventListener('click', () => modal.remove());
  modal.addEventListener('click', e => { if (e.target === modal) modal.remove(); });
  modal.querySelector('#vacReqRejectConfirmBtn').addEventListener('click', async () => {
    const note = modal.querySelector('#vacReqRejectNote').value.trim();
    const errEl = modal.querySelector('#vacReqRejectErr');
    if (!note) { errEl.textContent = 'Razlog odbijanja je obavezan.'; errEl.classList.add('visible'); return; }

    const btn = modal.querySelector('#vacReqRejectConfirmBtn');
    btn.disabled = true; btn.textContent = 'Slanje…';

    const res = await updateVacationRequestStatusInDb(id, 'rejected', note);
    if (!res) { errEl.textContent = 'Greška pri odbijanju.'; errEl.classList.add('visible'); btn.disabled = false; btn.textContent = 'Odbij zahtev'; return; }

    const idx = kadrVacReqState.items.findIndex(r => r.id === id);
    if (idx >= 0) kadrVacReqState.items[idx] = { ...kadrVacReqState.items[idx], status: 'rejected', rejectionNote: note };

    /* Notifikacija zaposlenom */
    queueVacationNotification(id, 'rejected', note);

    modal.remove();
    _renderRows();
    showToast('🚫 Zahtev odbijen');
  });

  setTimeout(() => modal.querySelector('#vacReqRejectNote')?.focus(), 50);
}

/* ── Obriši ──────────────────────────────────────────────────────── */

async function _deleteRequest(id) {
  if (!canManageVacationRequests()) return;
  if (!confirm('Obrisati ovaj zahtev?')) return;
  const ok = await deleteVacationRequestFromDb(id);
  if (!ok) { showToast('⚠ Brisanje nije uspelo'); return; }
  kadrVacReqState.items = kadrVacReqState.items.filter(r => r.id !== id);
  _renderRows();
  showToast('🗑 Zahtev obrisan');
}

/** Reload badge iz state-a (zove index.js pri mount-u modula). */
export function refreshVacReqBadge() {
  const pending = kadrVacReqState.items.filter(r => r.status === 'pending').length;
  const badge = document.getElementById('kadrTabCountVacReq');
  if (badge) badge.textContent = pending > 0 ? String(pending) : '0';
}
