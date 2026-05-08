/**
 * Modal za sertifikate / licence / obuke jednog zaposlenog (Faza K7).
 * Otvara se iz Zaposleni taba, sličan pattern kao medicalExamsModal.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { formatDate } from '../../lib/date.js';
import { canEditKadrovska, canViewEmployeePii } from '../../state/auth.js';
import { employeeDisplayName } from '../../lib/employeeNames.js';
import {
  CERT_TYPE_LABELS,
  loadCertificatesForEmployee,
  saveCertificate,
  deleteCertificate,
} from '../../services/certificates.js';
import { ensureEmployeesLoaded } from '../../services/kadrovska.js';
import { kadrovskaState } from '../../state/kadrovska.js';

let currentEmpId = null;
let currentList = [];
let onChangeCb = null;

function fmtRsd(n) {
  const v = Number(n || 0);
  return `${v.toLocaleString('sr-RS', { maximumFractionDigits: 2 })} RSD`;
}

function statusBadge(c) {
  if (!c.expiresOn) return '<span class="kadr-pill muted">Trajno</span>';
  const today = new Date().toISOString().slice(0, 10);
  if (c.expiresOn < today) return '<span class="kadr-pill warn">Istekao</span>';
  const d = new Date(c.expiresOn);
  const t = new Date();
  const diff = Math.round((d - t) / (1000 * 60 * 60 * 24));
  if (diff <= 30) return `<span class="kadr-pill accent">ističe za ${diff}d</span>`;
  return '<span class="kadr-pill ok">važi</span>';
}

export async function openCertificatesModal(employeeId, opts = {}) {
  if (!canViewEmployeePii()) { showToast('⚠ Pristup zabranjen'); return; }
  if (!employeeId) return;
  currentEmpId = employeeId;
  onChangeCb = opts.onChange || null;

  closeCertificatesModal();
  await ensureEmployeesLoaded();
  const emp = kadrovskaState.employees.find(e => e.id === employeeId);
  const name = employeeDisplayName(emp) || '—';

  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="emp-modal-overlay" id="certsModal" role="dialog" aria-modal="true">
      <div class="emp-modal emp-modal-wide">
        <div class="emp-modal-title">📜 Sertifikati / licence — ${escHtml(name)}</div>
        <div class="emp-modal-subtitle">Vozačke dozvole, viljuškarska/varilačka licenca, ZNR obuke, ISO sertifikati…</div>
        <div class="emp-modal-err" id="certErr"></div>
        <div id="certList"></div>
        ${canEditKadrovska() ? `
          <div class="emp-modal-actions" style="justify-content:flex-end">
            <button type="button" class="btn btn-primary" id="certAddBtn">+ Dodaj sertifikat</button>
          </div>
        ` : ''}
        <div class="emp-modal-actions">
          <button type="button" class="btn" id="certClose">Zatvori</button>
        </div>
      </div>
    </div>`;
  document.body.appendChild(wrap.firstElementChild);
  const m = document.getElementById('certsModal');
  m.querySelector('#certClose').addEventListener('click', closeCertificatesModal);
  m.addEventListener('click', e => { if (e.target === m) closeCertificatesModal(); });
  m.querySelector('#certAddBtn')?.addEventListener('click', () => openCertForm(null));

  await refreshCertList();
}

export function closeCertificatesModal() {
  document.getElementById('certsModal')?.remove();
  document.getElementById('certFormModal')?.remove();
}

async function refreshCertList() {
  const host = document.querySelector('#certsModal #certList');
  if (!host) return;
  const list = await loadCertificatesForEmployee(currentEmpId);
  currentList = list || [];
  if (!currentList.length) {
    host.innerHTML = '<div class="kadr-empty" style="padding:20px 0">Nema upisanih sertifikata.</div>';
    return;
  }
  host.innerHTML = `
    <table class="emp-children-table">
      <thead>
        <tr>
          <th>Tip / naziv</th>
          <th>Izdat</th>
          <th>Ističe</th>
          <th>Status</th>
          <th class="col-hide-sm">Izdavalac</th>
          <th class="col-hide-sm">Trošak</th>
          ${canEditKadrovska() ? '<th class="col-actions">Akcije</th>' : ''}
        </tr>
      </thead>
      <tbody>
        ${currentList.map(r => `<tr data-id="${escHtml(r.id)}">
          <td>
            <strong>${escHtml(r.certName || '—')}</strong>
            <div class="emp-sub">${escHtml(CERT_TYPE_LABELS[r.certType] || r.certType)}${r.documentNo ? ' · ' + escHtml(r.documentNo) : ''}</div>
          </td>
          <td>${escHtml(formatDate(r.issuedOn))}</td>
          <td>${r.expiresOn ? escHtml(formatDate(r.expiresOn)) : '<em class="emp-sub">trajno</em>'}</td>
          <td>${statusBadge(r)}</td>
          <td class="col-hide-sm">${escHtml(r.issuer || '—')}</td>
          <td class="col-hide-sm">${r.costRsd ? escHtml(fmtRsd(r.costRsd)) : '<em class="emp-sub">0</em>'}</td>
          ${canEditKadrovska() ? `<td class="col-actions">
            <button class="btn-row-act" data-act="edit">Izmeni</button>
            <button class="btn-row-act danger" data-act="del">Obriši</button>
          </td>` : ''}
        </tr>`).join('')}
      </tbody>
    </table>`;
  host.querySelectorAll('button[data-act="edit"]').forEach(b => {
    b.addEventListener('click', () => {
      const id = b.closest('tr').dataset.id;
      const r = currentList.find(x => x.id === id);
      if (r) openCertForm(r);
    });
  });
  host.querySelectorAll('button[data-act="del"]').forEach(b => {
    b.addEventListener('click', () => {
      const id = b.closest('tr').dataset.id;
      onDeleteCert(id);
    });
  });
}

async function onDeleteCert(id) {
  if (!confirm('Obrisati ovaj sertifikat?')) return;
  const ok = await deleteCertificate(id);
  if (!ok) { showToast('⚠ Brisanje nije uspelo'); return; }
  showToast('🗑 Obrisano');
  await refreshCertList();
  onChangeCb?.();
}

function openCertForm(record) {
  document.getElementById('certFormModal')?.remove();
  const isEdit = !!record;
  const todayIso = new Date().toISOString().slice(0, 10);

  const typeOpts = Object.entries(CERT_TYPE_LABELS).map(([k, v]) =>
    `<option value="${k}"${(record?.certType || 'other') === k ? ' selected' : ''}>${escHtml(v)}</option>`
  ).join('');

  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="emp-modal-overlay" id="certFormModal" role="dialog" aria-modal="true">
      <div class="emp-modal">
        <div class="emp-modal-title">${isEdit ? 'Izmeni sertifikat' : 'Novi sertifikat / licenca'}</div>
        <div class="emp-modal-err" id="certFormErr"></div>
        <form id="certForm">
          <input type="hidden" id="certId" value="${escHtml(record?.id || '')}">
          <div class="emp-form-grid">
            <div class="emp-field">
              <label for="certType">Tip *</label>
              <select id="certType" required>${typeOpts}</select>
            </div>
            <div class="emp-field">
              <label for="certName">Naziv *</label>
              <input type="text" id="certName" required maxlength="200" value="${escHtml(record?.certName || '')}" placeholder="npr. B kategorija, IPAF 3a/3b">
            </div>
            <div class="emp-field">
              <label for="certIssuer">Izdavalac</label>
              <input type="text" id="certIssuer" maxlength="200" value="${escHtml(record?.issuer || '')}">
            </div>
            <div class="emp-field">
              <label for="certDocNo">Br. dokumenta</label>
              <input type="text" id="certDocNo" maxlength="100" value="${escHtml(record?.documentNo || '')}">
            </div>
            <div class="emp-field">
              <label for="certIssued">Izdat *</label>
              <input type="date" id="certIssued" required value="${escHtml(record?.issuedOn || todayIso)}">
            </div>
            <div class="emp-field">
              <label for="certExpires">Ističe (opc.)</label>
              <input type="date" id="certExpires" value="${escHtml(record?.expiresOn || '')}">
            </div>
            <div class="emp-field">
              <label for="certCost">Trošak (RSD)</label>
              <input type="number" id="certCost" min="0" step="0.01" value="${record?.costRsd || 0}">
            </div>
            <div class="emp-field col-full">
              <label for="certDoc">Link na dokument (URL)</label>
              <input type="url" id="certDoc" maxlength="500" placeholder="https://…" value="${escHtml(record?.documentUrl || '')}">
            </div>
            <div class="emp-field col-full">
              <label for="certNote">Napomena</label>
              <textarea id="certNote" maxlength="1000" rows="2">${escHtml(record?.note || '')}</textarea>
            </div>
          </div>
          <div class="emp-modal-actions">
            <button type="button" class="btn" id="certFormCancel">Otkaži</button>
            <button type="submit" class="btn btn-primary" id="certFormSubmit">Sačuvaj</button>
          </div>
        </form>
      </div>
    </div>`;
  document.body.appendChild(wrap.firstElementChild);
  const m = document.getElementById('certFormModal');
  m.querySelector('#certFormCancel').addEventListener('click', () => m.remove());
  m.addEventListener('click', e => { if (e.target === m) m.remove(); });
  m.querySelector('#certForm').addEventListener('submit', e => {
    e.preventDefault();
    submitCertForm();
  });
  setTimeout(() => m.querySelector('#certName')?.focus(), 50);
}

async function submitCertForm() {
  const err = document.getElementById('certFormErr');
  err.textContent = ''; err.classList.remove('visible');

  const id = document.getElementById('certId').value || null;
  const certType = document.getElementById('certType').value;
  const certName = document.getElementById('certName').value.trim();
  const issuer = document.getElementById('certIssuer').value.trim();
  const documentNo = document.getElementById('certDocNo').value.trim();
  const issuedOn = document.getElementById('certIssued').value;
  const expiresOn = document.getElementById('certExpires').value || null;
  const costRsd = parseFloat(document.getElementById('certCost').value) || 0;
  const documentUrl = document.getElementById('certDoc').value.trim();
  const note = document.getElementById('certNote').value.trim();

  if (!certName) { err.textContent = 'Naziv je obavezan.'; err.classList.add('visible'); return; }
  if (!issuedOn) { err.textContent = 'Datum izdavanja je obavezan.'; err.classList.add('visible'); return; }
  if (expiresOn && expiresOn < issuedOn) {
    err.textContent = '"Ističe" ne može biti pre datuma izdavanja.';
    err.classList.add('visible'); return;
  }
  if (costRsd < 0) {
    err.textContent = 'Trošak ne može biti negativan.';
    err.classList.add('visible'); return;
  }

  const payload = {
    id, employeeId: currentEmpId,
    certType, certName, issuer, documentNo, issuedOn, expiresOn, costRsd, documentUrl, note,
  };
  const btn = document.getElementById('certFormSubmit');
  btn.disabled = true; btn.textContent = '⏳';
  try {
    const saved = await saveCertificate(payload);
    if (!saved) {
      err.textContent = 'Čuvanje nije uspelo. Da li je migracija add_kadr_certificates.sql primenjena?';
      err.classList.add('visible');
      return;
    }
    document.getElementById('certFormModal')?.remove();
    showToast(id ? '✏️ Izmenjeno' : '✅ Sertifikat sačuvan');
    await refreshCertList();
    onChangeCb?.();
  } catch (e) {
    console.error('[certs] save', e);
    err.textContent = 'Greška pri čuvanju.';
    err.classList.add('visible');
  } finally {
    btn.disabled = false; btn.textContent = 'Sačuvaj';
  }
}
