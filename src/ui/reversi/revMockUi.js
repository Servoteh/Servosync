/**
 * REVERSI — HTML helperi usklađeni sa .cursor/rev-redesign-import prototipom.
 */

import { escHtml } from '../../lib/dom.js';
import { ICON_REZNI_MACHINING } from './revMachiningIcon.js';

const P = {
  package:
    '<path d="M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z"/><path d="M12 22V12"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="m7.5 4.27 9 5.15"/>',
  wrench: '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>',
  scissors:
    '<circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><line x1="20" y1="4" x2="8.12" y2="15.88"/><line x1="14.47" y1="14.48" x2="20" y2="20"/><line x1="8.12" y1="8.12" x2="12" y2="12"/>',
  alert:
    '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
  search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
  download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>',
  plus: '<path d="M5 12h14"/><path d="M12 5v14"/>',
  eye:
    '<path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"/><circle cx="12" cy="12" r="3"/>',
  pencil:
    '<path d="M21.174 6.812a1 1 0 0 0-3.986-3.986L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a1 1 0 0 0 1.265 1.265l4.352-1.321a2 2 0 0 0 .83-.5z"/><path d="m15 5 4 4"/>',
  mapPin:
    '<path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0"/><circle cx="12" cy="10" r="3"/>',
  printer:
    '<path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><path d="M6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6"/><rect x="6" y="14" width="12" height="8" rx="1"/>',
  chevron: '<path d="m9 18 6-6-6-6"/>',
  check: '<path d="M20 6 9 17l-5-5"/>',
  cog:
    '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>',
  warehouse:
    '<path d="M22 8.35V20a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8.35A2 2 0 0 1 3.26 6.5l8-3.2a2 2 0 0 1 1.48 0l8 3.2A2 2 0 0 1 22 8.35Z"/><path d="M6 18h12"/><path d="M6 14h12"/><path d="M6 10h12"/>',
  rotate:
    '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>',
  user: '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  clipboard:
    '<rect width="8" height="4" x="8" y="2" rx="1" ry="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>',
  boxes:
    '<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="M12 22V12"/>',
  fileText:
    '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/>',
  arrowLeft: '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
  camera:
    '<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/><circle cx="12" cy="13" r="3"/>',
};

/** @param {keyof typeof P} name @param {number} [size] @param {string} [cls] */
export function revIcon(name, size = 16, cls = 'rev-ic') {
  const inner = P[name] || '';
  return `<svg class="${cls}" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${inner}</svg>`;
}

export function revIconRezni(size = 16, cls = 'rev-ic') {
  return ICON_REZNI_MACHINING.replace('width="16"', `width="${size}"`).replace('height="16"', `height="${size}"`).replace(
    'rev-tab-icon rev-icon--rezni-machining',
    cls,
  );
}

/**
 * @param {{ title: string, subtitle?: string, iconSvg: string, actionsHtml?: string }} p
 */
export function revPageHeaderHtml(p) {
  const sub = p.subtitle ? `<p class="rev-page-header__desc">${escHtml(p.subtitle)}</p>` : '';
  const actions = p.actionsHtml ? `<div class="rev-page-header__actions">${p.actionsHtml}</div>` : '';
  return `<header class="rev-page-header rev-page-header--mock">
    <div class="rev-page-header__main">
      <div class="rev-page-header__iconbox" aria-hidden="true">${p.iconSvg}</div>
      <div class="rev-page-header__text">
        <h2 class="rev-page-header__title">${escHtml(p.title)}</h2>
        ${sub}
      </div>
    </div>
    ${actions}
  </header>`;
}

/**
 * @param {{ label: string, value: string|number, hint?: string, iconName: keyof typeof P, tone?: 'default'|'warning'|'success' }} p
 */
export function revStatCardHtml(p) {
  const warn = p.tone === 'warning';
  const ok = p.tone === 'success';
  return `<div class="rev-stat-card rev-stat-card--mock ${warn ? 'rev-stat-card--mock-warn' : ''}">
    <div class="rev-stat-card__iconbox ${warn ? 'rev-stat-card__iconbox--warn' : ok ? 'rev-stat-card__iconbox--ok' : ''}" aria-hidden="true">${revIcon(p.iconName, 20)}</div>
    <div class="rev-stat-card__body">
      <div class="rev-stat-card__label">${escHtml(p.label)}</div>
      <div class="rev-stat-card__value-row">
        <span class="rev-stat-card__value">${escHtml(String(p.value))}</span>
        ${p.hint ? `<span class="rev-stat-card__hint-inline">${escHtml(p.hint)}</span>` : ''}
      </div>
    </div>
  </div>`;
}

