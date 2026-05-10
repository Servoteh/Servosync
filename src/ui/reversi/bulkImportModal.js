/**
 * Reversi — Bulk import iz Excel/CSV (RZ-6).
 *
 * Tri tipa importa u jednom modalu (segmented switch):
 *   1) Ručni alat / oprema / odelo → rev_tools (1 red = 1 komad, kategorija)
 *   2) Rezni alat (katalog)        → rev_cutting_tool_catalog + opciono početno stanje
 *   3) Reversi (već izdati)         → rev_documents + rev_document_lines
 *
 * Tok:
 *   - Upload XLSX/CSV (drag-drop ili picker)
 *   - Auto-mapping kolona po alias-ima (case-insensitive, dijakritike skinute)
 *   - Preview tabela sa validacijom
 *   - "Uvezi" → bulk insert preko postojećih servisa
 *
 * Excel template (download dugme po tipu) — header sa primerom.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { loadXlsx } from '../../lib/xlsx.js';
import { CSV_BOM } from '../../lib/csv.js';
import {
  insertTool,
  initialPlacementForTool,
  getMagacinLocationId,
  insertCuttingTool,
  seedCuttingToolStock,
  fetchActiveLocations,
  fetchEmployees,
  fetchEmployeesAny,
  fetchMachines,
  fetchCuttingToolByBarcode,
  fetchCuttingToolByOznaka,
  issueReversal,
  issueCuttingReversal,
} from '../../services/reversiService.js';

/* ─── Definicije kolona po tipu ─────────────────────────────────────── */

const HAND_COLS = [
  { key: 'oznaka', label: 'Oznaka', required: true,
    aliases: ['oznaka', 'sifra', 'šifra', 'kod', 'code'] },
  { key: 'naziv', label: 'Naziv', required: true,
    aliases: ['naziv', 'name', 'opis', 'description'] },
  { key: 'kategorija', label: 'Kategorija',
    aliases: ['kategorija', 'category', 'tip', 'vrsta'] },
  { key: 'serijski_broj', label: 'Serijski broj',
    aliases: ['serijski', 'serijski broj', 'sn', 'serial', 'serial number'] },
  { key: 'datum_kupovine', label: 'Datum kupovine', type: 'date',
    aliases: ['datum', 'datum kupovine', 'datum nabavke', 'purchase date', 'date'] },
  { key: 'napomena', label: 'Napomena',
    aliases: ['napomena', 'opis', 'note', 'notes', 'remark', 'pribor'] },
];

const CUTTING_COLS = [
  { key: 'oznaka', label: 'Oznaka', required: true,
    aliases: ['oznaka', 'sifra', 'šifra', 'kod', 'code'] },
  { key: 'naziv', label: 'Naziv', required: true,
    aliases: ['naziv', 'name', 'opis', 'description'] },
  { key: 'klasa', label: 'Klasa',
    aliases: ['klasa', 'class', 'tip', 'vrsta'] },
  { key: 'jedinica', label: 'Jedinica',
    aliases: ['jedinica', 'jedinica mere', 'jm', 'unit', 'jed mere'] },
  { key: 'kompatibilne_masine', label: 'Kompatibilne mašine',
    aliases: ['masine', 'mašine', 'machines', 'kompatibilne masine', 'kompatibilne mašine'] },
  { key: 'pocetna_kolicina', label: 'Početna količina', type: 'number',
    aliases: ['kolicina', 'količina', 'qty', 'pocetna', 'pocetno stanje', 'početno stanje', 'stanje'] },
  { key: 'napomena', label: 'Napomena',
    aliases: ['napomena', 'note', 'opis dodatni', 'notes'] },
];

const REVERS_COLS = [
  { key: 'tip', label: 'Tip dokumenta', required: true,
    aliases: ['tip', 'type', 'doc_type', 'tip dokumenta'] },
  { key: 'datum', label: 'Datum izdavanja', type: 'date',
    aliases: ['datum', 'date', 'datum izdavanja', 'issued at', 'issued_at'] },
  { key: 'primalac_tip', label: 'Tip primaoca', required: true,
    aliases: ['primalac tip', 'recipient_type', 'tip primaoca'] },
  { key: 'primalac', label: 'Primalac (ime / mašina / firma)', required: true,
    aliases: ['primalac', 'recipient', 'recipient_name', 'ime primaoca'] },
  { key: 'masina', label: 'Mašina (rj_code)',
    aliases: ['masina', 'mašina', 'machine', 'rj_code', 'rj code'] },
  { key: 'alat_oznaka_ili_barkod', label: 'Alat (oznaka ili barkod)', required: true,
    aliases: ['alat', 'oznaka', 'barkod', 'barcode', 'sifra', 'šifra'] },
  { key: 'kolicina', label: 'Količina', type: 'number',
    aliases: ['kolicina', 'količina', 'qty', 'qty_issued'] },
  { key: 'rok_povracaja', label: 'Rok povraćaja', type: 'date',
    aliases: ['rok', 'rok povracaja', 'rok povraćaja', 'expected return', 'return_date'] },
  { key: 'napomena', label: 'Napomena',
    aliases: ['napomena', 'note', 'notes'] },
];

const TYPES = [
  { id: 'hand',    label: 'Ručni alat / oprema',  cols: HAND_COLS },
  { id: 'cutting', label: 'Rezni alat',           cols: CUTTING_COLS },
  { id: 'revers',  label: 'Reversi (izdati)',     cols: REVERS_COLS },
];

/* ─── Helper ─────────────────────────────────────────────────────── */

function normHeader(s) {
  return String(s || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/\s+/g, ' ');
}

/**
 * Detektuj i popravi mojibake (UTF-8 bajtovi pročitani kao Windows-1252).
 * Tipičan obrazac: `š` → `Å¡`, `č` → `Ä`, `Ø` → `Ã˜`. Ako string sadrži >=2
 * takva pattern-a, primeni reverse: encode kao Latin-1, decode kao UTF-8.
 *
 * @param {string} s
 * @returns {string}
 */
