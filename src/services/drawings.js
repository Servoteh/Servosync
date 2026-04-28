/**
 * BigTehn crteži (PDF) — shared service.
 *
 * Centralizuje sav rad sa `bigtehn_drawings_cache` (metapodaci) i Supabase
 * Storage bucket-om `bigtehn-drawings` (signed URL za PDF preview u novom tabu).
 *
 * Koriste ga:
 *   - Modul "Praćenje proizvodnje" (`src/services/planProizvodnje.js`),
 *     koji re-exportuje `getBigtehnDrawingSignedUrl` radi backward-compat.
 *   - Modul "Plan Montaže" → polje „Veza sa“ na fazi
 *     (`src/ui/planMontaze/linkedDrawingsDialog.js`).
 *
 * Pravilo: NE diraj `bigtehn_*_cache` tabele iz frontenda — to su keš tabele
 * koje puni Bridge sync proces; ovde samo READ + signed URL.
 */

import {
  sbReq,
  getSupabaseUrl,
  getSupabaseAnonKey,
} from './supabase.js';
import { getCurrentUser, getIsOnline } from '../state/auth.js';
import { showToast } from '../lib/dom.js';

/** Storage bucket sa PDF crtežima (privatan, sve preko signed URL-a). */
export const BIGTEHN_DRAWINGS_BUCKET = 'bigtehn-drawings';

/** Default trajanje signed URL-a (5 min) — usklađeno sa planProizvodnje modulom. */
export const SIGNED_URL_TTL_SECONDS = 300;

/**
 * Rezoluje broj crteža na konkretan red iz `bigtehn_drawings_cache`.
 *
 * Strategija:
 *   1) Exact match (`drawing_no = brojCrteza`)
 *   2) Fallback: ako exact ne postoji, traži najnoviju reviziju
 *      (`drawing_no LIKE 'brojCrteza_*'` → uzmi najveću po sortiranju DESC).
 *      Ovo rešava čest slučaj gde BigTehn šalje broj bez sufiksa
 *      (npr. „1133219") a u Storage-u postoje samo revizije
 *      („1133219_A", „1133219_B").
 *
 * @returns {Promise<{ resolvedDrawingNo: string, storagePath: string,
 *                     isFallback: boolean } | null>}
 */
/**
 * Sanitizuje broj crteža iz BigTehn-a.
 *
 * BigTehn ima brojne data-quality probleme u koloni `broj_crteza`:
 *   - Leading/trailing whitespace (uobičajeno)
 *   - Trailing tačke: `1109245.`, `1117073..`, `1130518.` — verovatno
 *     copy-paste artefakti. Storage fajlovi su BEZ tačke.
 *   - Pure-dot vrednosti: `.`, `..`, `...` — placeholder kad tehnolog
 *     nije znao broj. Tretiramo kao prazno (vraćamo null).
 *
 * @returns {string|null} očišćen broj, ili null ako je placeholder/prazno
 */
export function sanitizeDrawingNo(brojCrteza) {
  if (brojCrteza == null) return null;
  let s = String(brojCrteza).trim();
  if (!s) return null;
  /* Skini leading/trailing tačke i razmake (npr. `..1133219.` → `1133219`,
     `1109245.` → `1109245`). */
  s = s.replace(/^[.\s]+/, '').replace(/[.\s]+$/, '');
  if (!s) return null;
  /* Pure-dot/garbage vrednosti (`.`, `..`, `...`) ostaće prazne nakon
     trim-a → vraćamo null. Dodatno: ako je nakon sanitizacije jedini
     karakter tačka/space (paranoja), tretiramo kao prazno. */
  if (/^[.\s]*$/.test(s)) return null;
  return s;
}

/**
 * Vraća true ako je broj crteža sanitizan-prazna ili placeholder vrednost
 * (npr. `.`, `..`, `   `, ``, null). Korisno UI-ju da NE renderuje PDF
 * dugme za garbage podatke iz BigTehn-a.
 */
export function isPlaceholderDrawingNo(brojCrteza) {
  return sanitizeDrawingNo(brojCrteza) === null;
}

