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

  it('loadDashboardStats maps RPC json', async () => {
    sbReqMock.mockResolvedValueOnce({
      sastanc_upcoming: 2,
      sastanc_u_toku: 1,
      akcije_otvoreno: 5,
      akcije_kasni: 1,
      pm_teme_na_cekanju: 3,
    });

    const { loadDashboardStats } = await import('../../src/services/sastanci.js');
    const stats = await loadDashboardStats();

    expect(sbReqMock).toHaveBeenCalledWith('rpc/sast_dashboard_stats', 'POST', {});
    expect(stats).toEqual({
      sastancUpcoming: 2,
      sastancUToku: 1,
      akcijeOtvoreno: 5,
      akcijeKasni: 1,
      pmTemeNaCekanju: 3,
    });
  });

  it('loadSastanciForUcesnik filters by ucesnik ids', async () => {
    sbReqMock
      .mockResolvedValueOnce([{ sastanak_id: 's1' }])
      .mockResolvedValueOnce([{
        id: 's1',
        tip: 'sedmicni',
        naslov: 'Moj',
        datum: '2026-05-20',
        status: 'planiran',
      }]);

    const { loadSastanciForUcesnik } = await import('../../src/services/sastanci.js');
    const rows = await loadSastanciForUcesnik('user@test.local');

    expect(sbReqMock).toHaveBeenCalledWith(expect.stringContaining('sastanak_ucesnici'));
    expect(sbReqMock).toHaveBeenCalledWith(expect.stringContaining('id=in.(s1)'));
    expect(rows).toHaveLength(1);
    expect(rows[0].naslov).toBe('Moj');
  });

  it('subscribeSastanakDetalj returns unsubscribe and polls', async () => {
    vi.useFakeTimers();
    sbReqMock
      .mockResolvedValueOnce([{ id: 's1', status: 'u_toku', updated_at: '2026-05-20T10:00:00Z' }])
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([{ id: 's1', status: 'u_toku', updated_at: '2026-05-20T10:05:00Z' }])
      .mockResolvedValueOnce([{ id: 'a1', updated_at: '2026-05-20T10:05:00Z' }]);

    const { subscribeSastanakDetalj } = await import('../../src/services/sastanciDetalj.js');
    const onChange = vi.fn();
    const unsub = subscribeSastanakDetalj('s1', onChange, { intervalMs: 1000 });

    await vi.advanceTimersByTimeAsync(2500);
    await vi.advanceTimersByTimeAsync(1000);
    expect(onChange).toHaveBeenCalled();
    unsub();
    vi.useRealTimers();
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
