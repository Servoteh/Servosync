/**
 * Podešavanja / Organizacija — admin CRUD za odeljenja, pododeljenja i radna mesta.
 *
 * Prikazuje trostepenu listu:
 *   Odeljenje → [+ pododeljenje]
 *     Pododeljenje → [+ radno mesto]
 *       Radno mesto
 *
 * Sve izmene odmah šalju na DB i osvežavaju prikaz.
 * Dostupno SAMO adminu (enforced RLS + canManageUsers guard u parentu).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { orgStructureState } from '../../state/kadrovska.js';
import { ensureOrgStructureLoaded } from '../../services/kadrovska.js';
import {
  saveDepartment, updateDepartment, deleteDepartment,
  saveSubDepartment, updateSubDepartment, deleteSubDepartment,
  saveJobPosition, updateJobPosition, deleteJobPosition,
} from '../../services/orgStructure.js';

let _root = null;

/* ── PUBLIC API ────────────────────────────────────────────────────── */

export function renderOrgStructureTab() {
  return `<div class="org-tab" id="orgStructureTab"><em>Učitavam strukturu…</em></div>`;
}

export async function wireOrgStructureTab(panelEl) {
  _root = panelEl.querySelector('#orgStructureTab');
  if (!_root) return;
  await ensureOrgStructureLoaded(true);
  _render();
}

export async function refreshOrgStructure() {
  await ensureOrgStructureLoaded(true);
  if (_root) _render();
}

/* ── RENDER ────────────────────────────────────────────────────────── */

function _render() {
  if (!_root) return;

  const depts = [...orgStructureState.departments].sort((a, b) => a.sort_order - b.sort_order || a.name.localeCompare(b.name, 'sr'));

  const rows = depts.map(dept => {
    const subDepts = orgStructureState.subDepartments
      .filter(s => s.department_id === dept.id)
      .sort((a, b) => a.sort_order - b.sort_order || a.name.localeCompare(b.name, 'sr'));

    const subRows = subDepts.map(sd => {
      const positions = orgStructureState.jobPositions
        .filter(p => p.sub_department_id === sd.id)
        .sort((a, b) => a.sort_order - b.sort_order || a.name.localeCompare(b.name, 'sr'));

      const posRows = positions.map(p => `
        <div class="org-item org-pos" data-pos-id="${p.id}">
          <span class="org-item-name">${escHtml(p.name)}</span>
          <div class="org-item-actions">
            <button class="btn-row-act" data-act="edit-pos" data-id="${p.id}">Preimenuj</button>
            <button class="btn-row-act danger" data-act="del-pos" data-id="${p.id}">Obriši</button>
          </div>
        </div>`).join('');

      return `
        <div class="org-item org-subdept" data-sd-id="${sd.id}">
          <div class="org-item-header">
            <span class="org-item-name">${escHtml(sd.name)}</span>
            <div class="org-item-actions">
              <button class="btn-row-act" data-act="add-pos" data-sd-id="${sd.id}" data-dept-id="${dept.id}">+ Radno mesto</button>
              <button class="btn-row-act" data-act="edit-sd" data-id="${sd.id}">Preimenuj</button>
              <button class="btn-row-act danger" data-act="del-sd" data-id="${sd.id}">Obriši</button>
            </div>
          </div>
          <div class="org-positions">${posRows}</div>
        </div>`;
    }).join('');

    /* Radna mesta direktno pod odeljenjem (bez pododeljenja) */
    const directPositions = orgStructureState.jobPositions
      .filter(p => p.department_id === dept.id && !p.sub_department_id)
      .sort((a, b) => a.sort_order - b.sort_order || a.name.localeCompare(b.name, 'sr'));

    const directPosRows = directPositions.map(p => `
      <div class="org-item org-pos" data-pos-id="${p.id}">
        <span class="org-item-name org-item-direct">${escHtml(p.name)}</span>
        <div class="org-item-actions">
          <button class="btn-row-act" data-act="edit-pos" data-id="${p.id}">Preimenuj</button>
          <button class="btn-row-act danger" data-act="del-pos" data-id="${p.id}">Obriši</button>
        </div>
      </div>`).join('');

    return `
      <div class="org-dept" data-dept-id="${dept.id}">
        <div class="org-dept-header">
          <span class="org-dept-name">${escHtml(dept.name)}</span>
          <div class="org-item-actions">
            <button class="btn-row-act" data-act="add-sd" data-dept-id="${dept.id}">+ Pododeljenje</button>
            <button class="btn-row-act" data-act="add-pos-direct" data-dept-id="${dept.id}">+ Radno mesto</button>
            <button class="btn-row-act" data-act="edit-dept" data-id="${dept.id}">Preimenuj</button>
            <button class="btn-row-act danger" data-act="del-dept" data-id="${dept.id}">Obriši</button>
          </div>
        </div>
        <div class="org-subdepts">
          ${subRows}
          ${directPosRows}
        </div>
      </div>`;
  }).join('');

  _root.innerHTML = `
    <div class="org-toolbar">
      <button class="btn btn-primary" id="orgAddDeptBtn">+ Novo odeljenje</button>
      <span class="form-hint">Samo admin može da menja listu odeljenja, pododeljenja i radnih mesta.</span>
    </div>
    <div class="org-tree">${rows || '<em class="org-empty">Nema unesenih odeljenja.</em>'}</div>
  `;

  _wire();
}

