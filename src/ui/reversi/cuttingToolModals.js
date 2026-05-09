/**
 * Reversi — modali za rezni alat (Sprint RZ-2):
 *   - openAddCuttingToolModal: nova/izmena šifre + početno stanje u magacinu
 *   - openCuttingToolDetailsModal: detalji + stanje po lokacijama
 *
 * Štampa nalepnice: helper printCuttingToolLabel poziva TSPL2 helper i mrežni proxy.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  fetchMachines,
  insertCuttingTool,
  updateCuttingTool,
  fetchCuttingToolStockDetails,
  fetchActiveLocations,
  getMagacinLocationId,
  seedCuttingToolStock,
} from '../../services/reversiService.js';
import { buildTspCuttingToolLabelProgram } from '../../lib/tspl2.js';
import { dispatchOptionalNetworkLabelPrint } from '../lokacije/labelsPrint.js';

const KLASE = ['glodalo', 'burgija', 'pločica', 'držač', 'narez', 'urezna', 'razvrtač', 'ostalo'];

function modalShell(title, bodyHtml, footerHtml, id) {
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay rev-modal-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal rev-modal">
        <div class="kadr-modal-header">
          <h2 id="${id}Title">${escHtml(title)}</h2>
          <button type="button" class="kadr-modal-close" data-rev-close aria-label="Zatvori">×</button>
        </div>
        <div class="kadr-modal-body rev-modal-body">${bodyHtml}</div>
        <div class="kadr-modal-footer rev-modal-footer">${footerHtml}</div>
      </div>
    </div>`;
  return wrap.firstElementChild;
}

function attachClose(root, onClose) {
  root.querySelector('[data-rev-close]')?.addEventListener('click', () => {
    root.remove();
    onClose?.();
  });
  root.addEventListener('click', (e) => {
    if (e.target === root) {
      root.remove();
      onClose?.();
    }
  });
}

/**
 * Modal za dodavanje nove šifre reznog alata. Barkod se generiše u DB triggerom (RZN-NNNNNN).
 * @param {{ onSuccess?: (created: object) => void, tool?: object|null }} opts
 */
