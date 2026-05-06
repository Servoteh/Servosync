/**
 * Tabela predmeta + filter + toggle aktivacije + prioritet.
 *
 * Prioritet (top 10): predmeti sa zvezdicom se prikazuju prvi u svim
 * pregledima (Plan, Praćenje, pretraga). Redosled se menja strelicama.
 * Čuva se lokalno u localStorage (prioritetService.js).
 */

import { escHtml, showToast } from '../../../lib/dom.js';
import { setPredmetAktivacija } from '../../../services/predmetAktivacija.js';
import { openNapomenaModal } from './napomenaModal.js';
import {
  getPrioritetIds,
  addToPrioritet,
  removeFromPrioritet,
  isPrioritet,
  movePrioritetUp,
  movePrioritetDown,
} from './prioritetService.js';

let _rows = [];
let _filter = 'all'; /* 'all' | 'active' | 'inactive' | 'prioritet' */
let _search = '';

function formatAt(iso) {
  if (!iso) return '—';
  try {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return escHtml(String(iso));
    return escHtml(d.toLocaleString('sr-Latn-RS', { dateStyle: 'short', timeStyle: 'short' }));
  } catch {
    return '—';
  }
}

function filterRows() {
  const q = _search.trim().toLowerCase();
  const prioIds = getPrioritetIds();

  let list = _rows.filter(r => {
    if (_filter === 'active' && !r.je_aktivan) return false;
    if (_filter === 'inactive' && r.je_aktivan) return false;
    if (_filter === 'prioritet' && !prioIds.includes(Number(r.item_id))) return false;
    if (!q) return true;
    const sif = String(r.broj_predmeta || '').toLowerCase();
    const naz = String(r.naziv_predmeta || '').toLowerCase();
    return sif.includes(q) || naz.includes(q);
  });

  /* Prioritetni redovi uvek prvi, sortirani po poziciji u listi */
  list.sort((a, b) => {
    const ia = prioIds.indexOf(Number(a.item_id));
    const ib = prioIds.indexOf(Number(b.item_id));
    if (ia !== -1 && ib !== -1) return ia - ib;
    if (ia !== -1) return -1;
    if (ib !== -1) return 1;
    return 0;
  });

  return list;
}

export function setPredmetAktivacijaRows(rows) {
  _rows = Array.isArray(rows) ? rows : [];
}

export function renderPredmetiTable() {
  const list = filterRows();
  const prioIds = getPrioritetIds();
  const prioCount = prioIds.length;
  const canAddMore = prioCount < 10;

  return `
    <div style="display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-bottom:10px">
      <span class="kadr-count">${list.length} prikazano / ${_rows.length} ukupno</span>
      <span style="font-size:12px;color:var(--text3)">•</span>
      <span style="font-size:12px;color:var(--text3)">
        ⭐ Top prioritet: <strong style="color:var(--accent)">${prioCount}/10</strong>
        ${!canAddMore ? ' — lista popunjena' : ''}
      </span>
    </div>
    <div style="display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-bottom:12px">
      <input type="search" class="form-input" id="predAktSearch" style="max-width:240px"
        placeholder="Šifra ili naziv…" value="${escHtml(_search)}">
      <select class="form-input" id="predAktFilter" style="max-width:180px">
        <option value="all" ${_filter === 'all' ? 'selected' : ''}>Svi predmeti</option>
        <option value="prioritet" ${_filter === 'prioritet' ? 'selected' : ''}>⭐ Samo prioritet</option>
        <option value="active" ${_filter === 'active' ? 'selected' : ''}>Aktivni</option>
        <option value="inactive" ${_filter === 'inactive' ? 'selected' : ''}>Neaktivni</option>
      </select>
    </div>
    <div class="mnt-table-wrap" style="overflow:auto;max-height:70vh">
      <table class="mnt-table" style="font-size:13px;min-width:780px">
        <thead>
          <tr>
            <th style="width:40px;text-align:center" title="Prioritet (top 10 — prikazuju se prvi u svim pregledima)">⭐</th>
            <th>Šifra</th>
            <th>Naziv</th>
            <th>Komitent</th>
            <th style="width:64px;text-align:center">Aktivan</th>
            <th>Poslednja izmena</th>
            <th>Napomena</th>
          </tr>
        </thead>
        <tbody>
          ${list.length ? list.map(r => _rowHtml(r, prioIds)).join('') : `<tr><td colspan="7" class="mnt-muted">Nema redova za filter.</td></tr>`}
        </tbody>
      </table>
    </div>
    ${prioCount > 0 ? _prioritetLegendHtml(prioIds) : ''}
  `;
}

