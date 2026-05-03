/**
 * Draft teme — structured weekly prep panel.
 *
 * Projektni izbor je lokalni za ovaj tab; routing i postojeći tabovi ostaju
 * netaknuti.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { loadSastanci } from '../../services/sastanci.js';
import {
  loadDraftTeme,
  loadPmTeme,
  predloziDraftTemu,
  pregledajDraftTemu,
  uvediDraftTemuNaSastanak,
} from '../../services/pmTeme.js';
import { loadProjektiLite } from '../../services/projekti.js';
import { canEdit as authCanEdit, getCurrentUser } from '../../state/auth.js';

let abortFlag = false;
let activeProjectId = null;
let cachedProjects = [];
let cachedDrafts = [];
let cachedMine = [];
let cachedMeetings = [];

export async function renderDraftTemePanel(host, { canEdit = authCanEdit() } = {}) {
  abortFlag = false;
  host.innerHTML = '<div class="sast-loading">Učitavam draft teme…</div>';

  cachedProjects = await loadProjektiLite();
  if (abortFlag) return;

  if (!cachedProjects.length) {
    host.innerHTML = '<div class="sast-empty">Nema dostupnih projekata.</div>';
    return;
  }

  if (!activeProjectId || !cachedProjects.some(p => p.id === activeProjectId)) {
    activeProjectId = cachedProjects[0].id;
  }

  host.innerHTML = `
    <div class="sast-section">
      <div class="sast-pregled-header">
        <h3>Draft teme</h3>
        <p class="sast-pregled-sub">Strukturisana priprema tema pre sedmičnog sastanka.</p>
      </div>

      <div class="sast-toolbar">
        <label class="sast-form-row" style="min-width:280px">
          <span>Projekat</span>
          <select id="draftProject" class="sast-input">
            ${cachedProjects.map(p => `
              <option value="${escHtml(p.id)}" ${p.id === activeProjectId ? 'selected' : ''}>
                ${escHtml(p.label)}
              </option>
            `).join('')}
          </select>
        </label>
      </div>

      ${canEdit ? renderCreateBox() : '<div class="sast-empty">Samo editori mogu predlagati draft teme.</div>'}

      <div class="sast-draft-grid">
        <section class="sast-card">
          <h4>Moje teme</h4>
          <div id="draftMine" class="sast-table-wrap"><div class="sast-loading">Učitavam…</div></div>
        </section>
        <section class="sast-card">
          <h4>Na pregledu <span class="sast-badge" id="draftPendingBadge">0</span></h4>
          <div id="draftReview" class="sast-table-wrap"><div class="sast-loading">Učitavam…</div></div>
        </section>
        <section class="sast-card">
          <h4>Usvojene za dodavanje na sastanak</h4>
          <div id="draftApproved" class="sast-table-wrap"><div class="sast-loading">Učitavam…</div></div>
        </section>
      </div>
    </div>
  `;

  host.querySelector('#draftProject')?.addEventListener('change', async (e) => {
    activeProjectId = e.target.value;
    await refreshPanel(host, { canEdit });
  });

  if (canEdit) wireCreateBox(host, { canEdit });
  await refreshPanel(host, { canEdit });
}

export function teardownDraftTemePanel() {
  abortFlag = true;
}

function renderCreateBox() {
  return `
    <form id="draftCreateForm" class="sast-form" style="margin:16px 0">
      <div class="sast-form-grid">
        <label class="sast-form-row">
          <span>Naslov *</span>
          <input class="sast-input" name="naslov" maxlength="200" required>
        </label>
        <label class="sast-form-row">
          <span>Prioritet</span>
          <select class="sast-input" name="prioritet">
            <option value="1">Visok</option>
            <option value="2" selected>Srednji</option>
            <option value="3">Nizak</option>
          </select>
        </label>
      </div>
      <label class="sast-form-row">
        <span>Opis</span>
        <textarea class="sast-input" name="opis" rows="2" maxlength="1000"></textarea>
      </label>
      <button type="submit" class="btn btn-primary">Predloži temu</button>
    </form>
  `;
}

function wireCreateBox(host, { canEdit }) {
  host.querySelector('#draftCreateForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const naslov = String(fd.get('naslov') || '').trim();
    if (!naslov) {
      showToast('⚠ Naslov je obavezan');
      return;
    }
    const row = await predloziDraftTemu(activeProjectId, {
      naslov,
      opis: String(fd.get('opis') || '').trim() || null,
      prioritet: Number(fd.get('prioritet') || 2),
    });
    if (!row) {
      showToast('⚠ Draft tema nije sačuvana');
      return;
    }
    e.currentTarget.reset();
    showToast('✅ Draft tema je poslata na pregled');
    await refreshPanel(host, { canEdit });
  });
}

async function refreshPanel(host, { canEdit }) {
  const cu = getCurrentUser();
  const [drafts, mine, meetings] = await Promise.all([
    loadDraftTeme(activeProjectId),
    cu?.email
      ? loadPmTeme({ projekatId: activeProjectId, predlozioEmail: cu.email, limit: 200 })
      : Promise.resolve([]),
    loadSastanci({ projekatId: activeProjectId, limit: 200 }),
  ]);

  if (abortFlag) return;

  cachedDrafts = drafts;
  cachedMine = mine.filter(t => ['draft', 'usvojeno', 'odbijeno'].includes(t.status));
  cachedMeetings = meetings.filter(s => s.status !== 'zakljucan');

  host.querySelector('#draftPendingBadge').textContent = String(cachedDrafts.length);
  renderMine(host.querySelector('#draftMine'));
  renderReview(host.querySelector('#draftReview'), { canEdit });
  renderApproved(host.querySelector('#draftApproved'), { canEdit });
}

function renderMine(host) {
  if (!cachedMine.length) {
    host.innerHTML = '<div class="sast-empty">Nema tvojih draft tema za ovaj projekat.</div>';
    return;
  }
  host.innerHTML = `
    <table class="sast-table">
      <thead><tr><th>Status</th><th>Naslov</th><th>Napomena</th><th>Datum</th></tr></thead>
      <tbody>
        ${cachedMine.map(t => `
          <tr>
            <td>${escHtml(statusLabel(t.status))}</td>
            <td><strong>${escHtml(t.naslov)}</strong>${t.opis ? `<br><small>${escHtml(t.opis)}</small>` : ''}</td>
            <td>${t.status === 'odbijeno' ? escHtml(t.resioNapomena || '—') : '—'}</td>
            <td>${escHtml((t.createdAt || t.predlozioAt || '').slice(0, 10))}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;
}

function renderReview(host, { canEdit }) {
  if (!cachedDrafts.length) {
    host.innerHTML = '<div class="sast-empty">Nema draft tema na pregledu.</div>';
    return;
  }
  host.innerHTML = `
    <table class="sast-table">
      <thead><tr><th>Naslov</th><th>Predložio</th><th>Datum</th><th class="sast-th-actions">Akcije</th></tr></thead>
      <tbody>
        ${cachedDrafts.map(t => `
          <tr>
            <td><strong>${escHtml(t.naslov)}</strong>${t.opis ? `<br><small>${escHtml(t.opis)}</small>` : ''}</td>
            <td>${escHtml(t.predlozioLabel || t.predlozioEmail || '—')}</td>
            <td>${escHtml((t.createdAt || t.predlozioAt || '').slice(0, 10))}</td>
            <td class="sast-td-actions">
              ${canEdit ? `
                <button class="btn btn-sm btn-success" data-review="accept" data-id="${escHtml(t.id)}">Prihvati</button>
                <button class="btn btn-sm btn-danger" data-review="reject" data-id="${escHtml(t.id)}">Odbaci</button>
              ` : '—'}
            </td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;

  host.querySelectorAll('[data-review]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const decision = btn.dataset.review === 'accept' ? 'aktivna' : 'odbijena';
      const note = btn.dataset.review === 'reject'
        ? prompt('Napomena predlagaču (opciono):') || null
        : null;
      const row = await pregledajDraftTemu(btn.dataset.id, decision, note);
      showToast(row ? '✅ Draft tema pregledana' : '⚠ Pregled nije uspeo');
      await refreshPanel(document.querySelector('#sastTabBody'), { canEdit });
    });
  });
}

function renderApproved(host, { canEdit }) {
  const approved = cachedMine.filter(t => t.status === 'usvojeno' && !t.sastanakId);
  if (!approved.length) {
    host.innerHTML = '<div class="sast-empty">Nema usvojenih tema koje čekaju sastanak.</div>';
    return;
  }
  if (!cachedMeetings.length) {
    host.innerHTML = '<div class="sast-empty">Postoje usvojene teme, ali nema aktivnog sastanka za izabrani projekat.</div>';
    return;
  }

  host.innerHTML = `
    <table class="sast-table">
      <thead><tr><th>Tema</th><th>Sastanak</th><th class="sast-th-actions">Akcija</th></tr></thead>
      <tbody>
        ${approved.map(t => `
          <tr>
            <td>${escHtml(t.naslov)}</td>
            <td>
              <select class="sast-input" data-meeting-select="${escHtml(t.id)}">
                ${cachedMeetings.map(s => `<option value="${escHtml(s.id)}">${escHtml(s.naslov)} · ${escHtml(s.datum || '')}</option>`).join('')}
              </select>
            </td>
            <td>${canEdit ? `<button class="btn btn-sm" data-add-meeting="${escHtml(t.id)}">Dodaj na sastanak</button>` : '—'}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;

  host.querySelectorAll('[data-add-meeting]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const temaId = btn.dataset.addMeeting;
      const sastanakId = host.querySelector(`[data-meeting-select="${CSS.escape(temaId)}"]`)?.value;
      const row = await uvediDraftTemuNaSastanak(temaId, sastanakId);
      showToast(row ? '✅ Tema dodata na sastanak' : '⚠ Dodavanje nije uspelo');
      await refreshPanel(document.querySelector('#sastTabBody'), { canEdit });
    });
  });
}

function statusLabel(status) {
  if (status === 'draft') return 'Na pregledu';
  if (status === 'usvojeno') return 'Odobrena';
  if (status === 'odbijeno') return 'Odbijena';
  return status || '—';
}