/**
 * Batch provera: koji od datih brojeva crteža POSTOJE u Bridge keš-u
 * (exact match ili bilo koja revizija — `{code}_*`).
 *
 * Korisno za UI da prikaže 📄 PDF dugme SAMO za crteže koji su realno
 * u Bridge keš-u (nema smisla ponuditi „otvori PDF" za fajl koji ne
 * postoji — korisnik dobije zbunjujuću poruku posle klika).
 *
 * Implementacija:
 *   - Sanitizuje sve ulazne vrednosti (skida tačke, razmake) i odbacuje
 *     placeholdere (`.`, `..`, prazno).
 *   - Razdeli unique sanitizovane brojeve u batch-eve od 50, šalje za
 *     svaki batch jedan PostgREST query sa `or=(in.(...), like.X*, like.Y*)`.
 *   - Za svaki vraćeni `drawing_no`, izvuče bazu (skidanje sufiksa
 *     `_<alfanum>`) i ako je u traženom skupu, mark-uje kao postojeći.
 *
 * @param {Array<string|null|undefined>} brojCrtezaArr — sirov input iz BigTehn-a
 * @returns {Promise<Set<string>>} skup SANITIZOVANIH brojeva za koje POSTOJI fajl
 */
/** PostgREST: vrednost u zagradi mora biti u dvostrukim navodnicima ako sadrži `.`, `/`, itd. */
function postgrestQuotedAtom(s) {
  return `"${String(s).replace(/"/g, '""')}"`;
}

/** `like` filter za prefix `{code}_` + SQL `%` (PostgREST `*` na kraju). */
function postgrestLikeRevPrefix(code) {
  const p = String(code) + '_';
  if (/^[0-9A-Za-z_-]+$/.test(p)) {
    return `${p}*`;
  }
  return `${postgrestQuotedAtom(p)}*`;
}

export async function findExistingDrawings(brojCrtezaArr) {
  if (!getIsOnline()) return new Set();
  if (!Array.isArray(brojCrtezaArr) || brojCrtezaArr.length === 0) return new Set();

  /* 1) Sanitizuj + ukloni duplikate i placeholder vrednosti. */
  const requested = new Set();
  for (const v of brojCrtezaArr) {
    const s = sanitizeDrawingNo(v);
    if (s) requested.add(s);
  }
  if (requested.size === 0) return new Set();

  const codes = Array.from(requested);
  const found = new Set();

  /* 2) Batch po 50 — drži URL ispod ~4 KB (PostgREST/CF limit ~8 KB). */
  const BATCH = 50;
  for (let i = 0; i < codes.length; i += BATCH) {
    const chunk = codes.slice(i, i + BATCH);
    const chunkSet = new Set(chunk);

    /* PostgREST OR: exact-in + like za svaku reviziju.
       VAŽNO: NE koristiti encodeURIComponent() na delovima `or` vrednosti — ceo
       query-string enkoduje URLSearchParams JEDNOM. Duplo enkodovanje (`%2F`
       → `%252F`) lomi filter za crteže sa kosom crtom (`2.04-2081/4`) i
       čitav batch pada → UI misli da nema PDF-ova ili daje pogrešne flag-ove. */
    const inList = chunk.map(postgrestQuotedAtom).join(',');
    const orParts = [`drawing_no.in.(${inList})`];
    for (const c of chunk) {
      /* Prefix `{code}_` + wildcard (isti smisao kao resolveBigtehnDrawing). */
      orParts.push(`drawing_no.like.${postgrestLikeRevPrefix(c)}`);
    }
    const params = new URLSearchParams();
    params.set('select', 'drawing_no,storage_path');
    params.set('removed_at', 'is.null');
    params.set('or', `(${orParts.join(',')})`);
    params.set('limit', '5000');

    let rows;
    try {
      rows = await sbReq(`bigtehn_drawings_cache?${params.toString()}`);
    } catch (e) {
      console.warn('[drawings.findExisting] batch failed', { from: i, size: chunk.length, e });
      continue;
    }
    if (!Array.isArray(rows)) continue;

    for (const r of rows) {
      const dn = String(r?.drawing_no || '');
      const sp = String(r?.storage_path || '').trim();
      if (!dn || !sp) continue;
      /* Exact match? */
      if (chunkSet.has(dn)) {
        found.add(dn);
        continue;
      }
      /* Revizija? — split na poslednje "_": ako je sufiks alfanumerički
         (uključujući prazan: `1117721_`), baza mora biti u traženom skupu. */
      const idx = dn.lastIndexOf('_');
      if (idx > 0) {
        const base = dn.slice(0, idx);
        const suffix = dn.slice(idx + 1);
        if (/^[A-Z0-9]*$/i.test(suffix) && chunkSet.has(base)) {
          found.add(base);
        }
      }
    }
  }

  return found;
}

