/**
 * GlobalniFAB + brzi unos PM teme sa bilo kog taba.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { saveTema, TEMA_VRSTE, TEMA_OBLASTI } from '../../services/pmTeme.js';
import { loadSastanci } from '../../services/sastanci.js';
import { loadProjektiLite } from '../../services/projekti.js';
import { getCurrentUser, canEdit, canPrioritizeTeme } from '../../state/auth.js';
import { renderPmTemeTab, teardownPmTemeTab } from './pmTemeTab.js';

let fabMounted = null;

/**
 * @param {object} o
 * @param {() => void} [o.onAfterSave] — npr. osvežavanje trenutnog taba
 */
export function openQuickAddTemaModal({ canEdit: canEditP, onAfterSave } = {}) {
  const canWrite = canEditP !== undefined ? canEditP : canEdit();
  if (!canWrite) {
    showToast('🔒 Nemaš pravo pisanja u modul');
    return;
  }

  const cu = getCurrentUser();
  const showZa = canPrioritizeTeme();
  const overlay = document.createElement('div');
  overlay.className = 'sast-modal-overlay';
  overlay.innerHTML = `
    <div class="sast-modal sast-modal--fabtema" role="dialog" aria-modal="true">
      <header class="sast-modal-header">
        <h3>+ Nova tema</h3>
        <button type="button" class="sast-modal-close" aria-label="Zatvori">✕</button>
      </header>
      <div class="sast-modal-body">
        <form id="fabTemaForm" class="sast-form">
          <label class="sast-form-row"><span>Naslov *</span>
            <input type="text" name="naslov" required maxlength="200" placeholder="Kratko i jasno"></label>
          <label class="sast-form-row"><span>Vrsta *</span>
            <select name="vrsta" required>
              ${Object.entries(TEMA_VRSTE).map(([k, v]) => `<option value="${k}">${escHtml(v)}</option>`).join('')}
            </select></label>
          <label class="sast-form-row"><span>Oblast *</span>
            <select name="oblast" required>
              ${Object.entries(TEMA_OBLASTI).map(([k, v]) => `<option value="${k}">${escHtml(v)}</option>`).join('')}
            </select></label>
          <label class="sast-form-row"><span>Projekat</span>
            <select name="projekatId" id="fabTemaPr"><option value="">—</option></select></label>
          <div class="sat-fabt-row">
            <label class="sast-fabt-check"><input type="checkbox" name="hitno"> <span>Hitno</span></label>
            ${showZa ? '<label class="sast-fabt-check"><input type="checkbox" name="zaRazmatranje"> <span>Za razmatranje (admin)</span></label>' : ''}
          </div>
          <label class="sast-form-row"><span>Stavi na sastanak</span>
            <select name="sastanakId" id="fabTemaSast"><option value="">—</option></select></label>
        </form>
      </div>
      <footer class="sast-modal-footer">
        <button type="button" class="btn" data-fab="x">Otkaži</button>
        <button type="button" class="btn btn-primary" data-fab="ok">Sačuvaj</button>
      </footer>
    </div>
  `;
  document.body.appendChild(overlay);

  const close = () => overlay.remove();

  (async () => {
    const [pr, sst] = await Promise.all([
      loadProjektiLite(),
      loadSastanci({ status: 'planiran', orderDatum: 'asc', limit: 100 }),
    ]);
    const pSel = overlay.querySelector('#fabTemaPr');
    pSel.innerHTML = '<option value="">—</option>' + (pr || []).map(p => `<option value="${p.id}">${escHtml(p.label)}</option>`).join('');
    const sSel = overlay.querySelector('#fabTemaSast');
    sSel.innerHTML = '<option value="">—</option>' + (sst || []).map(s => `<option value="${s.id}">${escHtml(s.datum + ' ' + s.naslov)}</option>`).join('');
  })();

  overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });
  overlay.querySelector('.sast-modal-close')?.addEventListener('click', close);
  overlay.querySelector('[data-fab=x]')?.addEventListener('click', close);
  overlay.querySelector('[data-fab=ok]')?.addEventListener('click', async () => {
    const fd = new FormData(overlay.querySelector('#fabTemaForm'));
    const naslov = String(fd.get('naslov') || '').trim();
    if (!naslov) { showToast('⚠ Naslov je obavezan'); return; }
    const t = {
      naslov,
      vrsta: fd.get('vrsta') || 'tema',
      oblast: fd.get('oblast') || 'opste',
      projekatId: fd.get('projekatId') || null,
      hitno: fd.get('hitno') === 'on',
      zaRazmatranje: showZa && fd.get('zaRazmatranje') === 'on',
      sastanakId: fd.get('sastanakId') || null,
      status: 'predlog',
      prioritet: 2,
      predlozioEmail: cu?.email || '',
    };
    const r = await saveTema(t);
    if (r) {
      showToast('Tema dodata');
      close();
      onAfterSave?.();
    } else {
      showToast('⚠ Snimanje nije uspelo');
    }
  });
}

/**
 * Mountuje fiksirano dugme u kontejner modula.
 * @param {HTMLElement} moduleRoot — #module-sastanci
 * @param {{ getActiveTab: () => string, canEdit: boolean }} o
 */
export function mountSastanciFab(moduleRoot, { getActiveTab, canEdit: ce }) {
  if (!moduleRoot || fabMounted) return;
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'sast-fab';
  btn.title = 'Nova tema';
  btn.setAttribute('aria-label', 'Nova tema');
  btn.textContent = '+';
  if (!ce) {
    btn.disabled = true;
    btn.title = 'Samo za uloge sa pravom pisanja';
  }
  btn.addEventListener('click', () => {
    if (!ce) { showToast('🔒 Nemaš pravo pisanja'); return; }
    openQuickAddTemaModal({
      canEdit: true,
      onAfterSave: () => {
        const tab = getActiveTab?.();
        if (tab === 'pm-teme') {
          const body = document.querySelector('#sastTabBody');
          if (body) {
            try { teardownPmTemeTab(); } catch (e) { /* ignore */ }
            renderPmTemeTab(body, { canEdit: ce });
          }
        }
      },
    });
  });
  moduleRoot.appendChild(btn);
  fabMounted = true;
}

export function unmountSastanciFab() {
  fabMounted = false;
}
