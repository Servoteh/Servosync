/**
 * Plan Montaže — modal „Glavni crtež sklopa" za ceo WP (nalog montaže).
 *
 * Razlika u odnosu na `linkedDrawingsDialog.js`:
 *   - Ovaj modal čuva JEDAN broj crteža (`work_packages.assembly_drawing_no`),
 *     a ne niz. Predstavlja glavni crtež celog sklopa/podsklopa za WP/RN.
 *   - Save ide kroz `saveWorkPackageToDb` (a ne kroz phase queue).
 *
 * Sadržaj modala:
 *   - Sekcija A: trenutno postavljen crtež (klik = otvori PDF; ✖ = ukloni;
 *     ⚠ ako broj nije u `bigtehn_drawings_cache`).
 *   - Sekcija B (samo `canEdit()`):
 *       B1: dropdown svih crteža RN-a tog WP-a (ne filtriramo — uvek prikazujemo
 *           sve da korisnik može da promeni izbor).
 *       B2: ručni unos broja crteža (fallback).
 *   - Footer: Sačuvaj / Otkaži. preventDataLoss pri close-u sa nesnimljenim
 *     promenama.
 *
 * Read-only (`canEdit() === false`): može da klikne na broj i otvori PDF,
 * ne vidi sekcije za izmenu.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { canEdit } from '../../state/auth.js';
import {
  getActiveProject,
  getActiveWP,
  getCachedDrawingsForWP,
  persistState,
} from '../../state/planMontaze.js';
import {
  openDrawingPdf,
  getDrawingByNumber,
} from '../../services/drawings.js';
import { saveWorkPackageToDb } from '../../services/projects.js';

let _overlayEl = null;
let _onEscBound = null;

/**
 * Otvori modal za aktivni WP.
 * @param {Function} [onSaved] Pozove se posle „Sačuvaj" (rerender shell-a).
 */
export function openWpAssemblyDrawingDialog(onSaved) {
  closeWpAssemblyDrawingDialog();
  const wp = getActiveWP();
  if (!wp) return;

  const editable = canEdit();
  const initial = String(wp.assemblyDrawingNo || '').trim();

  /* Lokalna radna kopija — direktno se ne menja state dok korisnik ne klikne
     Sačuvaj. Otkazom se promene odbacuju. */
  const work = {
    current: initial,
    initial,
    /* Lookup metapodataka: drawing_no -> { ... } | null  */
    metaByNo: new Map(),
    /* Spisak svih crteža RN-a (za dropdown). */
    rnDrawings: [],
    rnLoading: true,
    rnError: null,
  };

  _overlayEl = document.createElement('div');
  _overlayEl.className = 'modal-overlay open';
  _overlayEl.innerHTML = _shellHtml(wp, editable);
  document.body.appendChild(_overlayEl);

  /* Wire close interakcije */
  _overlayEl.querySelectorAll('[data-wad-action="close"]').forEach(b => {
    b.addEventListener('click', () => _attemptClose(work));
  });
  _overlayEl.addEventListener('click', (ev) => {
    if (ev.target === _overlayEl) _attemptClose(work);
  });
  _onEscBound = (ev) => {
    if (ev.key === 'Escape') _attemptClose(work);
  };
  document.addEventListener('keydown', _onEscBound);

  /* Save */
  _overlayEl.querySelector('[data-wad-action="save"]')?.addEventListener('click', () => {
    _commitAndClose(work, onSaved);
  });

  /* Sekcija B (samo edit) */
  if (editable) {
    _overlayEl.querySelector('[data-wad-action="set-from-rn"]')?.addEventListener('click', () => {
      const sel = _overlayEl.querySelector('#wadRnSelect');
      const v = String(sel?.value || '').trim();
      if (!v) { showToast('⚠ Izaberi crtež iz liste'); return; }
      _setDrawing(work, v);
      _renderCurrent(work, editable);
      _renderRnSection(work);
    });
    _overlayEl.querySelector('[data-wad-action="set-manual"]')?.addEventListener('click', () => {
      _onManualSet(work, editable);
    });
    _overlayEl.querySelector('#wadManualInput')?.addEventListener('keydown', (ev) => {
      if (ev.key === 'Enter') {
        ev.preventDefault();
        _onManualSet(work, editable);
      }
    });
  }

  _renderCurrent(work, editable);
  _hydrateMetaForCurrent(work, editable);
  _loadRnDrawings(work, editable);
}

