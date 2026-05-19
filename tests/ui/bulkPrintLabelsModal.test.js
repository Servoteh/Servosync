import { describe, it, expect } from 'vitest';
import { composeMultiLabelTspl } from '../../src/ui/reversi/bulkPrintLabelsModal.js';

describe('composeMultiLabelTspl', () => {
  const rows = [
    { grupa: 'HAND', barcode: 'ALAT-000001', oznaka: 'A1', naziv: 'Test', asset_kind: 'GENERAL_TOOL' },
    { grupa: 'CUTTING', barcode: 'RZN-000002', oznaka: 'G1', naziv: 'Glodalo', klasa: 'glodalo' },
  ];

  it('returns string with rows.length * copies BARCODE commands', () => {
    const out = composeMultiLabelTspl(rows, 'standard', 2);
    const count = (out.match(/BARCODE /g) || []).length;
    expect(count).toBe(rows.length * 2);
    expect(out).toContain('CLS');
    expect(out).not.toContain('SIZE');
  });

  it('mini template uses BARCODE per row per copy', () => {
    const out = composeMultiLabelTspl(rows, 'mini', 3);
    expect((out.match(/BARCODE /g) || []).length).toBe(6);
  });
});
