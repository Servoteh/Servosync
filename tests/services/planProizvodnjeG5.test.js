import { beforeEach, describe, expect, it, vi } from 'vitest';

const { sbReqMock, roleState } = vi.hoisted(() => ({
  sbReqMock: vi.fn(),
  roleState: { role: 'admin' },
}));

vi.mock('../../src/services/supabase.js', () => ({
  sbReq: sbReqMock,
  getSupabaseUrl: () => 'https://example.supabase.co',
  getSupabaseAnonKey: () => 'anon-key',
}));

vi.mock('../../src/state/auth.js', () => ({
  canEditPlanProizvodnje: () => true,
  getCurrentUser: () => ({ email: 'g5@example.com' }),
  getCurrentRole: () => roleState.role,
  isAdminOrMenadzment: () => roleState.role === 'admin' || roleState.role === 'menadzment',
  getIsOnline: () => true,
}));

vi.mock('../../src/services/drawings.js', () => ({
  BIGTEHN_DRAWINGS_BUCKET: 'bigtehn-drawings',
  getBigtehnDrawingSignedUrl: vi.fn(),
  parseSupabaseStorageSignResponse: vi.fn(),
  absolutizeSupabaseStorageSignedPath: vi.fn(),
}));

describe('G5 machine group helpers', () => {
  it('maps machine codes using the same business groups as departments.js', async () => {
    const { machineGroupSlugForCode, machineGroupLabel } = await import('../../src/services/planProizvodnje.js');

    expect(machineGroupSlugForCode('3.21')).toBe('glodanje');
    expect(machineGroupSlugForCode('2.10')).toBe('struganje');
    expect(machineGroupSlugForCode('21.1')).toBe('ostalo');
    expect(machineGroupSlugForCode('6.8')).toBe('ostalo');
    expect(machineGroupSlugForCode('10.4')).toBe('erodiranje');
    expect(machineGroupSlugForCode('5.11')).toBe('farbanje');
    expect(machineGroupLabel('brusenje')).toBe('Brušenje');
  });
});

describe('G5 reassign RPC writers', () => {
  beforeEach(() => {
    sbReqMock.mockReset();
    roleState.role = 'admin';
  });

  it('calls single reassign RPC with force metadata', async () => {
    const { reassignLine } = await import('../../src/services/planProizvodnje.js');
    sbReqMock.mockResolvedValue({ forced: true });

    await reassignLine({
      workOrderId: 101,
      lineId: 202,
      targetMachine: '4.1',
      force: true,
      reason: 'Mašina nije dostupna',
    });

    expect(sbReqMock).toHaveBeenCalledWith(
      'rpc/reassign_production_line',
      'POST',
      {
        p_work_order_id: 101,
        p_line_id: 202,
        p_target_machine: '4.1',
        p_force: true,
        p_force_reason: 'Mašina nije dostupna',
      },
      { upsert: false },
    );
  });

  it('calls bulk reassign RPC with normalized pairs', async () => {
    const { bulkReassignLines } = await import('../../src/services/planProizvodnje.js');
    sbReqMock.mockResolvedValue({ updated_count: 2 });

    await bulkReassignLines({
      pairs: [
        { work_order_id: 101, line_id: 202 },
        { wo: 303, line: 404 },
      ],
      targetMachine: '3.21',
    });

    expect(sbReqMock).toHaveBeenCalledWith(
      'rpc/bulk_reassign_production_lines',
      'POST',
      {
        p_pairs: [
          { wo: 101, line: 202 },
          { wo: 303, line: 404 },
        ],
        p_target_machine: '3.21',
        p_force: false,
        p_force_reason: null,
      },
      { upsert: false },
    );
  });
});

describe('G5 force UI role helper', () => {
  it('allows force UI for admin and menadzment only', async () => {
    const { canShowForceReassign } = await import('../../src/ui/planProizvodnje/poMasiniTab.js');

    expect(canShowForceReassign('admin')).toBe(true);
    expect(canShowForceReassign('menadzment')).toBe(true);
    expect(canShowForceReassign('pm')).toBe(false);
    expect(canShowForceReassign('viewer')).toBe(false);
  });
});
