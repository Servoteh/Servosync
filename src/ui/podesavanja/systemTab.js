/**
 * Podešavanja → Sistem (dijagnostika + linkovi).
 */

import { escHtml } from '../../lib/dom.js';
import { hasSupabaseConfig, SUPABASE_CONFIG } from '../../lib/constants.js';
import { getAuth } from '../../state/auth.js';
import { buildPodesavanjaModulePath } from '../../lib/podesavanjaTabs.js';

export function renderSystemTab() {
  const auth = getAuth();
  const url = SUPABASE_CONFIG.url || '—';
  const hasKey = !!SUPABASE_CONFIG.anonKey;
  return `
    <div class="set-page-header">
      <div class="set-page-header-icon">⚙</div>
      <div>
        <h2 class="set-page-header-title">Sistem</h2>
        <p class="set-page-header-sub">Dijagnostika i platforma</p>
      </div>
    </div>
    <main class="kadrovska-main" style="display:flex;flex-direction:column;gap:14px;max-width:720px;padding:0">
      <div class="kpi-grid">
        <div class="kpi-card kpi-${auth.isOnline ? 'info' : 'warn'}">
          <div class="kpi-label">Konekcija</div>
          <div class="kpi-value" style="font-size:14px">${auth.isOnline ? 'Online' : 'Offline'}</div>
          <div class="kpi-sub">${auth.isOnline ? 'Supabase REST dostupan' : 'localStorage fallback'}</div>
        </div>
        <div class="kpi-card kpi-${hasSupabaseConfig() ? 'info' : 'warn'}">
          <div class="kpi-label">Supabase config</div>
          <div class="kpi-value" style="font-size:14px">${hasSupabaseConfig() ? 'OK' : 'Nepotpun'}</div>
          <div class="kpi-sub">${hasKey ? 'anon key prisutan' : 'nema anon key-a'}</div>
        </div>
        <div class="kpi-card kpi-neutral">
          <div class="kpi-label">URL</div>
          <div class="kpi-value" style="font-size:11px;font-family:var(--mono);word-break:break-all">${escHtml(url)}</div>
          <div class="kpi-sub">env: VITE_SUPABASE_URL</div>
        </div>
      </div>
      <p class="form-hint">
        <a href="${escHtml(buildPodesavanjaModulePath('integracije'))}">Integracije</a> ·
        <a href="${escHtml(buildPodesavanjaModulePath('audit-log'))}">Audit log</a> ·
        Rezervna kopija i sync monitor — planirano u narednoj fazi.
      </p>
    </main>
  `;
}

export function wireSystemTab() {}
