/**
 * Štampa nalepnica za TP — zasebna stranica (/stampa-nalepnica).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { toggleTheme } from '../../lib/theme.js';
import { logout } from '../../services/auth.js';
import { getAuth } from '../../state/auth.js';
import {
  searchBigtehnItems,
  searchBigtehnWorkOrdersForItem,
} from '../../services/lokacije.js';
import { formatBigTehnRnzBarcode } from '../../lib/barcodeParse.js';
import {
  buildTechLabelHtmlBlock,
  printTechProcessLabelsBatch,
} from '../lokacije/labelsPrint.js';

const FETCH_LIMIT = 200;
const FIRST_PAGE = 20;
const MAX_QTY = 999;

function debounce(fn, ms) {
  let t = null;
  const w = (...a) => {
    clearTimeout(t);
    t = setTimeout(() => fn(...a), ms);
  };
  w.cancel = () => clearTimeout(t);
  return w;
}

function todayStrDDMMYY() {
  const d = new Date();
  const pad = n => String(n).padStart(2, '0');
  return `${pad(d.getDate())}-${pad(d.getMonth() + 1)}-${String(d.getFullYear()).slice(-2)}`;
}

const IC_BACK = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>`;
const IC_SEARCH = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>`;
const IC_PRINT = `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="6" y="14" width="12" height="8"/></svg>`;
const IC_TAG = `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2H2v10l9.29 9.29c.94.94 2.48.94 3.42 0l6.58-6.58c.94-.94.94-2.48 0-3.42L12 2"/><path d="M7 7h.01"/></svg>`;
const IC_BC = `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true"><path d="M4 7h2M4 12h1M4 17h3M8 7h1M8 12h2M8 17h1M12 7h3M12 13h2M12 17h1M16 7h1M16 12h2M16 17h3M19 7h1M19 12h1M19 17h1"/></svg>`;
const IC_EMPTY = `<svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="var(--text3,#9ca3af)" stroke-width="1.5" aria-hidden="true"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>`;

let teardownFn = null;

export function teardownStampaNalepnicaModule() {
  teardownFn?.();
  teardownFn = null;
}

/**
 * @param {HTMLElement} root
 * @param {{ onBackToHub: () => void, onLogout: () => void }} options
 */
