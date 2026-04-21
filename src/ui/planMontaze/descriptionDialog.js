/**
 * Plan Montaže — dijalog za detaljan opis faze.
 *
 * Otvara prozor sa velikim `<textarea>` poljem u kojem korisnik može
 * da napiše šta konkretno ova faza obuhvata (npr. "Postavljanje
 * pneumatskog sistema za presu 350t — spoj cilindara, podešavanje
 * pritiska, testiranje"). Snima se u `phase.description` i prolazi kroz
 * debounced Supabase save preko `updatePhaseField(..., 'description')`.
 *
 * Viewer (readonly) korisnik vidi sadržaj ali ne može da menja.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { canEdit } from '../../state/auth.js';
import { getActivePhases } from '../../state/planMontaze.js';
import { updatePhaseField } from './planActions.js';

let _overlayEl = null;

/**
 * @param {number} phaseIndex  Indeks u nizu faza aktivnog WP-a.
 * @param {Function} [onSaved] Callback posle snimanja (rerender).
 */
export function openDescriptionDialog(phaseIndex, onSaved) {
  closeDescriptionDialog();
  const phases = getActivePhases();
  const row = phases[phaseIndex];
  if (!row) return;
  const editable = canEdit();
  const title = row.name || `Faza ${phaseIndex + 1}`;

  _overlayEl = document.createElement('div');
  _overlayEl.className = 'modal-overlay open';
  _overlayEl.innerHTML = `
    <div class="modal-panel" role="dialog" aria-label="Detaljan opis faze">
      <div class="modal-head">
        <h3>📝 Opis — ${escHtml(title)}</h3>
        <button type="button" class="modal-close" data-desc-action="close" aria-label="Zatvori">✕</button>
      </div>
      <div class="modal-body">
        <p class="form-hint" style="margin-top:0">
          Upiši detaljan opis šta ova faza obuhvata — materijal, procedure,
          rizici, napomene koje treba znati pre starta montaže.
        </p>
        <textarea id="phaseDescTextarea"
                  class="phase-description-textarea"
                  rows="14"
                  placeholder="Npr. ugradnja hidrauličkog agregata 250 bar, povezivanje creva, test pritiska 1.5x radnog, obeležavanje mernih tačaka…"
                  ${editable ? '' : 'readonly'}>${escHtml(row.description || '')}</textarea>
        ${editable ? '' : '<p class="form-hint" style="color:var(--risk-med)">⚠ Pregled — opis je samo za čitanje.</p>'}
      </div>
      <div class="modal-foot">
        <button type="button" class="btn btn-ghost" data-desc-action="close">Otkaži</button>
        ${editable ? '<button type="button" class="btn btn-primary" data-desc-action="save">💾 Sačuvaj opis</button>' : ''}
      </div>
    </div>
  `;
  document.body.appendChild(_overlayEl);

  const ta = _overlayEl.querySelector('#phaseDescTextarea');

  _overlayEl.querySelectorAll('[data-desc-action="close"]').forEach(b => {
    b.addEventListener('click', closeDescriptionDialog);
  });
  _overlayEl.addEventListener('click', (ev) => {
    if (ev.target === _overlayEl) closeDescriptionDialog();
  });
  _overlayEl.querySelector('[data-desc-action="save"]')?.addEventListener('click', () => {
    const val = String(ta?.value || '').trim();
    updatePhaseField(phaseIndex, 'description', val);
    showToast('💾 Opis sačuvan');
    closeDescriptionDialog();
    onSaved?.();
  });

  document.addEventListener('keydown', _onKey);

  setTimeout(() => ta?.focus(), 20);
}

export function closeDescriptionDialog() {
  document.removeEventListener('keydown', _onKey);
  if (_overlayEl?.parentNode) _overlayEl.parentNode.removeChild(_overlayEl);
  _overlayEl = null;
}

function _onKey(ev) {
  if (ev.key === 'Escape') closeDescriptionDialog();
}
