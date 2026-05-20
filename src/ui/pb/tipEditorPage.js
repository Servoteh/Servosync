/**
 * PB Saveti — punostrani editor (bez modal overlay-a).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  saveEngTip,
  uploadEngTipFile,
  deleteEngTipFile,
  getEngTipFileSignedUrl,
} from '../../services/pbEngTips.js';
import { markdownToHtml } from './markdown.js';

/**
 * @param {HTMLElement} mountEl
 * @param {{
 *   tip?: object|null,
 *   projects?: object[],
 *   categories?: object[],
 *   canEdit?: boolean,
 *   onBack?: () => void,
 *   onSaved?: () => void,
 * }} opts
 */
export function renderTipEditorPage(mountEl, opts = {}) {
  const {
    tip = null,
    projects = [],
    categories = [],
    canEdit = false,
    onBack,
    onSaved,
  } = opts;

  if (!canEdit) {
    showToast('Nemate pravo da menjate savete');
    onBack?.();
    return;
  }

  const isNew = !tip?.id;
  const t = tip || {};
  const tags = Array.isArray(t.tags) ? [...t.tags] : [];
  /** @type {{ file: File, preview?: string }[]} */
  const pendingFiles = [];
  /** @type {object[]} */
  let existingFiles = Array.isArray(t.files) ? [...t.files] : [];

  const catOpts = categories.map(c =>
    `<option value="${escHtml(c.id)}" ${t.category_id === c.id ? 'selected' : ''}>${escHtml(c.ikona || '')} ${escHtml(c.naziv)}</option>`,
  ).join('');
  const projOpts = projects.map(p =>
    `<option value="${escHtml(p.id)}" ${t.project_id === p.id ? 'selected' : ''}>${escHtml(p.project_code)} \u2014 ${escHtml(p.project_name)}</option>`,
  ).join('');

  mountEl.innerHTML = `
    <div class="pb-saveti-editor-page">
      <header class="pb-saveti-editor-head">
        <button type="button" class="btn btn-ghost pb-saveti-editor-back" id="pbTeBack" aria-label="Nazad na listu">&larr; Nazad</button>
        <h2 class="pb-saveti-editor-title">${isNew ? 'Novi savet' : 'Izmena saveta'}</h2>
      </header>
      <div class="pb-saveti-editor-scroll">
        <label class="pb-field"><span>Naslov *</span>
          <input type="text" id="pbTeNaslov" maxlength="200" value="${escHtml(t.naslov || '')}" />
        </label>
        <label class="pb-field"><span>Kategorija</span>
          <select id="pbTeCat"><option value="">\u2014</option>${catOpts}</select>
        </label>
        <div class="pb-field">
          <span>Telo *</span>
          <div class="pb-te-tabs">
            <button type="button" class="pb-te-tab active" data-te-tab="write">Pisanje</button>
            <button type="button" class="pb-te-tab" data-te-tab="preview">Pregled</button>
          </div>
          <textarea id="pbTeTelo" class="pb-textarea-lg" rows="12">${escHtml(t.telo || '')}</textarea>
          <div id="pbTePreview" class="pb-te-preview" hidden></div>
        </div>
        <label class="pb-field"><span>Tagovi (Enter)</span>
          <div class="pb-te-tags-wrap" id="pbTeTagsWrap"></div>
          <input type="text" id="pbTeTagInput" class="pb-te-tag-input" placeholder="dodaj tag" />
        </label>
        <label class="pb-field"><span>Dobavlja\u010d</span>
          <input type="text" id="pbTeVendor" value="${escHtml(t.vendor || '')}" />
        </label>
        <label class="pb-field"><span>URL</span>
          <input type="url" id="pbTeUrl" value="${escHtml(t.url || '')}" placeholder="https://" />
        </label>
        <label class="pb-field"><span>Projekat</span>
          <select id="pbTeProject"><option value="">\u2014</option>${projOpts}</select>
        </label>
        <fieldset class="pb-field pb-te-status">
          <legend>Status</legend>
          <label><input type="radio" name="pbTeStatus" value="draft" ${t.status !== 'published' ? 'checked' : ''} /> Draft</label>
          <label><input type="radio" name="pbTeStatus" value="published" ${t.status === 'published' ? 'checked' : ''} /> Objavljen</label>
        </fieldset>
        <div class="pb-field">
          <span>Prilozi (slike, PDF, max 5 MB)</span>
          <div class="pb-te-drop" id="pbTeDrop">Prevuci fajlove ovde ili klikni</div>
          <input type="file" id="pbTeFileIn" accept="image/*,application/pdf" multiple hidden />
          <div id="pbTeFilesList" class="pb-te-files-list"></div>
        </div>
      </div>
      <footer class="pb-saveti-editor-foot">
        <button type="button" class="btn btn-primary" id="pbTeSave">Sa\u010duvaj</button>
        <button type="button" class="btn" id="pbTeCancel">Otka\u017ei</button>
      </footer>
    </div>`;

  const root = mountEl.querySelector('.pb-saveti-editor-page');
  if (!root) return;

  const naslovEl = mountEl.querySelector('#pbTeNaslov');
  const teloEl = mountEl.querySelector('#pbTeTelo');
  const tagsWrap = mountEl.querySelector('#pbTeTagsWrap');
  const tagIn = mountEl.querySelector('#pbTeTagInput');
  const filesList = mountEl.querySelector('#pbTeFilesList');
  const previewEl = mountEl.querySelector('#pbTePreview');

  const goBack = () => {
    pendingFiles.forEach(p => { if (p.preview) URL.revokeObjectURL(p.preview); });
    onBack?.();
  };

  function renderTags() {
    if (!tagsWrap) return;
    tagsWrap.innerHTML = tags.map((tag, i) =>
      `<span class="pb-te-tag-chip">${escHtml(tag)}<button type="button" data-tag-idx="${i}" aria-label="Ukloni">&#10005;</button></span>`,
    ).join('');
    tagsWrap.querySelectorAll('[data-tag-idx]').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = Number(btn.getAttribute('data-tag-idx'));
        tags.splice(idx, 1);
        renderTags();
      });
    });
  }
  renderTags();

  tagIn?.addEventListener('keydown', e => {
    if (e.key !== 'Enter') return;
    e.preventDefault();
    const v = (tagIn.value || '').trim();
    if (!v) return;
    if (tags.length >= 10) {
      showToast('Maksimalno 10 tag-ova');
      return;
    }
    if (!tags.includes(v)) tags.push(v);
    tagIn.value = '';
    renderTags();
  });

  root.querySelectorAll('.pb-te-tab').forEach(btn => {
    btn.addEventListener('click', () => {
      const mode = btn.getAttribute('data-te-tab');
      root.querySelectorAll('.pb-te-tab').forEach(b => b.classList.toggle('active', b === btn));
      if (mode === 'preview') {
        if (teloEl) teloEl.hidden = true;
        if (previewEl) {
          previewEl.hidden = false;
          previewEl.innerHTML = markdownToHtml(teloEl?.value || '');
        }
      } else {
        if (teloEl) teloEl.hidden = false;
        if (previewEl) previewEl.hidden = true;
      }
    });
  });

  async function renderFilesList() {
    if (!filesList) return;
    const rows = [];
    for (const f of existingFiles) {
      let thumb = '';
      if (f.is_image && f.storage_path) {
        const url = f.signed_url || await getEngTipFileSignedUrl(f.storage_path);
        if (url) thumb = `<img src="${escHtml(url)}" alt="" class="pb-te-thumb" />`;
      }
      rows.push(`<div class="pb-te-file-row" data-file-id="${escHtml(f.id)}">
        ${thumb}<span>${escHtml(f.file_name)}</span>
        <button type="button" class="pb-file-del" data-rm-existing="${escHtml(f.id)}">&#10005;</button>
      </div>`);
    }
    for (let i = 0; i < pendingFiles.length; i++) {
      const p = pendingFiles[i];
      const thumb = p.preview ? `<img src="${escHtml(p.preview)}" alt="" class="pb-te-thumb" />` : '';
      rows.push(`<div class="pb-te-file-row" data-pending="${i}">
        ${thumb}<span>${escHtml(p.file.name)}</span>
        <button type="button" class="pb-file-del" data-rm-pending="${i}">&#10005;</button>
      </div>`);
    }
    filesList.innerHTML = rows.length ? rows.join('') : '<p class="pb-muted">Nema priloga</p>';

    filesList.querySelectorAll('[data-rm-existing]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-rm-existing');
        const row = existingFiles.find(x => x.id === id);
        if (!row || !confirm('Obrisati prilog?')) return;
        btn.disabled = true;
        try {
          await deleteEngTipFile(row.id, row.storage_path);
          existingFiles = existingFiles.filter(x => x.id !== id);
          await renderFilesList();
        } catch (e) {
          showToast(e?.message || 'Brisanje nije uspelo');
          btn.disabled = false;
        }
      });
    });
    filesList.querySelectorAll('[data-rm-pending]').forEach(btn => {
      btn.addEventListener('click', () => {
        const i = Number(btn.getAttribute('data-rm-pending'));
        const p = pendingFiles[i];
        if (p?.preview) URL.revokeObjectURL(p.preview);
        pendingFiles.splice(i, 1);
        void renderFilesList();
      });
    });
  }
  void renderFilesList();

  function addPendingFiles(fileList) {
    for (const file of fileList) {
      if (existingFiles.length + pendingFiles.length >= 8) {
        showToast('Maksimalno 8 priloga');
        break;
      }
      const mime = file.type || '';
      if (mime && !mime.startsWith('image/') && mime !== 'application/pdf') {
        showToast(`${file.name}: samo slike i PDF`);
        continue;
      }
      if (file.size > 5 * 1024 * 1024) {
        showToast(`${file.name}: prevelik fajl`);
        continue;
      }
      const preview = mime.startsWith('image/') ? URL.createObjectURL(file) : undefined;
      pendingFiles.push({ file, preview });
    }
    void renderFilesList();
  }

  const drop = mountEl.querySelector('#pbTeDrop');
  const fileIn = mountEl.querySelector('#pbTeFileIn');
  drop?.addEventListener('click', () => fileIn?.click());
  fileIn?.addEventListener('change', () => {
    if (fileIn.files?.length) addPendingFiles(Array.from(fileIn.files));
    fileIn.value = '';
  });
  drop?.addEventListener('dragover', e => { e.preventDefault(); drop.classList.add('dragover'); });
  drop?.addEventListener('dragleave', () => drop.classList.remove('dragover'));
  drop?.addEventListener('drop', e => {
    e.preventDefault();
    drop.classList.remove('dragover');
    if (e.dataTransfer?.files?.length) addPendingFiles(Array.from(e.dataTransfer.files));
  });

  mountEl.querySelector('#pbTeBack')?.addEventListener('click', goBack);
  mountEl.querySelector('#pbTeCancel')?.addEventListener('click', goBack);

  mountEl.querySelector('#pbTeSave')?.addEventListener('click', async () => {
    const naslov = naslovEl?.value?.trim() || '';
    const telo = teloEl?.value?.trim() || '';
    naslovEl?.classList.remove('invalid');
    teloEl?.classList.remove('invalid');
    let ok = true;
    if (naslov.length < 3) { naslovEl?.classList.add('invalid'); ok = false; }
    if (telo.length < 10) { teloEl?.classList.add('invalid'); ok = false; }
    if (!ok) {
      showToast('Proveri naslov i telo');
      return;
    }

    const status = mountEl.querySelector('input[name="pbTeStatus"]:checked')?.value || 'draft';
    const saveBtn = mountEl.querySelector('#pbTeSave');
    if (saveBtn) saveBtn.disabled = true;
    try {
      const saved = await saveEngTip({
        id: t.id || undefined,
        naslov,
        telo,
        category_id: mountEl.querySelector('#pbTeCat')?.value || null,
        tags,
        vendor: mountEl.querySelector('#pbTeVendor')?.value?.trim() || null,
        url: mountEl.querySelector('#pbTeUrl')?.value?.trim() || null,
        project_id: mountEl.querySelector('#pbTeProject')?.value || null,
        status,
      });
      const tipId = saved?.id || t.id;
      if (tipId && pendingFiles.length) {
        let n = existingFiles.length;
        for (const p of pendingFiles) {
          await uploadEngTipFile(tipId, p.file, { existingCount: n });
          n += 1;
        }
      }
      showToast('Sa\u010duvano');
      pendingFiles.forEach(p => { if (p.preview) URL.revokeObjectURL(p.preview); });
      onSaved?.();
      goBack();
    } catch (e) {
      showToast(e?.message || 'Gre\u0161ka pri \u010duvanju');
    } finally {
      if (saveBtn) saveBtn.disabled = false;
    }
  });
}
