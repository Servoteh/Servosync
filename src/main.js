/**
 * Servoteh ERP — Vite entry point.
 *
 * Faza 0: scaffold + env verifikacija.
 * Faza 1: import CSS-a iz legacy fajla u src/styles/legacy.css. CSS će se
 *         progresivno razbijati po modulima u Fazama 4 i 5.
 * Faza 3: pravi auth + hub mount (placeholder za sad).
 *
 * Production aplikacija i dalje radi na `legacy/index.html` deploy-u dok
 * Faza 6 (cutover) ne završi.
 */

import './styles/legacy.css';

const root = document.getElementById('app');

if (!root) {
  throw new Error('Vite mount point #app nije pronađen u index.html');
}

const supaUrl = import.meta.env.VITE_SUPABASE_URL || '';
const supaKeyPresent = !!import.meta.env.VITE_SUPABASE_ANON_KEY;

/* Mali sanity demo: koristi prave CSS klase iz legacy-ja (.btn, .badge-status,
   .kpi-card itd.) da pokaže da se CSS učitava i da theme tokens rade. Ovaj
   blok ide napolje čim Faza 3 mount-uje pravi auth/hub. */
root.innerHTML = `
  <div style="min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;">
    <div class="auth-box" style="max-width:560px">
      <div class="auth-brand">
        <div class="auth-brand-mark">⚙</div>
        <div class="auth-title">Servoteh — Vite migracija</div>
        <div class="auth-subtitle">Faza 1 ✓ — CSS učitan iz <code>src/styles/legacy.css</code></div>
      </div>

      <div style="display:flex;flex-direction:column;gap:14px;margin-top:8px">

        <div style="display:flex;gap:8px;flex-wrap:wrap;justify-content:center">
          <span class="badge-status st-0">Nije počelo</span>
          <span class="badge-status st-1">U toku</span>
          <span class="badge-status st-2">Završeno</span>
          <span class="badge-status st-3">Pauza</span>
        </div>

        <div class="kpi-grid">
          <div class="kpi-card kpi-info">
            <div class="kpi-label">Faza 0 + 1</div>
            <div class="kpi-value">DONE</div>
            <div class="kpi-sub">scaffold + CSS</div>
          </div>
          <div class="kpi-card kpi-warn">
            <div class="kpi-label">Sledeće</div>
            <div class="kpi-value">F2</div>
            <div class="kpi-sub">services + state</div>
          </div>
          <div class="kpi-card kpi-neutral">
            <div class="kpi-label">Mod</div>
            <div class="kpi-value" style="font-size:14px">${import.meta.env.MODE}</div>
            <div class="kpi-sub">Vite dev/build</div>
          </div>
        </div>

        <div style="display:flex;gap:8px;justify-content:center;margin-top:8px">
          <button class="btn btn-primary" type="button" onclick="document.documentElement.setAttribute('data-theme', document.documentElement.getAttribute('data-theme')==='light'?'dark':'light')">
            🌓 Toggle theme
          </button>
        </div>

        <pre style="background:var(--surface3);padding:12px;border-radius:6px;border:1px solid var(--border2);font-family:var(--mono);font-size:11px;color:var(--text2);text-align:left;overflow:auto;margin-top:8px">VITE_SUPABASE_URL       = ${supaUrl ? supaUrl : 'missing'}
VITE_SUPABASE_ANON_KEY  = ${supaKeyPresent ? 'loaded (length=' + import.meta.env.VITE_SUPABASE_ANON_KEY.length + ')' : 'missing'}
MODE                    = ${import.meta.env.MODE}</pre>

        <div class="auth-footer">
          Production je i dalje na <strong>legacy/index.html</strong>. Korisnici neosećaju razliku do Faze 6.
        </div>
      </div>
    </div>
  </div>
`;

console.log('[main] Vite Faza 1 ready. CSS loaded from legacy.css. ENV check:', {
  VITE_SUPABASE_URL: supaUrl ? '✓' : 'missing',
  VITE_SUPABASE_ANON_KEY: supaKeyPresent ? '✓' : 'missing',
  MODE: import.meta.env.MODE,
});
