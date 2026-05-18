import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const { sbReqMock } = vi.hoisted(() => ({ sbReqMock: vi.fn() }));

vi.mock('../../src/services/supabase.js', () => ({
  sbReq: sbReqMock,
}));

vi.mock('../../src/state/auth.js', () => ({
  getCurrentUser: () => ({ email: 'pm@test.local' }),
  getIsOnline: () => true,
}));

describe('sastanci service smoke', () => {
  beforeEach(() => {
    sbReqMock.mockReset();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('loadSastanci maps rows and passes filters', async () => {
    sbReqMock.mockResolvedValueOnce([{
      id: 's1',
      tip: 'sedmicni',
      naslov: 'Test',
      datum: '2026-05-19',
      status: 'planiran',
    }]);

    const { loadSastanci } = await import('../../src/services/sastanci.js');
    const rows = await loadSastanci({ tip: 'sedmicni', status: 'planiran', limit: 10 });

    expect(sbReqMock).toHaveBeenCalledWith(expect.stringContaining('sastanci?'));
    expect(sbReqMock).toHaveBeenCalledWith(expect.stringContaining('tip=eq.sedmicni'));
    expect(rows).toHaveLength(1);
    expect(rows[0].naslov).toBe('Test');
  });

  it('createSastanak via saveSastanak posts payload', async () => {
    sbReqMock.mockResolvedValueOnce([{
      id: 'new-id',
      tip: 'dnevni',
      naslov: 'Novi',
      datum: '2026-05-20',
      status: 'planiran',
    }]);

    const { saveSastanak } = await import('../../src/services/sastanci.js');
    const created = await saveSastanak({
      tip: 'dnevni',
      naslov: 'Novi',
      datum: '2026-05-20',
    });

    expect(sbReqMock).toHaveBeenCalledWith('sastanci', 'POST', expect.objectContaining({
      naslov: 'Novi',
      tip: 'dnevni',
    }));
    expect(created?.id).toBe('new-id');
  });

  it('loadUcesnici maps ucesnike za sastanak', async () => {
    sbReqMock.mockResolvedValueOnce([{
      sastanak_id: 's1',
      email: 'a@test.local',
      label: 'A User',
      prisutan: true,
      pozvan: true,
    }]);

    const { loadUcesnici } = await import('../../src/services/sastanci.js');
    const rows = await loadUcesnici('s1');

    expect(sbReqMock).toHaveBeenCalledWith(expect.stringContaining('sastanak_ucesnici'));
    expect(rows[0].email).toBe('a@test.local');
    expect(rows[0].label).toBe('A User');
  });
});
