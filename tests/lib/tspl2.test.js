import { describe, it, expect } from 'vitest';
import { buildTspLabelProgram, buildTspShelfLabelProgram } from '../../src/lib/tspl2.js';

describe('buildTspLabelProgram', () => {
  const baseSpec = {
    fields: {
      brojPredmeta: '7351/1088',
      komitent: 'Jugoimport SDPR',
      nazivPredmeta: 'Perun – automatski punjač',
      nazivDela: 'PRIGUŠENJE 1 40/22 - KONUS',
      brojCrteza: '1130927',
      kolicina: '1/96',
      materijal: 'Č.4732 FI30X30',
      datum: '23-04-26',
    },
    barcodeValue: 'RNZ:0:7351/1088:0:0',
  };

  it('generates a valid TSPL2 program with required setup commands', () => {
    const out = buildTspLabelProgram(baseSpec);
    expect(out).toContain('SIZE 80 mm, 50 mm');
    expect(out).toContain('GAP 3 mm, 0 mm');
    expect(out).toContain('DIRECTION 1');
    expect(out).toContain('CLS');
    expect(out).toContain('PRINT 1,1');
    expect(out).toContain('CODEPAGE 1252');
  });

  it('embeds the RNZ barcode value verbatim in BARCODE command', () => {
    const out = buildTspLabelProgram(baseSpec);
    expect(out).toMatch(/BARCODE [\d]+,[\d]+,"128M",[\d]+,2,0,2,4,"RNZ:0:7351\/1088:0:0"/);
  });

  it('transliterates Serbian diacritics to ASCII for TEXT fields', () => {
    const out = buildTspLabelProgram(baseSpec);
    /* Č → C, š → s, ž → z, ć → c, đ → dj */
    expect(out).toContain('"Mat: C.4732 FI30X30  |  Dat: 23-04-26"');
    expect(out).toContain('"Deo: PRIGUSENJE 1 40/22 - KONUS"');
    expect(out).toMatch(/Predmet: Perun (-|–) automatski punjac/);
    /* Ne sme da ostane original sa dijakriticima */
    expect(out).not.toMatch(/Č\.4732/);
    expect(out).not.toMatch(/PRIGUŠENJE/);
    expect(out).not.toMatch(/punjač/);
  });

  it('honors copies parameter via PRINT command', () => {
    const out = buildTspLabelProgram({ ...baseSpec, copies: 5 });
    expect(out).toContain('PRINT 5,1');
  });

  it('throws if barcodeValue missing', () => {
    expect(() => buildTspLabelProgram({ fields: {}, barcodeValue: '' })).toThrow();
    expect(() => buildTspLabelProgram({ fields: {}, barcodeValue: null })).toThrow();
  });

  it('omits TEXT lines when corresponding field is missing', () => {
    const sparse = {
      fields: { brojPredmeta: '9000/522' },
      barcodeValue: 'RNZ:0:9000/522:0:0',
    };
    const out = buildTspLabelProgram(sparse);
    expect(out).toContain('"RN: 9000/522"');
    expect(out).not.toMatch(/Komitent/);
    expect(out).not.toMatch(/Materijal|Mat:/);
    /* Barkod uvek mora biti prisutan */
    expect(out).toContain('BARCODE');
  });

  it('escapes embedded double quotes by replacing with single quotes', () => {
    const out = buildTspLabelProgram({
      fields: { brojPredmeta: 'TEST "QUOTE"' },
      barcodeValue: 'RNZ:0:1/1:0:0',
    });
    /* Posle escape-a, dupli navodnici postaju jednostruki da TSPL2 parser
     * ne prekine string parametra. */
    expect(out).toContain("\"RN: TEST 'QUOTE'\"");
  });

  it('terminates each command with CRLF (TSC firmware requires it)', () => {
    const out = buildTspLabelProgram(baseSpec);
    expect(out.endsWith('\r\n')).toBe(true);
    expect(out).toContain('\r\n');
  });
});

describe('buildTspShelfLabelProgram', () => {
  it('generates valid program for shelf label', () => {
    const out = buildTspShelfLabelProgram({ location_code: 'MAG-1.A.03', name: 'Polica A03' });
    expect(out).toContain('SIZE 80 mm, 50 mm');
    expect(out).toContain('"MAG-1.A.03"');
    expect(out).toContain('"Polica A03"');
    expect(out).toMatch(/BARCODE [\d]+,[\d]+,"128M"/);
    expect(out).toContain('PRINT 1,1');
  });

  it('throws if location_code missing', () => {
    expect(() => buildTspShelfLabelProgram({ location_code: '' })).toThrow();
  });

  it('handles empty name gracefully', () => {
    const out = buildTspShelfLabelProgram({ location_code: 'X1' });
    expect(out).toContain('"X1"');
  });

  it('honors copies parameter', () => {
    const out = buildTspShelfLabelProgram({ location_code: 'X1', copies: 3 });
    expect(out).toContain('PRINT 3,1');
  });
});
