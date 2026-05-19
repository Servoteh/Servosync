import { describe, it, expect } from 'vitest';
import {
  computeAgingBuckets,
  computeMachineLoadCards,
} from '../../src/ui/reversi/revMapaCompute.js';

describe('computeAgingBuckets', () => {
  it('classifies fresh, aging, and overdue documents', () => {
    const today = new Date();
    const d7 = new Date(today);
    d7.setDate(d7.getDate() - 5);
    const d20 = new Date(today);
    d20.setDate(d20.getDate() - 20);
    const docs = [
      { issued_at: d7.toISOString(), expected_return_date: null, status: 'OPEN' },
      { issued_at: d20.toISOString(), expected_return_date: null, status: 'OPEN' },
      { issued_at: d7.toISOString(), expected_return_date: '2000-01-01', status: 'OPEN' },
    ];
    const b = computeAgingBuckets(docs);
    expect(b).toMatchSnapshot();
    expect(b.total).toBe(3);
    expect(b.overdue).toBeGreaterThanOrEqual(1);
  });
});

describe('computeMachineLoadCards', () => {
  it('aggregates symbols per machine with fill percent', () => {
    const documents = [
      { recipient_machine_code: '8.3', catalog_id: 'a' },
      { recipient_machine_code: '8.3', catalog_id: 'b' },
      { recipient_machine_code: '10.1', catalog_id: 'c', expected_return_date: '2000-01-01' },
    ];
    const machines = [
      { rj_code: '8.3', name: 'CNC 8.3' },
      { rj_code: '10.1', name: 'CNC 10.1' },
    ];
    const cards = computeMachineLoadCards(documents, machines, { capacity: 20 });
    expect(cards).toMatchSnapshot();
    expect(cards.find((c) => c.machine_code === '8.3')?.symbol_count).toBe(2);
    expect(cards.find((c) => c.machine_code === '8.3')?.fill_pct).toBe(10);
  });
});
