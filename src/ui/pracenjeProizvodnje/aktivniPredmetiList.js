/**
 * Ekran 1 — lista aktivnih predmeta (RPC get_aktivni_predmeti).
 */

import { escHtml } from '../../lib/dom.js';
import {
  loadAktivniPredmeti,
  selectPredmet,
  shiftPrioritet,
} from '../../state/pracenjeProizvodnjeState.js';

export function aktivniPredmetiListHtml(state) {
  const ap = state.aktivniPredmetiState || {};
  if (ap.loading) {
    return `
      <section class="form-card" style="margin-bottom:14px" aria-busy="true">
        <h2 class="form-section-title" style="margin:0 0 10px">Aktivni predmeti</h2>
        <p class="form-hint">Učitavanje liste…</p>
      </section>
    `;
  }
  if (ap.error) {
    return `
      <section class="form-card" style="margin-bottom:14px">
        <h2 class="form-section-title" style="margin:0 0 10px">Aktivni predmeti</h2>
        <p class="pp-error">Lista nije učitana: ${escHtml(ap.error)}</p>
        <button type="button" class="btn btn-ghost" id="ppAktPredmetiRetry">Pokušaj ponovo</button>
      </section>
    `;
  }
  const rows = ap.predmeti || [];
  if (!rows.length) {
    return `
      <section class="form-card" style="margin-bottom:14px">
        <h2 class="form-section-title" style="margin:0 0 10px">Aktivni predmeti</h2>
        <p class="form-hint">Nema aktivnih predmeta (MES lista bez item_id ili prazan cache).</p>
      </section>
    `;
  }
  const adminCol = ap.isAdmin
    ? '<th class="pp-cell-num" title="Samo admin">Prioritet</th>'
    : '';
  return `
    <section class="form-card" style="margin-bottom:14px">
      <h2 class="form-section-title" style="margin:0 0 10px">Aktivni predmeti</h2>
      <p class="form-hint" style="margin:0 0 12px">Klik na red ili badge otvara stablo podsklopova. RN detalji: <code>?rn=</code> ili polje ispod.</p>
      <div class="pp-table-wrap" style="max-height:min(60vh,520px);overflow:auto">
        <table class="pp-table" id="ppAktivniPredmetiTable">
          <thead>
            <tr>
              <th class="pp-cell-num">Red</th>
              <th>Predmet</th>
              <th>Komitent</th>
              <th class="pp-cell-num">Root RN</th>
              ${adminCol}
            </tr>
          </thead>
          <tbody id="ppAktPredmetiTbody">
            ${rows.map((r) => {
              const id = Number(r.item_id);
              const badge = Number(r.broj_root_rn ?? 0);
              const sub = escHtml(String(r.broj_predmeta || '—'));
              const naz = escHtml(String(r.naziv_predmeta || '—'));
              const kom = escHtml(String(r.customer_name || '—'));
              const adminBtns = ap.isAdmin ? `
                <td class="pp-cell-num">
                  <button type="button" class="pp-refresh-btn pp-prio-btn" data-pp-prio="${id}" data-dir="up" title="Gore">↑</button>
                  <button type="button" class="pp-refresh-btn pp-prio-btn" data-pp-prio="${id}" data-dir="down" title="Dole">↓</button>
                </td>` : '';
              return `
              <tr class="pp-pickable-predmet" data-predmet-id="${id}" style="cursor:pointer" title="Otvori podsklopove">
                <td class="pp-cell-num">${escHtml(String(r.redni_broj ?? ''))}</td>
                <td>
                  <div>${naz}</div>
                  <div class="form-hint" style="margin:2px 0 0;font-size:12px">${sub}</div>
                </td>
                <td>${kom}</td>
                <td class="pp-cell-num">
                  <button type="button" class="pp-badge-btn" data-predmet-badge="${id}" title="Otvori stablo">${badge}</button>
                </td>
                ${adminBtns}
              </tr>`;
            }).join('')}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

export function wireAktivniPredmetiList(container, renderShell) {
  container.querySelector('#ppAktPredmetiRetry')?.addEventListener('click', () => {
    void loadAktivniPredmeti().then(() => renderShell());
  });
  container.querySelector('#ppAktPredmetiTbody')?.addEventListener('click', (ev) => {
    const prio = ev.target.closest('.pp-prio-btn');
    if (prio) {
      ev.stopPropagation();
      const id = Number(prio.getAttribute('data-pp-prio'));
      const dir = prio.getAttribute('data-dir');
      if (Number.isFinite(id) && (dir === 'up' || dir === 'down')) {
        void shiftPrioritet(id, dir).then(() => renderShell());
      }
      return;
    }
    const badge = ev.target.closest('[data-predmet-badge]');
    if (badge) {
      ev.stopPropagation();
      const id = Number(badge.getAttribute('data-predmet-badge'));
      if (Number.isFinite(id)) void selectPredmet(id).then(() => renderShell());
      return;
    }
    const tr = ev.target.closest('tr[data-predmet-id]');
    if (!tr) return;
    const id = Number(tr.getAttribute('data-predmet-id'));
    if (Number.isFinite(id)) void selectPredmet(id).then(() => renderShell());
  });
}