function _prioritetLegendHtml(prioIds) {
  const names = prioIds.map((id, i) => {
    const r = _rows.find(x => Number(x.item_id) === id);
    if (!r) return null;
    return `<span style="font-size:11px;color:var(--text2)">${i + 1}. ${escHtml(String(r.broj_predmeta || ''))} ${escHtml(String(r.naziv_predmeta || ''))}</span>`;
  }).filter(Boolean);

  if (!names.length) return '';
  return `
    <div style="margin-top:12px;padding:10px 14px;background:var(--surface2);border-radius:8px;border:1px solid var(--border)">
      <div style="font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.07em;color:var(--text3);margin-bottom:6px">Prioritetni redosled (prikazuje se u svim pregledima)</div>
      <div style="display:flex;flex-wrap:wrap;gap:6px">${names.join('')}</div>
    </div>
  `;
}

function _rowHtml(r, prioIds) {
  const id = Number(r.item_id);
  const chk = r.je_aktivan ? 'checked' : '';
  const who = r.azurirao_email ? escHtml(r.azurirao_email) : '—';
  const when = formatAt(r.azurirano_at);
  const nap = r.napomena != null && String(r.napomena).trim() !== '' ? escHtml(String(r.napomena)) : '—';

  const prioPos = prioIds.indexOf(id);
  const inPrio = prioPos !== -1;
  const isFirst = prioPos === 0;
  const isLast = prioPos === prioIds.length - 1;

  const prioCell = inPrio
    ? `<div style="display:flex;align-items:center;justify-content:center;gap:2px">
         <span class="pred-prio-num">${prioPos + 1}</span>
         <div style="display:flex;flex-direction:column;gap:1px">
           <button type="button" class="pred-prio-btn" data-pred-prio-up="${id}" title="Pomeri gore" ${isFirst ? 'disabled style="opacity:0.3"' : ''}>▲</button>
           <button type="button" class="pred-prio-btn" data-pred-prio-down="${id}" title="Pomeri dole" ${isLast ? 'disabled style="opacity:0.3"' : ''}>▼</button>
         </div>
         <button type="button" class="pred-prio-btn is-prio" data-pred-prio-toggle="${id}" title="Ukloni iz prioriteta">⭐</button>
       </div>`
    : `<div style="display:flex;justify-content:center">
         <button type="button" class="pred-prio-btn" data-pred-prio-toggle="${id}" title="Dodaj u prioritet (top 10)">☆</button>
       </div>`;

  return `<tr data-pred-akt-id="${id}" ${inPrio ? 'style="background:color-mix(in srgb, var(--accent) 4%, var(--surface))"' : ''}>
    <td style="text-align:center;vertical-align:middle">${prioCell}</td>
    <td><code>${escHtml(String(r.broj_predmeta || ''))}</code></td>
    <td>${escHtml(String(r.naziv_predmeta || ''))}</td>
    <td>${escHtml(String(r.customer_name || ''))}</td>
    <td style="text-align:center"><label class="mnt-toggle"><input type="checkbox" data-pred-akt-toggle="${id}" ${chk} aria-label="Aktivan"></label></td>
    <td style="white-space:nowrap;font-size:12px">${who}<br><span class="mnt-muted">${when}</span></td>
    <td><button type="button" class="kadr-action-btn" data-pred-akt-nap="${id}" title="Izmeni napomenu">${nap}</button></td>
  </tr>`;
}

/**
 * @param {HTMLElement} root
 * @param {{ onChanged?: () => void }} [opts]
 */
