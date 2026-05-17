/**
 * Podešavanja → Mašine (matični podatak).
 *
 * Tanki wrapper oko `renderMaintCatalogPanel` iz Održavanja — ista komponenta,
 * druga tačka ulaska. Page header pojašnjava da je ovo matični podatak koji
 * se reflektuje i u Lokacijama i u Održavanju.
 *
 * Pristup: ERP admin / menadžment kroz `canAccessPodesavanja()`. Maint chief
 * i dalje ima paralelni ulaz preko `/maintenance/catalog`.
 */

import {
  renderMaintCatalogPanel,
} from '../odrzavanjeMasina/maintCatalogTab.js';
import { fetchMaintUserProfile } from '../../services/maintenance.js';

let _prof = null;

export async function refreshMaintMachinesTab() {
  _prof = await fetchMaintUserProfile().catch(() => null);
  return _prof;
}

export function renderMasineTab() {
  return `
    <div class="set-page-header">
      <div class="set-page-header-icon">🛠</div>
      <div>
        <h2 class="set-page-header-title">Mašine</h2>
        <p class="set-page-header-sub">
          Katalog mašina (matični podatak). Dodavanje, izmena, arhiviranje,
          uvoz iz BigTehn-a. Mašine iz ovog kataloga se prikazuju i u
          Lokacijama i u modulu Održavanje.
        </p>
      </div>
    </div>
    <div id="setMasineHost"></div>
  `;
}

/**
 * @param {HTMLElement} root
 * @param {{ onNavigateToPath?: (p:string)=>void }} [opts]
 */
export function wireMasineTab(root, opts = {}) {
  const host = root.querySelector('#setMasineHost');
  if (!host) return;
  renderMaintCatalogPanel(host, {
    prof: _prof,
    onNavigateToPath: opts.onNavigateToPath,
  });
}
