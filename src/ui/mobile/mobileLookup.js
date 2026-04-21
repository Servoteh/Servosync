/**
 * Mobilni ekran "Pretraga po broju crteža".
 *
 * Use-case: magacioner / viljuškarista ima neki komad u ruci i traži gde
 * već postoji drugi komad istog crteža (ili ako je crtež već negde smešten).
 * Jedan crtež može biti na VIŠE lokacija istovremeno — vidi
 * `loc_item_placements` unique constraint `(item_ref_table, item_ref_id,
 * order_no, location_id)` iz `sql/migrations/add_loc_v3_order_scope.sql`.
 *
 * Rezultat je lista kartica (mobile scroll), ne tabela. Svaka kartica pokazuje:
 *   • broj crteža + broj naloga (order_no)
 *   • lokacija: HALA › POLICA (s oznakom tipa)
 *   • količina
 *   • vreme poslednje izmene ("pre 4 min" / "pre 2d")
 *
 * Pretraga radi 2-fazno (vidi `fetchPlacementsByDrawing` u services/lokacije.js):
 *   1. Direktni match `item_ref_id ILIKE *X*` (short format nalepnica — crtež
 *      je item_ref_id direktno).
 *   2. Indirektni: `loc_location_movements.note ILIKE '*Crtež:X*'` (RNZ format
 *      nalepnica — crtež je zakopan u movement.note jer u RNZ-u item_ref_id je
 *      TP broj, ne crtež).
 *
 * Ruta: `/m/lookup` (vidi `src/lib/appPaths.js`).
 */

import { escHtml } from '../../lib/dom.js';
import {
  fetchPlacementsByDrawing,
  fetchLocations,
  resolveDrawingNoForPlacement,
} from '../../services/lokacije.js';

/** Tipovi koje UI tretira kao "POLICA" (konkretno fizičko mesto na polici). */
const SHELF_TYPES = new Set(['SHELF', 'RACK', 'BIN']);
/** Tipovi koje UI tretira kao "HALA" (veći prostor, root ili intermedijar). */
const HALL_TYPES = new Set(['WAREHOUSE', 'PRODUCTION', 'ASSEMBLY', 'FIELD', 'TEMP']);

function fmtAgo(iso) {
  if (!iso) return '';
  const then = new Date(iso).getTime();
  const now = Date.now();
  const sec = Math.max(0, Math.floor((now - then) / 1000));
  if (sec < 60) return `pre ${sec}s`;
  const min = Math.floor(sec / 60);
  if (min < 60) return `pre ${min} min`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return `pre ${hr}h`;
  const d = Math.floor(hr / 24);
  if (d < 30) return `pre ${d}d`;
  return new Date(iso).toLocaleDateString('sr-RS');
}

function fmtDate(iso) {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString('sr-RS', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return iso;
  }
}

/**
 * Za placement → vrati par (hallLabel, shelfLabel). Ako je placement direktno
 * na HALI (parent_id NULL i tip iz HALL_TYPES), shelfLabel je prazan.
 */
function resolveLocPath(loc, locMap) {
  if (!loc) return { hall: '—', shelf: '', kind: 'unknown' };
  const type = String(loc.location_type || '').toUpperCase();
  if (SHELF_TYPES.has(type)) {
    /* Polica — hala je parent (ako postoji). */
    const parent = loc.parent_id ? locMap.get(loc.parent_id) : null;
    const hall = parent
      ? `${parent.location_code} — ${parent.name || ''}`.trim()
      : '—';
    const shelf = `${loc.location_code} — ${loc.name || ''}`.trim();
    return { hall, shelf, kind: 'shelf' };
  }
  if (HALL_TYPES.has(type)) {
    const hall = `${loc.location_code} — ${loc.name || ''}`.trim();
    return { hall, shelf: '', kind: 'hall' };
  }
  /* Ostali specijalni tipovi (SCRAPPED, OFFICE, ...) — pokaži kao-jeste. */
  const label = `${loc.location_code} — ${loc.name || ''}`.trim();
  return { hall: label, shelf: '', kind: 'other' };
}

/**
 * @param {HTMLElement} mountEl
 * @param {{ onNavigate: (path: string) => void }} ctx
 */
