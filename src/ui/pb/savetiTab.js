/**
 * PB Saveti — lista + punostrani editor (bez modal overlay-a).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { getIsOnline, isAdmin, canWritePbEngTips } from '../../state/auth.js';
import {
  listEngTips,
  listEngTipCategories,
  canWriteEngTipLocal,
  canCurrentUserWriteEngTip,
  toggleEngTipLike,
} from '../../services/pbEngTips.js';
import { openTipDetailModal } from './tipDetailModal.js';
import { renderTipEditorPage } from './tipEditorPage.js';
import {
  snapshotEngTips,
  setEngTipsFilter,
  setEngTips,
  setEngTipCategories,
  setEngTipsLoading,
  setEngTipsError,
  setEngTipsCanWrite,
  subscribeEngTips,
  registerSavetiEditorOpener,
} from '../../state/pbEngTips.js';

let _searchDebounce = null;
let _unsub = null;
let _mountEl = null;
let _listCtx = null;
let _view = 'list';
/** @type {object|null} */
let _editorOpts = null;

/** Ako je tačno jedna kategorija u filteru, predloži je u editoru. */
function defaultTipFromCategoryFilter() {
  const ids = snapshotEngTips().filter.categoryIds || [];
  if (ids.length === 1) return { category_id: ids[0] };
  return null;
}

/**
 * @param {HTMLElement} mountEl
 * @param {{ projects?: object[], onRefresh?: () => void }} ctx
 */
export function renderSavetiTab(mountEl, ctx = {}) {
  _mountEl = mountEl;
  _listCtx = {
    ...ctx,
    projects: ctx.projects || [],
    engineers: ctx.engineers || [],
  };
  _view = 'list';
  _editorOpts = null;

  if (_unsub) {
    _unsub();
    _unsub = null;
  }

  registerSavetiEditorOpener(openSavetiTipEditor);

  setEngTipsCanWrite(canWriteEngTipLocal(_listCtx.engineers));

  paintSavetiView();

  _unsub = subscribeEngTips(s => {
    if (_view !== 'list') return;
    paintSavetiDom(mountEl, s, getIsOnline());
  });

  void loadCategoriesAndTips();
}

/**
 * Otvara editor kao punu stranicu u tabu Saveti (ne modal na body).
 * @param {object} opts
 */
export function openSavetiTipEditor(opts) {
  if (!_mountEl) {
    showToast('Otvorite tab Saveti pa pokušajte ponovo');
    return;
  }
  const engineers = _listCtx?.engineers || [];
  const canEdit = opts?.canEdit !== false
    && (canWriteEngTipLocal(engineers) || canWritePbEngTips());
  if (!canEdit) {
    showToast('Nemate pravo da kreirate ili menjate savete');
    return;
  }
  _view = 'editor';
  _editorOpts = { ...opts, canEdit: true };
  paintSavetiView();
}

function paintSavetiView() {
  if (!_mountEl) return;

  _mountEl.classList.toggle('pb-tab-body--saveti-editor', _view === 'editor');

  if (_view === 'editor' && _editorOpts) {
    const snap = snapshotEngTips();
    renderTipEditorPage(_mountEl, {
      tip: _editorOpts.tip ?? null,
      projects: _editorOpts.projects ?? _listCtx?.projects ?? [],
      categories: _editorOpts.categories ?? snap.categories,
      canEdit: _editorOpts.canEdit !== false,
      onBack: showSavetiList,
      onSaved: async () => {
        await reloadTips();
        _editorOpts.onSaved?.();
        _listCtx?.onRefresh?.();
      },
    });
    return;
  }

  showSavetiList();
}

function showSavetiList() {
  if (!_mountEl) return;
  _view = 'list';
  _editorOpts = null;
  _mountEl.classList.remove('pb-tab-body--saveti-editor');
  delete _mountEl.dataset.pbSavetiWired;

  _mountEl.innerHTML = savetiTabHtml(snapshotEngTips(), getIsOnline());
  wireSavetiTab(_mountEl, _listCtx || {});
  paintSavetiDom(_mountEl, snapshotEngTips(), getIsOnline());
}

function modalCtx(mountEl, ctx) {
  const snap = snapshotEngTips();
  return {
    projects: ctx.projects || [],
    categories: snap.categories,
    canWrite: snap.canWrite,
    onChanged: () => reloadTips(),
  };
}

