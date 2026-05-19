/**
 * Mobilni filter drawer — zajednički chrome + Plan filteri.
 */

/** @param {HTMLElement|null|undefined} root .pb-module */
export function pbIsCompact(root) {
  if (root?.classList.contains('pb-module--compact')) return true;
  return window.matchMedia('(max-width: 1024px)').matches;
}

/** @param {HTMLElement} moduleRoot */
export function openPbFilterDrawer(moduleRoot) {
  const drawer = moduleRoot.querySelector('#pbFilterDrawer');
  if (!drawer) return;
  drawer.hidden = false;
  moduleRoot.classList.add('pb-module--filter-open');
  const btn = moduleRoot.querySelector('#pbOpenFilters');
  btn?.setAttribute('aria-expanded', 'true');
  const panel = moduleRoot.querySelector('.pb-filter-drawer-panel');
  panel?.focus();
}

/** @param {HTMLElement} moduleRoot */
export function closePbFilterDrawer(moduleRoot) {
  const drawer = moduleRoot.querySelector('#pbFilterDrawer');
  if (!drawer) return;
  drawer.hidden = true;
  moduleRoot.classList.remove('pb-module--filter-open');
  const btn = moduleRoot.querySelector('#pbOpenFilters');
  btn?.setAttribute('aria-expanded', 'false');
  moduleRoot._pbFilterTrapCleanup?.();
  moduleRoot._pbFilterTrapCleanup = null;
}

/**
 * @param {HTMLElement} moduleRoot
 * @param {number} count
 */
export function updatePbFilterBadge(moduleRoot, count) {
  const badge = moduleRoot.querySelector('#pbFilterBadge');
  if (!badge) return;
  if (count > 0) {
    badge.textContent = String(count);
    badge.hidden = false;
  } else {
    badge.hidden = true;
  }
}

/**
 * @param {HTMLElement} moduleRoot
 * @param {{ project?: string, engineer?: string, search?: string }} chrome
 * @param {{ status?: string, vrsta?: string, prioritet?: string, problemOnly?: boolean, unassignedOnly?: boolean, showDone?: boolean }} [plan]
 */
export function countPbActiveFilters(chrome, plan) {
  let n = 0;
  if (chrome.project && chrome.project !== 'all') n += 1;
  if (chrome.engineer && chrome.engineer !== 'all') n += 1;
  if ((chrome.search || '').trim()) n += 1;
  if (!plan) return n;
  if (plan.status && plan.status !== 'all') n += 1;
  if (plan.vrsta && plan.vrsta !== 'all') n += 1;
  if (plan.prioritet && plan.prioritet !== 'all') n += 1;
  if (plan.problemOnly) n += 1;
  if (plan.unassignedOnly) n += 1;
  if (plan.showDone) n += 1;
  return n;
}

function trapFocusInDrawer(moduleRoot) {
  moduleRoot._pbFilterTrapCleanup?.();
  const panel = moduleRoot.querySelector('.pb-filter-drawer-panel');
  if (!panel) return;

  const focusables = () => Array.from(panel.querySelectorAll(
    'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
  )).filter(el => el.offsetParent !== null);

  const onKey = e => {
    if (e.key !== 'Tab' || moduleRoot.querySelector('#pbFilterDrawer')?.hidden) return;
    const items = focusables();
    if (!items.length) return;
    const first = items[0];
    const last = items[items.length - 1];
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  };

  document.addEventListener('keydown', onKey);
  moduleRoot._pbFilterTrapCleanup = () => document.removeEventListener('keydown', onKey);
}

/**
 * @param {HTMLElement} moduleRoot
 * @param {{ onApply?: () => void }} [opts]
 */
export function wirePbFilterDrawer(moduleRoot, opts = {}) {
  if (moduleRoot._pbFilterDrawerWired) return;
  moduleRoot._pbFilterDrawerWired = true;

  const toggle = () => {
    const drawer = moduleRoot.querySelector('#pbFilterDrawer');
    if (drawer?.hidden) {
      openPbFilterDrawer(moduleRoot);
      trapFocusInDrawer(moduleRoot);
    } else {
      closePbFilterDrawer(moduleRoot);
    }
  };

  moduleRoot.querySelector('#pbOpenFilters')?.addEventListener('click', toggle);
  moduleRoot.querySelector('#pbFilterDrawerClose')?.addEventListener('click', () => {
    closePbFilterDrawer(moduleRoot);
  });
  moduleRoot.querySelector('#pbFilterDrawerBackdrop')?.addEventListener('click', () => {
    closePbFilterDrawer(moduleRoot);
  });
  moduleRoot.querySelector('#pbFilterDrawerApply')?.addEventListener('click', () => {
    opts.onApply?.();
    closePbFilterDrawer(moduleRoot);
  });
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && !moduleRoot.querySelector('#pbFilterDrawer')?.hidden) {
      closePbFilterDrawer(moduleRoot);
    }
  });
}
