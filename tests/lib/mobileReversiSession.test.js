import { describe, it, expect, beforeEach, vi } from 'vitest';

vi.hoisted(() => {
  const store = new Map();
  globalThis.sessionStorage = {
    getItem: (k) => store.get(k) ?? null,
    setItem: (k, v) => store.set(k, String(v)),
    removeItem: (k) => store.delete(k),
    clear: () => store.clear(),
  };
});

import {
  getMobileRevMachine,
  setMobileRevMachine,
  getMobileRevOperator,
  setMobileRevOperator,
} from '../../src/lib/mobileReversiSession.js';

describe('mobileReversiSession', () => {
  beforeEach(() => {
    sessionStorage.clear();
  });

  it('stores and reads machine', () => {
    setMobileRevMachine({ rj_code: '8.3', name: 'CNC' });
    expect(getMobileRevMachine()).toEqual({ rj_code: '8.3', name: 'CNC' });
    setMobileRevMachine(null);
    expect(getMobileRevMachine()).toBeNull();
  });

  it('stores and reads operator', () => {
    setMobileRevOperator({ id: 'e1', full_name: 'Marko', department: 'Proizvodnja' });
    expect(getMobileRevOperator()).toEqual({
      id: 'e1',
      full_name: 'Marko',
      department: 'Proizvodnja',
    });
  });
});