function fixMojibake(s) {
  if (typeof s !== 'string' || s.length < 2) return s;
  /* Brzo odbijanje: ako nema 1-bajt-iznad-127 karaktera koji se pojavljuju u
   * UTF-8 → cp1252 dvostrukom enkodiranju, vrati. Ä je ključan jer Ä‡/Ä, Ä‘
   * pokrivaju ć/đ (najčešće u srpskom imenu).
   */
  if (!/[ÃÅÂÄ]/.test(s)) return s;
  /* Test patterni — primeri stvarnih sekvenci iz UTF-8→cp1252 misread-a.
   * Treba bar 2 različita pattern-a (broj hits-a) da bi fix bio aktiviran;
   * kratko ime kao "Predrag ÄiroviÄ" ima Ä dva puta — broji ih kao 2.
   */
  const patterns = [
    /Ä‡/, /Ä‘/, /Ä/g, /Å¡/, /Å¾/, /Å /, /Å½/,
    /Ã/g, /Ã‚/, /Ã©/, /Ã«/, /Â°/, /Ã˜/, /Â­/,
  ];
  let hits = 0;
  for (const p of patterns) {
    if (p.global) {
      const m = s.match(p);
      if (m) hits += m.length;
    } else if (p.test(s)) {
      hits += 1;
    }
    if (hits >= 2) break;
  }
  if (hits < 2) return s;
  try {
    /* "Latin-1 round-trip": svaki char je <= 0xFF zato što je iz cp1252,
     * pa charCodeAt vraća vrednost koja odgovara originalnom UTF-8 bajtu. */
    const bytes = new Uint8Array(s.length);
    for (let i = 0; i < s.length; i += 1) {
      const c = s.charCodeAt(i);
      if (c > 0xff) return s; /* nije čisti cp1252 — odustani */
      bytes[i] = c;
    }
    const fixed = new TextDecoder('utf-8', { fatal: false }).decode(bytes);
    /* Sanity: ako je fixed isti — vrati ga; ako sadrži replacement chars — original. */
    if (fixed && fixed !== s && !fixed.includes('�')) return fixed;
    return s;
  } catch {
    return s;
  }
}

/**
 * Mapiraj kategoriju iz Excel-a (GLODALA / BURGIJE / UREZNICE / RAZVRTAČI / GLODALO LOPTA / GLODAČKE GLAVE / GLODAČKE GLAVE I NOSAČI / ostalo) na rev_cutting_tool_catalog.klasa.
 * @param {string} kat
 * @returns {string}
 */
function mapKategorijaToKlasa(kat) {
  const k = String(kat || '').trim().toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '');
  if (!k) return '';
  if (k.includes('glodalo lopta') || k.includes('glodalo - lopta')) return 'glodalo';
  if (k.includes('glod')) return 'glodalo';
  if (k.includes('glava')) return 'glodačka glava';
  if (k.includes('nosac') || k.includes('nosač')) return 'glodačka glava';
  if (k.includes('burg')) return 'burgija';
  if (k.includes('urez')) return 'urezna';
  if (k.includes('razvrt')) return 'razvrtač';
  if (k.includes('ploc') || k.includes('ploč')) return 'pločica';
  if (k.includes('drzac') || k.includes('držač') || k.includes('holder')) return 'držač';
  if (k.includes('narez')) return 'narez';
  return 'ostalo';
}

/**
 * Skini dijakritike i lowercase + trim — za poređenje imena radnika
 * koja u izvoru mogu imati / ne imati ć/č/š/đ/ž zbog typing/encoding razlike.
 *
 * @param {string} s
 * @returns {string}
 */
function normalizeName(s) {
  return String(s || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ');
}

/**
 * Pretraži radnika po imenu sa fuzzy match-om. Pokriva:
 *   - dijakritike u CSV vs bez u bazi (i obrnuto)
 *   - obrnut redosled (CSV: "Petar Petrović" ↔ baza: "Petrović Petar")
 *   - srednje slovo (CSV: "Petar Petrović" ↔ baza: "Petar M. Petrović")
 *   - is_active=false (koristi fetchEmployeesAny, bez tog filtera)
 *
 * @param {string} name
 * @returns {Promise<{id: string, full_name: string, is_active?: boolean} | null>}
 */
async function resolveEmployeeFuzzy(name) {
  const original = String(name || '').trim();
  if (!original) return null;
  const normTarget = normalizeName(original);
  const targetTokens = normTarget.split(' ').filter(Boolean).sort();
  /* eslint-disable no-console */
  const dbg = (msg, data) => console.log(`[reversi/import/empResolve] ${msg}`, data);
  dbg('start', { name: original, normTarget, targetTokens });

  /* Helper: za listu kandidata, vrati onog čija je sortirana lista tokena
   * (skinut dijakritici, lower-case) ista kao target — pokriva i obrnut redosled
   * i srednje slovo (ako jedan ima a drugi nema, set jednog je podskup drugog). */
  const findTokenMatch = (list) => {
    /* exact: isti broj tokena, isti set */
    let hit = list.find((e) => {
      const tokens = normalizeName(e.full_name).split(' ').filter(Boolean).sort();
      return tokens.length === targetTokens.length && tokens.join(' ') === targetTokens.join(' ');
    });
    if (hit) return hit;
    /* superset/subset: jedan ima srednje slovo, drugi nema */
    if (targetTokens.length >= 2) {
      hit = list.find((e) => {
        const tokens = normalizeName(e.full_name).split(' ').filter(Boolean);
        const tokenSet = new Set(tokens);
        return targetTokens.every((t) => tokenSet.has(t));
      });
      if (hit) return hit;
    }
    return null;
  };

  /* Pokušaj 1: ilike sa originalnim imenom, fuzzy nad rezultatom */
  let r = await fetchEmployeesAny(original);
  let list = r.ok && Array.isArray(r.data) ? r.data : [];
  dbg(`pass1: ilike *${original}*`, { count: list.length, sample: list.slice(0, 3).map((e) => e.full_name) });
  let hit = findTokenMatch(list);
  if (hit) { dbg('pass1 HIT', hit.full_name); return { id: hit.id, full_name: hit.full_name, is_active: hit.is_active }; }

  /* Pokušaj 2: ilike sa stripped imenom (bez dijakritika) — pokriva slučaj kad
   * baza ima druge dijakritike (Cirovic vs Ćirović) ili kad PostgREST collation
   * ne radi pravilno za UTF-8 dijakritike. */
  const stripped = original.normalize('NFD').replace(/[̀-ͯ]/g, '');
  if (stripped !== original) {
    r = await fetchEmployeesAny(stripped);
    list = r.ok && Array.isArray(r.data) ? r.data : [];
    dbg(`pass2: ilike *${stripped}*`, { count: list.length, sample: list.slice(0, 3).map((e) => e.full_name) });
    hit = findTokenMatch(list);
    if (hit) { dbg('pass2 HIT', hit.full_name); return { id: hit.id, full_name: hit.full_name, is_active: hit.is_active }; }
  }

  /* Pokušaj 3: pretraga po SVAKOM tokenu (skinut dijakritik). Spaja sve
   * kandidate iz svih pojedinačnih ilike upita pa pravi token-match.
   * Hvata "Petar Petrović" ↔ "Petrović Petar" (svaki token zasebno tražen). */
  if (targetTokens.length >= 2) {
    const candidates = new Map(); // id → row
    for (const tok of targetTokens) {
      if (tok.length < 3) continue; /* preskoči inicijale / kratke reči */
      const tokStripped = tok.normalize('NFD').replace(/[̀-ͯ]/g, '');
      r = await fetchEmployeesAny(tokStripped);
      const tList = r.ok && Array.isArray(r.data) ? r.data : [];
      dbg(`pass3: ilike *${tokStripped}*`, { count: tList.length });
      for (const row of tList) {
        if (!candidates.has(row.id)) candidates.set(row.id, row);
      }
    }
    const merged = Array.from(candidates.values());
    dbg('pass3 merged', { count: merged.length, sample: merged.slice(0, 5).map((e) => e.full_name) });
    hit = findTokenMatch(merged);
    if (hit) { dbg('pass3 HIT', hit.full_name); return { id: hit.id, full_name: hit.full_name, is_active: hit.is_active }; }
  }

  dbg('NO MATCH', { name: original });
  /* eslint-enable no-console */
  return null;
}

/**
 * Iz napomene oblika "Naziv: Glodalo Ø 12; Kategorija: GLODALA; Mašina: …"
 * izvuci strukturisana polja.
 *
 * @param {string} note
 * @returns {{ naziv: string, kategorija: string, masinaText: string, izvor: string, raw: string }}
 */
function parseCuttingMetaFromNote(note) {
  const out = { naziv: '', kategorija: '', masinaText: '', izvor: '', raw: '' };
  if (!note) return out;
  const raw = fixMojibake(String(note).trim());
  out.raw = raw;
  const parts = raw.split(/\s*;\s*/);
  for (const p of parts) {
    const m = p.match(/^([^:]+)\s*:\s*(.+)$/);
    if (!m) continue;
    const key = m[1].trim().toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
    const val = m[2].trim();
    if (key === 'naziv') out.naziv = val;
    else if (key === 'kategorija') out.kategorija = val;
    else if (key === 'masina' || key === 'masine') out.masinaText = val;
    else if (key === 'izvor') out.izvor = val;
  }
  return out;
}

function normalizeDate(v) {
  if (!v) return '';
  if (v instanceof Date) {
    if (Number.isNaN(v.getTime())) return '';
    return v.toISOString().slice(0, 10);
  }
  const s = String(v).trim();
  if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
  /* DD.MM.YYYY ili DD/MM/YYYY */
  const m = s.match(/^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})$/);
  if (m) {
    const d = m[1].padStart(2, '0');
    const mo = m[2].padStart(2, '0');
    let y = m[3];
    if (y.length === 2) y = '20' + y;
    return `${y}-${mo}-${d}`;
  }
  return '';
}