function savetiCountLabel(s) {
  if (s.loading) return 'Učitavanje...';
  if (s.error) return '';
  const n = s.tips.length;
  if (!n) return 'Nema saveta za izabrane filtere';
  return n === 1 ? '1 savet' : `${n} saveta`;
}

function renderCategoryChipsHtml(s) {
  const f = s.filter;
  const chips = (s.categories || []).map(c => {
    const on = f.categoryIds.includes(c.id);
    return `<button type="button" class="pb-saveti-chip" data-cat-id="${escHtml(c.id)}" aria-pressed="${on ? 'true' : 'false'}">${escHtml(c.ikona || '')} ${escHtml(c.naziv)}</button>`;
  }).join('');
  return `
    <button type="button" class="pb-saveti-chip" data-cat-id="" aria-pressed="${f.categoryIds.length === 0 ? 'true' : 'false'}">Sve</button>
    ${chips}`;
}

function savetiTabHtml(s, online) {
  const f = s.filter;
  return `
    <div class="pb-saveti-root">
      ${!online ? '<div class="pb-readonly-banner" role="status">Saveti zahtevaju internet.</div>' : ''}
      <div class="pb-saveti-controls">
        <div class="pb-saveti-toolbar">
          <input type="search" class="pb-saveti-search" id="pbSavetiSearch" placeholder="Pretraga saveta..." value="${escHtml(f.search)}" ${online ? '' : 'disabled'} aria-label="Pretraga saveta" />
          <button type="button" class="pb-primary-btn pb-saveti-new-btn" id="pbSavetiNew" ${s.canWrite ? '' : 'hidden'} ${online ? '' : 'disabled'}>+ Novi savet</button>
        </div>
        <div class="pb-saveti-chips" id="pbSavetiChips" role="group" aria-label="Kategorije">
          ${renderCategoryChipsHtml(s)}
        </div>
        <div class="pb-saveti-toggles-row">
          <div class="pb-saveti-toggles">
            <label class="pb-saveti-toggle"><input type="radio" name="pbSavetiSort" value="recent" ${f.sort !== 'popular' ? 'checked' : ''} /> Najnoviji</label>
            <label class="pb-saveti-toggle"><input type="radio" name="pbSavetiSort" value="popular" ${f.sort === 'popular' ? 'checked' : ''} /> Najpopularniji</label>
            <label class="pb-saveti-toggle"><input type="checkbox" id="pbSavetiMyOnly" ${f.myOnly ? 'checked' : ''} /> Samo moji</label>
            <label class="pb-saveti-toggle" id="pbSavetiDraftsWrap" ${s.canWrite ? '' : 'hidden'}><input type="checkbox" id="pbSavetiDrafts" ${f.includeDrafts ? 'checked' : ''} /> Drafts</label>
          </div>
          <p class="pb-saveti-count" id="pbSavetiCount" aria-live="polite">${escHtml(savetiCountLabel(s))}</p>
        </div>
      </div>
      <div class="pb-saveti-list-wrap" id="pbSavetiListWrap">
        ${renderTipsListInner(s)}
      </div>
    </div>`;
}

function renderTipsListInner(s) {
  if (s.loading) {
    return '<div class="pb-saveti-state"><p class="pb-muted">Učitavanje...</p></div>';
  }
  if (s.error) {
    return `<div class="pb-saveti-state pb-saveti-state--error"><p class="pb-muted">${escHtml(String(s.error))}</p></div>`;
  }
  if (!s.tips.length) {
    return `<div class="pb-saveti-state">
      <p class="pb-saveti-empty-title">Nema saveta</p>
      <p class="pb-muted">Promenite filtere ili pretragu, ili dodajte prvi savet.</p>
    </div>`;
  }
  return `<div class="pb-tips-list">${s.tips.map(t => renderTipCard(t)).join('')}</div>`;
}

