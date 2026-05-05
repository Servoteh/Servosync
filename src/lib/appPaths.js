/**
 * URL rute aplikacije (History API). Cloudflare Pages već šalje sve nepoznate
 * putanje na /index.html (public/_redirects).
 *
 * Mašina u deep linku: segment path-a je `encodeURIComponent(rj_code)` npr. 8.3.
 */

/** @param {string} pathname */
function normalizePathname(pathname) {
  const raw = pathname && pathname !== '' ? pathname : '/';
  if (raw.length > 1 && raw.endsWith('/')) return raw.slice(0, -1);
  return raw;
}

/**
 * @param {string} pathname
 * @returns {{
 *   kind: 'session'
 *   | 'hub'
 *   | 'module'
 *   | 'maintenance'
 *   | 'mobile'
 *   | 'reset-password'
 *   | 'unknown',
 *   moduleId?: string,
 *   section?: 'dashboard' | 'machines' | 'machine' | 'board' | 'notifications' | 'catalog' | 'locations' | 'workorders' | 'assets' | 'assetsMachines' | 'assetsVehicles' | 'assetsIt' | 'assetsFacilities' | 'preventive' | 'calendar' | 'inventory' | 'documents' | 'reports' | 'settings',
 *   redirectTo?: string,
 *   machineCode?: string,
 *   mobileScreen?: 'home' | 'scan' | 'manual' | 'history' | 'batch' | 'lookup'
 * }}
 */
export function pathnameToRoute(pathname) {
  const p = normalizePathname(pathname);
  if (p === '/') {
    return { kind: 'session' };
  }
  if (p === '/hub') {
    return { kind: 'hub' };
  }
  /* Reset password — javna stranica (bez login guard-a). Supabase u mail-u
   * šalje redirect_to sa `/reset-password#access_token=...&type=recovery`
   * (implicit flow) ili `?code=...` (PKCE flow). */
  if (p === '/reset-password') {
    return { kind: 'reset-password' };
  }
  /* Mobilni shell za magacionere / viljuškariste (Faza 1 — PWA + Capacitor wrapper).
   * Namerno plitak tree: `/m` (home), i pod-rute (scan, manual, history, batch, lookup).
   * Sve nepoznate `/m/*` vode na home. */
  if (p === '/m') {
    return { kind: 'mobile', mobileScreen: 'home' };
  }
  if (p === '/m/scan') {
    return { kind: 'mobile', mobileScreen: 'scan' };
  }
  if (p === '/m/manual') {
    return { kind: 'mobile', mobileScreen: 'manual' };
  }
  if (p === '/m/history') {
    return { kind: 'mobile', mobileScreen: 'history' };
  }
  if (p === '/m/batch') {
    return { kind: 'mobile', mobileScreen: 'batch' };
  }
  if (p === '/m/lookup') {
    return { kind: 'mobile', mobileScreen: 'lookup' };
  }
  if (p === '/plan-montaze') {
    return { kind: 'module', moduleId: 'plan-montaze' };
  }
  if (p === '/lokacije-delova') {
    return { kind: 'module', moduleId: 'lokacije-delova' };
  }
  if (p === '/reversi') {
    return { kind: 'module', moduleId: 'reversi' };
  }
  if (p === '/plan-proizvodnje') {
    return { kind: 'module', moduleId: 'plan-proizvodnje' };
  }
  if (p === '/pracenje-proizvodnje') {
    return { kind: 'module', moduleId: 'pracenje-proizvodnje' };
  }
  if (p === '/kadrovska') {
    return { kind: 'module', moduleId: 'kadrovska' };
  }
  if (p === '/projektni-biro') {
    return { kind: 'module', moduleId: 'projektni-biro' };
  }
  if (p === '/sastanci') {
    return { kind: 'module', moduleId: 'sastanci' };
  }
  if (p === '/sastanci/podesavanja-notifikacija') {
    return { kind: 'module', moduleId: 'sastanci', sastanciTab: 'podesavanja-notif' };
  }
  const sd = /^\/sastanci\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/.exec(p);
  if (sd) {
    return { kind: 'module', moduleId: 'sastanci', sastanakId: sd[1] };
  }
  if (p === '/moj-profil') {
    return { kind: 'self-service' };
  }
  if (p === '/podesavanja') {
    return { kind: 'module', moduleId: 'podesavanja' };
  }
  if (p === '/maintenance') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'dashboard' };
  }
  if (p === '/maintenance/rokovi') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'preventive', redirectTo: '/maintenance/preventive' };
  }
  if (p === '/maintenance/katalog') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'assetsMachines', redirectTo: '/maintenance/assets/machines?view=admin' };
  }
  if (p === '/maintenance/machines') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'machines' };
  }
  if (p === '/maintenance/board') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'board' };
  }
  if (p === '/maintenance/notifications') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'notifications' };
  }
  if (p === '/maintenance/catalog') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'catalog' };
  }
  if (p === '/maintenance/locations') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'locations' };
  }
  if (p === '/maintenance/work-orders') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'workorders' };
  }
  if (p === '/maintenance/assets') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'assets' };
  }
  if (p === '/maintenance/assets/machines') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'assetsMachines' };
  }
  if (p === '/maintenance/assets/vehicles') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'assetsVehicles' };
  }
  if (p === '/maintenance/assets/it') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'assetsIt' };
  }
  if (p === '/maintenance/assets/facilities') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'assetsFacilities' };
  }
  if (p === '/maintenance/preventive') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'preventive' };
  }
  if (p === '/maintenance/calendar') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'calendar' };
  }
  if (p === '/maintenance/inventory') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'inventory' };
  }
  if (p === '/maintenance/documents') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'documents' };
  }
  if (p === '/maintenance/reports') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'reports' };
  }
  if (p === '/maintenance/settings') {
    return { kind: 'maintenance', moduleId: 'odrzavanje-masina', section: 'settings' };
  }
  const mm = /^\/maintenance\/machines\/([^/]+)$/.exec(p);
  if (mm) {
    let machineCode = mm[1];
    try {
      machineCode = decodeURIComponent(machineCode);
    } catch {
      /* ostavi raw segment */
    }
    return {
      kind: 'maintenance',
      moduleId: 'odrzavanje-masina',
      section: 'machine',
      machineCode,
    };
  }
  return { kind: 'unknown' };
}

