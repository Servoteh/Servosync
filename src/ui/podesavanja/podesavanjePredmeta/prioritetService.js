/**
 * Prioritet predmeta — lokalno čuvanje top-10 liste u localStorage.
 *
 * Exportuje getPrioritetIds() koji vraća array item_id-jeva u prioritetnom
 * redosledu (max 10). Ostali moduli mogu da importuju ovu funkciju i
 * sortiraju prikaze predmeta po ovom redosledu.
 */

const LS_KEY = 'servoteh_predmet_prioritet_v1';
const MAX = 10;

/** @returns {number[]} lista item_id u prioritetnom redosledu (max 10) */
export function getPrioritetIds() {
  try {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.map(Number).filter(n => Number.isFinite(n) && n > 0);
  } catch {
    return [];
  }
}

/** @param {number[]} ids */
function _save(ids) {
  localStorage.setItem(LS_KEY, JSON.stringify(ids.slice(0, MAX)));
}

/** @param {number} itemId @returns {boolean} true = dodat, false = već u listi */
export function addToPrioritet(itemId) {
  const id = Number(itemId);
  const list = getPrioritetIds();
  if (list.includes(id)) return false;
  if (list.length >= MAX) return false;
  list.push(id);
  _save(list);
  return true;
}

/** @param {number} itemId */
export function removeFromPrioritet(itemId) {
  const id = Number(itemId);
  _save(getPrioritetIds().filter(x => x !== id));
}

/** @param {number} itemId @returns {boolean} */
export function isPrioritet(itemId) {
  return getPrioritetIds().includes(Number(itemId));
}

/** Pomera item na gore u listi (swap sa prethodnim). @param {number} itemId */
export function movePrioritetUp(itemId) {
  const id = Number(itemId);
  const list = getPrioritetIds();
  const ix = list.indexOf(id);
  if (ix <= 0) return;
  [list[ix - 1], list[ix]] = [list[ix], list[ix - 1]];
  _save(list);
}

/** Pomera item na dole u listi (swap sa sledećim). @param {number} itemId */
export function movePrioritetDown(itemId) {
  const id = Number(itemId);
  const list = getPrioritetIds();
  const ix = list.indexOf(id);
  if (ix < 0 || ix >= list.length - 1) return;
  [list[ix], list[ix + 1]] = [list[ix + 1], list[ix]];
  _save(list);
}
