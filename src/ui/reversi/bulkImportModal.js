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
  confirmCuttingReturn,
  confirmReturn,
} from '../../services/reversiService.js';
import { sbReq } from '../../services/supabase.js';

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
  { key: 'minimalna_zaliha', label: 'Minimalna zaliha', type: 'number',
    aliases: ['minimalna zaliha', 'min zaliha', 'minimalna količina', 'minimum', 'min', 'reorder level'] },
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

/** Lista primalaca iz CSV (zarez), trim, dedupe. */
function parseRecipientList(raw) {
  return [...new Set(String(raw || '').split(/\s*,\s*/).map((x) => x.trim()).filter(Boolean))];
}

async function sha256HexUtf8(text) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
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
      if (c.key === 'minimalna_zaliha') return '0';
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
    progress: { ok: 0, fail: 0, skipped: 0, total: 0 },
    /* Reversi pre-pass rezultat: šta će biti kreirano (catalog) i šta nedostaje (employees) */
    analysis: null, // { newCatalog: [...], existingCatalog: [...], missingEmployees: [...], resolvedEmployees: Map, machineCodes: Set, docCount, lineCount }
    analyzing: false,
    sourceFileName: '',
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

        ${state.importing ? `<div class="rev-loading-card">Uvozim ${state.progress.ok + state.progress.fail + (state.progress.skipped || 0)} / ${state.progress.total}…</div>` : ''}
      </div>`;

    const validRowsCount = state.rows.filter((r) => validateRow(r, typeDef).length === 0).length;
    const blockedByAnalysis =
      state.type === 'revers' &&
      (state.analyzing ||
        (state.analysis &&
          (state.analysis.missingEmployees.length > 0 ||
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
    if (typeDef.id === 'cutting' && r.minimalna_zaliha !== '' && r.minimalna_zaliha != null) {
      const raw = String(r.minimalna_zaliha).replace(/\s/g, '').replace(',', '.');
      const mx = Number(raw);
      if (!Number.isFinite(mx) || mx < 0) errs.push('minimalna zaliha mora biti broj ≥ 0');
      else if (Math.floor(mx) !== mx) errs.push('minimalna zaliha mora biti ceo broj (kom)');
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
    const blocking = a.missingEmployees.length > 0 || (hasDup && !a.forceImportConfirmed);
    const blockReasons = [];
    if (a.missingEmployees.length > 0) {
      blockReasons.push(`${a.missingEmployees.length} radnika nedostaje u Kadrovskoj`);
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
                <span class="rev-muted" style="font-size:12px;align-self:center">Ovo dodaje još jedan dokument; dupli obrt u magacin/mašinu. Za ispravku količine ili mašine na postojećem dokumentu koristi ručnu korekciju u bazi ili storno pa ponovo import bez istog uvoznog hasha.</span>
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
      state.sourceFileName = file.name || '';
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
    state.progress = { ok: 0, fail: 0, skipped: 0, total: valid.length };
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
    const sk = state.progress.skipped || 0;
    showToast(
      sk > 0
        ? `✓ Uvezeno: ${state.progress.ok}, preskočeno (već postoji isti uvoz): ${sk}, neuspešno: ${state.progress.fail}`
        : `✓ Uvezeno: ${state.progress.ok}, neuspešno: ${state.progress.fail}`,
    );
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
      const minRaw = r.minimalna_zaliha !== '' && r.minimalna_zaliha != null
        ? Math.max(0, Math.floor(Number(String(r.minimalna_zaliha).replace(/\s/g, '').replace(',', '.')) || 0))
        : 0;
      const payload = {
        oznaka: r.oznaka,
        naziv: r.naziv,
        klasa: r.klasa || null,
        compatible_machine_codes: machines,
        unit: r.jedinica || 'kom',
        napomena: r.napomena || null,
        status: 'active',
        min_stock_qty: minRaw,
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

    /* 4. Skupi primalce koje treba resolve-ovati (zarez = više operatera) */
    const namesNeedingResolve = new Set();
    for (const r of rows) {
      const tip = (r.tip || 'TOOL').toUpperCase();
      const primTip = (r.primalac_tip || 'EMPLOYEE').toUpperCase();
      let names = [];
      if (tip === 'CUTTING_TOOL' || primTip === 'EMPLOYEE' || primTip === 'MACHINE') {
        names = parseRecipientList(r.primalac);
      }
      for (const nm of names) {
        if (nm) namesNeedingResolve.add(nm);
      }
    }

    for (const name of namesNeedingResolve) {
      const found = await resolveEmployeeFuzzy(name);
      if (found) {
        result.resolvedEmployees.set(name, { id: found.id, full_name: found.full_name });
      } else {
        result.missingEmployees.push(`Radnik ne postoji u Kadrovskoj: ${name}`);
      }
    }

    /* 5. Broj dokumenata = unique (tip, lista primalaca sortirana, mašina, datum) */
    const docKeys = new Set();
    for (const r of rows) {
      const tip = (r.tip || 'TOOL').toUpperCase();
      const primTip = (r.primalac_tip || 'EMPLOYEE').toUpperCase();
      let primKey = String(r.primalac || '').split(/\s*,\s*/)[0].trim();
      if (tip === 'CUTTING_TOOL') {
        primKey = parseRecipientList(r.primalac)
          .slice()
          .sort((a, b) => normalizeName(a).localeCompare(normalizeName(b)))
          .join('|');
      }
      docKeys.add([tip, primTip, primKey, r.masina || '', r.datum || ''].join('|'));
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
    /* Rollback: pamtimo sve uspešno kreirane doc_id-jeve i auto-kreirane catalog
     * id-jeve — ako user želi da poništi, koristi se za batch storno. */
    const importSession = {
      id: `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      startedAt: new Date().toISOString(),
      docIds: [],
      newCatalogIds: [],
    };
    idbg('start', { newCatalog: analysis.newCatalog.length, rows: rows.length });
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
      importSession.newCatalogIds.push(ins.data.id);
      /* Bez seed stocka — alat je odmah „izdat na mašinu“; magacin balance ostaje 0,
       * recipient location dobija qty (uradi se kroz issueCuttingReversal). */
    }

    /* Grupiši po (tip, primalci, mašina, datum) → 1 dokument */
    const byDoc = new Map();
    for (const r of rows) {
      const tip = (r.tip || 'TOOL').toUpperCase();
      const datum = r.datum || todayIso();
      let key;
      if (tip === 'CUTTING_TOOL') {
        const ppl = parseRecipientList(r.primalac)
          .slice()
          .sort((a, b) => normalizeName(a).localeCompare(normalizeName(b)));
        const pk = ppl.join('|');
        key = [tip, r.primalac_tip, pk, r.masina || '', datum].join('|');
      } else {
        const primary = String(r.primalac || '').split(/\s*,\s*/)[0].trim();
        key = [tip, r.primalac_tip, primary, r.masina || '', datum].join('|');
      }
      if (!byDoc.has(key)) {
        const people = tip === 'CUTTING_TOOL'
          ? parseRecipientList(r.primalac)
          : [String(r.primalac || '').split(/\s*,\s*/)[0].trim()].filter(Boolean);
        const primaryOne = tip === 'CUTTING_TOOL'
          ? (people[0] || '')
          : String(r.primalac || '').split(/\s*,\s*/)[0].trim();
        byDoc.set(key, {
          meta: { ...r, datum, primalacList: people, primalac: primaryOne },
          lines: [],
          primalacRaw: r.primalac,
        });
      }
      byDoc.get(key).lines.push(r);
    }

    for (const grp of byDoc.values()) {
      const m = grp.meta;
      const tip = (m.tip || 'TOOL').toUpperCase();
      const primTip = (m.primalac_tip || 'EMPLOYEE').toUpperCase();

      try {
        if (tip === 'CUTTING_TOOL') {
          if (!m.masina) { state.progress.fail += grp.lines.length; paint(); continue; }
          const people = Array.isArray(m.primalacList) && m.primalacList.length > 0
            ? m.primalacList
            : parseRecipientList(grp.primalacRaw || '');
          const primaryName = people[0];
          const primaryEmp = analysis.resolvedEmployees.get(primaryName);
          if (!primaryName || !primaryEmp) { state.progress.fail += grp.lines.length; paint(); continue; }

          const assigneesPayload = [];
          for (let pi = 0; pi < people.length; pi += 1) {
            const pnm = people[pi];
            const e = analysis.resolvedEmployees.get(pnm);
            if (!e) continue;
            assigneesPayload.push({ employee_id: e.id, role: pi === 0 ? 'PRIMARY' : 'SECONDARY' });
          }
          if (assigneesPayload.length === 0 || !assigneesPayload.some((a) => a.role === 'PRIMARY')) {
            state.progress.fail += grp.lines.length;
            paint();
            continue;
          }

          const lines = [];
          for (const ln of grp.lines) {
            const oznaka = String(ln.alat_oznaka_ili_barkod || '').trim();
            const catId = analysis.catalogByOznaka.get(oznaka);
            if (!catId) continue;
            const qty = Number(ln.kolicina) || 1;
            lines.push({ catalog_id: catId, quantity: qty });
          }
          if (lines.length === 0) { state.progress.fail += grp.lines.length; paint(); continue; }

          let napomena = m.napomena || null;
          if (people.length > 1) {
            napomena = `${napomena ? `${napomena} | ` : ''}Drugi potpisnik(i): ${people.slice(1).join(', ')}`;
          }

          const lineSig = grp.lines
            .map((ln) => `${String(ln.alat_oznaka_ili_barkod || '').trim()}:${Number(ln.kolicina) || 1}`)
            .sort()
            .join(';');
          const legacyKey = await sha256HexUtf8(
            `REVERSI|${state.sourceFileName || 'na'}|${m.masina}|${m.datum || ''}|${people.join('>')}|${lineSig}`,
          );

          idbg(`issueCuttingReversal call ${m.masina}`, { lines: lines.length, primary: primaryEmp.full_name });
          const issuePayload = {
            recipient_machine_code: m.masina,
            issued_to_employee_id: primaryEmp.id,
            issued_to_employee_name: primaryEmp.full_name,
            expected_return_date: m.rok_povracaja || null,
            napomena,
            lines,
            legacy_skip_source_decrement: true,
            bulk_import_legacy_key: legacyKey,
          };
          if (assigneesPayload.length > 1) {
            issuePayload.assignees = assigneesPayload;
          }
          const res = await issueCuttingReversal(issuePayload);
          idbg(`issueCuttingReversal result ${m.masina}`, {
            ok: res.ok,
            error: res.error,
            doc_number: res.data?.doc_number,
            idempotent: res.data?.idempotent,
          });
          if (res.ok) {
            if (res.data?.idempotent) {
              state.progress.skipped = (state.progress.skipped || 0) + grp.lines.length;
              showToast(
                `Preskočeno — isti bulk ključ (dokument već postoji): ${String(res.data?.doc_number || res.data?.doc_id || '')}`,
              );
            } else {
              state.progress.ok += grp.lines.length;
              if (res.data?.doc_id) importSession.docIds.push(res.data.doc_id);
            }
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
          if (res.ok) {
            state.progress.ok += grp.lines.length;
            if (res.data?.doc_id) importSession.docIds.push(res.data.doc_id);
          } else {
            state.progress.fail += grp.lines.length;
          }
        }
      } catch (e) {
        console.error('[bulkImport/revers] grp fail', e);
        state.progress.fail += grp.lines.length;
      }
      paint();
    }

    /* Snimi session u localStorage za rollback. Čuva se poslednje 5 sesija. */
    if (importSession.docIds.length > 0) {
      try {
        const key = 'reversi:importSessions';
        const existing = JSON.parse(localStorage.getItem(key) || '[]');
        existing.unshift({
          ...importSession,
          finishedAt: new Date().toISOString(),
          ok: state.progress.ok,
          fail: state.progress.fail,
        });
        localStorage.setItem(key, JSON.stringify(existing.slice(0, 5)));
        idbg('session saved', { id: importSession.id, docs: importSession.docIds.length, newCatalog: importSession.newCatalogIds.length });
      } catch (e) {
        console.warn('[reversi/import] session save failed (non-fatal)', e);
      }
    }
  }

  paint();
}