function renderTipCard(tip) {
  const boja = tip.category_boja || '#64748b';
  const draft = tip.status === 'draft'
    ? '<span class="pb-tip-draft-badge">DRAFT</span>'
    : '';
  const tags = (tip.tags || []).map(t => `<span class="pb-tip-tag">#${escHtml(t)}</span>`).join('');
  const files = tip.files_count > 0 ? `&#128206; ${tip.files_count}` : '';
  const liked = tip.is_liked_by_me ? ' liked' : '';
  return `
    <article class="pb-tip-card" data-tip-id="${escHtml(tip.id)}" role="button" tabindex="0" aria-label="Otvori savet ${escHtml(tip.naslov)}">
      <header class="pb-tip-card-head">
        <span class="pb-tip-cat-badge" style="background:${escHtml(boja)}1a;color:${escHtml(boja)}">
          ${escHtml(tip.category_ikona || '')} ${escHtml(tip.category_naziv || 'Razno')}
        </span>
        <span class="pb-tip-card-meta">${escHtml(formatShortDate(tip.created_at))} &middot; ${escHtml(tip.author_full_name || '')}</span>
        ${draft}
      </header>
      <h3 class="pb-tip-card-title">${escHtml(tip.naslov)}</h3>
      <p class="pb-tip-card-excerpt">${escHtml(tip.excerpt || '')}</p>
      <footer class="pb-tip-card-foot">
        <span class="pb-tip-tags">${tags}</span>
        <span class="pb-tip-card-stats">
          ${files}
          <button type="button" class="pb-tip-like-btn${liked}" data-tip-like="${escHtml(tip.id)}">&#128077; ${Number(tip.likes_count) || 0}</button>
        </span>
      </footer>
    </article>`;
}

function formatShortDate(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleDateString('sr-RS');
}

function paintSavetiChips(mountEl, s) {
  const wrap = mountEl.querySelector('#pbSavetiChips');
  if (wrap) wrap.innerHTML = renderCategoryChipsHtml(s);
}

function paintSavetiDom(mountEl, s, online) {
  const wrap = mountEl.querySelector('#pbSavetiListWrap');
  if (wrap) wrap.innerHTML = renderTipsListInner(s);
  const countEl = mountEl.querySelector('#pbSavetiCount');
  if (countEl) countEl.textContent = savetiCountLabel(s);
  const search = mountEl.querySelector('#pbSavetiSearch');
  if (search && search.value !== (s.filter.search || '')) search.value = s.filter.search || '';
  paintSavetiChips(mountEl, s);
  const newBtn = mountEl.querySelector('#pbSavetiNew');
  if (newBtn) {
    newBtn.hidden = !s.canWrite;
    newBtn.disabled = !online;
  }
  const draftsWrap = mountEl.querySelector('#pbSavetiDraftsWrap');
  if (draftsWrap) draftsWrap.hidden = !s.canWrite;
}

function wireSavetiTab(root, ctx) {
  if (root.dataset.pbSavetiWired === '1') return;
  root.dataset.pbSavetiWired = '1';

  root.querySelector('#pbSavetiSearch')?.addEventListener('input', e => {
    const v = e.target.value || '';
    setEngTipsFilter({ search: v });
    if (_searchDebounce) clearTimeout(_searchDebounce);
    _searchDebounce = setTimeout(() => { void reloadTips(); }, 250);
  });

  root.querySelector('#pbSavetiChips')?.addEventListener('click', e => {
    const btn = e.target.closest('[data-cat-id]');
    if (!btn) return;
    const id = btn.dataset.catId || '';
    const snap = snapshotEngTips();
    let ids = [...snap.filter.categoryIds];
    if (!id) {
      ids = [];
    } else if (ids.includes(id)) {
      ids = ids.filter(x => x !== id);
    } else {
      ids.push(id);
    }
    setEngTipsFilter({ categoryIds: ids });
    void reloadTips();
  });

  root.querySelectorAll('input[name="pbSavetiSort"]').forEach(inp => {
    inp.addEventListener('change', () => {
      if (!inp.checked) return;
      setEngTipsFilter({ sort: inp.value === 'popular' ? 'popular' : 'recent' });
      void reloadTips();
    });
  });

  root.querySelector('#pbSavetiMyOnly')?.addEventListener('change', e => {
    setEngTipsFilter({ myOnly: !!e.target.checked });
    void reloadTips();
  });

  root.querySelector('#pbSavetiDrafts')?.addEventListener('change', e => {
    setEngTipsFilter({ includeDrafts: !!e.target.checked });
    void reloadTips();
  });

  root.addEventListener('click', e => {
    if (!e.target.closest('#pbSavetiNew')) return;
    e.preventDefault();
    e.stopPropagation();
    const m = modalCtx(root, ctx);
    openSavetiTipEditor({
      tip: defaultTipFromCategoryFilter(),
      projects: m.projects,
      categories: m.categories,
      canEdit: true,
      onSaved: m.onChanged,
    });
  });

  root.querySelector('#pbSavetiListWrap')?.addEventListener('click', e => {
    const likeBtn = e.target.closest('[data-tip-like]');
    if (likeBtn) {
      e.stopPropagation();
      void handleTipLike(likeBtn);
      return;
    }
    const card = e.target.closest('[data-tip-id]');
    if (!card) return;
    const tipId = card.getAttribute('data-tip-id');
    if (!tipId) return;
    void openTipDetailModal({ tipId, ...modalCtx(root, ctx) });
  });

  root.querySelector('#pbSavetiListWrap')?.addEventListener('keydown', e => {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    const card = e.target.closest('[data-tip-id]');
    if (!card || e.target.closest('[data-tip-like]')) return;
    e.preventDefault();
    const tipId = card.getAttribute('data-tip-id');
    if (tipId) void openTipDetailModal({ tipId, ...modalCtx(root, ctx) });
  });
}

