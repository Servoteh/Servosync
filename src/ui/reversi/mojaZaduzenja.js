/**
 * Reversi — tab "Moja zaduženja" (Sprint RZ-4): mobilni self-service.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  fetchMyIssuedTools,
  fetchMyIssuedCuttingTools,
  fetchMyMachinesCuttingTools,
} from '../../services/reversiService.js';
import { openCuttingToolReturnScannerModal } from './cuttingToolScannerModal.js';
import { openQuickReturnModal } from './quickReturnModal.js';
import { formatRevAssetKind } from '../../lib/revAssetKind.js';
import { revFmtDate, revIcon, revPageHeaderHtml } from './revMockUi.js';

let bodyRoot = null;

function isOverdue(iso) {
  if (!iso) return false;
  const today = new Date().toISOString().slice(0, 10);
  return String(iso).slice(0, 10) < today;
}

function handToolCard(r) {
  const overdue = isOverdue(r.expected_return_date);
  return `<article class="rev-mz-card rev-mz-card--mock ${overdue ? 'is-overdue' : ''}">
    <header class="rev-mz-card-head">
      <span class="rev-mono rev-strong">${escHtml(r.oznaka || '')}</span>
      <span class="rev-mz-doc">${escHtml(r.doc_number || '')}</span>
    </header>
    <div class="rev-mz-card-body">
      <div class="rev-mz-name">${escHtml(r.naziv || '')}</div>
      ${r.asset_kind ? `<div class="rev-mz-meta">${escHtml(formatRevAssetKind(r.asset_kind))}</div>` : ''}
      ${r.serijski_broj ? `<div class="rev-mz-meta">SN: ${escHtml(r.serijski_broj)}</div>` : ''}
      ${r.pribor ? `<div class="rev-mz-meta">Pribor: ${escHtml(r.pribor)}</div>` : ''}
    </div>
    <footer class="rev-mz-card-foot">
      <span>Zadužen ${escHtml(revFmtDate(r.issued_at))}</span>
      ${r.expected_return_date ? `<span class="${overdue ? 'rev-warn' : ''}">Rok ${escHtml(revFmtDate(r.expected_return_date))}${overdue ? ' !' : ''}</span>` : ''}
    </footer>
  </article>`;
}

function cuttingCard(r) {
  return `<article class="rev-mz-card rev-mz-card--mock">
    <header class="rev-mz-card-head">
      <span class="rev-mono rev-strong">${escHtml(r.barcode || '')}</span>
      <span class="rev-mz-mchip">${escHtml(r.recipient_machine_code || '—')}</span>
    </header>
    <div class="rev-mz-card-body">
      <div class="rev-mz-name">${escHtml(r.naziv || r.oznaka || '')}</div>
      ${r.klasa ? `<div class="rev-mz-meta">Klasa: ${escHtml(r.klasa)}</div>` : ''}
      <div class="rev-mz-meta">Količina: <strong>${escHtml(String(r.remaining_quantity ?? r.quantity ?? 0))}</strong> ${escHtml(r.unit || 'kom')}${r.returned_quantity > 0 ? ` <span class="rev-muted">(vraćeno ${escHtml(String(r.returned_quantity))})</span>` : ''}</div>
      ${r.issued_to_employee_name ? `<div class="rev-mz-meta">Potpisao: ${escHtml(r.issued_to_employee_name)}</div>` : ''}
    </div>
    <footer class="rev-mz-card-foot">
      <span>Zadužen ${escHtml(revFmtDate(r.issued_at))}</span>
      <span class="rev-muted">${escHtml(r.doc_number || '')}</span>
    </footer>
  </article>`;
}

/** @param {HTMLElement} body Mount tačka */
export async function renderMojaZaduzenjaTab(body) {
  bodyRoot = body;
  body.innerHTML = '<div class="rev-loading-card">Učitavam tvoja zaduženja…</div>';

  const [hand, machines, signed] = await Promise.all([
    fetchMyIssuedTools(),
    fetchMyMachinesCuttingTools(),
    fetchMyIssuedCuttingTools(),
  ]);

  const handRows = hand.ok && Array.isArray(hand.data) ? hand.data : [];
  const machineRows = machines.ok && Array.isArray(machines.data) ? machines.data : [];
  const signedRows = signed.ok && Array.isArray(signed.data) ? signed.data : [];

  const seen = new Set();
  const cuttingRows = [];
  for (const list of [machineRows, signedRows]) {
    for (const r of list) {
      const k = String(r.line_id);
      if (seen.has(k)) continue;
      seen.add(k);
      cuttingRows.push(r);
    }
  }

  const byMachine = new Map();
  for (const r of cuttingRows) {
    const k = r.recipient_machine_code || '—';
    if (!byMachine.has(k)) byMachine.set(k, []);
    byMachine.get(k).push(r);
  }
  const machineKeys = Array.from(byMachine.keys()).sort();

  body.innerHTML = `
    <div class="rev-mz-shell rev-mz-shell--mock">
      ${revPageHeaderHtml({
        title: 'Moja zaduženja',
        subtitle: 'Trenutno stanje alata na vama i na vašim mašinama.',
        iconSvg: revIcon('user', 20),
      })}
      <button type="button" class="rev-quick-fab rev-btn rev-btn--primary" id="revMzQuickReturnFab">${revIcon('camera', 16, 'rev-ic')} Skeniraj</button>

      <section class="rev-mz-section">
        <div class="rev-mz-section-head">
          <h3>${revIcon('scissors', 16, 'rev-ic rev-ic--inline')} Rezni alat na mašinama</h3>
          <span class="rev-mz-count">${cuttingRows.length}</span>
        </div>
        ${
          cuttingRows.length === 0
            ? '<p class="rev-muted">Nema reznog alata na vašim mašinama.</p>'
            : machineKeys
                .map(
                  (mk) => `
            <div class="rev-mz-machine-block">
              <h4 class="rev-mz-machine-h">Mašina <span class="rev-mono">${escHtml(mk)}</span> <span class="rev-muted">(${byMachine.get(mk).length})</span></h4>
              <div class="rev-mz-cards">${byMachine.get(mk).map(cuttingCard).join('')}</div>
            </div>`,
                )
                .join('')
        }
        <div class="rev-mz-fab-actions">
          <button type="button" class="rev-btn rev-btn--secondary" id="revMzReturn">${revIcon('arrowLeft', 16, 'rev-ic')} Vrati alat (skener)</button>
          <button type="button" class="rev-btn rev-btn--primary" id="revMzQuickReturn">${revIcon('camera', 16, 'rev-ic')} Skeniraj povraćaj</button>
        </div>
      </section>

      <section class="rev-mz-section">
        <div class="rev-mz-section-head">
          <h3>${revIcon('wrench', 16, 'rev-ic rev-ic--inline')} Ručni alat (lično zaduženje)</h3>
          <span class="rev-mz-count">${handRows.length}</span>
        </div>
        ${
          handRows.length === 0
            ? '<p class="rev-muted">Nemate ručnih alata na zaduženju.</p>'
            : `<div class="rev-mz-cards">${handRows.map(handToolCard).join('')}</div>`
        }
      </section>
    </div>`;

  const openQr = () => {
    openQuickReturnModal({
      onSuccess: () => void renderMojaZaduzenjaTab(body),
    });
  };

  body.querySelector('#revMzReturn')?.addEventListener('click', () => {
    openCuttingToolReturnScannerModal({
      onSuccess: () => {
        showToast('Povraćaj kreiran — osveži listu');
        void renderMojaZaduzenjaTab(body);
      },
    });
  });
  body.querySelector('#revMzQuickReturn')?.addEventListener('click', openQr);
  body.querySelector('#revMzQuickReturnFab')?.addEventListener('click', openQr);
}

export function teardownMojaZaduzenjaTab() {
  bodyRoot = null;
}
