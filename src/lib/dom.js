/**
 * Sitni DOM/UI helperi koje koriste više modula.
 *
 * - escHtml: identičan onom iz legacy/index.html (NE menjaj — koristi se
 *   svuda za XSS-safe interpolaciju u .innerHTML).
 * - $/$$ : kratki querySelector/querySelectorAll.
 * - showToast: očekuje da postoji <div class="toast" id="toast"></div>
 *   negde u DOM-u (mount-uje se u Faza 3 u app shell).
 */

export function escHtml(s) {
  if (s == null) return '';
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function $(sel, root = document) {
  return root.querySelector(sel);
}

export function $$(sel, root = document) {
  return Array.from(root.querySelectorAll(sel));
}

/**
 * Toast notifikacija — stack do MAX_VISIBLE redom; preko toga čeka u queue.
 *
 * Auto-detekt tipa po prefix emoji-ju:
 *   ⚠ / ❌ / Greška → 'error' (crveno)
 *   ✅ / 💾 / 📊    → 'success' (zeleno)
 *   ℹ / 💡         → 'info'  (plavo)
 *   ostalo         → 'info'  (default)
 *
 * `opts.type` eksplicitno preglasava auto-detekciju.
 * `opts.duration` u ms (default 2800; error 4500 jer korisnik treba duže da pročita).
 *
 * Klik na toast = ručno zatvaranje. Backward compatible — `showToast('poruka')` i dalje radi.
 *
 * @param {string} msg
 * @param {{ type?: 'info'|'success'|'warn'|'error', duration?: number }} [opts]
 */
const TOAST_MAX_VISIBLE = 3;
const _toastQueue = [];
let _toastVisibleCount = 0;

function _toastDetectType(msg) {
  const s = String(msg || '');
  if (/^(⚠|❌|🚫|Greška|⛔)/i.test(s) || /greška|neuspe|nije uspe|fail/i.test(s)) return 'warn';
  if (/^(✅|💾|📊|🎉|✓|🗑|✏)/i.test(s)) return 'success';
  if (/^(ℹ|💡|📧|📄|🔔|⏳|🔒)/i.test(s)) return 'info';
  return 'info';
}

function _toastStack() {
  let stack = document.getElementById('toastStack');
  if (!stack) {
    stack = document.createElement('div');
    stack.id = 'toastStack';
    stack.className = 'toast-stack';
    stack.setAttribute('role', 'region');
    stack.setAttribute('aria-label', 'Notifikacije');
    stack.setAttribute('aria-live', 'polite');
    document.body.appendChild(stack);
  }
  return stack;
}

function _showToastImmediate(msg, opts) {
  const type = opts?.type || _toastDetectType(msg);
  const duration = Number(opts?.duration) || (type === 'warn' || type === 'error' ? 4500 : 2800);
  const stack = _toastStack();
  const el = document.createElement('div');
  el.className = `toast-item t-${type}`;
  el.textContent = String(msg);
  el.setAttribute('role', type === 'warn' || type === 'error' ? 'alert' : 'status');
  stack.appendChild(el);
  /* Trigger transition — slide-in. */
  requestAnimationFrame(() => el.classList.add('show'));
  _toastVisibleCount += 1;

  const dismiss = () => {
    if (el._dismissed) return;
    el._dismissed = true;
    el.classList.remove('show');
    setTimeout(() => {
      el.remove();
      _toastVisibleCount = Math.max(0, _toastVisibleCount - 1);
      _toastDrainQueue();
    }, 220);
  };
  el.addEventListener('click', dismiss);
  setTimeout(dismiss, duration);
}

function _toastDrainQueue() {
  while (_toastVisibleCount < TOAST_MAX_VISIBLE && _toastQueue.length) {
    const next = _toastQueue.shift();
    _showToastImmediate(next.msg, next.opts);
  }
}

export function showToast(msg, opts) {
  if (_toastVisibleCount >= TOAST_MAX_VISIBLE) {
    _toastQueue.push({ msg, opts });
    return;
  }
  _showToastImmediate(msg, opts);
}

/**
 * Skeleton loader HTML — koristi se umesto "Učitavanje…" tekstualnih placeholdera.
 * `variant` može biti:
 *   - 'table'  (default): N redova sa avatarom + 3 bara različite širine
 *   - 'list':   N redova sa 2 bara, bez avatara
 *   - 'bars':   N tankih bara raznih širina
 *
 * @param {{ variant?: 'table'|'list'|'bars', rows?: number }} [opts]
 */
export function renderSkeleton(opts = {}) {
  const variant = opts.variant || 'table';
  const rows = Math.max(1, opts.rows || 5);
  let body = '';
  if (variant === 'table') {
    for (let i = 0; i < rows; i++) {
      body += `<div class="kadr-skel-row">
        <span class="kadr-skel-block kadr-skel-circle"></span>
        <span class="kadr-skel-block kadr-skel-bar kadr-skel-bar-md"></span>
        <span class="kadr-skel-block kadr-skel-bar kadr-skel-bar-sm"></span>
        <span class="kadr-skel-block kadr-skel-bar kadr-skel-bar-lg" style="margin-left:auto;max-width:120px"></span>
      </div>`;
    }
  } else if (variant === 'list') {
    for (let i = 0; i < rows; i++) {
      body += `<div class="kadr-skel-row">
        <span class="kadr-skel-block kadr-skel-bar kadr-skel-bar-md"></span>
        <span class="kadr-skel-block kadr-skel-bar kadr-skel-bar-sm" style="margin-left:auto"></span>
      </div>`;
    }
  } else { /* bars */
    for (let i = 0; i < rows; i++) {
      const cls = i % 3 === 0 ? 'kadr-skel-bar-lg' : i % 3 === 1 ? 'kadr-skel-bar-md' : 'kadr-skel-bar-sm';
      body += `<div style="padding:6px 4px"><span class="kadr-skel-block kadr-skel-bar ${cls}"></span></div>`;
    }
  }
  return `<div class="kadr-skel-table" aria-busy="true" aria-label="Učitavanje">${body}</div>`;
}
