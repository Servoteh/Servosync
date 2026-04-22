/**
 * Plan Montaže — modal „Veza sa crtežima“ za jednu fazu.
 *
 * Edituje `phase.linkedDrawings` (niz stringova `drawing_no`) — perzistira
 * kroz postojeći debounced save queue (`updatePhaseField` → `queuePhaseSaveByIndex`).
 *
 * Sadržaj:
 *   - Sekcija A: trenutno povezani crteži (klik = otvori PDF u novom tabu;
 *     ✖ = ukloni; ⚠ ako broj nije u `bigtehn_drawings_cache`).
 *   - Sekcija B (samo `canEdit()`):
 *       B1: dropdown svih crteža RN-a tog WP-a (filtrirano: bez već dodatih).
 *       B2: ručni unos broja crteža (fallback).
 *   - Footer: Sačuvaj / Otkaži. Save se okida i pri close-u ako je bilo
 *     izmena (preventDataLoss pattern).
 *
 * Read-only za uloge sa `canEdit() === false` (`hr`, `viewer`):
 *   - Mogu da kliknu broj i otvore PDF
 *   - Sekcija B nije renderovana, dugme "Sačuvaj" ne postoji.
 *
 * Koristi shared sloj `services/drawings.js` — bez duplikata sa modulom
 * "Praćenje proizvodnje".
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { canEdit } from '../../state/auth.js';
import {
  getActivePhases,
  getActiveWP,
  getCachedDrawingsForWP,
} from '../../state/planMontaze.js';
import {
  openDrawingPdf,
  getDrawingByNumber,
} from '../../services/drawings.js';
import { updatePhaseField } from './planActions.js';

let _overlayEl = null;
let _onEscBound = null;

/**
 * Otvori modal za jednu fazu.
 * @param {number} phaseIndex  Indeks faze u aktivnom WP-u.
 * @param {Function} [onSaved] Pozove se posle „Sačuvaj“ (rerender).
 */
export function openLinkedDrawingsDialog(phaseIndex, onSaved) {
  closeLinkedDrawingsDialog();
  const phases = getActivePhases();
  const phase = phases[phaseIndex];
  const wp = getActiveWP();
  if (!phase || !wp) return;

  const editable = canEdit();

  /* Lokalna radna kopija — ne piši direktno u state dok korisnik ne klikne
     Sačuvaj. Ako se zatvori bez Sačuvaj, sve promene se odbacuju. */
  const initial = Array.isArray(phase.linkedDrawings) ? phase.linkedDrawings.slice() : [];
  const work = {
    list: initial.slice(),
    initial,
    /* Lookup metapodataka: drawing_no -> { drawing_no, file_name, ... } | null  */
    metaByNo: new Map(),
    /* Spisak svih crteža RN-a (za dropdown). */
    rnDrawings: [],
    rnLoading: true,
    rnError: null,
  };

  _overlayEl = document.createElement('div');
  _overlayEl.className = 'modal-overlay open';
  _overlayEl.innerHTML = _shellHtml(phase, wp, editable);
  document.body.appendChild(_overlayEl);

  /* Wire close interakcije */
  _overlayEl.querySelectorAll('[data-ld-action="close"]').forEach(b => {
    b.addEventListener('click', () => _attemptClose(work, phaseIndex));
  });
  _overlayEl.addEventListener('click', (ev) => {
    if (ev.target === _overlayEl) _attemptClose(work, phaseIndex);
  });
  _onEscBound = (ev) => {
    if (ev.key === 'Escape') _attemptClose(work, phaseIndex);
  };
  document.addEventListener('keydown', _onEscBound);

  /* Save */
  _overlayEl.querySelector('[data-ld-action="save"]')?.addEventListener('click', () => {
    _commitAndClose(work, phaseIndex, onSaved);
  });

  /* Sekcija B (samo edit) */
  if (editable) {
    _overlayEl.querySelector('[data-ld-action="add-from-rn"]')?.addEventListener('click', () => {
      const sel = _overlayEl.querySelector('#ldRnSelect');
      const v = String(sel?.value || '').trim();
      if (!v) { showToast('⚠ Izaberi crtež iz liste'); return; }
      _addDrawing(work, v);
      _renderList(work, editable);
      _renderRnSection(work);
    });
    _overlayEl.querySelector('[data-ld-action="add-manual"]')?.addEventListener('click', () => {
      _onManualAdd(work, editable);
    });
    _overlayEl.querySelector('#ldManualInput')?.addEventListener('keydown', (ev) => {
      if (ev.key === 'Enter') {
        ev.preventDefault();
        _onManualAdd(work, editable);
      }
    });
  }

  /* Inicijalni render: liste + lookup metadata + RN dropdown */
  _renderList(work, editable);
  _hydrateMetaForList(work, editable);
  _loadRnDrawings(work, editable);
}

