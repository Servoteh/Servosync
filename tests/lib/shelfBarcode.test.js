import { describe, expect, it } from 'vitest';
import {
  nearestHallAncestorId,
  buildShelfPrintBarcodeParts,
  parseShelfCompositeBarcodeToken,
  parseShortShelfBarcodePair,
  resolveCompositeShelfScan,
  formatShelfBarcodeHumanLine,
} from '../../src/lib/shelfBarcode.js';

const H_ID = '11111111-1111-4111-a111-111111111111';
const S_ID = '22222222-2222-4222-a222-222222222222';
const H2_ID = '33333333-3333-4333-a333-333333333333';

describe('shelfBarcode', () => {
  it('formatShelfBarcodeHumanLine koristi razmak oko ASCII crtice', () => {
    expect(formatShelfBarcodeHumanLine('MAG-X', 'P-09')).toBe('MAG-X - P-09');
    expect(formatShelfBarcodeHumanLine('', 'A1')).toBe('A1');
  });

  it('buildShelfPrintBarcodeParts — kratak štampani par umesto LP', () => {
    const shelf = {
      id: S_ID,
      location_type: 'SHELF',
      location_code: 'P-09',
      parent_id: H_ID,
      is_active: true,
    };
    const hall = {
      id: H_ID,
      location_type: 'WAREHOUSE',
      location_code: 'MAG-X',
      parent_id: null,
      is_active: true,
    };
    const m = new Map([
      [H_ID, hall],
      [S_ID, shelf],
    ]);
    const p = buildShelfPrintBarcodeParts(shelf, m);
    expect(p.barcodeValue).toBe('MAG-X - P-09');
    expect(p.displayPrimary).toBe('MAG-X - P-09');
    expect(p.presetHallFilterId).toBe(H_ID);
  });

  it('buildShelfPrintBarcodeParts ne uključuje nazive lokacija u štampu', () => {
    const shelf = {
      id: S_ID,
      location_type: 'SHELF',
      location_code: 'P-09',
      parent_id: H_ID,
      name: 'Farbanje A',
      is_active: true,
    };
    const hall = {
      id: H_ID,
      location_type: 'WAREHOUSE',
      location_code: 'MAG-X',
      name: 'Centralni magacin',
      parent_id: null,
      is_active: true,
    };
    const m = new Map([
      [H_ID, hall],
      [S_ID, shelf],
    ]);
    const p = buildShelfPrintBarcodeParts(shelf, m);
    expect(p.barcodeValue).toBe('MAG-X - P-09');
  });

  it('parseShortShelfBarcodePair prima znak crtice kao separator', () => {
    expect(parseShortShelfBarcodePair('MAG-X - P-09')).toEqual({
      hallCode: 'MAG-X',
      shelfCode: 'P-09',
    });
    expect(parseShortShelfBarcodePair('A - BC - XY')).toEqual({
      hallCode: 'A',
      shelfCode: 'BC - XY',
    });
    expect(parseShortShelfBarcodePair(`LP:${H_ID}:${S_ID}`)).toBe(null);
  });

  it('resolveCompositeShelfScan kratkog formata MAG-X - P-09', () => {
    const shelf = {
      id: S_ID,
      location_type: 'SHELF',
      location_code: 'P-09',
      parent_id: H_ID,
      is_active: true,
    };
    const hall = {
      id: H_ID,
      location_type: 'WAREHOUSE',
      location_code: 'MAG-X',
      parent_id: null,
      is_active: true,
    };
    const locs = [hall, shelf];
    const map = new Map(locs.map(l => [l.id, l]));
    const r = resolveCompositeShelfScan('MAG-X - P-09', locs, map);
    expect(r?.ok).toBe(true);
    if (r?.ok) expect(r.loc.id).toBe(S_ID);
  });

  it('resolveCompositeShelfScan LP i dalje prolazi na starim naljepnicama', () => {
    const shelf = {
      id: S_ID,
      location_type: 'SHELF',
      location_code: 'P-09',
      parent_id: H_ID,
      is_active: true,
    };
    const hall = {
      id: H_ID,
      location_type: 'WAREHOUSE',
      location_code: 'MAG-X',
      parent_id: null,
      is_active: true,
    };
    const locs = [hall, shelf];
    const map = new Map(locs.map(l => [l.id, l]));
    const tok = `LP:${H_ID}:${S_ID}`;
    expect(parseShelfCompositeBarcodeToken(tok)).toEqual({
      hallId: H_ID,
      shelfId: S_ID,
    });
    const r = resolveCompositeShelfScan(tok, locs, map);
    expect(r?.ok).toBe(true);
    if (r?.ok) expect(r.loc.id).toBe(S_ID);
  });

  it('resolveCompositeShelfScan odbije kad hall u LP barkodu nije ancestr polici', () => {
    const shelf = {
      id: S_ID,
      location_type: 'SHELF',
      location_code: 'P-09',
      parent_id: H_ID,
      is_active: true,
    };
    const hall = {
      id: H_ID,
      location_type: 'WAREHOUSE',
      location_code: 'MAG-X',
      parent_id: null,
      is_active: true,
    };
    const otherHall = {
      id: H2_ID,
      location_type: 'WAREHOUSE',
      location_code: 'PROD-Y',
      parent_id: null,
      is_active: true,
    };
    const locs = [hall, otherHall, shelf];
    const map = new Map(locs.map(l => [l.id, l]));
    const r = resolveCompositeShelfScan(`LP:${H2_ID}:${S_ID}`, locs, map);
    expect(r?.ok).toBe(false);
  });

  it('nearestHallAncestorId preskače zonu do halе', () => {
    const zone = {
      id: 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
      location_type: 'OTHER',
      parent_id: H_ID,
    };
    const shelf = {
      id: S_ID,
      location_type: 'BIN',
      parent_id: zone.id,
    };
    const hall = {
      id: H_ID,
      location_type: 'WAREHOUSE',
      parent_id: null,
    };
    const m = new Map([
      [H_ID, hall],
      [zone.id, zone],
      [S_ID, shelf],
    ]);
    expect(nearestHallAncestorId(shelf, m)).toBe(H_ID);
  });
});
