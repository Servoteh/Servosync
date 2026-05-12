/**
 * Postavi top/left na `position: fixed` meni — anker uz trigger,
 * clamp na viewport (8px margin), flip iznad ako ne staje dole.
 * @param {HTMLElement} trigger - dugme koje otvara meni
 * @param {HTMLElement} menu - dropdown element (position: fixed)
 * @param {'left'|'right'} [anchor='left'] - na koju ivicu trigger-a aligniraj meni
 */
export function positionFloatingMenu(trigger, menu, anchor = 'left') {
  const wasHidden = menu.hasAttribute('hidden');
  menu.style.visibility = 'hidden';
  menu.removeAttribute('hidden');
  const tr = trigger.getBoundingClientRect();
  const menuW = menu.offsetWidth || 240;
  const menuH = menu.offsetHeight || 200;
  if (wasHidden) menu.setAttribute('hidden', '');
  menu.style.visibility = '';

  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const margin = 8;

  let left = anchor === 'right' ? Math.round(tr.right - menuW) : Math.round(tr.left);
  if (left < margin) left = margin;
  if (left + menuW > vw - margin) left = Math.max(margin, vw - menuW - margin);

  let top = Math.round(tr.bottom + 4);
  if (top + menuH > vh - margin) top = Math.max(margin, Math.round(tr.top - menuH - 4));

  menu.style.left = `${left}px`;
  menu.style.top = `${top}px`;
}
