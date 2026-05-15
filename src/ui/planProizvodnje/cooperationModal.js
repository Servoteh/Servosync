/**
 * PP-D: modal za izbor kojih TP linija RN idu u kooperaciju.
 */
import { escHtml, showToast } from '../../lib/dom.js';
import {
  loadWorkOrderLinesBigtehn,
  loadActiveCooperationOps,
  syncCooperationSelections,
} from '../../services/planProizvodnje.js';

/**
 * @param {object} opts
 * @param {object} opts.row — red iz plana (ima work_order_id, line_id, rn_ident_broj, broj_crteza)
 * @param {boolean} opts.canEdit
 * @param {() => Promise<void>} [opts.onSaved]
 */
export async function openCooperationPickModal({ row, canEdit, onSaved }) {
  if (!canEdit) {
    showToast('Nemaš pravo uređivanja Plan proizvodnje.');
    return;
  }
  const wo = Number(row?.work_order_id);
  if (!Number.isFinite(wo)) return;

  let lines;
  let active;
  try {
    [lines, active] = await Promise.all([
      loadWorkOrderLinesBigtehn(wo),
      loadActiveCooperationOps(wo),
    ]);
  } catch (e) {
    console.error('[coop-modal]', e);
    showToast('Greška pri učitavanju podataka za kooperaciju.');
    return;
  }

  const activeSet = new Set(active.map(a => `${Number(a.line_id)}:${Number(a.operacija)}`));
  const subtitle = row?.broj_crteza
    ? `${escHtml(String(row.broj_crteza).trim())}`
    : `${escHtml(row?.rn_ident_broj || '')}`;

  const overlay = document.createElement('div');
  overlay.className = 'pp-reassign-modal-backdrop';
  overlay.innerHTML = `
    <div class="pp-reassign-modal pp-cooperation-modal" role="dialog" aria-modal="true">
      <div class="pp-reassign-modal-head">
        <strong>Slanje pozicije u kooperaciju</strong>
        <button type="button" class="pp-modal-close" data-action="close">×</button>
      </div>
      <div class="pp-reassign-modal-body">
        <p class="pp-modal-hint">Crtež / RN: <strong>${subtitle}</strong></p>
        <p class="pp-modal-hint">Označi koje operacije (TP stavke) idu spolja — ostale ostaju u operativnom planu.</p>
        <div class="pp-coop-op-list" role="group" aria-label="Operacije">
          ${lines.length === 0
            ? '<div class="pp-warning">Nema stavki RN u kešu — proveri Bridge sync.</div>'
            : lines.map(l => {
              const lid = Number(l.id);
              const op = Number(l.operacija);
              const k = `${lid}:${op}`;
              const chk = activeSet.has(k) ? 'checked' : '';
              const machine = escHtml(l.machine_code || '—');
              const desc = escHtml((l.opis_rada || '').slice(0, 120));
              return `
                <label class="pp-coop-op-row">
                  <input type="checkbox" data-line="${lid}" data-op="${op}" ${chk} />
                  <span class="pp-coop-meta">
                    <span class="pp-coop-no">Op. ${escHtml(String(op).padStart(2, '0'))}</span>
                    <span class="pp-coop-m">${machine}</span>
                  </span>
                  <span class="pp-coop-desc" title="${escHtml(l.opis_rada || '')}">${desc || '—'}</span>
                </label>`;
            }).join('')}
        </div>
        <label class="pp-reassign-field">
          <span>Napomena (opciono)</span>
          <textarea data-role="note" rows="2" placeholder="Npr. partner, rok povrataka…"></textarea>
        </label>
        <div class="pp-modal-error" data-role="error"></div>
      </div>
      <div class="pp-reassign-modal-foot">
        <button type="button" class="pp-refresh-btn" data-action="close">Otkaži</button>
        <button type="button" class="pp-refresh-btn pp-modal-primary" data-action="save">
          Sačuvaj
        </button>
      </div>
    </div>`;
  document.body.appendChild(overlay);

  const close = () => overlay.remove();
  const errEl = overlay.querySelector('[data-role="error"]');
  const noteTa = overlay.querySelector('[data-role="note"]');
  overlay.querySelectorAll('[data-action="close"]').forEach(b => b.addEventListener('click', close));
  overlay.addEventListener('click', e => {
    if (e.target === overlay) close();
  });

  overlay.querySelector('[data-action="save"]')?.addEventListener('click', async () => {
    const checks = overlay.querySelectorAll('input[type="checkbox"][data-line]');
    const selections = [];
    checks.forEach(ch => {
      if (!ch.checked) return;
      selections.push({
        lineId: Number(ch.dataset.line),
        operacija: Number(ch.dataset.op),
      });
    });
    errEl.textContent = '';
    const ok = await syncCooperationSelections({
      workOrderId: wo,
      selections,
      note: noteTa?.value || '',
    });
    if (!ok) {
      errEl.textContent = 'Snimanje nije uspelo (mreža ili prava).';
      return;
    }
    showToast('✓ Kooperacija ažurirana');
    close();
    if (typeof onSaved === 'function') await onSaved();
  });
}
