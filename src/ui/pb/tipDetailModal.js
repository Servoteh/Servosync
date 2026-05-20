import { escHtml, showToast } from '../../lib/dom.js';
import {
  getEngTip,
  softDeleteEngTip,
  toggleEngTipLike,
  getEngTipFileSignedUrl,
} from '../../services/pbEngTips.js';
import { markdownToHtml } from './markdown.js';
import { openSavetiTipEditor } from '../../state/pbEngTips.js';
import {
  pbTipModalShell,
  wirePbTipModal,
  canManageEngTip,
  formatTipDate,
  navigatePbToProject,
} from './tipModalShared.js';

/**
 * @param {{ tipId: string, projects?: object[], categories?: object[], canWrite?: boolean, onChanged?: () => void }} opts
 */
export async function openTipDetailModal(opts) {
  const { tipId, projects = [], categories = [], canWrite = false, onChanged } = opts || {};
  if (!tipId) return;

  const { cls } = pbTipModalShell();
  const wrap = document.createElement('div');
  wrap.className = cls;
  wrap.innerHTML = `
    <div class="modal-panel pb-tip-panel" role="dialog" aria-busy="true">
      <div class="pb-modal-head">
        <h2>U\u010ditavanje...</h2>
        <button type="button" class="btn btn-ghost pb-close-modal" aria-label="Zatvori">&#10005;</button>
      </div>
      <div class="pb-tip-detail-body"><p class="pb-muted">U\u010ditavanje...</p></div>
    </div>`;
  document.body.appendChild(wrap);
  const { close } = wirePbTipModal(wrap, '.pb-tip-panel');

  try {
    const tip = await getEngTip(tipId);
    if (!tip) throw new Error('Savet nije prona\u0111en');
    const files = Array.isArray(tip.files) ? tip.files : [];
    await Promise.all(files.map(async f => {
      if (f.storage_path) {
        f.signed_url = await getEngTipFileSignedUrl(f.storage_path, 3600);
      }
    }));
    renderDetail(wrap, tip, { projects, categories, canWrite, onChanged, close });
  } catch (err) {
    showToast(err?.message || 'Gre\u0161ka');
    close();
  }
}

function renderDetail(wrap, tip, ctx) {
  const canManage = canManageEngTip(tip);
  const cat = tip.category || {};
  const boja = cat.boja || '#64748b';
  const proj = tip.project;
  const authorName = tip.author?.full_name || tip.author_email || '';
  const tags = (tip.tags || []).map(t => `<span class="pb-tip-tag">#${escHtml(t)}</span>`).join('');
  const bodyHtml = markdownToHtml(tip.telo || '');
  const draftHtml = tip.status === 'draft' ? ' <span class="pb-tip-draft-badge">DRAFT</span>' : '';

  const filesHtml = (tip.files || []).map(f => {
    if (f.is_image && f.signed_url) {
      return `<figure class="pb-tip-attach-img"><img class="pb-tip-image" src="${escHtml(f.signed_url)}" alt="${escHtml(f.file_name)}" loading="lazy" /></figure>`;
    }
    if (f.signed_url) {
      return `<p><a class="pb-tip-pdf-link" href="${escHtml(f.signed_url)}" target="_blank" rel="noopener" download>${escHtml(f.file_name || 'PDF')}</a></p>`;
    }
    return `<p class="pb-muted">${escHtml(f.file_name || 'Prilog')}</p>`;
  }).join('');

  const projLink = proj?.id
    ? `<button type="button" class="btn btn-ghost btn-sm" id="pbTipGoProject">Povezano: ${escHtml(proj.project_code || proj.project_name || 'Projekat')}</button>`
    : '';

  const panel = wrap.querySelector('.pb-tip-panel');
  if (!panel) return;
  panel.removeAttribute('aria-busy');
  panel.innerHTML = `
    <div class="pb-modal-head">
      <span class="pb-tip-cat-badge" style="background:${escHtml(boja)}1a;color:${escHtml(boja)}">
        ${escHtml(cat.ikona || '')} ${escHtml(cat.naziv || '')}
      </span>
      <button type="button" class="btn btn-ghost pb-close-modal" aria-label="Zatvori">&#10005;</button>
    </div>
    <h2 class="pb-tip-detail-title">${escHtml(tip.naslov)}</h2>
    <p class="pb-tip-detail-meta">${escHtml(authorName)} &middot; ${escHtml(formatTipDate(tip.created_at))}${draftHtml}</p>
    ${projLink}
    ${tip.url ? `<p><a href="${escHtml(tip.url)}" target="_blank" rel="noopener">${escHtml(tip.url)}</a></p>` : ''}
    ${tip.vendor ? `<p class="pb-muted">Dobavlja\u010d: ${escHtml(tip.vendor)}</p>` : ''}
    <div class="pb-tip-detail-md">${bodyHtml}</div>
    ${filesHtml ? `<div class="pb-tip-detail-files">${filesHtml}</div>` : ''}
    <div class="pb-tip-tags pb-tip-detail-tags">${tags}</div>
    <div class="pb-modal-actions pb-tip-detail-actions">
      <button type="button" class="pb-tip-like-btn${tip.is_liked_by_me ? ' liked' : ''}" id="pbTipLikeBtn">&#128077; Korisno (${Number(tip.likes_count) || 0})</button>
      ${canManage ? '<button type="button" class="btn" id="pbTipEditBtn">Izmeni</button>' : ''}
      ${canManage ? '<button type="button" class="btn btn-ghost pb-tip-del-btn" id="pbTipDelBtn">Obri\u0161i</button>' : ''}
      <button type="button" class="btn" id="pbTipCloseBtn">Zatvori</button>
    </div>`;

  wrap.querySelector('#pbTipCloseBtn')?.addEventListener('click', ctx.close);
  wrap.querySelector('#pbTipGoProject')?.addEventListener('click', () => {
    void navigatePbToProject(proj.id, ctx.close);
  });

  wrap.querySelector('#pbTipLikeBtn')?.addEventListener('click', async () => {
    const btn = wrap.querySelector('#pbTipLikeBtn');
    if (!btn) return;
    btn.disabled = true;
    try {
      const r = await toggleEngTipLike(tip.id);
      if (r) {
        tip.is_liked_by_me = r.liked;
        tip.likes_count = r.likes_count;
        btn.classList.toggle('liked', !!r.liked);
        btn.textContent = `\u{1F44D} Korisno (${r.likes_count})`;
        ctx.onChanged?.();
      }
    } catch (e) {
      showToast(e?.message || 'Gre\u0161ka');
    } finally {
      btn.disabled = false;
    }
  });

  wrap.querySelectorAll('.pb-close-modal').forEach(btn => {
    btn.addEventListener('click', ctx.close);
  });

  wrap.querySelector('#pbTipEditBtn')?.addEventListener('click', () => {
    ctx.close();
    openSavetiTipEditor({
      tip,
      projects: ctx.projects,
      categories: ctx.categories,
      canEdit: canManage,
      onSaved: () => ctx.onChanged?.(),
    });
  });

  wrap.querySelector('#pbTipDelBtn')?.addEventListener('click', async () => {
    if (!confirm('Obrisati savet?')) return;
    try {
      await softDeleteEngTip(tip.id);
      showToast('Obrisano');
      ctx.close();
      ctx.onChanged?.();
    } catch (e) {
      showToast(e?.message || 'Brisanje nije uspelo');
    }
  });
}
