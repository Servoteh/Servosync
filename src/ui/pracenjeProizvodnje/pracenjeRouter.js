/**
 * URL stanje za Praćenje proizvodnje: ?rn= | ?predmet= | lista (bez query).
 */

export function getPracenjeUrlState() {
  if (typeof window === 'undefined') {
    return { rn: null, predmet: null };
  }
  const p = new URLSearchParams(window.location.search);
  const rn = p.get('rn');
  const pred = p.get('predmet');
  const predNum = pred != null && /^\d+$/.test(String(pred).trim()) ? Number(pred) : null;
  return {
    rn: rn && String(rn).trim() ? String(rn).trim() : null,
    predmet: predNum != null && Number.isFinite(predNum) ? predNum : null,
  };
}
