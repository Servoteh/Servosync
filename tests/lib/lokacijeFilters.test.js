import { describe, it, expect } from 'vitest';
import {
  normalizeQuery,
  locationMatches,
  filterLocationsHierarchical,
  placementMatches,
  filterPlacements,
} from '../../src/lib/lokacijeFilters.js';

/**
 * Test fixture: hijerarhija M2 (magacin 2) > R1 (regal 1) > P3 (polica 3), uz odvojeni PROJECT.
 *   M2
 *   └── R1
 *       └── P3
 *   PRJ-BEO
 */
const fixtureLocs = [
  { id: 'm2', parent_id: null, depth: 0, location_code: 'M2', name: 'Magacin 2', path_cached: 'M2' },
  {
    id: 'r1',
    parent_id: 'm2',
    depth: 1,
    location_code: 'R1',
    name: 'Regal 1',
    path_cached: 'M2 > R1',
  },
  {
    id: 'p3',
    parent_id: 'r1',
    depth: 2,
    location_code: 'P3',
    name: 'Polica 3',
    path_cached: 'M2 > R1 > P3',
  },
  {
    id: 'prj',
    parent_id: null,
    depth: 0,
    location_code: 'PRJ-BEO',
    name: 'Projekat Beograd',
    path_cached: 'PRJ-BEO',
  },
];

describe('normalizeQuery', () => {
  it('trim + lowercase', () => {
    expect(normalizeQuery('  HeLo  ')).toBe('helo');
  });
  it('null/undefined → ""', () => {
    expect(normalizeQuery(null)).toBe('');
    expect(normalizeQuery(undefined)).toBe('');
  });
  it('koerciše ne-string u string', () => {
    expect(normalizeQuery(42)).toBe('42');
  });
});

describe('locationMatches', () => {
  const q = 'r1';
  it('match po šifri', () => {
    expect(locationMatches(fixtureLocs[1], q)).toBe(true);
  });
  it('no match po drugom kodu', () => {
    expect(locationMatches(fixtureLocs[0], q)).toBe(false);
  });
  it('prazan upit → uvek match', () => {
    expect(locationMatches(fixtureLocs[0], '')).toBe(true);
  });
  it('match po nazivu', () => {
    expect(locationMatches(fixtureLocs[0], 'magacin')).toBe(true);
  });
  it('match po path_cached', () => {
    expect(locationMatches(fixtureLocs[2], 'm2 > r1')).toBe(true);
  });
  it('undefined loc → false', () => {
    expect(locationMatches(null, 'x')).toBe(false);
  });
});

describe('filterLocationsHierarchical', () => {
  it('prazan upit → ista lista (kopija)', () => {
    const result = filterLocationsHierarchical(fixtureLocs, '');
    expect(result).toHaveLength(fixtureLocs.length);
    expect(result).not.toBe(fixtureLocs);
  });

  it('match leaf-a uključuje sve pretke', () => {
    /* "polica" hvata samo P3, ali hijerarhija treba da zadrži R1 i M2. */
    const result = filterLocationsHierarchical(fixtureLocs, 'polica');
    const ids = result.map(r => r.id);
    expect(ids).toEqual(['m2', 'r1', 'p3']);
  });

  it('match roditelja ne uključuje decu', () => {
    const result = filterLocationsHierarchical(fixtureLocs, 'magacin');
    expect(result.map(r => r.id)).toEqual(['m2']);
  });

  it('nezavisna grana se ne uključuje', () => {
    const result = filterLocationsHierarchical(fixtureLocs, 'polica');
    expect(result.find(r => r.id === 'prj')).toBeUndefined();
  });

  it('bez match-a → prazan niz', () => {
    const result = filterLocationsHierarchical(fixtureLocs, 'xyz123');
    expect(result).toEqual([]);
  });

  it('case-insensitive', () => {
    const a = filterLocationsHierarchical(fixtureLocs, 'POLICA');
    const b = filterLocationsHierarchical(fixtureLocs, 'polica');
    expect(a.map(r => r.id)).toEqual(b.map(r => r.id));
  });

  it('radi sa non-array ulazom', () => {
    expect(filterLocationsHierarchical(null, 'x')).toEqual([]);
    expect(filterLocationsHierarchical(undefined, '')).toEqual([]);
  });
});

describe('placementMatches / filterPlacements', () => {
  const locIdx = new Map([
    ['m2', { id: 'm2', location_code: 'M2', name: 'Magacin 2' }],
    ['prj', { id: 'prj', location_code: 'PRJ-BEO', name: 'Projekat Beograd' }],
  ]);
  const placements = [
    { item_ref_table: 'parts', item_ref_id: 'P-100', placement_status: 'ACTIVE', location_id: 'm2' },
    { item_ref_table: 'tools', item_ref_id: 'T-7', placement_status: 'IN_TRANSIT', location_id: 'prj' },
    {
      item_ref_table: 'parts',
      item_ref_id: 'P-200',
      placement_status: 'ACTIVE',
      location_id: 'm2',
    },
  ];

  it('match po item_ref_table', () => {
    expect(filterPlacements(placements, locIdx, 'tools')).toHaveLength(1);
  });
  it('match po item_ref_id', () => {
    expect(filterPlacements(placements, locIdx, 'p-100')).toHaveLength(1);
  });
  it('match po status-u', () => {
    expect(filterPlacements(placements, locIdx, 'in_transit')).toHaveLength(1);
  });
  it('match po location code preko locIdx', () => {
    expect(filterPlacements(placements, locIdx, 'prj-beo')).toHaveLength(1);
  });
  it('match po location name', () => {
    expect(filterPlacements(placements, locIdx, 'magacin')).toHaveLength(2);
  });
  it('prazan upit → kopija celog niza', () => {
    const r = filterPlacements(placements, locIdx, '');
    expect(r).toHaveLength(placements.length);
    expect(r).not.toBe(placements);
  });
  it('bez match-a → prazan niz', () => {
    expect(filterPlacements(placements, locIdx, 'nema-ovoga')).toHaveLength(0);
  });
  it('null placements → prazan niz', () => {
    expect(filterPlacements(null, locIdx, 'x')).toEqual([]);
  });
  it('placement bez location_id u locIdx → ostaje samo ako match drugde', () => {
    const p = [{ item_ref_table: 'x', item_ref_id: 'y', location_id: 'nepoznata' }];
    expect(placementMatches(p[0], locIdx, 'x')).toBe(true);
    expect(placementMatches(p[0], locIdx, 'magacin')).toBe(false);
  });
});
