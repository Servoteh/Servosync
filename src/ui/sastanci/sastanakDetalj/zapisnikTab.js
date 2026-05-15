/**
 * Zapisnik tab — presek_aktivnosti sa rich-text editorom i upload slika.
 *
 * Svaka sekcija = jedan red presek_aktivnosti:
 *   - naslov, pod_rn, odgovoran, rok, status, sadrzaj (rich-text), slike
 * Drag-drop za reorder sekcija (redosled kolona).
 * Auto-save: debounce (SAVE_DEBOUNCE_MS) po polju; blur / skrivanje taba flush-uje odmah.
 * Upload slika → Storage 'sastanak-slike' → presek_slike.
 */

import { escHtml, showToast } from '../../../lib/dom.js';
import { SAVE_DEBOUNCE_MS } from '../../../lib/constants.js';
import { sanitizeHtml, htmlToText } from '../../../lib/htmlSanitize.js';
import { getIsOnline, onAuthChange } from '../../../state/auth.js';
import {
  loadPresekAktivnosti, savePresekAktivnost, deletePresekAktivnost,
  reorderPresekAktivnosti, loadPresekSlike,
  uploadPresekSlika, deletePresekSlika, getPresekSlikaUrl,
} from '../../../services/sastanciDetalj.js';

const PRESEK_STATUSI = {
  planiran:   'Planiran',
  u_toku:     'U toku',
  zavrsen:    'Završen',
  blokirano:  'Blokirano',
  odlozeno:   'Odloženo',
};

let abortFlag = false;
let dragState = null;

/** @type {Map<string, { timer: ReturnType<typeof setTimeout>, exec: () => Promise<void> }>} */
let pendingSaves = new Map();
let saveBarEls = {
  root: /** @type {HTMLElement | null} */ (null),
  text: /** @type {HTMLElement | null} */ (null),
  saveNow: /** @type {HTMLButtonElement | null} */ (null),
};
let activeSaving = 0;
let saveHadError = false;
/** @type {(() => void)[]} */
let zapisnikLifecycleCleanups = [];

function refreshSaveBar() {
  const textEl = saveBarEls.text;
  const rootEl = saveBarEls.root;
  const btn = saveBarEls.saveNow;
  if (!textEl || !rootEl) return;
  rootEl.classList.remove(
    'zs-save-bar--pending', 'zs-save-bar--saving', 'zs-save-bar--error', 'zs-save-bar--offline',
  );

  if (!getIsOnline()) {
    rootEl.classList.add('zs-save-bar--offline');
    textEl.textContent =
      'Niste na mreži — izmene se ne mogu sačuvati dok se konekcija ne vrati.';
    if (btn) btn.disabled = true;
    return;
  }
  if (saveHadError && activeSaving === 0 && pendingSaves.size === 0) {
    rootEl.classList.add('zs-save-bar--error');
    textEl.textContent =
      'Greška pri čuvanju — proveri mrežu, izmeni polje ponovo ili osveži stranicu.';
    if (btn) btn.disabled = false;
    return;
  }
  if (activeSaving > 0) {
    rootEl.classList.add('zs-save-bar--saving');
    textEl.textContent = 'Čuvam u bazu…';
    if (btn) btn.disabled = true;
    return;
  }
  if (pendingSaves.size > 0) {
    rootEl.classList.add('zs-save-bar--pending');
    textEl.textContent =
      'Ima nesačuvanih izmena — sačuvaću automatski uskoro (klik van polja čuva odmah).';
    if (btn) btn.disabled = false;
    return;
  }
  textEl.textContent = 'Sačuvano · poslednje izmene su u bazi.';
  if (btn) btn.disabled = false;
}

