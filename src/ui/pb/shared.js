/**
 * Zajedničke komponente za Projektni biro — modali, alarmi, load meter.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  createPbTask,
  updatePbTask,
  softDeletePbTask,
  fetchPbTaskFiles,
  uploadPbTaskFile,
  deletePbTaskFile,
  getPbTaskFileSignedUrl,
  getPbTaskDeps,
  addPbTaskDep,
  deletePbTaskDep,
  getPbTasks,
  getPbTaskComments,
  createPbTaskComment,
  deletePbTaskComment,
} from '../../services/pb.js';

export const PB_STATE_KEY = 'pb_state_v1';
export const PB_VIEWS_KEY = 'pb_views_v1';

export const PB_TASK_STATUS = [
  'Nije počelo', 'U toku', 'Pregled', 'Završeno', 'Blokirano',
];
export const PB_TASK_VRSTA = [
  'Projektovanje 3D', 'Dokumentacija', 'Nabavka', 'Algoritam', 'Montaža',
];
export const PB_PRIORITET = ['Visok', 'Srednji', 'Nizak'];

/** Built-in presets (read-only — ne mogu se brisati). */
export const PB_BUILTIN_VIEWS = [
  { name: 'Visok prioritet', filters: { prioritet: 'Visok' } },
  { name: 'U toku', filters: { status: 'U toku' } },
  { name: 'Bez inženjera', filters: { unassignedOnly: true } },
  { name: 'Sa problemom', filters: { problemOnly: true } },
  { name: 'Blokirano', filters: { status: 'Blokirano' } },
];

/** Jednokratna migracija sa sessionStorage → localStorage (ako postoji stara sesija). */
function migrateSessionToLocal() {
  try {
    if (localStorage.getItem(PB_STATE_KEY)) return;
    const old = sessionStorage.getItem(PB_STATE_KEY);
    if (old) {
      localStorage.setItem(PB_STATE_KEY, old);
      sessionStorage.removeItem(PB_STATE_KEY);
    }
  } catch {
    /* ignore */
  }
}

export function loadPbState() {
  try {
    migrateSessionToLocal();
    const raw = localStorage.getItem(PB_STATE_KEY);
    if (!raw) return defaultPbState();
    const o = JSON.parse(raw);
    return {
      activeProject: o.activeProject ?? 'all',
      activeEngineer: o.activeEngineer ?? 'all',
      activeTab: o.activeTab ?? 'plan',
      moduleSearch: o.moduleSearch ?? '',
      moduleShowDone: o.moduleShowDone ?? false,
      moduleStatus: o.moduleStatus ?? 'all',
      modulePrioritet: o.modulePrioritet ?? 'all',
      moduleVrsta: o.moduleVrsta ?? 'all',
      moduleProblemOnly: o.moduleProblemOnly ?? false,
      moduleUnassignedOnly: o.moduleUnassignedOnly ?? false,
      ganttStartDate: o.ganttStartDate ?? null,
      ganttZoom: o.ganttZoom ?? 'day',
    };
  } catch {
    return defaultPbState();
  }
}

export function savePbState(st) {
  try {
    localStorage.setItem(PB_STATE_KEY, JSON.stringify(st));
  } catch {
    /* quota / privacy mode — silent */
  }
}

/** @returns {Array<{ name: string, filters: object }>} */
export function loadPbViews() {
  try {
    const raw = localStorage.getItem(PB_VIEWS_KEY);
    if (!raw) return [];
    const arr = JSON.parse(raw);
    if (!Array.isArray(arr)) return [];
    return arr
      .filter(v => v && typeof v.name === 'string' && v.filters && typeof v.filters === 'object')
      .map(v => ({ name: v.name, filters: { ...v.filters } }));
  } catch {
    return [];
  }
}

