/**
 * Modal za istoriju lekarskih pregleda jednog zaposlenog (Faza K6).
 *
 * Otvara se iz Zaposleni taba (per-row akcija ili iz detalja modala).
 * Prikazuje hronologiju, omogućava dodavanje/izmenu/brisanje. Po insert-u,
 * DB trigger automatski ažurira `employees.medical_exam_date/expires` na
 * najnoviji red — UI ne mora da dodatno PATCH-uje employees.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { formatDate } from '../../lib/date.js';
import { canEditKadrovska, canViewEmployeePii } from '../../state/auth.js';
import { employeeDisplayName } from '../../lib/employeeNames.js';
import {
  loadMedExamsForEmployee,
  saveMedExam,
  deleteMedExam,
} from '../../services/medicalExams.js';
import { ensureEmployeesLoaded } from '../../services/kadrovska.js';
import { kadrovskaState } from '../../state/kadrovska.js';
import { askConfirm } from '../../lib/confirm.js';

const EXAM_TYPE_LABELS = {
  redovan:    'Redovan',
  prethodni:  'Prethodni',
  periodicni: 'Periodični',
  ciljani:    'Ciljani',
  vanredni:   'Vanredni',
};

let currentEmpId = null;
let currentList = [];
let onChangeCb = null;

function fmtRsd(n) {
  const v = Number(n || 0);
  return `${v.toLocaleString('sr-RS', { maximumFractionDigits: 2 })} RSD`;
}

function statusFromValid(validUntil) {
  if (!validUntil) return { label: 'bez datuma', tone: 'muted' };
  const today = new Date().toISOString().slice(0, 10);
  if (validUntil < today) return { label: 'istekao', tone: 'warn' };
  const d = new Date(validUntil);
  const t = new Date();
  const diffDays = Math.round((d - t) / (1000 * 60 * 60 * 24));
  if (diffDays <= 30) return { label: `ističe za ${diffDays} d`, tone: 'accent' };
  return { label: 'važi', tone: 'ok' };
}

export async function openMedicalExamsModal(employeeId, opts = {}) {
  if (!canViewEmployeePii()) {
    showToast('⚠ Pristup zabranjen');
    return;
  }
  if (!employeeId) return;
  currentEmpId = employeeId;
  onChangeCb = opts.onChange || null;

  closeMedicalExamsModal();
  await ensureEmployeesLoaded();
  const emp = kadrovskaState.employees.find(e => e.id === employeeId);
  const name = employeeDisplayName(emp) || '—';

  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="emp-modal-overlay" id="medExamsModal" role="dialog" aria-modal="true">
      <div class="emp-modal emp-modal-wide">
        <div class="emp-modal-title">🩺 Lekarski pregledi — ${escHtml(name)}</div>
        <div class="emp-modal-subtitle">Najnoviji unos automatski postaje aktuelni datum/istek na profilu zaposlenog.</div>
        <div class="emp-modal-err" id="medErr"></div>
        <div id="medList"></div>
        ${canEditKadrovska() ? `
          <div class="emp-modal-actions" style="justify-content:flex-end">
            <button type="button" class="btn btn-primary" id="medAddBtn">+ Dodaj pregled</button>
          </div>
        ` : ''}
        <div class="emp-modal-actions">
          <button type="button" class="btn" id="medClose">Zatvori</button>
        </div>
      </div>
    </div>`;
  document.body.appendChild(wrap.firstElementChild);
  const m = document.getElementById('medExamsModal');
  m.querySelector('#medClose').addEventListener('click', closeMedicalExamsModal);
  m.addEventListener('click', e => { if (e.target === m) closeMedicalExamsModal(); });
  m.querySelector('#medAddBtn')?.addEventListener('click', () => openMedExamForm(null));

  await refreshMedList();
}

export function closeMedicalExamsModal() {
  document.getElementById('medExamsModal')?.remove();
  document.getElementById('medExamFormModal')?.remove();
}

async function refreshMedList() {
  const host = document.querySelector('#medExamsModal #medList');
  if (!host) return;
  const list = await loadMedExamsForEmployee(currentEmpId);
  currentList = list || [];
  if (!currentList.length) {
    host.innerHTML = '<div class="kadr-empty" style="padding:20px 0">Nema upisanih pregleda za ovog zaposlenog.</div>';
    return;
  }
  host.innerHTML = `
    <table class="emp-children-table">
      <thead>
        <tr>
          <th>Datum</th>
          <th>Tip</th>
          <th>Važi do</th>
          <th>Status</th>
          <th class="col-hide-sm">Ustanova</th>
          <th class="col-hide-sm">Trošak</th>
          ${canEditKadrovska() ? '<th class="col-actions">Akcije</th>' : ''}
        </tr>
      </thead>
      <tbody>
        ${currentList.map(r => {
          const s = statusFromValid(r.validUntil);
          return `<tr data-id="${escHtml(r.id)}">
            <td>${escHtml(formatDate(r.examDate))}</td>
            <td>${escHtml(EXAM_TYPE_LABELS[r.examType] || r.examType)}</td>
            <td>${r.validUntil ? escHtml(formatDate(r.validUntil)) : '<em class="emp-sub">—</em>'}</td>
            <td><span class="kadr-pill ${s.tone}">${escHtml(s.label)}</span></td>
            <td class="col-hide-sm">${escHtml(r.institution || '—')}</td>
            <td class="col-hide-sm">${r.costRsd ? escHtml(fmtRsd(r.costRsd)) : '<em class="emp-sub">0</em>'}</td>
            ${canEditKadrovska() ? `<td class="col-actions">
              <button class="btn-row-act" data-act="edit">Izmeni</button>
              <button class="btn-row-act danger" data-act="del">Obriši</button>
            </td>` : ''}
          </tr>`;
        }).join('')}
      </tbody>
    </table>`;
  host.querySelectorAll('button[data-act="edit"]').forEach(b => {
    b.addEventListener('click', () => {
      const id = b.closest('tr').dataset.id;
      const r = currentList.find(x => x.id === id);
      if (r) openMedExamForm(r);
    });
  });
  host.querySelectorAll('button[data-act="del"]').forEach(b => {
    b.addEventListener('click', () => {
      const id = b.closest('tr').dataset.id;
      onDeleteMedExam(id);
    });
  });
}

async function onDeleteMedExam(id) {
  const ok = await askConfirm({
    title: 'Brisanje lekarskog pregleda',
    body: 'Obrisati ovaj lekarski pregled? Akcija je trajna.',
    confirmLabel: 'Obriši',
    danger: true,
  });
  if (!ok) return;
  const deleted = await deleteMedExam(id);
  if (!deleted) { showToast('⚠ Brisanje nije uspelo'); return; }
  showToast('🗑 Obrisano');
  await refreshMedList();
  onChangeCb?.();
}

function openMedExamForm(record) {
  document.getElementById('medExamFormModal')?.remove();
  const isEdit = !!record;
  const todayIso = new Date().toISOString().slice(0, 10);

  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="emp-modal-overlay" id="medExamFormModal" role="dialog" aria-modal="true">
      <div class="emp-modal">
        <div class="emp-modal-title">${isEdit ? 'Izmeni pregled' : 'Novi lekarski pregled'}</div>
        <div class="emp-modal-err" id="medFormErr"></div>
        <form id="medExamForm">
          <input type="hidden" id="medId" value="${escHtml(record?.id || '')}">
          <div class="emp-form-grid">
            <div class="emp-field">
              <label for="medDate">Datum pregleda *</label>
              <input type="date" id="medDate" required value="${escHtml(record?.examDate || todayIso)}">
            </div>
            <div class="emp-field">
              <label for="medValid">Važi do</label>
              <input type="date" id="medValid" value="${escHtml(record?.validUntil || '')}">
            </div>
            <div class="emp-field">
              <label for="medType">Tip *</label>
              <select id="medType" required>
                ${Object.entries(EXAM_TYPE_LABELS).map(([k, v]) =>
                  `<option value="${k}"${(record?.examType || 'redovan') === k ? ' selected' : ''}>${escHtml(v)}</option>`
                ).join('')}
              </select>
            </div>
            <div class="emp-field">
              <label for="medCost">Trošak (RSD)</label>
              <input type="number" id="medCost" min="0" step="0.01" value="${record?.costRsd || 0}">
            </div>
            <div class="emp-field col-full">
              <label for="medInst">Ustanova / lekar</label>
              <input type="text" id="medInst" maxlength="200" value="${escHtml(record?.institution || '')}">
            </div>
            <div class="emp-field col-full">
              <label for="medDoc">Link na dokument (URL)</label>
              <input type="url" id="medDoc" maxlength="500" placeholder="https://…" value="${escHtml(record?.documentUrl || '')}">
            </div>
            <div class="emp-field col-full">
              <label for="medNote">Napomena</label>
              <textarea id="medNote" maxlength="1000" rows="2">${escHtml(record?.note || '')}</textarea>
            </div>
          </div>
          <div class="emp-modal-actions">
            <button type="button" class="btn" id="medFormCancel">Otkaži</button>
            <button type="submit" class="btn btn-primary" id="medFormSubmit">Sačuvaj</button>
          </div>
        </form>
      </div>
    </div>`;
  document.body.appendChild(wrap.firstElementChild);
  const m = document.getElementById('medExamFormModal');
  m.querySelector('#medFormCancel').addEventListener('click', () => m.remove());
  m.addEventListener('click', e => { if (e.target === m) m.remove(); });
  m.querySelector('#medExamForm').addEventListener('submit', e => {
    e.preventDefault();
    submitMedExamForm();
  });
  setTimeout(() => m.querySelector('#medDate')?.focus(), 50);
}

async function submitMedExamForm() {
  const err = document.getElementById('medFormErr');
  err.textContent = ''; err.classList.remove('visible');

  const id = document.getElementById('medId').value || null;
  const examDate = document.getElementById('medDate').value;
  const validUntil = document.getElementById('medValid').value || null;
  const examType = document.getElementById('medType').value;
  const costRsd = parseFloat(document.getElementById('medCost').value) || 0;
  const institution = document.getElementById('medInst').value.trim();
  const documentUrl = document.getElementById('medDoc').value.trim();
  const note = document.getElementById('medNote').value.trim();

  if (!examDate) { err.textContent = 'Datum pregleda je obavezan.'; err.classList.add('visible'); return; }
  if (validUntil && validUntil < examDate) {
    err.textContent = '"Važi do" ne može biti pre datuma pregleda.';
    err.classList.add('visible'); return;
  }
  if (costRsd < 0) {
    err.textContent = 'Trošak ne može biti negativan.';
    err.classList.add('visible'); return;
  }

  const payload = {
    id, employeeId: currentEmpId,
    examDate, validUntil, examType, costRsd, institution, documentUrl, note,
  };
  const btn = document.getElementById('medFormSubmit');
  btn.disabled = true; btn.textContent = '⏳';
  try {
    const saved = await saveMedExam(payload);
    if (!saved) {
      err.textContent = 'Čuvanje nije uspelo. Da li je migracija add_kadr_medical_exams.sql primenjena?';
      err.classList.add('visible');
      return;
    }
    document.getElementById('medExamFormModal')?.remove();
    showToast(id ? '✏️ Izmenjeno' : '✅ Pregled sačuvan');
    await refreshMedList();
    onChangeCb?.();
  } catch (e) {
    console.error('[medExams] save', e);
    err.textContent = 'Greška pri čuvanju.';
    err.classList.add('visible');
  } finally {
    btn.disabled = false; btn.textContent = 'Sačuvaj';
  }
}
