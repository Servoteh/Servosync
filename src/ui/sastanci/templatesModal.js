/**
 * Modal: Templati sastanaka — CRUD + Zakaži po templatu
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  listTemplates, createTemplate, updateTemplate, deleteTemplate, instantiateTemplate,
  nextOccurrence,
} from '../../services/sastanciTemplates.js';
import { SASTANAK_TIPOVI } from '../../services/sastanci.js';

const CADS = {
  none: 'Bez ponavljanja',
  daily: 'Dnevno',
  weekly: 'Nedeljno',
  biweekly: 'Na dve nedelje',
  monthly: 'Mesečno',
};

export function openTemplatesModal({ canEdit, onInstantiated }) {
  const overlay = document.createElement('div');
  overlay.className = 'sast-modal-overlay';
  overlay.innerHTML = `
    <div class="sast-modal sast-modal--wide" role="dialog" aria-modal="true">
      <header class="sast-modal-header">
        <h3>📋 Templati sastanaka</h3>
        <button type="button" class="sast-modal-close" aria-label="Zatvori">✕</button>
      </header>
      <div class="sst-tpl-bod" id="sstTplBody">Učitavam…</div>
    </div>
  `;
  document.body.appendChild(overlay);
  const close = () => overlay.remove();
  overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });
  overlay.querySelector('.sast-modal-close')?.addEventListener('click', close);

  async function refresh() {
    const list = await listTemplates();
    const body = overlay.querySelector('#sstTplBody');
    if (!list.length) {
      body.innerHTML = `
        <div class="sst-tpl-empty">
          <p>Još nema šablona. Kreiraj prvi (npr. <strong>Nedeljni PM sastanak</strong>).</p>
          ${canEdit ? '<button type="button" class="btn btn-primary" data-seed>+ Kreiraj \"Nedeljni PM sastanak\" (predlog)</button>' : ''}
        </div>
      `;
      body.querySelector('[data-seed]')?.addEventListener('click', () => {
        openForm(null, {
          naziv: 'Nedeljni PM sastanak',
          tip: 'sedmicni',
          cadence: 'weekly',
          cadenceDow: 1,
          vreme: '09:00',
        });
      });
      return;
    }
    const today = new Date();
    body.innerHTML = `
      <div class="sst-tpl-top">
        ${canEdit ? '<button type="button" class="btn btn-primary" id="sstAddTpl">+ Novi templat</button>' : ''}
      </div>
      <table class="sast-table sst-tpl-tbl">
        <thead>
          <tr>
            <th>Naziv</th><th>Cadence</th><th>Sledeći (procena)</th><th>Aktivan</th>
            <th class="sast-th-actions">Akcije</th>
          </tr>
        </thead>
        <tbody>
          ${list.map(t => {
            const nextD = nextOccurrence(t, today);
            return `
              <tr>
                <td><strong>${escHtml(t.naziv)}</strong> <span class="sst-sm">${escHtml(t.tip)}</span></td>
                <td>${escHtml(CADS[t.cadence] || t.cadence)}</td>
                <td>${escHtml(nextD)}</td>
                <td>${t.isActive ? 'da' : 'ne'}</td>
                <td class="sast-td-actions">
                  ${canEdit ? `<button type="button" class="btn btn-sm btn-primary" data-z="${t.id}">Zakaži po templatu</button>
                  <button type="button" class="btn btn-sm" data-e="${t.id}">Uredi</button>
                  <button type="button" class="btn btn-sm btn-danger" data-d="${t.id}">Obriši</button>` : ''}
                </td>
              </tr>
            `;
          }).join('')}
        </tbody>
      </table>
    `;
    body.querySelector('#sstAddTpl')?.addEventListener('click', () => openForm(null, {}));
    if (canEdit) {
      list.forEach(t => {
        body.querySelector(`[data-z="${t.id}"]`)?.addEventListener('click', async () => {
          const s = await instantiateTemplate(t);
          if (s) {
            showToast('📅 Sastanak zakazan');
            onInstantiated?.(s);
            close();
          } else { showToast('⚠ Nije moguće kreirati sastanak (proveri šemu / RLS)'); }
        });
        body.querySelector(`[data-e="${t.id}"]`)?.addEventListener('click', () => openForm(t, {}));
        body.querySelector(`[data-d="${t.id}"]`)?.addEventListener('click', async () => {
          if (!confirm('Obrisati templat?')) return;
          if (await deleteTemplate(t.id)) { showToast('Obrisano'); refresh(); }
        });
      });
    }
  }

  function openForm(tpl, seed) {
    const isEdit = !!tpl?.id;
    const t = isEdit
      ? { ...tpl, ...seed }
      : { cadence: 'weekly', isActive: true, tip: 'sedmicni', ucesnici: [], ...seed };
    const formOv = document.createElement('div');
    formOv.className = 'sast-modal-overlay';
    formOv.innerHTML = `
      <div class="sast-modal">
        <header class="sast-modal-header"><h3>${isEdit ? 'Uredi templat' : 'Novi templat'}</h3>
          <button type="button" class="sast-modal-close" data-x>✕</button></header>
        <div class="sst-form-tpl sast-modal-body">
          <form id="tplF" class="sast-form">
            <label class="sast-form-row"><span>Naziv *</span>
              <input name="naziv" required maxlength="200" value="${escHtml(t.naziv || '')}"></label>
            <label class="sast-form-row"><span>Tip *</span>
              <select name="tip">
                ${Object.entries(SASTANAK_TIPOVI).map(([k, v]) => `<option value="${k}"${t.tip === k ? ' selected' : ''}>${escHtml(v)}</option>`).join('')}
              </select></label>
            <label class="sast-form-row"><span>Mesto</span>
              <input name="mesto" value="${escHtml(t.mesto || '')}"></label>
            <div class="sas-form-2">
              <label class="sast-form-row"><span>Vodio (email)</span>
                <input name="vodioEmail" type="email" value="${escHtml(t.vodioEmail || '')}"></label>
              <label class="sast-form-row"><span>Zapisničar (email)</span>
                <input name="zapEmail" type="email" value="${escHtml(t.zapisnicarEmail || '')}"></label>
            </div>
            <label class="sast-form-row"><span>Cadence *</span>
              <select name="cadence">
                ${Object.entries(CADS).map(([k, v]) => `<option value="${k}"${t.cadence === k ? ' selected' : ''}>${escHtml(v)}</option>`).join('')}
              </select></label>
            <div class="sas-form-2">
              <label class="sast-form-row"><span>Dan (0=ned, 1=pon …)</span>
                <input name="cdow" type="number" min="0" max="6" value="${t.cadenceDow != null ? t.cadenceDow : ''}"></label>
              <label class="sast-form-row"><span>Dan u mesecu (1–31)</span>
                <input name="cdom" type="number" min="1" max="31" value="${t.cadenceDom != null ? t.cadenceDom : ''}"></label>
            </div>
            <label class="sast-form-row"><span>Vreme (HH:MM)</span>
              <input name="vreme" type="time" value="${(t.vreme && String(t.vreme).slice(0, 5)) || '09:00'}"></label>
            <label class="sast-form-row"><span>Napomena</span>
              <textarea name="nap" rows="2" maxlength="1000">${escHtml(t.napomena || '')}</textarea></label>
            <label class="sas-check"><input type="checkbox" name="active" ${t.isActive !== false ? 'checked' : ''}> Aktivan</label>
            <label class="sast-form-row"><span>Učesnici (email, jedan po liniji)</span>
              <textarea name="ucTxt" rows="3" placeholder="a@b.rs&#10;b@b.rs Ime i prezime">${(t.ucesnici || []).map(u => u.label ? `${u.email} ${u.label}` : u.email).join('\n')}</textarea></label>
          </form>
        </div>
        <footer class="sast-modal-footer">
          <button type="button" class="btn" data-c>Otkaži</button>
          <button type="button" class="btn btn-primary" data-s>Sačuvaj</button>
        </footer>
      </div>
    `;
    document.body.appendChild(formOv);
    const c = () => formOv.remove();
    formOv.addEventListener('click', (e) => { if (e.target === formOv) c(); });
    formOv.querySelector('[data-x]')?.addEventListener('click', c);
    formOv.querySelector('[data-c]')?.addEventListener('click', c);
    formOv.querySelector('[data-s]')?.addEventListener('click', async () => {
      const fd = new FormData(formOv.querySelector('#tplF'));
      const ucesnici = parseUc(fd.get('ucTxt'));
      const p = {
        naziv: String(fd.get('naziv') || '').trim(),
        tip: fd.get('tip') || 'sedmicni',
        mesto: String(fd.get('mesto') || '').trim() || null,
        vodioEmail: String(fd.get('vodioEmail') || '').trim() || null,
        zapisnicarEmail: String(fd.get('zapEmail') || '').trim() || null,
        cadence: fd.get('cadence') || 'none',
        cadenceDow: fd.get('cdow') === '' ? null : Number(fd.get('cdow')),
        cadenceDom: fd.get('cdom') === '' ? null : Number(fd.get('cdom')),
        vreme: fd.get('vreme') || null,
        napomena: String(fd.get('nap') || '').trim() || null,
        isActive: fd.get('active') === 'on',
      };
      if (!p.naziv) { showToast('⚠ Naziv je obavezan'); return; }
      if (isEdit) {
        const r = await updateTemplate(tpl.id, p, ucesnici);
        if (r) { showToast('Sačuvano'); c(); refresh(); }
        else showToast('⚠ Greška');
      } else {
        const r = await createTemplate(p, ucesnici);
        if (r) { showToast('Kreirano'); c(); refresh(); }
        else showToast('⚠ Greška');
      }
    });
  }

  function parseUc(txt) {
    const s = String(txt || '').split(/\r?\n/).map(l => l.trim()).filter(Boolean);
    return s.map(line => {
      const sp = line.split(/\s+/);
      const email = sp[0] || '';
      const label = sp.slice(1).join(' ').trim();
      return { email, label: label || email };
    });
  }

  refresh();
}
