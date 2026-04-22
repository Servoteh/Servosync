/**
 * Reset password ekran — cilj stranice je da korisnik koji je kliknuo na
 * "zaboravljena lozinka" link iz Supabase email-a može da postavi novu
 * lozinku i automatski se prijavi.
 *
 * Supabase može vratiti korisnika u 2 formata zavisno od projektnog auth
 * flow-a (Dashboard → Authentication → Providers → Email):
 *
 *   1) Implicit flow (default za starije projekte):
 *      https://app.example.com/reset-password#access_token=ey...&refresh_token=...&type=recovery&expires_in=3600
 *      → access_token je u URL hash-u (fragmentu).
 *
 *   2) PKCE flow (noviji):
 *      https://app.example.com/reset-password?code=abcd-1234-...
 *      → code je u query string-u, razmenjuje se za session preko
 *      /auth/v1/token?grant_type=pkce.
 *
 * Takođe rukujemo slučaj kada u hash-u imamo `error` / `error_description`
 * (npr. link je istekao, već je korišten) — tada ne pokazujemo formu nego
 * poruku sa CTA "Pošalji novi link".
 *
 * Nakon uspešne izmene, token iz recovery flow-a je u stvari validna sesija
 * (Supabase ga označi kao `aal1`), pa radnika direktno ubacimo u hub bez
 * ponovnog unosa email/password.
 */

import { escHtml } from '../../lib/dom.js';
import { hasSupabaseConfig } from '../../lib/constants.js';
import {
  updatePassword,
  exchangeCodeForSession,
  requestPasswordReset,
} from '../../services/auth.js';
import { setUser, setOnline, persistSession } from '../../state/auth.js';

/**
 * Pokušaj da izvučeš tokene iz URL hash-a (implicit flow) ili query-a (PKCE).
 *
 * @returns {{
 *   accessToken: string | null,
 *   refreshToken: string | null,
 *   code: string | null,
 *   type: string | null,
 *   error: string | null,
 *   errorDescription: string | null,
 * }}
 */
export function parseRecoveryUrl() {
  const rawHash = window.location.hash || '';
  const hash = rawHash.startsWith('#') ? rawHash.slice(1) : rawHash;
  const hashParams = new URLSearchParams(hash);
  const queryParams = new URLSearchParams(window.location.search || '');

  /* Supabase vraća `error` ili `error_description` kad link ne radi
   * (npr. "Email link is invalid or has expired"). Po konvenciji su u
   * hash-u, ali backup i query ako je flow custom. */
  const error =
    hashParams.get('error') ||
    queryParams.get('error') ||
    null;
  const errorDescription =
    hashParams.get('error_description') ||
    queryParams.get('error_description') ||
    null;

  return {
    accessToken: hashParams.get('access_token') || null,
    refreshToken: hashParams.get('refresh_token') || null,
    code: queryParams.get('code') || null,
    type: hashParams.get('type') || queryParams.get('type') || null,
    error,
    errorDescription,
  };
}

/**
 * Očisti URL od recovery tokena posle uspešne obrade — da korisnik slučajno
 * ne otvori DevTools i vidi access_token, i da reload ne baci ga ponovo na
 * istu stranicu (token je jednokratan).
 */
function cleanRecoveryUrl() {
  try {
    const url = new URL(window.location.href);
    url.hash = '';
    url.searchParams.delete('code');
    url.searchParams.delete('type');
    url.searchParams.delete('error');
    url.searchParams.delete('error_description');
    window.history.replaceState({}, '', url.toString());
  } catch (e) {
    /* no-op */
  }
}

/**
 * @param {{
 *   onSuccess: (result: { session?: object }) => void,
 *   onCancel: () => void,
 * }} opts
 */
