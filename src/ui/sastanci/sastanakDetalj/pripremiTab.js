/**
 * Priprema tab — mesto/vreme, učesnici (RSVP), dnevni red (pm_teme), beleška.
 */

import { escHtml, showToast } from '../../../lib/dom.js';
import { formatDate } from '../../../lib/date.js';
import { SAVE_DEBOUNCE_MS } from '../../../lib/constants.js';
import { sbReq } from '../../../services/supabase.js';
import { saveSastanak, saveUcesnici, loadUcesnici, SASTANAK_TIPOVI } from '../../../services/sastanci.js';
import {
  loadPmTemeForSastanak,
  addUcesnik, removeUcesnik,
  updateUcesnikPozvan, updateUcesnikPrisustvo,
  reorderPmTeme,
  updateTemaAdminRang,
} from '../../../services/sastanciDetalj.js';
import { loadUsersFromDb } from '../../../services/users.js';
import { isAdmin } from '../../../state/auth.js';

let abortFlag = false;
let debounceTimer = null;
let dragState = null;

export async function renderPripremiTab(host, { sastanak, canWrite, isReadOnly }) {
  abortFlag = false;
  host.innerHTML = '<div class="sast-loading">Učitavam pripremu…</div>';

  let teme, users;
  try {
    [teme, users] = await Promise.all([
      loadPmTemeForSastanak(sastanak.id),
      canWrite ? loadUsersFromDb() : Promise.resolve([]),
    ]);
  } catch (e) {
    console.error('[PripremiTab] load error', e);
    host.innerHTML = '<div class="sast-empty">⚠ Greška pri učitavanju.</div>';
    return;
  }

  if (abortFlag) return;
  renderContent(host, sastanak, teme, users || [], { canWrite, isReadOnly });
}

function renderContent(host, sastanak, teme, users, { canWrite, isReadOnly }) {
  const ucesnici = sastanak.ucesnici || [];
  const admin = isAdmin();

  host.innerHTML = `
    <div class="sast-pripremi">

      <!-- Mesto i vreme -->
      <section class="sast-pripremi-section">
        <div class="sast-section-header">
          <h3>📍 Mesto i vreme</h3>
          ${canWrite && !isReadOnly ? `<button type="button" class="btn btn-sm" id="sdEditMeta">Uredi</button>` : ''}
        </div>
        <div class="sast-meta-grid" id="sdMeta">
          ${renderMetaGrid(sastanak)}
        </div>
      </section>

      <!-- Učesnici -->
      <section class="sast-pripremi-section">
        <div class="sast-section-header">
          <h3>👥 Učesnici</h3>
          ${canWrite && !isReadOnly ? `<button type="button" class="btn btn-sm" id="sdAddUcesnik">+ Dodaj učesnika</button>` : ''}
        </div>
        <div id="sdUcesniciTable">${renderUcesniciTable(ucesnici, canWrite, isReadOnly, sastanak.status)}</div>
        ${canWrite && !isReadOnly ? `
          <div class="sast-add-ucesnik-form" id="sdAddUcesnikForm" style="display:none">
            <input type="text" class="input input-sm" id="sdUcesnikEmail" placeholder="Email ili ime…" list="sdUsersList" autocomplete="off">
            <datalist id="sdUsersList">
              ${users.map(u => `<option value="${escHtml(u.email)}">${escHtml(u.email)}</option>`).join('')}
            </datalist>
            <button type="button" class="btn btn-sm btn-primary" id="sdAddUcesnikSave">Dodaj</button>
            <button type="button" class="btn btn-sm" id="sdAddUcesnikCancel">Otkaži</button>
          </div>
        ` : ''}
      </section>

      <!-- Dnevni red -->
      <section class="sast-pripremi-section">
        <div class="sast-section-header">
          <h3>📋 Dnevni red</h3>
          ${canWrite && !isReadOnly ? `<button type="button" class="btn btn-sm" id="sdOtkaci" style="display:none">Otkači temu</button>` : ''}
        </div>
        <div id="sdTemeList">${renderTemeList(teme, canWrite, isReadOnly, admin)}</div>
      </section>

      <!-- Beleška organizatora -->
      <section class="sast-pripremi-section">
        <div class="sast-section-header">
          <h3>📒 Beleška organizatora</h3>
        </div>
        ${canWrite && !isReadOnly
          ? `<textarea class="sast-napomena-ta" id="sdNapomena" rows="4" placeholder="Interne napomene…">${escHtml(sastanak.napomena || '')}</textarea>
             <span class="sast-save-indicator" id="sdNapSave" style="visibility:hidden">✓ Sačuvano</span>`
          : `<div class="sast-napomena-ro">${escHtml(sastanak.napomena || '—')}</div>`
        }
      </section>
    </div>
  `;

  if (canWrite && !isReadOnly) {
    wireEditMeta(host, sastanak);
    wireAddUcesnik(host, sastanak, users);
    wireUcesniciToggles(host, sastanak.id);
    wireTemeReorder(host, teme, admin);
    wireNapomena(host, sastanak);
  } else {
    wireUcesniciToggles(host, sastanak.id, true);
  }
}

