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

  it('skida zero-width znakove', () => {
    expect(normalizeBarcodeText('9833\u200B:9400/7-5:0')).toBe('9833:9400/7-5:0');
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

  it('parsira alfanumerički TP i varijantu (RNZ)', () => {
    const r = parseBigTehnBarcode('RNZ:9833:9400/7-5-S1:1:44963');
    expect(r).toMatchObject({
      format: 'rnz',
      idrn: '9833',
      orderNo: '9400',
      itemRefId: '7-5-S1',
      varijanta: '1',
      field4: '44963',
      drawingNo: '',
    });
  });

  it('parsira TP sa kosom crtom u ref-u (RNZ)', () => {
    expect(parseBigTehnBarcode('RNZ:10348:9400/1/300:0:44706')).toEqual({
      idrn: '10348',
      orderNo: '9400',
      itemRefId: '1/300',
      drawingNo: '',
      format: 'rnz',
      raw: 'RNZ:10348:9400/1/300:0:44706',
      varijanta: '0',
      field4: '44706',
    });
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
  it('parsira kratki format sa troznamenkastim crtežom (gust Code128 na štampi)', () => {
    expect(parseBigTehnBarcode('9000/365')).toEqual({
      orderNo: '9000',
      itemRefId: '365',
      drawingNo: '365',
      format: 'short',
      raw: '9000/365',
    });
  });

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

describe('parseBigTehnBarcode — compact label (fallback bez RNZ:)', () => {
  it('parsira nalepnicu 9833:9400/7-5:0', () => {
    expect(parseBigTehnBarcode('9833:9400/7-5:0')).toEqual({
      idrn: '9833',
      orderNo: '9400',
      itemRefId: '7-5',
      drawingNo: '',
      format: 'compact',
      raw: '9833:9400/7-5:0',
      varijanta: '0',
      field4: '',
    });
  });

  it('toleriše | i ; umesto : (čitač)', () => {
    expect(parseBigTehnBarcode('9833|9400/7-5|0')).toMatchObject({
      format: 'compact',
      idrn: '9833',
      orderNo: '9400',
      itemRefId: '7-5',
      varijanta: '0',
    });
  });

  it('RNZ i dalje ima prioritet (isti brojevi, drugačiji oblik)', () => {
    expect(parseBigTehnBarcode('RNZ:9833:9400/7-5:0:44963')).toMatchObject({
      format: 'rnz',
      orderNo: '9400',
      itemRefId: '7-5',
    });
  });

  it('short format ima prioritet pre compact (samo nalog/crtež)', () => {
    expect(parseBigTehnBarcode('9000/1091063')?.format).toBe('short');
  });

  it('vraća null ako fali varijanta ili TP ima nedozvoljen znak', () => {
    expect(parseBigTehnBarcode('9833:9400/7-5')).toBeNull();
    expect(parseBigTehnBarcode('9833:9400/7_5:0')).toBeNull();
  });
});

describe('parseBigTehnBarcode — invalid input', () => {
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

  it('RNZ generator čuva kosu crtu u tpNo (round-trip)', () => {
    const raw = formatBigTehnRnzBarcode({
      internalId: '10348',
      orderNo: '9400',
      tpNo: '1/300',
      segment3: '0',
      segment4: '44706',
    });
    expect(raw).toBe('RNZ:10348:9400/1/300:0:44706');
    expect(parseBigTehnBarcode(raw)?.itemRefId).toBe('1/300');
  });

  it('short format round-trip', () => {
    const s = formatBigTehnShortBarcode('9000', '1091063');
    expect(s).toBe('9000/1091063');
    expect(parseBigTehnBarcode(s)?.format).toBe('short');
  });
});