export function renderResetPasswordScreen({ onSuccess, onCancel }) {
  const parsed = parseRecoveryUrl();

  const overlay = document.createElement('div');
  overlay.className = 'auth-overlay';
  overlay.id = 'resetPasswordOverlay';

  /* Grane rendera zavisno od stanja tokena:
   *   - invalidLink: nema access_token ni code, ali ima type=recovery (ili
   *                  error) → link je obrađen/istekao.
   *   - implicitToken: imamo access_token u hash-u → pokaži formu odmah.
   *   - pkceCode: imamo code u query-ju → exchange, pa forma.
   *   - noToken: nema ničega → korisnik je direktno seo na /reset-password.
   *              Pokaži formu sa "Unesi email da dobiješ link". */
  const hasToken = !!parsed.accessToken;
  const hasCode = !!parsed.code;
  const hasErrorFromSupabase = !!(parsed.error || parsed.errorDescription);
  const isRecoveryType = parsed.type === 'recovery';

  overlay.innerHTML = shellHtml();

  const msg = overlay.querySelector('#resetMsg');
  const brandSub = overlay.querySelector('#resetSubtitle');

  /* Helper za lepo prikazivanje poruke. */
  function setMsg(kind, text) {
    if (!text) {
      msg.innerHTML = '';
      return;
    }
    if (kind === 'err') {
      msg.innerHTML = `<span class="auth-err">${escHtml(text)}</span>`;
    } else {
      msg.textContent = text;
    }
  }

  /* ── Konfiguracija dugmadi ── */
  const backBtn = overlay.querySelector('#resetBackBtn');
  backBtn.addEventListener('click', () => {
    cleanRecoveryUrl();
    onCancel?.();
  });

  if (!hasSupabaseConfig()) {
    brandSub.textContent = 'Supabase konfiguracija nije postavljena.';
    setMsg('err', 'Proveri .env (VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY).');
    return overlay;
  }

  if (hasErrorFromSupabase) {
    renderLinkInvalid(overlay, {
      description: parsed.errorDescription || parsed.error || 'Link nije validan.',
      onCancel,
    });
    return overlay;
  }

  if (hasToken) {
    /* Implicit flow — access_token je odmah u hash-u. */
    renderNewPasswordForm(overlay, {
      accessToken: parsed.accessToken,
      refreshToken: parsed.refreshToken,
      onSuccess,
      onCancel,
    });
    return overlay;
  }

  if (hasCode) {
    /* PKCE flow — zameni code za session. */
    brandSub.textContent = 'Razmenjujem link za sesiju…';
    (async () => {
      const res = await exchangeCodeForSession(parsed.code);
      if (!res.ok) {
        renderLinkInvalid(overlay, {
          description: res.error || 'Nisam mogao da razmenim link za sesiju.',
          onCancel,
        });
        return;
      }
      renderNewPasswordForm(overlay, {
        accessToken: res.session.access_token,
        refreshToken: res.session.refresh_token,
        onSuccess,
        onCancel,
      });
    })();
    return overlay;
  }

  /* Nema ni token-a ni code-a: korisnik je direktno otvorio /reset-password
   * (npr. zaobilaznim putem, ili je link već iskorišten i očišćen URL).
   * Ako je to recovery type ali nema token-a — link je možda dvaput otvoren. */
  if (isRecoveryType) {
    renderLinkInvalid(overlay, {
      description: 'Link za reset lozinke je istekao ili je već iskorišćen.',
      onCancel,
    });
    return overlay;
  }

  /* Fallback: direktan pristup — ponudi da pošalje novi link. */
  renderRequestLinkForm(overlay, { onCancel });
  return overlay;
}

/* ── HTML skeleti ────────────────────────────────────────────────────────── */

function shellHtml() {
  return `
    <div class="auth-box" role="dialog" aria-labelledby="resetTitle" aria-describedby="resetSubtitle">
      <div class="auth-brand">
        <div class="auth-brand-mark" aria-hidden="true">
          <svg viewBox="0 0 24 24" role="img" aria-label="Servoteh">
            <path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.5 2.5-2.8-.7-.7-2.8 2.5-2.5z"></path>
          </svg>
        </div>
        <div class="auth-title" id="resetTitle">Reset lozinke</div>
        <div class="auth-subtitle" id="resetSubtitle">Postavi novu lozinku za svoj nalog</div>
      </div>

      <div id="resetContent"></div>

      <div class="auth-msg" id="resetMsg" role="status" aria-live="polite"></div>

      <div class="auth-reset-back">
        <button type="button" class="auth-btn-ghost" id="resetBackBtn">← Nazad na prijavu</button>
      </div>

      <div class="auth-footer"><strong>SERVOTEH</strong> · Plan Montaže</div>
    </div>
  `;
}

/**
 * Forma za novu lozinku (unos + potvrda) — koristi se i za implicit flow i za
 * PKCE flow posle razmene code-a.
 *
 * @param {HTMLElement} overlay
 * @param {{
 *   accessToken: string,
 *   refreshToken: string | null,
 *   onSuccess: (r: { session: { access_token: string, refresh_token: string | null, user: object } }) => void,
 *   onCancel: () => void,
 * }} opts
 */
