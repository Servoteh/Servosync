/**
 * jmbg.test.js — JMBG validator + parser.
 *
 * Pokriva:
 *  - format check (13 cifara)
 *  - kontrolnu cifru (modulo 11)
 *  - izračunavanje datuma rođenja i pola iz validnih JMBG-a
 *  - rejekciju nevalidnih datuma (29.02.2001, 31.04, ...)
 *  - validateJmbg (kombinovani helper sa porukama greške)
 */

import { describe, it, expect } from 'vitest';
import {
  isValidJmbgFormat,
  isValidJmbgChecksum,
  parseJmbg,
  validateJmbg,
} from '../../src/lib/jmbg.js';

describe('isValidJmbgFormat', () => {
  it('prihvata 13 cifara', () => {
    expect(isValidJmbgFormat('0101990123456')).toBe(true);
  });
  it('odbija ne-string', () => {
    expect(isValidJmbgFormat(1234567890123)).toBe(false);
    expect(isValidJmbgFormat(null)).toBe(false);
    expect(isValidJmbgFormat(undefined)).toBe(false);
  });
  it('odbija pogrešnu dužinu', () => {
    expect(isValidJmbgFormat('123')).toBe(false);
    expect(isValidJmbgFormat('12345678901234')).toBe(false);
  });
  it('odbija ne-cifre', () => {
    expect(isValidJmbgFormat('010199012345A')).toBe(false);
    expect(isValidJmbgFormat('010199 123456')).toBe(false);
  });
});

describe('isValidJmbgChecksum', () => {
  /* Validan JMBG: 0101990500006 — datum 01.01.1990, region 50, pol M (000),
     kontrolna 6. Provera: 7×0+6×1+5×0+4×1+3×9+2×9+7×0+6×5+5×0+4×0+3×0+2×0
            = 0+6+0+4+27+18+0+30+0+0+0+0 = 85
     11 - (85 mod 11) = 11 - 8 = 3 → kontrolna treba biti 3, ne 6.
     Tako da idem sa konkretnim ispravnim primerom: */
  it('prihvata validan JMBG sa tačnom kontrolnom cifrom', () => {
    /* Generisan iz pravila: 0101990500003 */
    expect(isValidJmbgChecksum('0101990500003')).toBe(true);
  });
  it('odbija JMBG sa pogrešnom kontrolnom cifrom', () => {
    expect(isValidJmbgChecksum('0101990500005')).toBe(false);
    expect(isValidJmbgChecksum('0101990500009')).toBe(false);
  });
  it('odbija nevalidan format', () => {
    expect(isValidJmbgChecksum('123')).toBe(false);
    expect(isValidJmbgChecksum(null)).toBe(false);
  });
});

describe('parseJmbg', () => {
  it('izvuče datum rođenja i pol — žensko, 1990', () => {
    /* Format: DDMMGGG_RR_BBB_K. BBB=505 ≥ 500 → Z.
       0101990505005 → DD=01 MM=01 GGG=990 RR=50 BBB=505 K=5 */
    const r = parseJmbg('0101990505005');
    expect(r).toBeTruthy();
    expect(r.birthDate).toBe('1990-01-01');
    expect(r.gender).toBe('Z');
    expect(r.region).toBe('50');
  });
  it('izvuče datum rođenja i pol — muško, 2005', () => {
    /* BBB=000 < 500 → M. K se ne validira u parseJmbg. */
    const r = parseJmbg('1503005500001');
    expect(r).toBeTruthy();
    expect(r.birthDate).toBe('2005-03-15');
    expect(r.gender).toBe('M');
  });
  it('rejektuje nevalidan datum (31.04)', () => {
    expect(parseJmbg('3104990500003')).toBeNull();
  });
  it('rejektuje nevalidan datum (29.02 ne-prestupna)', () => {
    expect(parseJmbg('2902001500003')).toBeNull(); /* 2001 nije prestupna */
  });
  it('prihvata 29.02 u prestupnoj godini', () => {
    const r = parseJmbg('2902000500003'); /* 2000 jeste prestupna */
    expect(r).toBeTruthy();
    expect(r.birthDate).toBe('2000-02-29');
  });
  it('vraća null za nevalidan format', () => {
    expect(parseJmbg('abc')).toBeNull();
    expect(parseJmbg('')).toBeNull();
  });
});

describe('validateJmbg', () => {
  it('prijavljuje praznu vrednost', () => {
    const r = validateJmbg('');
    expect(r.valid).toBe(false);
    expect(r.error).toMatch(/prazan/i);
  });
  it('prijavljuje pogrešnu dužinu', () => {
    const r = validateJmbg('123');
    expect(r.valid).toBe(false);
    expect(r.error).toMatch(/13 cifara/);
  });
  it('prijavljuje nevalidan datum', () => {
    const r = validateJmbg('3104990500003');
    expect(r.valid).toBe(false);
    expect(r.error).toMatch(/datum/i);
  });
  it('vraća valid + parsed za format-validne unose (bez checksum-a)', () => {
    const r = validateJmbg('0101990505005');
    expect(r.valid).toBe(true);
    expect(r.birthDate).toBe('1990-01-01');
    expect(r.gender).toBe('Z');
  });
  it('strikni mod ne propušta nevalidan checksum', () => {
    const r = validateJmbg('0101990505009', { requireChecksum: true });
    expect(r.valid).toBe(false);
    expect(r.error).toMatch(/kontrolna/i);
  });
});
