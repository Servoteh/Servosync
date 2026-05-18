import { beforeEach, describe, expect, it, vi } from 'vitest';

const { sbReqMock } = vi.hoisted(() => ({ sbReqMock: vi.fn() }));

vi.mock('../../src/services/supabase.js', () => ({ sbReq: sbReqMock }));
vi.mock('../../src/state/auth.js', () => ({ getIsOnline: () => true }));

describe('sastanciOdluke service', () => {
  beforeEach(() => sbReqMock.mockReset());

  it('loadOdlukeBySastanak maps rows', async () => {
    sbReqMock.mockResolvedValueOnce([{
      id: 'o1',
      sastanak_id: 's1',
      rb: 1,
      naslov: 'Odluka 1',
      status: 'na_snazi',
    }]);
    const { loadOdlukeBySastanak } = await import('../../src/services/sastanciOdluke.js');
    const rows = await loadOdlukeBySastanak('s1');
    expect(rows[0].naslov).toBe('Odluka 1');
    expect(sbReqMock).toHaveBeenCalledWith(expect.stringContaining('sastanak_odluke'));
  });
});
