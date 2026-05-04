import { describe, it, expect } from 'vitest';
import {
  normalizeBarcodeText,
  parseBigTehnBarcode,
  parsePredmetTpFromLabelText,
  formatBigTehnRnzBarcode,
  formatBigTehnShortBarcode,
} from '../../src/lib/barcodeParse.js';

describe('normalizeBarcodeText', () => {
  it('trimuje razmake, CR i LF', () => {
    expect(normalizeBarcodeText('  9000/260\r\n')).toBe('9000/260');
    expect(normalizeBarcodeText('\t1091063 ')).toBe('1091063');
  });

  it('skida Code39 *TEXT* delimitere', () => {
    expect(normalizeBarcodeText('*1084924*')).toBe('1084924');
    expect(normalizeBarcodeText('*9000/260*')).toBe('9000/260');
  });

  it('ne dira single-star strings', () => {
    expect(normalizeBarcodeText('*')).toBe('*');
    expect(normalizeBarcodeText('**')).toBe('**');
  });

  it('vraća "" za non-string input', () => {
    expect(normalizeBarcodeText(null)).toBe('');
    expect(normalizeBarcodeText(undefined)).toBe('');
    expect(normalizeBarcodeText(42)).toBe('');
  });
});

describe('parseBigTehnBarcode — RNZ format (current production)', () => {
  it('parsira realan RNZ barkod iz magacina', () => {
    expect(parseBigTehnBarcode('RNZ:8693:7351/1088:0:39757')).toEqual({
      idrn: '8693',
      orderNo: '7351',
      itemRefId: '1088',
      drawingNo: '',
      format: 'rnz',
      raw: 'RNZ:8693:7351/1088:0:39757',
      varijanta: '0',
      field4: '39757',
    });
  });

  it('parsira alfanumerički TP (crtice + slova)', () => {
    const r1 = parseBigTehnBarcode('RNZ:9833:9400/7-5-S1:1:44963');
    expect(r1).not.toBeNull();
    expect(r1?.format).toBe('rnz');
    expect(r1?.orderNo).toBe('9400');
    expect(r1?.itemRefId).toBe('7-5-S1');
    expect(r1?.idrn).toBe('9833');
    expect(r1?.varijanta).toBe('1');
    expect(r1?.field4).toBe('44963');
    expect(r1?.drawingNo).toBe('');
  });

  it('ne regresira čisto numerički TP', () => {
    const r2 = parseBigTehnBarcode('RNZ:9466:8069/830:0:44586');
    expect(r2).not.toBeNull();
    expect(r2?.orderNo).toBe('8069');
    expect(r2?.itemRefId).toBe('830');
    expect(r2?.idrn).toBe('9466');
  });

  it('izdvaja idrn, varijantu i field4', () => {
    const a = parseBigTehnBarcode('RNZ:1:5000/100:0:99999');
    expect(a?.orderNo).toBe('5000');
    expect(a?.itemRefId).toBe('100');
    expect(a?.format).toBe('rnz');
    expect(a?.idrn).toBe('1');
    expect(a?.varijanta).toBe('0');
    expect(a?.field4).toBe('99999');
  });

  it('toleriše razmake između segmenata', () => {
    expect(parseBigTehnBarcode('RNZ : 8693 : 7351/1088 : 0 : 39757')?.orderNo).toBe('7351');
  });

  it('toleriše | umesto : (kao Code39 escape)', () => {
    expect(parseBigTehnBarcode('RNZ|8693|7351/1088|0|39757')?.itemRefId).toBe('1088');
  });

  it('case-insensitive prefix', () => {
    expect(parseBigTehnBarcode('rnz:1:5000/100:0:1')?.format).toBe('rnz');
    expect(parseBigTehnBarcode('Rnz:1:5000/100:0:1')?.format).toBe('rnz');
  });

  it('odbija RNZ sa premalo segmenata', () => {
    expect(parseBigTehnBarcode('RNZ:8693:7351/1088')).toBeNull();
    expect(parseBigTehnBarcode('RNZ:7351/1088')).toBeNull();
  });
});