export function closeLinkedDrawingsDialog() {
  if (_onEscBound) {
    document.removeEventListener('keydown', _onEscBound);
    _onEscBound = null;
  }
  if (_overlayEl?.parentNode) _overlayEl.parentNode.removeChild(_overlayEl);
  _overlayEl = null;
}

/* ── Internal: shell ──────────────────────────────────────────────────── */

function _shellHtml(phase, wp, editable) {
  const title = phase.name || 'Faza';
  return `
    <div class="modal-panel ld-panel" role="dialog" aria-label="Veza sa crtežima">
      <div class="modal-head">
        <div>
          <h3>🔗 Veza sa crtežima — ${escHtml(title)}</h3>
          <div class="ld-subtitle">Radni nalog: <strong>${escHtml(wp.rnCode || '—')}</strong></div>
        </div>
        <button type="button" class="modal-close" data-ld-action="close" aria-label="Zatvori">✕</button>
      </div>
      <div class="modal-body">
        <section class="ld-section">
          <div class="ld-section-title">Trenutno povezani crteži</div>
          <div id="ldList" class="ld-list">
            <div class="ld-empty">⏳ Učitavam…</div>
          </div>
        </section>

        ${editable ? `
        <section class="ld-section">
          <div class="ld-section-title">Dodaj crtež iz radnog naloga</div>
          <div id="ldRnSection" class="ld-rn-section">
            <div class="ld-empty">⏳ Učitavam crteže RN-a…</div>
          </div>
        </section>

        <section class="ld-section">
          <div class="ld-section-title">…ili ručno unesi broj crteža</div>
          <div class="ld-manual-row">
            <input type="text" id="ldManualInput" class="ld-manual-input" placeholder="npr. SC-12345" maxlength="120" autocomplete="off">
            <button type="button" class="btn" data-ld-action="add-manual">＋ Dodaj ručno</button>
          </div>
          <p class="form-hint" style="margin:4px 0 0">Crtež koji nije u BigTehn-u dozvoljen je, ali će biti označen ⚠ dok se ne sinhronizuje.</p>
        </section>
        ` : `
        <p class="form-hint">🔒 Pregled — kao ${escHtml(_roleLabel())}, ne možeš da menjaš listu crteža. Klik na broj otvara PDF.</p>
        `}
      </div>
      <div class="modal-foot">
        <button type="button" class="btn btn-ghost" data-ld-action="close">${editable ? 'Otkaži' : 'Zatvori'}</button>
        ${editable ? '<button type="button" class="btn btn-primary" data-ld-action="save">💾 Sačuvaj</button>' : ''}
      </div>
    </div>
  `;
}

function _roleLabel() {
  /* Kratki label samo za vizuelni hint (ne procena role-a). */
  return 'pregledni korisnik';
}

/* ── Internal: render lista trenutno povezanih ─────────────────────────── */

