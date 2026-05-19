/**
 * Quick Return — skeniraj barkod alata i potvrdi povraćaj (pun ekran skener).
 */

import { showToast } from '../../lib/dom.js';
import {
  confirmReturn,
  confirmCuttingReturn,
  fetchOpenHandLineByToolBarcode,
  fetchMyIssuedCuttingTools,
  getMagacinLocationId,
} from '../../services/reversiService.js';
import { openReversiScanOverlay } from './scanOverlay.js';

/**
 * @param {{ onSuccess?: () => void }} opts
 */
export function openQuickReturnModal(opts = {}) {
  let magacinId = null;

  const runReturn = async (match) => {
    if (!match) return;
    if (!magacinId) {
      const mid = await getMagacinLocationId();
      if (!mid) {
        showToast('Magacin nije pronađen');
        return;
      }
      magacinId = mid;
    }
    if (match.kind === 'HAND') {
      const res = await confirmReturn({
        doc_id: match.document_id,
        return_to_location_id: magacinId,
        return_notes: 'Quick return',
        returned_lines: [{ line_id: match.line_id, returned_quantity: 1 }],
      });
      if (!res.ok) {
        showToast(res.error || 'Greška povraćaja');
        return;
      }
      showToast('Vraćeno');
      opts.onSuccess?.();
      return;
    }
    const res = await confirmCuttingReturn({
      line_id: match.line_id,
      returned_quantity: match.return_qty,
      return_to_location_id: magacinId,
      return_notes: 'Quick return',
    });
    if (!res.ok) {
      showToast(res.error || 'Greška povraćaja');
      return;
    }
    showToast('Vraćeno');
    opts.onSuccess?.();
  };

  async function resolveMatch(parsed) {
    const bc = parsed.barcode;
    if (parsed.kind === 'HAND') {
      const r = await fetchOpenHandLineByToolBarcode(bc);
      if (!r.ok || !r.data) {
        showToast('Nema otvorenog reversa za ovaj alat');
        return null;
      }
      return {
        kind: 'HAND',
        barcode: bc,
        doc_number: r.data.doc_number,
        recipient_label: r.data.recipient_label,
        line_id: r.data.line_id,
        document_id: r.data.document_id,
        return_qty: 1,
      };
    }
    if (parsed.kind === 'CUTTING') {
      const my = await fetchMyIssuedCuttingTools();
      const rows = my.ok && Array.isArray(my.data) ? my.data : [];
      const hit = rows.find((x) => String(x.barcode || '').toUpperCase() === bc.toUpperCase());
      if (!hit?.line_id) {
        showToast('Nema vašeg otvorenog zaduženja za ovu šifru');
        return null;
      }
      const rem = Number(hit.remaining_quantity ?? hit.quantity ?? 0);
      return {
        kind: 'CUTTING',
        barcode: hit.barcode,
        doc_number: hit.doc_number,
        recipient_label: hit.issued_to_employee_name || '—',
        line_id: hit.line_id,
        return_qty: rem > 0 ? rem : 1,
      };
    }
    return null;
  }

  openReversiScanOverlay({
    title: 'Skeniraj povraćaj',
    hint: 'Skeniraj ALAT-… ili RZN-… — skener ostaje otvoren posle svakog vraćanja',
    acceptKinds: ['HAND', 'CUTTING'],
    continuous: true,
    onResult: async (parsed) => {
      const match = await resolveMatch(parsed);
      if (!match) return;
      const ok = window.confirm(
        `Vraćaš ${match.barcode} sa reversa ${match.doc_number} (${match.recipient_label})?`,
      );
      if (!ok) return;
      await runReturn(match);
    },
  });
}