function mapRow(raw, cols) {
  const headerMap = new Map();
  const firstKeys = Object.keys(raw[0] || {});
  for (const hk of firstKeys) {
    /* Header može biti dvostruko-enkodovan kao i vrednosti — popravi pre normalizacije */
    const fixed = fixMojibake(hk);
    const n = normHeader(fixed);
    const col = cols.find(c =>
      normHeader(c.label) === n ||
      (c.aliases || []).some(a => normHeader(a) === n)
    );
    if (col) headerMap.set(hk, col);
  }
  return raw.map((src) => {
    const r = {};
    for (const [hk, col] of headerMap.entries()) {
      let v = src[hk];
      if (v === undefined || v === null) v = '';
      if (col.type === 'date') v = normalizeDate(v);
      else if (col.type === 'number') {
        const n = Number(String(v).replace(',', '.').replace(/\s/g, ''));
        v = Number.isFinite(n) ? n : 0;
      } else {
        v = fixMojibake(String(v).trim());
      }
      r[col.key] = v;
    }
    return r;
  });
}

function modalShell(title, bodyHtml, footerHtml, id) {
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay rev-modal-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal rev-modal" style="max-width:980px">
        <div class="kadr-modal-header">
          <h2>${escHtml(title)}</h2>
          <button type="button" class="kadr-modal-close" data-imp-close>×</button>
        </div>
        <div class="kadr-modal-body rev-modal-body">${bodyHtml}</div>
        <div class="kadr-modal-footer rev-modal-footer">${footerHtml}</div>
      </div>
    </div>`;
  return wrap.firstElementChild;
}

function downloadTemplate(typeDef) {
  const headers = typeDef.cols.map((c) => c.label);
  const example = typeDef.cols.map((c) => {
    if (typeDef.id === 'hand') {
      if (c.key === 'oznaka') return 'AL-001';
      if (c.key === 'naziv') return 'Akumulatorska bušilica';
      if (c.key === 'kategorija') return 'alat';
      if (c.key === 'serijski_broj') return 'SN-12345';
      if (c.key === 'datum_kupovine') return '2024-03-15';
      if (c.key === 'napomena') return 'sa baterijom + punjac';
    } else if (typeDef.id === 'cutting') {
      if (c.key === 'oznaka') return 'GL-D12-HSS';
      if (c.key === 'naziv') return 'Glodalo HSS Ø12';
      if (c.key === 'klasa') return 'glodalo';
      if (c.key === 'jedinica') return 'kom';
      if (c.key === 'kompatibilne_masine') return '8.3, 10.1';
      if (c.key === 'pocetna_kolicina') return '20';
      if (c.key === 'napomena') return '';
    } else if (typeDef.id === 'revers') {
      if (c.key === 'tip') return 'TOOL';
      if (c.key === 'datum') return '2026-05-01';
      if (c.key === 'primalac_tip') return 'EMPLOYEE';
      if (c.key === 'primalac') return 'Petar Petrović';
      if (c.key === 'masina') return '';
      if (c.key === 'alat_oznaka_ili_barkod') return 'AL-001';
      if (c.key === 'kolicina') return '1';
      if (c.key === 'rok_povracaja') return '2026-08-01';
      if (c.key === 'napomena') return 'pribor: punjač';
    }
    return '';
  });
  const csv = headers.map((h) => `"${h}"`).join(',') + '\r\n' + example.map((v) => {
    const s = String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  }).join(',') + '\r\n';
  const blob = new Blob([CSV_BOM + csv], { type: 'text/csv;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `reversi-template-${typeDef.id}.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
}

/* ─── Glavni modal ─────────────────────────────────────────────── */

