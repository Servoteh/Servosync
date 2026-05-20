/**
 * Prirodno sortiranje po `location_code` (brojevi kao brojevi — A10 posle A2).
 *
 * Koristi isti jezik kao ostatak Lokacija UI-a (`sr`).
 */

import { nearestHallAncestorId } from './shelfBarcode.js';

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
 * @param {object} shelf
 * @param {Map<string, object>} locById
 */
function hallCodeForShelf(shelf, locById) {
  const hid = nearestHallAncestorId(shelf, locById);
  if (!hid) return '\uffff';
  const hall = locById.get(String(hid)) || locById.get(hid);
  return String(hall?.location_code ?? '').trim();
}

/**
 * Redosled za štampu: prvo hala (A–Z po šifri), zatim polica (A–Z).
 *
 * @param {object[]} shelves
 * @param {Map<string, object>} locById
 */
export function sortShelvesByHallThenCode(shelves, locById) {
  return [...shelves].sort((a, b) => {
    const byHall = hallCodeForShelf(a, locById).localeCompare(hallCodeForShelf(b, locById), 'sr', {
      numeric: true,
      sensitivity: 'base',
    });
    if (byHall !== 0) return byHall;
    return compareLocationCodeNatural(a, b);
  });
}

/**
 * @param {object} shelf
 * @param {string} hallId UUID halе; prazno = sve
 * @param {Map<string, object>} locById
 */
export function shelfBelongsToHall(shelf, hallId, locById) {
  if (!hallId) return true;
  const hid = nearestHallAncestorId(shelf, locById);
  return hid != null && String(hid) === String(hallId);
}
