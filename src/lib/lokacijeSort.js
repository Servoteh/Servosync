/**
 * Prirodno sortiranje po `location_code` (brojevi kao brojevi — A10 posle A2).
 *
 * Koristi isti jezik kao ostatak Lokacija UI-a (`sr`).
 */

/**
 * @param {{ location_code?: string }|null|undefined} a
 * @param {{ location_code?: string }|null|undefined} b
 */
export function compareLocationCodeNatural(a, b) {
  return String(a?.location_code ?? '').localeCompare(String(b?.location_code ?? ''), 'sr', {
    numeric: true,
    sensitivity: 'base',
  });
}

/**
 * Grupisanje police po vodećem bloku slova u `location_code` do prve cifre
 * (npr. `A1`/`A100` → `A`, `AB02` → `AB`). Ostalo (nema slova na početku) → `#`.
 *
 * @param {object[]} shelves lokacije tipa polica (već filtrirane po hali)
 * @returns {{ prefix: string, shelves: object[] }[]}
 */
export function groupShelvesByCodePrefix(shelves) {
  /** @type {Map<string, object[]>} */
  const byPrefix = new Map();
  for (const s of shelves || []) {
    const p = locationCodeShelfPrefix(s?.location_code);
    if (!byPrefix.has(p)) byPrefix.set(p, []);
    byPrefix.get(p).push(s);
  }
  for (const arr of byPrefix.values()) {
    arr.sort(compareLocationCodeNatural);
  }
  const keys = [...byPrefix.keys()].sort((a, b) =>
    a.localeCompare(b, 'sr', { numeric: true, sensitivity: 'base' }),
  );
  return keys.map(prefix => ({ prefix, shelves: byPrefix.get(prefix) || [] }));
}

/**
 * @param {string|undefined|null} code
 * @returns {string}
 */
export function locationCodeShelfPrefix(code) {
  const s = String(code ?? '').trim();
  if (!s) return '—';
  const m = s.match(/^(\p{L}+)/u);
  if (m) return m[1].toLocaleUpperCase('sr');
  return '#';
}