export async function renderMobileLookup(mountEl, ctx) {
  document.body.classList.add('m-body');
  mountEl.innerHTML = `
    <div class="m-shell">
      <header class="m-header">
        <button type="button" class="m-btn-ghost" data-act="back" aria-label="Nazad">←</button>
        <div class="m-brand">
          <div class="m-brand-title">PRETRAGA PO CRTEŽU</div>
          <div class="m-brand-sub">gde se nalazi neki crtež</div>
        </div>
        <span class="m-btn-ghost" style="opacity:0;pointer-events:none">·</span>
      </header>

      <main class="m-main m-lookup-main">
        <form class="m-lookup-form" id="mLookupForm" autocomplete="off">
          <label class="m-field-label" for="mLookupInput">Broj crteža</label>
          <div class="m-lookup-row">
            <input type="search" class="m-lookup-input" id="mLookupInput"
                   inputmode="search" autocapitalize="characters" autocorrect="off"
                   placeholder="npr. 1130927" enterkeyhint="search" />
            <button type="submit" class="m-lookup-submit">Traži</button>
          </div>
          <div class="m-lookup-hint">Pretražuje se i direktno (item ref) i u notama (RNZ format).</div>
        </form>

        <div id="mLookupResults" class="m-lookup-results">
          <div class="m-empty">
            <div class="m-empty-ico">🔎</div>
            <div class="m-empty-title">Unesi broj crteža</div>
            <div class="m-empty-sub">Dovoljno i par poslednjih cifara — pokazujemo sve lokacije gde se taj crtež trenutno nalazi.</div>
          </div>
        </div>
      </main>
    </div>
  `;

  const form = mountEl.querySelector('#mLookupForm');
  const input = /** @type {HTMLInputElement} */ (mountEl.querySelector('#mLookupInput'));
  const resultsEl = mountEl.querySelector('#mLookupResults');
  const goBack = () => ctx.onNavigate('/m');

  mountEl.addEventListener('click', ev => {
    const act = ev.target.closest('[data-act]')?.dataset?.act;
    if (act === 'back') goBack();
  });

  form.addEventListener('submit', ev => {
    ev.preventDefault();
    void runSearch();
  });

  /* Pokreni pretragu nakon 500ms neaktivnosti (magacioner retko unosi dugo). */
  let debounceTimer = null;
  input.addEventListener('input', () => {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => void runSearch(), 500);
  });

  /* Pre-fill iz ?q=... query param-a (deep link iz scan toast-a, npr.). */
  try {
    const params = new URLSearchParams(window.location.search);
    const prefill = params.get('q');
    if (prefill) {
      input.value = prefill;
      setTimeout(() => void runSearch(), 0);
    } else {
      setTimeout(() => input.focus(), 150);
    }
  } catch {
    /* no-op */
  }

  async function runSearch() {
    const q = input.value.trim();
    if (q.length < 2) {
      resultsEl.innerHTML = `
        <div class="m-empty">
          <div class="m-empty-ico">🔎</div>
          <div class="m-empty-title">Unesi broj crteža</div>
          <div class="m-empty-sub">Minimalno 2 karaktera za pretragu.</div>
        </div>
      `;
      return;
    }
    resultsEl.innerHTML = `<div class="m-loading-dot"></div>`;

    let placements;
    let locs;
    try {
      [placements, locs] = await Promise.all([
        fetchPlacementsByDrawing(q),
        fetchLocationsCached(),
      ]);
    } catch (e) {
      console.error('[mobile/lookup] fetch failed', e);
      resultsEl.innerHTML = `
        <div class="m-empty">
          <div class="m-empty-ico">⚠</div>
          <div class="m-empty-title">Greška pri pretrazi</div>
          <div class="m-empty-sub">${escHtml((e && e.message) || String(e))}</div>
        </div>
      `;
      return;
    }

    if (!Array.isArray(placements) || placements.length === 0) {
      resultsEl.innerHTML = `
        <div class="m-empty">
          <div class="m-empty-ico">🙈</div>
          <div class="m-empty-title">Nema rezultata</div>
          <div class="m-empty-sub">Crtež "${escHtml(q)}" nije smešten ni na jednoj lokaciji. Možda je otišao u proizvodnju ili je već ugrađen.</div>
        </div>
      `;
      return;
    }

    const locMap = new Map((locs || []).map(l => [l.id, l]));

    /* Pokušaj da rešiš tačan broj crteža za svaki placement (korisno ako je
     * user upisao "130927" a taj broj je u item_ref_id kao "1130927" — ipak
     * ih prikažemo jer je ilike match). Ako nema, pad u placement.item_ref_id. */
    const resolvedDrawings = await Promise.all(
      placements.map(p => resolveDrawingNoForPlacement(p).catch(() => null)),
    );

    /* Grupiši po HALI. U svakoj HALI imamo listu police+količina. */
    const byHall = new Map(); /* hallLabel → {hall, rows: [{placement, shelf, drawing}]} */
    placements.forEach((p, i) => {
      const loc = locMap.get(p.location_id);
      const path = resolveLocPath(loc, locMap);
      const bucket = byHall.get(path.hall) || { hall: path.hall, kind: path.kind, rows: [] };
      bucket.rows.push({
        placement: p,
        shelf: path.shelf,
        drawing: resolvedDrawings[i] || p.item_ref_id,
      });
      byHall.set(path.hall, bucket);
    });

    const totalQty = placements.reduce((s, p) => s + Number(p.quantity || 0), 0);
    const summary = `
      <div class="m-lookup-summary">
        <strong>${escHtml(String(placements.length))}</strong> ${placements.length === 1 ? 'lokacija' : placements.length < 5 ? 'lokacije' : 'lokacija'} ·
        ukupno <strong>${escHtml(String(totalQty))}</strong> kom
      </div>
    `;

    const hallsHtml = Array.from(byHall.values())
      .map(bucket => renderHallGroup(bucket))
      .join('');

    resultsEl.innerHTML = summary + hallsHtml;
  }

  function renderHallGroup(bucket) {
    const hallIco = bucket.kind === 'shelf' || bucket.kind === 'hall' ? '🏭' : '📦';
    const rows = bucket.rows
      .map(r => {
        const p = r.placement;
        const shelfHtml = r.shelf
          ? `<div class="m-lookup-shelf">📍 ${escHtml(r.shelf)}</div>`
          : '';
        const orderHtml = p.order_no
          ? `<span class="m-hist-order">nalog ${escHtml(p.order_no)}</span>`
          : '';
        const drawingHtml = r.drawing
          ? `<span class="m-hist-drawing">📐 ${escHtml(r.drawing)}</span>`
          : '';
        const statusBadge =
          p.placement_status && p.placement_status !== 'ACTIVE'
            ? `<span class="m-badge m-badge-warn">${escHtml(p.placement_status)}</span>`
            : '';
        return `
          <div class="m-lookup-card">
            <div class="m-hist-head">
              ${drawingHtml}
              ${orderHtml}
              ${statusBadge}
            </div>
            ${shelfHtml}
            <div class="m-lookup-meta">
              <span class="m-lookup-qty">${escHtml(String(p.quantity || 0))} kom</span>
              <span class="m-dot">·</span>
              <span title="${escHtml(fmtDate(p.updated_at))}">${escHtml(fmtAgo(p.updated_at))}</span>
            </div>
          </div>
        `;
      })
      .join('');
    return `
      <div class="m-lookup-hall">
        <div class="m-lookup-hall-head">${hallIco} ${escHtml(bucket.hall)}</div>
        ${rows}
      </div>
    `;
  }

  return {
    teardown() {
      document.body.classList.remove('m-body');
      mountEl.innerHTML = '';
    },
  };
}

/* ── Lokacije cache (lokalni, 10 min TTL) — iste ključeve koristi i history.js.
 * Ako se menja struktura, podigni verziju ključa. ─────────────────────────── */

const LOC_CACHE_KEY = 'm.locations.cache.v1';
const LOC_CACHE_TTL_MS = 10 * 60 * 1000;

async function fetchLocationsCached() {
  try {
    const raw = localStorage.getItem(LOC_CACHE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (parsed?.ts && Date.now() - parsed.ts < LOC_CACHE_TTL_MS && Array.isArray(parsed.rows)) {
        return parsed.rows;
      }
    }
  } catch {
    /* corrupted — ignoriši */
  }
  const rows = await fetchLocations();
  try {
    localStorage.setItem(LOC_CACHE_KEY, JSON.stringify({ ts: Date.now(), rows }));
  } catch {
    /* quota — ignoriši */
  }
  return rows;
}
