/**
 * Globalni keyboard shortcuts (C5 UX polish).
 *
 * Cilj: ubrzati svakodnevni rad bez mouseva.
 *
 * Default shortcuts (svuda gde se mountira):
 *   /        — fokus na primarnu pretragu u trenutnom panelu
 *   n        — otvori primarno "+Novi" dugme (ako je vidljivo)
 *   r        — osveži / reload (klikne "Osveži" / "↻" dugme ako postoji)
 *   ?        — otvori help overlay sa listom shortcut-a
 *   ESC      — već handluje modalA11y.js (zatvara modal)
 *
 * Pravila:
 *  - Ne aktiviraj kad je fokus u input/textarea/select/contenteditable
 *    izuzev `/` koji uvek hvata i fokusira pretragu (vežne za GitHub stil).
 *  - Ne aktiviraj kad je modifier (Ctrl/Cmd/Alt) — prepuštamo browser-u.
 *  - Help overlay (`?`) može da se zatvori ESC-om ili klikom na overlay.
 *
 * Idempotentno — `installKeyboardShortcuts()` se može zvati više puta.
 */

import { escHtml } from './dom.js';

const SEARCH_SELECTOR = [
  '.kadrovska-search',
  '.kadr-grid-search-input',
  'input[type="search"]',
  'input[id$="Search"]',
  'input[id$="search"]',
].join(', ');

const NEW_BUTTON_SELECTOR = [
  '.btn.btn-primary',  // primarno + dugme u toolbar-ima
  '[data-shortcut="new"]',
].join(', ');

const RELOAD_BUTTON_SELECTOR = [
  '#gridReload',
  '#kadrDashRefresh',
  '#hrnScanBtn',
  '[data-shortcut="reload"]',
].join(', ');

const HELP_MODAL_ID = 'kadrShortcutsHelp';

let _installed = false;

function isTypingTarget(ev) {
  const t = ev.target;
  if (!t) return false;
  const tag = t.tagName;
  if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return true;
  if (t.isContentEditable) return true;
  return false;
}

function hasModifier(ev) {
  return ev.ctrlKey || ev.metaKey || ev.altKey;
}

/** Nađi najvidljiviji search input u panelu / page. */
function findVisibleSearch() {
  const all = document.querySelectorAll(SEARCH_SELECTOR);
  for (const el of all) {
    if (el.offsetParent !== null && !el.disabled) return el;
  }
  return null;
}

/** Nađi vidljivo primarno dugme — preferira "+Novi" tekst, inače prvi btn-primary u toolbar-u. */
function findVisibleNewButton() {
  /* 1) explicit data-shortcut="new" ima prednost */
  const tagged = Array.from(document.querySelectorAll('[data-shortcut="new"]'))
    .find(b => b.offsetParent !== null && !b.disabled);
  if (tagged) return tagged;
  /* 2) primary dugme u toolbar-u kome tekst počinje sa "+ " */
  const toolbarButtons = Array.from(document.querySelectorAll('.kadrovska-toolbar .btn-primary, .kadr-toolbar .btn-primary'));
  for (const b of toolbarButtons) {
    if (b.offsetParent === null || b.disabled) continue;
    const txt = (b.textContent || '').trim();
    if (txt.startsWith('+')) return b;
  }
  /* 3) bilo koji primarni btn u toolbar-u */
  for (const b of toolbarButtons) {
    if (b.offsetParent !== null && !b.disabled) return b;
  }
  return null;
}

function findVisibleReload() {
  const all = document.querySelectorAll(RELOAD_BUTTON_SELECTOR);
  for (const el of all) {
    if (el.offsetParent !== null && !el.disabled) return el;
  }
  return null;
}

function openHelp() {
  closeHelp();
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay" id="${HELP_MODAL_ID}" role="dialog" aria-modal="true">
      <div class="kadr-modal kadr-shortcuts-modal">
        <div class="kadr-modal-title">⌨ Tastaturni prečice</div>
        <div class="kadr-modal-subtitle">Ubrzaj svakodnevni rad — primenjivi su svuda osim kad kucaš u input/textarea.</div>
        <div class="kadr-shortcut-list">
          <div class="kadr-shortcut-row">
            <kbd>/</kbd>
            <span>Fokusiraj pretragu u trenutnom panelu</span>
          </div>
          <div class="kadr-shortcut-row">
            <kbd>n</kbd>
            <span>Otvori „+ Novi…" (glavno dugme u toolbar-u)</span>
          </div>
          <div class="kadr-shortcut-row">
            <kbd>r</kbd>
            <span>Osveži / reload tabelu (↻)</span>
          </div>
          <div class="kadr-shortcut-row">
            <kbd>?</kbd>
            <span>Otvori ovaj prikaz</span>
          </div>
          <div class="kadr-shortcut-row">
            <kbd>Esc</kbd>
            <span>Zatvori najgornji modal</span>
          </div>
          <div class="kadr-shortcut-row">
            <kbd>Esc</kbd> <kbd>Esc</kbd>
            <span>Iz textarea sa tekstom — prvo blur, drugo zatvori</span>
          </div>
        </div>
        <div class="kadr-modal-actions">
          <button type="button" class="btn btn-primary" id="kadrShortcutsClose">U redu</button>
        </div>
      </div>
    </div>`;
  document.body.appendChild(wrap.firstElementChild);
  const modal = document.getElementById(HELP_MODAL_ID);
  modal.querySelector('#kadrShortcutsClose').addEventListener('click', closeHelp);
  modal.addEventListener('click', e => { if (e.target === modal) closeHelp(); });
}

function closeHelp() {
  document.getElementById(HELP_MODAL_ID)?.remove();
}

function onKeyDown(ev) {
  if (hasModifier(ev)) return;
  const key = ev.key;

  /* `/` uvek hvata — fokus na pretragu (osim ako je već u njoj). */
  if (key === '/') {
    if (isTypingTarget(ev)) {
      /* Ne hvataj kad korisnik kuca u textarea/input — pusti normalan unos. */
      return;
    }
    const inp = findVisibleSearch();
    if (inp) {
      ev.preventDefault();
      inp.focus();
      inp.select?.();
    }
    return;
  }

  /* Ostali shortcut-i se ne aktiviraju kad korisnik kuca. */
  if (isTypingTarget(ev)) return;

  if (key === '?' || (key === '/' && ev.shiftKey)) {
    ev.preventDefault();
    openHelp();
    return;
  }
  if (key === 'n' || key === 'N') {
    const btn = findVisibleNewButton();
    if (btn) {
      ev.preventDefault();
      btn.click();
    }
    return;
  }
  if (key === 'r' || key === 'R') {
    const btn = findVisibleReload();
    if (btn) {
      ev.preventDefault();
      btn.click();
    }
    return;
  }
}

export function installKeyboardShortcuts() {
  if (_installed) return;
  _installed = true;
  document.addEventListener('keydown', onKeyDown);
}