export function closeWpAssemblyDrawingDialog() {
  if (_onEscBound) {
    document.removeEventListener('keydown', _onEscBound);
    _onEscBound = null;
  }
  if (_overlayEl?.parentNode) _overlayEl.parentNode.removeChild(_overlayEl);
  _overlayEl = null;
}

/* ── Internal: shell ──────────────────────────────────────────────────── */

function _shellHtml(wp, editable) {
  return `
    <div class="modal-panel ld-panel" role="dialog" aria-label="Glavni crtež sklopa">
      <div class="modal-head">
        <div>
          <h3>🔗 Glavni crtež sklopa — ${escHtml(wp.name || 'Pozicija')}</h3>
          <div class="ld-subtitle">Radni nalog: <strong>${escHtml(wp.rnCode || '—')}</strong> · jedan crtež za <em>ceo</em> sklop/podsklop</div>
        </div>
        <button type="button" class="modal-close" data-wad-action="close" aria-label="Zatvori">✕</button>
      </div>
      <div class="modal-body">
        <section class="ld-section">
          <div class="ld-section-title">Trenutni crtež sklopa</div>
          <div id="wadCurrent" class="ld-list">
            <div class="ld-empty">⏳ Učitavam…</div>
          </div>
        </section>

        ${editable ? `
        <section class="ld-section">
          <div class="ld-section-title">Izaberi crtež iz radnog naloga</div>
          <div id="wadRnSection" class="ld-rn-section">
            <div class="ld-empty">⏳ Učitavam crteže RN-a…</div>
          </div>
        </section>

        <section class="ld-section">
          <div class="ld-section-title">…ili ručno unesi broj crteža</div>
          <div class="ld-manual-row">
            <input type="text" id="wadManualInput" class="ld-manual-input" placeholder="npr. SC-12345" maxlength="120" autocomplete="off">
            <button type="button" class="btn" data-wad-action="set-manual">✎ Postavi ručno</button>
          </div>
          <p class="form-hint" style="margin:4px 0 0">Crtež koji nije u BigTehn-u dozvoljen je, ali će biti označen ⚠ dok se ne sinhronizuje.</p>
        </section>
        ` : `
        <p class="form-hint">🔒 Pregled — nemaš dozvolu za izmenu glavnog crteža sklopa. Klik na broj otvara PDF.</p>
        `}
      </div>
      <div class="modal-foot">
        <button type="button" class="btn btn-ghost" data-wad-action="close">${editable ? 'Otkaži' : 'Zatvori'}</button>
        ${editable ? '<button type="button" class="btn btn-primary" data-wad-action="save">💾 Sačuvaj</button>' : ''}
      </div>
    </div>
  `;
}

/* ── Internal: render trenutni izabrani crtež ─────────────────────────── */

function _renderCurrent(work, editable) {
  if (!_overlayEl) return;
  const host = _overlayEl.querySelector('#wadCurrent');
  if (!host) return;
  const no = work.current;
  if (!no) {
    host.innerHTML = '<div class="ld-empty">Još nije postavljen glavni crtež sklopa.</div>';
    return;
  }
  host.innerHTML = _itemHtml(no, work.metaByNo.get(no), editable);
  /* Wire actions */
  host.querySelectorAll('[data-wad-row-action]').forEach(btn => {
    btn.addEventListener('click', (ev) => {
      ev.preventDefault();
      ev.stopPropagation();
      const action = btn.dataset.wadRowAction;
      const n = btn.dataset.wadNo;
      if (!n) return;
      if (action === 'open') {
        const meta = work.metaByNo.get(n);
        if (meta === null) {
          showToast('Crtež nije dostupan');
          return;
        }
        openDrawingPdf(n);
      } else if (action === 'remove') {
        if (!editable) return;
        _setDrawing(work, '');
        _renderCurrent(work, editable);
        _renderRnSection(work);
      }
    });
  });
}

function _itemHtml(no, meta, editable) {
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
    ? `<button type="button" class="ld-btn-remove" data-wad-row-action="remove" data-wad-no="${escHtml(no)}" title="Ukloni">✖</button>`
    : '';
  return `
    <div class="ld-row${warnCls}">
      <button type="button" class="ld-no-btn" data-wad-row-action="open" data-wad-no="${escHtml(no)}" title="Otvori PDF u novom tabu">
        <span class="ld-no-code">${escHtml(no)}</span>
        ${nameHtml}
      </button>
      <button type="button" class="ld-btn-open" data-wad-row-action="open" data-wad-no="${escHtml(no)}" title="Otvori PDF">📄</button>
      ${removeBtn}
    </div>
  `;
}

