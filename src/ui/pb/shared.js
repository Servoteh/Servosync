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

/** ISO yyyy-mm-dd → dd/mm/yyyy (forma modala). */
function pbFormatIsoToDmy(iso) {
  const s = String(iso || '').trim().slice(0, 10);
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return '';
  return `${m[3]}/${m[2]}/${m[1]}`;
}

/**
 * dd/mm/yyyy ili dd.mm.yyyy → ISO yyyy-mm-dd.
 * @returns {string|null} null = prazno polje, '' = nevalidan unos
 */
function pbParseDmyToIso(s) {
  const t = String(s || '').trim();
  if (!t) return null;
  const m = /^(\d{1,2})[/.](\d{1,2})[/.](\d{4})$/.exec(t);
  if (!m) return '';
  const d = Number(m[1]);
  const mo = Number(m[2]);
  const y = Number(m[3]);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return '';
  const dt = new Date(y, mo - 1, d);
  if (dt.getFullYear() !== y || dt.getMonth() !== mo - 1 || dt.getDate() !== d) return '';
  return `${y}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

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
      planLoadSectionOpen: o.planLoadSectionOpen ?? false,
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
    planLoadSectionOpen: false,
  };
}

/** Čuva da li je "Opterećenost" panel u Plan tabu otvoren. */
export function savePbPlanLoadSectionOpen(open) {
  const s = loadPbState();
  s.planLoadSectionOpen = !!open;
  savePbState(s);
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
  return root?.closest('.pb-module')?.classList.contains('pb-module--compact')
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
        <div class="pb-task-form-scroll">
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
          <label><span>Plan početak</span>
            <div class="pb-date-input-wrap">
              <input type="text" class="pb-task-date-dmy" id="pbTfDp" inputmode="numeric" autocomplete="off" placeholder="dd/mm/yyyy" value="${escHtml(pbFormatIsoToDmy(t.datum_pocetka_plan))}" ${canEdit ? '' : 'disabled'} />
              <button type="button" class="pb-date-picker-btn" aria-label="Otvori kalendar" ${canEdit ? '' : 'disabled'}>📅</button>
              <input type="date" class="pb-date-native" tabindex="-1" aria-hidden="true" value="${escHtml(String(t.datum_pocetka_plan || '').slice(0, 10))}" />
            </div>
          </label>
          <label><span>Plan rok</span>
            <div class="pb-date-input-wrap">
              <input type="text" class="pb-task-date-dmy" id="pbTfDr" inputmode="numeric" autocomplete="off" placeholder="dd/mm/yyyy" value="${escHtml(pbFormatIsoToDmy(t.datum_zavrsetka_plan))}" ${canEdit ? '' : 'disabled'} />
              <button type="button" class="pb-date-picker-btn" aria-label="Otvori kalendar" ${canEdit ? '' : 'disabled'}>📅</button>
              <input type="date" class="pb-date-native" tabindex="-1" aria-hidden="true" value="${escHtml(String(t.datum_zavrsetka_plan || '').slice(0, 10))}" />
            </div>
          </label>
          <label><span>Ostvaren poč.</span>
            <div class="pb-date-input-wrap">
              <input type="text" class="pb-task-date-dmy" id="pbTfRp" inputmode="numeric" autocomplete="off" placeholder="dd/mm/yyyy" value="${escHtml(pbFormatIsoToDmy(t.datum_pocetka_real))}" ${canEdit ? '' : 'disabled'} />
              <button type="button" class="pb-date-picker-btn" aria-label="Otvori kalendar" ${canEdit ? '' : 'disabled'}>📅</button>
              <input type="date" class="pb-date-native" tabindex="-1" aria-hidden="true" value="${escHtml(String(t.datum_pocetka_real || '').slice(0, 10))}" />
            </div>
          </label>
          <label><span>Ostvaren završetak</span>
            <div class="pb-date-input-wrap">
              <input type="text" class="pb-task-date-dmy" id="pbTfRz" inputmode="numeric" autocomplete="off" placeholder="dd/mm/yyyy" value="${escHtml(pbFormatIsoToDmy(t.datum_zavrsetka_real))}" ${canEdit ? '' : 'disabled'} />
              <button type="button" class="pb-date-picker-btn" aria-label="Otvori kalendar" ${canEdit ? '' : 'disabled'}>📅</button>
              <input type="date" class="pb-date-native" tabindex="-1" aria-hidden="true" value="${escHtml(String(t.datum_zavrsetka_real || '').slice(0, 10))}" />
            </div>
          </label>
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
        </div>
        <div class="pb-modal-actions">
          ${canEdit ? `<button type="button" class="btn btn-primary" id="pbTfSave" data-pb-task="save">Sačuvaj</button>` : ''}
          <button type="button" class="btn" id="pbTfCancel" data-pb-task="cancel">Otkaži</button>
        </div>
      </div>
    </div>`;

  function close() {
    wrap.remove();
  }

  const panelEl = wrap.querySelector('.pb-task-panel');

  wrap.addEventListener('click', e => {
    if (e.target === wrap) close();
  });

  const normR = wrap.querySelector('#pbTfNormR');
  const normN = wrap.querySelector('#pbTfNormN');
  normR?.addEventListener('input', () => { if (normN) normN.value = normR.value; });
  normN?.addEventListener('input', () => { if (normR) normR.value = normN.value; });

  async function handleSave() {
    const naziv = wrap.querySelector('#pbTfNaziv')?.value?.trim();
    const projectId = wrap.querySelector('#pbTfProject')?.value || null;
    if (!naziv || !projectId) {
      showToast('Unesi naziv i projekat');
      return;
    }
    /** @param {string} id */
    const readD = (id) => {
      const raw = wrap.querySelector(id)?.value?.trim() || '';
      if (!raw) return { ok: true, iso: null };
      const iso = pbParseDmyToIso(raw);
      if (iso === '') return { ok: false, iso: null };
      return { ok: true, iso };
    };
    const fDp = readD('#pbTfDp');
    const fDr = readD('#pbTfDr');
    const fRp = readD('#pbTfRp');
    const fRz = readD('#pbTfRz');
    if (!fDp.ok || !fDr.ok || !fRp.ok || !fRz.ok) {
      showToast('Datum mora biti u formatu dd/mm/yyyy (npr. 15/05/2026) ili ostavi prazno.');
      return;
    }
    const payload = {
      naziv,
      project_id: projectId,
      employee_id: wrap.querySelector('#pbTfEng')?.value || null,
      vrsta: wrap.querySelector('#pbTfVrsta')?.value,
      prioritet: wrap.querySelector('#pbTfPrio')?.value,
      status: wrap.querySelector('#pbTfStatus')?.value,
      datum_pocetka_plan: fDp.iso,
      datum_zavrsetka_plan: fDr.iso,
      datum_pocetka_real: fRp.iso,
      datum_zavrsetka_real: fRz.iso,
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
  }

  panelEl?.addEventListener('click', (e) => {
    const rawT = e.target;
    const t = rawT instanceof Element ? rawT : rawT.parentElement;
    if (!t || !(t instanceof Element)) return;
    if (t.closest('.pb-close-modal') || t.closest('[data-pb-task="cancel"]')) {
      e.preventDefault();
      close();
      return;
    }
    if (t.closest('[data-pb-task="save"]')) {
      e.preventDefault();
      void handleSave();
    }
  });

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

  document.body.appendChild(wrap);

  panelEl?.querySelectorAll('.pb-date-input-wrap').forEach((wrap) => {
    const textInp = /** @type {HTMLInputElement|null} */ (wrap.querySelector('.pb-task-date-dmy'));
    const btn = /** @type {HTMLButtonElement|null} */ (wrap.querySelector('.pb-date-picker-btn'));
    const nativeInp = /** @type {HTMLInputElement|null} */ (wrap.querySelector('.pb-date-native'));
    if (!textInp) return;

    /** Sinhronizuj text → native pre nego što picker otvori (start position). */
    function syncTextToNative() {
      if (!nativeInp) return;
      const iso = pbParseDmyToIso(textInp.value);
      if (iso) nativeInp.value = iso;
    }

    textInp.addEventListener('blur', () => {
      const raw = textInp.value.trim();
      if (!raw) return;
      const iso = pbParseDmyToIso(raw);
      if (iso) {
        textInp.value = pbFormatIsoToDmy(iso);
        if (nativeInp) nativeInp.value = iso;
      }
    });

    btn?.addEventListener('click', () => {
      if (!nativeInp || nativeInp.disabled) return;
      syncTextToNative();
      try {
        if (typeof nativeInp.showPicker === 'function') {
          nativeInp.showPicker();
        } else {
          nativeInp.focus();
          nativeInp.click();
        }
      } catch (_e) {
        nativeInp.focus();
      }
    });

    nativeInp?.addEventListener('change', () => {
      const iso = (nativeInp.value || '').slice(0, 10);
      if (iso) {
        textInp.value = pbFormatIsoToDmy(iso);
      }
    });
  });
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
