import { describe, expect, it } from 'vitest';
import {
  buildWhyExplanation,
  describeAutoSortBucket,
} from '../../src/ui/planProizvodnje/whyBottleneckModal.js';

describe('buildWhyExplanation', () => {
  it('flags blokiran lokalni status', () => {
    const d = buildWhyExplanation({
      local_status: 'blocked',
      is_ready_for_machine: true,
    });
    expect(d.summaryLine).toMatch(/blokirana/i);
    expect(d.tags.some(t => t.key === 'blocked')).toBe(true);
  });

  it('prioritet čeka prethodnu operaciju kada nije spremno', () => {
    const d = buildWhyExplanation({
      is_ready_for_machine: false,
      previous_operation_status: 'not_started',
      previous_operation_operacija: 5,
      previous_operation_machine_code: '3.1',
      local_status: 'waiting',
    });
    expect(d.summaryLine).toMatch(/prethodn/i);
    expect(d.blocks[0].lines.some(l => l.includes('prethod'))).toBe(true);
  });
});

describe('describeAutoSortBucket', () => {
  it('mapira bucket 6', () => {
    const s = describeAutoSortBucket({
      auto_sort_bucket: 6,
      local_status: 'waiting',
      is_ready_for_machine: false,
    });
    expect(s).toMatch(/prethodnu operaciju/i);
  });
});
