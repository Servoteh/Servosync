import { escHtml } from '../../lib/dom.js';

/**
 * Minimalni markdown (bez npm). Ulaz se prvo escHtml-uje.
 */
export function markdownToHtml(src) {
  const raw = String(src || '');
  if (!raw.trim()) return '';

  const parts = [];
  const re = /```([\s\S]*?)```/g;
  let last = 0;
  let m;
  while ((m = re.exec(raw)) !== null) {
    if (m.index > last) parts.push({ type: 'text', v: raw.slice(last, m.index) });
    parts.push({ type: 'code', v: m[1] });
    last = m.index + m[0].length;
  }
  if (last < raw.length) parts.push({ type: 'text', v: raw.slice(last) });

  return parts.map(p => {
    if (p.type === 'code') {
      return `<pre class="pb-md-pre"><code>${escHtml(p.v)}</code></pre>`;
    }
    let s = escHtml(p.v);
    s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    s = s.replace(/\*([^*]+)\*/g, '<em>$1</em>');
    s = s.replace(
      /\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g,
      '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>',
    );
    return s.split(/\n\n+/).map(block => {
      const t = block.trim();
      if (!t) return '';
      return `<p class="pb-md-p">${t.replace(/\n/g, '<br>')}</p>`;
    }).join('');
  }).join('');
}