export function openBulkImportModal(opts = {}) {
  const id = `revBulkImp_${Date.now()}`;
  const state = {
    type: 'hand',
    rows: [],
    importing: false,
    progress: { ok: 0, fail: 0, total: 0 },
    /* Reversi pre-pass rezultat: šta će biti kreirano (catalog) i šta nedostaje (employees) */
    analysis: null, // { newCatalog: [...], existingCatalog: [...], missingEmployees: [...], resolvedEmployees: Map, machineCodes: Set, docCount, lineCount }
    analyzing: false,
  };
  const overlay = modalShell(
    '📥 Bulk import iz Excel/CSV',
    `<div id="revImpBody"></div>`,
    `<div id="revImpFoot"></div>`,
    id,
  );
  document.body.appendChild(overlay);

  /* Delegated handler: footer se rebuild-uje u paint() pa direktan listener na
   * Otkaži dugme bi bio izgubljen. Slušamo ceo overlay i checkiramo target. */
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) {
      overlay.remove();
      return;
    }
    const closeBtn = e.target.closest('[data-imp-close]');
    if (closeBtn && overlay.contains(closeBtn)) {
      overlay.remove();
    }
  });

  function paint() {
    const typeDef = TYPES.find((t) => t.id === state.type);
    const body = overlay.querySelector('#revImpBody');
    const foot = overlay.querySelector('#revImpFoot');

    body.innerHTML = `
      <div class="rev-form-grid">
        <fieldset class="rev-fieldset">
          <legend>Tip importa</legend>
          <div class="rev-seg" role="group">
            ${TYPES.map((t) => `<button type="button" class="rev-seg-btn ${state.type === t.id ? 'is-on' : ''}" data-imp-type="${t.id}">${escHtml(t.label)}</button>`).join('')}
          </div>
        </fieldset>

        <div class="rev-imp-template">
          <p class="rev-muted">Očekivane kolone (header u prvom redu — dijakritici i veličina slova nisu bitni):</p>
          <ul class="rev-imp-cols">
            ${typeDef.cols.map((c) => `<li><strong>${escHtml(c.label)}</strong>${c.required ? ' <span class="rev-warn">*</span>' : ''} <span class="rev-muted">(${(c.aliases || []).slice(0, 3).join(' / ')})</span></li>`).join('')}
          </ul>
          <button type="button" class="rev-btn rev-btn--secondary" id="revImpDlTpl">📄 Preuzmi template (CSV)</button>
        </div>

        <div class="rev-imp-drop" id="revImpDrop">
          <p>Prevuci Excel/CSV fajl ovde ili klikni za izbor.</p>
          <p class="rev-muted">Podržani formati: .xlsx, .xls, .csv</p>
          <input type="file" id="revImpFile" accept=".xlsx,.xls,.csv" hidden/>
          <button type="button" class="rev-btn" id="revImpBrowse">Izaberi fajl…</button>
        </div>

        ${analysisSummaryHtml()}

        ${
          state.rows.length === 0
            ? ''
            : `
          <div class="rev-imp-preview">
            <div class="rev-imp-preview-head">
              <strong>Preview:</strong> ${state.rows.length} redova
              <button type="button" class="rev-btn rev-btn--secondary" id="revImpClear">Očisti</button>
            </div>
            <div class="rev-table-shell" style="max-height:300px;overflow:auto">
              <table class="rev-data-table">
                <thead><tr>${typeDef.cols.map((c) => `<th>${escHtml(c.label)}${c.required ? ' *' : ''}</th>`).join('')}<th>Validno?</th></tr></thead>
                <tbody>${state.rows
                  .slice(0, 200)
                  .map((r, idx) => {
                    const errs = validateRow(r, typeDef);
                    const valid = errs.length === 0;
                    return `<tr class="${valid ? '' : 'is-invalid'}">${typeDef.cols
                      .map((c) => `<td>${escHtml(String(r[c.key] ?? ''))}</td>`)
                      .join('')}<td>${valid ? '✓' : `<span class="rev-warn" title="${escHtml(errs.join(', '))}">⚠ ${errs.length}</span>`}</td></tr>`;
                  })
                  .join('')}
              </tbody></table>
            </div>
            ${state.rows.length > 200 ? `<p class="rev-muted">Prikazano prvih 200 redova; biće uvezeno svih ${state.rows.length}.</p>` : ''}
          </div>`
        }

        ${state.importing ? `<div class="rev-loading-card">Uvozim ${state.progress.ok + state.progress.fail} / ${state.progress.total}…</div>` : ''}
      </div>`;

    const validRowsCount = state.rows.filter((r) => validateRow(r, typeDef).length === 0).length;
    const blockedByAnalysis =
      state.type === 'revers' &&
      (state.analyzing ||
        (state.analysis &&
          (state.analysis.missingEmployees.length > 0 ||
            !state.analysis.magacinExists ||
            (state.analysis.duplicateDocs.length > 0 && !state.analysis.forceImportConfirmed))));
    const canRun = state.rows.length > 0 && validRowsCount > 0 && !state.importing && !blockedByAnalysis;
    foot.innerHTML = `
      <button type="button" class="rev-btn" data-imp-close>Otkaži</button>
      <button type="button" class="rev-btn rev-btn--primary" id="revImpRun" ${canRun ? '' : 'disabled'}>
        ${state.importing ? 'Uvozim…' : state.analyzing ? 'Analiziram…' : `Uvezi ${validRowsCount} redova`}
      </button>`;

    bindEvents();
  }

  function validateRow(r, typeDef) {
    const errs = [];
    for (const c of typeDef.cols) {
      /* Datum izdavanja nije obavezan — prazan se popunjava današnjim datumom u importu */
      if (c.required && !r[c.key]) errs.push(`${c.label} obavezno`);
    }
    if (typeDef.id === 'revers') {
      if (r.tip && !['TOOL', 'COOPERATION_GOODS', 'CUTTING_TOOL'].includes(r.tip.toUpperCase())) {
        errs.push(`tip mora biti TOOL/COOPERATION_GOODS/CUTTING_TOOL`);
      }
      if (r.primalac_tip && !['EMPLOYEE', 'DEPARTMENT', 'EXTERNAL_COMPANY', 'MACHINE'].includes(r.primalac_tip.toUpperCase())) {
        errs.push(`primalac_tip mora biti EMPLOYEE/DEPARTMENT/EXTERNAL_COMPANY/MACHINE`);
      }
      const primTip = (r.primalac_tip || '').toUpperCase();
      if (primTip === 'MACHINE' && !r.masina) {
        errs.push(`masina obavezno za MACHINE primaoca`);
      }
      const tip = (r.tip || '').toUpperCase();
      if (tip === 'CUTTING_TOOL' && !r.masina) {
        errs.push(`mašina obavezna za CUTTING_TOOL`);
      }
    }
    if (typeDef.id === 'cutting' && r.pocetna_kolicina && Number(r.pocetna_kolicina) < 0) {
      errs.push('početna količina ne može biti negativna');
    }
    return errs;
  }

  /** Sažetak preanalize za revers tip — prikaz pre import-a. */
  function analysisSummaryHtml() {
    if (state.type !== 'revers') return '';
    if (state.analyzing) {
      return `<div class="rev-imp-analysis is-loading"><strong>Analiza u toku…</strong> Resolve-ujemo radnike i šifre alata, ne stiskaj „Uvezi“ još.</div>`;
    }
    if (!state.analysis) return '';
    const a = state.analysis;
    const hasDup = a.duplicateDocs.length > 0;
    const blocking = a.missingEmployees.length > 0 || !a.magacinExists || (hasDup && !a.forceImportConfirmed);
    const blockReasons = [];
    if (a.missingEmployees.length > 0) {
      blockReasons.push(`${a.missingEmployees.length} radnika nedostaje u Kadrovskoj`);
    }
    if (!a.magacinExists) {
      blockReasons.push('Magacin lokacija „ALAT-MAG-01" ne postoji u Lokacije modulu');
    }
    if (hasDup && !a.forceImportConfirmed) {
      blockReasons.push(`${a.duplicateDocs.length} mašina već ima aktivan revers — verovatno duplikat importa`);
    }
    return `
      <div class="rev-imp-analysis ${blocking ? 'is-blocking' : 'is-ready'}">
        <strong>Pre-import analiza:</strong>
        <ul class="rev-imp-analysis-list">
          <li>Reversi dokumenata: <strong>${escHtml(String(a.docCount))}</strong> (${escHtml(String(a.lineCount))} stavki)</li>
          <li>Mašine prepoznate: ${a.machineCodes.size}</li>
          <li>Šifre reznog alata postojeće: ${a.existingCatalog.length}</li>
          <li>Šifre koje će biti <strong>auto-kreirane</strong>: ${a.newCatalog.length}${a.newCatalog.length > 0 ? ` <span class="rev-muted">(${a.newCatalog.slice(0, 6).map((x) => escHtml(x.oznaka)).join(', ')}${a.newCatalog.length > 6 ? '…' : ''})</span>` : ''}</li>
          <li>Radnici resolve-ovani: ${a.resolvedEmployees.size}</li>
          <li>Magacin lokacija (ALAT-MAG-01): ${a.magacinExists ? '<span style="color:#2a8c4a">✓ postoji</span>' : '<span class="rev-warn">⚠ NE POSTOJI</span>'}</li>
          ${
            a.missingEmployees.length > 0
              ? `<li class="rev-warn"><strong>NEDOSTAJU U BAZI</strong>: ${a.missingEmployees.length} radnika — admin mora ručno da ih kreira pre importa:<br/><span class="rev-muted">${a.missingEmployees.slice(0, 20).map(escHtml).join(', ')}${a.missingEmployees.length > 20 ? '…' : ''}</span></li>`
              : ''
          }
          ${
            hasDup
              ? `<li class="rev-warn"><strong>⚠ DUPLIKAT IMPORTA</strong>: ${a.duplicateDocs.length} aktivan(ih) reverz dokument(a) već postoji za ove mašine:<br/>${a.duplicateDocs
                  .slice(0, 10)
                  .map((d) => `<span class="rev-muted">• ${escHtml(d.machine)} — ${escHtml(d.doc_number)} (${escHtml(String(d.issued_at).slice(0, 10))}, ${escHtml(d.employee || '?')})</span>`)
                  .join('<br/>')}${a.duplicateDocs.length > 10 ? `<br/><span class="rev-muted">…i još ${a.duplicateDocs.length - 10}</span>` : ''}</li>`
              : ''
          }
        </ul>
        ${blocking ? `<p class="rev-warn">Import je <strong>blokiran</strong>: ${escHtml(blockReasons.join('; '))}.</p>` : ''}
        ${
          !a.magacinExists
            ? `<p class="rev-muted" style="font-size:12px">Otvori Lokacije modul i kreiraj <code>ALAT-MAG-01</code> sa tipom <code>WAREHOUSE</code>, ili pokreni SQL u Supabase:<br/><code>INSERT INTO loc_locations(location_code, name, location_type, is_active) VALUES('ALAT-MAG-01', 'Centralna alatnica — magacin', 'WAREHOUSE', true);</code></p>`
            : ''
        }
        ${
          hasDup && !a.forceImportConfirmed
            ? `<div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap">
                <button type="button" class="rev-btn rev-btn--secondary" id="revImpForceImport">⚠ Ipak nastavi (kreiraj duplikat reversa)</button>
                <span class="rev-muted" style="font-size:12px;align-self:center">Ovo će napraviti DRUGI revers dokument za ista zaduženja. Ako je prvi import napravljen greškom, prvo ga storniraj iz tab-a „Zaduženja".</span>
              </div>`
            : ''
        }
      </div>`;
  }

  function bindEvents() {
    overlay.querySelectorAll('[data-imp-type]').forEach((b) => {
      b.addEventListener('click', () => {
        state.type = b.getAttribute('data-imp-type');
        state.rows = [];
        state.analysis = null;
        state.analyzing = false;
        paint();
      });
    });
    overlay.querySelector('#revImpDlTpl')?.addEventListener('click', () => {
      const td = TYPES.find((t) => t.id === state.type);
      downloadTemplate(td);
    });
    const fileInput = overlay.querySelector('#revImpFile');
    overlay.querySelector('#revImpBrowse')?.addEventListener('click', () => fileInput?.click());
    overlay.querySelector('#revImpClear')?.addEventListener('click', () => {
      state.rows = [];
      state.analysis = null;
      state.analyzing = false;
      paint();
    });
    fileInput?.addEventListener('change', async () => {
      const f = fileInput.files?.[0];
      if (f) await handleFile(f);
      fileInput.value = '';
    });
    const drop = overlay.querySelector('#revImpDrop');
    if (drop) {
      drop.addEventListener('dragover', (e) => { e.preventDefault(); drop.classList.add('is-dragging'); });
      drop.addEventListener('dragleave', () => drop.classList.remove('is-dragging'));
      drop.addEventListener('drop', async (e) => {
        e.preventDefault();
        drop.classList.remove('is-dragging');
        const f = e.dataTransfer?.files?.[0];
        if (f) await handleFile(f);
      });
    }
    overlay.querySelector('#revImpRun')?.addEventListener('click', runImport);
    overlay.querySelector('#revImpForceImport')?.addEventListener('click', () => {
      if (state.analysis) {
        state.analysis.forceImportConfirmed = true;
        paint();
      }
    });
  }

  async function handleFile(file) {
    try {
      const typeDef = TYPES.find((t) => t.id === state.type);
      let raw = [];
      if (/\.csv$/i.test(file.name)) {
        const text = await file.text();
        raw = parseCsvToObjects(text);
      } else {
        const XLSX = await loadXlsx();
        const buf = await file.arrayBuffer();
        const wb = XLSX.read(buf, { type: 'array', cellDates: true });
        const sheet = wb.Sheets[wb.SheetNames[0]];
        if (!sheet) { showToast('Fajl je prazan'); return; }
        raw = XLSX.utils.sheet_to_json(sheet, { defval: '', raw: false, dateNF: 'yyyy-mm-dd' });
      }
      state.rows = mapRow(raw, typeDef.cols);
      state.analysis = null;
      showToast(`✔ Učitano ${state.rows.length} redova`);
      paint();

      /* Pre-pass analiza za revers tip — pokreni asinhrono */
      if (state.type === 'revers' && state.rows.length > 0) {
        state.analyzing = true;
        paint();
        try {
          const valid = state.rows.filter((r) => validateRow(r, typeDef).length === 0);
          state.analysis = await analyzeRevers(valid);
        } catch (e) {
          console.error('[bulkImport] analyze fail', e);
          showToast(`Greška pri analizi: ${e?.message || e}`);
        } finally {
          state.analyzing = false;
          paint();
        }
      }
    } catch (e) {
      console.error('[bulkImport] parse fail', e);
      showToast(`Greška pri čitanju fajla: ${e?.message || e}`);
    }
  }

  async function runImport() {
    const typeDef = TYPES.find((t) => t.id === state.type);
    const valid = state.rows.filter((r) => validateRow(r, typeDef).length === 0);
    if (valid.length === 0) return;
    state.importing = true;
    state.progress = { ok: 0, fail: 0, total: valid.length };
    paint();

    try {
      if (typeDef.id === 'hand') await importHand(valid);
      else if (typeDef.id === 'cutting') await importCutting(valid);
      else if (typeDef.id === 'revers') {
        if (!state.analysis) {
          showToast('Analiza nije gotova — sačekaj par sekundi pa pokušaj opet.');
          state.importing = false;
          paint();
          return;
        }
        if (state.analysis.missingEmployees.length > 0) {
          showToast(`Import blokiran: ${state.analysis.missingEmployees.length} radnika nedostaje u Kadrovskoj.`);
          state.importing = false;
          paint();
          return;
        }
        if (!state.analysis.magacinExists) {
          showToast('Import blokiran: ALAT-MAG-01 lokacija ne postoji u Lokacije modulu.');
          state.importing = false;
          paint();
          return;
        }
        if (state.analysis.duplicateDocs.length > 0 && !state.analysis.forceImportConfirmed) {
          showToast(`Import blokiran: ${state.analysis.duplicateDocs.length} mašina već ima aktivan revers (verovatno duplikat).`);
          state.importing = false;
          paint();
          return;
        }
        await importRevers(valid, state.analysis);
      }
    } catch (e) {
      console.error('[bulkImport] run fail', e);
      showToast(`Greška: ${e?.message || e}`);
    }
    state.importing = false;
    showToast(`✓ Uvezeno: ${state.progress.ok}, neuspešno: ${state.progress.fail}`);
    if (state.progress.ok > 0) {
      opts.onSuccess?.();
    }
    if (state.progress.fail === 0) {
      overlay.remove();
    } else {
      paint();
    }
  }

  async function importHand(rows) {
    const magId = await getMagacinLocationId();
    for (const r of rows) {
      const payload = {
        oznaka: r.oznaka,
        naziv: r.naziv,
        kategorija: r.kategorija || null,
        serijski_broj: r.serijski_broj || null,
        datum_kupovine: r.datum_kupovine || null,
        napomena: r.napomena || null,
        status: 'active',
      };
      const ins = await insertTool(payload);
      if (!ins.ok) { state.progress.fail += 1; paint(); continue; }
      if (magId) {
        const pl = await initialPlacementForTool(ins.data.loc_item_ref_id, magId);
        if (!pl.ok) { state.progress.fail += 1; paint(); continue; }
      }
      state.progress.ok += 1;
      paint();
    }
  }

  async function importCutting(rows) {
    const magId = await getMagacinLocationId();
    for (const r of rows) {
      const machines = String(r.kompatibilne_masine || '')
        .split(/[,;]/)
        .map((s) => s.trim())
        .filter(Boolean);
      const payload = {
        oznaka: r.oznaka,
        naziv: r.naziv,
        klasa: r.klasa || null,
        compatible_machine_codes: machines,
        unit: r.jedinica || 'kom',
        napomena: r.napomena || null,
        status: 'active',
      };
      const ins = await insertCuttingTool(payload);
      if (!ins.ok) { state.progress.fail += 1; paint(); continue; }
      const qty = Math.max(0, Math.floor(Number(r.pocetna_kolicina) || 0));
      if (qty > 0 && magId) {
        const seed = await seedCuttingToolStock(ins.data.id, magId, qty);
        if (!seed.ok) { state.progress.fail += 1; paint(); continue; }
      }
      state.progress.ok += 1;
      paint();
    }
  }

  /* ─── REVERS pre-import analiza ───────────────────────────────────
   * Pre nego što kreiramo dokumente:
   *   1. resolve employee imena (strict — admin ne dozvoljava auto-create)
   *   2. resolve postojeće šifre reznog alata po oznaci/barkodu
   *   3. za nepoznate oznake — pripremi auto-create podatke iz Napomene
   * Vraća objekat sa listama: missingEmployees (blokira import), newCatalog (kreiraće se),
   * existingCatalog, machineCodes, docCount, lineCount.
   */
  async function analyzeRevers(rows) {
    const result = {
      newCatalog: [],          // [{ oznaka, naziv, klasa, masine: Set }]
      existingCatalog: [],     // [{ oznaka, id }]
      missingEmployees: [],    // [name, ...] — strict, blokira import
      resolvedEmployees: new Map(), // name -> { id, full_name }
      machineCodes: new Set(),
      docCount: 0,
      lineCount: rows.length,
      catalogByOznaka: new Map(), // oznaka -> { id (ako postoji) | placeholder za novi }
      magacinExists: false,    // ALAT-MAG-01 — blokira CUTTING_TOOL import ako fali
      duplicateDocs: [],       // [{ machine, doc_number, issued_at, employee }] — već postoji aktivan revers za istu mašinu
      forceImportConfirmed: false, // user je eksplicitno potvrdio override duplikata
    };

    /* 0. Provera magacin lokacije (ALAT-MAG-01) — RPC rev_issue_cutting_reversal
     * je zahteva kao default izvorište. Ako fali, CUTTING_TOOL import će pasti. */
    const magId = await getMagacinLocationId();
    result.magacinExists = !!magId;

    /* 1. Skupi unique oznake alata sa metapodacima iz Napomene */
    const oznakaToMeta = new Map(); // oznaka -> { naziv, klasa, masine: Set }
    for (const r of rows) {
      const oznaka = String(r.alat_oznaka_ili_barkod || '').trim();
      if (!oznaka) continue;
      if (!oznakaToMeta.has(oznaka)) {
        const meta = parseCuttingMetaFromNote(r.napomena);
        oznakaToMeta.set(oznaka, {
          naziv: meta.naziv || oznaka,
          klasa: mapKategorijaToKlasa(meta.kategorija),
          masine: new Set(),
        });
      }
      const masina = String(r.masina || '').trim();
      if (masina) oznakaToMeta.get(oznaka).masine.add(masina);
    }

    /* 2. Resolve catalog po oznaci (ili barkodu ako počinje sa RZN-) */
    for (const [oznaka, meta] of oznakaToMeta.entries()) {
      let found = null;
      if (/^RZN-/i.test(oznaka)) {
        const r = await fetchCuttingToolByBarcode(oznaka);
        if (r.ok && r.data?.id) found = r.data;
      }
      if (!found) {
        const r = await fetchCuttingToolByOznaka(oznaka);
        if (r.ok && r.data?.id) found = r.data;
      }
      if (found) {
        result.existingCatalog.push({ oznaka, id: found.id, naziv: found.naziv });
        result.catalogByOznaka.set(oznaka, found.id);
      } else {
        result.newCatalog.push({
          oznaka,
          naziv: meta.naziv,
          klasa: meta.klasa,
          masine: Array.from(meta.masine),
        });
        /* placeholder za auto-create — id će biti popunjen u runImport */
        result.catalogByOznaka.set(oznaka, null);
      }
    }

    /* 3. Skupi unique mašine */
    for (const r of rows) {
      const m = String(r.masina || '').trim();
      if (m) result.machineCodes.add(m);
    }

    /* 4. Skupi unique primaoce (samo MACHINE i EMPLOYEE primaoci se moraju resolve-ovati strogo) */
    const namesNeedingResolve = new Set();
    for (const r of rows) {
      const tip = (r.tip || 'TOOL').toUpperCase();
      const primTip = (r.primalac_tip || 'EMPLOYEE').toUpperCase();
      if (tip === 'CUTTING_TOOL' || primTip === 'EMPLOYEE' || primTip === 'MACHINE') {
        /* Za "Luka Stanić, Lazar Jovanović" — uzmi prvog kao potpisnika */
        const primary = String(r.primalac || '').split(/\s*,\s*/)[0].trim();
        if (primary) namesNeedingResolve.add(primary);
      }
    }

    for (const name of namesNeedingResolve) {
      const found = await resolveEmployeeFuzzy(name);
      if (found) {
        result.resolvedEmployees.set(name, { id: found.id, full_name: found.full_name });
      } else {
        result.missingEmployees.push(name);
      }
    }

    /* 5. Broj dokumenata = unique (tip, primalac, mašina, datum) */
    const docKeys = new Set();
    for (const r of rows) {
      const tip = (r.tip || 'TOOL').toUpperCase();
      const primTip = (r.primalac_tip || 'EMPLOYEE').toUpperCase();
      const primary = String(r.primalac || '').split(/\s*,\s*/)[0].trim();
      docKeys.add([tip, primTip, primary, r.masina || '', r.datum || ''].join('|'));
    }
    result.docCount = docKeys.size;

    /* 6. Detekcija duplikat-importa: za svaku mašinu iz CSV-a, proveri da li
     * postoji aktivan CUTTING_TOOL revers (OPEN ili PARTIALLY_RETURNED).
     * Sprečava nehotice dupli import koji pravi 2 dokumenta za istu mašinu
     * sa istim alatom — što je greška u 99% slučajeva i razbija stock balans. */
    if (result.machineCodes.size > 0) {
      const machineList = Array.from(result.machineCodes).map((m) => encodeURIComponent(m)).join(',');
      const url = `rev_documents?select=id,doc_number,recipient_machine_code,issued_at,issued_to_employee_name,status&doc_type=eq.CUTTING_TOOL&status=in.(OPEN,PARTIALLY_RETURNED)&recipient_machine_code=in.(${machineList})&order=issued_at.desc`;
      try {
        const sb = await import('../../services/supabase.js');
        const dupRows = await sb.sbReq(url);
        if (Array.isArray(dupRows)) {
          for (const d of dupRows) {
            result.duplicateDocs.push({
              machine: d.recipient_machine_code,
              doc_number: d.doc_number,
              issued_at: d.issued_at,
              employee: d.issued_to_employee_name,
              status: d.status,
            });
          }
        }
      } catch (e) {
        console.warn('[reversi/import] duplicate check failed (non-fatal)', e);
      }
    }

    return result;
  }

  function todayIso() {
    return new Date().toISOString().slice(0, 10);
  }

  async function importRevers(rows, analysis) {
    /* Auto-create catalog za nove oznake — koristi analysis.newCatalog */
    /* eslint-disable no-console */
    const idbg = (msg, data) => console.log(`[reversi/import] ${msg}`, data);
    const magId = await getMagacinLocationId();
    idbg('start', { magId, newCatalog: analysis.newCatalog.length, rows: rows.length });
    if (!magId) {
      console.error('[reversi/import] magId je null — ALAT-MAG-01 ne postoji ili cache zastareo');
      showToast('Magacin lokacija nije pronađena. Hard refresh (Ctrl+Shift+R) pa probaj opet.');
      state.progress.fail = rows.length;
      paint();
      return;
    }
    for (const nc of analysis.newCatalog) {
      const payload = {
        oznaka: nc.oznaka,
        naziv: nc.naziv,
        klasa: nc.klasa || null,
        compatible_machine_codes: nc.masine,
        unit: 'kom',
        status: 'active',
      };
      const ins = await insertCuttingTool(payload);
      if (!ins.ok) {
        /* Catalog auto-create fail — sve linije sa tom oznakom će biti skipped */
        analysis.catalogByOznaka.set(nc.oznaka, null);
        continue;
      }
      analysis.catalogByOznaka.set(nc.oznaka, ins.data.id);
      /* Bez seed stocka — alat je odmah „izdat na mašinu“; magacin balance ostaje 0,
       * recipient location dobija qty (uradi se kroz issueCuttingReversal). */
    }

    /* Grupiši po (tip, primalac_primary, masina, datum) → 1 dokument */
    const byDoc = new Map();
    for (const r of rows) {
      const tip = (r.tip || 'TOOL').toUpperCase();
      const primary = String(r.primalac || '').split(/\s*,\s*/)[0].trim();
      const datum = r.datum || todayIso();
      const key = [tip, r.primalac_tip, primary, r.masina || '', datum].join('|');
      if (!byDoc.has(key)) byDoc.set(key, { meta: { ...r, datum, primalac: primary }, lines: [], primalacRaw: r.primalac });
      byDoc.get(key).lines.push(r);
    }

    for (const grp of byDoc.values()) {
      const m = grp.meta;
      const tip = (m.tip || 'TOOL').toUpperCase();
      const primTip = (m.primalac_tip || 'EMPLOYEE').toUpperCase();

      try {
        if (tip === 'CUTTING_TOOL') {
          if (!m.masina) { state.progress.fail += grp.lines.length; paint(); continue; }
          const emp = analysis.resolvedEmployees.get(m.primalac);
          if (!emp) { state.progress.fail += grp.lines.length; paint(); continue; }

          const lines = [];
          const qtyByCat = new Map(); /* catalog_id -> total qty u ovoj grupi */
          for (const ln of grp.lines) {
            const oznaka = String(ln.alat_oznaka_ili_barkod || '').trim();
            const catId = analysis.catalogByOznaka.get(oznaka);
            if (!catId) continue;
            const qty = Number(ln.kolicina) || 1;
            lines.push({ catalog_id: catId, quantity: qty });
            qtyByCat.set(catId, (qtyByCat.get(catId) || 0) + qty);
          }
          if (lines.length === 0) { state.progress.fail += grp.lines.length; paint(); continue; }

          /* Pre-seed magacin sa potrebnom količinom (RPC issueCuttingReversal će
           * dekrementovati magacin za qty; ako magacin nema balance, CHECK puca).
           * Virtuelni put: nabavljen → magacin → odmah izdat na mašinu. */
          idbg(`pre-seed grupe ${m.masina}`, { catCount: qtyByCat.size, totalQty: Array.from(qtyByCat.values()).reduce((a, b) => a + b, 0) });
          let seedFail = false;
          let seedFailReason = '';
          let seedCount = 0;
          for (const [catId, qty] of qtyByCat.entries()) {
            const seed = await seedCuttingToolStock(catId, magId, qty);
            if (!seed.ok) {
              seedFailReason = `cat=${catId} qty=${qty} → ${seed.error}`;
              console.error('[reversi/import] seed pao', { catId, qty, magId, err: seed.error });
              seedFail = true;
              break;
            }
            seedCount += 1;
          }
          idbg(`seed gotov ${m.masina}`, { ok: seedCount, fail: seedFail ? 1 : 0, reason: seedFailReason });
          if (seedFail) {
            showToast(`Seed magacina pao: ${seedFailReason}`);
            state.progress.fail += grp.lines.length;
            paint();
            continue;
          }

          /* Ako su bile dve osobe u koloni primaoca, dodaj drugu u napomenu */
          let napomena = m.napomena || null;
          const allNames = String(grp.primalacRaw || '').split(/\s*,\s*/).map((s) => s.trim()).filter(Boolean);
          if (allNames.length > 1) {
            const second = allNames.slice(1).join(', ');
            napomena = `${napomena ? napomena + ' | ' : ''}Drugi potpisnik(i): ${second}`;
          }

          idbg(`issueCuttingReversal call ${m.masina}`, { lines: lines.length, emp: emp.full_name });
          const res = await issueCuttingReversal({
            recipient_machine_code: m.masina,
            issued_to_employee_id: emp.id,
            issued_to_employee_name: emp.full_name,
            expected_return_date: m.rok_povracaja || null,
            napomena,
            lines,
          });
          idbg(`issueCuttingReversal result ${m.masina}`, { ok: res.ok, error: res.error, doc_number: res.data?.doc_number });
          if (res.ok) {
            state.progress.ok += grp.lines.length;
          } else {
            state.progress.fail += grp.lines.length;
            showToast(`Reverz pao za mašinu ${m.masina}: ${res.error}`);
          }
        } else {
          /* TOOL ili COOPERATION_GOODS — koristi postojeći issueReversal */
          const payload = {
            doc_type: tip,
            recipient_type: primTip,
            recipient_employee_id: null,
            recipient_employee_name: null,
            recipient_department: null,
            recipient_company_name: null,
            expected_return_date: m.rok_povracaja || null,
            napomena: m.napomena || null,
            lines: [],
          };
          if (primTip === 'EMPLOYEE') {
            const e = analysis.resolvedEmployees.get(m.primalac);
            if (e) {
              payload.recipient_employee_id = e.id;
              payload.recipient_employee_name = e.full_name;
            } else {
              /* missingEmployees za EMPLOYEE smo već blokirali u UI-u, ne bi smelo doći ovde */
              state.progress.fail += grp.lines.length;
              paint();
              continue;
            }
          } else if (primTip === 'DEPARTMENT') {
            payload.recipient_department = m.primalac;
          } else if (primTip === 'EXTERNAL_COMPANY') {
            payload.recipient_company_name = m.primalac;
          }
          for (const ln of grp.lines) {
            payload.lines.push({
              line_type: 'TOOL',
              tool_id: null,
              part_name: ln.alat_oznaka_ili_barkod,
              drawing_no: '',
              quantity: Number(ln.kolicina) || 1,
              unit: 'kom',
              napomena: ln.napomena || '',
            });
          }
          const res = await issueReversal(payload);
          if (res.ok) state.progress.ok += grp.lines.length;
          else state.progress.fail += grp.lines.length;
        }
      } catch (e) {
        console.error('[bulkImport/revers] grp fail', e);
        state.progress.fail += grp.lines.length;
      }
      paint();
    }
  }

  paint();
}

function parseCsvToObjects(text) {
  const lines = text.replace(/﻿/, '').split(/\r?\n/).filter((l) => l.trim() !== '');
  if (lines.length === 0) return [];
  const splitCsv = (line) => {
    const out = [];
    let cur = '';
    let inQ = false;
    for (let i = 0; i < line.length; i += 1) {
      const ch = line[i];
      if (ch === '"') {
        if (inQ && line[i + 1] === '"') { cur += '"'; i += 1; }
        else inQ = !inQ;
      } else if (ch === ',' && !inQ) {
        out.push(cur); cur = '';
      } else {
        cur += ch;
      }
    }
    out.push(cur);
    return out;
  };
  const headers = splitCsv(lines[0]).map((h) => h.trim());
  return lines.slice(1).map((ln) => {
    const cells = splitCsv(ln);
    const obj = {};
    headers.forEach((h, i) => { obj[h] = cells[i] ?? ''; });
    return obj;
  });
}