/** @param {string} [search] */
export function parseSearchParams(search) {
  const q = new URLSearchParams(search || '');
  const tab = q.get('tab');
  return { tab: tab && tab.trim() ? tab.trim() : null };
}

/** @param {string} moduleId */
export function pathForModule(moduleId) {
  const map = {
    'plan-montaze': '/plan-montaze',
    'lokacije-delova': '/lokacije-delova',
    reversi: '/reversi',
    'plan-proizvodnje': '/plan-proizvodnje',
    'pracenje-proizvodnje': '/pracenje-proizvodnje',
    kadrovska: '/kadrovska',
    'projektni-biro': '/projektni-biro',
    sastanci: '/sastanci',
    podesavanja: '/podesavanja',
    'odrzavanje-masina': '/maintenance',
    'moj-profil': '/moj-profil',
  };
  return map[moduleId] || '/';
}

/**
 * Deep link na detalj mašine (isto kao u spec-u Telegram poruke).
 * @param {string} machineCode npr. rj_code iz BigTehn cache-a
 * @param {string | null} [tab] npr. 'checks'
 */
export function buildMaintenanceMachinePath(machineCode, tab = null) {
  const enc = encodeURIComponent(machineCode);
  const base = `/maintenance/machines/${enc}`;
  if (tab) return `${base}?tab=${encodeURIComponent(tab)}`;
  return base;
}

/**
 * Deep link na detalj sastanka.
 * @param {string} sastanakId UUID
 * @param {string | null} [tab] npr. 'zapisnik'
 */
export function buildSastanakDetaljPath(sastanakId, tab = null) {
  const base = `/sastanci/${sastanakId}`;
  if (tab) return `${base}?tab=${encodeURIComponent(tab)}`;
  return base;
}
