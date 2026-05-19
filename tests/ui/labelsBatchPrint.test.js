import { describe, it, expect } from 'vitest';
import { composeReversiBatchTspl } from '../../src/ui/reversi/labelsBatchPrint.js';

describe('composeReversiBatchTspl', () => {
  it('emits BARCODE per item x copies with PRINT 1,1', () => {
    const rows = [
      { barcode: 'ALAT-000001', oznaka: 'A1', naziv: 'Test', kind: 'HAND' },
      { barcode: 'RZN-000002', oznaka: 'R1', naziv: 'Pločica', klasa: 'X' },
    ];
    const out = composeReversiBatchTspl(rows, 'standard', 2);
    const barcodes = (out.match(/BARCODE/g) || []).length;
    expect(barcodes).toBe(4);
    expect(out).toContain('PRINT 1,1');
  });

  it('uses mini template for inserts', () => {
    const out = composeReversiBatchTspl(
      [{ barcode: 'RZN-000003', oznaka: 'P1', klasa: 'Pločica' }],
      'mini',
      3,
    );
    expect((out.match(/BARCODE/g) || []).length).toBe(3);
    expect(out).toContain('PRINT 1,1');
  });
});
