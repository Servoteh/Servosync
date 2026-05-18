import { escHtml } from '../../lib/dom.js';

export function renderEmptyStateHtml({ icon = '📭', title, hint = '', actionHtml = '' }) {
  return `
    <div class="sast-empty sast-empty-state">
      <span class="sast-empty-icon" aria-hidden="true">${icon}</span>
      <p class="sast-empty-title">${escHtml(title)}</p>
      ${hint ? `<p class="sast-empty-hint">${escHtml(hint)}</p>` : ''}
      ${actionHtml ? `<div class="sast-empty-action">${actionHtml}</div>` : ''}
    </div>
  `;
}
