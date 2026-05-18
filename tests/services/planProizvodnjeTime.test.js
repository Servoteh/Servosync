import { describe, expect, it } from 'vitest';
import { plannedSeconds } from '../../src/services/planProizvodnje.js';

describe('plannedSeconds (remaining lot)', () => {
  it('uses full lot when nothing is done', () => {
    expect(plannedSeconds({ tpz_min: 2, tk_min: 1.5, komada_total: 100, komada_done: 0 }))
      .toBe(Math.round((2 + 1.5 * 100) * 60));
  });

  it('drops TPZ after first piece reported', () => {
    expect(plannedSeconds({ tpz_min: 10, tk_min: 1, komada_total: 100, komada_done: 1 }))
      .toBe(Math.round(1 * 99 * 60));
  });

  it('returns zero when lot is complete', () => {
    expect(plannedSeconds({ tpz_min: 5, tk_min: 2, komada_total: 50, komada_done: 50 }))
      .toBe(0);
  });

  it('caps done above total to zero remaining', () => {
    expect(plannedSeconds({ tpz_min: 1, tk_min: 1, komada_total: 10, komada_done: 15 }))
      .toBe(0);
  });
});
