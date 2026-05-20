import { describe, expect, it } from 'vitest';
import {
  compareLocationCodeNatural,
  shelfBelongsToHall,
  sortShelvesByHallThenCode,
} from '../../src/lib/lokacijeSort.js';

const H1 = '11111111-1111-4111-a111-111111111111';
const H2 = '22222222-2222-4222-a222-222222222222';
const S1 = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
const S2 = 'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb';
const S3 = 'cccccccc-cccc-4ccc-cccc-cccccccccccc';

describe('lokacijeSort — police za štampu', () => {
  const locById = new Map([
    [H1, { id: H1, location_type: 'WAREHOUSE', location_code: 'HALA 1', parent_id: null }],
    [H2, { id: H2, location_type: 'WAREHOUSE', location_code: 'HALA 2A', parent_id: null }],
    [S1, { id: S1, location_type: 'SHELF', location_code: 'A12', parent_id: H1 }],
    [S2, { id: S2, location_type: 'SHELF', location_code: 'A10', parent_id: H1 }],
    [S3, { id: S3, location_type: 'SHELF', location_code: 'A10', parent_id: H2 }],
  ]);

  it('sortShelvesByHallThenCode — hala pa polica A–Z', () => {
    const sorted = sortShelvesByHallThenCode(
      [locById.get(S1), locById.get(S3), locById.get(S2)],
      locById,
    ).map(l => l.id);
    expect(sorted).toEqual([S2, S1, S3]);
  });

  it('shelfBelongsToHall filtrira po parent hali', () => {
    expect(shelfBelongsToHall(locById.get(S2), H1, locById)).toBe(true);
    expect(shelfBelongsToHall(locById.get(S3), H1, locById)).toBe(false);
    expect(shelfBelongsToHall(locById.get(S3), '', locById)).toBe(true);
  });

  it('compareLocationCodeNatural — A10 posle A2', () => {
    expect(
      compareLocationCodeNatural({ location_code: 'A2' }, { location_code: 'A10' }),
    ).toBeLessThan(0);
  });
});
