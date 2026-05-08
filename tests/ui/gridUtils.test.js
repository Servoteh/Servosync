/**
 * gridUtils.test.js — testovi za pure helpers iz gridTab.js refaktora.
 */

import { describe, it, expect } from 'vitest';
import {
  GRID_ABS_CODES,
  GRID_BO_SUBTYPE_MAP,
  GRID_DAY_LETTERS,
  ymdOf,
  gridIsoToday,
  gridDirtyKey,
  gridDaysInMonth,
  gridDayClasses,
  gridParseCellText,
  gridFormatNum,
  gridFormatSum,
} from '../../src/ui/kadrovska/gridUtils.js';

describe('ymdOf', () => {
  it('formatira datum kao YYYY-MM-DD sa zero-padd', () => {
    expect(ymdOf(2026, 1, 5)).toBe('2026-01-05');
    expect(ymdOf(2026, 12, 31)).toBe('2026-12-31');
  });
});

describe('gridIsoToday', () => {
  it('vraća validan YYYY-MM-DD format', () => {
    const today = gridIsoToday();
    expect(today).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });
});

describe('gridDirtyKey', () => {
  it('formira stabilnu kombinaciju empId|ymd', () => {
    expect(gridDirtyKey('emp-1', '2026-05-08')).toBe('emp-1|2026-05-08');
  });
});

describe('gridDaysInMonth', () => {
  it('vraća 31 dan za mart 2026', () => {
    const days = gridDaysInMonth('2026-03');
    expect(days).toHaveLength(31);
    expect(days[0].day).toBe(1);
    expect(days[30].day).toBe(31);
  });
  it('vraća 28 dana za februar 2026 (ne-prestupna)', () => {
    expect(gridDaysInMonth('2026-02')).toHaveLength(28);
  });
  it('vraća 29 dana za februar 2024 (prestupna)', () => {
    expect(gridDaysInMonth('2024-02')).toHaveLength(29);
  });
  it('označava vikende', () => {
    /* 2026-05-02 je subota, 2026-05-03 nedelja. */
    const days = gridDaysInMonth('2026-05');
    expect(days[1].isWeekend).toBe(true);
    expect(days[2].isWeekend).toBe(true);
    expect(days[0].isWeekend).toBe(false); /* 2026-05-01 petak */
  });
  it('vraća prazan niz za prazan ulaz', () => {
    expect(gridDaysInMonth('')).toEqual([]);
    expect(gridDaysInMonth(null)).toEqual([]);
  });
});

describe('gridDayClasses', () => {
  it('osnovna klasa col-day uvek prisutna', () => {
    expect(gridDayClasses({ dow: 1 }, new Set())).toContain('col-day');
  });
  it('vikend dobija cell-weekend + smer (sat/sun)', () => {
    const cls = gridDayClasses({ dow: 6, isWeekend: true }, new Set());
    expect(cls).toContain('cell-weekend');
    expect(cls).toContain('cell-weekend-sat');
  });
  it('praznik dobija cell-holiday', () => {
    const hol = new Set(['2026-01-01']);
    const cls = gridDayClasses({ ymd: '2026-01-01', dow: 4 }, hol);
    expect(cls).toContain('cell-holiday');
  });
  it('extra klase se dodaju', () => {
    const cls = gridDayClasses({ dow: 1 }, new Set(), ['cell-today', '']);
    expect(cls).toContain('cell-today');
  });
});

describe('gridParseCellText', () => {
  it('prazno polje', () => {
    expect(gridParseCellText('').kind).toBe('empty');
    expect(gridParseCellText('   ').kind).toBe('empty');
  });
  it('broj sa tačkom', () => {
    const r = gridParseCellText('8.5');
    expect(r.kind).toBe('num');
    expect(r.value).toBe(8.5);
  });
  it('broj sa zarezom', () => {
    const r = gridParseCellText('7,25');
    expect(r.kind).toBe('num');
    expect(r.value).toBe(7.25);
  });
  it('odbija >24', () => {
    expect(gridParseCellText('25').kind).toBe('err');
  });
  it('odbija negativne', () => {
    expect(gridParseCellText('-1').kind).toBe('err');
  });
  it('odbija nevalidne stringove', () => {
    expect(gridParseCellText('abc').kind).toBe('err');
    expect(gridParseCellText('8x').kind).toBe('err');
  });
  it('prepoznaje šifre odsustva (lowercase)', () => {
    const r = gridParseCellText('go');
    expect(r.kind).toBe('abs');
    expect(r.code).toBe('go');
    expect(r.subtype).toBeNull();
  });
  it('prepoznaje šifre case-insensitive', () => {
    expect(gridParseCellText('SP').kind).toBe('abs');
    expect(gridParseCellText('NoP').code).toBe('nop');
  });
  it('mapira bo subtype: bop → povreda_na_radu', () => {
    const r = gridParseCellText('bop');
    expect(r.kind).toBe('abs');
    expect(r.code).toBe('bo');
    expect(r.subtype).toBe('povreda_na_radu');
  });
  it('mapira bo subtype: bot → odrzavanje_trudnoce', () => {
    const r = gridParseCellText('bot');
    expect(r.code).toBe('bo');
    expect(r.subtype).toBe('odrzavanje_trudnoce');
  });
  it('"bo" je obicno bolovanje', () => {
    const r = gridParseCellText('bo');
    expect(r.code).toBe('bo');
    expect(r.subtype).toBe('obicno');
  });
});

describe('gridFormatNum', () => {
  it('0 i null daju prazan string', () => {
    expect(gridFormatNum(0)).toBe('');
    expect(gridFormatNum(null)).toBe('');
    expect(gridFormatNum(undefined)).toBe('');
  });
  it('cele brojeve bez decimale', () => {
    expect(gridFormatNum(8)).toBe('8');
  });
  it('decimalne uklanja trailing nule', () => {
    expect(gridFormatNum(8.5)).toBe('8.5');
    expect(gridFormatNum(8.50)).toBe('8.5');
  });
});

describe('gridFormatSum', () => {
  it('0 daje "0" (ne prazno)', () => {
    expect(gridFormatSum(0)).toBe('0');
    expect(gridFormatSum(null)).toBe('0');
  });
  it('cele brojeve bez decimale', () => {
    expect(gridFormatSum(160)).toBe('160');
  });
  it('decimalne uklanja trailing nule', () => {
    expect(gridFormatSum(160.50)).toBe('160.5');
  });
});

describe('konstante', () => {
  it('GRID_ABS_CODES sadrži standardne šifre', () => {
    expect(GRID_ABS_CODES).toContain('go');
    expect(GRID_ABS_CODES).toContain('bo');
    expect(GRID_ABS_CODES).toContain('nop');
  });
  it('GRID_BO_SUBTYPE_MAP ima 3 ključa', () => {
    expect(Object.keys(GRID_BO_SUBTYPE_MAP)).toHaveLength(3);
  });
  it('GRID_DAY_LETTERS ima 7 stavki', () => {
    expect(GRID_DAY_LETTERS).toHaveLength(7);
  });
});
