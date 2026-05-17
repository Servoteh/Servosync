/**
 * Stilizovan, promise-based confirm modal (zamena za window.confirm).
 *
 * Razlozi za zamenu:
 *  - native `confirm()` blokira event loop i UI thread → loš UX na sporijim mašinama
 *  - native dijalog ne može da se stilizuje (problem za destruktivne akcije)
 *  - ne radi konzistentno u Capacitor (mobilni iOS/Android)
 *  - prekida snimanje rada / scroll pozicije u pozadini
 *
 * API:
 *   const ok = await askConfirm({
 *     title: 'Brisanje zaposlenog',
 *     body:  'Petar Petrović — akcija je trajna.',
 *     confirmLabel: 'Obriši',     // default 'Potvrdi'
 *     cancelLabel:  'Otkaži',     // default 'Otkaži'
 *     danger: true,               // crveno dugme + zaglavlje
 *     requireType: 'OBRIŠI',      // zahteva da korisnik ukuca tačno taj tekst
 *   });
 *   if (!ok) return;
 *
 * Modal naseđuje globalni ESC/scroll-lock handler iz `lib/modalA11y.js`
 * (samo ako je `installModalA11y()` pozvan u app-bootstrap-u).
 */

import { escHtml } from './dom.js';

const ID = 'kadrConfirmModal';

function buildHtml({ title, body, confirmLabel, cancelLabel, danger, requireType }) {
  const dangerCls = danger ? ' kadr-confirm--danger' : '';
  const titleHtml = title
    ? `<div class="kadr-modal-title">${escHtml(title)}</div>`
    : '';
  const requireBlock = requireType
    ? `
      <div class="emp-form-grid" style="margin-top:12px;">
        <div class="emp-field col-full">
          <label for="kadrConfirmType">
            Da bi potvrdio, ukucaj <strong>${escHtml(requireType)}</strong>:
          </label>
          <input type="text" id="kadrConfirmType" autocomplete="off" spellcheck="false"
                 placeholder="${escHtml(requireType)}" data-expect="${escHtml(requireType)}">
        </div>
      </div>`
    : '';
  return `
    <div class="kadr-modal-overlay${dangerCls}" id="${ID}" role="alertdialog" aria-modal="true" aria-labelledby="${ID}Title">
      <div class="kadr-modal kadr-confirm">
        ${titleHtml ? titleHtml.replace('kadr-modal-title', 'kadr-modal-title') : ''}
        <div class="kadr-modal-subtitle" id="${ID}Body">${escHtml(body || '')}</div>
        ${requireBlock}
        <div class="kadr-modal-actions">
          <button type="button" class="btn" id="kadrConfirmCancel">${escHtml(cancelLabel || 'Otkaži')}</button>
          <button type="button" class="btn ${danger ? 'btn-danger-soft' : 'btn-primary'}" id="kadrConfirmOk" ${requireType ? 'disabled' : ''}>${escHtml(confirmLabel || 'Potvrdi')}</button>
        </div>
      </div>
    </div>`;
}

function close() {
  document.getElementById(ID)?.remove();
}

/**
 * @param {object} opts
 * @param {string} [opts.title]        — Naslov (može i bez)
 * @param {string} opts.body           — Glavna poruka
 * @param {string} [opts.confirmLabel] — Tekst dugmeta za potvrdu (default „Potvrdi")
 * @param {string} [opts.cancelLabel]  — Tekst dugmeta za otkaz (default „Otkaži")
 * @param {boolean} [opts.danger]      — Markira destruktivnu akciju (crveno dugme)
 * @param {string} [opts.requireType]  — Zahteva da korisnik ukuca tačno taj tekst
 * @returns {Promise<boolean>}
 */
export function askConfirm(opts) {
  /* Ako već postoji confirm modal (dupli klik) — zatvori ga i napravi nov. */
  close();
  return new Promise((resolve) => {
    const wrap = document.createElement('div');
    wrap.innerHTML = buildHtml(opts || {});
    document.body.appendChild(wrap.firstElementChild);

    const modal = document.getElementById(ID);
    const okBtn = modal.querySelector('#kadrConfirmOk');
    const cancelBtn = modal.querySelector('#kadrConfirmCancel');
    const typeInp = modal.querySelector('#kadrConfirmType');

    let settled = false;
    const done = (ok) => {
      if (settled) return;
      settled = true;
      close();
      resolve(!!ok);
    };

    cancelBtn.addEventListener('click', () => done(false));
    okBtn.addEventListener('click', () => done(true));
    /* Klik na overlay = cancel (kompatibilno sa modalA11y ESC handlerom,
       koji dispatch-uje overlay-click). */
    modal.addEventListener('click', (e) => {
      if (e.target === modal) done(false);
    });

    if (typeInp) {
      const expect = typeInp.dataset.expect || '';
      typeInp.addEventListener('input', () => {
        okBtn.disabled = typeInp.value.trim() !== expect;
      });
      /* Enter na input-u = submit ako je dozvoljeno */
      typeInp.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !okBtn.disabled) {
          e.preventDefault();
          done(true);
        }
      });
      setTimeout(() => typeInp.focus(), 50);
    } else {
      /* Bez require-type: fokus na confirm + Enter ga okida. */
      setTimeout(() => okBtn.focus(), 50);
    }
  });
}