/* ──────────────────────────────────────────────────────────────────
 * Rollback bulk importa
 *
 * Otvara modal sa listom poslednjih sesija (čuvanih u localStorage).
 * Klik na „Storniraj sesiju" →
 *   1. Za svaki doc_id iz sesije, pozovi rev_confirm_cutting_return
 *      sa svim qty po liniji → status = RETURNED, stock se vrati u magacin.
 *   2. Sesija se ukloni iz localStorage.
 *
 * NAPOMENA: ne BRIŠE auto-kreirane catalog redove (RZN-…). Ako želiš da
 * se i oni obrišu, otvori Reversi → Rezni alat → izbriši pojedinačno.
 * ────────────────────────────────────────────────────────────────── */

function loadImportSessions() {
  try {
    return JSON.parse(localStorage.getItem('reversi:importSessions') || '[]');
  } catch {
    return [];
  }
}

function saveImportSessions(arr) {
  try {
    localStorage.setItem('reversi:importSessions', JSON.stringify(arr));
  } catch {
    /* localStorage full — ignoriši */
  }
}

export function openImportRollbackModal(opts = {}) {
  const id = `revImpRollback_${Date.now()}`;
  const overlay = document.createElement('div');
  overlay.innerHTML = `
    <div class="kadr-modal-overlay rev-modal-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal rev-modal" style="max-width:720px">
        <div class="kadr-modal-header">
          <h2>🔄 Storno bulk importa</h2>
          <button type="button" class="kadr-modal-close" data-imp-rb-close>×</button>
        </div>
        <div class="kadr-modal-body rev-modal-body" id="revImpRbBody"></div>
        <div class="kadr-modal-footer rev-modal-footer">
          <button type="button" class="rev-btn" data-imp-rb-close>Zatvori</button>
        </div>
      </div>
    </div>`;
  const root = overlay.firstElementChild;
  document.body.appendChild(root);

  root.addEventListener('click', (e) => {
    if (e.target === root) root.remove();
    else if (e.target.closest('[data-imp-rb-close]')) root.remove();
  });

  const body = root.querySelector('#revImpRbBody');

  function paint() {
    const sessions = loadImportSessions();
    if (sessions.length === 0) {
      body.innerHTML = `<p class="rev-muted">Nema poslednjih bulk importa za storno. Sesije se pamte u browser localStorage-u (samo za ovog korisnika, na ovoj mašini).</p>`;
      return;
    }
    body.innerHTML = `
      <p class="rev-muted">Poslednjih ${sessions.length} bulk importa. „Storniraj" će <strong>vratiti sve stavke u magacin</strong> i markirati dokumente kao RETURNED. Auto-kreirane šifre (RZN-…) ostaju u katalogu.</p>
      <div class="rev-imp-rb-list">
        ${sessions
          .map(
            (s, idx) => `
          <div class="rev-imp-rb-card" data-imp-rb-idx="${idx}">
            <div>
              <strong>${escHtml(new Date(s.finishedAt || s.startedAt).toLocaleString('sr-Latn-RS'))}</strong>
              <div class="rev-muted" style="font-size:12px">
                ${escHtml(String(s.docIds?.length || 0))} dokumenata, ${escHtml(String(s.newCatalogIds?.length || 0))} novih šifri ·
                ✓ ${escHtml(String(s.ok || 0))} / ⚠ ${escHtml(String(s.fail || 0))}
              </div>
            </div>
            <div style="display:flex;gap:8px">
              <button type="button" class="rev-btn rev-btn--secondary" data-imp-rb-forget="${idx}" title="Ukloni sesiju iz liste (bez stornijanja u bazi)">Zaboravi</button>
              <button type="button" class="rev-btn" style="background:#c46e1f;color:#fff" data-imp-rb-cancel="${idx}">🔄 Storniraj</button>
            </div>
          </div>`,
          )
          .join('')}
      </div>`;

    body.querySelectorAll('[data-imp-rb-forget]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const idx = Number(btn.getAttribute('data-imp-rb-forget'));
        const arr = loadImportSessions();
        arr.splice(idx, 1);
        saveImportSessions(arr);
        paint();
      });
    });

    body.querySelectorAll('[data-imp-rb-cancel]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const idx = Number(btn.getAttribute('data-imp-rb-cancel'));
        const sessions2 = loadImportSessions();
        const sess = sessions2[idx];
        if (!sess) return;
        // eslint-disable-next-line no-alert
        if (!confirm(`Storniraj ${sess.docIds.length} reverz dokumenta? Sve stavke će biti vraćene u magacin (RETURNED).`)) return;
        btn.disabled = true;
        btn.textContent = 'Storniram…';
        let ok = 0;
        let fail = 0;
        for (const docId of sess.docIds) {
          try {
            /* Dovuci linije dokumenta */
            const lines = await sbReq(`rev_document_lines?document_id=eq.${encodeURIComponent(docId)}&select=id,quantity,returned_quantity,line_type`);
            const linesArr = Array.isArray(lines) ? lines : [];
            const returnedLines = linesArr
              .filter((l) => Number(l.quantity) > Number(l.returned_quantity || 0))
              .map((l) => ({ line_id: l.id, returned_quantity: Number(l.quantity) - Number(l.returned_quantity || 0) }));
            if (returnedLines.length === 0) { ok += 1; continue; }
            /* Cutting tools koriste rev_confirm_cutting_return; ostale rev_confirm_return */
            const isCutting = linesArr.some((l) => l.line_type === 'CUTTING_TOOL');
            const fn = isCutting ? confirmCuttingReturn : confirmReturn;
            const res = await fn({ doc_id: docId, returned_lines: returnedLines });
            if (res.ok) ok += 1;
            else fail += 1;
          } catch (e) {
            console.error('[reversi/rollback] doc fail', { docId, e });
            fail += 1;
          }
        }
        if (fail === 0) {
          /* Sve uspelo — ukloni sesiju iz liste */
          const arr = loadImportSessions();
          arr.splice(idx, 1);
          saveImportSessions(arr);
          showToast(`✓ Stornirano ${ok} dokumenata. Stock vraćen u magacin.`);
        } else {
          showToast(`Storno: ${ok} uspešno, ${fail} neuspešno. Sesija ostaje u listi.`);
        }
        paint();
        opts.onSuccess?.();
      });
    });
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
