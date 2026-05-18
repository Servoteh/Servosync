/** Deep link parametri za /projektni-biro */

const PB_TABS = new Set(['plan', 'kanban', 'gantt', 'izvestaji', 'analiza', 'podesavanja']);

/**
 * @param {string} [search] window.location.search
 * @returns {{ tab: string|null, predmet: string|null, inzenjer: string|null, q: string|null, rn: string|null }}
 */
export function parsePbModuleSearch(search) {
  const q = new URLSearchParams(search || '');
  const tab = q.get('tab');
  const predmet = q.get('predmet');
  const inzenjer = q.get('inzenjer') || q.get('engineer');
  const textQ = q.get('q') || q.get('search');
  const rn = q.get('rn') || q.get('zadatak');
  return {
    tab: tab && PB_TABS.has(tab) ? tab : null,
    predmet: predmet?.trim() || null,
    inzenjer: inzenjer?.trim() || null,
    q: textQ?.trim() || null,
    rn: rn?.trim() || null,
  };
}

/**
 * @param {{
 *   tab?: string,
 *   predmet?: string,
 *   inzenjer?: string,
 *   q?: string,
 *   rn?: string,
 * }} params
 */
export function buildPbModuleUrl(params = {}) {
  const q = new URLSearchParams();
  const tab = params.tab || 'plan';
  if (tab && tab !== 'plan') q.set('tab', tab);
  if (params.predmet && params.predmet !== 'all') q.set('predmet', params.predmet);
  if (params.inzenjer && params.inzenjer !== 'all') q.set('inzenjer', params.inzenjer);
  if (params.q?.trim()) q.set('q', params.q.trim());
  if (params.rn) q.set('rn', params.rn);
  const qs = q.toString();
  return `/projektni-biro${qs ? `?${qs}` : ''}`;
}

/**
 * @param {object} state PB state objekat (activeTab, activeProject, …)
 * @param {{ tab?: string|null, predmet?: string|null, inzenjer?: string|null, q?: string|null, rn?: string|null }} url
 */
export function applyPbUrlToState(state, url) {
  if (!state || !url) return;
  if (url.tab) state.activeTab = url.tab;
  if (url.predmet) state.activeProject = url.predmet;
  if (url.inzenjer) state.activeEngineer = url.inzenjer;
  if (url.q != null) state.moduleSearch = url.q;
}
