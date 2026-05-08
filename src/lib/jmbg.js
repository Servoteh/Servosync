/**
 * JMBG (jedinstveni matični broj građana) — validacija i parser.
 *
 * Format (13 cifara): DDMMGGG RR BBB K
 *   DD       — dan rođenja (01–31)
 *   MM       — mesec rođenja (01–12)
 *   GGG      — poslednje 3 cifre godine; 000–899 → 2000–2899, 900–999 → 1900–1999
 *   RR       — region rođenja (00–99)
 *   BBB      — redni broj; 000–499 = M, 500–999 = Ž
 *   K        — kontrolna cifra (modulo 11)
 *
 * Kontrolna cifra (K) se izračunava tako da:
 *   m = 11 − ((7×a + 6×b + 5×c + 4×d + 3×e + 2×f + 7×g + 6×h + 5×i + 4×j + 3×k + 2×l) mod 11)
 *   K = m % 10  (ako je m == 11, K = 0; ako je m == 10 — JMBG nije validan)
 *
 * Funkcije:
 *   isValidJmbgFormat(v)     → boolean (samo dužina 13 + sve cifre)
 *   isValidJmbgChecksum(v)   → boolean (kontrolna cifra)
 *   parseJmbg(v)             → { birthDate, gender, region } | null
 *   validateJmbg(v)          → { valid, error?, birthDate?, gender?, region? }
 */

/** True ako je string tačno 13 cifara. */
export function isValidJmbgFormat(jmbg) {
  return typeof jmbg === 'string' && /^\d{13}$/.test(jmbg);
}

/**
 * Validacija kontrolne cifre po algoritmu modulo 11.
 * Vraća true samo ako je format ispravan I checksum se slaže.
 */
export function isValidJmbgChecksum(jmbg) {
  if (!isValidJmbgFormat(jmbg)) return false;
  const d = jmbg.split('').map(Number);
  const sum =
    7 * d[0] + 6 * d[1] + 5 * d[2] + 4 * d[3] +
    3 * d[4] + 2 * d[5] + 7 * d[6] + 6 * d[7] +
    5 * d[8] + 4 * d[9] + 3 * d[10] + 2 * d[11];
  const m = 11 - (sum % 11);
  let expected;
  if (m === 11) expected = 0;
  else if (m === 10) return false; /* nemoguća kontrolna cifra */
  else expected = m;
  return expected === d[12];
}

/**
 * Izvuci datum rođenja (ISO 'YYYY-MM-DD'), pol ('M'/'Z') i regionski kod
 * iz JMBG-a. Vraća null ako format nije ispravan ili datum nije validan.
 */
export function parseJmbg(jmbg) {
  if (!isValidJmbgFormat(jmbg)) return null;
  const dd = parseInt(jmbg.slice(0, 2), 10);
  const mm = parseInt(jmbg.slice(2, 4), 10);
  const yyy = parseInt(jmbg.slice(4, 7), 10);
  const region = jmbg.slice(7, 9);
  const rrr = parseInt(jmbg.slice(9, 12), 10);
  if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
  const year = yyy >= 900 ? 1000 + yyy : 2000 + yyy;
  const dt = new Date(year, mm - 1, dd);
  if (dt.getFullYear() !== year || dt.getMonth() !== mm - 1 || dt.getDate() !== dd) return null;
  const iso = `${year}-${String(mm).padStart(2, '0')}-${String(dd).padStart(2, '0')}`;
  const gender = rrr >= 500 ? 'Z' : 'M';
  return { birthDate: iso, gender, region };
}

/**
 * Kompletna validacija — vraća objekat sa polje `valid` + parsed podaci ili `error` text.
 * Korisno za UI: jedna funkcija, jedna poruka.
 *
 * Konfiguracija:
 *   { requireChecksum: true } — strikna provera (default false zbog
 *     legacy podataka koji ne moraju da prođu checksum, ali su važeći).
 */
export function validateJmbg(jmbg, opts = {}) {
  if (jmbg == null || jmbg === '') return { valid: false, error: 'JMBG je prazan.' };
  if (!isValidJmbgFormat(jmbg)) return { valid: false, error: 'JMBG mora imati tačno 13 cifara.' };
  const parsed = parseJmbg(jmbg);
  if (!parsed) return { valid: false, error: 'JMBG ima neispravan datum rođenja.' };
  if (opts.requireChecksum && !isValidJmbgChecksum(jmbg)) {
    return { valid: false, error: 'JMBG nije validan (kontrolna cifra ne odgovara).' };
  }
  return { valid: true, ...parsed };
}
