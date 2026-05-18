/**
 * Sticky horizontal scrollbar — proxy scroll element fiksiran na dnu vertikalnog
 * scroll viewport-a (a NE na dnu samog tabelarnog sadržaja). Korisno za duge
 * tabele gde "pravi" hscroll bar bude off-screen dok ne scrolluješ dole.
 *
 * Pattern:
 *   1. `scrollEl` je element sa `overflow-x: auto` (tabelarni wrap).
 *   2. Insert proxy element kao siblings IZA `scrollEl`, sa
 *      `position: sticky; bottom: 0` da se zalepi za dno vidljivog viewport-a
 *      bližeg ancestral scroll container-a (npr. .pb-tab-body, .kadrovska-tab-body).
 *   3. Proxy ima fixed visinu (~14px), `overflow-x: auto`, i unutar njega "spacer"
 *      div čija je širina = `scrollEl.scrollWidth` (replikuje horizontal extent).
 *   4. JS sync: scroll na proxy → scrollEl.scrollLeft (i obrnuto).
 *
 * Mobile: nativni horizontal scroll je dovoljan (touch). Proxy je sakriven CSS-om
 * pod 768px.
 *
 * @param {HTMLElement|null} scrollEl   Element sa overflow-x: auto.
 * @param {object} [opts]
 * @param {string} [opts.contentSelector]  CSS selector za content unutar scrollEl
 *   čija se širina meri (default: scrollEl sam).
 * @returns {() => void | undefined}   Cleanup funkcija; pozvati pri unmount-u.
 */
export function attachStickyHscroll(scrollEl, opts = {}) {
  if (!scrollEl) return undefined;
  if (scrollEl.dataset.stickyHscrollAttached === '1') return undefined;
  scrollEl.dataset.stickyHscrollAttached = '1';

  const proxy = document.createElement('div');
  proxy.className = 'sticky-hscroll-proxy';
  proxy.setAttribute('aria-hidden', 'true');
  const spacer = document.createElement('div');
  spacer.className = 'sticky-hscroll-spacer';
  proxy.appendChild(spacer);

  // Insert proxy odmah POSLE scrollEl-a u istom parent-u (DOM siblings).
  if (scrollEl.parentNode) {
    scrollEl.parentNode.insertBefore(proxy, scrollEl.nextSibling);
  }

  const contentEl = opts.contentSelector
    ? scrollEl.querySelector(opts.contentSelector)
    : null;

  function getContentWidth() {
    if (contentEl) return contentEl.scrollWidth;
    return scrollEl.scrollWidth;
  }

  function updateSpacerWidth() {
    const w = getContentWidth();
    spacer.style.width = `${w}px`;
    // Sakrij proxy kad nema horizontal overflow-a (širina sadržaja <= širina viewport-a).
    const hasOverflow = w > scrollEl.clientWidth + 1;
    proxy.style.display = hasOverflow ? '' : 'none';
  }

  let syncing = false;
  function syncFromMain() {
    if (syncing) return;
    syncing = true;
    if (proxy.scrollLeft !== scrollEl.scrollLeft) {
      proxy.scrollLeft = scrollEl.scrollLeft;
    }
    syncing = false;
  }
  function syncFromProxy() {
    if (syncing) return;
    syncing = true;
    if (scrollEl.scrollLeft !== proxy.scrollLeft) {
      scrollEl.scrollLeft = proxy.scrollLeft;
    }
    syncing = false;
  }

  scrollEl.addEventListener('scroll', syncFromMain, { passive: true });
  proxy.addEventListener('scroll', syncFromProxy, { passive: true });

  let ro = null;
  if (typeof ResizeObserver !== 'undefined') {
    ro = new ResizeObserver(updateSpacerWidth);
    ro.observe(scrollEl);
    if (contentEl) ro.observe(contentEl);
  }

  // Inicijalni sync (sledeći frame da DOM dobije pravi scrollWidth).
  requestAnimationFrame(updateSpacerWidth);

  return () => {
    ro?.disconnect();
    scrollEl.removeEventListener('scroll', syncFromMain);
    proxy.removeEventListener('scroll', syncFromProxy);
    proxy.remove();
    delete scrollEl.dataset.stickyHscrollAttached;
  };
}
