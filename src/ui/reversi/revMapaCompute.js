/**
 * Pure compute za Reversi "Mapa" pregled (testabilno).
 */

const MS_DAY = 86400000;

/**
 * @param {object[]} documents rev_documents (OPEN / PARTIALLY_RETURNED)
 * @returns {{ fresh: number, aging: number, overdue: number, total: number }}
 */
export function computeAgingBuckets(documents) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayMs = today.getTime();
  let fresh = 0;
  let aging = 0;
  let overdue = 0;
  for (const d of documents || []) {
    const exp = d.expected_return_date ? String(d.expected_return_date).slice(0, 10) : null;
    if (exp && exp < today.toISOString().slice(0, 10)) {
      overdue += 1;
      continue;
    }
    const issued = d.issued_at ? new Date(d.issued_at) : null;
    if (!issued || Number.isNaN(issued.getTime())) {
      aging += 1;
      continue;
    }
    const days = Math.floor((todayMs - issued.getTime()) / MS_DAY);
    if (days <= 7) fresh += 1;
    else if (days <= 30) aging += 1;
    else overdue += 1;
  }
  return { fresh, aging, overdue, total: fresh + aging + overdue };
}

/**
 * @param {object[]} documents aktivni CUTTING_TOOL dokumenti sa recipient_machine_code
 * @param {object[]} machines bigtehn_machines_cache redovi
 * @param {{ capacity?: number }} [opts]
 * @returns {Array<{ machine_code: string, machine_name: string, symbol_count: number, fill_pct: number, overdue_count: number }>}
 */
export function computeMachineLoadCards(documents, machines, opts = {}) {
  const cap = Number(opts.capacity) > 0 ? Number(opts.capacity) : 20;
  const today = new Date().toISOString().slice(0, 10);
  const symByMc = new Map();
  const overdueByMc = new Map();

  for (const d of documents || []) {
    const mc = d.recipient_machine_code;
    if (!mc) continue;
    if (d.expected_return_date && String(d.expected_return_date).slice(0, 10) < today) {
      overdueByMc.set(mc, (overdueByMc.get(mc) || 0) + 1);
    }
  }

  for (const row of documents || []) {
    const mc = row.recipient_machine_code || row.machine_code;
    if (!mc) continue;
    const cat = row.catalog_id || row.cutting_tool_catalog_id || row.oznaka || row.id;
    if (!symByMc.has(mc)) symByMc.set(mc, new Set());
    if (cat) symByMc.get(mc).add(String(cat));
  }

  const nameByCode = new Map();
  for (const m of machines || []) {
    if (m.rj_code) nameByCode.set(m.rj_code, m.name || '');
  }

  const codes = new Set([...symByMc.keys(), ...(documents || []).map((d) => d.recipient_machine_code).filter(Boolean)]);
  return Array.from(codes)
    .map((machine_code) => {
      const symbol_count = symByMc.get(machine_code)?.size || 0;
      if (symbol_count === 0) return null;
      const fill_pct = Math.min(100, Math.round((symbol_count / cap) * 100));
      return {
        machine_code,
        machine_name: nameByCode.get(machine_code) || '',
        symbol_count,
        fill_pct,
        overdue_count: overdueByMc.get(machine_code) || 0,
      };
    })
    .filter(Boolean)
    .sort((a, b) => b.symbol_count - a.symbol_count);
}

/**
 * @param {object[]} catalogRows
 * @returns {Array<{ id: string, oznaka: string, naziv: string, qty: number, min: number }>}
 */
export function computeLowStockTop10(catalogRows) {
  const low = (catalogRows || [])
    .filter((r) => {
      const min = Number(r.min_stock_qty) || 0;
      const wh = Number(r.in_warehouse_qty) || 0;
      return r.status === 'active' && min > 0 && wh < min;
    })
    .map((r) => ({
      id: r.id,
      oznaka: r.oznaka,
      naziv: r.naziv,
      qty: Number(r.in_warehouse_qty) || 0,
      min: Number(r.min_stock_qty) || 0,
    }))
    .sort((a, b) => a.qty / a.min - b.qty / b.min);
  return low.slice(0, 10);
}