export function renderStampaNalepnicaModule(root, { onBackToHub, onLogout } = {}) {
  teardownStampaNalepnicaModule();

  const auth = getAuth();
  if (!auth.user) {
    showToast('Prijavi se da otvoriš Štampa nalepnica');
    onBackToHub?.();
    return;
  }

  const wrap = document.createElement('div');
  wrap.className = 'sn-root kadrovska-section';
  wrap.innerHTML = `
    <header class="pb-header sn-top">
      <div class="pb-header-left">
        <button type="button" class="pb-back-btn" id="snHubBack" aria-label="Nazad na module">${IC_BACK} Moduli</button>
        <div class="pb-header-brand">
          <div class="pb-module-icon sn-ico-head" aria-hidden="true">${IC_PRINT}</div>
          <div>
            <div class="pb-header-title">Štampa nalepnica</div>
            <div class="pb-header-sub">Tehnološki postupak · RNZ</div>
          </div>
        </div>
      </div>
      <div class="pb-header-right">
        <button type="button" class="pb-theme-btn" id="snTheme" aria-label="Tema">🌙</button>
        ${auth.role ? `<span class="pb-role-badge">${escHtml(String(auth.role).toUpperCase())}</span>` : ''}
        <button type="button" class="pb-logout-btn" id="snLogout">Odjavi se</button>
      </div>
    </header>

    <main class="sn-page">
      <div class="sn-page-head-card">
        <div class="sn-page-head-main">
          <div class="sn-icon-square" aria-hidden="true">${IC_TAG}</div>
          <div>
            <h1>Štampa nalepnice za tehnološki postupak</h1>
            <p>Predmet → TP → količina · Barkod RNZ standard</p>
          </div>
        </div>
        <div class="sn-progress" id="snProgress" aria-hidden="true">
          <span class="sn-progress-step is-active" data-step="1"><span class="sn-progress-dot"></span> Predmet</span>
          <span aria-hidden="true">→</span>
          <span class="sn-progress-step" data-step="2"><span class="sn-progress-dot"></span> TP</span>
          <span aria-hidden="true">→</span>
          <span class="sn-progress-step" data-step="3"><span class="sn-progress-dot"></span> Količina</span>
        </div>
        <button type="button" class="sn-back-outline" id="snBackLok">${IC_BACK} Nazad</button>
      </div>

      <div class="sn-grid">
        <div class="sn-col-main">
          <section class="sn-step-card" id="snCard1">
            <h2 class="sn-step-label">1. Predmet</h2>
            <div class="sn-combo" id="snCombo">
              <div class="sn-combo-chip-row" id="snChipRow" hidden></div>
              <div class="sn-combo-input-wrap" id="snInputWrap">
                ${IC_SEARCH}
                <input type="search" id="snPredQ" class="sn-combo-input" placeholder="Pretraži predmet — broj, naziv, ugovor…" autocomplete="off" />
              </div>
              <div class="sn-dropdown" id="snDrop" aria-expanded="false"></div>
            </div>
            <span class="sn-hint">Lista uključuje samo nezatvorene predmete iz BigTehn-a (status „U TOKU")</span>
          </section>

          <section class="sn-step-card is-disabled" id="snCard2" style="display:none">
            <h2 class="sn-step-label is-muted" id="snLab2">2. Tehnološki postupak</h2>
            <p class="sn-placeholder-muted" id="snTpPlaceholder">Prvo odaberite predmet.</p>
            <div id="snTpBlock" style="display:none">
              <div class="sn-tp-search" id="snTpSearchWrap" style="display:none">
                <input type="search" id="snTpFilter" placeholder="Pretraži TP po RN, crtežu, nazivu dela…" autocomplete="off" />
              </div>
              <div class="sn-tp-list" id="snTpList" role="radiogroup"></div>
            </div>
          </section>

          <section class="sn-step-card is-disabled" id="snCard3" style="display:none">
            <h2 class="sn-step-label is-muted" id="snLab3">3. Količina nalepnica</h2>
            <div id="snQtyBlock" style="display:none">
              <div class="sn-qty-row">
                <div class="sn-qty-ctrl">
                  <button type="button" id="snQtyM" aria-label="Smanji">−</button>
                  <input type="number" id="snQty" min="1" max="${MAX_QTY}" step="1" value="1" inputmode="numeric" />
                  <button type="button" id="snQtyP" aria-label="Povećaj">+</button>
                </div>
              </div>
              <div class="sn-quick-chips" id="snQuick"></div>
            </div>
          </section>
        </div>

        <aside class="sn-col-side">
          <div class="sn-step-card sn-preview-card">
            <div class="sn-step-label">Preview nalepnice</div>
            <div class="sn-muted-size" style="font-size:0.75rem;color:var(--text3,#9ca3af);margin:-8px 0 8px">~ 80 × 38 mm</div>
            <div class="sn-preview-box">
              <div class="sn-preview-head">SERVOTEH · TP</div>
              <div class="sn-preview-scale" id="snPrevScale"></div>
            </div>
            <div class="sn-preview-hint" id="snPrevHint">Štampa će kreirati <strong>1</strong> kopiju</div>
          </div>
        </aside>
      </div>
    </main>

    <div class="sn-sticky">
      <button type="button" class="sn-link-reset" id="snReset">↻ Resetuj formu</button>
      <div class="sn-sticky-right">
        <button type="button" class="sn-btn-outline" id="snCancel">Otkaži</button>
        <button type="button" class="sn-btn-primary" id="snPrint" disabled>🖨 Štampaj 1 nalepnicu</button>
      </div>
    </div>`;

  root.appendChild(wrap);

  const qEl = wrap.querySelector('#snPredQ');
  const dropEl = wrap.querySelector('#snDrop');
  const chipRow = wrap.querySelector('#snChipRow');
  const inputWrap = wrap.querySelector('#snInputWrap');
  const card2 = wrap.querySelector('#snCard2');
  const card3 = wrap.querySelector('#snCard3');
  const lab2 = wrap.querySelector('#snLab2');
  const lab3 = wrap.querySelector('#snLab3');
  const tpPh = wrap.querySelector('#snTpPlaceholder');
  const tpBlock = wrap.querySelector('#snTpBlock');
  const tpSearchWrap = wrap.querySelector('#snTpSearchWrap');
  const tpFilter = wrap.querySelector('#snTpFilter');
  const tpListEl = wrap.querySelector('#snTpList');
  const qtyBlock = wrap.querySelector('#snQtyBlock');
  const qtyEl = wrap.querySelector('#snQty');
  const prevScale = wrap.querySelector('#snPrevScale');
  const prevHint = wrap.querySelector('#snPrevHint');
  const btnPrint = wrap.querySelector('#snPrint');
  const progressEl = wrap.querySelector('#snProgress');
  const quickHost = wrap.querySelector('#snQuick');

  /** @type {object|null} */
  let selectedPredmet = null;
  /** @type {object[]} */
  let tpsCache = [];
  /** @type {object|null} */
  let selectedTp = null;
  /** @type {object[]} */
  let predRows = [];
  let predLoading = false;
  let predExpanded = false;
  let dropOpen = false;
  let activeDdIndex = -1;
  let pendingSearch = '';

  const docClick = ev => {
    const combo = wrap.querySelector('#snCombo');
    if (combo && combo.contains(ev.target)) return;
    closeDrop();
  };

  function getPrintQty() {
    const n = Math.floor(Number(qtyEl.value) || 1);
    return Math.max(1, Math.min(MAX_QTY, n));
  }

  function setPrintQty(n) {
    qtyEl.value = String(Math.max(1, Math.min(MAX_QTY, Math.floor(Number(n) || 1))));
    paintQtyChips();
    refreshPreview();
  }

  function printLabelWord(n) {
    if (n === 1) return 'nalepnicu';
    if (n >= 2 && n <= 4) return 'nalepnice';
    return 'nalepnica';
  }

  function closeDrop() {
    dropOpen = false;
    dropEl.classList.remove('is-open');
    activeDdIndex = -1;
  }

  function openDrop() {
    dropOpen = true;
    dropEl.classList.add('is-open');
  }

  function paintProgress() {
    const s = !selectedPredmet ? 1 : !selectedTp ? 2 : 3;
    progressEl.querySelectorAll('.sn-progress-step').forEach(el => {
      const k = Number(el.getAttribute('data-step'));
      el.classList.toggle('is-active', k <= s);
    });
  }

  function paintQtyChips() {
    const v = getPrintQty();
    const vals = [1, 5, 10, 25, 50];
    quickHost.innerHTML = vals
      .map(
        n =>
          `<button type="button" class="sn-q-chip ${n === v ? 'is-active' : ''}" data-q="${n}">${n}</button>`,
      )
      .join('');
    quickHost.querySelectorAll('[data-q]').forEach(btn => {
      btn.addEventListener('click', () => setPrintQty(btn.getAttribute('data-q')));
    });
  }

  function syncStepCards() {
    if (selectedPredmet) {
      card2.style.display = '';
      card2.classList.remove('is-disabled');
      lab2.classList.remove('is-muted');
      tpPh.style.display = 'none';
      tpBlock.style.display = '';
    } else {
      card2.style.display = 'none';
      card3.style.display = 'none';
      return;
    }
    if (selectedTp) {
      card3.style.display = '';
      card3.classList.remove('is-disabled');
      lab3.classList.remove('is-muted');
      qtyBlock.style.display = '';
    } else {
      card3.style.display = 'none';
    }
  }

  function renderPredSkeleton() {
    dropEl.innerHTML = `<div class="sn-dd-scroll">${[1, 2, 3, 4]
      .map(() => '<div class="sn-dd-skel"><div class="sn-skel-line"></div><div class="sn-skel-line short"></div></div>')
      .join('')}</div>`;
    openDrop();
  }

  function renderPredDropdown() {
    dropEl._virtCleanup?.();
    dropEl._virtCleanup = null;
    if (predLoading) {
      renderPredSkeleton();
      return;
    }
    const rows = predRows;
    if (!rows.length) {
      dropEl.innerHTML = `<div class="sn-dd-empty">${IC_EMPTY}<div style="margin-top:8px">Nema predmeta koji odgovaraju pretrazi</div></div>`;
      openDrop();
      return;
    }
    const expanded = predExpanded;
    const showRows = expanded ? rows : rows.slice(0, FIRST_PAGE);
    const hasMore = rows.length > FIRST_PAGE && !expanded;

    const useVirt = showRows.length > 100;
    const outer = document.createElement('div');
    outer.className = 'sn-dd-scroll';
    let virtCleanup = null;

    if (useVirt) {
      const ROW_H = 52;
      const inner = document.createElement('div');
      inner.style.position = 'relative';
      inner.style.minHeight = `${showRows.length * ROW_H}px`;
      outer.appendChild(inner);
      const paint = () => {
        const h = outer.clientHeight || 280;
        const st = outer.scrollTop;
        const start = Math.max(0, Math.floor(st / ROW_H) - 2);
        const end = Math.min(showRows.length, start + Math.ceil(h / ROW_H) + 6);
        inner.style.paddingTop = `${start * ROW_H}px`;
        inner.style.paddingBottom = `${(showRows.length - end) * ROW_H}px`;
        inner.innerHTML = showRows
          .slice(start, end)
          .map((r, i) => {
            const idx = start + i;
            const code = escHtml(r.broj_predmeta || '');
            const nz = escHtml(String(r.naziv_predmeta || '').slice(0, 80));
            const cust = escHtml(String(r.customer_name || '').toUpperCase());
            return `<button type="button" class="sn-dd-row ${idx === activeDdIndex ? 'is-active' : ''}" data-idx="${idx}" data-pid="${escHtml(String(r.id))}" style="min-height:${ROW_H}px">
            <div class="sn-dd-row-line1"><strong>${code}</strong> · ${nz}</div>
            <div class="sn-dd-row-line2">${cust}</div>
          </button>`;
          })
          .join('');
        inner.querySelectorAll('[data-pid]').forEach(btn => {
          btn.addEventListener('click', () => {
            const pid = Number(btn.getAttribute('data-pid'));
            const it = showRows.find(x => Number(x.id) === pid);
            if (it) pickPredmet(it);
          });
        });
      };
      paint();
      outer.addEventListener('scroll', paint, { passive: true });
      virtCleanup = () => outer.removeEventListener('scroll', paint);
    } else {
      outer.innerHTML = showRows
        .map((r, idx) => {
          const code = escHtml(r.broj_predmeta || '');
          const nz = escHtml(String(r.naziv_predmeta || '').slice(0, 80));
          const cust = escHtml(String(r.customer_name || '').toUpperCase());
          return `<button type="button" class="sn-dd-row ${idx === activeDdIndex ? 'is-active' : ''}" data-idx="${idx}" data-pid="${escHtml(String(r.id))}">
            <div class="sn-dd-row-line1"><strong>${code}</strong> · ${nz}</div>
            <div class="sn-dd-row-line2">${cust}</div>
          </button>`;
        })
        .join('');
      outer.querySelectorAll('[data-pid]').forEach(btn => {
        btn.addEventListener('click', () => {
          const pid = Number(btn.getAttribute('data-pid'));
          const it = showRows.find(x => Number(x.id) === pid);
          if (it) pickPredmet(it);
        });
      });
    }

    dropEl.innerHTML = '';
    dropEl.appendChild(outer);
    if (hasMore) {
      const more = document.createElement('button');
      more.type = 'button';
      more.className = 'sn-dd-more';
      more.textContent = 'Prikaži više…';
      more.addEventListener('click', () => {
        predExpanded = true;
        renderPredDropdown();
      });
      dropEl.appendChild(more);
    }
    openDrop();
    dropEl._virtCleanup = virtCleanup;
  }

  async function runPredSearch(q) {
    predLoading = true;
    predExpanded = false;
    renderPredDropdown();
    try {
      predRows = await searchBigtehnItems(q, FETCH_LIMIT);
    } catch (e) {
      console.error('[sn/predmet]', e);
      predRows = [];
      showToast('⚠ Greška pri pretrazi predmeta');
    } finally {
      predLoading = false;
      renderPredDropdown();
    }
  }

  const debouncedPred = debounce(() => runPredSearch(pendingSearch), 250);

  function pickPredmet(item) {
    selectedPredmet = item;
    selectedTp = null;
    tpsCache = [];
    qEl.value = '';
    chipRow.hidden = false;
    chipRow.innerHTML = `<span class="sn-chip"><span>${escHtml(item.broj_predmeta || '')} · ${escHtml(String(item.naziv_predmeta || '').slice(0, 42))}</span><button type="button" class="sn-chip-remove" data-x-chip aria-label="Ukloni">×</button></span>`;
    chipRow.querySelector('[data-x-chip]')?.addEventListener('click', () => clearPredmet());
    inputWrap.style.display = 'none';
    closeDrop();
    card2.classList.add('sn-step-animate-in');
    void loadTpsForPredmet();
    syncStepCards();
    paintProgress();
    refreshPreview();
  }

  function clearPredmet() {
    selectedPredmet = null;
    selectedTp = null;
    tpsCache = [];
    chipRow.hidden = true;
    chipRow.innerHTML = '';
    inputWrap.style.display = '';
    tpListEl.innerHTML = '';
    tpFilter.value = '';
    setPrintQty(1);
    syncStepCards();
    paintProgress();
    refreshPreview();
    qEl.focus();
  }

  async function loadTpsForPredmet() {
    if (!selectedPredmet) return;
    tpListEl.innerHTML = '<p class="sn-placeholder-muted">Učitavam tehnološke postupke…</p>';
    try {
      tpsCache = await searchBigtehnWorkOrdersForItem(selectedPredmet.id, { onlyOpen: true, limit: 1000 });
      renderTpList('');
    } catch (e) {
      console.error('[sn/tp]', e);
      tpListEl.innerHTML = `<p class="sn-hint" style="color:#b91c1c">${escHtml(e?.message || String(e))}</p>`;
    }
  }

  function filteredTpList(filter) {
    const f = String(filter || '').trim().toLowerCase();
    if (!f) return tpsCache;
    return tpsCache.filter(
      x =>
        String(x.ident_broj || '')
          .toLowerCase()
          .includes(f) ||
        String(x.broj_crteza || '')
          .toLowerCase()
          .includes(f) ||
        String(x.naziv_dela || '')
          .toLowerCase()
          .includes(f),
    );
  }

  async function renderTpList(filterText) {
    if (!selectedPredmet) return;
    const rawF = String(filterText || '').trim();
    let list = filteredTpList(rawF);
    if (rawF && !list.length) {
      tpListEl.innerHTML = '<p class="sn-placeholder-muted">Tražim u bazi…</p>';
      try {
        const serverRows = await searchBigtehnWorkOrdersForItem(selectedPredmet.id, {
          onlyOpen: true,
          limit: 500,
          search: rawF,
        });
        const extra = Array.isArray(serverRows) ? serverRows : [];
        const byId = new Map(tpsCache.map(r => [Number(r.id), r]));
        for (const r of extra) {
          if (r?.id != null) byId.set(Number(r.id), r);
        }
        tpsCache = Array.from(byId.values()).sort((a, b) =>
          String(a.ident_broj || '').localeCompare(String(b.ident_broj || ''), undefined, { numeric: true }),
        );
        list = filteredTpList(rawF);
      } catch (e) {
        console.error('[sn/tp search]', e);
        list = [];
      }
    }
    tpSearchWrap.style.display = tpsCache.length > 8 ? '' : 'none';
    if (!list.length) {
      tpListEl.innerHTML =
        '<p class="sn-placeholder-muted">Nema otvorenih tehnoloških postupaka za ovaj predmet (ili filter ne pogađa).</p>';
      return;
    }
    tpListEl.innerHTML = list
      .map(wo => {
        const sel = selectedTp && Number(selectedTp.id) === Number(wo.id);
        const idb = escHtml(String(wo.ident_broj || ''));
        const rnz = escHtml(String(wo.broj_crteza || '—'));
        const nz = escHtml(String(wo.naziv_dela || '').slice(0, 120));
        return `<button type="button" role="radio" aria-checked="${sel}" class="sn-tp-card ${sel ? 'is-selected' : ''}" data-tpid="${escHtml(String(wo.id))}">
          <span class="sn-tp-radio" aria-hidden="true"></span>
          <div class="sn-tp-card-body">
            <div class="sn-tp-title">${nz}</div>
            <div class="sn-tp-sub">RNZ <strong>${idb}</strong> · crtež ${rnz}</div>
          </div>
          <span class="sn-tp-bcico">${IC_BC}</span>
        </button>`;
      })
      .join('');
    tpListEl.querySelectorAll('[data-tpid]').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = Number(btn.getAttribute('data-tpid'));
        const wo = tpsCache.find(x => Number(x.id) === id);
        if (wo) selectTp(wo);
      });
    });
  }

  function selectTp(wo) {
    selectedTp = wo;
    card3.classList.add('sn-step-animate-in');
    setPrintQty(1);
    renderTpList(tpFilter.value);
    syncStepCards();
    paintProgress();
    refreshPreview();
  }

  function clearTp() {
    selectedTp = null;
    renderTpList(tpFilter.value);
    syncStepCards();
    paintProgress();
    refreshPreview();
  }

  async function refreshPreview() {
    const qty = getPrintQty();
    prevHint.innerHTML = `Štampa će kreirati <strong>${qty}</strong> kopij${qty === 1 ? 'u' : qty < 5 ? 'e' : 'a'}`;
    btnPrint.textContent = `🖨 Štampaj ${qty} ${printLabelWord(qty)}`;

    if (!selectedPredmet || !selectedTp) {
      prevScale.innerHTML = '<p class="sn-placeholder-muted" style="padding:12px">Izaberi predmet i TP</p>';
      btnPrint.disabled = true;
      return;
    }
    const idb = String(selectedTp.ident_broj || '');
    const slash = idb.indexOf('/');
    const orderPart = slash >= 0 ? idb.slice(0, slash) : idb;
    const tpPart = slash >= 0 ? idb.slice(slash + 1) : '';
    const bc = formatBigTehnRnzBarcode({ orderNo: orderPart, tpNo: tpPart });
    const totalQty = Number(selectedTp.komada) || qty;
    if (!bc) {
      prevScale.innerHTML = '<p class="sn-hint" style="color:#b91c1c">Nije moguće generisati RNZ barkod</p>';
      btnPrint.disabled = true;
      return;
    }
    const fields = {
      brojPredmeta: idb,
      komitent: selectedPredmet.customer_name || '',
      nazivPredmeta: selectedPredmet.naziv_predmeta || '',
      nazivDela: selectedTp.naziv_dela || '',
      brojCrteza: selectedTp.broj_crteza || '',
      kolicina: `${qty}/${totalQty}`,
      materijal: selectedTp.materijal || '',
      datum: todayStrDDMMYY(),
    };
    prevScale.innerHTML = buildTechLabelHtmlBlock({ fields, barcodeValue: bc }, 0);
    btnPrint.disabled = false;
    try {
      const mod = await import('jsbarcode');
      const JsBarcode = mod.default || mod;
      const svg = prevScale.querySelector('svg');
      if (svg && bc) {
        JsBarcode(svg, String(bc).trim(), {
          format: 'CODE128',
          displayValue: false,
          margin: 0,
          height: 80,
          width: 2.2,
          background: '#ffffff',
          lineColor: '#000000',
        });
      }
    } catch (e) {
      console.warn('[sn/preview bc]', e);
    }
  }

  async function doPrint() {
    if (!selectedPredmet || !selectedTp) return;
    const qty = getPrintQty();
    const idb = String(selectedTp.ident_broj || '');
    const slash = idb.indexOf('/');
    const orderPart = slash >= 0 ? idb.slice(0, slash) : idb;
    const tpPart = slash >= 0 ? idb.slice(slash + 1) : '';
    const bc = formatBigTehnRnzBarcode({ orderNo: orderPart, tpNo: tpPart });
    if (!bc) {
      showToast('⚠ Nije moguće generisati barkod');
      return;
    }
    const totalQty = Number(selectedTp.komada) || qty;
    await printTechProcessLabelsBatch([
      {
        barcodeValue: bc,
        copies: qty,
        fields: {
          brojPredmeta: idb,
          komitent: selectedPredmet.customer_name || '',
          nazivPredmeta: selectedPredmet.naziv_predmeta || '',
          nazivDela: selectedTp.naziv_dela || '',
          brojCrteza: selectedTp.broj_crteza || '',
          kolicina: `${qty}/${totalQty}`,
          materijal: selectedTp.materijal || '',
          datum: todayStrDDMMYY(),
        },
      },
    ]);
    showToast(`✓ Štampano ${qty} nalepnica`);
  }

  /* Events */
  wrap.querySelector('#snHubBack')?.addEventListener('click', () => onBackToHub?.());
  wrap.querySelector('#snBackLok')?.addEventListener('click', () => {
    import('../router.js').then(({ navigateToAppPath }) => navigateToAppPath('/lokacije-delova'));
  });
  wrap.querySelector('#snTheme')?.addEventListener('click', () => toggleTheme());
  wrap.querySelector('#snLogout')?.addEventListener('click', async () => {
    await logout();
    onLogout?.();
  });
  wrap.querySelector('#snCancel')?.addEventListener('click', () => {
    import('../router.js').then(({ navigateToAppPath }) => navigateToAppPath('/lokacije-delova'));
  });
  wrap.querySelector('#snReset')?.addEventListener('click', () => {
    clearPredmet();
    clearTp();
    predRows = [];
    predExpanded = false;
    void runPredSearch('');
  });
  wrap.querySelector('#snPrint')?.addEventListener('click', () => void doPrint());

  qEl.addEventListener('input', () => {
    pendingSearch = qEl.value;
    debouncedPred();
  });
  qEl.addEventListener('focus', () => {
    if (!selectedPredmet) {
      pendingSearch = qEl.value;
      void runPredSearch(pendingSearch);
    }
  });

  qEl.addEventListener('keydown', ev => {
    if (!dropOpen && (ev.key === 'ArrowDown' || ev.key === 'ArrowUp') && !selectedPredmet) {
      void runPredSearch(qEl.value);
    }
    const visible = predExpanded ? predRows : predRows.slice(0, FIRST_PAGE);
    if (!dropOpen && (ev.key === 'ArrowDown' || ev.key === 'Enter')) {
      if (predRows.length) openDrop();
    }
    if (!dropOpen) return;
    if (ev.key === 'Escape') {
      ev.preventDefault();
      closeDrop();
      return;
    }
    if (ev.key === 'ArrowDown') {
      ev.preventDefault();
      activeDdIndex = Math.min(activeDdIndex + 1, visible.length - 1);
      renderPredDropdown();
    } else if (ev.key === 'ArrowUp') {
      ev.preventDefault();
      activeDdIndex = Math.max(activeDdIndex - 1, 0);
      renderPredDropdown();
    } else if (ev.key === 'Enter' && activeDdIndex >= 0 && visible[activeDdIndex]) {
      ev.preventDefault();
      pickPredmet(visible[activeDdIndex]);
    }
  });

  const debTp = debounce(() => void renderTpList(tpFilter.value), 280);
  tpFilter.addEventListener('input', () => debTp());

  wrap.querySelector('#snQtyM')?.addEventListener('click', () => setPrintQty(getPrintQty() - 1));
  wrap.querySelector('#snQtyP')?.addEventListener('click', () => setPrintQty(getPrintQty() + 1));
  qtyEl.addEventListener('input', () => {
    setPrintQty(qtyEl.value);
  });
  qtyEl.addEventListener('keydown', ev => {
    if (ev.key === 'Enter' && !btnPrint.disabled) {
      ev.preventDefault();
      void doPrint();
    }
  });

  document.addEventListener('mousedown', docClick);
  paintQtyChips();
  syncStepCards();
  paintProgress();
  void refreshPreview();
  void runPredSearch('');

  teardownFn = () => {
    document.removeEventListener('mousedown', docClick);
    debouncedPred.cancel();
    debTp.cancel();
    dropEl._virtCleanup?.();
    root.innerHTML = '';
  };
}
