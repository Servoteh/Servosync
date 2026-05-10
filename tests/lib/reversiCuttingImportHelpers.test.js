/**
 * Ponašanje pomoćnih pravila za REVERSI rezni alat (bez importa modula).
 */
import { describe, it, expect } from 'vitest';

function parseRecipientList(raw) {
  return [...new Set(String(raw || '').split(/\s*,\s*/).map((x) => x.trim()).filter(Boolean))];
}

describe('reversi cutting import — lista primalaca', () => {
  it('razdvaja zarezom i trimuje', () => {
    expect(parseRecipientList('A , B')).toEqual(['A', 'B']);
  });
  it('uklanja duplikate', () => {
    expect(parseRecipientList('X, X, Y')).toEqual(['X', 'Y']);
  });
});
