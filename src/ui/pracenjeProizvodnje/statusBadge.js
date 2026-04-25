import { escHtml } from '../../lib/dom.js';

const STATUS_META = {
  nije_krenulo: { label: 'Nije krenulo', cls: 's-waiting' },
  u_toku: { label: 'U toku', cls: 's-in_progress' },
  blokirano: { label: 'Blokirano', cls: 's-blocked' },
  zavrseno: { label: 'Završeno', cls: 's-completed' },
};

export function statusBadgeHtml(activityOrStatus, opts = {}) {
  const activity = typeof activityOrStatus === 'object'
    ? activityOrStatus
    : { efektivni_status: activityOrStatus };
  const status = activity.efektivni_status || activity.status || 'nije_krenulo';
  const meta = STATUS_META[status] || STATUS_META.nije_krenulo;
  const detailParts = [];
  if (activity.status_is_auto && activity.status_detail) detailParts.push(activity.status_detail);
  if (status === 'blokirano' && activity.blokirano_razlog) {
    detailParts.push(`Razlog: ${activity.blokirano_razlog}`);
  }
  const title = detailParts.join(' | ') || meta.label;
  const autoIcon = activity.status_is_auto
    ? `<span aria-hidden="true" title="${escHtml(title)}">↔</span>`
    : '';
  const disabled = opts.button === false ? '' : ' type="button"';
  return `
    <button${disabled} class="pp-status ${meta.cls}" title="${escHtml(title)}" data-status-badge="${escHtml(status)}">
      ${escHtml(meta.label)}${autoIcon}
    </button>
  `;
}

export function priorityBadgeHtml(priority) {
  const p = priority || 'srednji';
  const label = p === 'visok' ? 'Visok' : p === 'nizak' ? 'Nizak' : 'Srednji';
  return `<span class="pp-pri" title="Prioritet">${escHtml(label)}</span>`;
}