export async function resolveBigtehnDrawing(brojCrteza) {
  const code = sanitizeDrawingNo(brojCrteza);
  if (!code) {
    console.warn('[drawings.resolve] empty/placeholder brojCrteza:', JSON.stringify(brojCrteza));
    return null;
  }
  if (!getIsOnline()) {
    console.warn('[drawings.resolve] offline → cannot resolve', code);
    return null;
  }
  /* 1) Exact match na sanitizovan code */
  {
    const p = new URLSearchParams();
    p.set('select', 'drawing_no,storage_path');
    p.set('drawing_no', `eq.${code}`);
    p.set('removed_at', 'is.null');
    p.set('limit', '1');
    const rows = await sbReq(`bigtehn_drawings_cache?${p.toString()}`);
    if (Array.isArray(rows) && rows[0]?.storage_path) {
      return {
        resolvedDrawingNo: rows[0].drawing_no || code,
        storagePath: rows[0].storage_path,
        isFallback: false,
      };
    }
  }

  /* 2) Fallback: traži revizije (`{code}_X`).
     PostgREST `like.foo*` mapira `*` → SQL `%`. Underscore (`_`) ostaje
     SQL single-char wildcard, što odgovara našim sufiksima (`_A`, `_B`),
     ali zbog sigurnosti dodatno filtriramo na klijentu. */
  const p = new URLSearchParams();
  p.set('select', 'drawing_no,storage_path');
  p.set('drawing_no', `like.${code}*`);
  p.set('removed_at', 'is.null');
  p.set('order', 'drawing_no.desc');
  p.set('limit', '50');
  const rows = await sbReq(`bigtehn_drawings_cache?${p.toString()}`);
  if (!Array.isArray(rows) || rows.length === 0) {
    console.warn('[drawings.resolve] no rows in cache for', code, 'or revisions (Bridge sync ne pokriva ovaj fajl?)');
    return null;
  }
  const prefix = code + '_';
  const candidates = rows.filter(r => {
    const dn = String(r?.drawing_no || '');
    return dn === code || dn.startsWith(prefix);
  });
  if (candidates.length === 0) {
    console.warn('[drawings.resolve] no matching revisions for', code, '— rows:', rows.map(r => r.drawing_no));
    return null;
  }
  /* Već sortirano `drawing_no.desc` → prvi je „najveći" sufiks (B > A). */
  const top = candidates[0];
  if (!top.storage_path) {
    console.warn('[drawings.resolve] candidate without storage_path', top);
    return null;
  }
  return {
    resolvedDrawingNo: top.drawing_no || code,
    storagePath: top.storage_path,
    isFallback: top.drawing_no !== code,
  };
}

/**
 * Vraća signed URL (default 5 min) za PDF crtež po broju crteža.
 * Sa auto-revision fallback-om: ako exact `brojCrteza` ne postoji u kešu,
 * koristi najnoviju reviziju (npr. „1133219" → „1133219_B").
 * Vraća null ako ni jedna revizija ne postoji.
 *
 * @param {string} brojCrteza  Naziv crteža (= naziv fajla bez .pdf)
 * @param {number} [expiresIn=SIGNED_URL_TTL_SECONDS]
 */
