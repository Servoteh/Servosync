/**
 * gridUtils.js — pure helpers za Mesečni grid (Faza K8 refactor).
 *
 * Ovde žive samo funkcije bez side-effecta i bez DOM/state zavisnosti.
 * Time se gridTab.js zadržava na orkestraciji (DOM rendering + event wiring),
 * a ove funkcije se mogu nezavisno testirati (vidi tests/ui/gridUtils.test.js).
 *
 * Šifre odsustva u Redovni redu:
 *   go  = godišnji odmor
 *   bo  = bolovanje 65% (obicno)
 *   bop = bolovanje 100% (povreda na radu)        — mapira se na bo + subtype
 *   bot = bolovanje 100% (održavanje trudnoće)    — mapira se na bo + subtype
 *   sp  = slobodan/plaćeni praznik
 *   np  = neopravdano (legacy)
 *   sl  = slobodan dan
 *   pr  = prazan dan
 *   nop = neplaćeno odsustvo
 */

import { parseDateLocal } from '../../lib/date.js';

export const GRID_ABS_CODES = ['go', 'bo', 'sp', 'np', 'sl', 'pr', 'nop'];

export const GRID_BO_SUBTYPE_MAP = {
  bo:  'obicno',
  bop: 'povreda_na_radu',
  bot: 'odrzavanje_trudnoce',
};

/** Index 0 = nedelja. */
export const GRID_DAY_LETTERS = ['N', 'P', 'U', 'S', 'Č', 'P', 'S'];

export const GRID_FIELD_SUBTYPE_DEFAULT = 'domestic';

/** "YYYY-MM-DD" iz (year, month1based, day). */
export function ymdOf(y, m1, d) {
  return `${y}-${String(m1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

/** Današnji datum kao 'YYYY-MM-DD' (lokalni kalendar). */
export function gridIsoToday() {
  const t = new Date();
  return ymdOf(t.getFullYear(), t.getMonth() + 1, t.getDate());
}

/** Stabilan key za dirty Map: 'empId|ymd'. */
export function gridDirtyKey(empId, ymd) {
  return empId + '|' + ymd;
}

/**
 * Vrati niz dana za dati 'YYYY-MM' string.
 *  Svaki dan: { day, ymd, dow, isWeekend, letter }
 */
export function gridDaysInMonth(yyyymm) {
  if (!yyyymm) return [];
  const [y, m] = yyyymm.split('-').map(n => parseInt(n, 10));
  if (!y || !m) return [];
  const last = new Date(y, m, 0).getDate();
  const out = [];
  for (let d = 1; d <= last; d++) {
    const ymd = ymdOf(y, m, d);
    const dt = parseDateLocal(ymd);
    const dow = dt ? dt.getDay() : new Date(y, m - 1, d).getDay();
    out.push({
      day: d,
      ymd,
      dow,
      isWeekend: dow === 0 || dow === 6,
      letter: GRID_DAY_LETTERS[dow],
    });
  }
  return out;
}

/** CSS klase za grid ćeliju u zavisnosti od dana + praznika. */
export function gridDayClasses(day, holidayYmdSet, extra = []) {
  const cls = ['col-day'];
  if (day?.isWeekend) cls.push('cell-weekend');
  if (day?.dow === 6) cls.push('cell-weekend-sat');
  if (day?.dow === 0) cls.push('cell-weekend-sun');
  if (holidayYmdSet?.has?.(day?.ymd)) cls.push('cell-holiday');
  if (extra?.length) cls.push(...extra.filter(Boolean));
  return cls;
}

/**
 * Parsiranje sirovog teksta ćelije Redovni reda.
 *  - prazan → { kind: 'empty' }
 *  - šifra odsustva → { kind: 'abs', code, subtype }
 *  - broj 0..24 (zarez ili tačka) → { kind: 'num', value }
 *  - sve ostalo → { kind: 'err' }
 */
export function gridParseCellText(raw) {
  const v = String(raw || '').trim().toLowerCase();
  if (!v) return { kind: 'empty' };
  if (Object.prototype.hasOwnProperty.call(GRID_BO_SUBTYPE_MAP, v)) {
    return { kind: 'abs', code: 'bo', subtype: GRID_BO_SUBTYPE_MAP[v] };
  }
  if (GRID_ABS_CODES.includes(v)) return { kind: 'abs', code: v, subtype: null };
  const num = parseFloat(v.replace(',', '.'));
  if (
    isFinite(num) &&
    num >= 0 &&
    num <= 24 &&
    /^[0-9]+([.,][0-9]+)?$/.test(v)
  ) {
    return { kind: 'num', value: Math.round(num * 100) / 100 };
  }
  return { kind: 'err' };
}

/** Format broja za ćeliju — prazno za 0, do 2 decimale. */
export function gridFormatNum(n) {
  if (n == null || n === 0) return '';
  const r = Math.round(Number(n) * 100) / 100;
  if (Number.isInteger(r)) return String(r);
  return String(r).replace(/0+$/, '').replace(/\.$/, '');
}

/** Format zbira za footer red — '0' za 0, do 2 decimale. */
export function gridFormatSum(n) {
  if (!n || n === 0) return '0';
  const r = Math.round(Number(n) * 100) / 100;
  if (Number.isInteger(r)) return String(r);
  return r.toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
}
