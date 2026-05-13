/**
 * Horizontalni „mirror” scrollbar ispod Gantt oblasti — uvek vidljiv dok je
 * panel fokusiran, sinhronizovan sa `.gantt-wrap-scroll` (Opcija A iz spec-a).
 *
 * @param {HTMLElement|null} wrapEl npr. #ganttWrap ili #totalGanttWrap
 * @returns {void | (() => void)}
 */
export function wireGanttScrollDock(wrapEl) {
  if (!wrapEl) return undefined;
  const scrollEl = wrapEl.querySelector('.gantt-wrap-scroll');
  const mirror = wrapEl.querySelector('.gantt-scroll-mirror');
  const spacer = mirror?.querySelector('.gantt-scroll-mirror-spacer');
  const inner = wrapEl.querySelector('.gantt-wrap-inner');
  if (!scrollEl || !mirror || !spacer || !inner) return undefined;

  const syncMirrorToScroll = () => {
    if (mirror.scrollLeft !== scrollEl.scrollLeft) mirror.scrollLeft = scrollEl.scrollLeft;
  };

  const syncScrollToMirror = () => {
    if (scrollEl.scrollLeft !== mirror.scrollLeft) scrollEl.scrollLeft = mirror.scrollLeft;
  };

  const setSpacerWidth = () => {
    spacer.style.width = `${inner.scrollWidth}px`;
    syncMirrorToScroll();
  };

  const ro = typeof ResizeObserver !== 'undefined'
    ? new ResizeObserver(setSpacerWidth)
    : null;
  ro?.observe(inner);

  scrollEl.addEventListener('scroll', syncMirrorToScroll, { passive: true });
  mirror.addEventListener('scroll', syncScrollToMirror, { passive: true });
  setSpacerWidth();

  return () => {
    ro?.disconnect();
    scrollEl.removeEventListener('scroll', syncMirrorToScroll);
    mirror.removeEventListener('scroll', syncScrollToMirror);
  };
}