export async function getBigtehnDrawingSignedUrl(brojCrteza, expiresIn = SIGNED_URL_TTL_SECONDS) {
  const resolved = await resolveBigtehnDrawing(brojCrteza);
  if (!resolved) return null;
  return await signBigtehnDrawingsStoragePath(resolved.storagePath, expiresIn);
}

/**
 * Potpisuje postojeći `storage_path` u bucket-u `bigtehn-drawings` (bez lookup-a
 * u `bigtehn_drawings_cache`). Koristi istu logiku kao `getBigtehnDrawingSignedUrl`
 * posle resolve koraka.
 *
 * @param {string} storagePath  npr. `1061228_B.pdf`
 * @param {number} [expiresIn]
 * @returns {Promise<string|null>}
 */
export async function signBigtehnDrawingsStoragePath(storagePath, expiresIn = SIGNED_URL_TTL_SECONDS) {
  return await _signStoragePath(storagePath, expiresIn);
}

/**
 * Izvlači relativni signed path iz JSON odgovora Storage API-ja.
 * Novije verzije ponekad vraćaju **niz** `[{ signedUrl, error, path }]`
 * umesto `{ signedURL }` — staro `const { signedURL } = await r.json()` onda
 * uvek daje `undefined` i PDF „nikad ne radi“.
 */
function _pickStorageSignRelativeUrl(json) {
  if (json == null) return null;
  if (Array.isArray(json)) {
    const row = json[0];
    if (row?.error) {
      console.warn('[drawings.sign] API row error', row.error, row.path);
    }
    return row?.signedURL || row?.signedUrl || null;
  }
  if (typeof json === 'object') {
    if (json.signedURL || json.signedUrl) {
      return json.signedURL || json.signedUrl;
    }
    if (json.data != null) return _pickStorageSignRelativeUrl(json.data);
  }
  return null;
}

