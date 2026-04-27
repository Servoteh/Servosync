/**
 * Modali za potvrdu kontrole i prijavu incidenta (kadr-modal stil).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  insertMaintCheck,
  insertMaintIncident,
  fetchMaintAssetsForPicker,
  fetchMaintWorkOrderByIncidentId,
  patchMaintIncident,
  upsertMaintMachineOverride,
  uploadMaintMachineFile,
} from '../../services/maintenance.js';
import { openMaintWorkOrderDetailModal } from './maintWorkOrdersPanel.js';

function removeIfExists(id) {
  document.getElementById(id)?.remove();
}

function assetTypeLabel(t) {
  const m = {
    machine: 'Mašina',
    vehicle: 'Vozilo',
    it: 'IT',
    facility: 'Objekat',
  };
  return m[t] || t || 'Sredstvo';
}

/**
 * @param {{ machineCode: string, tasks: Array<{ id: string, title?: string }>, preselectTaskId?: string|null, onSaved?: () => void }} opts
 */
export function openConfirmCheckModal(opts) {
  const { machineCode, tasks, preselectTaskId, onSaved } = opts;
  removeIfExists('mntDlgCheck');

  const taskOpts = (tasks || [])
    .map(t => {
      const sel = t.id === preselectTaskId ? ' selected' : '';
      return `<option value="${escHtml(String(t.id))}"${sel}>${escHtml(t.title || t.id)}</option>`;
    })
    .join('');

  const wrap = document.createElement('div');
  wrap.id = 'mntDlgCheck';
  wrap.className = 'kadr-modal-overlay';
  wrap.setAttribute('role', 'dialog');
  wrap.setAttribute('aria-modal', 'true');
  wrap.innerHTML = `
    <div class="kadr-modal" style="max-width:440px">
      <div class="kadr-modal-title">Potvrdi preventivnu kontrolu</div>
      <div class="kadr-modal-subtitle">Mašina <code>${escHtml(machineCode)}</code></div>
      <div class="kadr-modal-err" id="mntDlgCheckErr"></div>
      <form id="mntDlgCheckForm">
        <label class="form-label">Kontrola (task)</label>
        <select class="form-input" id="mntDlgCheckTask" required>${taskOpts || '<option value="">— Nema aktivnih taskova —</option>'}</select>
        <label class="form-label">Rezultat</label>
        <select class="form-input" id="mntDlgCheckResult">
          <option value="ok">OK</option>
          <option value="warning">Zamerka (warning)</option>
          <option value="fail">Ne prolazi (fail)</option>
          <option value="skipped">Preskočeno</option>
        </select>
        <label class="form-label">Napomena (opciono)</label>
        <textarea class="form-input" id="mntDlgCheckNotes" rows="3" placeholder=""></textarea>
        <div class="kadr-modal-actions" style="margin-top:16px">
          <button type="button" class="btn btn-secondary" id="mntDlgCheckCancel">Otkaži</button>
          <button type="submit" class="btn" id="mntDlgCheckSave">Sačuvaj</button>
        </div>
      </form>
    </div>`;
  document.body.appendChild(wrap);

  const close = () => wrap.remove();
  wrap.addEventListener('click', e => {
    if (e.target === wrap) close();
  });
  wrap.querySelector('#mntDlgCheckCancel')?.addEventListener('click', close);

  wrap.querySelector('#mntDlgCheckForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const errEl = wrap.querySelector('#mntDlgCheckErr');
    if (errEl) errEl.textContent = '';
    const taskId = wrap.querySelector('#mntDlgCheckTask')?.value;
    if (!taskId) {
      if (errEl) errEl.textContent = 'Izaberi kontrolu.';
      return;
    }
    const result = wrap.querySelector('#mntDlgCheckResult')?.value || 'ok';
    const notes = wrap.querySelector('#mntDlgCheckNotes')?.value?.trim() || null;
    const btn = wrap.querySelector('#mntDlgCheckSave');
    if (btn) btn.disabled = true;
    const row = await insertMaintCheck({ task_id: taskId, machine_code: machineCode, result, notes });
    if (btn) btn.disabled = false;
    if (!row) {
      if (errEl) errEl.textContent = 'Snimanje nije uspelo (RLS ili mreža).';
      showToast('⚠ Kontrola nije sačuvana');
      return;
    }
    showToast('✅ Kontrola zabeležena');
    close();
    onSaved?.();
  });

  setTimeout(() => wrap.querySelector('#mntDlgCheckTask')?.focus(), 50);
}

