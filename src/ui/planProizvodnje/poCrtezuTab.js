/**
 * Plan proizvodnje — tab „Po crtežu“ (PP-E): sve operacije jednog crteža / RN identa.
 */
import { escHtml, showToast } from '../../lib/dom.js';
import {
  loadOperationsByDrawingSearch,
  plannedSeconds,
  formatSecondsHm,
  rokUrgencyClass,
} from '../../services/planProizvodnje.js';
import { formatDate } from '../../lib/date.js';

const state = {
  host: null,
  query: '',
  rows: [],
  loading: false,
  onJumpToPoMasini: null,
};

function statusLabel(s) {
  switch (s) {
    case 'waiting': return 'Čeka';
    case 'in_progress': return 'U radu';
    case 'blocked': return 'Blokirano';
    case 'completed': return 'Završeno';
    default: return s || '—';
  }
}

function renderTable(wrap) {
  if (!state.rows.length) {
    wrap.innerHTML = `
      <div class="pp-state">
        <div class="pp-state-icon">🔎</div>
        <div class="pp-state-title">Nema rezultata</div>
        <div class="pp-state-hint">Unesi broj crteža ili ident RN-a i klikni Traži.</div>
      </div>`;
    return;
  }
  const body = state.rows.map(r => {
    const st = r.local_status || 'waiting';
    const hm = formatSecondsHm(plannedSeconds(r));
    const mc = r.effective_machine_code || '—';
    const ready = !!(r.is_ready_for_processing ?? r.is_ready_for_machine);
    const hitno = !!r.is_urgent;
    const scrap = !!(r.is_scrap_release ?? r.is_scrap);
    const rokCls = rokUrgencyClass(r.rok_izrade);
    const rok = r.rok_izrade ? formatDate(r.rok_izrade) : '—';
    return `
      <tr class="pp-draw-tab-row${scrap ? ' pp-row-scrap' : ''}" data-machine="${escHtml(mc)}">
        <td class="pp-cell-center">${escHtml(String(r.operacija ?? '—'))}</td>
        <td><button type="button" class="pp-link-machine" data-mc="${escHtml(mc)}">${escHtml(mc)}</button></td>
        <td><span class="pp-status-mini s-${st}">${escHtml(statusLabel(st))}</span></td>
        <td class="pp-cell-num">${escHtml(hm)}</td>
        <td class="pp-cell-center">${ready ? '✓' : '—'}</td>
        <td class="pp-cell-center">${hitno ? 'HITNO' : '—'}</td>
        <td>${scrap ? '⚠' : '—'}</td>
        <td><span class="pp-rok urgency-${rokCls || 'none'}">${escHtml(rok)}</span></td>
        <td class="pp-cell-muted">${escHtml(r.rn_ident_broj || '—')}</td>
      </tr>`;
  }).join('');

  wrap.innerHTML = `
    <div class="pp-table-wrap">
      <table class="pp-table pp-draw-tab-table">
        <thead>
          <tr>
            <th class="pp-cell-center">Op.</th>
            <th>Mašina</th>
            <th>Status</th>
            <th class="pp-cell-num">Plan (T)</th>
            <th class="pp-cell-center">Spremno</th>
            <th class="pp-cell-center">Hitno</th>
            <th>Skart</th>
            <th>Rok</th>
            <th>RN</th>
          </tr>
        </thead>
        <tbody>${body}</tbody>
      </table>
    </div>`;

  wrap.querySelectorAll('.pp-link-machine').forEach(btn => {
    btn.addEventListener('click', () => {
      const mc = btn.dataset.mc;
      if (mc && typeof state.onJumpToPoMasini === 'function') state.onJumpToPoMasini(mc);
      else showToast(`Mašina: ${mc}`);
    });
  });
}

export async function renderPoCrtezuTab(host, { canEdit, onJumpToPoMasini } = {}) {
  state.host = host;
  state.onJumpToPoMasini = onJumpToPoMasini || null;
  void canEdit;

  host.innerHTML = `
    <div class="pp-toolbar">
      <label class="pp-rn-filter" title="Broj crteža ili ident RN-a (delimično poklapanje)">
        <span>🔎 Crtež / RN</span>
        <input type="search" id="ppDrawSearch" value="${escHtml(state.query)}"
               placeholder="npr. 1133219 ili 9000" autocomplete="off">
      </label>
      <button type="button" class="pp-refresh-btn" id="ppDrawSearchBtn">Traži</button>
      <button class="pp-refresh-btn" id="ppDrawRefreshBtn" title="Ponovi poslednju pretragu">
        <span aria-hidden="true">↻</span> Osveži
      </button>
    </div>
    <div id="ppDrawError" class="pp-error" hidden role="alert"></div>
    <div id="ppDrawBody"><div class="pp-state"><div class="pp-state-icon">🔎</div>
      <div class="pp-state-title">Pretraga po crtežu</div>
      <div class="pp-state-hint">Prikaz svih operacija koje odgovaraju upitu, kroz sve mašine (bez drag-drop).</div>
    </div></div>`;

  const runSearch = async () => {
    const inp = host.querySelector('#ppDrawSearch');
    const q = String(inp?.value || '').trim();
    state.query = q;
    const err = host.querySelector('#ppDrawError');
    const body = host.querySelector('#ppDrawBody');
    if (!q) {
      state.rows = [];
      renderTable(body);
      return;
    }
    err.hidden = true;
    body.innerHTML = '<div class="pp-state"><div class="pp-state-icon">⏳</div><div class="pp-state-title">Učitavanje…</div></div>';
    state.loading = true;
    try {
      state.rows = await loadOperationsByDrawingSearch(q);
      renderTable(body);
    } catch (e) {
      console.error('[po-crtezu]', e);
      err.textContent = 'Greška pri učitavanju: ' + (e?.message || e);
      err.hidden = false;
      body.innerHTML = '';
    } finally {
      state.loading = false;
    }
  };

  host.querySelector('#ppDrawSearchBtn')?.addEventListener('click', () => void runSearch());
  host.querySelector('#ppDrawRefreshBtn')?.addEventListener('click', () => void runSearch());
  host.querySelector('#ppDrawSearch')?.addEventListener('keydown', e => {
    if (e.key === 'Enter') void runSearch();
  });
}

export function teardownPoCrtezuTab() {
  state.host = null;
  state.rows = [];
  state.onJumpToPoMasini = null;
}
