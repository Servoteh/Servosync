/**
 * PB Saveti — lista, filteri (skeleton; detalj/editor u koraku 4).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { getIsOnline } from '../../state/auth.js';
import {
  listEngTips,
  listEngTipCategories,
  canCurrentUserWriteEngTip,
} from '../../services/pbEngTips.js';
import {
  snapshotEngTips,
  setEngTipsFilter,
  setEngTips,
  setEngTipCategories,
  setEngTipsLoading,
  setEngTipsError,
  setEngTipsCanWrite,
  subscribeEngTips,
} from '../../state/pbEngTips.js';

let _searchDebounce = null;
let _unsub = null;

/**
 * @param {HTMLElement} mountEl
 * @param {{ projects?: object[], onRefresh?: () => void }} ctx
 */
export function renderSavetiTab(mountEl, ctx = {}) {
  if (_unsub) {
    _unsub();
    _unsub = null;
  }
  mountEl.innerHTML = savetiTabHtml(snapshotEngTips(), getIsOnline());
  _unsub = subscribeEngTips(s => {
    paintSavetiDom(mountEl, s, getIsOnline());
  });
  wireSavetiTab(mountEl, ctx);
  void loadCategoriesAndTips(ctx);
}

function savetiTabHtml(s, online) {
  const f = s.filter;
  const chips = (s.categories || []).map(c => {
    const on = f.categoryIds.includes(c.id);
    return `<button type="button" class="pb-saveti-chip" data-cat-id="${escHtml(c.id)}" aria-pressed="${on ? 'true' : 'false'}">${escHtml(c.ikona || '')} ${escHtml(c.naziv)}</button>`;
  }).join('');

  return `
    <div class="pb-saveti-root">
      ${!online ? '<div class="pb-readonly-banner" role="status">Saveti zahtevaju internet.</div>' : ''}
      <div class="pb-saveti-toolbar">
        <h2 class="pb-saveti-title">Saveti</h2>
        <input type="search" class="pb-saveti-search" id="pbSavetiSearch" placeholder="Pretraga saveta..." value="${escHtml(f.search)}" ${online ? '' : 'disabled'} />
        ${s.canWrite ? `<button type="button" class="pb-primary-btn" id="pbSavetiNew" ${online ? '' : 'disabled'}>+ Novi savet</button>` : ''}
      </div>
      <div class="pb-saveti-chips" id="pbSavetiChips">
        <button type="button" class="pb-saveti-chip" data-cat-id="" aria-pressed="${f.categoryIds.length === 0 ? 'true' : 'false'}">Sve</button>
        ${chips}
      </div>
      <div class="pb-saveti-toggles">
        <label class="pb-saveti-toggle"><input type="radio" name="pbSavetiSort" value="recent" ${f.sort !== 'popular' ? 'checked' : ''} /> Najnoviji</label>
        <label class="pb-saveti-toggle"><input type="radio" name="pbSavetiSort" value="popular" ${f.sort === 'popular' ? 'checked' : ''} /> Najpopularniji</label>
        <label class="pb-saveti-toggle"><input type="checkbox" id="pbSavetiMyOnly" ${f.myOnly ? 'checked' : ''} /> Samo moji</label>
        <label class="pb-saveti-toggle"><input type="checkbox" id="pbSavetiDrafts" ${f.includeDrafts ? 'checked' : ''} /> Drafts</label>
      </div>
      <div class="pb-saveti-list-wrap" id="pbSavetiListWrap">
        ${renderTipsListInner(s)}
      </div>
    </div>`;
}

function renderTipsListInner(s) {
  if (s.loading) {
    return '<p class="pb-muted">U\u010ditavanje...</p>';
  }
  if (s.error) {
    return `<p class="pb-muted">${escHtml(String(s.error))}</p>`;
  }
  if (!s.tips.length) {
    return '<p class="pb-muted">Nema saveta za izabrane filtere.</p>';
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

function paintSavetiDom(mountEl, s, online) {
  const wrap = mountEl.querySelector('#pbSavetiListWrap');
  if (wrap) wrap.innerHTML = renderTipsListInner(s);
  const search = mountEl.querySelector('#pbSavetiSearch');
  if (search && search.value !== (s.filter.search || '')) search.value = s.filter.search || '';
  mountEl.querySelectorAll('.pb-saveti-chip').forEach(btn => {
    const id = btn.dataset.catId || '';
    const on = id
      ? s.filter.categoryIds.includes(id)
      : s.filter.categoryIds.length === 0;
    btn.setAttribute('aria-pressed', on ? 'true' : 'false');
  });
  const newBtn = mountEl.querySelector('#pbSavetiNew');
  if (newBtn) newBtn.disabled = !online;
}

function wireSavetiTab(root, ctx) {
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

  root.querySelector('#pbSavetiNew')?.addEventListener('click', () => {
    showToast('Editor saveta dolazi u slede\u0107em koraku.');
  });

  root.querySelector('#pbSavetiListWrap')?.addEventListener('click', e => {
    if (e.target.closest('[data-tip-like]')) return;
    const card = e.target.closest('[data-tip-id]');
    if (!card) return;
    showToast('Detalj saveta dolazi u slede\u0107em koraku.');
  });
}

async function loadCategoriesAndTips(ctx) {
  if (!getIsOnline()) {
    setEngTipsError('Saveti zahtevaju internet');
    setEngTips([]);
    return;
  }
  setEngTipsLoading(true);
  setEngTipsError(null);
  try {
    const [cats, canWrite] = await Promise.all([
      listEngTipCategories(),
      canCurrentUserWriteEngTip(),
    ]);
    setEngTipCategories(cats);
    setEngTipsCanWrite(canWrite);
    await reloadTips();
  } catch (err) {
    setEngTipsError(err?.message || 'Gre\u0161ka pri u\u010ditavanju');
    showToast(err?.message || 'Gre\u0161ka pri u\u010ditavanju');
  } finally {
    setEngTipsLoading(false);
  }
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
      includeDrafts: filter.includeDrafts,
      sort: filter.sort,
    });
    setEngTips(tips);
    setEngTipsError(null);
  } catch (err) {
    setEngTipsError(err?.message || 'Gre\u0161ka pri u\u010ditavanju');
    showToast(err?.message || 'Gre\u0161ka');
  }
}
