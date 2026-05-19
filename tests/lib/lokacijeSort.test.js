import { describe, expect, it } from 'vitest';
import {
  compareLocationCodeNatural,
  groupShelvesByCodePrefix,
  locationCodeShelfPrefix,
} from '../../src/lib/lokacijeSort.js';

describe('locationCodeShelfPrefix', () => {
  it('vraća vodeća slova do prve cifre', () => {
    expect(locationCodeShelfPrefix('A1')).toBe('A');
    expect(locationCodeShelfPrefix('a100')).toBe('A');
    expect(locationCodeShelfPrefix('AB02')).toBe('AB');
  });

  it('prazno ili whitespace', () => {
    expect(locationCodeShelfPrefix('')).toBe('—');
    expect(locationCodeShelfPrefix('   ')).toBe('—');
    expect(locationCodeShelfPrefix(null)).toBe('—');
  });

  it('bez vodećih slova', () => {
    expect(locationCodeShelfPrefix('12A')).toBe('#');
    expect(locationCodeShelfPrefix('-X1')).toBe('#');
  });
});

describe('groupShelvesByCodePrefix', () => {
  it('grupiše i sortira prefikse i police', () => {
    const rows = [
      { id: '1', location_code: 'B1', name: 'b' },
      { id: '2', location_code: 'A10', name: 'x' },
      { id: '3', location_code: 'A2', name: 'y' },
    ];
    const g = groupShelvesByCodePrefix(rows);
    expect(g.map(x => x.prefix)).toEqual(['A', 'B']);
    expect(g[0].shelves.map(r => r.location_code)).toEqual(['A2', 'A10']);
    expect(g[1].shelves.map(r => r.location_code)).toEqual(['B1']);
  });

  it('prazan niz', () => {
    expect(groupShelvesByCodePrefix([])).toEqual([]);
  });
});

describe('compareLocationCodeNatural', () => {
  it('brojevi kao brojevi', () => {
    const rows = [{ location_code: 'A10' }, { location_code: 'A2' }].sort(compareLocationCodeNatural);
    expect(rows.map(r => r.location_code)).toEqual(['A2', 'A10']);
  });
});