/* ── WIRE ──────────────────────────────────────────────────────────── */

function _wire() {
  _root.querySelector('#orgAddDeptBtn')?.addEventListener('click', () => _addDept());

  _root.querySelectorAll('[data-act]').forEach(btn => {
    const act = btn.dataset.act;
    if (act === 'edit-dept')      btn.addEventListener('click', () => _editDept(parseInt(btn.dataset.id, 10)));
    if (act === 'del-dept')       btn.addEventListener('click', () => _delDept(parseInt(btn.dataset.id, 10)));
    if (act === 'add-sd')         btn.addEventListener('click', () => _addSubDept(parseInt(btn.dataset.deptId, 10)));
    if (act === 'edit-sd')        btn.addEventListener('click', () => _editSubDept(parseInt(btn.dataset.id, 10)));
    if (act === 'del-sd')         btn.addEventListener('click', () => _delSubDept(parseInt(btn.dataset.id, 10)));
    if (act === 'add-pos')        btn.addEventListener('click', () => _addPos(parseInt(btn.dataset.deptId, 10), parseInt(btn.dataset.sdId, 10)));
    if (act === 'add-pos-direct') btn.addEventListener('click', () => _addPos(parseInt(btn.dataset.deptId, 10), null));
    if (act === 'edit-pos')       btn.addEventListener('click', () => _editPos(parseInt(btn.dataset.id, 10)));
    if (act === 'del-pos')        btn.addEventListener('click', () => _delPos(parseInt(btn.dataset.id, 10)));
  });
}

/* ── INLINE PROMPT HELPER ──────────────────────────────────────────── */

function _prompt(msg, defaultVal = '') {
  const v = window.prompt(msg, defaultVal);
  return v === null ? null : v.trim();
}

/* ── DEPARTMENTS ───────────────────────────────────────────────────── */

async function _addDept() {
  const name = _prompt('Naziv novog odeljenja:');
  if (!name) return;
  const res = await saveDepartment({ name });
  if (!res?.length) { showToast('⚠ Nije uspelo dodavanje'); return; }
  await refreshOrgStructure();
  showToast('✅ Odeljenje dodato');
}

async function _editDept(id) {
  const dept = orgStructureState.departments.find(d => d.id === id);
  if (!dept) return;
  const name = _prompt('Novo ime odeljenja:', dept.name);
  if (!name || name === dept.name) return;
  const res = await updateDepartment(id, { name });
  if (!res) { showToast('⚠ Nije uspelo preimenovanje'); return; }
  await refreshOrgStructure();
  showToast('✅ Odeljenje preimenovano');
}

