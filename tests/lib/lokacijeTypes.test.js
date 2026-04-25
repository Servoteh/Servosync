import { describe, it, expect } from 'vitest';
import {
  canBeShelfParent,
  getLocationKind,
  getLocationKindLabel,
  getLocationTypeLabel,
  isHallType,
  isShelfType,
} from '../../src/lib/lokacijeTypes.js';

describe('lokacijeTypes', () => {
  it('klasifikuje šire HALA tipove', () => {
    for (const type of ['WAREHOUSE', 'PRODUCTION', 'ASSEMBLY', 'FIELD', 'TEMP']) {
      expect(isHallType(type)).toBe(true);
      expect(getLocationKind(type)).toBe('hall');
      expect(getLocationKindLabel(type)).toBe('HALA');
    }
  });

  it('klasifikuje POLICA tipove', () => {
    for (const type of ['SHELF', 'RACK', 'BIN']) {
      expect(isShelfType(type)).toBe(true);
      expect(getLocationKind(type)).toBe('shelf');
      expect(getLocationKindLabel(type)).toBe('POLICA');
    }
  });

  it('ostale tipove odvaja od hala i polica', () => {
    expect(getLocationKind('PROJECT')).toBe('other');
    expect(getLocationKindLabel('PROJECT')).toBe('OSTALO');
    expect(getLocationTypeLabel('PROJECT')).toBe('PROJECT');
  });

  it('samo aktivna HALA može biti roditelj police', () => {
    expect(canBeShelfParent({ location_type: 'WAREHOUSE', is_active: true })).toBe(true);
    expect(canBeShelfParent({ location_type: 'PRODUCTION' })).toBe(true);
    expect(canBeShelfParent({ location_type: 'SHELF', is_active: true })).toBe(false);
    expect(canBeShelfParent({ location_type: 'WAREHOUSE', is_active: false })).toBe(false);
  });
});
