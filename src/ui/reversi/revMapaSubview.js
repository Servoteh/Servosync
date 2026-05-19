/**
 * Reversi rezni alat — sub-tab "Mapa" (grafički pregled).
 */

import { escHtml } from '../../lib/dom.js';
import {
  fetchCuttingByMachine,
  fetchCuttingToolCatalog,
  fetchDocuments,
  fetchMachines,
} from '../../services/reversiService.js';
import { openCuttingToolDetailsModal } from './cuttingToolModals.js';
import {
  computeAgingBuckets,
  computeLowStockTop10,
  computeMachineLoadCards,
} from './revMapaCompute.js';

/** @param {HTMLElement} host */
/** @param {{ onNavigateMachine?: (code: string) => void }} opts */
export async function renderMapaSubview(host, opts = {}) {
  host.innerHTML = '<div class="rev-loading-card">Učitavanje mape…</div>';

  const [cutRes, docRes, catRes, machRes] = await Promise.all([
    fetchCuttingByMachine({}),
    fetchDocuments({ statuses: ['OPEN', 'PARTIALLY_RETURNED'], limit: 500, offset: 0 }),
    fetchCuttingToolCatalog({ status: 'active', limit: 500, offset: 0 }),
    fetchMachines({}),
  ]);

  const cuttingRows = cutRes.ok && Array.isArray(cutRes.data) ? cutRes.data : [];
  const docs = docRes.ok && docRes.data?.rows ? docRes.data.rows : [];
  const catalog = catRes.ok && catRes.data?.rows ? catRes.data.rows : [];
  const machines = machRes.ok && Array.isArray(machRes.data) ? machRes.data : [];

  const docForAging = docs.filter((d) => d.doc_type === 'CUTTING_TOOL' || d.doc_type === 'TOOL');
  const aging = computeAgingBuckets(docForAging);

  const machineDocs = cuttingRows.map((r) => ({
    recipient_machine_code: r.machine_code,
    catalog_id: r.catalog_id,
    expected_return_date: null,
  }));
  for (const d of docs) {
    if (d.doc_type === 'CUTTING_TOOL' && d.recipient_machine_code) {
      machineDocs.push({
        recipient_machine_code: d.recipient_machine_code,
        catalog_id: d.id,
        expected_return_date: d.expected_return_date,
      });
    }
  }
  const cards = computeMachineLoadCards(machineDocs, machines);
  const lowStock = computeLowStockTop10(catalog);

  host.innerHTML = `
    <div class="rev-mapa">
      <section class="rev-mapa-section">
        <h3 class="rev-h3">Mapa mašina</h3>
        <div class="rev-mapa-machine-grid">
          ${
            cards.length === 0
              ? '<p class="rev-muted">Nema aktivnih zaduženja po mašinama.</p>'
              : cards
                  .map(
                    (c) => `<article class="rev-mapa-mcard" data-mapa-mc="${escHtml(c.machine_code)}" tabindex="0">
              <div class="rev-mapa-mcard-title">${escHtml(c.machine_code)}</div>
              <div class="rev-mapa-mcard-sub">${escHtml(c.machine_name || '')}</div>
              <div class="rev-mapa-mcard-stat">${escHtml(String(c.symbol_count))} šifri</div>
              <div class="rev-mapa-progress" aria-hidden="true"><span style="width:${c.fill_pct}%"></span></div>
              <div class="rev-mapa-mcard-pct">${escHtml(String(c.fill_pct))}%</div>
              ${c.overdue_count > 0 ? `<span class="rev-mapa-overdue">+ ${c.overdue_count} prekoračena</span>` : ''}
            </article>`,
                  )
                  .join('')
          }
        </div>
      </section>

      <section class="rev-mapa-section rev-mapa-aging">
        <h3 class="rev-h3">Aging zaduženja</h3>
        <div class="rev-mapa-donut-wrap">
          ${renderDonutSvg(aging)}
          <ul class="rev-mapa-legend">
            <li><span class="rev-mapa-dot rev-mapa-dot--fresh"></span> Sveže (≤7 d) — ${aging.fresh}</li>
            <li><span class="rev-mapa-dot rev-mapa-dot--aging"></span> Stari (8–30 d) — ${aging.aging}</li>
            <li><span class="rev-mapa-dot rev-mapa-dot--overdue"></span> Prekoračeni — ${aging.overdue}</li>
          </ul>
        </div>
      </section>

      <section class="rev-mapa-section">
        <h3 class="rev-h3">Top 10 niskih stanja</h3>
        ${
          lowStock.length === 0
            ? '<p class="rev-muted">Nema šifara ispod minimuma.</p>'
            : `<ul class="rev-mapa-low-list">${lowStock
                .map((r) => {
                  const pct = r.min > 0 ? Math.round((r.qty / r.min) * 100) : 0;
                  return `<li class="rev-mapa-low-row" data-mapa-cat="${escHtml(r.id)}" tabindex="0">
                <span class="rev-mapa-low-name">${escHtml(r.oznaka)} — ${escHtml((r.naziv || '').slice(0, 32))}</span>
                <span class="rev-mapa-low-bar"><span style="width:${Math.min(100, pct)}%"></span></span>
                <span class="rev-mapa-low-qty">${r.qty}/${r.min}</span>
              </li>`;
                })
                .join('')}</ul>`
        }
      </section>
    </div>`;

  host.querySelectorAll('[data-mapa-mc]').forEach((el) => {
    const go = () => opts.onNavigateMachine?.(el.getAttribute('data-mapa-mc') || '');
    el.addEventListener('click', go);
    el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') go();
    });
  });

  host.querySelectorAll('[data-mapa-cat]').forEach((el) => {
    const go = () => {
      const id = el.getAttribute('data-mapa-cat');
      const row = catalog.find((c) => c.id === id);
      if (row) openCuttingToolDetailsModal({ tool: row });
    };
    el.addEventListener('click', go);
    el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') go();
    });
  });
}

/**
 * @param {{ fresh: number, aging: number, overdue: number, total: number }} buckets
 */
function renderDonutSvg(buckets) {
  const total = buckets.total || 0;
  const r = 42;
  const c = 2 * Math.PI * r;
  const segs = [
    { n: buckets.fresh, cls: 'rev-donut-fresh' },
    { n: buckets.aging, cls: 'rev-donut-aging' },
    { n: buckets.overdue, cls: 'rev-donut-overdue' },
  ];
  let offset = 0;
  const circles = segs
    .map((s) => {
      const len = total > 0 ? (s.n / total) * c : 0;
      const dash = `${len} ${c - len}`;
      const el = `<circle class="${s.cls}" cx="50" cy="50" r="${r}" fill="none" stroke-width="14"
        stroke-dasharray="${dash}" stroke-dashoffset="${-offset}" transform="rotate(-90 50 50)"/>`;
      offset += len;
      return el;
    })
    .join('');
  return `<svg class="rev-mapa-donut" viewBox="0 0 100 100" role="img" aria-label="Aging zaduženja">
    ${circles}
    <text x="50" y="52" text-anchor="middle" class="rev-mapa-donut-center">${total}</text>
  </svg>`;
}
