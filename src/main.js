/**
 * Servoteh ERP — Vite entry point.
 *
 * Faza 0: scaffold + env verifikacija.
 * Faza 1: import CSS-a iz legacy fajla u src/styles/legacy.css.
 * Faza 2: lib/services/state moduli postoje. Ovaj entry pokazuje sanity panel
 *         koji u browser-u potvrđuje da:
 *           - constants/storage/dom/date helperi rade,
 *           - sbReq() radi sa env-om,
 *           - restoreSession() može da povrati staru legacy sesiju (isti
 *             localStorage ključ AUTH = 'plan_montaze_v51_auth'),
 *           - loadAndApplyUserRole() ispravno odredi rolu,
 *           - loadEmployeesFromDb() vraća listu (ako je korisnik HR/admin).
 * Faza 3: pravi auth + hub + theme mount (sledeća iteracija).
 *
 * Production aplikacija i dalje radi na `legacy/index.html` deploy-u dok
 * Faza 6 (cutover) ne završi.
 */

import './styles/legacy.css';

import { hasSupabaseConfig, SUPABASE_CONFIG } from './lib/constants.js';
import { escHtml, showToast } from './lib/dom.js';
import { today, formatDate, dayDiffFromToday } from './lib/date.js';
import { restoreSession, logout } from './services/auth.js';
import { loadAndApplyUserRole } from './services/userRoles.js';
import { loadEmployeesFromDb } from './services/employees.js';
import { loadProjectsFromDb } from './services/projects.js';
import {
  getAuth,
  onAuthChange,
  canAccessKadrovska,
  canEdit,
} from './state/auth.js';

const root = document.getElementById('app');
if (!root) {
  throw new Error('Vite mount point #app nije pronađen u index.html');
}

/* Theme inicijalizacija — koristi isti ključ kao legacy. */
try {
  const savedTheme = localStorage.getItem('pm_theme_v1');
  if (savedTheme === 'light' || savedTheme === 'dark') {
    document.documentElement.setAttribute('data-theme', savedTheme);
  }
} catch (e) { /* noop */ }

function row(label, value, tone = 'info') {
  const cls = tone === 'ok' ? 'kpi-info'
    : tone === 'warn' ? 'kpi-warn'
    : tone === 'err' ? 'kpi-warn'
    : 'kpi-neutral';
  return `
    <div class="kpi-card ${cls}">
      <div class="kpi-label">${escHtml(label)}</div>
      <div class="kpi-value" style="font-size:14px">${escHtml(String(value))}</div>
    </div>`;
}

function render(opts) {
  const auth = getAuth();
  const supaInfo = hasSupabaseConfig()
    ? `${SUPABASE_CONFIG.url.replace(/^https?:\/\//, '').slice(0, 40)}…`
    : 'missing';

  root.innerHTML = `
    <div style="min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;">
      <div class="auth-box" style="max-width:760px;width:100%">
        <div class="auth-brand">
          <div class="auth-brand-mark">⚙</div>
          <div class="auth-title">Servoteh — Vite migracija</div>
          <div class="auth-subtitle">Faza 2 ✓ — lib / services / state moduli</div>
        </div>

        <div style="display:flex;flex-direction:column;gap:14px;margin-top:8px">

          <div class="kpi-grid">
            ${row('MODE', import.meta.env.MODE, 'ok')}
            ${row('Supabase', supaInfo, hasSupabaseConfig() ? 'ok' : 'err')}
            ${row('Online', auth.isOnline ? 'YES' : 'NO', auth.isOnline ? 'ok' : 'warn')}
            ${row('User', auth.user?.email || '—', auth.user ? 'ok' : 'warn')}
            ${row('Role', auth.role, auth.user ? 'ok' : 'warn')}
            ${row('canEdit', canEdit() ? 'true' : 'false')}
            ${row('canAccessKadrovska', canAccessKadrovska() ? 'true' : 'false')}
            ${row('Today', formatDate(today))}
          </div>

          <pre style="background:var(--surface3);padding:12px;border-radius:6px;border:1px solid var(--border2);font-family:var(--mono);font-size:11px;color:var(--text2);text-align:left;overflow:auto;max-height:240px;margin:0">${escHtml(opts.log.join('\n'))}</pre>

          <div style="display:flex;gap:8px;justify-content:center;flex-wrap:wrap">
            <button class="btn btn-primary" type="button" data-action="reload-roles">🔄 Reload roles</button>
            <button class="btn btn-secondary" type="button" data-action="probe-projects">📦 Probe projects</button>
            <button class="btn btn-secondary" type="button" data-action="probe-employees">👥 Probe employees</button>
            <button class="btn" type="button" data-action="toggle-theme">🌓 Toggle theme</button>
            ${auth.user
              ? `<button class="btn" type="button" data-action="logout">🚪 Logout</button>`
              : `<span class="auth-footer" style="margin:0">Nije ulogovan — login UI dolazi u Fazi 3</span>`
            }
          </div>

          <div class="auth-footer">
            Production je i dalje na <strong>legacy/index.html</strong> (main grana). Vite radi na
            <strong>feature/vite-migration</strong> i niko nije pogođen do cutover-a (Faza 6).
          </div>
        </div>
      </div>
    </div>
  `;

  /* Wire dugmad bez inline onclick-ova (postavljamo standard od Faze 2). */
  root.querySelectorAll('button[data-action]').forEach(btn => {
    btn.addEventListener('click', () => handleAction(btn.dataset.action));
  });
}