async function handleTipLike(btn) {
  const id = btn.getAttribute('data-tip-like');
  if (!id) return;
  const tips = snapshotEngTips().tips;
  const tip = tips.find(t => t.id === id);
  const prevLiked = !!tip?.is_liked_by_me;
  const prevCount = Number(tip?.likes_count) || 0;
  const nextLiked = !prevLiked;
  const nextCount = Math.max(0, prevCount + (nextLiked ? 1 : -1));
  if (tip) {
    tip.is_liked_by_me = nextLiked;
    tip.likes_count = nextCount;
    setEngTips([...tips]);
  }
  btn.disabled = true;
  try {
    const r = await toggleEngTipLike(id);
    if (r && tip) {
      tip.is_liked_by_me = r.liked;
      tip.likes_count = r.likes_count;
      setEngTips([...tips]);
    }
  } catch (err) {
    if (tip) {
      tip.is_liked_by_me = prevLiked;
      tip.likes_count = prevCount;
      setEngTips([...tips]);
    }
    showToast(err?.message || 'Greška');
  } finally {
    btn.disabled = false;
  }
}

async function loadCategoriesAndTips() {
  if (!getIsOnline()) {
    setEngTipsError('Saveti zahtevaju internet');
    setEngTips([]);
    return;
  }
  const engineers = _listCtx?.engineers || [];
  setEngTipsCanWrite(canWriteEngTipLocal(engineers));
  setEngTipsLoading(true);
  setEngTipsError(null);
  try {
    const cats = await listEngTipCategories();
    setEngTipCategories(cats);
    if (isAdmin() && !snapshotEngTips().filter.includeDrafts) {
      setEngTipsFilter({ includeDrafts: true });
    }
    await reloadTips();
  } catch (err) {
    setEngTipsError(err?.message || 'Greška pri učitavanju');
    showToast(err?.message || 'Greška pri učitavanju');
  } finally {
    setEngTipsLoading(false);
  }
  void canCurrentUserWriteEngTip(engineers).then(ok => {
    if (_view === 'list') setEngTipsCanWrite(!!ok);
  });
}

async function reloadTips() {
  if (!getIsOnline()) return;
  const { filter } = snapshotEngTips();
  try {
    const tips = await listEngTips({
      search: filter.search,
      categoryIds: filter.categoryIds,
      tags: filter.tags,
      myOnly: filter.myOnly,
      includeDrafts: filter.includeDrafts || isAdmin(),
      sort: filter.sort,
    });
    setEngTips(tips);
    setEngTipsError(null);
  } catch (err) {
    setEngTipsError(err?.message || 'Greška pri učitavanju');
    showToast(err?.message || 'Greška');
  }
}

export async function refreshSavetiCategories() {
  if (!getIsOnline()) return;
  try {
    const cats = await listEngTipCategories();
    setEngTipCategories(cats);
  } catch (err) {
    console.warn('[saveti] refreshSavetiCategories', err);
  }
}