export function openAddCuttingToolModal(opts = {}) {
  const editing = !!opts.tool;
  const id = `revCtsNew_${Date.now()}`;
  const state = {
    oznaka: opts.tool?.oznaka || '',
    naziv: opts.tool?.naziv || '',
    klasa: opts.tool?.klasa || '',
    klasaOther: '',
    compatible_machine_codes: Array.isArray(opts.tool?.compatible_machine_codes)
      ? [...opts.tool.compatible_machine_codes]
      : [],
    unit: opts.tool?.unit || 'kom',
    napomena: opts.tool?.napomena || '',
    min_stock_qty: opts.tool?.min_stock_qty != null ? String(opts.tool.min_stock_qty) : '0',
    machineSearch: '',
    machines: [],
    /* Inicijalni stock (samo na NEW, ne na edit) */
    initialQty: '',
    initialLocationId: '',
    locations: [],
  };

  const overlay = modalShell(
    editing ? 'Izmena šifre reznog alata' : 'Nova šifra reznog alata',
    `<div id="revCtsBody"></div>`,
    `<div id="revCtsFoot"></div>`,
    id,
  );
  document.body.appendChild(overlay);
  attachClose(overlay, opts.onClose);

  let machinesLoaded = false;
  let mDeb = null;

  async function loadMachines(q) {
    const r = await fetchMachines({ search: q });
    state.machines = r.ok && Array.isArray(r.data) ? r.data : [];
    machinesLoaded = true;
  }

  async function loadLocationsAndDefault() {
    if (editing) return;
    const [locRes, magId] = await Promise.all([fetchActiveLocations(), getMagacinLocationId()]);
    state.locations = locRes.ok && Array.isArray(locRes.data) ? locRes.data : [];
    if (magId && !state.initialLocationId) state.initialLocationId = magId;
  }

  function paint() {
    const body = overlay.querySelector('#revCtsBody');
    const foot = overlay.querySelector('#revCtsFoot');
    if (!body || !foot) return;

    const klasaInList = KLASE.includes(state.klasa);
    const klasaSelectVal = klasaInList ? state.klasa : (state.klasa ? '__other' : '');
    if (!klasaInList && state.klasa) state.klasaOther = state.klasa;

    const machineChips = state.compatible_machine_codes
      .map(
        (m) =>
          `<span class="rev-chip" data-rev-mchip="${escHtml(m)}">${escHtml(m)} <button type="button" class="rev-chip-x" data-rev-mrm="${escHtml(m)}" aria-label="Ukloni">×</button></span>`,
      )
      .join('');

    const matches = state.machines
      .filter((m) => !state.compatible_machine_codes.includes(m.rj_code))
      .slice(0, 12);

    body.innerHTML = `
      <div class="rev-form-grid">
        <label>Oznaka (interni naziv)
          <input type="text" id="revCtsOznaka" class="input" value="${escHtml(state.oznaka)}" placeholder="npr. GL-D12-HSS"/>
        </label>
        <label>Naziv / opis
          <input type="text" id="revCtsNaziv" class="input" value="${escHtml(state.naziv)}" placeholder="npr. Glodalo HSS Ø12 4-zubo"/>
        </label>
        <label>Klasa
          <select id="revCtsKlasa" class="rev-select">
            <option value="" ${klasaSelectVal === '' ? 'selected' : ''}>— izaberi —</option>
            ${KLASE.map(
              (k) => `<option value="${escHtml(k)}" ${klasaSelectVal === k ? 'selected' : ''}>${escHtml(k)}</option>`,
            ).join('')}
            <option value="__other" ${klasaSelectVal === '__other' ? 'selected' : ''}>drugo…</option>
          </select>
        </label>
        ${
          klasaSelectVal === '__other'
            ? `<label>Slobodan upis klase
                  <input type="text" id="revCtsKlasaOther" class="input" value="${escHtml(state.klasaOther)}"/>
                </label>`
            : ''
        }
        <label>Jedinica mere
          <select id="revCtsUnit" class="rev-select">
            ${['kom', 'set', 'pak'].map((u) => `<option value="${u}" ${state.unit === u ? 'selected' : ''}>${u}</option>`).join('')}
          </select>
        </label>
        <fieldset class="rev-fieldset">
          <legend>Kompatibilne mašine</legend>
          <div class="rev-chip-row" id="revCtsMChips">${machineChips || '<span class="rev-muted">— bez ograničenja —</span>'}</div>
          <input type="text" id="revCtsMSearch" class="input" placeholder="Šifra ili naziv mašine…" value="${escHtml(state.machineSearch)}"/>
          <div class="rev-autocomplete-list">
            ${matches
              .map(
                (m) =>
                  `<button type="button" class="rev-ac-item" data-rev-madd="${escHtml(m.rj_code)}">${escHtml(m.rj_code)} <span class="rev-muted">${escHtml(m.name || '')}</span></button>`,
              )
              .join('')}
          </div>
        </fieldset>
        <label>Minimalna zaliha (upozorenje)
          <input type="number" id="revCtsMinSt" class="input" min="0" step="1" value="${escHtml(String(state.min_stock_qty))}"/>
        </label>
        <label>Napomena
          <textarea id="revCtsNote" rows="2" class="input">${escHtml(state.napomena)}</textarea>
        </label>
        ${
          editing
            ? ''
            : `
        <fieldset class="rev-fieldset">
          <legend>Početno stanje (opciono)</legend>
          <div class="rev-form-grid">
            <label>Količina
              <input type="number" id="revCtsInitQty" class="input" min="0" step="1" placeholder="0" value="${escHtml(String(state.initialQty || ''))}"/>
            </label>
            <label>Lokacija
              <select id="revCtsInitLoc" class="rev-select">
                <option value="">— izaberi —</option>
                ${state.locations
                  .map(
                    (l) =>
                      `<option value="${escHtml(l.id)}" ${state.initialLocationId === l.id ? 'selected' : ''}>${escHtml(l.location_code)} ${escHtml(l.name || '')}</option>`,
                  )
                  .join('')}
              </select>
            </label>
          </div>
          <p class="rev-muted" style="font-size:11px;margin:4px 0 0">Ako uneseš količinu, biće odmah upisana u stanje na izabranoj lokaciji (default: ALAT-MAG-01).</p>
        </fieldset>`
        }
      </div>`;

    foot.innerHTML = `
      <button type="button" class="btn" data-rev-close>Otkaži</button>
      <button type="button" class="btn btn-primary" id="revCtsSave">${editing ? 'Sačuvaj izmene' : 'Sačuvaj'}</button>`;

    body.querySelector('#revCtsOznaka')?.addEventListener('input', (e) => {
      state.oznaka = e.target.value;
    });
    body.querySelector('#revCtsNaziv')?.addEventListener('input', (e) => {
      state.naziv = e.target.value;
    });
    body.querySelector('#revCtsKlasa')?.addEventListener('change', (e) => {
      const v = e.target.value;
      if (v === '__other') {
        state.klasa = state.klasaOther || '';
      } else {
        state.klasa = v;
      }
      paint();
    });
    body.querySelector('#revCtsKlasaOther')?.addEventListener('input', (e) => {
      state.klasaOther = e.target.value;
      state.klasa = e.target.value;
    });
    body.querySelector('#revCtsUnit')?.addEventListener('change', (e) => {
      state.unit = e.target.value;
    });
    body.querySelector('#revCtsMinSt')?.addEventListener('input', (e) => {
      state.min_stock_qty = e.target.value;
    });
    body.querySelector('#revCtsNote')?.addEventListener('input', (e) => {
      state.napomena = e.target.value;
    });
    body.querySelector('#revCtsInitQty')?.addEventListener('input', (e) => {
      state.initialQty = e.target.value;
    });
    body.querySelector('#revCtsInitLoc')?.addEventListener('change', (e) => {
      state.initialLocationId = e.target.value;
    });
    body.querySelector('#revCtsMSearch')?.addEventListener('input', (e) => {
      state.machineSearch = e.target.value;
      clearTimeout(mDeb);
      mDeb = setTimeout(async () => {
        await loadMachines(state.machineSearch);
        paint();
      }, 250);
    });
    body.querySelectorAll('[data-rev-madd]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const code = btn.getAttribute('data-rev-madd');
        if (code && !state.compatible_machine_codes.includes(code)) {
          state.compatible_machine_codes.push(code);
          paint();
        }
      });
    });
    body.querySelectorAll('[data-rev-mrm]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const code = btn.getAttribute('data-rev-mrm');
        state.compatible_machine_codes = state.compatible_machine_codes.filter((x) => x !== code);
        paint();
      });
    });

    foot.querySelector('#revCtsSave')?.addEventListener('click', async () => {
      const oznaka = state.oznaka.trim();
      const naziv = state.naziv.trim();
      if (!oznaka || !naziv) {
        showToast('Oznaka i naziv su obavezni');
        return;
      }
      const payload = {
        oznaka,
        naziv,
        klasa: state.klasa.trim() || null,
        compatible_machine_codes: state.compatible_machine_codes,
        unit: state.unit || 'kom',
        napomena: state.napomena.trim() || null,
        status: opts.tool?.status || 'active',
        min_stock_qty: Math.max(0, Math.floor(Number(state.min_stock_qty) || 0)),
      };
      const btn = foot.querySelector('#revCtsSave');
      btn.disabled = true;
      btn.textContent = 'Čuvam…';
      try {
        if (editing) {
          const r = await updateCuttingTool(opts.tool.id, payload);
          if (!r.ok) {
            showToast(`Greška: ${r.error}`);
            return;
          }
          showToast('Šifra ažurirana');
          opts.onSuccess?.(r.data);
        } else {
          const r = await insertCuttingTool(payload);
          if (!r.ok) {
            showToast(`Greška: ${r.error}`);
            return;
          }
          /* Inicijalni stock — ako je uneta količina i lokacija */
          const initQty = Math.max(0, Math.floor(Number(state.initialQty) || 0));
          if (initQty > 0 && state.initialLocationId) {
            const seed = await seedCuttingToolStock(r.data.id, state.initialLocationId, initQty);
            if (!seed.ok) {
              showToast(`Šifra dodata: ${r.data.barcode}, ali seed je pao: ${seed.error}`);
            } else {
              showToast(`✓ Šifra ${r.data.barcode} + ${initQty} ${payload.unit} u magacinu`);
            }
          } else {
            showToast(`Šifra dodata: ${r.data.barcode}`);
          }
          opts.onSuccess?.(r.data);
        }
        overlay.remove();
      } finally {
        btn.disabled = false;
      }
    });
  }

  paint();
  void Promise.all([loadMachines(''), loadLocationsAndDefault()]).then(() => {
    paint();
  });
}

