/**
 * Globalni a11y/UX helper za kadrovska modale.
 *
 * Tipičan modal u modulu se ubacuje u DOM kao:
 *   <div class="emp-modal-overlay" id="…" role="dialog" aria-modal="true">…</div>
 *   ili
 *   <div class="kadr-modal-overlay" id="…" role="dialog" aria-modal="true">…</div>
 *
 * Svaki već handluje overlay-click kao close (modal.addEventListener('click', …)).
 * Ovaj modul dodaje dve stvari koje su prethodno bile rasute / nedostajale:
 *
 *   1) ESC zatvara najgornji modal — simulira klik na overlay element koji
 *      svaki modal već handluje kao close. Ne diramo individualne wire-ove.
 *
 *   2) `<body>` scroll lock dok je bar jedan modal otvoren — sprečava da
 *      pozadina skroluje na touch / wheel kad korisnik pomera modal sadržaj.
 *
 * Bez framework-a, bez state-a — MutationObserver gleda body za dodavanje /
 * uklanjanje modala. Instalira se jednom u app-bootstrap-u (npr. iz Kadrovska
 * `index.js`). Idempotentno.
 */

const MODAL_SELECTOR = '.emp-modal-overlay, .kadr-modal-overlay';
const BODY_LOCK_ATTR = 'data-kadr-modal-open';

let _installed = false;
let _prevBodyOverflow = '';

function isModalOverlay(node) {
  return node && node.nodeType === 1 && node.matches?.(MODAL_SELECTOR);
}

function visibleModals() {
  return Array.from(document.querySelectorAll(MODAL_SELECTOR))
    .filter(m => m.isConnected && m.offsetParent !== null);
}

function applyBodyLock() {
  const open = visibleModals().length > 0;
  const body = document.body;
  if (!body) return;
  const isLocked = body.hasAttribute(BODY_LOCK_ATTR);
  if (open && !isLocked) {
    _prevBodyOverflow = body.style.overflow || '';
    body.style.overflow = 'hidden';
    body.setAttribute(BODY_LOCK_ATTR, '1');
  } else if (!open && isLocked) {
    body.style.overflow = _prevBodyOverflow;
    body.removeAttribute(BODY_LOCK_ATTR);
    _prevBodyOverflow = '';
  }
}

function onKeyDown(ev) {
  if (ev.key !== 'Escape' && ev.key !== 'Esc') return;
  const modals = visibleModals();
  if (!modals.length) return;
  /* Najgornji = poslednji u DOM redosledu (jer modali se append-uju u body). */
  const top = modals[modals.length - 1];
  /* Ne zatvaraj ako je fokus u textarea sa nesačuvanim tekstom — UX:
     korisnik može da preuredjuje pa pritisne ESC slučajno. Treba dva ESC.
     Jednostavnije rešenje: ako je aktivni element textarea SA tekstom
     unutar modala, prvi ESC samo blur-uje; drugi zatvara. */
  const ae = document.activeElement;
  if (ae && top.contains(ae) && ae.tagName === 'TEXTAREA' && ae.value && ae.value.trim()) {
    if (!top.dataset.kadrEscArmed) {
      top.dataset.kadrEscArmed = '1';
      ae.blur();
      ev.preventDefault();
      setTimeout(() => { try { delete top.dataset.kadrEscArmed; } catch {} }, 1500);
      return;
    }
  }
  /* Simuliraj overlay-click — svaki modal već handluje
     `if (ev.target === modal) close()`. Šaljemo synthetic click na sam overlay. */
  ev.preventDefault();
  ev.stopPropagation();
  try {
    top.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
  } catch {
    /* Fallback — ukloni iz DOM-a direktno (gubi se cleanup hooks, ali sve modale
       su self-contained: njihovi listeneri su attach-ovani na elemente unutar i
       odlaze sa overlay-em). */
    top.remove();
  }
  applyBodyLock();
}

function onMutation(mutations) {
  let touched = false;
  for (const m of mutations) {
    if (m.type !== 'childList') continue;
    for (const n of m.addedNodes) {
      if (isModalOverlay(n) || n.querySelector?.(MODAL_SELECTOR)) {
        touched = true;
        break;
      }
    }
    if (touched) break;
    for (const n of m.removedNodes) {
      if (isModalOverlay(n) || n.querySelector?.(MODAL_SELECTOR)) {
        touched = true;
        break;
      }
    }
    if (touched) break;
  }
  if (touched) applyBodyLock();
}

/**
 * Instaliraj globalne a11y handlere. Idempotentno — bezbedno zvati više puta.
 * Treba pozvati jednom pri prvom mount-u Kadrovska modula.
 */
export function installModalA11y() {
  if (_installed) return;
  _installed = true;
  document.addEventListener('keydown', onKeyDown, true);
  const obs = new MutationObserver(onMutation);
  obs.observe(document.body, { childList: true, subtree: false });
  /* Initial state: ako je modal već u DOM-u, zaključaj odmah. */
  applyBodyLock();
}