describe('parseBigTehnBarcode — legacy short format', () => {
  it('parsira stari NALOG/CRTEŽ', () => {
    expect(parseBigTehnBarcode('9000/1091063')).toEqual({
      orderNo: '9000',
      itemRefId: '1091063',
      drawingNo: '1091063',
      format: 'short',
      raw: '9000/1091063',
    });
  });

  it('parsira kraće varijante sa manjim brojem crteža', () => {
    expect(parseBigTehnBarcode('9000/260')?.itemRefId).toBe('260');
  });

  it('toleriše razmake oko razdvajača', () => {
    expect(parseBigTehnBarcode('9000 / 1091063')?.drawingNo).toBe('1091063');
  });

  it('toleriše alternativne razdvajače (backslash/dash/underscore)', () => {
    expect(parseBigTehnBarcode('9000\\1091063')?.drawingNo).toBe('1091063');
    expect(parseBigTehnBarcode('9000-1091063')?.drawingNo).toBe('1091063');
    expect(parseBigTehnBarcode('9000_1091063')?.drawingNo).toBe('1091063');
    expect(parseBigTehnBarcode('9000 1091063')?.drawingNo).toBe('1091063');
  });

  it('skida Code39 `*` pre parsiranja', () => {
    expect(parseBigTehnBarcode('*9000/1091063*')?.orderNo).toBe('9000');
  });
});

describe('parsePredmetTpFromLabelText — OCR sa nalepnice', () => {
  it('parsira broj predmeta / TP iz jedne linije', () => {
    expect(parsePredmetTpFromLabelText('7351/1088')).toMatchObject({
      orderNo: '7351',
      itemRefId: '1088',
      format: 'ocr',
    });
  });

  it('radi za blok teksta sa oznakama', () => {
    const t = `Broj predmeta / Tehnološki postupak\n7351/1088`;
    expect(parsePredmetTpFromLabelText(t)?.itemRefId).toBe('1088');
  });

  it('toleriše tipične OCR greške u razdvajaču', () => {
    expect(parsePredmetTpFromLabelText('7351|1088')?.orderNo).toBe('7351');
    expect(parsePredmetTpFromLabelText('7351\\1088')?.itemRefId).toBe('1088');
  });

  it('vraća null bez validnog para', () => {
    expect(parsePredmetTpFromLabelText('')).toBeNull();
    expect(parsePredmetTpFromLabelText('samo tekst')).toBeNull();
  });
});

describe('parseBigTehnBarcode — invalid input', () => {
  it('vraća null za random string', () => {
    expect(parseBigTehnBarcode('RANDOM_STRING')).toBeNull();
  });

  it('vraća null za plain broj crteža (samo drawing no)', () => {
    expect(parseBigTehnBarcode('1091063')).toBeNull();
    expect(parseBigTehnBarcode('1084924')).toBeNull();
  });

  it('vraća null za prazan / neiksrni / ne-numerički input', () => {
    expect(parseBigTehnBarcode('')).toBeNull();
    expect(parseBigTehnBarcode(null)).toBeNull();
    expect(parseBigTehnBarcode('ABC/DEF')).toBeNull();
    expect(parseBigTehnBarcode('9000/ABC')).toBeNull();
    expect(parseBigTehnBarcode('9000//1091063')).toBeNull();
    expect(parseBigTehnBarcode('9000/1091063/extra')).toBeNull();
  });

  it('ne hvata prevelike brojeve (chaos safeguard)', () => {
    expect(parseBigTehnBarcode('999999999/1')).toBeNull(); // 9-cifreni nalog
    expect(parseBigTehnBarcode('1/12345678901')).toBeNull(); // 11-cifreni crtež
  });
});

describe('formatBigTehnRnzBarcode / formatBigTehnShortBarcode', () => {
  it('RNZ generator round-trip sa parserom', () => {
    const raw = formatBigTehnRnzBarcode({
      internalId: '8693',
      orderNo: '7351',
      tpNo: '1088',
      segment3: '0',
      segment4: '39757',
    });
    expect(raw).toBe('RNZ:8693:7351/1088:0:39757');
    expect(parseBigTehnBarcode(raw)).toMatchObject({
      orderNo: '7351',
      itemRefId: '1088',
      format: 'rnz',
    });
  });

  it('short format round-trip', () => {
    const s = formatBigTehnShortBarcode('9000', '1091063');
    expect(s).toBe('9000/1091063');
    expect(parseBigTehnBarcode(s)?.format).toBe('short');
  });
});