/**
 * Modal sa detaljima šifre + stanje po lokacijama.
 * @param {{ tool: object, onClose?: () => void }} opts
 */
export function openCuttingToolDetailsModal(opts = {}) {
  const t = opts.tool;
  if (!t?.id) return;
  const id = `revCtsDet_${Date.now()}`;

  const overlay = modalShell(
    `Šifra reznog alata: ${t.oznaka}`,
    `<div id="revCtsDetBody"><p class="rev-muted">Učitavam stanje…</p></div>`,
    `<button type="button" class="btn" data-rev-close>Zatvori</button>`,
    id,
  );
  document.body.appendChild(overlay);
  attachClose(overlay, opts.onClose);

  void (async () => {
    const r = await fetchCuttingToolStockDetails(t.id);
    const stock = r.ok && Array.isArray(r.data) ? r.data : [];
    const body = overlay.querySelector('#revCtsDetBody');
    if (!body) return;
    const meta = `
      <dl class="rev-meta-grid">
        <dt>Barkod</dt><dd class="rev-mono">${escHtml(t.barcode || '')}</dd>
        <dt>Naziv</dt><dd>${escHtml(t.naziv || '')}</dd>
        <dt>Klasa</dt><dd>${escHtml(t.klasa || '—')}</dd>
        <dt>Jedinica</dt><dd>${escHtml(t.unit || 'kom')}</dd>
        <dt>Kompatibilne mašine</dt><dd>${(t.compatible_machine_codes || []).map(escHtml).join(', ') || '<span class="rev-muted">bez ograničenja</span>'}</dd>
        <dt>Status</dt><dd>${escHtml(t.status || 'active')}</dd>
        ${t.napomena ? `<dt>Napomena</dt><dd>${escHtml(t.napomena)}</dd>` : ''}
      </dl>`;
    const stockHtml = stock.length
      ? `<table class="rev-data-table"><thead><tr><th>Lokacija</th><th>Tip</th><th class="rev-th-num">Količina</th></tr></thead><tbody>${stock
          .map((s) => {
            const loc = Array.isArray(s.loc_locations) ? s.loc_locations[0] : s.loc_locations;
            const code = loc?.location_code || '—';
            const name = loc?.name || '';
            const type = loc?.location_type || '';
            return `<tr><td><span class="rev-mono">${escHtml(code)}</span> <span class="rev-muted">${escHtml(name)}</span></td><td>${escHtml(type)}</td><td class="rev-td-num">${escHtml(String(Number(s.on_hand_qty) || 0))}</td></tr>`;
          })
          .join('')}</tbody></table>`
      : '<p class="rev-muted">Nema balansa ni na jednoj lokaciji.</p>';
    body.innerHTML = `${meta}<h3 class="rev-h3">Stanje po lokacijama</h3>${stockHtml}`;
  })();
}