const log = [];
function pushLog(line) {
  const ts = new Date().toLocaleTimeString();
  log.push(`[${ts}] ${line}`);
  if (log.length > 80) log.shift();
}

async function handleAction(action) {
  try {
    if (action === 'reload-roles') {
      pushLog('reload-roles…');
      const { role, matches } = await loadAndApplyUserRole();
      pushLog(`role=${role}  matches=${matches.length}`);
    } else if (action === 'probe-projects') {
      pushLog('probe projects…');
      const list = await loadProjectsFromDb();
      pushLog(list ? `projects=${list.length}` : 'projects: null (offline ili greška)');
    } else if (action === 'probe-employees') {
      pushLog('probe employees…');
      const list = await loadEmployeesFromDb();
      pushLog(list ? `employees=${list.length}` : 'employees: null (offline ili nema HR rolu)');
    } else if (action === 'toggle-theme') {
      const cur = document.documentElement.getAttribute('data-theme') || 'dark';
      const next = cur === 'light' ? 'dark' : 'light';
      document.documentElement.setAttribute('data-theme', next);
      try { localStorage.setItem('pm_theme_v1', next); } catch (e) { /* noop */ }
    } else if (action === 'logout') {
      pushLog('logout…');
      await logout();
      pushLog('logged out');
    }
  } catch (e) {
    pushLog('ERR ' + (e?.message || String(e)));
    console.error(e);
    showToast('⚠ ' + (e?.message || 'Greška'));
  }
  render({ log });
}

/* Re-render kad god se auth promeni (login, logout, role update). */
onAuthChange(() => render({ log }));

/* Inicijalna sekvenca:
     1) ispiši env status
     2) probaj restoreSession iz localStorage (legacy ključ — kompatibilno!)
     3) ako je sesija OK, učitaj rolu pa probaj projects/employees
     4) render */
async function bootstrap() {
  pushLog(`Vite mode=${import.meta.env.MODE}, supabase=${hasSupabaseConfig() ? 'configured' : 'MISSING'}`);
  pushLog(`Today (lokalno) = ${formatDate(today)}, dayDiff(today)=${dayDiffFromToday(formatDate(today).split('.').reverse().map((v, i) => i === 0 ? v : v).join('-'))}`);
  /* prvi render — još bez sesije */
  render({ log });

  if (!hasSupabaseConfig()) {
    pushLog('⚠ Nema Supabase env vars — preskačem restoreSession');
    render({ log });
    return;
  }

  pushLog('restoreSession()…');
  const restored = await restoreSession();
  pushLog('restoreSession → ' + (restored ? 'OK' : 'no session'));

  if (restored) {
    pushLog('loadAndApplyUserRole()…');
    const { role, matches } = await loadAndApplyUserRole();
    pushLog(`role=${role}  matches=${matches.length}`);
  }

  render({ log });
}

bootstrap();
