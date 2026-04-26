/**
 * Podešavanja → Podešavanje predmeta (aktivacija za Plan + Praćenje).
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
      <div class="auth-box" style="max-width:560px;margin:12px 0">
        <div class="auth-title">Pristup odbijen</div>
        <p class="form-hint">Nemate prava da pristupite ovoj stranici (samo admin ili menadžment u ERP-u).</p>
      </div>`;
  }
  return `
    <p class="form-hint" style="margin-bottom:10px">
      Uključivanje predmeta određuje vidljivost u <strong>Planu proizvodnje</strong> i <strong>Praćenju proizvodnje</strong>.
      Novi predmeti iz BigTehn cache-a podrazumevano su aktivni dok ih ne isključite.
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
