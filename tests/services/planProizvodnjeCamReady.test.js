import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const { sbReqMock } = vi.hoisted(() => ({ sbReqMock: vi.fn() }));

vi.mock('../../src/services/supabase.js', () => ({
  sbReq: sbReqMock,
  getSupabaseUrl: () => 'https://example.supabase.co',
  getSupabaseAnonKey: () => 'anon-key',
}));

vi.mock('../../src/state/auth.js', () => ({
  canEditPlanProizvodnje: () => true,
  getCurrentUser: () => ({ email: 'cam@example.com' }),
  getIsOnline: () => true,
}));

vi.mock('../../src/services/drawings.js', () => ({
  BIGTEHN_DRAWINGS_BUCKET: 'bigtehn-drawings',
  getBigtehnDrawingSignedUrl: vi.fn(),
  parseSupabaseStorageSignResponse: vi.fn(),
  absolutizeSupabaseStorageSignedPath: vi.fn(),
}));

describe('setCamReady', () => {
  beforeEach(() => {
    sbReqMock.mockReset();
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-04-25T10:15:30.000Z'));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('upserts cam ready metadata for an operation', async () => {
    const { setCamReady } = await import('../../src/services/planProizvodnje.js');
    sbReqMock.mockResolvedValue([{ id: 1 }]);

    await setCamReady(101, 202, true);

    expect(sbReqMock).toHaveBeenCalledWith(
      'production_overlays?on_conflict=work_order_id,line_id',
      'POST',
      expect.objectContaining({
        work_order_id: 101,
        line_id: 202,
        cam_ready: true,
        cam_ready_at: '2026-04-25T10:15:30.000Z',
        cam_ready_by: 'cam@example.com',
        updated_by: 'cam@example.com',
        created_by: 'cam@example.com',
      }),
    );
  });

  it('clears cam ready audit fields when unchecked', async () => {
    const { setCamReady } = await import('../../src/services/planProizvodnje.js');
    sbReqMock.mockResolvedValue([{ id: 1 }]);

    await setCamReady(101, 202, false);

    expect(sbReqMock).toHaveBeenCalledWith(
      'production_overlays?on_conflict=work_order_id,line_id',
      'POST',
      expect.objectContaining({
        cam_ready: false,
        cam_ready_at: null,
        cam_ready_by: null,
      }),
    );
  });
});
