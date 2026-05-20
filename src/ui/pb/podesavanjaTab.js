/**
 * Podešavanja PB — admin: notifikacije + kategorije saveta.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { getPbNotifConfig, updatePbNotifConfig } from '../../services/pb.js';
import {
  listAllEngTipCategoriesAdmin,
  listEngTipCategories,
  upsertEngTipCategory,
  deleteEngTipCategory,
} from '../../services/pbEngTips.js';
import { setEngTipCategories } from '../../state/pbEngTips.js';

function parseEmails(s) {
  return String(s || '')
    .split(/[,;\s]+/)
    .map(x => x.trim())
    .filter(Boolean);
}

async function syncSavetiCategoryChips() {
  try {
    const active = await listEngTipCategories();
    setEngTipCategories(active);
  } catch (err) {
    console.warn('[pb] syncSavetiCategoryChips', err);
  }
}

/**
 * @param {HTMLElement} root
 * @param {{ onSaved?: () => void }} ctx
 */
export async function renderPbPodesavanja(root, ctx) {
  const cfg = await getPbNotifConfig();
  if (!cfg) {
    root.innerHTML = '<p class="pb-muted">Konfiguracija nije dostupna.</p>';
    return;
  }

  let tipCategories = [];

  function paintNotif() {
    const emails = Array.isArray(cfg.email_recipients) ? cfg.email_recipients : [];
    return `
      <section class="pb-settings">
        <h3 class="pb-section-title">Email notifikacije (Projektni biro)</h3>
        <div class="pb-settings-grid">
          <label class="pb-check"><input type="checkbox" id="pbCfgEn" ${cfg.enabled ? 'checked' : ''} /> Notifikacije uključene</label>
          <label class="pb-field"><span>Upozorenje pred rok (dana)</span>
            <input type="number" id="pbCfgDw" min="1" max="30" value="${Number(cfg.deadline_warning_days) || 3}" />
          </label>
          <label class="pb-field"><span>Prag preopterećenosti (%)</span>
            <input type="number" id="pbCfgOl" min="50" max="200" value="${Number(cfg.overload_threshold_pct) || 100}" />
          </label>
          <label class="pb-field pb-settings-span2"><span>Email primaoci (zarez ili novi red)</span>
            <textarea id="pbCfgEm" rows="3" class="pb-textarea-lg">${escHtml(emails.join(', '))}</textarea>
          </label>
          <label class="pb-check"><input type="checkbox" id="pbCfgNb" ${cfg.notify_on_blocked ? 'checked' : ''} /> Blokirani zadaci</label>
          <label class="pb-check"><input type="checkbox" id="pbCfgNo" ${cfg.notify_on_overload ? 'checked' : ''} /> Preopterećenost</label>
          <label class="pb-check"><input type="checkbox" id="pbCfgNw" ${cfg.notify_on_deadline_warning ? 'checked' : ''} /> Rok uskoro</label>
          <label class="pb-check"><input type="checkbox" id="pbCfgNd" ${cfg.notify_on_deadline_overdue ? 'checked' : ''} /> Kašnjenje roka</label>
          <label class="pb-check"><input type="checkbox" id="pbCfgNe" ${cfg.notify_on_no_engineer ? 'checked' : ''} /> Bez inženjera (uskoro početak)</label>
        </div>
        <h3 class="pb-section-title pb-settings-section-gap">Tihi sati i digest</h3>
        <p class="pb-muted pb-settings-hint">
          Tihi sati: notifikacije se zadržavaju do kraja prozora (npr. 22:00 → 06:00 ne šalje noću).
          Digest: više pending poruka istog primaoca u jednom mejlu (Edge function obrađuje).
        </p>
        <div class="pb-settings-grid">
          <label class="pb-field"><span>Tihi sati — početak</span>
            <input type="time" id="pbCfgQs" value="${escHtml(String(cfg.quiet_hours_start || '').slice(0, 5))}" />
          </label>
          <label class="pb-field"><span>Tihi sati — kraj</span>
            <input type="time" id="pbCfgQe" value="${escHtml(String(cfg.quiet_hours_end || '').slice(0, 5))}" />
          </label>
          <label class="pb-check pb-settings-span2"><input type="checkbox" id="pbCfgDm" ${cfg.digest_mode ? 'checked' : ''} /> Grupisi poruke (digest mode)</label>
        </div>
        <div class="pb-modal-actions">
          <button type="button" class="btn btn-primary" id="pbCfgSave">Sačuvaj</button>
        </div>
      </section>`;
  }

  function paintTipCatForm(editRow) {
    const r = editRow || {};
    const isEdit = !!r.id;
    return `
      <form class="pb-eng-tip-cat-form" id="pbTipCatForm">
        <input type="hidden" id="pbTipCatId" value="${escHtml(r.id || '')}" />
        <div class="pb-eng-tip-cat-form-grid">
          <label class="pb-field"><span>Naziv *</span>
            <input type="text" id="pbTipCatNaziv" maxlength="80" value="${escHtml(r.naziv || '')}" required />
          </label>
          <label class="pb-field"><span>Ikona</span>
            <input type="text" id="pbTipCatIkona" maxlength="8" placeholder="🧱" value="${escHtml(r.ikona || '')}" />
          </label>
          <label class="pb-field"><span>Boja</span>
            <input type="color" id="pbTipCatBoja" value="${escHtml(r.boja || '#64748b')}" />
          </label>
          <label class="pb-field"><span>Redosled</span>
            <input type="number" id="pbTipCatRed" min="0" max="999" value="${Number(r.redosled) || 0}" />
          </label>
          <label class="pb-check pb-eng-tip-cat-active"><input type="checkbox" id="pbTipCatAktivna" ${r.je_aktivna !== false ? 'checked' : ''} /> Aktivna</label>
        </div>
        <div class="pb-modal-actions pb-eng-tip-cat-form-actions">
          <button type="submit" class="btn btn-primary">${isEdit ? 'Sačuvaj izmene' : 'Dodaj kategoriju'}</button>
          ${isEdit ? '<button type="button" class="btn btn-secondary" id="pbTipCatReset">Poništi</button>' : ''}
        </div>
      </form>`;
  }

  function paintTipCatTable() {
    if (!tipCategories.length) {
      return '<p class="pb-muted">Nema kategorija.</p>';
    }
    const rows = tipCategories.map(c => {
      const boja = c.boja || '#64748b';
      const inactive = c.je_aktivna === false ? ' <span class="pb-eng-tip-cat-inactive">neaktivna</span>' : '';
      return `<tr data-cat-row="${escHtml(c.id)}">
        <td class="pb-eng-tip-cat-ico">${escHtml(c.ikona || '—')}</td>
        <td><span class="pb-eng-tip-cat-swatch" style="background:${escHtml(boja)}"></span> ${escHtml(c.naziv)}${inactive}</td>
        <td class="pb-muted">${escHtml(c.slug || '')}</td>
        <td>${Number(c.redosled) || 0}</td>
        <td class="pb-eng-tip-cat-actions">
          <button type="button" class="btn btn-sm btn-secondary" data-cat-edit="${escHtml(c.id)}">Izmeni</button>
          <button type="button" class="btn btn-sm btn-danger-soft" data-cat-del="${escHtml(c.id)}">Obriši</button>
        </td>
      </tr>`;
    }).join('');
    return `<div class="pb-eng-tip-cat-table-wrap">
      <table class="pb-eng-tip-cat-table">
        <thead><tr><th></th><th>Naziv</th><th>Slug</th><th>Red</th><th></th></tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>`;
  }

  function paintTipCatsSection() {
    return `
      <section class="pb-settings pb-eng-tip-cat-admin">
        <h3 class="pb-section-title pb-settings-section-gap">Kategorije saveta</h3>
        <p class="pb-muted pb-settings-hint">Aktivne kategorije se prikazuju u tabu Saveti. Neaktivne ostaju u bazi ali se ne nude pri kreiranju saveta.</p>
        <div id="pbTipCatFormHost">${paintTipCatForm()}</div>
        <div id="pbTipCatTableHost">${paintTipCatTable()}</div>
      </section>`;
  }

  function paintAll() {
    root.innerHTML = paintNotif() + paintTipCatsSection();
    wireNotifSave();
    wireTipCats();
  }

  function wireNotifSave() {
    root.querySelector('#pbCfgSave')?.addEventListener('click', async () => {
      const qs = root.querySelector('#pbCfgQs')?.value || '';
      const qe = root.querySelector('#pbCfgQe')?.value || '';
      const payload = {
        enabled: root.querySelector('#pbCfgEn')?.checked ?? false,
        deadline_warning_days: Number(root.querySelector('#pbCfgDw')?.value) || 3,
        overload_threshold_pct: Number(root.querySelector('#pbCfgOl')?.value) || 100,
        email_recipients: parseEmails(root.querySelector('#pbCfgEm')?.value),
        notify_on_blocked: root.querySelector('#pbCfgNb')?.checked ?? false,
        notify_on_overload: root.querySelector('#pbCfgNo')?.checked ?? false,
        notify_on_deadline_warning: root.querySelector('#pbCfgNw')?.checked ?? false,
        notify_on_deadline_overdue: root.querySelector('#pbCfgNd')?.checked ?? false,
        notify_on_no_engineer: root.querySelector('#pbCfgNe')?.checked ?? false,
        quiet_hours_start: qs ? qs : null,
        quiet_hours_end: qe ? qe : null,
        digest_mode: root.querySelector('#pbCfgDm')?.checked ?? false,
      };
      const row = await updatePbNotifConfig(payload);
      if (row) {
        showToast('Sačuvano');
        Object.assign(cfg, row);
        ctx.onSaved?.();
      } else showToast('Čuvanje nije uspelo (samo admin)');
    });
  }

  function fillTipCatForm(row) {
    const host = root.querySelector('#pbTipCatFormHost');
    if (!host) return;
    host.innerHTML = paintTipCatForm(row || null);
    wireTipCatForm();
  }

  async function reloadTipCategories() {
    tipCategories = await listAllEngTipCategoriesAdmin();
    const tableHost = root.querySelector('#pbTipCatTableHost');
    if (tableHost) tableHost.innerHTML = paintTipCatTable();
    wireTipCatTable();
    await syncSavetiCategoryChips();
  }

  function readTipCatPayload() {
    const naziv = (root.querySelector('#pbTipCatNaziv')?.value || '').trim();
    if (!naziv) {
      const e = new Error('Naziv kategorije je obavezan');
      e.code = 'VALIDATION';
      throw e;
    }
    const id = (root.querySelector('#pbTipCatId')?.value || '').trim();
    return {
      id: id || undefined,
      naziv,
      ikona: (root.querySelector('#pbTipCatIkona')?.value || '').trim() || null,
      boja: root.querySelector('#pbTipCatBoja')?.value || null,
      redosled: Number(root.querySelector('#pbTipCatRed')?.value) || 0,
      je_aktivna: root.querySelector('#pbTipCatAktivna')?.checked !== false,
    };
  }

  function wireTipCatForm() {
    root.querySelector('#pbTipCatForm')?.addEventListener('submit', async e => {
      e.preventDefault();
      try {
        const payload = readTipCatPayload();
        await upsertEngTipCategory(payload);
        showToast('Kategorija sačuvana');
        fillTipCatForm(null);
        await reloadTipCategories();
      } catch (err) {
        showToast(err?.message || 'Greška');
      }
    });
    root.querySelector('#pbTipCatReset')?.addEventListener('click', () => fillTipCatForm(null));
  }

  function wireTipCatTable() {
    root.querySelectorAll('[data-cat-edit]').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-cat-edit');
        const row = tipCategories.find(c => c.id === id);
        if (row) fillTipCatForm(row);
      });
    });
    root.querySelectorAll('[data-cat-del]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-cat-del');
        if (!id) return;
        const row = tipCategories.find(c => c.id === id);
        const label = row?.naziv || 'kategoriju';
        if (!confirm(`Obrisati kategoriju "${label}"? Saveti ostaju, ali gube vezu sa kategorijom.`)) return;
        try {
          await deleteEngTipCategory(id);
          showToast('Obrisano');
          if (root.querySelector('#pbTipCatId')?.value === id) fillTipCatForm(null);
          await reloadTipCategories();
        } catch (err) {
          showToast(err?.message || 'Brisanje nije uspelo');
        }
      });
    });
  }

  function wireTipCats() {
    wireTipCatForm();
    wireTipCatTable();
  }

  paintAll();
  try {
    await reloadTipCategories();
  } catch (err) {
    showToast(err?.message || 'Kategorije nisu učitane');
  }
}