function renderNewPasswordForm(overlay, { accessToken, refreshToken, onSuccess }) {
  const content = overlay.querySelector('#resetContent');
  content.innerHTML = `
    <form class="auth-form" id="resetForm">
      <div class="auth-field">
        <label for="resetPw1">Nova lozinka</label>
        <input type="password" id="resetPw1" placeholder="min. 6 karaktera"
               autocomplete="new-password" required minlength="6">
      </div>
      <div class="auth-field">
        <label for="resetPw2">Potvrdi lozinku</label>
        <input type="password" id="resetPw2" placeholder="unesi ponovo"
               autocomplete="new-password" required minlength="6">
      </div>
      <button type="submit" class="auth-btn-primary" id="resetSubmitBtn">
        Sačuvaj novu lozinku
        <span class="arrow" aria-hidden="true">→</span>
      </button>
    </form>
  `;

  const form = overlay.querySelector('#resetForm');
  const pw1 = /** @type {HTMLInputElement} */ (overlay.querySelector('#resetPw1'));
  const pw2 = /** @type {HTMLInputElement} */ (overlay.querySelector('#resetPw2'));
  const submitBtn = /** @type {HTMLButtonElement} */ (overlay.querySelector('#resetSubmitBtn'));
  const msg = overlay.querySelector('#resetMsg');

  setTimeout(() => pw1.focus(), 60);

  form.addEventListener('submit', async ev => {
    ev.preventDefault();
    msg.textContent = '';
    const p1 = pw1.value;
    const p2 = pw2.value;
    if (p1.length < 6) {
      msg.innerHTML = '<span class="auth-err">Lozinka mora imati najmanje 6 karaktera.</span>';
      return;
    }
    if (p1 !== p2) {
      msg.innerHTML = '<span class="auth-err">Lozinke se ne poklapaju.</span>';
      return;
    }

    submitBtn.disabled = true;
    msg.textContent = 'Menjam lozinku…';
    const res = await updatePassword(accessToken, p1);
    if (!res.ok) {
      submitBtn.disabled = false;
      msg.innerHTML = `<span class="auth-err">${escHtml(res.error)}</span>`;
      return;
    }

    /* Supabase posle uspeha vraća user objekat bez tokena — ali recovery token
     * (access_token) je VEĆ punopravan access token koji važi 1h (Supabase
     * vraća aal1 sesiju). Koristimo ga za automatski login i perzistenciju
     * sesije. */
    const user = res.user || {};
    setUser({
      email: (user.email || '').toLowerCase(),
      emailRaw: String(user.email || '').trim(),
      id: user.id,
      _token: accessToken,
    });
    setOnline(true);
    persistSession({
      access_token: accessToken,
      refresh_token: refreshToken || null,
      user,
    });

    cleanRecoveryUrl();
    msg.textContent = '✓ Lozinka je promenjena. Prijavljujem te…';
    setTimeout(() => {
      onSuccess?.({
        session: {
          access_token: accessToken,
          refresh_token: refreshToken || null,
          user,
        },
      });
    }, 500);
  });
}

/**
 * Prikaži poruku "link ne radi" + CTA za slanje novog linka.
 *
 * @param {HTMLElement} overlay
 * @param {{ description: string, onCancel: () => void }} opts
 */
function renderLinkInvalid(overlay, { description }) {
  const content = overlay.querySelector('#resetContent');
  const sub = overlay.querySelector('#resetSubtitle');
  sub.textContent = 'Link ne radi';
  content.innerHTML = `
    <div class="auth-reset-info">
      <div class="auth-reset-info-ico" aria-hidden="true">⚠️</div>
      <div class="auth-reset-info-txt">${escHtml(description)}</div>
    </div>
  `;
  /* Ispod poruke ponudi novi request. */
  renderRequestLinkForm(overlay, { append: true });
}

/**
 * Forma "Pošalji mi novi link". Pojavi se kada:
 *   a) korisnik uđe direktno na /reset-password bez ikakvih tokena,
 *   b) link ne radi (ispod obaveštenja).
 *
 * @param {HTMLElement} overlay
 * @param {{ append?: boolean, onCancel?: () => void }} [opts]
 */
function renderRequestLinkForm(overlay, { append = false } = {}) {
  const content = overlay.querySelector('#resetContent');
  const sub = overlay.querySelector('#resetSubtitle');
  if (!append) {
    sub.textContent = 'Pošalji link za reset na svoj email';
  }

  const formHtml = `
    ${append ? '<div class="auth-divider">Pošalji novi link</div>' : ''}
    <form class="auth-form" id="resetRequestForm">
      <div class="auth-field">
        <label for="resetReqEmail">Email</label>
        <input type="email" id="resetReqEmail" placeholder="ime@servoteh.rs"
               autocomplete="username" required>
      </div>
      <button type="submit" class="auth-btn-primary" id="resetReqBtn">
        Pošalji link
        <span class="arrow" aria-hidden="true">→</span>
      </button>
    </form>
  `;

  if (append) {
    content.insertAdjacentHTML('beforeend', formHtml);
  } else {
    content.innerHTML = formHtml;
  }

  const form = overlay.querySelector('#resetRequestForm');
  const emailEl = /** @type {HTMLInputElement} */ (overlay.querySelector('#resetReqEmail'));
  const btn = /** @type {HTMLButtonElement} */ (overlay.querySelector('#resetReqBtn'));
  const msg = overlay.querySelector('#resetMsg');

  form.addEventListener('submit', async ev => {
    ev.preventDefault();
    msg.textContent = '';
    const email = emailEl.value.trim();
    if (!email) {
      msg.innerHTML = '<span class="auth-err">Unesi email.</span>';
      return;
    }
    btn.disabled = true;
    msg.textContent = 'Šaljem link…';
    /* redirectTo vraća korisnika na istu stranicu (apsolutni URL + path). */
    const redirectTo = `${window.location.origin}/reset-password`;
    const res = await requestPasswordReset(email, redirectTo);
    btn.disabled = false;
    if (!res.ok) {
      msg.innerHTML = `<span class="auth-err">${escHtml(res.error)}</span>`;
      return;
    }
    msg.textContent = '✓ Ako postoji nalog sa tim email-om, poslali smo ti link.';
    /* Namerno generička poruka (email enumeration resistance). */
    emailEl.value = '';
  });
}