/**
 * @param {{ left: string, right?: string }} p
 */
export function revTableMetaHtml(p) {
  return `<div class="rev-table-meta">
    <div class="rev-table-meta__left">${p.left}</div>
    ${p.right ? `<div class="rev-table-meta__right">${p.right}</div>` : ''}
  </div>`;
}

/**
 * @param {keyof typeof P} iconName
 * @param {string} title
 * @param {string} attrs extra attributes e.g. data-mag-eye="id"
 */
export function revActBtnHtml(iconName, title, attrs = '') {
  return `<button type="button" class="rev-act-btn rev-act-btn--mock" title="${escHtml(title)}" ${attrs}>${revIcon(iconName, 16)}</button>`;
}

/** @param {'HAND'|'CUTTING'} grupa */
export function revGrupaBadgeHtml(grupa) {
  if (grupa === 'CUTTING') {
    return `<span class="rev-grupa-badge rev-grupa-badge--rezni">${revIcon('scissors', 12, 'rev-ic rev-ic--inline')} Rezni</span>`;
  }
  return `<span class="rev-grupa-badge rev-grupa-badge--rucni">${revIcon('wrench', 12, 'rev-ic rev-ic--inline')} Ručni</span>`;
}

/** @param {string} code */
export function revLocPillHtml(code) {
  const c = String(code || '').trim();
  if (!c) return '<span class="rev-loc-empty">—</span>';
  return `<span class="rev-loc-pill">${revIcon('mapPin', 12, 'rev-ic rev-ic--inline')}<span class="rev-mono">${escHtml(c)}</span></span>`;
}

/** @param {unknown} d */
export function revFmtDate(d) {
  if (!d) return '—';
  try {
    const dt = new Date(/** @type {string} */ (d));
    if (Number.isNaN(dt.getTime())) return '—';
    const day = String(dt.getDate()).padStart(2, '0');
    const mon = String(dt.getMonth() + 1).padStart(2, '0');
    return `${day}.${mon}.${dt.getFullYear()}.`;
  } catch {
    return '—';
  }
}

/** @param {string} status rev_documents.status */
export function revDocStatusPillHtml(status) {
  const m = {
    OPEN: { cls: 'rev-status-pill--ok', text: 'Aktivno' },
    PARTIALLY_RETURNED: { cls: 'rev-status-pill--warn', text: 'Delimično vraćeno' },
    RETURNED: { cls: 'rev-status-pill--ok', text: 'Vraćeno' },
    CANCELLED: { cls: 'rev-status-pill--neutral', text: 'Otkazano' },
  };
  const p = m[status] || { cls: 'rev-status-pill--neutral', text: String(status || '—') };
  return `<span class="rev-status-pill ${p.cls}"><span class="rev-status-pill__dot"></span>${escHtml(p.text)}</span>`;
}

/** @param {{ status?: string, issued_holder?: unknown }} tool */
export function revToolStatusPillHtml(tool) {
  let cls = 'rev-status-pill--neutral';
  let text = tool.status || '—';
  if (tool.status === 'scrapped') {
    cls = 'rev-status-pill--neutral';
    text = 'Otpisan';
  } else if (tool.status === 'lost') {
    cls = 'rev-status-pill--danger';
    text = 'Izgubljen';
  } else if (tool.status === 'active') {
    cls = tool.issued_holder ? 'rev-status-pill--warn' : 'rev-status-pill--ok';
    text = tool.issued_holder ? 'Na reversu' : 'Aktivan';
  }
  return `<span class="rev-status-pill ${cls}"><span class="rev-status-pill__dot"></span>${escHtml(text)}</span>`;
}

/**
 * @param {string} id
 * @param {string} value
 * @param {string} placeholder
 */
export function revSearchFieldHtml(id, value, placeholder) {
  return `<div class="rev-search-field">
    ${revIcon('search', 16, 'rev-search-field__ic')}
    <input type="search" id="${escHtml(id)}" class="rev-input rev-input--search rev-input--mock" placeholder="${escHtml(placeholder)}" value="${escHtml(value)}"/>
  </div>`;
}