/* ── Meta display ── */

function renderMetaGrid(s) {
  return `
    <div class="sast-meta-row"><span>Tip</span><span>${escHtml(SASTANAK_TIPOVI[s.tip] || s.tip)}</span></div>
    <div class="sast-meta-row"><span>Datum</span><span>${formatDate(s.datum)}</span></div>
    <div class="sast-meta-row"><span>Vreme</span><span>${s.vreme ? s.vreme.slice(0, 5) : '—'}</span></div>
    <div class="sast-meta-row"><span>Mesto</span><span>${escHtml(s.mesto || '—')}</span></div>
    <div class="sast-meta-row"><span>Vodio</span><span>${escHtml(s.vodioLabel || s.vodioEmail || '—')}</span></div>
    <div class="sast-meta-row"><span>Zapisničar</span><span>${escHtml(s.zapisnicarLabel || s.zapisnicarEmail || '—')}</span></div>
  `;
}

function wireEditMeta(host, sastanak) {
  host.querySelector('#sdEditMeta')?.addEventListener('click', () => {
    openMetaModal(host, sastanak);
  });
}

function openMetaModal(host, sastanak) {
  const overlay = document.createElement('div');
  overlay.className = 'sast-modal-overlay';
  overlay.innerHTML = `
    <div class="sast-modal" role="dialog" aria-modal="true">
      <header class="sast-modal-header">
        <h3>Uredi sastanak</h3>
        <button type="button" class="sast-modal-close" aria-label="Zatvori">✕</button>
      </header>
      <div class="sast-modal-body">
        <label class="sast-form-label">Naslov
          <input type="text" class="input" id="editNaslov" value="${escHtml(sastanak.naslov)}">
        </label>
        <div class="sast-form-row2">
          <label class="sast-form-label">Datum
            <input type="date" class="input" id="editDatum" value="${escHtml(sastanak.datum || '')}">
          </label>
          <label class="sast-form-label">Vreme
            <input type="time" class="input" id="editVreme" value="${escHtml(sastanak.vreme ? sastanak.vreme.slice(0,5) : '')}">
          </label>
        </div>
        <label class="sast-form-label">Mesto
          <input type="text" class="input" id="editMesto" value="${escHtml(sastanak.mesto || '')}">
        </label>
      </div>
      <footer class="sast-modal-footer">
        <button type="button" class="btn btn-primary" id="editMetaSave">Sačuvaj</button>
        <button type="button" class="btn" data-action="close">Otkaži</button>
      </footer>
    </div>
  `;
  document.body.appendChild(overlay);
  const close = () => overlay.remove();
  overlay.addEventListener('click', e => { if (e.target === overlay) close(); });
  overlay.querySelector('.sast-modal-close')?.addEventListener('click', close);
  overlay.querySelector('[data-action=close]')?.addEventListener('click', close);

  overlay.querySelector('#editMetaSave')?.addEventListener('click', async () => {
    const updated = {
      ...sastanak,
      naslov: overlay.querySelector('#editNaslov').value.trim() || sastanak.naslov,
      datum: overlay.querySelector('#editDatum').value || sastanak.datum,
      vreme: overlay.querySelector('#editVreme').value || null,
      mesto: overlay.querySelector('#editMesto').value.trim(),
    };
    const saved = await saveSastanak(updated);
    if (saved) {
      showToast('✅ Sačuvano');
      host.querySelector('#sdMeta').innerHTML = renderMetaGrid(saved);
      Object.assign(sastanak, saved);
      close();
    } else {
      showToast('⚠ Nije uspelo');
    }
  });
}

/* ── Učesnici ── */

function renderUcesniciTable(ucesnici, canWrite, isReadOnly, status) {
  if (!ucesnici.length) return '<p class="sast-empty-inline">Nema učesnika.</p>';
  const inProgress = status === 'u_toku';
  return `
    <table class="sast-ucesnici-table">
      <thead><tr>
        <th>Ime / Email</th>
        <th title="Pozvan">Poz.</th>
        <th title="Prisutan">Pris.</th>
        ${canWrite && !isReadOnly ? '<th></th>' : ''}
      </tr></thead>
      <tbody>
        ${ucesnici.map(u => `
          <tr data-email="${escHtml(u.email)}">
            <td>${escHtml(u.label || u.email)}<br><small>${escHtml(u.email)}</small></td>
            <td>
              <input type="checkbox" class="sd-uc-pozvan" data-email="${escHtml(u.email)}"
                ${u.pozvan ? 'checked' : ''}
                ${(!canWrite || isReadOnly || inProgress) ? 'disabled' : ''}
                title="Pozvan">
            </td>
            <td>
              <input type="checkbox" class="sd-uc-prisutan" data-email="${escHtml(u.email)}"
                ${u.prisutan ? 'checked' : ''}
                ${(!canWrite || isReadOnly) ? 'disabled' : ''}
                title="Prisutan">
            </td>
            ${canWrite && !isReadOnly ? `
              <td><button type="button" class="btn btn-sm btn-danger-ghost sd-uc-remove" data-email="${escHtml(u.email)}" title="Ukloni">✕</button></td>
            ` : ''}
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;
}