/** Dodaj ili prepiši (po imenu). */
export function savePbView(name, filters) {
  const trimmed = String(name || '').trim();
  if (!trimmed) return false;
  const all = loadPbViews().filter(v => v.name !== trimmed);
  all.push({ name: trimmed, filters: { ...filters } });
  try {
    localStorage.setItem(PB_VIEWS_KEY, JSON.stringify(all));
    return true;
  } catch {
    return false;
  }
}

export function deletePbView(name) {
  const all = loadPbViews().filter(v => v.name !== name);
  try {
    localStorage.setItem(PB_VIEWS_KEY, JSON.stringify(all));
    return true;
  } catch {
    return false;
  }
}

function defaultPbState() {
  return {
    activeProject: 'all',
    activeEngineer: 'all',
    activeTab: 'plan',
    moduleSearch: '',
    moduleShowDone: false,
    moduleStatus: 'all',
    modulePrioritet: 'all',
    moduleVrsta: 'all',
    moduleProblemOnly: false,
    moduleUnassignedOnly: false,
    ganttStartDate: null,
    ganttZoom: 'day',
  };
}

/** Sinhronizacija Plan / Kanban / Gantt filtera. */
export function syncPbModuleFilters(patch) {
  const s = loadPbState();
  for (const k of [
    'moduleSearch',
    'moduleShowDone',
    'moduleStatus',
    'modulePrioritet',
    'moduleVrsta',
    'moduleProblemOnly',
    'moduleUnassignedOnly',
  ]) {
    if (k in patch) s[k] = patch[k];
  }
  savePbState(s);
}

/** Čuva mesec za Gantt navigaciju (prvi dan meseca, ISO string). */
export function savePbGanttMonth(isoDateString) {
  const s = loadPbState();
  s.ganttStartDate = isoDateString;
  savePbState(s);
}

/** Čuva Gantt zoom level: 'day' | 'week' | 'month' | 'quarter'. */
export function savePbGanttZoom(zoom) {
  const valid = ['day', 'week', 'month', 'quarter'].includes(zoom) ? zoom : 'day';
  const s = loadPbState();
  s.ganttZoom = valid;
  savePbState(s);
}

export function statusBadgeClass(status) {
  const s = String(status || '');
  if (s === 'Završeno') return 'pb-badge pb-badge--ok';
  if (s === 'Blokirano') return 'pb-badge pb-badge--danger';
  if (s === 'U toku' || s === 'Pregled') return 'pb-badge pb-badge--warn';
  return 'pb-badge';
}

export function prioClass(p) {
  if (p === 'Visok') return 'pb-prio pb-prio--high';
  if (p === 'Nizak') return 'pb-prio pb-prio--low';
  return 'pb-prio pb-prio--mid';
}

/** @param {HTMLElement} root */
export function isPbMobile(root) {
  return root?.closest('.pb-module')?.classList.contains('pb-module--mobile')
    ?? window.matchMedia('(max-width: 767px)').matches;
}

function fmtBytes(n) {
  const x = Number(n);
  if (!Number.isFinite(x) || x <= 0) return '';
  if (x < 1024) return `${x} B`;
  if (x < 1024 * 1024) return `${(x / 1024).toFixed(1)} KB`;
  return `${(x / (1024 * 1024)).toFixed(1)} MB`;
}