async function _hydrateMetaForCurrent(work, editable) {
  if (!work.current || work.metaByNo.has(work.current)) return;
  try {
    const meta = await getDrawingByNumber(work.current);
    work.metaByNo.set(work.current, meta || null);
  } catch (e) {
    console.warn('[wpAssemblyDrawing] getDrawingByNumber', work.current, e);
    work.metaByNo.set(work.current, null);
  }
  if (_overlayEl) _renderCurrent(work, editable);
}

/* ── Internal: RN drawings (Sekcija B1) ────────────────────────────────── */

async function _loadRnDrawings(work, editable) {
  if (!editable) return;
  const wp = getActiveWP();
  if (!wp) return;
  try {
    work.rnDrawings = await getCachedDrawingsForWP(wp.id);
    work.rnLoading = false;
    for (const d of work.rnDrawings) {
      if (d?.drawing_no && !work.metaByNo.has(d.drawing_no)) {
        work.metaByNo.set(d.drawing_no, d);
      }
    }
  } catch (e) {
    console.error('[wpAssemblyDrawing] loadRnDrawings', e);
    work.rnLoading = false;
    work.rnError = String(e?.message || e);
  }
  _renderCurrent(work, editable);
  _renderRnSection(work);
}

function _renderRnSection(work) {
  if (!_overlayEl) return;
  const host = _overlayEl.querySelector('#wadRnSection');
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
  /* Single-select: ne filtriramo trenutni izbor — može da se promeni. */
  host.innerHTML = `
    <div class="ld-rn-row">
      <select id="wadRnSelect" class="ld-rn-select">
        <option value="">— izaberi crtež —</option>
        ${work.rnDrawings.map(d => {
          const sel = d.drawing_no === work.current ? ' selected' : '';
          const lbl = d.file_name ? `${d.drawing_no} — ${d.file_name}` : d.drawing_no;
          return `<option value="${escHtml(d.drawing_no)}"${sel}>${escHtml(lbl)}</option>`;
        }).join('')}
      </select>
      <button type="button" class="btn" data-wad-action="set-from-rn">✎ Postavi</button>
    </div>
  `;
  host.querySelector('[data-wad-action="set-from-rn"]')?.addEventListener('click', () => {
    const sel = host.querySelector('#wadRnSelect');
    const v = String(sel?.value || '').trim();
    if (!v) { showToast('⚠ Izaberi crtež iz liste'); return; }
    _setDrawing(work, v);
    _renderCurrent(work, /*editable*/ true);
    _renderRnSection(work);
  });
}

/* ── Internal: state mutators ─────────────────────────────────────────── */

function _setDrawing(work, no) {
  const v = String(no || '').trim();
  work.current = v;
  if (v && !work.metaByNo.has(v)) {
    getDrawingByNumber(v).then(meta => {
      work.metaByNo.set(v, meta || null);
      if (!meta) showToast('⚠ Broj nije u BigTehn-u — sačuvano kao kandidat');
      _renderCurrent(work, true);
    }).catch(() => {
      work.metaByNo.set(v, null);
      _renderCurrent(work, true);
    });
  }
}

function _onManualSet(work, editable) {
  if (!editable) return;
  const inp = _overlayEl?.querySelector('#wadManualInput');
  const raw = String(inp?.value || '').trim();
  if (!raw) { showToast('⚠ Unesi broj crteža'); inp?.focus(); return; }
  _setDrawing(work, raw);
  if (inp) inp.value = '';
  _renderCurrent(work, editable);
  _renderRnSection(work);
}

/* ── Internal: save / close ───────────────────────────────────────────── */

function _hasChanges(work) {
  return work.current !== work.initial;
}

function _commitAndClose(work, onSaved) {
  if (!canEdit()) {
    closeWpAssemblyDrawingDialog();
    return;
  }
  if (_hasChanges(work)) {
    const wp = getActiveWP();
    const proj = getActiveProject();
    if (wp && proj) {
      wp.assemblyDrawingNo = work.current;
      persistState();
      /* Save WP record sam (analogno meta-modal flow-u). */
      saveWorkPackageToDb(wp, proj.id).catch(e => {
        console.warn('[wpAssemblyDrawing] save failed', e);
        showToast('⚠ Greška pri snimanju glavnog crteža');
      });
      showToast('💾 Sačuvano');
    }
  }
  closeWpAssemblyDrawingDialog();
  onSaved?.();
}

function _attemptClose(work) {
  if (canEdit() && _hasChanges(work)) {
    if (!confirm('Imaš nesnimljene promene. Odbaci ih?')) return;
  }
  closeWpAssemblyDrawingDialog();
}