function _renderList(work, editable) {
  if (!_overlayEl) return;
  const host = _overlayEl.querySelector('#ldList');
  if (!host) return;
  if (!work.list.length) {
    host.innerHTML = '<div class="ld-empty">Još nije povezan nijedan crtež.</div>';
    return;
  }
  host.innerHTML = work.list.map(no => _itemHtml(no, work.metaByNo.get(no), editable)).join('');
  /* Wire actions */
  host.querySelectorAll('[data-ld-row-action]').forEach(btn => {
    btn.addEventListener('click', (ev) => {
      ev.preventDefault();
      ev.stopPropagation();
      const action = btn.dataset.ldRowAction;
      const no = btn.dataset.ldNo;
      if (!no) return;
      if (action === 'open') {
        const meta = work.metaByNo.get(no);
        if (meta === null) {
          showToast('Crtež nije dostupan');
          return;
        }
        openDrawingPdf(no);
      } else if (action === 'remove') {
        if (!editable) return;
        _removeDrawing(work, no);
        _renderList(work, editable);
        _renderRnSection(work);
      }
    });
  });
}

function _itemHtml(no, meta, editable) {
  /* meta states:
   *   undefined → još učitavamo (spinner)
   *   null      → ne postoji u cache-u (warning)
   *   object    → ok, prikaži file_name */
  let nameHtml;
  let warnCls = '';
  if (meta === undefined) {
    nameHtml = '<span class="ld-meta-loading">⏳…</span>';
  } else if (meta === null) {
    nameHtml = '<span class="ld-meta-warn">⚠ crtež nije u bazi — proveri broj</span>';
    warnCls = ' ld-row-warn';
  } else {
    nameHtml = `<span class="ld-meta-name" title="${escHtml(meta.file_name || '')}">${escHtml(meta.file_name || '')}</span>`;
  }
  const removeBtn = editable
    ? `<button type="button" class="ld-btn-remove" data-ld-row-action="remove" data-ld-no="${escHtml(no)}" title="Ukloni">✖</button>`
    : '';
  return `
    <div class="ld-row${warnCls}">
      <button type="button" class="ld-no-btn" data-ld-row-action="open" data-ld-no="${escHtml(no)}" title="Otvori PDF u novom tabu">
        <span class="ld-no-code">${escHtml(no)}</span>
        ${nameHtml}
      </button>
      <button type="button" class="ld-btn-open" data-ld-row-action="open" data-ld-no="${escHtml(no)}" title="Otvori PDF">📄</button>
      ${removeBtn}
    </div>
  `;
}

/* Lazy-fetch metapodataka za sve trenutno povezane brojeve. */
async function _hydrateMetaForList(work, editable) {
  /* Skupi sve no koje još nemaju lookup. */
  const todo = work.list.filter(no => !work.metaByNo.has(no));
  for (const no of todo) {
    /* Marker da je u toku → undefined → koristi placeholder */
    /* (u Map: nepostojeci je == undefined; ostavimo). */
    try {
      const meta = await getDrawingByNumber(no);
      /* Ako je modal u međuvremenu zatvoren ili lista promenjena, ipak upiši
         u Map — koristiće sledeći put. */
      work.metaByNo.set(no, meta || null);
    } catch (e) {
      console.warn('[linkedDrawings] getDrawingByNumber', no, e);
      work.metaByNo.set(no, null);
    }
    if (_overlayEl) _renderList(work, editable);
  }
}

/* ── Internal: RN drawings (Sekcija B1) ────────────────────────────────── */

async function _loadRnDrawings(work, editable) {
  if (!editable) return;
  const wp = getActiveWP();
  if (!wp) return;
  try {
    work.rnDrawings = await getCachedDrawingsForWP(wp.id);
    work.rnLoading = false;
    /* Popuni metaByNo i za sve RN drawing-e (free, već imamo file_name). */
    for (const d of work.rnDrawings) {
      if (d?.drawing_no && !work.metaByNo.has(d.drawing_no)) {
        work.metaByNo.set(d.drawing_no, d);
      }
    }
  } catch (e) {
    console.error('[linkedDrawings] loadRnDrawings', e);
    work.rnLoading = false;
    work.rnError = String(e?.message || e);
  }
  _renderList(work, editable);
  _renderRnSection(work);
}