function wireUcesniciToggles(host, sastanakId, readOnly = false) {
  if (readOnly) return;

  host.querySelectorAll('.sd-uc-pozvan').forEach(cb => {
    if (cb.disabled) return;
    cb.addEventListener('change', async () => {
      const email = cb.dataset.email;
      await updateUcesnikPozvan(sastanakId, email, cb.checked);
    });
  });

  host.querySelectorAll('.sd-uc-prisutan').forEach(cb => {
    if (cb.disabled) return;
    cb.addEventListener('change', async () => {
      const email = cb.dataset.email;
      await updateUcesnikPrisustvo(sastanakId, email, cb.checked);
    });
  });

  host.querySelectorAll('.sd-uc-remove').forEach(btn => {
    btn.addEventListener('click', async () => {
      const email = btn.dataset.email;
      if (!confirm(`Ukloniti učesnika ${email}?`)) return;
      const ok = await removeUcesnik(sastanakId, email);
      if (ok) {
        btn.closest('tr')?.remove();
        showToast('Učesnik uklonjen');
      } else {
        showToast('⚠ Nije uspelo');
      }
    });
  });
}

function wireAddUcesnik(host, sastanak, users) {
  const btn = host.querySelector('#sdAddUcesnik');
  const form = host.querySelector('#sdAddUcesnikForm');
  if (!btn || !form) return;

  btn.addEventListener('click', () => {
    form.style.display = 'flex';
    form.querySelector('#sdUcesnikEmail')?.focus();
  });

  host.querySelector('#sdAddUcesnikCancel')?.addEventListener('click', () => {
    form.style.display = 'none';
    host.querySelector('#sdUcesnikEmail').value = '';
  });

  host.querySelector('#sdAddUcesnikSave')?.addEventListener('click', async () => {
    const emailVal = host.querySelector('#sdUcesnikEmail').value.trim().toLowerCase();
    if (!emailVal) return;
    const user = users.find(u => u.email.toLowerCase() === emailVal);
    const ok = await addUcesnik(sastanak.id, {
      email: emailVal,
      label: user?.full_name || user?.email || emailVal,
    });
    if (ok) {
      showToast('✅ Učesnik dodat');
      form.style.display = 'none';
      host.querySelector('#sdUcesnikEmail').value = '';
      const fresh = await loadUcesnici(sastanak.id);
      sastanak.ucesnici = fresh;
      host.querySelector('#sdUcesniciTable').innerHTML =
        renderUcesniciTable(fresh, true, false, sastanak.status);
      wireUcesniciToggles(host, sastanak.id);
      wireAddUcesnik(host, sastanak, users);
    } else {
      showToast('⚠ Nije uspelo (učesnik već dodat?)');
    }
  });
}

/* ── Dnevni red (pm_teme) ── */

function renderTemeList(teme, canWrite, isReadOnly, admin) {
  if (!teme.length) {
    return `<p class="sast-empty-inline">Nema tema na dnevnom redu.
      ${canWrite && !isReadOnly ? ' Dodaj temu kroz PM teme tab ili FAB.' : ''}
    </p>`;
  }
  return `
    <ul class="sast-dnevni-red" id="sdTemeUl">
      ${teme.map((t, i) => `
        <li class="sast-dr-item${t.hitno ? ' tema-hitna' : ''}"
            draggable="${canWrite && !isReadOnly && admin ? 'true' : 'false'}"
            data-tema-id="${escHtml(t.id)}"
            data-idx="${i}">
          <span class="sast-dr-handle" aria-hidden="true">${canWrite && !isReadOnly && admin ? '⠿' : ''}</span>
          <span class="sast-dr-rb">${i + 1}.</span>
          <span class="sast-dr-naslov">${escHtml(t.naslov)}</span>
          ${t.hitno ? '<span class="sast-hitno-badge">🔥</span>' : ''}
          <span class="sast-dr-status sast-status-${escHtml(t.status)}">${escHtml(t.status)}</span>
          ${canWrite && !isReadOnly
            ? `<button type="button" class="btn btn-sm btn-ghost sd-otkaci-temu" data-tema-id="${escHtml(t.id)}" title="Otkači sa dnevnog reda">✕</button>`
            : ''}
        </li>
      `).join('')}
    </ul>
  `;
}

