import { escHtml } from '../../lib/dom.js';
import { PRACENJE_TABS, setActiveTab } from '../../state/pracenjeProizvodnjeState.js';

const TABS = [
  { id: 'po_pozicijama', label: 'Po pozicijama', icon: '▦' },
  { id: 'operativni_plan', label: 'Operativni plan', icon: '☷' },
];

export function tabSwitcherHtml(activeTab) {
  return `
    <nav class="kadrovska-tabs" role="tablist" aria-label="Praćenje proizvodnje tabovi" style="margin-bottom:14px">
      ${TABS.map(t => `
        <button type="button" role="tab"
          class="kadrovska-tab${t.id === activeTab ? ' is-active' : ''}"
          data-pracenje-tab="${escHtml(t.id)}"
          aria-selected="${t.id === activeTab ? 'true' : 'false'}">
          <span aria-hidden="true">${escHtml(t.icon)}</span> ${escHtml(t.label)}
        </button>
      `).join('')}
    </nav>
  `;
}

export function wireTabSwitcher(root, onChange) {
  root.querySelectorAll('[data-pracenje-tab]').forEach(btn => {
    btn.addEventListener('click', () => {
      const tab = btn.dataset.pracenjeTab;
      if (!PRACENJE_TABS.includes(tab)) return;
      const nextHash = `#tab=${tab}`;
      if (window.location.hash !== nextHash) {
        history.replaceState(null, '', window.location.pathname + window.location.search + nextHash);
      }
      setActiveTab(tab);
      onChange?.();
    });
  });
}

export function tabFromHash() {
  const raw = new URLSearchParams((window.location.hash || '').replace(/^#/, '')).get('tab');
  return PRACENJE_TABS.includes(raw) ? raw : null;
}