async function _delDept(id) {
  const dept = orgStructureState.departments.find(d => d.id === id);
  if (!dept) return;
  const hasSub = orgStructureState.subDepartments.some(s => s.department_id === id);
  const hasPos = orgStructureState.jobPositions.some(p => p.department_id === id);
  if (hasSub || hasPos) {
    if (!confirm(`Odeljenje "${dept.name}" ima pododeljenja ili radna mesta.\nBrisanjem odeljenja brišu se i sva pododeljenja i radna mesta ispod njega.\nNastaviti?`)) return;
  } else {
    if (!confirm(`Obrisati odeljenje "${dept.name}"?`)) return;
  }
  const ok = await deleteDepartment(id);
  if (!ok) { showToast('⚠ Nije uspelo brisanje'); return; }
  await refreshOrgStructure();
  showToast('🗑 Odeljenje obrisano');
}

/* ── SUB-DEPARTMENTS ───────────────────────────────────────────────── */

async function _addSubDept(deptId) {
  const dept = orgStructureState.departments.find(d => d.id === deptId);
  const name = _prompt(`Naziv novog pododeljenja u "${dept?.name || ''}":`);;
  if (!name) return;
  const res = await saveSubDepartment({ department_id: deptId, name });
  if (!res?.length) { showToast('⚠ Nije uspelo dodavanje'); return; }
  await refreshOrgStructure();
  showToast('✅ Pododeljenje dodato');
}

async function _editSubDept(id) {
  const sd = orgStructureState.subDepartments.find(s => s.id === id);
  if (!sd) return;
  const name = _prompt('Novo ime pododeljenja:', sd.name);
  if (!name || name === sd.name) return;
  const res = await updateSubDepartment(id, { name });
  if (!res) { showToast('⚠ Nije uspelo preimenovanje'); return; }
  await refreshOrgStructure();
  showToast('✅ Pododeljenje preimenovano');
}

async function _delSubDept(id) {
  const sd = orgStructureState.subDepartments.find(s => s.id === id);
  if (!sd) return;
  const hasPos = orgStructureState.jobPositions.some(p => p.sub_department_id === id);
  if (hasPos) {
    if (!confirm(`Pododeljenje "${sd.name}" ima radna mesta.\nBrisanjem pododeljenja, radna mesta ostaju ali se odvajaju od pododeljenja.\nNastaviti?`)) return;
  } else {
    if (!confirm(`Obrisati pododeljenje "${sd.name}"?`)) return;
  }
  const ok = await deleteSubDepartment(id);
  if (!ok) { showToast('⚠ Nije uspelo brisanje'); return; }
  await refreshOrgStructure();
  showToast('🗑 Pododeljenje obrisano');
}

/* ── JOB POSITIONS ─────────────────────────────────────────────────── */

async function _addPos(deptId, subDeptId) {
  const parent = subDeptId
    ? orgStructureState.subDepartments.find(s => s.id === subDeptId)?.name
    : orgStructureState.departments.find(d => d.id === deptId)?.name;
  const name = _prompt(`Naziv novog radnog mesta u "${parent || ''}":`);;
  if (!name) return;
  const res = await saveJobPosition({ department_id: deptId, sub_department_id: subDeptId, name });
  if (!res?.length) { showToast('⚠ Nije uspelo dodavanje'); return; }
  await refreshOrgStructure();
  showToast('✅ Radno mesto dodato');
}

async function _editPos(id) {
  const pos = orgStructureState.jobPositions.find(p => p.id === id);
  if (!pos) return;
  const name = _prompt('Novo ime radnog mesta:', pos.name);
  if (!name || name === pos.name) return;
  const res = await updateJobPosition(id, { name });
  if (!res) { showToast('⚠ Nije uspelo preimenovanje'); return; }
  await refreshOrgStructure();
  showToast('✅ Radno mesto preimenovano');
}

async function _delPos(id) {
  const pos = orgStructureState.jobPositions.find(p => p.id === id);
  if (!pos) return;
  if (!confirm(`Obrisati radno mesto "${pos.name}"?`)) return;
  const ok = await deleteJobPosition(id);
  if (!ok) { showToast('⚠ Nije uspelo brisanje'); return; }
  await refreshOrgStructure();
  showToast('🗑 Radno mesto obrisano');
}
