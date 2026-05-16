import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const { sbReqMock } = vi.hoisted(() => ({ sbReqMock: vi.fn() }));

vi.mock('../../src/services/supabase.js', () => ({
  sbReq: sbReqMock,
  getSupabaseUrl: () => 'https://example.supabase.co',
  getSupabaseAnonKey: () => 'anon-key',
}));

vi.mock('../../src/state/auth.js', () => ({
  canEditPlanProizvodnje: () => true,
  getCurrentUser: () => ({ email: 'g2@example.com' }),
  getIsOnline: () => true,
}));

vi.mock('../../src/services/drawings.js', () => ({
  BIGTEHN_DRAWINGS_BUCKET: 'bigtehn-drawings',
  getBigtehnDrawingSignedUrl: vi.fn(),
  parseSupabaseStorageSignResponse: vi.fn(),
  absolutizeSupabaseStorageSignedPath: vi.fn(),
}));

describe('PP-B sortByUrgencyAndReady', () => {
  it('sorts strict 0→1→2→3 by hitno × spremno, then rok', async () => {
    const { sortByUrgencyAndReady } = await import('../../src/services/planProizvodnje.js');
    const rows = [
      {
        id: 'b3', is_urgent: false, is_ready_for_machine: false, rok_izrade: '2026-04-01', work_order_id: 40, line_id: 1,
      },
      {
        id: 'b2', is_urgent: false, is_ready_for_machine: true, rok_izrade: '2026-06-01', work_order_id: 30, line_id: 1,
      },
      {
        id: 'b1', is_urgent: true, is_ready_for_machine: false, rok_izrade: '2026-05-01', work_order_id: 20, line_id: 1,
      },
      {
        id: 'b0', is_urgent: true, is_ready_for_machine: true, rok_izrade: '2026-07-01', work_order_id: 10, line_id: 1,
      },
    ];

    expect(sortByUrgencyAndReady(rows).map(r => r.id)).toEqual(['b0', 'b1', 'b2', 'b3']);
  });

  it('within urgent+ready bucket uses shift_sort_order before rok', async () => {
    const { sortByUrgencyAndReady } = await import('../../src/services/planProizvodnje.js');
    const rows = [
      {
        id: 'late-shift', is_urgent: true, is_ready_for_machine: true, shift_sort_order: 2, rok_izrade: '2026-04-01',
        work_order_id: 1, line_id: 1,
      },
      {
        id: 'early-shift', is_urgent: true, is_ready_for_machine: true, shift_sort_order: 1, rok_izrade: '2026-05-01',
        work_order_id: 1, line_id: 2,
      },
      {
        id: 'pinned-null', is_urgent: true, is_ready_for_machine: true, shift_sort_order: null, rok_izrade: '2026-01-01',
        work_order_id: 2, line_id: 1,
      },
    ];
    expect(sortByUrgencyAndReady(rows).map(r => r.id)).toEqual(['early-shift', 'late-shift', 'pinned-null']);
  });

  it('lower-bucket pinned rows rank after urgent+ready block', async () => {
    const { sortByUrgencyAndReady } = await import('../../src/services/planProizvodnje.js');
    const rows = [
      {
        id: 'auto-hit-ready', is_urgent: true, is_ready_for_machine: true, shift_sort_order: null, rok_izrade: '2026-04-01',
        work_order_id: 99, line_id: 1,
      },
      {
        id: 'pinned-not-urg', is_urgent: false, is_ready_for_machine: true, shift_sort_order: 1, rok_izrade: '2026-03-01',
        work_order_id: 1, line_id: 2,
      },
    ];
    expect(sortByUrgencyAndReady(rows).map(r => r.id)).toEqual(['auto-hit-ready', 'pinned-not-urg']);
  });
});

describe('urgencyReadyBucketsAreNonDecreasing', () => {
  it('detects inversion across buckets', async () => {
    const { urgencyReadyBucketsAreNonDecreasing } = await import('../../src/services/planProizvodnje.js');
    const ok = [
      { is_urgent: true, is_ready_for_machine: true },
      { is_urgent: true, is_ready_for_machine: false },
    ];
    const bad = [
      { is_urgent: false, is_ready_for_machine: false },
      { is_urgent: true, is_ready_for_machine: true },
    ];
    expect(urgencyReadyBucketsAreNonDecreasing(ok)).toBe(true);
    expect(urgencyReadyBucketsAreNonDecreasing(bad)).toBe(false);
  });
});

describe('G2 writers', () => {
  beforeEach(() => {
    sbReqMock.mockReset();
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-04-25T10:15:30.000Z'));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('upserts urgent metadata for a work order', async () => {
    const { setUrgent } = await import('../../src/services/planProizvodnje.js');
    sbReqMock.mockResolvedValue([{ work_order_id: 101 }]);

    await setUrgent(101, 'Kupac traži prioritet');

    expect(sbReqMock).toHaveBeenCalledWith(
      'production_urgency_overrides?on_conflict=work_order_id',
      'POST',
      {
        work_order_id: 101,
        is_urgent: true,
        reason: 'Kupac traži prioritet',
        set_by: 'g2@example.com',
        set_at: '2026-04-25T10:15:30.000Z',
        cleared_at: null,
        cleared_by: null,
      },
    );
  });

  it('clears urgent metadata for a work order', async () => {
    const { clearUrgent } = await import('../../src/services/planProizvodnje.js');
    sbReqMock.mockResolvedValue([{ work_order_id: 101 }]);

    await clearUrgent(101);

    expect(sbReqMock).toHaveBeenCalledWith(
      'production_urgency_overrides?on_conflict=work_order_id',
      'POST',
      {
        work_order_id: 101,
        is_urgent: false,
        cleared_at: '2026-04-25T10:15:30.000Z',
        cleared_by: 'g2@example.com',
      },
    );
  });

  it('pins an operation above existing manual order', async () => {
    const { pinToTop } = await import('../../src/services/planProizvodnje.js');
    sbReqMock.mockResolvedValue([{ id: 1 }]);

    await pinToTop(
      { work_order_id: 101, line_id: 202 },
      [{ shift_sort_order: 5 }, { shift_sort_order: 9 }, { shift_sort_order: null }],
    );

    expect(sbReqMock).toHaveBeenCalledWith(
      'production_overlays?on_conflict=work_order_id,line_id',
      'POST',
      expect.objectContaining({
        work_order_id: 101,
        line_id: 202,
        shift_sort_order: 4,
        updated_by: 'g2@example.com',
        created_by: 'g2@example.com',
      }),
    );
  });

  it('unpins an operation by clearing shift_sort_order', async () => {
    const { unpin } = await import('../../src/services/planProizvodnje.js');
    sbReqMock.mockResolvedValue([{ id: 1 }]);

    await unpin({ work_order_id: 101, line_id: 202 });

    expect(sbReqMock).toHaveBeenCalledWith(
      'production_overlays?on_conflict=work_order_id,line_id',
      'POST',
      expect.objectContaining({
        work_order_id: 101,
        line_id: 202,
        shift_sort_order: null,
      }),
    );
  });
});
