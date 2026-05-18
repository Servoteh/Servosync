/**
 * Podešavanja → Notifikacije (centralni hub + linkovi ka modulima).
 */

import { escHtml } from '../../lib/dom.js';
import { buildPodesavanjaModulePath } from '../../lib/podesavanjaTabs.js';

const MODULE_NOTIF_LINKS = [
  {
    id: 'pb',
    icon: '📐',
    title: 'Projektni biro',
    desc: 'Email primaoci, pragovi rokova, tihi sati, digest.',
    href: '/projektni-biro',
    hint: 'Tab „Podešavanja” unutar PB modula (samo admin).',
  },
  {
    id: 'sastanci',
    icon: '📅',
    title: 'Sastanci',
    desc: 'Lične email preference: pozivnice, zaključavanje, podsetnici.',
    href: '/sastanci/podesavanja-notifikacija',
    hint: 'Svaki korisnik podešava svoje preference.',
  },
  {
    id: 'maint',
    icon: '🔧',
    title: 'Održavanje mašina',
    desc: 'CMMS pravila, kanali, eskalacije.',
    href: '/maintenance/settings',
    hint: 'Maint chief / admin u modulu Održavanje.',
  },
  {
    id: 'kadrovska',
    icon: '🏥',
    title: 'Kadrovska (HR)',
    desc: 'HR podsetnici — WhatsApp / email outbox.',
    href: '/kadrovska',
    hint: 'Konfiguracija u Kadrovskoj sekciji notifikacija.',
  },
];

export function renderNotifikacijeTab() {
  const cards = MODULE_NOTIF_LINKS.map(l => `
    <a class="set-notif-card" href="${escHtml(l.href)}" data-notif-link="${escHtml(l.id)}">
      <span class="set-notif-card-icon" aria-hidden="true">${l.icon}</span>
      <div class="set-notif-card-body">
        <div class="set-notif-card-title">${escHtml(l.title)}</div>
        <p class="set-notif-card-desc">${escHtml(l.desc)}</p>
        <p class="set-notif-card-hint">${escHtml(l.hint)}</p>
      </div>
      <span class="set-notif-card-arrow" aria-hidden="true">→</span>
    </a>
  `).join('');

  return `
    <div class="set-page-header">
      <div class="set-page-header-icon">🔔</div>
      <div>
        <h2 class="set-page-header-title">Notifikacije</h2>
        <p class="set-page-header-sub">Centralni pregled — konfiguracija po modulu</p>
      </div>
    </div>
    <p class="form-hint" style="margin-bottom:14px">
      Notifikacije su trenutno podešavane u okviru svakog modula. Ovde su svi ulazi na jednom mestu.
      Globalni digest / integracije: tab <a href="${escHtml(buildPodesavanjaModulePath('integracije'))}">Integracije</a>.
    </p>
    <div class="set-notif-grid">${cards}</div>
  `;
}

export function wireNotifikacijeTab(root) {
  root.querySelectorAll('[data-notif-link]').forEach(a => {
    a.addEventListener('click', ev => {
      /* SPA router hvata klik na <a href> ako je već podešeno u app */
    });
  });
}
