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
}

/** @param {HTMLElement} moduleRoot */
export function closePbFilterDrawer(moduleRoot) {
  const drawer = moduleRoot.querySelector('#pbFilterDrawer');
  if (!drawer) return;
  drawer.hidden = true;
  moduleRoot.classList.remove('pb-module--filter-open');
  const btn = moduleRoot.querySelector('#pbOpenFilters');
  btn?.setAttribute('aria-expanded', 'false');
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

/**
 * @param {HTMLElement} moduleRoot
 */
export function wirePbFilterDrawer(moduleRoot) {
  if (moduleRoot._pbFilterDrawerWired) return;
  moduleRoot._pbFilterDrawerWired = true;

  moduleRoot.querySelector('#pbOpenFilters')?.addEventListener('click', () => {
    const drawer = moduleRoot.querySelector('#pbFilterDrawer');
    if (drawer?.hidden) openPbFilterDrawer(moduleRoot);
    else closePbFilterDrawer(moduleRoot);
  });
  moduleRoot.querySelector('#pbFilterDrawerClose')?.addEventListener('click', () => {
    closePbFilterDrawer(moduleRoot);
  });
  moduleRoot.querySelector('#pbFilterDrawerBackdrop')?.addEventListener('click', () => {
    closePbFilterDrawer(moduleRoot);
  });
}
