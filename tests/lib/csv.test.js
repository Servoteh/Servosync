/**
 * Unit testovi za `src/lib/csv.js`.
 * Ne koriste DOM — pure funkcije.
 */

import { describe, it, expect } from 'vitest';
import { toCsvField, rowsToCsv, CSV_BOM, parseCsv } from '../../src/lib/csv.js';

describe('toCsvField', () => {
  it('vraća prazan string za null i undefined', () => {
    expect(toCsvField(null)).toBe('');
    expect(toCsvField(undefined)).toBe('');
  });

  it('pravi string-ovi ne dobijaju navodnike', () => {
    expect(toCsvField('hello')).toBe('hello');
    expect(toCsvField('1234')).toBe('1234');
    expect(toCsvField('a b c')).toBe('a b c');
  });

  it('brojevi i booleani su stringifikovani bez navodnika', () => {
    expect(toCsvField(42)).toBe('42');
    expect(toCsvField(0)).toBe('0');
    expect(toCsvField(true)).toBe('true');
    expect(toCsvField(false)).toBe('false');
  });

  it('zarez zahteva navodnike', () => {
    expect(toCsvField('a,b')).toBe('"a,b"');
  });

  it('duplira interne navodnike', () => {
    expect(toCsvField('he said "hi"')).toBe('"he said ""hi"""');
  });

  it('novi redovi zahtevaju navodnike', () => {
    expect(toCsvField('line1\nline2')).toBe('"line1\nline2"');
    expect(toCsvField('line1\r\nline2')).toBe('"line1\r\nline2"');
  });

  it('Date → ISO 8601', () => {
    const d = new Date('2024-03-15T10:20:30Z');
    expect(toCsvField(d)).toBe('2024-03-15T10:20:30.000Z');
  });

  it('nevažeći Date → prazno', () => {
    const bad = new Date('zzz');
    expect(toCsvField(bad)).toBe('');
  });

  it('objekat → JSON', () => {
    expect(toCsvField({ a: 1 })).toBe('"{""a"":1}"');
  });
});

describe('rowsToCsv', () => {
  it('sastavlja header + rows sa CRLF', () => {
    const csv = rowsToCsv(
      ['A', 'B', 'C'],
      [
        ['1', '2', '3'],
        ['4', '5', '6'],
      ],
    );
    expect(csv).toBe('A,B,C\r\n1,2,3\r\n4,5,6');
  });

  it('escapuje zarez u headeru i redu', () => {
    const csv = rowsToCsv(['a,b', 'c'], [['"x"', 'y']]);
    expect(csv).toBe('"a,b",c\r\n"""x""",y');
  });

  it('prazni redovi daju samo header', () => {
    expect(rowsToCsv(['A', 'B'], [])).toBe('A,B');
  });

  it('null/undefined ćelije postaju prazne', () => {
    const csv = rowsToCsv(['A', 'B'], [[null, undefined]]);
    expect(csv).toBe('A,B\r\n,');
  });

  it('mešavina tipova u jednom redu', () => {
    const csv = rowsToCsv(
      ['num', 'str', 'bool'],
      [[1, 'hello, world', true]],
    );
    expect(csv).toBe('num,str,bool\r\n1,"hello, world",true');
  });
});

describe('CSV_BOM', () => {
  it('je UTF-8 BOM karakter', () => {
    expect(CSV_BOM).toBe('\uFEFF');
    expect(CSV_BOM.length).toBe(1);
  });

  it('prefix + CSV daje validan Excel-friendly dokument', () => {
    const csv = CSV_BOM + rowsToCsv(['Kod', 'Naziv'], [['A-1', 'Čamac žute boje']]);
    expect(csv).toBe('\uFEFFKod,Naziv\r\nA-1,Čamac žute boje');
  });
});

describe('parseCsv', () => {
  it('razbija header i redove', () => {
    const { headers, rows } = parseCsv('a,b\r\n1,2\r\n3,4');
    expect(headers).toEqual(['a', 'b']);
    expect(rows).toEqual([
      ['1', '2'],
      ['3', '4'],
    ]);
  });

  it('podržava navodnike i zarez u polju', () => {
    const { headers, rows } = parseCsv('"a,b","c"\r\n"""x""",y');
    expect(headers).toEqual(['a,b', 'c']);
    expect(rows).toEqual([['"x"', 'y']]);
  });

  it('uklanja UTF-8 BOM', () => {
    const { headers } = parseCsv('\uFEFFh1\nv1');
    expect(headers).toEqual(['h1']);
  });

  it('preskače prazne redove na kraju', () => {
    const { rows } = parseCsv('A\n1\n\n');
    expect(rows).toEqual([['1']]);
  });
});
