/** @vitest-environment jsdom */
import { describe, expect, it } from 'vitest';
import { sanitizeZapisnikPasteHtml } from '../../src/lib/sastanciPasteSanitize.js';

describe('sanitizeZapisnikPasteHtml', () => {
  it('strips inline style and class from pasted HTML', () => {
    const raw = '<p class="MsoNormal" style="color:red;font-family:Calibri">Hello</p>';
    const out = sanitizeZapisnikPasteHtml(raw);
    expect(out).not.toContain('style=');
    expect(out).not.toContain('class=');
    expect(out).toContain('Hello');
  });

  it('keeps allowed headings and lists', () => {
    const raw = '<h2>Title</h2><ul><li>one</li></ul>';
    const out = sanitizeZapisnikPasteHtml(raw);
    expect(out).toContain('<h2>');
    expect(out).toContain('<ul>');
    expect(out).toContain('<li>');
  });
});