function bindSaveBar(host) {
  saveBarEls = {
    root: host.querySelector('#zsSaveBar'),
    text: host.querySelector('#zsSaveBarText'),
    saveNow: host.querySelector('#zsSaveNowBtn'),
  };
  saveBarEls.saveNow?.addEventListener('click', async () => {
    if (!getIsOnline()) {
      showToast('⚠ Nema mreže');
      return;
    }
    const queued = pendingSaves.size;
    await flushAllPendingSaves();
    if (saveHadError) showToast('⚠ Čuvanje nije uspelo — proveri poruku iznad');
    else if (queued > 0) showToast('✅ Sačuvano u bazu');
    else showToast('ℹ Nema izmena na čekanju — sve je već u bazi');
  });
  refreshSaveBar();
}

function registerZapisnikLifecycleListeners() {
  const onVis = () => {
    if (document.visibilityState === 'hidden') void flushAllPendingSaves();
  };
  const onBeforeUnload = (e) => {
    if (pendingSaves.size > 0 || activeSaving > 0) {
      e.preventDefault();
      e.returnValue = '';
    }
  };
  document.addEventListener('visibilitychange', onVis);
  window.addEventListener('beforeunload', onBeforeUnload);
  const unsubAuth = onAuthChange(() => refreshSaveBar());
  zapisnikLifecycleCleanups.push(() => {
    document.removeEventListener('visibilitychange', onVis);
    window.removeEventListener('beforeunload', onBeforeUnload);
    unsubAuth();
  });
}

function scheduleDebouncedSave(key, exec) {
  const prev = pendingSaves.get(key);
  if (prev) clearTimeout(prev.timer);
  const timer = setTimeout(() => {
    pendingSaves.delete(key);
    void runSaveNow(key, exec);
  }, SAVE_DEBOUNCE_MS);
  pendingSaves.set(key, { timer, exec });
  refreshSaveBar();
}

async function runSaveNow(key, exec) {
  if (!getIsOnline()) {
    saveHadError = true;
    refreshSaveBar();
    showToast('⚠ Nema mreže');
    return;
  }
  activeSaving++;
  refreshSaveBar();
  try {
    await exec();
    saveHadError = false;
  } catch (err) {
    console.error('[ZapisnikTab] save', key, err);
    saveHadError = true;
    showToast('⚠ Čuvanje nije uspelo');
  } finally {
    activeSaving--;
    refreshSaveBar();
  }
}

function flushSaveKey(key) {
  const st = pendingSaves.get(key);
  if (!st) return;
  clearTimeout(st.timer);
  pendingSaves.delete(key);
  void runSaveNow(key, st.exec);
}

async function flushAllPendingSaves() {
  const entries = [...pendingSaves.entries()];
  for (const [key, st] of entries) {
    clearTimeout(st.timer);
    pendingSaves.delete(key);
    await runSaveNow(key, st.exec);
  }
}

/**
 * @param {HTMLElement} el
 * @param {object} akt
 */
async function persistPresek(el, akt, patch) {
  Object.assign(akt, patch);
  const saved = await savePresekAktivnost(akt);
  if (!saved) throw new Error('save failed');
  Object.assign(akt, saved);
  const ind = el.querySelector('.zs-save-ind');
  if (ind) {
    ind.style.visibility = 'visible';
    setTimeout(() => { ind.style.visibility = 'hidden'; }, 1800);
  }
}

export async function renderZapisnikTab(host, { sastanak, canWrite, isReadOnly }) {
  abortFlag = false;
  const locked = isReadOnly || !canWrite;

  if (sastanak.status === 'planiran' && canWrite) {
    host.innerHTML = `
      <div class="sast-zapisnik-warn">
        ℹ Pre nego što počneš sa zapisnikom, klikni <strong>Počni sastanak</strong> u zaglavlju.
      </div>
    `;
    return;
  }

  host.innerHTML = '<div class="sast-loading">Učitavam zapisnik…</div>';

  let aktivnosti, slike;
  try {
    [aktivnosti, slike] = await Promise.all([
      loadPresekAktivnosti(sastanak.id),
      loadPresekSlike(sastanak.id),
    ]);
  } catch (e) {
    console.error('[ZapisnikTab] load error', e);
    host.innerHTML = '<div class="sast-empty">⚠ Greška pri učitavanju.</div>';
    return;
  }

  if (abortFlag) return;

  const slikeMap = new Map();
  slike.forEach(s => {
    if (!slikeMap.has(s.aktivnostId)) slikeMap.set(s.aktivnostId, []);
    slikeMap.get(s.aktivnostId).push(s);
  });

  renderZapisnikContent(host, aktivnosti, slikeMap, sastanak, locked);
}