function wireTemeReorder(host, teme, admin) {
  const ul = host.querySelector('#sdTemeUl');
  if (!ul || !admin) {
    wireOtkaciTemu(host);
    return;
  }

  ul.addEventListener('dragstart', e => {
    const li = e.target.closest('li[draggable="true"]');
    if (!li) return;
    dragState = li.dataset.temaId;
    li.classList.add('is-dragging');
    e.dataTransfer.effectAllowed = 'move';
  });

  ul.addEventListener('dragend', () => {
    ul.querySelectorAll('.is-dragging,.drop-target-above,.drop-target-below').forEach(el => {
      el.classList.remove('is-dragging', 'drop-target-above', 'drop-target-below');
    });
    dragState = null;
  });

  ul.addEventListener('dragover', e => {
    if (!dragState) return;
    const li = e.target.closest('li');
    if (!li || li.dataset.temaId === dragState) return;
    e.preventDefault();
    ul.querySelectorAll('.drop-target-above,.drop-target-below').forEach(el => {
      el.classList.remove('drop-target-above', 'drop-target-below');
    });
    const rect = li.getBoundingClientRect();
    li.classList.add(e.clientY < rect.top + rect.height / 2 ? 'drop-target-above' : 'drop-target-below');
  });

  ul.addEventListener('drop', async e => {
    e.preventDefault();
    if (!dragState) return;
    const targetLi = e.target.closest('li');
    if (!targetLi || targetLi.dataset.temaId === dragState) { dragState = null; return; }

    const before = targetLi.classList.contains('drop-target-above');
    ul.querySelectorAll('.drop-target-above,.drop-target-below,.is-dragging').forEach(el => {
      el.classList.remove('drop-target-above', 'drop-target-below', 'is-dragging');
    });

    const items = [...ul.querySelectorAll('li')];
    const fromIdx = items.findIndex(li => li.dataset.temaId === dragState);
    let toIdx = items.findIndex(li => li.dataset.temaId === targetLi.dataset.temaId);
    if (fromIdx === -1 || toIdx === -1) { dragState = null; return; }
    if (!before) toIdx += 1;
    if (fromIdx < toIdx) toIdx -= 1;

    const arr = teme.slice();
    const [moved] = arr.splice(fromIdx, 1);
    arr.splice(toIdx, 0, moved);
    teme.length = 0;
    arr.forEach(t => teme.push(t));

    dragState = null;
    ul.innerHTML = renderTemeList(teme, true, false, admin).match(/<li[\s\S]*<\/ul>/)?.[0]?.replace(/<\/?ul[^>]*>/g, '') || '';
    // re-render properly
    host.querySelector('#sdTemeList').innerHTML = renderTemeList(teme, true, false, admin);
    wireTemeReorder(host, teme, admin);

    const ok = await reorderPmTeme(teme.map((t, idx) => ({ id: t.id, rang: idx + 1 })));
    if (!ok) showToast('⚠ Redosled nije sačuvan');
  });

  wireOtkaciTemu(host);
}

function wireOtkaciTemu(host) {
  host.querySelectorAll('.sd-otkaci-temu').forEach(btn => {
    btn.addEventListener('click', async () => {
      const temaId = btn.dataset.temaId;
      if (!confirm('Otkačiti temu sa dnevnog reda ovog sastanka?')) return;
      const ok = await sbReq(`pm_teme?id=eq.${encodeURIComponent(temaId)}`, 'PATCH', {
        sastanak_id: null,
        updated_at: new Date().toISOString(),
      });
      if (ok !== null) {
        btn.closest('li')?.remove();
        showToast('Tema otkačena');
      } else {
        showToast('⚠ Nije uspelo');
      }
    });
  });
}

/* ── Beleška organizatora ── */

function wireNapomena(host, sastanak) {
  const ta = host.querySelector('#sdNapomena');
  const indicator = host.querySelector('#sdNapSave');
  if (!ta) return;

  ta.addEventListener('input', () => {
    clearTimeout(debounceTimer);
    if (indicator) indicator.style.visibility = 'hidden';
    debounceTimer = setTimeout(async () => {
      const ok = await sbReq(
        `sastanci?id=eq.${encodeURIComponent(sastanak.id)}`,
        'PATCH',
        { napomena: ta.value, updated_at: new Date().toISOString() },
      );
      if (ok !== null && indicator) {
        indicator.style.visibility = 'visible';
        setTimeout(() => { indicator.style.visibility = 'hidden'; }, 2000);
      }
    }, SAVE_DEBOUNCE_MS);
  });
}

export function teardownPripremiTab() {
  abortFlag = true;
  clearTimeout(debounceTimer);
  dragState = null;
}
