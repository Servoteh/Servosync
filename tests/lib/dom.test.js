import { describe, it, expect } from 'vitest';
import { escHtml } from '../../src/lib/dom.js';

describe('escHtml', () => {
  it('vraća prazan string za null / undefined', () => {
    expect(escHtml(null)).toBe('');
    expect(escHtml(undefined)).toBe('');
  });

  it('escape-uje < > & " \' za XSS', () => {
    expect(escHtml('<script>alert("x")</script>')).toBe(
      '&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;',
    );
    expect(escHtml("it's")).toBe('it&#39;s');
    expect(escHtml('A & B')).toBe('A &amp; B');
  });

  it('ne menja plain text', () => {
    expect(escHtml('Lokacija 1')).toBe('Lokacija 1');
    expect(escHtml('M2-R1-P3')).toBe('M2-R1-P3');
  });

  it('konvertuje brojeve/booleane u string', () => {
    expect(escHtml(42)).toBe('42');
    expect(escHtml(true)).toBe('true');
    expect(escHtml(0)).toBe('0');
  });
});