/**
 * Štampa jednu nalepnicu reznog alata kroz mrežni TSC proxy + browser fallback.
 * @param {object} tool red iz rev_cutting_tool_catalog
 * @param {number} [copies=1]
 * @returns {Promise<{ ok: boolean, reason?: string }>}
 */
export async function printCuttingToolLabel(tool, copies = 1) {
  if (!tool?.barcode) {
    showToast('Nema barkoda za štampu');
    return { ok: false, reason: 'no_barcode' };
  }
  let tspl2 = '';
  try {
    tspl2 = buildTspCuttingToolLabelProgram({
      barcode: tool.barcode,
      oznaka: tool.oznaka,
      naziv: tool.naziv,
      klasa: tool.klasa,
      compatible_machine_codes: tool.compatible_machine_codes || [],
      copies,
    });
  } catch (e) {
    console.error('[reversi/rezni] TSPL2 build', e);
    showToast(`Greška: ${e?.message || e}`);
    return { ok: false, reason: 'tspl2_build_failed' };
  }

  const res = await dispatchOptionalNetworkLabelPrint({
    mode: 'cutting_tool',
    payload: {
      tool: {
        id: tool.id,
        barcode: tool.barcode,
        oznaka: tool.oznaka,
        naziv: tool.naziv,
        klasa: tool.klasa,
      },
      copies,
      tspl2,
    },
  });

  if (res.ok) {
    showToast(`Nalepnica poslata štampaču (${copies}×)`);
    return { ok: true };
  }
  if (res.reason === 'no_proxy_url') {
    showToast('LAN proxy nije postavljen — koristi browser print');
    return { ok: false, reason: 'no_proxy_url' };
  }
  showToast(`Štampač nije dostupan: ${res.reason}`);
  return { ok: false, reason: res.reason };
}