function _renderRnSection(work) {
  if (!_overlayEl) return;
  const host = _overlayEl.querySelector('#ldRnSection');
  if (!host) return;
  if (work.rnLoading) {
    host.innerHTML = '<div class="ld-empty">⏳ Učitavam crteže RN-a…</div>';
    return;
  }
  if (work.rnError) {
    host.innerHTML = `<div class="ld-empty ld-error">⚠ Greška: ${escHtml(work.rnError)}</div>`;
    return;
  }
  if (!work.rnDrawings.length) {
    host.innerHTML = '<div class="ld-empty">Nema crteža za ovaj RN u BigTehn-u (ili RN nije popunjen). Koristi ručni unos ispod.</div>';
    return;
  }
  /* Filtriraj već dodate. */
  const taken = new Set(work.list);
  const available = work.rnDrawings.filter(d => d?.drawing_no && !taken.has(d.drawing_no));
  if (!available.length) {
    host.innerHTML = '<div class="ld-empty">Svi crteži ovog RN-a su već u listi iznad.</div>';
    return;
  }
  host.innerHTML = `
    <div class="ld-rn-row">
      <select id="ldRnSelect" class="ld-rn-select">
        <option value="">— izaberi crtež —</option>
        ${available.map(d => {
          const lbl = d.file_name ? `${d.drawing_no} — ${d.file_name}` : d.drawing_no;
          return `<option value="${escHtml(d.drawing_no)}">${escHtml(lbl)}</option>`;
        }).join('')}
      </select>
      <button type="button" class="btn" data-ld-action="add-from-rn">＋ Dodaj</button>
    </div>
  `;
  /* Wire add (button moved fresh — re-attach handler since whole HTML re-rendered) */
  host.querySelector('[data-ld-action="add-from-rn"]')?.addEventListener('click', () => {
    const sel = host.querySelector('#ldRnSelect');
    const v = String(sel?.value || '').trim();
    if (!v) { showToast('⚠ Izaberi crtež iz liste'); return; }
    _addDrawing(work, v);
    _renderList(work, /*editable*/ true);
    _renderRnSection(work);
  });
}

/* ── Internal: state mutators ─────────────────────────────────────────── */

function _addDrawing(work, no) {
  const v = String(no || '').trim();
  if (!v) return;
  if (work.list.includes(v)) {
    showToast('Crtež je već u listi');
    return;
  }
  work.list.push(v);
  /* Ako još nemamo lookup, asinhrono ga doteraj. */
  if (!work.metaByNo.has(v)) {
    getDrawingByNumber(v).then(meta => {
      work.metaByNo.set(v, meta || null);
      if (!meta) showToast('⚠ Broj nije u BigTehn-u — sačuvano kao kandidat');
      _renderList(work, true);
    }).catch(() => {
      work.metaByNo.set(v, null);
      _renderList(work, true);
    });
  }
}

function _removeDrawing(work, no) {
  const i = work.list.indexOf(no);
  if (i >= 0) work.list.splice(i, 1);
}

function _onManualAdd(work, editable) {
  if (!editable) return;
  const inp = _overlayEl?.querySelector('#ldManualInput');
  const raw = String(inp?.value || '').trim();
  if (!raw) { showToast('⚠ Unesi broj crteža'); inp?.focus(); return; }
  _addDrawing(work, raw);
  if (inp) inp.value = '';
  _renderList(work, editable);
  _renderRnSection(work);
}

/* ── Internal: save / close ───────────────────────────────────────────── */

function _hasChanges(work) {
  if (work.list.length !== work.initial.length) return true;
  for (let i = 0; i < work.list.length; i++) {
    if (work.list[i] !== work.initial[i]) return true;
  }
  return false;
}

function _commitAndClose(work, phaseIndex, onSaved) {
  if (!canEdit()) {
    closeLinkedDrawingsDialog();
    return;
  }
  if (_hasChanges(work)) {
    /* `updatePhaseField` validira canEdit, persistira u localStorage i okida
       debounced Supabase save kroz `queuePhaseSaveByIndex(i)`. */
    updatePhaseField(phaseIndex, 'linkedDrawings', work.list.slice());
    showToast('💾 Sačuvano');
  }
  closeLinkedDrawingsDialog();
  onSaved?.();
}

function _attemptClose(work, _phaseIndex) {
  if (canEdit() && _hasChanges(work)) {
    if (!confirm('Imaš nesnimljene promene. Odbaci ih?')) return;
  }
  closeLinkedDrawingsDialog();
}
