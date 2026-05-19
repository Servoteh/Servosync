import { describe, it, expect } from 'vitest';
import { splitLinesForRpc } from '../../src/ui/reversi/quickIssueModal.js';

describe('splitLinesForRpc', () => {
  it('splits hand and cutting lines', () => {
    const lines = [
      { kind: 'HAND', tool: { id: '1' } },
      { kind: 'CUTTING', tool: { id: '2' }, qty: 3 },
      { kind: 'HAND', tool: { id: '3' } },
    ];
    const { hand, cutting } = splitLinesForRpc(lines);
    expect(hand).toHaveLength(2);
    expect(cutting).toHaveLength(1);
    expect(cutting[0].qty).toBe(3);
  });
});
