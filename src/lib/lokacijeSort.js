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