function fmtUploadDate(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()}`;
}

function buildFilesListHtml(files, canEdit) {
  if (!files || !files.length) {
    return '<div class="pb-files-empty">Nema priloga.</div>';
  }
  return files.map(f => `
    <div class="pb-file-row" data-file-id="${escHtml(f.id)}" data-storage="${escHtml(f.storage_path || '')}">
      <button type="button" class="pb-file-open" title="Otvori">
        <span class="pb-file-icon">📎</span>
        <span class="pb-file-name">${escHtml(f.file_name || '')}</span>
      </button>
      <span class="pb-file-meta">
        ${f.category ? `<span class="pb-file-cat">${escHtml(f.category)}</span>` : ''}
        ${escHtml(fmtBytes(f.size_bytes))}
        · ${escHtml(fmtUploadDate(f.uploaded_at))}
        ${f.uploaded_by_email ? ` · ${escHtml(f.uploaded_by_email)}` : ''}
      </span>
      ${canEdit ? '<button type="button" class="pb-file-del" title="Obriši" aria-label="Obriši">✕</button>' : ''}
    </div>`).join('');
}

/**
 * @param {{
 *   task: object,
 *   projects: Array<{id:string,project_code:string,project_name:string}>,
 *   engineers: Array<{id:string,full_name:string}>,
 *   canEdit: boolean,
 *   onSaved: () => void,
 * }} opts
 */
export function openTaskEditorModal(opts) {
  const { task, projects, engineers, canEdit, onSaved } = opts;
  const wrap = document.createElement('div');
  const mobile = window.matchMedia('(max-width: 767px)').matches;
  wrap.className = mobile ? 'modal-overlay open pb-modal pb-modal--sheet' : 'modal-overlay open pb-modal';
  const isNew = !task?.id;
  const t = task || {};

  wrap.innerHTML = `
    <div class="modal-panel pb-task-panel" role="dialog" aria-label="${isNew ? 'Novi zadatak' : 'Izmeni zadatak'}">
      <div class="pb-modal-head">
        <h2>${isNew ? 'Novi zadatak' : 'Izmena zadatka'}</h2>
        <button type="button" class="btn btn-ghost pb-close-modal" aria-label="Zatvori">✕</button>
      </div>
      <div class="pb-task-form">
        <label class="pb-field"><span>Naziv *</span>
          <input type="text" id="pbTfNaziv" required value="${escHtml(t.naziv || '')}" ${canEdit ? '' : 'disabled'} />
        </label>
        <label class="pb-field"><span>Projekat *</span>
          <select id="pbTfProject" ${canEdit ? '' : 'disabled'}>
            <option value="">— izaberi —</option>
            ${projects.map(p => `
              <option value="${escHtml(p.id)}" ${t.project_id === p.id ? 'selected' : ''}>
                ${escHtml(p.project_code)} — ${escHtml(p.project_name)}
              </option>`).join('')}
          </select>
        </label>
        <label class="pb-field"><span>Inženjer</span>
          <select id="pbTfEng" ${canEdit ? '' : 'disabled'}>
            <option value="">— nije dodeljen —</option>
            ${engineers.map(e => `
              <option value="${escHtml(e.id)}" ${t.employee_id === e.id ? 'selected' : ''}>
                ${escHtml(e.full_name)}
              </option>`).join('')}
          </select>
        </label>
        <div class="pb-field-row">
          <label class="pb-field"><span>Vrsta</span>
            <select id="pbTfVrsta" ${canEdit ? '' : 'disabled'}>
              ${PB_TASK_VRSTA.map(v => `<option value="${escHtml(v)}" ${t.vrsta === v ? 'selected' : ''}>${escHtml(v)}</option>`).join('')}
            </select>
          </label>
          <label class="pb-field"><span>Prioritet</span>
            <select id="pbTfPrio" ${canEdit ? '' : 'disabled'}>
              ${PB_PRIORITET.map(v => `<option value="${escHtml(v)}" ${t.prioritet === v ? 'selected' : ''}>${escHtml(v)}</option>`).join('')}
            </select>
          </label>
          <label class="pb-field"><span>Status</span>
            <select id="pbTfStatus" ${canEdit ? '' : 'disabled'}>
              ${PB_TASK_STATUS.map(v => `<option value="${escHtml(v)}" ${t.status === v ? 'selected' : ''}>${escHtml(v)}</option>`).join('')}
            </select>
          </label>
        </div>
        <div class="pb-dates-grid">
          <label><span>Plan početak</span><input type="date" id="pbTfDp" value="${escHtml((t.datum_pocetka_plan || '').slice(0, 10))}" ${canEdit ? '' : 'disabled'} /></label>
          <label><span>Plan rok</span><input type="date" id="pbTfDr" value="${escHtml((t.datum_zavrsetka_plan || '').slice(0, 10))}" ${canEdit ? '' : 'disabled'} /></label>
          <label><span>Ostvaren poč.</span><input type="date" id="pbTfRp" value="${escHtml((t.datum_pocetka_real || '').slice(0, 10))}" ${canEdit ? '' : 'disabled'} /></label>
          <label><span>Ostvaren završetak</span><input type="date" id="pbTfRz" value="${escHtml((t.datum_zavrsetka_real || '').slice(0, 10))}" ${canEdit ? '' : 'disabled'} /></label>
        </div>
        <label class="pb-field"><span>Norma (h/dan)</span>
          <div class="pb-norm-row">
            <input type="range" id="pbTfNormR" min="1" max="7" value="${Number(t.norma_sati_dan) || 4}" ${canEdit ? '' : 'disabled'} />
            <input type="number" id="pbTfNormN" min="1" max="7" value="${Number(t.norma_sati_dan) || 4}" ${canEdit ? '' : 'disabled'} />
          </div>
        </label>
        <label class="pb-field"><span>Završenost %</span>
          <input type="number" id="pbTfPct" min="0" max="100" value="${Number(t.procenat_zavrsenosti) || 0}" ${canEdit ? '' : 'disabled'} />
        </label>
        ${isNew ? '' : `
          <div class="pb-comments-section" id="pbTfCommentsSection">
            <div class="pb-files-head">
              <span class="pb-files-title">💬 Komentari</span>
            </div>
            <div class="pb-comments-list" id="pbTfCommentsList">
              <div class="pb-files-loading">Učitavanje…</div>
            </div>
            ${canEdit ? `
              <div class="pb-comment-input-row">
                <textarea id="pbTfCommentInput" class="pb-textarea-lg" rows="2" placeholder="Dodaj komentar… (@email za mention)"></textarea>
                <button type="button" class="btn btn-sm btn-primary" id="pbTfCommentSend">Pošalji</button>
              </div>` : ''}
          </div>
          <div class="pb-deps-section" id="pbTfDepsSection">
            <div class="pb-files-head">
              <span class="pb-files-title">🔗 Zavisi od</span>
              ${canEdit ? '<button type="button" class="pb-files-upload-btn" id="pbTfDepAddBtn"><span>＋ Dodaj zavisnost</span></button>' : ''}
            </div>
            <div class="pb-deps-list" id="pbTfDepsList">
              <div class="pb-files-loading">Učitavanje…</div>
            </div>
          </div>
          <div class="pb-files-section" id="pbTfFilesSection">
            <div class="pb-files-head">
              <span class="pb-files-title">📎 Prilozi</span>
              ${canEdit ? `
                <label class="pb-files-upload-btn" for="pbTfFileInput">
                  <span>＋ Dodaj fajl</span>
                  <input type="file" id="pbTfFileInput" multiple style="display:none" />
                </label>` : ''}
            </div>
            <div class="pb-files-list" id="pbTfFilesList">
              <div class="pb-files-loading">Učitavanje…</div>
            </div>
          </div>`}
        <div class="pb-modal-actions">
          ${canEdit ? `<button type="button" class="btn btn-primary" id="pbTfSave">Sačuvaj</button>` : ''}
          <button type="button" class="btn" id="pbTfCancel">Otkaži</button>
        </div>
      </div>
    </div>`;

  function close() {
    wrap.remove();
  }

  wrap.querySelector('.pb-close-modal')?.addEventListener('click', close);
  wrap.querySelector('#pbTfCancel')?.addEventListener('click', close);
  wrap.addEventListener('click', e => {
    if (e.target === wrap) close();
  });

  const normR = wrap.querySelector('#pbTfNormR');
  const normN = wrap.querySelector('#pbTfNormN');
  normR?.addEventListener('input', () => { if (normN) normN.value = normR.value; });
  normN?.addEventListener('input', () => { if (normR) normR.value = normN.value; });

  /* ── Komentari (samo za postojeći task) ───────────────────────────── */
  if (!isNew) {
    const cListEl = wrap.querySelector('#pbTfCommentsList');
    const cInputEl = /** @type {HTMLTextAreaElement|null} */ (wrap.querySelector('#pbTfCommentInput'));
    const cSendBtn = wrap.querySelector('#pbTfCommentSend');
    let _comments = [];

    function fmtDateTime(iso) {
      if (!iso) return '';
      const d = new Date(iso);
      if (Number.isNaN(d.getTime())) return '';
      const pad = (n) => String(n).padStart(2, '0');
      return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
    }

    function renderBody(body) {
      /* Highlight @mentions u rich tekstu. */
      return escHtml(body || '')
        .replace(/@[\w.\-+]+/g, m => `<span class="pb-mention">${m}</span>`)
        .replace(/\n/g, '<br/>');
    }

    function commentRowHtml(c) {
      const author = c.created_by || '?';
      return `<div class="pb-comment-row" data-comment-id="${escHtml(c.id)}">
        <div class="pb-comment-head">
          <span class="pb-comment-author">${escHtml(author)}</span>
          <span class="pb-comment-date">${escHtml(fmtDateTime(c.created_at))}${c.edited_at ? ' · izmenjeno' : ''}</span>
          ${canEdit ? '<button type="button" class="pb-comment-del" title="Obriši" aria-label="Obriši">✕</button>' : ''}
        </div>
        <div class="pb-comment-body">${renderBody(c.body)}</div>
      </div>`;
    }

    function renderComments() {
      if (!cListEl) return;
      cListEl.innerHTML = _comments.length
        ? _comments.map(commentRowHtml).join('')
        : '<div class="pb-files-empty">Nema komentara.</div>';
      cListEl.querySelectorAll('.pb-comment-del').forEach(btn => {
        btn.addEventListener('click', async () => {
          const row = btn.closest('.pb-comment-row');
          const id = row?.getAttribute('data-comment-id');
          if (!id) return;
          if (!confirm('Obrisati komentar?')) return;
          btn.disabled = true;
          try {
            await deletePbTaskComment(id);
            _comments = _comments.filter(x => x.id !== id);
            renderComments();
          } catch {
            btn.disabled = false;
            showToast('Brisanje nije uspelo (možda je istekao 60-minut window)');
          }
        });
      });
    }

    async function loadComments() {
      _comments = await getPbTaskComments(t.id);
      renderComments();
    }

    cSendBtn?.addEventListener('click', async () => {
      const body = (cInputEl?.value || '').trim();
      if (!body) return;
      cSendBtn.disabled = true;
      const r = await createPbTaskComment(t.id, body);
      cSendBtn.disabled = false;
      if (r.ok && r.row) {
        _comments = [r.row, ..._comments];
        if (cInputEl) cInputEl.value = '';
        renderComments();
      } else {
        showToast(r.error || 'Slanje nije uspelo');
      }
    });

    loadComments();
  }

  /* ── Zavisnosti (samo za postojeći task) ──────────────────────────── */
  if (!isNew) {
    const depsListEl = wrap.querySelector('#pbTfDepsList');
    let _deps = [];
    let _allTasks = null; /* Cache svih taskova za picker. */

    function depRowHtml(d) {
      const target = d.depends_on || {};
      const statusBadge = target.status
        ? `<span class="${statusBadgeClass(target.status)}">${escHtml(target.status)}</span>`
        : '';
      return `<div class="pb-dep-row" data-dep-id="${escHtml(d.id)}">
        <span class="pb-dep-name">${escHtml(target.naziv || '(nepoznat zadatak)')}</span>
        ${statusBadge}
        ${canEdit ? '<button type="button" class="pb-file-del" title="Ukloni" aria-label="Ukloni">✕</button>' : ''}
      </div>`;
    }

    function renderDeps() {
      if (!depsListEl) return;
      depsListEl.innerHTML = _deps.length
        ? _deps.map(depRowHtml).join('')
        : '<div class="pb-files-empty">Nema zavisnosti — zadatak ne čeka nikoga.</div>';
      depsListEl.querySelectorAll('.pb-file-del').forEach(btn => {
        btn.addEventListener('click', async () => {
          const row = btn.closest('.pb-dep-row');
          const id = row?.getAttribute('data-dep-id');
          if (!id) return;
          btn.disabled = true;
          try {
            await deletePbTaskDep(id);
            _deps = _deps.filter(x => x.id !== id);
            renderDeps();
            showToast('Zavisnost uklonjena');
          } catch (e) {
            btn.disabled = false;
            showToast('Brisanje nije uspelo');
          }
        });
      });
    }

    async function loadDeps() {
      _deps = await getPbTaskDeps(t.id);
      renderDeps();
    }

    function openDepPicker() {
      if (!canEdit) return;
      const dlg = document.createElement('div');
      dlg.className = 'modal-overlay open pb-modal pb-modal--picker';
      dlg.innerHTML = `
        <div class="modal-panel pb-text-panel" role="dialog" aria-label="Izaberi zadatak">
          <div class="pb-modal-head">
            <h2>Dodaj zavisnost</h2>
            <button type="button" class="btn btn-ghost pb-close-picker">✕</button>
          </div>
          <input type="search" class="pb-ft-search" id="pbDepPickSearch" placeholder="Pretraži zadatke..." />
          <div class="pb-dep-picker-list" id="pbDepPickList"><div class="pb-files-loading">Učitavanje…</div></div>
        </div>`;
      document.body.appendChild(dlg);
      const close = () => dlg.remove();
      dlg.querySelector('.pb-close-picker')?.addEventListener('click', close);
      dlg.addEventListener('click', e => { if (e.target === dlg) close(); });

      const search = dlg.querySelector('#pbDepPickSearch');
      const list = dlg.querySelector('#pbDepPickList');

      function renderList(items, q) {
        const ql = String(q || '').trim().toLowerCase();
        const excluded = new Set([t.id, ..._deps.map(d => d.depends_on_task_id)]);
        const filtered = items
          .filter(x => !excluded.has(x.id))
          .filter(x => !ql || String(x.naziv || '').toLowerCase().includes(ql))
          .slice(0, 50);
        if (!filtered.length) {
          list.innerHTML = '<div class="pb-files-empty">Nema rezultata.</div>';
          return;
        }
        list.innerHTML = filtered.map(x => `
          <button type="button" class="pb-dep-pick-item" data-task-id="${escHtml(x.id)}">
            <span class="pb-dep-name">${escHtml(x.naziv || '')}</span>
            <span class="pb-file-meta">${escHtml(x.project_code || '')} · ${escHtml(x.status || '')}</span>
          </button>`).join('');
        list.querySelectorAll('.pb-dep-pick-item').forEach(btn => {
          btn.addEventListener('click', async () => {
            const tid = btn.getAttribute('data-task-id');
            if (!tid) return;
            btn.disabled = true;
            const r = await addPbTaskDep(t.id, tid);
            if (r.ok) {
              showToast('Zavisnost dodata');
              close();
              loadDeps();
            } else {
              btn.disabled = false;
              showToast(r.error || 'Greška');
            }
          });
        });
      }

      (async () => {
        if (!_allTasks) {
          _allTasks = await getPbTasks();
        }
        renderList(_allTasks, '');
        search?.addEventListener('input', () => renderList(_allTasks, search.value));
        setTimeout(() => search?.focus(), 50);
      })();
    }

    wrap.querySelector('#pbTfDepAddBtn')?.addEventListener('click', openDepPicker);
    loadDeps();
  }

  /* ── Prilozi (samo za postojeći task) ─────────────────────────────── */
  if (!isNew) {
    const listEl = wrap.querySelector('#pbTfFilesList');
    let _files = [];

    function renderList() {
      if (!listEl) return;
      listEl.innerHTML = buildFilesListHtml(_files, canEdit);
      listEl.querySelectorAll('.pb-file-open').forEach(btn => {
        btn.addEventListener('click', async () => {
          const row = btn.closest('.pb-file-row');
          const sp = row?.getAttribute('data-storage');
          if (!sp) return;
          const url = await getPbTaskFileSignedUrl(sp, 300);
          if (url) window.open(url, '_blank', 'noopener');
          else showToast('Ne mogu da otvorim fajl');
        });
      });
      listEl.querySelectorAll('.pb-file-del').forEach(btn => {
        btn.addEventListener('click', async () => {
          const row = btn.closest('.pb-file-row');
          const id = row?.getAttribute('data-file-id');
          const sp = row?.getAttribute('data-storage');
          if (!id) return;
          if (!confirm('Obrisati prilog?')) return;
          btn.disabled = true;
          const r = await deletePbTaskFile({ id, storage_path: sp || undefined });
          if (r.ok) {
            _files = _files.filter(f => f.id !== id);
            renderList();
            showToast('Prilog obrisan');
          } else {
            btn.disabled = false;
            showToast(r.error || 'Brisanje nije uspelo');
          }
        });
      });
    }

    async function loadFiles() {
      _files = await fetchPbTaskFiles(t.id);
      renderList();
    }

    const fileInput = wrap.querySelector('#pbTfFileInput');
    fileInput?.addEventListener('change', async () => {
      const files = Array.from(fileInput.files || []);
      if (!files.length) return;
      const label = wrap.querySelector('.pb-files-upload-btn span');
      const origText = label?.textContent;
      for (let i = 0; i < files.length; i++) {
        if (label) label.textContent = `Šaljem ${i + 1}/${files.length}…`;
        const r = await uploadPbTaskFile({ taskId: t.id, file: files[i] });
        if (r.ok && r.row) {
          _files = [r.row, ..._files];
          renderList();
        } else {
          showToast(r.error || `Greška: ${files[i].name}`);
        }
      }
      if (label && origText) label.textContent = origText;
      fileInput.value = '';
    });

    loadFiles();
  }

  wrap.querySelector('#pbTfSave')?.addEventListener('click', async () => {
    const naziv = wrap.querySelector('#pbTfNaziv')?.value?.trim();
    const projectId = wrap.querySelector('#pbTfProject')?.value || null;
    if (!naziv || !projectId) {
      showToast('Unesi naziv i projekat');
      return;
    }
    const payload = {
      naziv,
      project_id: projectId,
      employee_id: wrap.querySelector('#pbTfEng')?.value || null,
      vrsta: wrap.querySelector('#pbTfVrsta')?.value,
      prioritet: wrap.querySelector('#pbTfPrio')?.value,
      status: wrap.querySelector('#pbTfStatus')?.value,
      datum_pocetka_plan: wrap.querySelector('#pbTfDp')?.value || null,
      datum_zavrsetka_plan: wrap.querySelector('#pbTfDr')?.value || null,
      datum_pocetka_real: wrap.querySelector('#pbTfRp')?.value || null,
      datum_zavrsetka_real: wrap.querySelector('#pbTfRz')?.value || null,
      norma_sati_dan: Number(normN?.value) || 4,
      procenat_zavrsenosti: Number(wrap.querySelector('#pbTfPct')?.value) || 0,
    };
    let ok;
    if (isNew) ok = await createPbTask(payload);
    else ok = await updatePbTask(t.id, payload);
    if (ok) {
      showToast('Sačuvano');
      close();
      onSaved?.();
    } else showToast('Greška pri čuvanju');
  });

  document.body.appendChild(wrap);
}

export function openTextAreaModal({ title, initial, hint, canEdit, onSave }) {
  const wrap = document.createElement('div');
  const mobile = window.matchMedia('(max-width: 767px)').matches;
  wrap.className = mobile ? 'modal-overlay open pb-modal pb-modal--sheet' : 'modal-overlay open pb-modal';
  wrap.innerHTML = `
    <div class="modal-panel pb-text-panel" role="dialog">
      <div class="pb-modal-head"><h2>${escHtml(title)}</h2>
        <button type="button" class="btn btn-ghost pb-close-modal">✕</button></div>
      ${hint ? `<p class="pb-hint">${escHtml(hint)}</p>` : ''}
      <textarea id="pbTaBody" class="pb-textarea-lg" ${canEdit ? '' : 'disabled'}></textarea>
      <div class="pb-modal-actions">
        ${canEdit ? `<button type="button" class="btn btn-primary" id="pbTaSave">Sačuvaj</button>` : ''}
        <button type="button" class="btn" id="pbTaCancel">Otkaži</button>
      </div>
    </div>`;
  const ta = wrap.querySelector('#pbTaBody');
  if (ta) ta.value = initial || '';
  function close() { wrap.remove(); }
  wrap.querySelector('.pb-close-modal')?.addEventListener('click', close);
  wrap.querySelector('#pbTaCancel')?.addEventListener('click', close);
  wrap.addEventListener('click', e => { if (e.target === wrap) close(); });
  wrap.querySelector('#pbTaSave')?.addEventListener('click', async () => {
    const v = wrap.querySelector('#pbTaBody')?.value ?? '';
    await onSave?.(v);
    close();
  });
  document.body.appendChild(wrap);
}

/** Zaustavlja glasovni unos u Izveštajima pri promeni taba (registracija iz izvestajiTab). */
let pbIzvestajiSpeechRec = null;

/** @param {SpeechRecognition|null} r */
export function setPbIzvestajiSpeechRecog(r) {
  pbIzvestajiSpeechRec = r;
}

export function stopPbIzvestajiSpeech() {
  if (!pbIzvestajiSpeechRec) return;
  try {
    pbIzvestajiSpeechRec.stop();
  } catch {
    /* ignore */
  }
  pbIzvestajiSpeechRec = null;
}

/** Chrome / Edge / standard; Firefox; Safari; ime tipa. */
const PB_NETWORK_ERR_RE = /failed to fetch|networkerror|load failed|err_network|internet.*disconnected/i;

const PB_NO_INTERNET_HINT =
  'Nema internet veze ili je mreža nestabilna — proverite Wi‑Fi ili mobilne podatke, pa pokušajte ponovo.'
  + ' Ako ste na poslovnoj mreži, firewall ili VPN mogu da blokiraju pristup serveru.';

/**
 * Poruka za korisnika iz greške backend-a ili mreže.
 * @param {unknown} err
 */
export function pbErrorMessage(err) {
  if (err == null) return 'Nepoznata greška';
  if (typeof err === 'string') {
    return PB_NETWORK_ERR_RE.test(err) ? PB_NO_INTERNET_HINT : err;
  }
  if (typeof err === 'object' && err !== null) {
    const code = Object.prototype.hasOwnProperty.call(err, 'code')
      ? String((/** @type {{ code?: unknown }} */ (err)).code ?? '')
      : '';
    const msg = 'message' in err && /** @type {{ message?: unknown }} */ (err).message != null
      ? String((/** @type {{ message?: unknown }} */ (err)).message)
      : '';
    if (code === 'NETWORK' || PB_NETWORK_ERR_RE.test(msg)) {
      return PB_NO_INTERNET_HINT;
    }
    if (msg) return msg;
  }
  return String(err);
}

export async function confirmDeletePbTask(id, onDone) {
  if (!id || !confirm('Označiti zadatak kao obrisan (soft delete)?')) return;
  try {
    await softDeletePbTask(id);
    showToast('Zadatak obrisan');
    onDone?.();
  } catch (e) {
    showToast(pbErrorMessage(e) || 'Brisanje nije uspelo');
  }
}
