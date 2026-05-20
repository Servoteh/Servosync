/**
 * Reversi — mobilni hub (barkod-first) unutar /m/reversi.
 * Pun modul ostaje na /reversi; ovde su samo skener tokovi za magacionera.
 */

import { enableMobileBack } from '../../lib/mobileBack.js';
import { canManageReversi } from '../../state/auth.js';
import { openQuickIssueModal } from '../reversi/quickIssueModal.js';
import { openQuickReturnModal } from '../reversi/quickReturnModal.js';
import {
  openCuttingToolIssueScannerModal,
  openCuttingToolReturnScannerModal,
} from '../reversi/cuttingToolScannerModal.js';
import { STORAGE_KEYS } from '../../lib/constants.js';
import { ssSet } from '../../lib/storage.js';

/**
 * @param {HTMLElement} mountEl
 * @param {{ onNavigate: (path: string) => void }} ctx
 */
export function renderMobileReversi(mountEl, ctx) {
  const canManage = canManageReversi();

  mountEl.innerHTML = `
    <div class="m-shell" id="mRevShell">
      <header class="m-header">
        <button type="button" class="m-btn-ghost" data-act="back" aria-label="Nazad na magacin">←</button>
        <div class="m-brand">
          <div class="m-brand-title">REVERSI</div>
          <div class="m-brand-sub">Zaduženja i povraćaji (barkod)</div>
        </div>
      </header>

      <main class="m-main">
        ${
          canManage
            ? `
        <button type="button" class="m-cta m-cta-primary" data-act="quickIssue">
          <span class="m-cta-ico">📷</span>
          <span class="m-cta-txt">
            <span class="m-cta-title">QUICK ISSUE</span>
            <span class="m-cta-sub">Skeniraj alat, radnika i mašinu</span>
          </span>
        </button>
        <button type="button" class="m-cta m-cta-secondary" data-act="quickReturn">
          <span class="m-cta-ico">↩</span>
          <span class="m-cta-txt">
            <span class="m-cta-title">QUICK RETURN</span>
            <span class="m-cta-sub">Skeniraj ALAT-… ili RZN-… za povraćaj</span>
          </span>
        </button>
        <div class="m-section-head">Rezni alat</div>
        <div class="m-cta-row">
          <button type="button" class="m-cta m-cta-secondary" data-act="rznIssue">
            <span class="m-cta-ico">📷</span>
            <span class="m-cta-txt">
              <span class="m-cta-title">ZADUŽENJE</span>
              <span class="m-cta-sub">RZN-… + radnik + mašina</span>
            </span>
          </button>
          <button type="button" class="m-cta m-cta-secondary" data-act="rznReturn">
            <span class="m-cta-ico">↩</span>
            <span class="m-cta-txt">
              <span class="m-cta-title">POVRAĆAJ</span>
              <span class="m-cta-sub">Skeniraj režni alat</span>
            </span>
          </button>
        </div>`
            : `<p class="m-muted-block">Izdavanje i povraćaj zahtevaju ulogu magacioner / menadžment. Možeš otvoriti pun modul ispod.</p>`
        }
        <button type="button" class="m-cta m-cta-tertiary m-cta-full" data-act="fullModule">
          <span class="m-cta-ico">🔁</span>
          <span class="m-cta-txt">
            <span class="m-cta-title">PUN MODUL REVERSI</span>
            <span class="m-cta-sub">Inventar, dokumenti, izveštaji</span>
          </span>
        </button>
      </main>
    </div>
  `;

  document.body.classList.add('m-body');

  mountEl.addEventListener('click', ev => {
    const act = ev.target.closest('[data-act]')?.dataset?.act;
    if (!act) return;
    switch (act) {
      case 'back':
        ctx.onNavigate('/m');
        break;
      case 'quickIssue':
        openQuickIssueModal({});
        break;
      case 'quickReturn':
        openQuickReturnModal({});
        break;
      case 'rznIssue':
        openCuttingToolIssueScannerModal({});
        break;
      case 'rznReturn':
        openCuttingToolReturnScannerModal({});
        break;
      case 'fullModule':
        enableMobileBack();
        ssSet(`sess:${STORAGE_KEYS.REVERSI_TAB}`, 'magacin');
        ctx.onNavigate('/reversi');
        break;
      default:
        break;
    }
  });

  return {
    teardown() {
      document.body.classList.remove('m-body');
      mountEl.innerHTML = '';
    },
  };
}
