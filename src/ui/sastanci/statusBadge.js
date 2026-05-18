import { escHtml } from '../../lib/dom.js';
import { SASTANAK_STATUSI, SASTANAK_STATUS_BOJE } from '../../services/sastanci.js';
import { AKCIJA_STATUSI, AKCIJA_STATUS_BOJE } from '../../services/akcioniPlan.js';

const STATUS_MAPS = {
  sastanak: { labels: SASTANAK_STATUSI, colors: SASTANAK_STATUS_BOJE },
  akcija: { labels: AKCIJA_STATUSI, colors: AKCIJA_STATUS_BOJE },
};

/**
 * @param {string} status
 * @param {{ kind?: 'sastanak'|'akcija', label?: string, title?: string, className?: string }} [opts]
 */
export function renderStatusBadge(status, opts = {}) {
  const kind = opts.kind || 'sastanak';
  const maps = STATUS_MAPS[kind] || STATUS_MAPS.sastanak;
  const st = status || 'planiran';
  const label = opts.label ?? maps.labels[st] ?? st;
  const color = maps.colors[st] || '#888';
  const extra = opts.className ? ` ${opts.className}` : '';
  const title = opts.title ? ` title="${escHtml(opts.title)}"` : '';
  return `<span class="sast-status-pill sast-status-pill--${escHtml(st)}${extra}" style="background:${color}"${title}>${escHtml(label)}</span>`;
}
