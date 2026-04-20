/**
 * Modali — Nova lokacija, Brzo premeštanje (RPC loc_create_movement).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { canEdit } from '../../state/auth.js';
import {
  createLocation,
  fetchItemMovements,
  fetchLocations,
  locCreateMovement,
  updateLocation,
} from '../../services/lokacije.js';

const LOC_TYPES = [
  'WAREHOUSE',
  'RACK',
  'SHELF',
  'BIN',
  'PROJECT',
  'PRODUCTION',
  'ASSEMBLY',
  'SERVICE',
  'FIELD',
  'TRANSIT',
  'OFFICE',
  'TEMP',
  'SCRAPPED',
  'OTHER',
];

/* TRANSFER je prvi jer je najčešći slučaj u svakodnevnom radu;
 * INITIAL_PLACEMENT je eksplicitno drugačiji tok (samo za nove stavke). */
const MOVEMENT_TYPES = [
  'TRANSFER',
  'INITIAL_PLACEMENT',
  'ASSIGN_TO_PROJECT',
  'RETURN_FROM_PROJECT',
  'SEND_TO_SERVICE',
  'RETURN_FROM_SERVICE',
  'SEND_TO_FIELD',
  'RETURN_FROM_FIELD',
  'SCRAP',
  'CORRECTION',
  'INVENTORY_ADJUSTMENT',
];

/* Whitelist ERP tabela kojima se može referencirati stavka. Proširiti po potrebi;
 * ekvivalentna validacija ne postoji u SQL-u jer se payload trenutno ne verifikuje. */
const ITEM_REF_TABLES = [
  { value: 'parts', label: 'parts — delovi' },
  { value: 'tools', label: 'tools — alati' },
  { value: 'machines', label: 'machines — mašine' },
  { value: 'consumables', label: 'consumables — potrošni' },
  { value: 'assemblies', label: 'assemblies — sklopovi' },
  { value: 'other', label: 'other — ostalo' },
];

/**
 * Ne-breaking space indent zavisno od `depth`.
 * @param {number} depth
 */
function indentFor(depth) {
  const n = Math.max(0, Math.min(Number(depth) || 0, 12));
  return n === 0 ? '' : '\u00a0\u00a0'.repeat(n) + '· ';
}

/**
 * HTML <option> redovi za dropdown sa indentiranim prikazom hijerarhije.
 * Ulazna lista je već sortirana po `path_cached` (fetchLocations order).
 * @param {object[]} locs
 * @param {{ blankLabel?: string, includeBlank?: boolean }} [opts]
 */
function locationOptionsHtml(locs, { blankLabel = '', includeBlank = true } = {}) {
  const rows = [];
  if (includeBlank) rows.push(`<option value="">${escHtml(blankLabel)}</option>`);
  for (const l of locs) {
    const indent = indentFor(l.depth);
    const label = `${indent}${l.location_code || ''} — ${l.name || ''}`;
    rows.push(`<option value="${escHtml(String(l.id))}">${escHtml(label)}</option>`);
  }
  return rows.join('');
}

/**
 * Registruje Esc-key listener koji zatvara modal, i vraća cleanup funkciju.
 * @param {() => void} onClose
 */
function bindEscClose(onClose) {
  const handler = ev => {
    if (ev.key === 'Escape') {
      ev.preventDefault();
      onClose();
    }
  };
  document.addEventListener('keydown', handler);
  return () => document.removeEventListener('keydown', handler);
}

function movementErrMsg(code) {
  const m = {
    missing_fields: 'Popuni sva obavezna polja.',
    bad_to_location: 'Odredišna lokacija nije validna ili nije aktivna.',
    bad_to_uuid: 'Odredišna lokacija ima neispravan ID.',
    bad_from_uuid: 'Polazna lokacija ima neispravan ID.',
    bad_movement_type: 'Neispravan tip pokreta.',
    already_placed: 'Stavka već ima lokaciju — koristi TRANSFER ili drugi tip (ne INITIAL_PLACEMENT).',
    no_current_placement: 'Nema trenutnog placement-a — izaberi INITIAL_PLACEMENT.',
    from_mismatch: 'Polazna lokacija ne odgovara trenutnoj.',
    not_authenticated: 'Prijavi se ponovo.',
  };
  return m[code] || code || 'Operacija nije uspela.';
}