/**
 * @param {{ machineCode: string, onSaved?: () => void, maintProf?: object|null, onNavigateToPath?: (p:string)=>void }} opts
 */
export function openReportIncidentModal(opts) {
  const { machineCode, onSaved, maintProf = null, onNavigateToPath = null } = opts;
  removeIfExists('mntDlgInc');

  const wrap = document.createElement('div');
  wrap.id = 'mntDlgInc';
  wrap.className = 'kadr-modal-overlay';
  wrap.setAttribute('role', 'dialog');
  wrap.setAttribute('aria-modal', 'true');
  wrap.innerHTML = `
    <div class="kadr-modal" style="max-width:480px">
      <div class="kadr-modal-title">Prijavi kvar</div>
      <div class="kadr-modal-subtitle">Sredstvo <code>${escHtml(machineCode)}</code></div>
      <div class="kadr-modal-err" id="mntDlgIncErr"></div>
      <form id="mntDlgIncForm">
        <label class="form-label">Sredstvo *</label>
        <input type="text" class="form-input" id="mntDlgIncAsset" list="mntDlgIncAssetList" required placeholder="Pretraga šifre ili naziva sredstva">
        <datalist id="mntDlgIncAssetList"></datalist>
        <div class="mnt-muted" id="mntDlgIncAssetHint" style="font-size:12px;margin-top:4px">Učitavam sredstva…</div>
        <label class="form-label">Naslov *</label>
        <input type="text" class="form-input" id="mntDlgIncTitle" required maxlength="200" placeholder="Kratak opis kvara">
        <label class="form-label">Ozbiljnost</label>
        <select class="form-input" id="mntDlgIncSev">
          <option value="minor">Manje (minor)</option>
          <option value="major">Veće (major)</option>
          <option value="critical">Kritično (critical)</option>
        </select>
        <label class="form-label">Opis</label>
        <textarea class="form-input" id="mntDlgIncDesc" rows="4" placeholder="Detalji, šta se dešava…"></textarea>
        <label class="mnt-wo-check" style="margin-top:10px">
          <input type="checkbox" id="mntDlgIncSafety"> Bezbednosni rizik / safety marker
        </label>
        <label class="mnt-wo-check" style="margin-top:6px">
          <input type="checkbox" id="mntDlgIncDown"> Sredstvo je u zastoju (postavi status down)
        </label>
        <div class="mnt-muted" id="mntDlgIncDownHint" style="font-size:12px;margin-top:4px"></div>

        <label class="form-label" style="margin-top:10px">Fotografije (opciono)</label>
        <div class="mnt-inc-photo-wrap">
          <label class="mnt-inc-photo-btn" for="mntDlgIncFiles">
            <span>📷 Dodaj fotografije</span>
            <input id="mntDlgIncFiles" type="file" accept="image/*" capture="environment" multiple style="display:none">
          </label>
          <div class="mnt-inc-photo-hint mnt-muted" style="font-size:12px">JPG/PNG do 8 MB po fotografiji · otvara kameru na telefonu.</div>
          <div class="mnt-inc-photo-list" id="mntDlgIncFileList"></div>
        </div>

        <div class="kadr-modal-actions" style="margin-top:16px">
          <button type="button" class="btn btn-secondary" id="mntDlgIncCancel">Otkaži</button>
          <button type="submit" class="btn" id="mntDlgIncSave">Prijavi</button>
        </div>
      </form>
    </div>`;
  document.body.appendChild(wrap);

  const close = () => wrap.remove();
  wrap.addEventListener('click', e => {
    if (e.target === wrap) close();
  });
  wrap.querySelector('#mntDlgIncCancel')?.addEventListener('click', close);

  /** @type {Array<object>} */
  let assetRows = [];
  const assetInput = /** @type {HTMLInputElement} */ (wrap.querySelector('#mntDlgIncAsset'));
  const assetList = /** @type {HTMLDataListElement} */ (wrap.querySelector('#mntDlgIncAssetList'));
  const assetHint = wrap.querySelector('#mntDlgIncAssetHint');
  const downCheck = /** @type {HTMLInputElement} */ (wrap.querySelector('#mntDlgIncDown'));
  const downHint = wrap.querySelector('#mntDlgIncDownHint');

  const assetDisplay = a => `${a.asset_code || ''} — ${a.name || ''} (${assetTypeLabel(a.asset_type)})`;
  const selectedAsset = () => {
    const raw = String(assetInput?.value || '').trim();
    return assetRows.find(a => assetDisplay(a) === raw || String(a.asset_code || '').toLowerCase() === raw.toLowerCase()) || null;
  };
  function renderAssets() {
    if (assetList) {
      assetList.innerHTML = assetRows.map(a => `<option value="${escHtml(assetDisplay(a))}"></option>`).join('');
    }
    const sel = selectedAsset();
    if (assetHint) {
      assetHint.textContent = sel
        ? `${assetTypeLabel(sel.asset_type)} · ${sel.asset_code || '—'} · ${sel.name || '—'}`
        : 'Izaberi sredstvo iz predloga.';
    }
    if (downCheck) {
      downCheck.disabled = !!sel && sel.asset_type !== 'machine';
      if (downCheck.disabled) downCheck.checked = false;
    }
    if (downHint) {
      downHint.textContent = sel?.asset_type === 'machine'
        ? 'Ako označiš zastoj, mašina dobija manuelni status down.'
        : 'Zastoj trenutno automatski menjamo samo za mašine.';
    }
  }
  async function loadAssets(q = '') {
    assetRows = await fetchMaintAssetsForPicker({ q, limit: 300 });
    const initial = assetRows.find(a => String(a.asset_code || '').toLowerCase() === String(machineCode || '').toLowerCase());
    if (initial && assetInput && !assetInput.value) {
      assetInput.value = assetDisplay(initial);
    }
    renderAssets();
  }
  let assetTimer = 0;
  assetInput?.addEventListener('input', () => {
    renderAssets();
    window.clearTimeout(assetTimer);
    assetTimer = window.setTimeout(() => {
      void loadAssets(assetInput.value);
    }, 250);
  });
  void loadAssets(machineCode);

  /* ── Upravljanje odabranim fotografijama (preview + ukloni) ─────────── */
  /** @type {File[]} */
  const selected = [];
  const MAX_PHOTO_BYTES = 8 * 1024 * 1024;
  const fileInput = /** @type {HTMLInputElement} */ (wrap.querySelector('#mntDlgIncFiles'));
  const fileList = wrap.querySelector('#mntDlgIncFileList');
  const previewUrls = new Map();

  function renderFileList() {
    if (!fileList) return;
    fileList.innerHTML = selected.map((f, i) => {
      if (!previewUrls.has(f)) {
        try { previewUrls.set(f, URL.createObjectURL(f)); } catch { previewUrls.set(f, null); }
      }
      const url = previewUrls.get(f);
      const kb = Math.round((f.size || 0) / 1024);
      return `<div class="mnt-inc-photo-item" data-idx="${i}">
        ${url ? `<img src="${url}" alt="foto ${i + 1}">` : '<span>📎</span>'}
        <div class="mnt-inc-photo-meta">
          <div>${escHtml(f.name || `foto ${i + 1}`)}</div>
          <div class="mnt-muted" style="font-size:11px">${kb} KB</div>
        </div>
        <button type="button" class="mnt-inc-photo-x" data-rm="${i}" aria-label="Ukloni">×</button>
      </div>`;
    }).join('');
    fileList.querySelectorAll('[data-rm]').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = Number(btn.getAttribute('data-rm'));
        const f = selected[idx];
        if (previewUrls.has(f)) {
          try { URL.revokeObjectURL(previewUrls.get(f)); } catch { /* ignore */ }
          previewUrls.delete(f);
        }
        selected.splice(idx, 1);
        renderFileList();
      });
    });
  }

  fileInput?.addEventListener('change', () => {
    const files = Array.from(fileInput.files || []);
    for (const f of files) {
      if (!f.type?.startsWith('image/')) continue;
      if (f.size > MAX_PHOTO_BYTES) {
        showToast(`⚠ „${f.name}" veće od 8 MB — preskočeno`);
        continue;
      }
      if (selected.length >= 6) {
        showToast('⚠ Max 6 fotografija po prijavi');
        break;
      }
      selected.push(f);
    }
    fileInput.value = '';
    renderFileList();
  });

  wrap.querySelector('#mntDlgIncForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const errEl = wrap.querySelector('#mntDlgIncErr');
    if (errEl) errEl.textContent = '';
    const title = wrap.querySelector('#mntDlgIncTitle')?.value?.trim();
    if (!title) {
      if (errEl) errEl.textContent = 'Naslov je obavezan.';
      return;
    }
    const asset = selectedAsset();
    if (!asset?.asset_id) {
      if (errEl) errEl.textContent = 'Izaberi sredstvo iz liste.';
      return;
    }
    const severity = wrap.querySelector('#mntDlgIncSev')?.value || 'minor';
    const description = wrap.querySelector('#mntDlgIncDesc')?.value?.trim() || null;
    const safetyMarker = !!wrap.querySelector('#mntDlgIncSafety')?.checked;
    const markDown = !!downCheck?.checked && asset.asset_type === 'machine';
    const btn = wrap.querySelector('#mntDlgIncSave');
    if (btn) { btn.disabled = true; btn.textContent = selected.length ? 'Prijavljujem…' : 'Prijavi'; }
    const inc = await insertMaintIncident({
      machine_code: asset.asset_code || machineCode,
      asset_id: asset.asset_id,
      asset_type: asset.asset_type,
      title,
      description,
      severity,
      safety_marker: safetyMarker,
    });
    if (!inc?.id) {
      if (btn) { btn.disabled = false; btn.textContent = 'Prijavi'; }
      if (errEl) errEl.textContent = 'Prijava nije uspela (RLS ili mreža).';
      showToast('⚠ Kvar nije prijavljen');
      return;
    }
    if (markDown) {
      const okDown = await upsertMaintMachineOverride({
        machine_code: asset.asset_code || machineCode,
        status: 'down',
        reason: `Kvar: ${title}`.slice(0, 200),
        valid_until: null,
      });
      if (!okDown) showToast('⚠ Kvar je prijavljen, ali status down nije postavljen (ovlašćenje/RLS).');
    }

    /* Foto upload je best-effort: ako neka slika padne, incident ipak ostaje.
       Uploadujemo u maint-machine-files sa kategorijom incident-foto i
       pamtimo storage_path-ove; incident-u ih dodajemo kao attachment_urls. */
    const paths = [];
    if (selected.length) {
      if (btn) btn.textContent = `Uploadujem 0/${selected.length}…`;
      let done = 0;
      for (const f of selected) {
        const res = await uploadMaintMachineFile({
          machineCode: asset.asset_code || machineCode,
          file: f,
          category: 'incident-foto',
          description: `Kvar: ${title}`.slice(0, 200),
        });
        done++;
        if (btn) btn.textContent = `Uploadujem ${done}/${selected.length}…`;
        if (res?.ok && res.row?.storage_path) paths.push(res.row.storage_path);
      }
      if (paths.length) {
        await patchMaintIncident(inc.id, { attachment_urls: paths });
      }
      if (paths.length < selected.length) {
        showToast(`⚠ ${selected.length - paths.length} fotografija nije uploadovano`);
      }
    }

    /* Oslobodi preview URL-ove. */
    for (const u of previewUrls.values()) {
      if (u) try { URL.revokeObjectURL(u); } catch { /* ignore */ }
    }

    if (btn) { btn.disabled = false; btn.textContent = 'Prijavi'; }
    /* 'created' događaj upisuje DB trigger maint_incidents_audit (vidi add_maint_incidents_policies_v2.sql) */
    showToast(paths.length ? `✅ Kvar prijavljen (${paths.length} foto)` : '✅ Kvar prijavljen');
    close();
    onSaved?.();
    const wo = await fetchMaintWorkOrderByIncidentId(inc.id);
    if (wo?.wo_id) {
      await openMaintWorkOrderDetailModal({
        woId: String(wo.wo_id),
        maintProf,
        onNavigateToPath,
        onSaved,
      });
    } else if (severity === 'minor') {
      showToast('ℹ Za manje kvarove radni nalog se ne kreira automatski.');
    }
  });

  setTimeout(() => wrap.querySelector('#mntDlgIncTitle')?.focus(), 50);
}
