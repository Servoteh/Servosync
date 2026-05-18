/**
 * Podešavanja → Matični podaci — pregled šta je već u drugim tabovima.
 */

import { escHtml } from '../../lib/dom.js';
import { buildPodesavanjaModulePath } from '../../lib/podesavanjaTabs.js';

const LINKS = [
  { tab: 'organizacija', label: 'Organizacija', desc: 'Odeljenja, pododeljenja, radna mesta' },
  { tab: 'masine', label: 'Mašine', desc: 'Katalog mašina (CMMS + Lokacije sync)' },
  { tab: 'predmet-aktivacija', label: 'Podeš. predmeta', desc: 'Aktivacija predmeta i prioritet ⭐' },
];

export function renderMastersTab() {
  const items = LINKS.map(l => `
    <a class="set-notif-card" href="${escHtml(buildPodesavanjaModulePath(l.tab))}">
      <span class="set-notif-card-icon" aria-hidden="true">🗄</span>
      <div class="set-notif-card-body">
        <div class="set-notif-card-title">${escHtml(l.label)}</div>
        <p class="set-notif-card-desc">${escHtml(l.desc)}</p>
      </div>
      <span class="set-notif-card-arrow" aria-hidden="true">→</span>
    </a>
  `).join('');

  return `
    <div class="set-page-header">
      <div class="set-page-header-icon">🗄</div>
      <div>
        <h2 class="set-page-header-title">Matični podaci</h2>
        <p class="set-page-header-sub">Referentni podaci raspoređeni po sekcijama</p>
      </div>
    </div>
    <p class="form-hint" style="margin-bottom:14px">
      Umesto duplog „Odeljenja” taba, matični podaci su podeljeni: organizacija (kadrovska struktura),
      mašine (fizički resursi), predmeti (BigTehn cache + aktivacija).
    </p>
    <div class="set-notif-grid">${items}</div>
  `;
}
