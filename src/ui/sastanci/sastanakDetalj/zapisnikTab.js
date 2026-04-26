/**
 * Zapisnik tab — presek_aktivnosti sa rich-text editorom i upload slika.
 *
 * Svaka sekcija = jedan red presek_aktivnosti:
 *   - naslov, pod_rn, odgovoran, rok, status, sadrzaj (rich-text), slike
 * Drag-drop za reorder sekcija (redosled kolona).
 * Auto-save: debounce 800ms po polju.
 * Upload slika → Storage 'sastanak-slike' → presek_slike.
 */

import { escHtml, showToast } from '../../../lib/dom.js';
import { SAVE_DEBOUNCE_MS } from '../../../lib/constants.js';
import { sanitizeHtml, htmlToText } from '../../../lib/htmlSanitize.js';
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
let debounceTimers = {};
let dragState = null;

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
  host.innerHTML = `
    <div class="sast-zapisnik">
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

  const debounce = (key, fn) => {
    clearTimeout(debounceTimers[key]);
    debounceTimers[key] = setTimeout(fn, SAVE_DEBOUNCE_MS);
  };

  const saveAkt = async (patch) => {
    Object.assign(akt, patch);
    await savePresekAktivnost(akt);
    const ind = el.querySelector('.zs-save-ind');
    if (ind) { ind.style.visibility = 'visible'; setTimeout(() => { ind.style.visibility = 'hidden'; }, 1800); }
  };

  el.querySelector('.zs-naslov')?.addEventListener('input', e => {
    debounce('naslov_' + akt.id, () => saveAkt({ naslov: e.target.value }));
  });

  el.querySelector('.zs-pod-rn')?.addEventListener('input', e => {
    debounce('pod_rn_' + akt.id, () => saveAkt({ podRn: e.target.value }));
  });

  el.querySelector('.zs-odg')?.addEventListener('input', e => {
    debounce('odg_' + akt.id, () => saveAkt({ odgText: e.target.value, odgLabel: e.target.value }));
  });

  el.querySelector('.zs-rok')?.addEventListener('change', e => {
    saveAkt({ rok: e.target.value || null });
  });

  el.querySelector('.zs-status')?.addEventListener('change', e => {
    saveAkt({ status: e.target.value });
  });

  /* Rich-text toolbar */
  el.querySelectorAll('.zs-tb').forEach(btn => {
    btn.addEventListener('mousedown', e => {
      e.preventDefault();
      document.execCommand(btn.dataset.cmd, false, null);
    });
  });

  /* Rich-text editor auto-save */
  const editor = el.querySelector('.zs-editor');
  if (editor) {
    editor.addEventListener('input', () => {
      debounce('html_' + akt.id, () => {
        const rawHtml = editor.innerHTML;
        const clean = sanitizeHtml(rawHtml);
        if (clean !== rawHtml) editor.innerHTML = clean;
        saveAkt({ sadrzajHtml: clean, sadrzajText: htmlToText(clean) });
      });
    });
  }

  /* Delete sekcija */
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

  /* Upload slika */
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
  Object.values(debounceTimers).forEach(t => clearTimeout(t));
  debounceTimers = {};
  dragState = null;
}