function _absoluteSignedUrl(baseUrl, rel) {
  if (!rel) return null;
  if (/^https?:\/\//i.test(rel)) return rel;
  return baseUrl + '/storage/v1' + (rel.startsWith('/') ? rel : '/' + rel);
}

/** Za ostale servise koji ručno zovu `/storage/v1/object/sign/…`. */
export function parseSupabaseStorageSignResponse(json) {
  return _pickStorageSignRelativeUrl(json);
}

export function absolutizeSupabaseStorageSignedPath(baseUrl, rel) {
  return _absoluteSignedUrl(baseUrl, rel);
}

/**
 * Helper koji potpisuje storage path → vraća apsolutni signed URL.
 * Interna implementacija — ne export-ujemo da ne curi van modula.
 */
async function _signStoragePath(storagePath, expiresIn) {
  const user = getCurrentUser();
  const token = user?._token || getSupabaseAnonKey();
  const apiKey = getSupabaseAnonKey();
  const baseUrl = getSupabaseUrl();
  if (!baseUrl || !apiKey) {
    console.error('[drawings.sign] missing Supabase config (baseUrl/apiKey)');
    return null;
  }
  const headers = {
    'Authorization': 'Bearer ' + token,
    'apikey': apiKey,
    'Content-Type': 'application/json',
  };
  try {
    /* 1) Preferirano: `POST /object/sign/{bucket}` sa `{ paths: [...] }` — isto
       kao `createSignedUrls` u SDK-u; izbegava probleme sa enkodiranjem putanje
       u samom URL-u. */
    const rBatch = await fetch(
      `${baseUrl}/storage/v1/object/sign/${BIGTEHN_DRAWINGS_BUCKET}`,
      {
        method: 'POST',
        headers,
        body: JSON.stringify({ expiresIn, paths: [storagePath] }),
      },
    );
    if (rBatch.ok) {
      const jBatch = await rBatch.json().catch(() => null);
      const relB = _pickStorageSignRelativeUrl(jBatch);
      const fullB = _absoluteSignedUrl(baseUrl, relB);
      if (fullB) {
        return fullB;
      }
    } else {
      const tb = await rBatch.text().catch(() => '');
      console.warn('[drawings.sign] batch HTTP', rBatch.status, tb.slice(0, 240));
    }

    /* 2) Fallback: legacy `POST /object/sign/{bucket}/{path}` */
    const r = await fetch(
      `${baseUrl}/storage/v1/object/sign/${BIGTEHN_DRAWINGS_BUCKET}/${encodeURIComponent(storagePath)}`,
      {
        method: 'POST',
        headers,
        body: JSON.stringify({ expiresIn }),
      },
    );
    if (!r.ok) {
      const txt = await r.text().catch(() => '');
      console.error('[drawings.sign] HTTP', r.status, 'for', storagePath, '→', txt.slice(0, 300));
      if (!user?._token) {
        console.warn('[drawings.sign] nema korisničkog JWT — bucket bigtehn-drawings dozvoljava samo authenticated');
      }
      return null;
    }
    const j = await r.json().catch(() => null);
    const rel = _pickStorageSignRelativeUrl(j);
    const fullUrl = _absoluteSignedUrl(baseUrl, rel);
    if (!fullUrl) {
      console.error('[drawings.sign] response missing signed URL', { storagePath, j });
      return null;
    }
    return fullUrl;
  } catch (e) {
    console.error('[drawings.sign] exception', e);
    return null;
  }
}

/**
 * Vrati metapodatke jednog crteža po broju crteža (drawing_no).
 *
 * Sa auto-revision fallback-om (isto kao `resolveBigtehnDrawing`):
 *   1) Exact match na `drawing_no`.
 *   2) Ako exact nema → najnovija revizija (`{drawingNo}_*`).
 *
 * Korisno u Plan Montaži dialogu „Veza sa" gde korisnik tipuje broj
 * bez sufiksa (npr. „1133219") a u Bridge cache-u postoje samo revizije.
 *
 * @param {string} drawingNo
 * @returns {Promise<{drawing_no:string, storage_path:string, file_name:string, mime_type:string|null, size_bytes:number|null, _isFallback?:boolean}|null>}
 */
export async function getDrawingByNumber(drawingNo) {
  if (!getIsOnline() || !drawingNo) return null;
  const code = String(drawingNo).trim();
  if (!code) return null;
  const cols = 'drawing_no,storage_path,file_name,mime_type,size_bytes';

  /* 1) Exact */
  {
    const p = new URLSearchParams();
    p.set('select', cols);
    p.set('drawing_no', `eq.${code}`);
    p.set('removed_at', 'is.null');
    p.set('limit', '1');
    const rows = await sbReq(`bigtehn_drawings_cache?${p.toString()}`);
    if (Array.isArray(rows) && rows[0]) {
      return { ...rows[0], _isFallback: false };
    }
  }

  /* 2) Fallback: najnovija revizija */
  const p = new URLSearchParams();
  p.set('select', cols);
  p.set('drawing_no', `like.${code}*`);
  p.set('removed_at', 'is.null');
  p.set('order', 'drawing_no.desc');
  p.set('limit', '50');
  const rows = await sbReq(`bigtehn_drawings_cache?${p.toString()}`);
  if (!Array.isArray(rows) || rows.length === 0) return null;
  const prefix = code + '_';
  const top = rows.find(r => {
    const dn = String(r?.drawing_no || '');
    return dn === code || dn.startsWith(prefix);
  });
  if (!top) return null;
  return { ...top, _isFallback: top.drawing_no !== code };
}

/**
 * Vrati listu crteža (sa metapodacima) za jedan RN, identifikovan po
 * `bigtehn_work_orders_cache.ident_broj` (npr. `"9000/568"`).
 *
 * Korak 1: nađi sve `bigtehn_work_orders_cache` redove sa `ident_broj=rnCode`
 *   → izvuci sve distinct `broj_crteza` (može biti više varijanti istog RN-a).
 * Korak 2: učitaj `bigtehn_drawings_cache` za sve te brojeve crteža (samo
 *   `removed_at IS NULL`) i vrati ih kao [{drawing_no, storage_path, file_name, ...}].
 *
 * Brojevi crteža za koje fajl još nije sinhronizovan u Storage NEĆE biti u
 * vraćenoj listi (ali postoje kao "kandidat" iz BigTehn-a).
 *
 * @param {string} rnCode  vrednost `work_packages.rn_code` (= `ident_broj` u BigTehn-u)
 * @returns {Promise<Array<object>>}
 */
export async function listDrawingsForRnCode(rnCode) {
  if (!getIsOnline()) return [];
  const code = String(rnCode || '').trim();
  if (!code) return [];

  /* Normalizacija: WP rn_code u Plan Montaži često sadrži prefiks „RN "
     (npr. „RN 9000/1"), dok je u BigTehn-u `ident_broj` bez prefiksa
     („9000/1"). Pokušaj sa oba oblika — prvo sa skinutim prefiksom, pa sa
     originalnim, pa fallback varijante (npr. razmak/separatori). */
  const candidates = [];
  const stripped = code.replace(/^RN\s+/i, '').trim();
  if (stripped && stripped !== code) candidates.push(stripped);
  candidates.push(code);
  /* Dedup, sačuvaj redosled. */
  const seenC = new Set();
  const tryCodes = candidates.filter(c => (c && !seenC.has(c) && (seenC.add(c), true)));

  let woRows = null;
  for (const c of tryCodes) {
    const woParams = new URLSearchParams();
    woParams.set('select', 'broj_crteza');
    woParams.set('ident_broj', `eq.${c}`);
    woParams.set('limit', '500');
    const rows = await sbReq(`bigtehn_work_orders_cache?${woParams.toString()}`);
    if (Array.isArray(rows) && rows.length) {
      woRows = rows;
      break;
    }
  }
  if (!Array.isArray(woRows) || !woRows.length) return [];
  const drawingNos = [
    ...new Set(
      woRows
        .map(r => (r?.broj_crteza == null ? '' : String(r.broj_crteza).trim()))
        .filter(s => s !== ''),
    ),
  ];
  if (!drawingNos.length) return [];

  /* 2) Lookup u bigtehn_drawings_cache. PostgREST `in.(...)` filter. */
  const escaped = drawingNos.map(s => `"${s.replace(/"/g, '\\"')}"`).join(',');
  const dParams = new URLSearchParams();
  dParams.set('select', 'drawing_no,storage_path,file_name,mime_type,size_bytes');
  dParams.set('drawing_no', `in.(${escaped})`);
  dParams.set('removed_at', 'is.null');
  dParams.set('order', 'drawing_no.asc');
  dParams.set('limit', '500');
  const drawings = await sbReq(`bigtehn_drawings_cache?${dParams.toString()}`);
  return Array.isArray(drawings) ? drawings : [];
}

/**
 * Konveniencija: dohvati listu crteža za work_package iz Plan Montaže state-a
 * (potreban je njegov `rn_code`/`rnCode`).
 *
 * Prima ili WP objekat (sa `rnCode`/`rn_code`) ili string `rn_code` direktno.
 *
 * @param {string|{rnCode?:string, rn_code?:string}} wpOrRnCode
 */
export async function listDrawingsForWorkPackage(wpOrRnCode) {
  let rnCode = '';
  if (typeof wpOrRnCode === 'string') {
    rnCode = wpOrRnCode;
  } else if (wpOrRnCode && typeof wpOrRnCode === 'object') {
    rnCode = wpOrRnCode.rnCode || wpOrRnCode.rn_code || '';
  }
  return await listDrawingsForRnCode(rnCode);
}

/**
 * Otvara PDF crtež u novom tabu — kreira signed URL i `window.open`.
 * Ako fajl ne postoji ili broj crteža nije sinhronizovan u Storage,
 * prikazuje toast „Crtež nije dostupan“ i ne otvara prazan tab.
 *
 * @param {string} drawingNo
 */
export async function openDrawingPdf(drawingNo) {
  const code = String(drawingNo || '').trim();
  if (!code) return;
  const url = await getBigtehnDrawingSignedUrl(code);
  if (!url) {
    showToast('Crtež nije dostupan');
    return;
  }
  window.open(url, '_blank', 'noopener');
}
