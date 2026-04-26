/**
 * SheetJS (xlsx) lazy učitavanje preko dynamic import-a.
 *
 * Ranije: CDN (jsdelivr) — pada iza korporativnog firewalla, striktnog CSP ili offline.
 * Sada: `xlsx` je npm zavisnost; Vite pravi zaseban chunk, učitava se tek pri prvom
 * export-u/importu, bez mrežnog fetch-a.
 */

let _promise = null;

/** @returns {Promise<import('xlsx')>} */
export function loadXlsx() {
  if (typeof window === 'undefined') {
    return Promise.reject(new Error('XLSX dostupan samo u browser kontekstu'));
  }
  if (_promise) return _promise;

  _promise = import('xlsx').catch((err) => {
    _promise = null;
    return Promise.reject(err);
  });
  return _promise;
}