export function wirePredmetiTable(root, opts = {}) {
  const onChanged = opts.onChanged || null;

  const findRow = id => _rows.find(x => Number(x.item_id) === Number(id));

  root.querySelector('#predAktSearch')?.addEventListener('input', e => {
    _search = e.target?.value || '';
    onChanged?.();
  });
  root.querySelector('#predAktFilter')?.addEventListener('change', e => {
    _filter = e.target?.value || 'all';
    onChanged?.();
  });

  /* Aktivacija toggle */
  root.querySelectorAll('[data-pred-akt-toggle]').forEach(el => {
    el.addEventListener('change', async ev => {
      const input = ev.target;
      if (!(input instanceof HTMLInputElement) || input.type !== 'checkbox') return;
      const id = Number(input.getAttribute('data-pred-akt-toggle'));
      const next = input.checked;
      const prev = findRow(id);
      const oldAkt = !!prev?.je_aktivan;
      input.checked = oldAkt;
      const sif = prev ? String(prev.broj_predmeta || '').trim() : '';
      const naz = prev ? String(prev.naziv_predmeta || '').trim() : '';
      const opis = [sif || `#${id}`, naz].filter(Boolean).join(' — ');
      const akcija = next ? 'aktivirate' : 'deaktivirate';
      const upozorenje = next
        ? 'Predmet će ući u Plan proizvodnje i u listu u Praćenju proizvodnje (uz ostala podešavanja).'
        : 'Predmet će biti uklonjen iz Plana proizvodnje i iz liste u Praćenju proizvodnje, bez brisanja podataka u bazi.';
      const potvrdi = window.confirm(
        `Da li ste sigurni da želite da ${akcija} predmet?\n\n${opis}\n\n${upozorenje}\n\nNastaviti?`
      );
      if (!potvrdi) return;
      input.checked = next;
      if (prev) prev.je_aktivan = next;
      const ok = await setPredmetAktivacija(id, next, null);
      if (ok == null) {
        if (prev) prev.je_aktivan = oldAkt;
        input.checked = oldAkt;
        showToast('Snimanje nije uspelo (proveri dozvolu ili mrežu).');
        return;
      }
      showToast('Sačuvano');
      onChanged?.();
    });
  });

  /* Napomena */
  root.querySelectorAll('[data-pred-akt-nap]').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = Number(btn.getAttribute('data-pred-akt-nap'));
      const row = findRow(id);
      openNapomenaModal({
        title: 'Napomena za predmet',
        initial: row?.napomena || '',
        onConfirm: async text => {
          const nextAkt = !!row?.je_aktivan;
          const ok = await setPredmetAktivacija(id, nextAkt, text);
          if (ok == null) {
            showToast('Snimanje napomene nije uspelo.');
            return;
          }
          if (row) row.napomena = text;
          showToast('Sačuvano');
          onChanged?.();
        },
      });
    });
  });

  /* Prioritet toggle */
  root.querySelectorAll('[data-pred-prio-toggle]').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = Number(btn.getAttribute('data-pred-prio-toggle'));
      if (isPrioritet(id)) {
        removeFromPrioritet(id);
        const r = findRow(id);
        showToast(`Uklonjen iz prioriteta: ${r?.broj_predmeta || id}`);
      } else {
        const ok = addToPrioritet(id);
        if (!ok) {
          showToast('Lista prioriteta je puna (max 10). Ukloni neki pre nego što dodaš novi.');
          return;
        }
        const r = findRow(id);
        showToast(`⭐ Dodat u prioritet: ${r?.broj_predmeta || id}`);
      }
      onChanged?.();
    });
  });

  /* Prioritet gore/dole */
  root.querySelectorAll('[data-pred-prio-up]').forEach(btn => {
    btn.addEventListener('click', () => {
      movePrioritetUp(Number(btn.getAttribute('data-pred-prio-up')));
      onChanged?.();
    });
  });
  root.querySelectorAll('[data-pred-prio-down]').forEach(btn => {
    btn.addEventListener('click', () => {
      movePrioritetDown(Number(btn.getAttribute('data-pred-prio-down')));
      onChanged?.();
    });
  });
}