function renderZapisnikContent(host, aktivnosti, slikeMap, sastanak, locked) {
  const pdfStaleHint = !locked && sastanak.status === 'u_toku' && sastanak.arhiva?.zapisnikStoragePath
    ? `<div class="zs-pdf-stale-hint" role="note">
        Postoji PDF zapisnik od ranijeg zaključavanja. Posle dopune zapisnika,
        <strong>ponovo zaključaj</strong> da se PDF uskladi sa bazom.
      </div>`
    : '';

  host.innerHTML = `
    <div class="sast-zapisnik">
      ${!locked ? `
        <div class="zs-save-bar" id="zsSaveBar" role="status" aria-live="polite">
          <span class="zs-save-bar-text" id="zsSaveBarText"></span>
          <button type="button" class="btn btn-sm btn-primary zs-save-now-btn" id="zsSaveNowBtn">Sačuvaj sada</button>
        </div>
        ${pdfStaleHint}
      ` : ''}
      <div class="sast-zapisnik-sections" id="zsSekcije">
        ${aktivnosti.map(a => renderSekcija(a, slikeMap.get(a.id) || [], locked)).join('')}
      </div>
      ${!locked ? `
        <button type="button" class="btn btn-primary sast-add-sekcija" id="zsAddSekcija">
          + Dodaj tačku dnevnog reda
        </button>
      ` : ''}
    </div>
  `;

  if (!locked) {
    bindSaveBar(host);
    registerZapisnikLifecycleListeners();
    wireDragDrop(host, aktivnosti);
    host.querySelector('#zsAddSekcija')?.addEventListener('click', async () => {
      const nova = await savePresekAktivnost({
        sastanakId: sastanak.id,
        naslov: 'Nova tačka',
        status: 'planiran',
        redosled: aktivnosti.length,
      });
      if (nova) {
        aktivnosti.push(nova);
        slikeMap.set(nova.id, []);
        const el = document.createElement('div');
        el.innerHTML = renderSekcija(nova, [], locked);
        const sekcija = el.firstElementChild;
        host.querySelector('#zsSekcije')?.appendChild(sekcija);
        wireSekcijaEvents(sekcija, nova, slikeMap, sastanak, locked, aktivnosti);
        sekcija.querySelector('.zs-naslov')?.focus();
        refreshSaveBar();
      } else {
        showToast('⚠ Nije uspelo');
      }
    });
  }

  host.querySelectorAll('.zs-sekcija').forEach(sekEl => {
    const id = sekEl.dataset.id;
    const akt = aktivnosti.find(a => a.id === id);
    if (akt) wireSekcijaEvents(sekEl, akt, slikeMap, sastanak, locked, aktivnosti);
  });
}

