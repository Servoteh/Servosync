/**
 * Modal za unos/izmenu napomene uz predmet aktivacije.
 */

import { escHtml } from '../../../lib/dom.js';

/**
 * @param {object} opts
 * @param {string} opts.title
 * @param {string} [opts.initial]
 * @param {(text: string|null) => void} opts.onConfirm  null = očisti / prazno
 */
export function openNapomenaModal(opts = {}) {
  const title = opts.title || 'Napomena';
  const initial = opts.initial != null ? String(opts.initial) : '';
  const onConfirm = typeof opts.onConfirm === 'function' ? opts.onConfirm : () => {};

  document.getElementById('predAktNapDlg')?.remove();
  const wrap = document.createElement('div');
  wrap.id = 'predAktNapDlg';
  wrap.className = 'kadr-modal-overlay';
  wrap.innerHTML = `
    <div class="kadr-modal" style="max-width:440px">
      <div class="kadr-modal-title">${escHtml(title)}</div>
      <textarea class="form-input" id="predAktNapTxt" rows="4" style="min-height:96px;width:100%;resize:vertical"
        placeholder="Slobodan tekst…"></textarea>
      <div style="display:flex;gap:8px;justify-content:flex-end;margin-top:14px">
        <button type="button" class="btn" id="predAktNapCancel">Otkaži</button>
        <button type="button" class="btn btn-primary" id="predAktNapSave">Sačuvaj</button>
      </div>
    </div>`;
  const ta = wrap.querySelector('#predAktNapTxt');
  if (ta) ta.value = initial;

  const close = () => wrap.remove();

  wrap.addEventListener('click', e => {
    if (e.target === wrap) close();
  });
  wrap.querySelector('#predAktNapCancel')?.addEventListener('click', close);
  wrap.querySelector('#predAktNapSave')?.addEventListener('click', () => {
    const v = wrap.querySelector('#predAktNapTxt')?.value?.trim() ?? '';
    onConfirm(v === '' ? null : v);
    close();
  });

  document.body.appendChild(wrap);
  ta?.focus();
}
