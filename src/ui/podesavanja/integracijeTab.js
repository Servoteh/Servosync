/**
 * Podešavanja → Integracije (Supabase health + linkovi).
 */

import { escHtml } from '../../lib/dom.js';
import { hasSupabaseConfig, SUPABASE_CONFIG } from '../../lib/constants.js';
import { getAuth } from '../../state/auth.js';
import { buildPodesavanjaModulePath } from '../../lib/podesavanjaTabs.js';

export function renderIntegracijeTab() {
  const auth = getAuth();
  const url = SUPABASE_CONFIG.url || '—';
  const hasKey = !!SUPABASE_CONFIG.anonKey;

  return `
    <div class="set-page-header">
      <div class="set-page-header-icon">🔗</div>
      <div>
        <h2 class="set-page-header-title">Integracije</h2>
        <p class="set-page-header-sub">Spoljni sistemi i platforma</p>
      </div>
    </div>
    <div class="kpi-grid" style="margin-bottom:16px">
      <div class="kpi-card kpi-${auth.isOnline ? 'info' : 'warn'}">
        <div class="kpi-label">Supabase REST</div>
        <div class="kpi-value" style="font-size:14px">${auth.isOnline ? 'Online' : 'Offline'}</div>
        <div class="kpi-sub">JWT + PostgREST</div>
      </div>
      <div class="kpi-card kpi-${hasSupabaseConfig() ? 'info' : 'warn'}">
        <div class="kpi-label">Konfiguracija</div>
        <div class="kpi-value" style="font-size:14px">${hasSupabaseConfig() ? 'OK' : 'Nepotpuna'}</div>
        <div class="kpi-sub">${hasKey ? 'anon key' : 'bez anon key'}</div>
      </div>
      <div class="kpi-card kpi-neutral">
        <div class="kpi-label">Projekat URL</div>
        <div class="kpi-value" style="font-size:11px;font-family:var(--mono);word-break:break-all">${escHtml(url)}</div>
      </div>
    </div>
    <table class="kadrovska-table set-integ-table">
      <thead>
        <tr><th>Integracija</th><th>Status</th><th>Napomena</th></tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>BigTehn cache</strong></td>
          <td><span class="set-integ-ok">Aktivno</span></td>
          <td>Predmeti, RN, mašine — read-only sync u Supabase</td>
        </tr>
        <tr>
          <td><strong>Supabase Auth</strong></td>
          <td><span class="set-integ-ok">${auth.user ? 'Prijavljen' : '—'}</span></td>
          <td>Invite: Edge <code>admin-invite-user</code> + RPC <code>admin_invite_user_role</code></td>
        </tr>
        <tr>
          <td><strong>Resend / email dispatch</strong></td>
          <td><span class="set-integ-partial">Po modulu</span></td>
          <td>PB, Sastanci, HR, CMMS — Edge funkcije</td>
        </tr>
        <tr>
          <td><strong>WhatsApp (Meta)</strong></td>
          <td><span class="set-integ-partial">Opciono</span></td>
          <td>HR / Sastanci — env secrets na Edge</td>
        </tr>
        <tr>
          <td><strong>MES radni nalozi</strong></td>
          <td><span class="set-integ-info">Read</span></td>
          <td>Ne filtrira aktivne predmete u Podešavanjima</td>
        </tr>
      </tbody>
    </table>
    <p class="form-hint" style="margin-top:14px">
      Dijagnostika: tab <a href="${escHtml(buildPodesavanjaModulePath('system'))}">Sistem</a>.
      Notifikacije: <a href="${escHtml(buildPodesavanjaModulePath('notifikacije'))}">Notifikacije</a>.
    </p>
  `;
}

export function wireIntegracijeTab() {}