function renderSekcija(a, slike, locked) {
  const statusOptions = Object.entries(PRESEK_STATUSI)
    .map(([v, l]) => `<option value="${v}"${a.status === v ? ' selected' : ''}>${escHtml(l)}</option>`)
    .join('');

  return `
    <div class="zs-sekcija" data-id="${escHtml(a.id)}"
         draggable="${!locked ? 'true' : 'false'}">
      <div class="zs-sekcija-header">
        ${!locked ? '<span class="zs-drag-handle" aria-hidden="true">⠿</span>' : ''}
        ${!locked
          ? `<input type="text" class="input zs-naslov" value="${escHtml(a.naslov)}" placeholder="Naslov tačke…">`
          : `<strong class="zs-naslov-ro">${escHtml(a.naslov)}</strong>`
        }
        ${!locked ? `<button type="button" class="btn btn-sm btn-danger-ghost zs-del" data-id="${escHtml(a.id)}" title="Obriši sekciju">🗑</button>` : ''}
      </div>
      <div class="zs-sekcija-meta">
        <label>Pod RN
          <input type="text" class="input input-sm zs-pod-rn" value="${escHtml(a.podRn || '')}" ${locked ? 'disabled' : ''}>
        </label>
        <label>Odgovoran
          <input type="text" class="input input-sm zs-odg" value="${escHtml(a.odgLabel || a.odgText || '')}" ${locked ? 'disabled' : ''}>
        </label>
        <label>Rok
          <input type="date" class="input input-sm zs-rok" value="${escHtml(a.rok || '')}" ${locked ? 'disabled' : ''}>
        </label>
        <label>Status
          <select class="input input-sm zs-status" ${locked ? 'disabled' : ''}>${statusOptions}</select>
        </label>
      </div>
      <div class="zs-editor-wrap">
        <div class="zs-editor-toolbar" ${locked ? 'style="display:none"' : ''}>
          <button type="button" class="zs-tb" data-cmd="bold" title="Bold"><b>B</b></button>
          <button type="button" class="zs-tb" data-cmd="italic" title="Italic"><i>I</i></button>
          <button type="button" class="zs-tb" data-cmd="underline" title="Underline"><u>U</u></button>
          <button type="button" class="zs-tb" data-cmd="insertUnorderedList" title="Lista">≡</button>
          <button type="button" class="zs-tb" data-cmd="insertOrderedList" title="Broj.lista">1.</button>
        </div>
        <div class="zs-editor" contenteditable="${!locked}"
             data-id="${escHtml(a.id)}"
             ${locked ? '' : 'role="textbox" aria-multiline="true"'}
        >${a.sadrzajHtml || ''}</div>
        <span class="sast-save-indicator zs-save-ind" style="visibility:hidden">✓</span>
      </div>
      <div class="zs-slike-section">
        <div class="zs-slike-grid" data-id="${escHtml(a.id)}">
          ${slike.map(s => renderSlika(s)).join('')}
        </div>
        ${!locked ? `
          <label class="btn btn-sm zs-upload-btn" title="Dodaj sliku">
            📎 Dodaj sliku
            <input type="file" class="zs-file-input" accept="image/*,application/pdf" data-aid="${escHtml(a.id)}" style="display:none">
          </label>
        ` : ''}
      </div>
      ${a.napomena && locked ? `<p class="zs-napomena">${escHtml(a.napomena)}</p>` : ''}
    </div>
  `;
}

function renderSlika(s) {
  return `
    <div class="zs-slika-thumb" data-slika-id="${escHtml(s.id)}" data-path="${escHtml(s.storagePath)}">
      <span class="zs-slika-name" title="${escHtml(s.fileName)}">${escHtml(s.fileName || 'slika')}</span>
      <button type="button" class="zs-slika-del btn-danger-ghost" data-slika-id="${escHtml(s.id)}" data-path="${escHtml(s.storagePath)}" title="Obriši">✕</button>
    </div>
  `;
}

