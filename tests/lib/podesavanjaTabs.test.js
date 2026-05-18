import { describe, it, expect } from 'vitest';
import {
  parsePodesavanjaTabFromLocation,
  buildPodesavanjaModulePath,
  PODESAVANJA_TAB_IDS,
} from '../../src/lib/podesavanjaTabs.js';

describe('podesavanjaTabs', () => {
  it('parses valid tab ids', () => {
    expect(parsePodesavanjaTabFromLocation('users')).toBe('users');
    expect(parsePodesavanjaTabFromLocation('predmet-aktivacija')).toBe('predmet-aktivacija');
    expect(parsePodesavanjaTabFromLocation('invalid')).toBeNull();
  });

  it('buildPodesavanjaModulePath', () => {
    expect(buildPodesavanjaModulePath('users')).toBe('/podesavanja?tab=users');
    expect(buildPodesavanjaModulePath()).toBe('/podesavanja');
  });

  it('knows system tab', () => {
    expect(PODESAVANJA_TAB_IDS).toContain('system');
    expect(PODESAVANJA_TAB_IDS).toContain('notifikacije');
  });
});