function removeModal(id) {
  document.getElementById(id)?.remove();
}

/**
 * Pravi shell modala sa loading sadržajem. Vraća elemente za kasniju zamenu.
 * @param {{ id: string, title: string, subtitle?: string }} params
 */
function createModalShell({ id, title, subtitle = '' }) {
  removeModal(id);
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay" id="${id}" role="dialog" aria-labelledby="${id}Title" aria-modal="true">
      <div class="kadr-modal">
        <div class="kadr-modal-title" id="${id}Title">${escHtml(title)}</div>
        ${subtitle ? `<div class="kadr-modal-subtitle">${subtitle}</div>` : ''}
        <div class="kadr-modal-body" data-modal-body>
          <p class="loc-muted" style="padding:24px 0; text-align:center">Učitavam lokacije…</p>
        </div>
      </div>
    </div>`;
  document.body.appendChild(wrap.firstElementChild);
  const overlay = document.getElementById(id);
  return {
    overlay,
    body: overlay.querySelector('[data-modal-body]'),
  };
}

/**
 * Modal za kreiranje ili izmenu master lokacije.
 * @param {{ existing?: object|null, onSuccess?: () => void }} [opts]
 */
export function openLocationModal({ existing = null, onSuccess } = {}) {
  if (!canEdit()) {
    showToast('⚠ Samo admin / LeadPM / PM može da menja lokacije');
    return;
  }

  const isEdit = !!existing;
  const modalId = 'locModalNewLoc';
  const { overlay, body } = createModalShell({
    id: modalId,
    title: isEdit ? 'Izmeni lokaciju' : 'Nova lokacija',
    subtitle: isEdit
      ? 'Šifra se ne menja (koristi se u sync-u). Ostala polja su ažurabilna.'
      : 'Master zapis u <code>loc_locations</code> (RLS: admin / LeadPM / PM).',
  });

  let unbindEsc = null;
  const close = () => {
    if (unbindEsc) {
      unbindEsc();
      unbindEsc = null;
    }
    removeModal(modalId);
  };
  unbindEsc = bindEscClose(close);
  overlay.addEventListener('click', ev => {
    if (ev.target === overlay) close();
  });

  (async () => {
    const locs = await fetchLocations({ activeOnly: false });
    if (!Array.isArray(locs)) {
      close();
      showToast('⚠ Ne mogu da učitam lokacije');
      return;
    }

    /* Pri izmeni, izbacujemo samu lokaciju i sve njene potomke iz parent dropdown-a
     * (nema dobrog načina da otkrijemo potomke iz flat liste bez dodatnog upita,
     * ali prosto izbacivanje samog ID-ja pokriva 99% slučajeva — ciklus hvata
     * SQL trigger loc_locations_guard_and_path). */
    const parentChoices = isEdit ? locs.filter(l => l.id !== existing.id) : locs;
    const parentOpts = locationOptionsHtml(parentChoices, {
      includeBlank: true,
      blankLabel: '— bez roditelja —',
    });
    const selectedParent = isEdit ? existing.parent_id || '' : '';
    const selectedType = isEdit ? existing.location_type : LOC_TYPES[0];

    const typeOpts = LOC_TYPES.map(
      t => `<option value="${t}"${t === selectedType ? ' selected' : ''}>${escHtml(t)}</option>`,
    ).join('');

    body.innerHTML = `
      <div class="kadr-modal-err" id="locModalNewLocErr"></div>
      <form id="locFormNewLoc">
        <div class="emp-form-grid">
          <div class="emp-field">
            <label for="locNewCode">Šifra *</label>
            <input type="text" id="locNewCode" required maxlength="80" placeholder="npr. M2-R1-P3" autocomplete="off"
              value="${escHtml(isEdit ? existing.location_code || '' : '')}"
              ${isEdit ? 'readonly' : ''}>
          </div>
          <div class="emp-field col-full">
            <label for="locNewName">Naziv *</label>
            <input type="text" id="locNewName" required maxlength="200" placeholder="Kratak naziv lokacije"
              value="${escHtml(isEdit ? existing.name || '' : '')}">
          </div>
          <div class="emp-field">
            <label for="locNewType">Tip *</label>
            <select id="locNewType" required>${typeOpts}</select>
          </div>
          <div class="emp-field">
            <label for="locNewParent">Roditelj</label>
            <select id="locNewParent">${parentOpts}</select>
          </div>
        </div>
        <div class="kadr-modal-actions">
          <button type="button" class="btn" id="locNewLocCancel">Otkaži</button>
          <button type="submit" class="btn btn-primary" id="locNewLocSubmit">Sačuvaj</button>
        </div>
      </form>`;

    const errEl = overlay.querySelector('#locModalNewLocErr');
    const form = overlay.querySelector('#locFormNewLoc');
    const submitBtn = overlay.querySelector('#locNewLocSubmit');
    const parentSel = overlay.querySelector('#locNewParent');

    if (selectedParent) parentSel.value = String(selectedParent);

    overlay.querySelector('#locNewLocCancel').addEventListener('click', close);
    (isEdit ? overlay.querySelector('#locNewName') : overlay.querySelector('#locNewCode')).focus();

    form.addEventListener('submit', async ev => {
      ev.preventDefault();
      errEl.textContent = '';
      const name = overlay.querySelector('#locNewName').value.trim();
      const location_type = overlay.querySelector('#locNewType').value;
      const parent_id = parentSel.value || null;

      if (isEdit) {
        if (!name) {
          errEl.textContent = 'Naziv je obavezan.';
          return;
        }
        submitBtn.disabled = true;
        const row = await updateLocation(existing.id, { name, location_type, parent_id });
        submitBtn.disabled = false;
        if (!row) {
          errEl.textContent = 'Izmena nije uspela (možda ciklus u hijerarhiji ili RLS).';
          return;
        }
        showToast('✓ Lokacija izmenjena');
      } else {
        const code = overlay.querySelector('#locNewCode').value.trim();
        if (!code || !name) {
          errEl.textContent = 'Šifra i naziv su obavezni.';
          return;
        }
        submitBtn.disabled = true;
        const row = await createLocation({ location_code: code, name, location_type, parent_id });
        submitBtn.disabled = false;
        if (!row) {
          errEl.textContent = 'Snimanje nije uspelo (duplikat šifre ili RLS).';
          return;
        }
        showToast('✓ Lokacija kreirana');
      }
      close();
      onSuccess?.();
    });
  })();
}

/* Wrapper — zadržava staro ime radi kompatibilnosti sa postojećim pozivima. */
export function openNewLocationModal(opts = {}) {
  return openLocationModal({ existing: null, ...opts });
}

/**
 * Modal sa istorijom premeštanja za jednu stavku.
 * @param {{ itemRefTable: string, itemRefId: string }} params
 */
export function openItemHistoryModal({ itemRefTable, itemRefId }) {
  if (!itemRefTable || !itemRefId) {
    showToast('⚠ Nedostaje referenca stavke');
    return;
  }

  const modalId = 'locModalHistory';
  const { overlay, body } = createModalShell({
    id: modalId,
    title: 'Istorija premeštanja',
    subtitle: `<code>${escHtml(itemRefTable)}</code> · <code>${escHtml(itemRefId)}</code>`,
  });

  let unbindEsc = null;
  const close = () => {
    if (unbindEsc) {
      unbindEsc();
      unbindEsc = null;
    }
    removeModal(modalId);
  };
  unbindEsc = bindEscClose(close);
  overlay.addEventListener('click', ev => {
    if (ev.target === overlay) close();
  });

  (async () => {
    const [movs, locs] = await Promise.all([
      fetchItemMovements(itemRefTable, itemRefId, 200),
      fetchLocations({ activeOnly: false }),
    ]);

    if (!Array.isArray(movs)) {
      body.innerHTML = `<p class="loc-warn">Učitavanje istorije neuspešno.</p>
        <div class="kadr-modal-actions"><button type="button" class="btn" id="locHistClose">Zatvori</button></div>`;
      overlay.querySelector('#locHistClose').addEventListener('click', close);
      return;
    }

    const locIdx = new Map(
      Array.isArray(locs) ? locs.filter(l => l?.id).map(l => [l.id, l]) : [],
    );
    const locBrief = id => {
      if (!id) return '<span class="loc-muted">—</span>';
      const l = locIdx.get(id);
      return l
        ? `<span class="loc-code-strong">${escHtml(l.location_code || '')}</span> · ${escHtml(l.name || '')}`
        : `<span class="loc-path">${escHtml(String(id).slice(0, 8))}…</span>`;
    };

    const rowsHtml = movs.length
      ? movs
          .map(m => {
            const ts = (m.moved_at || '').replace('T', ' ').slice(0, 16);
            return `<tr>
              <td class="loc-path">${escHtml(ts)}</td>
              <td><span class="loc-mov-type">${escHtml(m.movement_type || '')}</span></td>
              <td>${locBrief(m.from_location_id)}</td>
              <td>${locBrief(m.to_location_id)}</td>
              <td class="loc-path">${escHtml((m.note || m.movement_reason || '').slice(0, 120))}</td>
            </tr>`;
          })
          .join('')
      : '<tr><td colspan="5" class="loc-muted">Nema zabeleženih premeštanja.</td></tr>';

    body.innerHTML = `
      <div class="loc-table-wrap" style="max-height:60vh">
        <table class="loc-table">
          <thead><tr><th>Vreme</th><th>Tip</th><th>Odakle</th><th>Dokle</th><th>Napomena</th></tr></thead>
          <tbody>${rowsHtml}</tbody>
        </table>
      </div>
      <div class="kadr-modal-actions">
        <button type="button" class="btn" id="locHistClose">Zatvori</button>
      </div>`;

    overlay.querySelector('#locHistClose').addEventListener('click', close);
  })();
}

/**
 * Toggle `is_active` na postojećoj lokaciji (RLS: admin / leadpm / pm).
 * @param {object} row lokacija koju menjamo
 * @param {{ onSuccess?: () => void }} [opts]
 */
export async function toggleLocationActive(row, { onSuccess } = {}) {
  if (!canEdit()) {
    showToast('⚠ Samo admin / LeadPM / PM može da (de)aktivira lokacije');
    return;
  }
  const next = !row.is_active;
  const verb = next ? 'aktivirati' : 'deaktivirati';
  const msg = `Da li želiš da ${verb} lokaciju "${row.location_code} — ${row.name}"?`;
  if (!window.confirm(msg)) return;

  const updated = await updateLocation(row.id, { is_active: next });
  if (!updated) {
    showToast('⚠ Izmena statusa nije uspela');
    return;
  }
  showToast(next ? '✓ Lokacija aktivirana' : '✓ Lokacija deaktivirana');
  onSuccess?.();
}

/**
 * @param {{ onSuccess?: () => void }} [opts]
 */
export function openQuickMoveModal({ onSuccess } = {}) {
  const modalId = 'locModalQuickMove';
  const { overlay, body } = createModalShell({
    id: modalId,
    title: 'Brzo premeštanje',
    subtitle:
      'Poziva RPC <code>loc_create_movement</code>. Za novu stavku koristi <strong>INITIAL_PLACEMENT</strong>; za postojeći placement <strong>TRANSFER</strong> ili drugi tip.',
  });

  let unbindEsc = null;
  const close = () => {
    if (unbindEsc) {
      unbindEsc();
      unbindEsc = null;
    }
    removeModal(modalId);
  };
  unbindEsc = bindEscClose(close);
  overlay.addEventListener('click', ev => {
    if (ev.target === overlay) close();
  });

  (async () => {
    const locs = await fetchLocations();
    if (!Array.isArray(locs)) {
      close();
      showToast('⚠ Ne mogu da učitam lokacije');
      return;
    }

    const toOpts = locationOptionsHtml(locs, {
      includeBlank: true,
      blankLabel: '— izaberi odredište —',
    });
    const movOpts = MOVEMENT_TYPES.map(t => `<option value="${t}">${escHtml(t)}</option>`).join('');
    const tableOpts = ITEM_REF_TABLES.map(
      t => `<option value="${escHtml(t.value)}">${escHtml(t.label)}</option>`,
    ).join('');

    body.innerHTML = `
      <div class="kadr-modal-err" id="locModalQuickMoveErr"></div>
      <form id="locFormQuickMove">
        <div class="emp-form-grid">
          <div class="emp-field">
            <label for="locQmTable">Ref. tabela *</label>
            <select id="locQmTable" required>${tableOpts}</select>
          </div>
          <div class="emp-field">
            <label for="locQmItemId">ID stavke *</label>
            <input type="text" id="locQmItemId" required maxlength="200" placeholder="ERP / sync ID" autocomplete="off">
          </div>
          <div class="emp-field col-full">
            <label for="locQmTo">Odredišna lokacija *</label>
            <select id="locQmTo" required>${toOpts}</select>
          </div>
          <div class="emp-field">
            <label for="locQmType">Tip pokreta *</label>
            <select id="locQmType" required>${movOpts}</select>
          </div>
          <div class="emp-field col-full">
            <label for="locQmNote">Napomena</label>
            <textarea id="locQmNote" maxlength="500" rows="2" placeholder="Opciono"></textarea>
          </div>
        </div>
        <div class="kadr-modal-actions">
          <button type="button" class="btn" id="locQmCancel">Otkaži</button>
          <button type="submit" class="btn btn-primary" id="locQmSubmit">Izvrši</button>
        </div>
      </form>`;

    const errEl = overlay.querySelector('#locModalQuickMoveErr');
    const submitBtn = overlay.querySelector('#locQmSubmit');

    overlay.querySelector('#locQmCancel').addEventListener('click', close);
    overlay.querySelector('#locQmItemId').focus();

    overlay.querySelector('#locFormQuickMove').addEventListener('submit', async ev => {
      ev.preventDefault();
      errEl.textContent = '';
      const item_ref_table = overlay.querySelector('#locQmTable').value.trim();
      const item_ref_id = overlay.querySelector('#locQmItemId').value.trim();
      const to_location_id = overlay.querySelector('#locQmTo').value;
      const movement_type = overlay.querySelector('#locQmType').value;
      const note = overlay.querySelector('#locQmNote').value.trim();
      if (!item_ref_table || !item_ref_id || !to_location_id || !movement_type) {
        errEl.textContent = 'Popuni obavezna polja.';
        return;
      }
      submitBtn.disabled = true;
      const res = await locCreateMovement({
        item_ref_table,
        item_ref_id,
        to_location_id,
        movement_type,
        note: note || undefined,
      });
      submitBtn.disabled = false;
      if (!res) {
        errEl.textContent = 'Server nije odgovorio.';
        return;
      }
      if (!res.ok) {
        errEl.textContent = movementErrMsg(res.error);
        return;
      }
      showToast('✓ Premeštanje zabeleženo');
      close();
      onSuccess?.();
    });
  })();
}