function wireSekcijaEvents(el, akt, slikeMap, sastanak, locked, aktivnosti) {
  if (locked) {
    wireSlikeView(el, akt);
    return;
  }

  const saveHtmlFromDom = async () => {
    const ed = el.querySelector('.zs-editor');
    if (!ed) return;
    let rawHtml = ed.innerHTML;
    const clean = sanitizeHtml(rawHtml);
    if (clean !== rawHtml) ed.innerHTML = clean;
    await persistPresek(el, akt, { sadrzajHtml: clean, sadrzajText: htmlToText(clean) });
  };

  el.querySelector('.zs-naslov')?.addEventListener('input', () => {
    scheduleDebouncedSave(`naslov_${akt.id}`, async () => {
      const v = el.querySelector('.zs-naslov')?.value ?? '';
      await persistPresek(el, akt, { naslov: v });
    });
  });
  el.querySelector('.zs-naslov')?.addEventListener('blur', () => flushSaveKey(`naslov_${akt.id}`));

  el.querySelector('.zs-pod-rn')?.addEventListener('input', () => {
    scheduleDebouncedSave(`pod_rn_${akt.id}`, async () => {
      const v = el.querySelector('.zs-pod-rn')?.value ?? '';
      await persistPresek(el, akt, { podRn: v });
    });
  });
  el.querySelector('.zs-pod-rn')?.addEventListener('blur', () => flushSaveKey(`pod_rn_${akt.id}`));

  el.querySelector('.zs-odg')?.addEventListener('input', () => {
    scheduleDebouncedSave(`odg_${akt.id}`, async () => {
      const v = el.querySelector('.zs-odg')?.value ?? '';
      await persistPresek(el, akt, { odgText: v, odgLabel: v });
    });
  });
  el.querySelector('.zs-odg')?.addEventListener('blur', () => flushSaveKey(`odg_${akt.id}`));

  el.querySelector('.zs-rok')?.addEventListener('change', e => {
    void runSaveNow(`rok_${akt.id}`, async () => {
      await persistPresek(el, akt, { rok: e.target.value || null });
    });
  });

  el.querySelector('.zs-status')?.addEventListener('change', e => {
    void runSaveNow(`status_${akt.id}`, async () => {
      await persistPresek(el, akt, { status: e.target.value });
    });
  });

  const editor = el.querySelector('.zs-editor');

  el.querySelectorAll('.zs-tb').forEach(btn => {
    btn.addEventListener('mousedown', e => {
      e.preventDefault();
      document.execCommand(btn.dataset.cmd, false, null);
      editor?.dispatchEvent(new Event('input', { bubbles: true }));
    });
  });

  if (editor) {
    editor.addEventListener('input', () => {
      scheduleDebouncedSave(`html_${akt.id}`, saveHtmlFromDom);
    });
    editor.addEventListener('blur', () => flushSaveKey(`html_${akt.id}`));
  }

  el.querySelector('.zs-del')?.addEventListener('click', async () => {
    if (!confirm('Obrisati ovu tačku? Sve slike se brišu.')) return;
    const ok = await deletePresekAktivnost(akt.id);
    if (ok) {
      el.remove();
      aktivnosti.splice(aktivnosti.findIndex(a => a.id === akt.id), 1);
    } else {
      showToast('⚠ Nije uspelo');
    }
  });

  el.querySelectorAll('.zs-file-input').forEach(inp => {
    inp.addEventListener('change', async () => {
      const file = inp.files[0];
      if (!file) return;
      inp.disabled = true;
      showToast('⏳ Upload…');
      const slika = await uploadPresekSlika(file, sastanak.id, akt.id);
      inp.value = '';
      inp.disabled = false;
      if (slika) {
        const grid = el.querySelector('.zs-slike-grid');
        if (grid) {
          const div = document.createElement('div');
          div.innerHTML = renderSlika(slika);
          const thumb = div.firstElementChild;
          grid.appendChild(thumb);
          wireSlikaDelete(thumb);
        }
        showToast('✅ Slika dodata');
      } else {
        showToast('⚠ Upload nije uspeo');
      }
    });
  });

  wireSlikaDelete(el);
  wireSlikeView(el, akt);
}

function wireSlikaDelete(container) {
  container.querySelectorAll('.zs-slika-del').forEach(btn => {
    btn.addEventListener('click', async () => {
      if (!confirm('Obrisati sliku?')) return;
      const ok = await deletePresekSlika(btn.dataset.slikaId, btn.dataset.path);
      if (ok) {
        btn.closest('.zs-slika-thumb')?.remove();
      } else {
        showToast('⚠ Nije uspelo');
      }
    });
  });
}

