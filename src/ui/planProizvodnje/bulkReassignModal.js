/**
 * Plan proizvodnje — bulk i single REASSIGN modal (PP-E).
 */
import { escHtml, showToast } from '../../lib/dom.js';
import {
  reassignLine,
  bulkReassignLines,
  machineGroupSlugForCode,
  machineGroupLabel,
  canShowForcePlanReassign,
} from '../../services/planProizvodnje.js';

function buildReassignCandidates(allMachines, rows, force) {
  const sourceGroups = new Set(
    rows.map(r => machineGroupSlugForCode(r.assigned_machine_code || r.original_machine_code)),
  );
  const sourceGroup = sourceGroups.size === 1 ? Array.from(sourceGroups)[0] : null;
  const originalCodes = new Set(rows.map(r => r.original_machine_code).filter(Boolean));
  return (allMachines || []).filter(m => {
    if (!m?.rj_code || originalCodes.has(m.rj_code)) return false;
    if (force) return true;
    return sourceGroup && machineGroupSlugForCode(m.rj_code) === sourceGroup;
  });
}

/**
 * @param {object} o
 * @param {object[]} o.selectedRows
 * @param {object[]} o.allMachines
 * @param {boolean} o.bulk
 * @param {() => Promise<void>} o.onComplete posle uspeha
 */
export function openPlanBulkReassignModal({
  selectedRows,
  allMachines,
  bulk,
  onComplete,
}) {
  const selected = Array.isArray(selectedRows) ? selectedRows.filter(Boolean) : [];
  if (selected.length === 0) return;

  const forceAllowed = canShowForcePlanReassign();
  const sourceGroups = new Set(
    selected.map(r => machineGroupSlugForCode(r.assigned_machine_code || r.original_machine_code)),
  );
  const sourceGroup = sourceGroups.size === 1 ? Array.from(sourceGroups)[0] : null;
  const mixedGroups = sourceGroups.size > 1;
  const title = bulk
    ? `Premesti ${selected.length} pozicija`
    : `Premesti RN ${selected[0].rn_ident_broj || '?'} / op. ${selected[0].operacija || '?'}`;

  const overlay = document.createElement('div');
  overlay.className = 'pp-reassign-modal-backdrop';
  overlay.innerHTML = `
    <div class="pp-reassign-modal" role="dialog" aria-modal="true" aria-label="${escHtml(title)}">
      <div class="pp-reassign-modal-head">
        <strong>${escHtml(title)}</strong>
        <button type="button" class="pp-modal-close" data-action="close">×</button>
      </div>
      <div class="pp-reassign-modal-body">
        <p class="pp-modal-hint">
          Izvorna grupa:
          <strong>${mixedGroups ? 'mešane grupe' : escHtml(machineGroupLabel(sourceGroup))}</strong>
        </p>
        ${mixedGroups
          ? `<div class="pp-warning">Izabrane operacije su iz različitih vrsta mašina. Standardni bulk je blokiran; force mogu samo admin/menadžment uz razlog.</div>`
          : ''}
        ${forceAllowed
          ? `<label class="pp-force-row">
               <input type="checkbox" data-action="force-toggle">
               Forsiraj drugu vrstu mašine
             </label>`
          : ''}
        <label class="pp-reassign-field">
          <span>Ciljna mašina</span>
          <select data-action="target-machine"></select>
        </label>
        <label class="pp-reassign-field pp-force-reason" hidden>
          <span>Razlog forsiranja</span>
          <textarea data-action="force-reason" rows="3" placeholder="Npr. mašina nije dostupna, posao kompatibilan..."></textarea>
        </label>
        <div class="pp-modal-error" data-role="error"></div>
      </div>
      <div class="pp-reassign-modal-foot">
        <button type="button" class="pp-refresh-btn" data-action="close">Otkaži</button>
        <button type="button" class="pp-refresh-btn pp-modal-primary" data-action="submit">Premesti</button>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);

  const close = () => overlay.remove();
  const forceToggle = overlay.querySelector('[data-action="force-toggle"]');
  const select = overlay.querySelector('[data-action="target-machine"]');
  const reasonWrap = overlay.querySelector('.pp-force-reason');
  const reasonInput = overlay.querySelector('[data-action="force-reason"]');
  const errorEl = overlay.querySelector('[data-role="error"]');
  const submit = overlay.querySelector('[data-action="submit"]');

  const renderOptions = () => {
    const force = !!forceToggle?.checked;
    const candidates = buildReassignCandidates(allMachines, selected, force);
    select.innerHTML = `
      <option value="">— izaberi mašinu —</option>
      ${candidates.map(m => `
        <option value="${escHtml(m.rj_code)}">
          ${escHtml(m.name || '')} (${escHtml(m.rj_code)}) · ${escHtml(machineGroupLabel(machineGroupSlugForCode(m.rj_code)))}
        </option>
      `).join('')}
    `;
    if (reasonWrap) reasonWrap.hidden = !force;
    if (mixedGroups && !force) {
      errorEl.textContent = forceAllowed
        ? 'Uključi force za mešane grupe ili izaberi operacije iz iste vrste mašine.'
        : 'Bulk REASSIGN zahteva da sve izabrane operacije pripadaju istoj vrsti mašina.';
      submit.disabled = true;
    } else {
      errorEl.textContent = '';
      submit.disabled = false;
    }
  };

  overlay.querySelectorAll('[data-action="close"]').forEach(btn => btn.addEventListener('click', close));
  overlay.addEventListener('click', e => {
    if (e.target === overlay) close();
  });
  forceToggle?.addEventListener('change', renderOptions);
  renderOptions();

  submit.addEventListener('click', async () => {
    const targetMachine = select.value || null;
    const force = !!forceToggle?.checked;
    const reason = String(reasonInput?.value || '').trim();
    if (!targetMachine) {
      errorEl.textContent = 'Izaberi ciljnu mašinu.';
      return;
    }
    if (force && reason.length < 3) {
      errorEl.textContent = 'Razlog forsiranja je obavezan (min 3 karaktera).';
      return;
    }
    submit.disabled = true;
    const res = bulk
      ? await bulkReassignLines({
        pairs: selected.map(r => ({ wo: r.work_order_id, line: r.line_id })),
        targetMachine,
        force,
        reason,
      })
      : await reassignLine({
        workOrderId: selected[0].work_order_id,
        lineId: selected[0].line_id,
        targetMachine,
        force,
        reason,
      });
    if (res === null) {
      submit.disabled = false;
      errorEl.textContent = force
        ? 'Premestanje nije uspelo. Proveri prava i razlog forsiranja.'
        : 'Premestanje nije uspelo. Ciljna mašina verovatno nije ista vrsta.';
      return;
    }
    showToast(
      bulk
        ? `✓ Premešteno ${selected.length} operacija na ${targetMachine}`
        : `✓ Operacija premeštena na ${targetMachine}`,
    );
    close();
    if (typeof onComplete === 'function') await onComplete();
  });

  select.focus();
}
