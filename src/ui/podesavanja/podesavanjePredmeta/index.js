/**
 * Podešavanja → Podešavanje predmeta (aktivacija za Plan + Praćenje; poseban flag za projektovanje/montažu).
 */

import { listPredmetAktivacijaAdmin } from '../../../services/predmetAktivacija.js';
import { showToast } from '../../../lib/dom.js';
import {
  renderPredmetiTable,
  setPredmetAktivacijaRows,
  wirePredmetiTable,
} from './predmetiTable.js';

let _loadError = null;

export async function refreshPredmetAktivacija() {
  _loadError = null;
  const raw = await listPredmetAktivacijaAdmin();
  if (raw == null) {
    _loadError = 'forbidden';
    setPredmetAktivacijaRows([]);
    return [];
  }
  const rows = Array.isArray(raw) ? raw : [];
  setPredmetAktivacijaRows(rows);
  return rows;
}

export function getPredmetAktivacijaLoadError() {
  return _loadError;
}

export function renderPodesavanjePredmetaPanel() {
  if (_loadError === 'forbidden') {
    return `
      <div class="set-page-header">
        <div class="set-page-header-icon">&#x1F4CB;</div>
        <div>
          <h2 class="set-page-header-title">Pode&#x161;avanje predmeta</h2>
          <p class="set-page-header-sub">Aktivacija predmeta za Plan i Pra&#x107;enje; projektovanje i monta&#x17E;a (posebna kolona)</p>
        </div>
      </div>
      <div class="auth-box" style="max-width:560px;margin:12px 0">
        <div class="auth-title">Pristup odbijen</div>
        <p class="form-hint">Nemate prava da pristupite ovoj stranici (samo admin ili menad&#x17E;ment u ERP-u).</p>
      </div>`;
  }
  return `
    <div class="set-page-header">
      <div class="set-page-header-icon">&#x1F4CB;</div>
      <div>
        <h2 class="set-page-header-title">Pode&#x161;avanje predmeta</h2>
        <p class="set-page-header-sub">Aktivacija predmeta za Plan i Pra&#x107;enje; projektovanje i monta&#x17E;a (posebna kolona)</p>
      </div>
    </div>
    <p class="form-hint" style="margin-bottom:10px">
      Kolona <strong>Aktivan</strong> kontroli&#x161;e Plan proizvodnje i Pra&#x107;enje proizvodnje.
      Kolona <strong>Projektovanje i monta&#x17E;a</strong> &#x107;e kasnije filtrirati iste predmete u modulima projektovanja i plana monta&#x17E;e &mdash; prikazani bi&#x263;e samo predmeti koji su aktivni i ovde uklju&#x10D;eni za projektovanje/monta&#x17E;u.
      Novi predmeti iz BigTehn cache-a podrazumevano su uklju&#x10D;eni u oba slu&#x10D;aja dok ih ne isklju&#x10D;ite.
    </p>
    <div id="predAktTableHost">${renderPredmetiTable()}</div>`;
}

/**
 * @param {HTMLElement} root  panel (sadrži #predAktTableHost)
 */
export function wirePodesavanjePredmetaPanel(root) {
  const host = root.querySelector?.('#predAktTableHost');
  if (!host) return;
  const rerender = () => {
    host.innerHTML = renderPredmetiTable();
    wirePredmetiTable(host, { onChanged: rerender });
  };
  wirePredmetiTable(host, { onChanged: rerender });
}