function wireSlikeView(container, akt) {
  container.querySelectorAll('.zs-slika-thumb').forEach(thumb => {
    thumb.addEventListener('click', async e => {
      if (e.target.classList.contains('zs-slika-del')) return;
      const path = thumb.dataset.path;
      if (!path) return;
      const url = await getPresekSlikaUrl(path);
      if (url) window.open(url, '_blank', 'noopener');
    });
  });
}

/* ── Drag-drop sekcija ── */

function wireDragDrop(host, aktivnosti) {
  const container = host.querySelector('#zsSekcije');
  if (!container) return;

  container.addEventListener('dragstart', e => {
    const sek = e.target.closest('.zs-sekcija[draggable="true"]');
    if (!sek) return;
    dragState = sek.dataset.id;
    sek.classList.add('is-dragging');
    e.dataTransfer.effectAllowed = 'move';
  });

  container.addEventListener('dragend', () => {
    container.querySelectorAll('.is-dragging,.drop-target-above,.drop-target-below').forEach(el => {
      el.classList.remove('is-dragging', 'drop-target-above', 'drop-target-below');
    });
    dragState = null;
  });

  container.addEventListener('dragover', e => {
    if (!dragState) return;
    const sek = e.target.closest('.zs-sekcija');
    if (!sek || sek.dataset.id === dragState) return;
    e.preventDefault();
    container.querySelectorAll('.drop-target-above,.drop-target-below').forEach(el => {
      el.classList.remove('drop-target-above', 'drop-target-below');
    });
    const rect = sek.getBoundingClientRect();
    sek.classList.add(e.clientY < rect.top + rect.height / 2 ? 'drop-target-above' : 'drop-target-below');
  });

  container.addEventListener('drop', async e => {
    e.preventDefault();
    if (!dragState) return;
    const targetSek = e.target.closest('.zs-sekcija');
    if (!targetSek || targetSek.dataset.id === dragState) { dragState = null; return; }

    await flushAllPendingSaves();

    const before = targetSek.classList.contains('drop-target-above');
    container.querySelectorAll('.drop-target-above,.drop-target-below,.is-dragging').forEach(el => {
      el.classList.remove('drop-target-above', 'drop-target-below', 'is-dragging');
    });

    const sekcije = [...container.querySelectorAll('.zs-sekcija')];
    const fromIdx = sekcije.findIndex(s => s.dataset.id === dragState);
    let toIdx = sekcije.findIndex(s => s.dataset.id === targetSek.dataset.id);
    if (fromIdx === -1 || toIdx === -1) { dragState = null; return; }

    const arr = aktivnosti.slice();
    const [moved] = arr.splice(fromIdx, 1);
    if (!before) toIdx += 1;
    if (fromIdx < toIdx) toIdx -= 1;
    arr.splice(toIdx, 0, moved);
    aktivnosti.length = 0;
    arr.forEach(a => aktivnosti.push(a));

    const draggedEl = sekcije[fromIdx];
    if (before) {
      container.insertBefore(draggedEl, targetSek);
    } else {
      targetSek.after(draggedEl);
    }
    dragState = null;

    const ok = await reorderPresekAktivnosti(aktivnosti);
    if (!ok) showToast('⚠ Redosled nije sačuvan');
  });
}

export function teardownZapisnikTab() {
  abortFlag = true;
  for (const [, st] of pendingSaves) clearTimeout(st.timer);
  const toRun = [...pendingSaves.entries()];
  pendingSaves.clear();
  for (const [key, st] of toRun) {
    void runSaveNow(key, st.exec);
  }
  zapisnikLifecycleCleanups.forEach(fn => fn());
  zapisnikLifecycleCleanups = [];
  saveBarEls = { root: null, text: null, saveNow: null };
  dragState = null;
}
