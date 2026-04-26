/**
 * Kanban prikaz za Akcioni plan — 3 kolone, drag-drop menja status.
 *
 * Kolone:
 *   Otvorene  — effectiveStatus: otvoren | u_toku | kasni
 *   Završene  — effectiveStatus: zavrsen
 *   Odložene  — effectiveStatus: odlozen | otkazan
 *
 * Drop u kolonu poziva updateAkcijaStatus() sa ciljnim statusom.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { formatDate } from '../../lib/date.js';
import { updateAkcijaStatus, deleteAkcija, AKCIJA_STATUSI, AKCIJA_STATUS_BOJE } from '../../services/akcioniPlan.js';

const COLUMNS = [
  { id: 'otvorene', label: 'Otvorene',  statuses: ['otvoren', 'u_toku', 'kasni'], dropStatus: 'otvoren', cls: 'skb-col--open'   },
  { id: 'zavrsene', label: 'Završene',  statuses: ['zavrsen'],                     dropStatus: 'zavrsen', cls: 'skb-col--done'   },
  { id: 'odlozene', label: 'Odložene',  statuses: ['odlozen', 'otkazan'],          dropStatus: 'odlozen', cls: 'skb-col--delay'  },
];

let dragId = null;

export function renderAkcioniKanban(host, rows, { canEdit, cachedProjekti, onRefresh, onEdit }) {
  const grouped = {};
  COLUMNS.forEach(c => { grouped[c.id] = []; });
  rows.forEach(a => {
    const eff = a.effectiveStatus || a.status;
    const col = COLUMNS.find(c => c.statuses.includes(eff));
    if (col) grouped[col.id].push(a);
  });

  host.innerHTML = `
    <div class="sast-kanban">
      ${COLUMNS.map(col => `
        <div class="sast-kanban-col ${col.cls}" data-col="${col.id}">
          <div class="skb-col-header">
            <span class="skb-col-title">${escHtml(col.label)}</span>
            <span class="skb-col-count">${grouped[col.id].length}</span>
          </div>
          <div class="skb-cards" data-col="${col.id}" data-drop-status="${col.dropStatus}">
            ${grouped[col.id].map(a => renderCard(a, canEdit, cachedProjekti)).join('')}
            ${grouped[col.id].length === 0 ? `<div class="skb-empty">${colEmptyMsg(col.id)}</div>` : ''}
          </div>
        </div>
      `).join('')}
    </div>
  `;

  if (canEdit) {
    wireDragDrop(host, rows, onRefresh);
    wireCardActions(host, rows, { onRefresh, onEdit });
  }
}

function colEmptyMsg(colId) {
  if (colId === 'otvorene') return 'Nema otvorenih akcija';
  if (colId === 'zavrsene') return 'Nema završenih akcija';
  return 'Nema odloženih/otkazanih akcija';
}

function renderCard(a, canEdit, cachedProjekti) {
  const eff = a.effectiveStatus || a.status;
  const color = AKCIJA_STATUS_BOJE[eff] || '#888';
  const isLate = eff === 'kasni';
  const projekat = cachedProjekti.find(p => p.id === a.projekatId);
  const projLabel = projekat ? escHtml(projekat.code || projekat.name) : null;
  const priIcon = a.prioritet === 1 ? '🔴' : (a.prioritet === 2 ? '🟡' : '🟢');

  return `
    <div class="skb-card${isLate ? ' skb-card--late' : ''}" data-id="${escHtml(a.id)}" draggable="${canEdit ? 'true' : 'false'}">
      <div class="skb-card-head">
        <span class="skb-status-dot" style="background:${color}" title="${escHtml(AKCIJA_STATUSI[eff] || eff)}"></span>
        <span class="skb-naslov">${escHtml(a.naslov)}</span>
        ${canEdit ? `
          <div class="skb-card-btns">
            <button type="button" class="btn-icon" data-action="edit" data-id="${escHtml(a.id)}" title="Izmeni">✎</button>
            <button type="button" class="btn-icon btn-danger" data-action="delete" data-id="${escHtml(a.id)}" title="Obriši">🗑</button>
          </div>
        ` : ''}
      </div>
      ${(a.odgovoranLabel || a.odgovoranText || a.odgovoranEmail) ? `<div class="skb-meta">👤 ${escHtml(a.odgovoranLabel || a.odgovoranText || a.odgovoranEmail)}</div>` : ''}
      ${a.rok ? `<div class="skb-meta${isLate ? ' skb-rok-late' : ''}">📅 ${escHtml(formatDate(a.rok))}${isLate && a.danaDoRoka != null ? ` <span class="skb-kasni-tag">kasni ${Math.abs(a.danaDoRoka)}d</span>` : ''}</div>` : ''}
      <div class="skb-card-foot">
        <span title="Prioritet">${priIcon}</span>
        ${projLabel ? `<span class="skb-proj">${projLabel}</span>` : ''}
      </div>
    </div>
  `;
}

function wireCardActions(host, rows, { onRefresh, onEdit }) {
  host.querySelectorAll('.skb-card').forEach(card => {
    card.addEventListener('click', e => {
      if (e.target.closest('[data-action]')) return;
      const a = rows.find(r => r.id === card.dataset.id);
      if (a) onEdit(a);
    });
  });

  host.querySelectorAll('[data-action="edit"]').forEach(btn => {
    btn.addEventListener('click', e => {
      e.stopPropagation();
      const a = rows.find(r => r.id === btn.dataset.id);
      if (a) onEdit(a);
    });
  });

  host.querySelectorAll('[data-action="delete"]').forEach(btn => {
    btn.addEventListener('click', async e => {
      e.stopPropagation();
      const a = rows.find(r => r.id === btn.dataset.id);
      if (!a || !confirm(`Obriši akciju "${a.naslov}"?`)) return;
      const ok = await deleteAkcija(a.id);
      if (ok) { showToast('🗑 Akcija obrisana'); onRefresh(); }
      else showToast('⚠ Greška');
    });
  });
}

function wireDragDrop(host, rows, onRefresh) {
  host.addEventListener('dragstart', e => {
    const card = e.target.closest('.skb-card[draggable="true"]');
    if (!card) return;
    dragId = card.dataset.id;
    card.classList.add('is-dragging');
    e.dataTransfer.effectAllowed = 'move';
  });

  host.addEventListener('dragend', () => {
    host.querySelectorAll('.is-dragging, .skb-drag-over').forEach(el => {
      el.classList.remove('is-dragging', 'skb-drag-over');
    });
    dragId = null;
  });

  host.querySelectorAll('.skb-cards').forEach(zone => {
    zone.addEventListener('dragover', e => {
      if (!dragId) return;
      e.preventDefault();
      host.querySelectorAll('.skb-drag-over').forEach(el => el.classList.remove('skb-drag-over'));
      zone.classList.add('skb-drag-over');
      e.dataTransfer.dropEffect = 'move';
    });

    zone.addEventListener('dragleave', e => {
      if (!zone.contains(e.relatedTarget)) zone.classList.remove('skb-drag-over');
    });

    zone.addEventListener('drop', async e => {
      e.preventDefault();
      zone.classList.remove('skb-drag-over');
      if (!dragId) return;
      const dropStatus = zone.dataset.dropStatus;
      const colDef = COLUMNS.find(c => c.dropStatus === dropStatus);
      if (!colDef) return;
      const a = rows.find(r => r.id === dragId);
      if (!a) return;
      const curEff = a.effectiveStatus || a.status;
      if (colDef.statuses.includes(curEff)) { dragId = null; return; }
      const ok = await updateAkcijaStatus(a.id, dropStatus);
      if (ok) { showToast(`↪ ${escHtml(a.naslov.slice(0, 30))} → ${escHtml(colDef.label)}`); onRefresh(); }
      else showToast('⚠ Nije uspelo premestanje');
      dragId = null;
    });
  });
}
