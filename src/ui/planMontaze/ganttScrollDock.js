/**
 * Drži vertikalni scroll Gantt wrap-a na dnu sadržaja tako da je horizontalni
 * scrollbar uvek pri dnu vidljivog okvira (bez skrolovanja cele stranice).
 *
 * @param {HTMLElement|null} wrapEl npr. #ganttWrap ili #totalGanttWrap
 */
export function wireGanttScrollDock(wrapEl) {
  if (!wrapEl || wrapEl.dataset.scrollDocked === '1') return;
  wrapEl.dataset.scrollDocked = '1';

  let syncing = false;
  const snapToBottom = () => {
    if (syncing) return;
    syncing = true;
    requestAnimationFrame(() => {
      try {
        wrapEl.scrollTop = Math.max(0, wrapEl.scrollHeight - wrapEl.clientHeight);
      } finally {
        syncing = false;
      }
    });
  };

  wrapEl.addEventListener('scroll', () => {
    /* Korisnik ručno skroluje vertikalno — ne forsiraj nazad dok ne stane (resize/content). */
  }, { passive: true });

  const ro = typeof ResizeObserver !== 'undefined'
    ? new ResizeObserver(snapToBottom)
    : null;
  ro?.observe(wrapEl);
  snapToBottom();

  return () => {
    ro?.disconnect();
    wrapEl.dataset.scrollDocked = '';
  };
}
