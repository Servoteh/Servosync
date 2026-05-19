/**
 * Reversi modul — Supabase pozivi (rev_*, loc_*, view).
 */

import { sbReq, sbReqWithCount, sbReqThrow, hasSupabaseConfig, getSupabaseUrl, getSupabaseHeaders } from './supabase.js';
import { locCreateMovement } from './lokacije.js';

const MAG_CODE = 'ALAT-MAG-01';

/** @type {string|null|undefined} undefined = not loaded */
let magacinLocationIdCache;

function formatErr(e, fallback = 'Nepoznata greška') {
  if (!e) return fallback;
  if (typeof e === 'string') return e;
  if (e.message) return String(e.message);
  return fallback;
}

/**
 * @returns {{ ok: boolean, data?: any, error?: string }}
 */
function wrap(fn) {
  return async (...args) => {
    try {
      const data = await fn(...args);
      return { ok: true, data };
    } catch (e) {
      console.error('[reversiService]', e);
      return { ok: false, error: formatErr(e) };
    }
  };
}

/**
 * @param {{
 *   status?: string,
 *   statuses?: string[],
 *   overdue?: boolean,
 *   search?: string,
 *   recipient_search?: string,
 *   doc_type?: string,
 *   issued_from?: string,
 *   issued_to?: string,
 *   limit?: number,
 *   offset?: number,
 * }} params
 */
export async function fetchDocuments(params = {}) {
  return wrap(async () => {
    const limit = Math.max(1, Math.min(Number(params.limit) || 25, 100));
    const offset = Math.max(0, Number(params.offset) || 0);
    const parts = [
      'select=*',
      'rev_document_lines(count)',
      `order=issued_at.desc`,
      `limit=${limit}`,
      `offset=${offset}`,
    ];

    const from = params.issued_from && String(params.issued_from).trim();
    const to = params.issued_to && String(params.issued_to).trim();
    if (from) {
      parts.push(`issued_at=gte.${encodeURIComponent(from)}`);
    }
    if (to) {
      parts.push(`issued_at=lte.${encodeURIComponent(to)}`);
    }

    if (params.overdue === true) {
      const today = new Date().toISOString().slice(0, 10);
      parts.push(
        `and=(or(status.eq.OPEN,status.eq.PARTIALLY_RETURNED),expected_return_date.lt.${today})`,
      );
    } else {
      const multi = Array.isArray(params.statuses) ? params.statuses.filter(Boolean) : [];
      if (multi.length > 0) {
        parts.push(`status=in.(${multi.map((s) => encodeURIComponent(String(s).trim())).join(',')})`);
      } else {
        const st = params.status && String(params.status).trim();
        if (st && st !== 'ALL') {
          parts.push(`status=eq.${encodeURIComponent(st)}`);
        }
      }
    }

    const dt = params.doc_type && String(params.doc_type).trim();
    if (dt === 'TOOL') parts.push('doc_type=eq.TOOL');
    else if (dt === 'COOPERATION_GOODS') parts.push('doc_type=eq.COOPERATION_GOODS');

    const rawQ = params.search ?? params.recipient_search;
    const rs = rawQ && String(rawQ).trim();
    if (rs) {
      const enc = encodeURIComponent(`*${rs}*`);
      parts.push(
        `or=(doc_number.ilike.${enc},recipient_employee_name.ilike.${enc},recipient_department.ilike.${enc},recipient_company_name.ilike.${enc})`,
      );
    }

    const q = `rev_documents?${parts.join('&')}`;
    const res = await sbReqWithCount(q);
    const rows = Array.isArray(res?.rows) ? res.rows : [];
    const mapped = rows.map((r) => {
      const cnt =
        Array.isArray(r.rev_document_lines) && r.rev_document_lines[0]
          ? Number(r.rev_document_lines[0].count) || 0
          : 0;
      const { rev_document_lines: _rl, ...doc } = r;
      return { ...doc, line_count: cnt };
    });
    return { rows: mapped, total: res?.total ?? null };
  })();
}

/**
 * Broj različitih primalaca na aktivnim dokumentima (gruba procena ako ima više od cap redova).
 * @param {{ cap?: number, issued_from?: string, issued_to?: string, doc_type?: string, search?: string }} [opts]
 */
export async function fetchOpenRecipientCardinality(opts = {}) {
  return wrap(async () => {
    const cap = Math.max(50, Math.min(Number(opts.cap) || 2500, 5000));
    const parts = [
      'select=recipient_type,recipient_employee_id,recipient_department,recipient_company_name',
      'status=in.(OPEN,PARTIALLY_RETURNED)',
      `limit=${cap}`,
    ];
    const from = opts.issued_from && String(opts.issued_from).trim();
    const to = opts.issued_to && String(opts.issued_to).trim();
    if (from) parts.push(`issued_at=gte.${encodeURIComponent(from)}`);
    if (to) parts.push(`issued_at=lte.${encodeURIComponent(to)}`);
    const dt = opts.doc_type && String(opts.doc_type).trim();
    if (dt === 'TOOL') parts.push('doc_type=eq.TOOL');
    else if (dt === 'COOPERATION_GOODS') parts.push('doc_type=eq.COOPERATION_GOODS');
    const rawQ = opts.search;
    const rs = rawQ && String(rawQ).trim();
    if (rs) {
      const enc = encodeURIComponent(`*${rs}*`);
      parts.push(
        `or=(doc_number.ilike.${enc},recipient_employee_name.ilike.${enc},recipient_department.ilike.${enc},recipient_company_name.ilike.${enc})`,
      );
    }
    const q = `rev_documents?${parts.join('&')}`;
    const rows = await sbReq(q);
    const list = Array.isArray(rows) ? rows : [];
    const keys = new Set();
    for (const r of list) {
      const rt = r.recipient_type;
      if (rt === 'EMPLOYEE' && r.recipient_employee_id) {
        keys.add(`e:${r.recipient_employee_id}`);
      } else if (rt === 'DEPARTMENT' && r.recipient_department) {
        keys.add(`d:${String(r.recipient_department).trim()}`);
      } else if (r.recipient_company_name) {
        keys.add(`c:${String(r.recipient_company_name).trim()}`);
      } else if (r.recipient_department) {
        keys.add(`d:${String(r.recipient_department).trim()}`);
      } else {
        keys.add(`u:${JSON.stringify(r)}`);
      }
    }
    return { count: keys.size, truncated: list.length >= cap };
  })();
}

/**
 * @param {string} documentId
 */
export async function fetchDocumentLines(documentId) {
  return wrap(async () => {
    const q =
      `rev_document_lines?document_id=eq.${encodeURIComponent(documentId)}` +
      '&select=*,rev_tools(oznaka,naziv,serijski_broj,loc_item_ref_id)' +
      '&order=sort_order.asc';
    const rows = await sbReq(q);
    return Array.isArray(rows) ? rows : [];
  })();
}

/**
 * @param {{ status?: string, search?: string, asset_kind?: string, limit?: number, offset?: number }} params
 */
export async function fetchTools(params = {}) {
  return wrap(async () => {
    const limit = Math.max(1, Math.min(Number(params.limit) || 24, 100));
    const offset = Math.max(0, Number(params.offset) || 0);
    const parts = ['select=*', `order=oznaka.asc`, `limit=${limit}`, `offset=${offset}`];

    const st = params.status && String(params.status).trim();
    if (st === 'active') parts.push(`status=eq.active`);
    else if (st === 'scrapped') parts.push(`status=eq.scrapped`);
    else if (st === 'lost') parts.push(`status=eq.lost`);
    /* 'all' — bez filtera na status */

    const search = params.search && String(params.search).trim();
    if (search) {
      const enc = encodeURIComponent(`*${search}*`);
      parts.push(`or=(oznaka.ilike.${enc},naziv.ilike.${enc},barcode.ilike.${enc})`);
    }

    const ak = params.asset_kind && String(params.asset_kind).trim();
    if (ak && ak !== 'ALL') {
      parts.push(`asset_kind=eq.${encodeURIComponent(ak)}`);
    }

    const qTools = `rev_tools?${parts.join('&')}`;
    const res = await sbReqWithCount(qTools);
    const tools = Array.isArray(res?.rows) ? res.rows : [];
    if (tools.length === 0) return { rows: [], total: res?.total ?? 0 };

    const ids = tools.map((t) => t.id).filter(Boolean);
    const refIds = tools.map((t) => t.loc_item_ref_id).filter(Boolean);

    const inList = (arr) => arr.map((x) => encodeURIComponent(x)).join(',');

    const placements =
      refIds.length > 0
        ? await sbReq(
            `loc_item_placements?item_ref_table=eq.rev_tools&item_ref_id=in.(${inList(refIds)})&select=*,loc_locations(location_code,name)`,
          )
        : [];
    const placeByRef = new Map(
      (Array.isArray(placements) ? placements : []).map((p) => [p.item_ref_id, p]),
    );

    const lines =
      ids.length > 0
        ? await sbReq(
            `rev_document_lines?tool_id=in.(${inList(ids)})&line_status=eq.ISSUED&select=*,rev_documents(doc_number,recipient_type,recipient_employee_name,recipient_department,recipient_company_name,status)`,
          )
        : [];
    const issuedByTool = new Map();
    for (const ln of Array.isArray(lines) ? lines : []) {
      if (!ln.tool_id) continue;
      const doc = ln.rev_documents;
      const d = Array.isArray(doc) ? doc[0] : doc;
      if (d && (d.status === 'OPEN' || d.status === 'PARTIALLY_RETURNED')) {
        issuedByTool.set(ln.tool_id, { line: ln, doc: d });
      }
    }

    const magId = await getMagacinLocationId();
    const rowsOut = tools.map((t) => {
      const pl = placeByRef.get(t.loc_item_ref_id);
      const locNested = pl?.loc_locations;
      const locRow = Array.isArray(locNested) ? locNested[0] : locNested;
      const issued = issuedByTool.get(t.id);
      const locCode = locRow?.location_code ?? null;
      return {
        ...t,
        placement: pl || null,
        current_location_id: pl?.location_id ?? null,
        current_location_code: locCode,
        issued_holder: issued || null,
      };
    });

    return { rows: rowsOut, total: res?.total ?? null, magacinLocationId: magId };
  })();
}

export async function fetchAvailableTools() {
  return wrap(async () => {
    const magId = await getMagacinLocationId();
    const allActive = await sbReq(
      'rev_tools?status=eq.active&select=*&order=oznaka.asc&limit=500',
    );
    const tools = Array.isArray(allActive) ? allActive : [];
    if (tools.length === 0) return [];

    const ids = tools.map((t) => t.id);
    const refIds = tools.map((t) => t.loc_item_ref_id).filter(Boolean);
    const inList = (arr) => arr.map((x) => encodeURIComponent(x)).join(',');

    const placements =
      refIds.length > 0
        ? await sbReq(
            `loc_item_placements?item_ref_table=eq.rev_tools&item_ref_id=in.(${inList(refIds)})&select=*`,
          )
        : [];
    const placeByRef = new Map(
      (Array.isArray(placements) ? placements : []).map((p) => [p.item_ref_id, p]),
    );

    const lines =
      ids.length > 0
        ? await sbReq(
            `rev_document_lines?tool_id=in.(${inList(ids)})&line_status=eq.ISSUED&select=tool_id,rev_documents(status)`,
          )
        : [];
    const hasIssued = new Set();
    for (const ln of Array.isArray(lines) ? lines : []) {
      const doc = ln.rev_documents;
      const d = Array.isArray(doc) ? doc[0] : doc;
      if (d && (d.status === 'OPEN' || d.status === 'PARTIALLY_RETURNED')) {
        hasIssued.add(ln.tool_id);
      }
    }

    return tools.filter((t) => {
      if (hasIssued.has(t.id)) return false;
      const pl = placeByRef.get(t.loc_item_ref_id);
      const atMag = magId && pl?.location_id === magId;
      const noPlacement = !pl;
      /* Spec: u magacinu ILI bez aktivnog ISSUED reda — ovde je ISSUED već isključen; dozvoli i bez placement-a */
      return atMag || noPlacement;
    });
  })();
}

export async function fetchEmployees(search) {
  return wrap(async () => {
    const s = typeof search === 'string' ? search.trim() : '';
    let q = 'employees?select=id,full_name,email&is_active=eq.true&order=full_name.asc&limit=25';
    if (s) {
      const enc = encodeURIComponent(`*${s}*`);
      q += `&full_name=ilike.${enc}`;
    }
    const rows = await sbReq(q);
    return Array.isArray(rows) ? rows : [];
  })();
}

/**
 * Pretraži radnika BEZ is_active filtera i sa većim limit-om — za bulk import
 * gde nam smeta da neaktivan radnik blokira import. Vraća do 200 redova.
 *
 * @param {string} search
 */
export async function fetchEmployeesAny(search) {
  return wrap(async () => {
    const s = typeof search === 'string' ? search.trim() : '';
    let q = 'employees?select=id,full_name,email,is_active,department&order=full_name.asc&limit=200';
    if (s) {
      const enc = encodeURIComponent(`*${s}*`);
      q += `&full_name=ilike.${enc}`;
    }
    const rows = await sbReq(q);
    return Array.isArray(rows) ? rows : [];
  })();
}

export async function issueReversal(payload) {
  return wrap(async () => {
    const raw = await sbReqThrow('rpc/rev_issue_reversal', 'POST', { p_payload: payload }, { upsert: false });
    return raw;
  })();
}

export async function confirmReturn(payload) {
  return wrap(async () => {
    const raw = await sbReqThrow('rpc/rev_confirm_return', 'POST', { p_payload: payload }, { upsert: false });
    return raw;
  })();
}

export async function getMagacinLocationId() {
  if (!hasSupabaseConfig()) return null;
  if (magacinLocationIdCache !== undefined) return magacinLocationIdCache;
  const row = await sbReq(
    `loc_locations?location_code=eq.${encodeURIComponent(MAG_CODE)}&select=id&limit=1`,
  );
  const id = Array.isArray(row) && row[0]?.id ? row[0].id : null;
  magacinLocationIdCache = id;
  return id;
}

export function clearMagacinLocationCache() {
  magacinLocationIdCache = undefined;
}

export async function fetchMyIssuedTools() {
  return wrap(async () => {
    const rows = await sbReq('v_rev_my_issued_tools?select=*&order=issued_at.desc&limit=100');
    return Array.isArray(rows) ? rows : [];
  })();
}

/**
 * @param {object} toolRow polja za rev_tools
 */
export async function insertTool(toolRow) {
  return wrap(async () => {
    const row = await sbReqThrow('rev_tools', 'POST', toolRow, { upsert: false });
    const created = Array.isArray(row) ? row[0] : row;
    if (!created?.id || !created?.loc_item_ref_id) {
      throw new Error('Insert alata nije vratio očekivani red');
    }
    return created;
  })();
}

/**
 * Početni smeštaj alata u magacin (INITIAL_PLACEMENT).
 * @param {string} locItemRefId iz rev_tools.loc_item_ref_id
 * @param {string} magacinLocationId
 */
export async function initialPlacementForTool(locItemRefId, magacinLocationId) {
  return wrap(async () => {
    const res = await locCreateMovement({
      item_ref_table: 'rev_tools',
      item_ref_id: locItemRefId,
      to_location_id: magacinLocationId,
      movement_type: 'INITIAL_PLACEMENT',
      movement_reason: 'Ručni unos alata — Reversi UI',
      note: '',
      quantity: 1,
      order_no: '',
      drawing_no: '',
    });
    if (!res || res.ok !== true) {
      throw new Error(res?.error || 'loc_create_movement nije uspeo');
    }
    return res;
  })();
}

/**
 * Aktivne lokacije za dropdown povraćaja.
 */
export async function fetchActiveLocations() {
  return wrap(async () => {
    const rows = await sbReq(
      'loc_locations?is_active=eq.true&select=id,location_code,name,location_type&order=location_code.asc&limit=500',
    );
    return Array.isArray(rows) ? rows : [];
  })();
}

/**
 * Jedan reversal dokument (zaglavlje).
 * @param {string} documentId
 */
export async function fetchDocumentById(documentId) {
  return wrap(async () => {
    const rows = await sbReq(
      `rev_documents?id=eq.${encodeURIComponent(documentId)}&select=*&limit=1`,
    );
    const row = Array.isArray(rows) && rows[0] ? rows[0] : null;
    if (!row) throw new Error('Dokument nije pronađen');
    return row;
  })();
}

/**
 * @param {string|null|undefined} employeeId
 * @returns {{ ok: boolean, data?: string|null, error?: string }}
 */
export async function fetchEmployeeDepartment(employeeId) {
  return wrap(async () => {
    if (!employeeId) return null;
    const rows = await sbReq(
      `employees?id=eq.${encodeURIComponent(employeeId)}&select=department&limit=1`,
    );
    const row = Array.isArray(rows) && rows[0] ? rows[0] : null;
    return row?.department ?? null;
  })();
}

/**
 * Upload-uje PDF blob u Storage bucket `reversal-pdf`.
 * Path u bucket-u: `{docNumber}.pdf`
 * @param {string} docNumber
 * @param {Blob} pdfBlob
 * @returns {Promise<string>} Putanja unutar bucket-a (npr. `REV-TOOL-2026-0001.pdf`)
 */
export async function uploadReversalPdf(docNumber, pdfBlob) {
  if (!hasSupabaseConfig()) throw new Error('Supabase nije konfigurisan');
  const safeName = String(docNumber || 'document').replace(/[^\w.\-]+/g, '_');
  const path = `${safeName}.pdf`;
  const url = `${getSupabaseUrl().replace(/\/$/, '')}/storage/v1/object/reversal-pdf/${encodeURIComponent(path)}`;

  const r = await fetch(url, {
    method: 'POST',
    headers: {
      ...getSupabaseHeaders(),
      'Content-Type': 'application/pdf',
      'x-upsert': 'true',
    },
    body: pdfBlob,
  });

  const txt = await r.text();
  if (!r.ok) {
    let msg = txt?.trim() || `HTTP ${r.status}`;
    try {
      const j = JSON.parse(txt);
      if (j?.message) msg = String(j.message);
    } catch {
      /* ignore */
    }
    throw new Error(`PDF upload nije uspeo: ${msg}`);
  }

  return path;
}

/* ============================================================
 * Rezni alat (Sprint RZ-2) — katalog, stock, RPC-i, scanner lookup
 * ============================================================ */

/**
 * Lista šifri reznog alata:
 *   - U magacinu: suma stock redova gde je lokacija tipa WAREHOUSE
 *   - Na mašinama: suma otvorenih zaduženja iz v_rev_cts_machine_stock (količina − vraćeno)
 *   - Ukupno: magacin + na mašinama
 *
 * @param {{ search?: string, status?: 'active'|'scrapped'|'all', machine?: string, klasa?: string, limit?: number, offset?: number }} params
 */
export async function fetchCuttingToolCatalog(params = {}) {
  return wrap(async () => {
    const limit = Math.max(1, Math.min(Number(params.limit) || 25, 15_000));
    const offset = Math.max(0, Number(params.offset) || 0);
    const parts = ['select=*', 'order=oznaka.asc', `limit=${limit}`, `offset=${offset}`];

    const st = params.status && String(params.status).trim();
    if (st === 'active') parts.push('status=eq.active');
    else if (st === 'scrapped') parts.push('status=eq.scrapped');

    const search = params.search && String(params.search).trim();
    if (search) {
      const enc = encodeURIComponent(`*${search}*`);
      parts.push(`or=(oznaka.ilike.${enc},naziv.ilike.${enc},klasa.ilike.${enc},barcode.ilike.${enc})`);
    }
    const kl = params.klasa && String(params.klasa).trim();
    if (kl) {
      parts.push(`klasa=eq.${encodeURIComponent(kl)}`);
    }

    const m = params.machine && String(params.machine).trim();
    if (m) {
      parts.push(`compatible_machine_codes=cs.{${encodeURIComponent(m)}}`);
    }

    const q = `rev_cutting_tool_catalog?${parts.join('&')}`;
    const res = await sbReqWithCount(q);
    const rows = Array.isArray(res?.rows) ? res.rows : [];
    if (rows.length === 0) return { rows: [], total: res?.total ?? 0 };

    const ids = rows.map((r) => r.id);
    const inList = ids.map((x) => encodeURIComponent(x)).join(',');
    const stockRows = await sbReq(
      `rev_cutting_tool_stock?catalog_id=in.(${inList})&select=catalog_id,location_id,on_hand_qty,loc_locations(location_code,location_type)`,
    );
    const stockByCatalog = new Map();
    for (const s of Array.isArray(stockRows) ? stockRows : []) {
      const k = s.catalog_id;
      if (!stockByCatalog.has(k)) stockByCatalog.set(k, []);
      stockByCatalog.get(k).push(s);
    }

    let msRows = [];
    try {
      msRows = await sbReq(
        `v_rev_cts_machine_stock?catalog_id=in.(${inList})&select=catalog_id,machine_code,outstanding_qty&limit=20000`,
      );
    } catch {
      msRows = [];
    }
    const machByCatalog = new Map();
    for (const row of Array.isArray(msRows) ? msRows : []) {
      const cid = row.catalog_id;
      if (!cid) continue;
      const mq = Number(row.outstanding_qty) || 0;
      if (!machByCatalog.has(cid)) {
        machByCatalog.set(cid, { total: 0, breakdown: [] });
      }
      const o = machByCatalog.get(cid);
      if (mq > 0) {
        o.total += mq;
        o.breakdown.push({ masina: row.machine_code || '', kolicina: mq });
      }
    }

    const enriched = rows.map((r) => {
      const stock = stockByCatalog.get(r.id) || [];
      let inWarehouse = 0;
      let stockWarehouseSum = 0;
      for (const s of stock) {
        const qty = Number(s.on_hand_qty) || 0;
        const loc = Array.isArray(s.loc_locations) ? s.loc_locations[0] : s.loc_locations;
        const lt = String(loc?.location_type || '').toUpperCase();
        if (lt === 'WAREHOUSE') {
          inWarehouse += qty;
          stockWarehouseSum += qty;
        }
      }
      const mach = machByCatalog.get(r.id) || { total: 0, breakdown: [] };
      const onMachines = mach.total;
      const machineBreakdown = [...mach.breakdown].sort((a, b) =>
        String(a.masina).localeCompare(String(b.masina), 'sr'),
      );
      const totalOnHand = inWarehouse + onMachines;
      return {
        ...r,
        total_on_hand: totalOnHand,
        on_machines_qty: onMachines,
        in_warehouse_qty: inWarehouse,
        stock,
        machine_breakdown: machineBreakdown,
        stock_warehouse_qty: stockWarehouseSum,
      };
    });

    return { rows: enriched, total: res?.total ?? null };
  })();
}

/**
 * Stock detaljno po lokaciji za jednu šifru (pregled gde je alat trenutno).
 * @param {string} catalogId
 */
export async function fetchCuttingToolStockDetails(catalogId) {
  return wrap(async () => {
    const rows = await sbReq(
      `rev_cutting_tool_stock?catalog_id=eq.${encodeURIComponent(catalogId)}` +
        '&select=*,loc_locations(location_code,name,location_type)' +
        '&order=on_hand_qty.desc',
    );
    return Array.isArray(rows) ? rows : [];
  })();
}

/**
 * Pretraži šifru po barkodu (Code128 sa nalepnice).
 * @param {string} barcode
 */
export async function fetchCuttingToolByBarcode(barcode) {
  return wrap(async () => {
    if (!barcode) return null;
    const rows = await sbReq(
      `rev_cutting_tool_catalog?barcode=eq.${encodeURIComponent(barcode)}&select=*&limit=1`,
    );
    return Array.isArray(rows) && rows[0] ? rows[0] : null;
  })();
}

/**
 * Ručni alat po barkodu (ALAT-…) sa proverom aktivnog zaduženja.
 * @param {string} barcode
 */
export async function fetchHandToolByBarcode(barcode) {
  return wrap(async () => {
    const bc = String(barcode || '').trim();
    if (!bc) return null;
    const rows = await sbReq(`rev_tools?barcode=eq.${encodeURIComponent(bc)}&select=*&limit=1`);
    const tool = Array.isArray(rows) && rows[0] ? rows[0] : null;
    if (!tool?.id) return null;
    const lines = await sbReq(
      `rev_document_lines?tool_id=eq.${encodeURIComponent(tool.id)}&line_status=eq.ISSUED&select=*,rev_documents(doc_number,status,recipient_type,recipient_employee_name,recipient_department,recipient_company_name)`,
    );
    let issued_holder = null;
    for (const ln of Array.isArray(lines) ? lines : []) {
      const doc = Array.isArray(ln.rev_documents) ? ln.rev_documents[0] : ln.rev_documents;
      if (doc && (doc.status === 'OPEN' || doc.status === 'PARTIALLY_RETURNED')) {
        issued_holder = { line: ln, doc };
        break;
      }
    }
    return { ...tool, issued_holder };
  })();
}

/**
 * Otvorena ISSUED linija ručnog alata po barkodu (za quick return).
 * @param {string} barcode
 */
export async function fetchOpenHandLineByToolBarcode(barcode) {
  return wrap(async () => {
    const bc = String(barcode || '').trim();
    if (!bc) return null;
    const rows = await sbReq(`rev_tools?barcode=eq.${encodeURIComponent(bc)}&select=*&limit=1`);
    const tool = Array.isArray(rows) && rows[0] ? rows[0] : null;
    if (!tool?.id) return null;
    const lines = await sbReq(
      `rev_document_lines?tool_id=eq.${encodeURIComponent(tool.id)}&line_status=eq.ISSUED&select=*,rev_documents(doc_number,status,recipient_employee_name,recipient_department,recipient_company_name)`,
    );
    for (const ln of Array.isArray(lines) ? lines : []) {
      const doc = Array.isArray(ln.rev_documents) ? ln.rev_documents[0] : ln.rev_documents;
      if (doc && (doc.status === 'OPEN' || doc.status === 'PARTIALLY_RETURNED')) {
        return {
          line_id: ln.id,
          document_id: doc.id,
          doc_number: doc.doc_number,
          tool,
          recipient_label:
            doc.recipient_employee_name || doc.recipient_department || doc.recipient_company_name || '—',
        };
      }
    }
    return null;
  })();
}

/**
 * Pretraži šifru po oznaci (exact match, case-insensitive trim). Za bulk import
 * gde izvor šalje oznake (npr. "GL-D12") umesto barkoda.
 * @param {string} oznaka
 */
export async function fetchCuttingToolByOznaka(oznaka) {
  return wrap(async () => {
    if (!oznaka) return null;
    const v = String(oznaka).trim();
    if (!v) return null;
    const rows = await sbReq(
      `rev_cutting_tool_catalog?oznaka=eq.${encodeURIComponent(v)}&select=*&limit=2`,
    );
    return Array.isArray(rows) && rows[0] ? rows[0] : null;
  })();
}

/** @param {object} payload polja za rev_cutting_tool_catalog */
export async function insertCuttingTool(payload) {
  return wrap(async () => {
    const row = await sbReqThrow('rev_cutting_tool_catalog', 'POST', payload, { upsert: false });
    const created = Array.isArray(row) ? row[0] : row;
    if (!created?.id || !created?.barcode) throw new Error('Insert šifre nije vratio očekivani red');
    return created;
  })();
}

/**
 * Update postojeće šifre (oznaka, naziv, klasa, mašine, status, napomena).
 * @param {string} id
 * @param {object} patch
 */
export async function updateCuttingTool(id, patch) {
  return wrap(async () => {
    const rows = await sbReqThrow(
      `rev_cutting_tool_catalog?id=eq.${encodeURIComponent(id)}`,
      'PATCH',
      patch,
      { upsert: false },
    );
    if (!Array.isArray(rows) || !rows[0]) throw new Error('Update šifre nije vratio red');
    return rows[0];
  })();
}

/**
 * Magacioner unosi inicijalno stanje reznog alata na lokaciju (najčešće ALAT-MAG-01).
 * @param {string} catalogId
 * @param {string} locationId
 * @param {number} qty pozitivan broj
 */
export async function seedCuttingToolStock(catalogId, locationId, qty) {
  return wrap(async () => {
    const raw = await sbReqThrow(
      'rpc/rev_cutting_tool_seed_stock',
      'POST',
      { p_catalog_id: catalogId, p_location_id: locationId, p_qty: qty },
      { upsert: false },
    );
    return raw;
  })();
}

export async function issueCuttingReversal(payload) {
  return wrap(async () => {
    const raw = await sbReqThrow('rpc/rev_issue_cutting_reversal', 'POST', { p_payload: payload }, { upsert: false });
    return raw;
  })();
}

export async function confirmCuttingReturn(payload) {
  return wrap(async () => {
    const raw = await sbReqThrow('rpc/rev_confirm_cutting_return', 'POST', { p_payload: payload }, { upsert: false });
    return raw;
  })();
}

export async function fetchMyIssuedCuttingTools() {
  return wrap(async () => {
    const rows = await sbReq(
      'v_rev_my_issued_cutting_tools?select=*&order=issued_at.desc&limit=200',
    );
    return Array.isArray(rows) ? rows : [];
  })();
}

/**
 * Pregled reznog alata po mašini — agregat (machine_code, catalog_id) sa preostalom količinom.
 * @param {{ search?: string }} [opts]
 */
export async function fetchCuttingByMachine(opts = {}) {
  return wrap(async () => {
    const parts = ['select=*', 'order=machine_code.asc,oznaka.asc', 'limit=1000'];
    const s = opts.search && String(opts.search).trim();
    if (s) {
      const enc = encodeURIComponent(`*${s}*`);
      parts.push(`or=(machine_code.ilike.${enc},machine_name.ilike.${enc},oznaka.ilike.${enc},naziv.ilike.${enc},barcode.ilike.${enc})`);
    }
    const rows = await sbReq(`v_rev_cts_by_machine?${parts.join('&')}`);
    return Array.isArray(rows) ? rows : [];
  })();
}

/**
 * Pregled reznog alata po zaposlenom (potpisniku).
 * @param {{ search?: string, department?: string }} [opts]
 */
export async function fetchCuttingByEmployee(opts = {}) {
  return wrap(async () => {
    const parts = ['select=*', 'order=employee_name.asc,oznaka.asc', 'limit=1000'];
    const s = opts.search && String(opts.search).trim();
    if (s) {
      const enc = encodeURIComponent(`*${s}*`);
      parts.push(`or=(employee_name.ilike.${enc},oznaka.ilike.${enc},naziv.ilike.${enc},barcode.ilike.${enc})`);
    }
    const dep = opts.department && String(opts.department).trim();
    if (dep) parts.push(`department=eq.${encodeURIComponent(dep)}`);
    const rows = await sbReq(`v_rev_cts_by_employee?${parts.join('&')}`);
    return Array.isArray(rows) ? rows : [];
  })();
}

/**
 * Magacin — UNION rev_tools (HAND) + rev_cutting_tool_catalog (CUTTING).
 * Vraća samo redove sa qty > 0 osim ako includeZero=true.
 * Sa allLocations=true koristi v_rev_inventory_all_locations (qty_total, location_label) ako view postoji.
 *
 * @param {{
 *   grupa?: 'HAND'|'CUTTING'|'ALL',
 *   search?: string,
 *   klasa?: string,
 *   includeZero?: boolean,
 *   allLocations?: boolean
 * }} [opts]
 */
export async function fetchUnifiedWarehouse(opts = {}) {
  return wrap(async () => {
    const allLoc = !!opts.allLocations;
    let view = allLoc ? 'v_rev_inventory_all_locations' : 'v_rev_warehouse_unified';
    const parts = ['select=*', 'order=grupa.asc,oznaka.asc', 'limit=1000'];
    const grupa = opts.grupa && String(opts.grupa).trim();
    if (grupa === 'HAND') parts.push('grupa=eq.HAND');
    else if (grupa === 'CUTTING') parts.push('grupa=eq.CUTTING');
    if (!opts.includeZero) {
      parts.push(allLoc ? 'qty_total=gt.0' : 'in_warehouse_qty=gt.0');
    }
    const klasa = opts.klasa && String(opts.klasa).trim();
    if (klasa) parts.push(`klasa=eq.${encodeURIComponent(klasa)}`);
    const s = opts.search && String(opts.search).trim();
    if (s) {
      const enc = encodeURIComponent(`*${s}*`);
      parts.push(`or=(oznaka.ilike.${enc},naziv.ilike.${enc},barcode.ilike.${enc},klasa.ilike.${enc})`);
    }
    try {
      const rows = await sbReq(`${view}?${parts.join('&')}`);
      return Array.isArray(rows) ? rows : [];
    } catch (e) {
      if (
        allLoc &&
        /relation|does not exist|42P01|404|PGRST205/i.test(String(e?.message || ''))
      ) {
        const fb = parts.filter((p) => !p.startsWith('qty_total='));
        if (!opts.includeZero) fb.push('in_warehouse_qty=gt.0');
        const rows = await sbReq(`v_rev_warehouse_unified?${fb.join('&')}`);
        return Array.isArray(rows) ? rows : [];
      }
      throw e;
    }
  })();
}

/**
 * Lista odeljenja iz employees tabele (DISTINCT, neprazno).
 */
export async function fetchEmployeeDepartments() {
  return wrap(async () => {
    const rows = await sbReq(
      'employees?select=department&is_active=eq.true&department=not.is.null&limit=2000',
    );
    const set = new Set();
    for (const r of Array.isArray(rows) ? rows : []) {
      const d = String(r.department || '').trim();
      if (d) set.add(d);
    }
    return Array.from(set).sort();
  })();
}

/**
 * Self-service: rezni alat na mašinama na kojima operater trenutno radi.
 * Fallback: ako view ne postoji (CI / nema production schema), vraća empty list bez greške.
 */
export async function fetchMyMachinesCuttingTools() {
  return wrap(async () => {
    try {
      const rows = await sbReq(
        'v_rev_my_machines_cutting_tools?select=*&order=recipient_machine_code.asc,issued_at.desc&limit=300',
      );
      return Array.isArray(rows) ? rows : [];
    } catch (e) {
      const msg = String(e?.message || '');
      if (/relation|does not exist|42P01|404/i.test(msg)) return [];
      throw e;
    }
  })();
}

/**
 * Lista mašina iz BigTehn cache-a (rj_code = "8.3", "10.1", ...).
 * @param {{ search?: string }} [opts]
 */
export async function fetchMachines(opts = {}) {
  return wrap(async () => {
    const parts = ['select=rj_code,name,no_procedure', 'order=rj_code.asc', 'limit=500'];
    const s = opts.search && String(opts.search).trim();
    if (s) {
      const enc = encodeURIComponent(`*${s}*`);
      parts.push(`or=(rj_code.ilike.${enc},name.ilike.${enc})`);
    }
    const rows = await sbReq(`bigtehn_machines_cache?${parts.join('&')}`);
    return Array.isArray(rows) ? rows : [];
  })();
}

/**
 * Pronađi radnika po card_barcode — koristi scanner za potpisnika preuzimanja.
 * @param {string} cardBarcode
 */
export async function fetchEmployeeByCardBarcode(cardBarcode) {
  return wrap(async () => {
    const v = String(cardBarcode || '').trim();
    if (!v) return null;
    const rows = await sbReq(
      `employees?card_barcode=eq.${encodeURIComponent(v)}&select=id,full_name,department,is_active&limit=1`,
    );
    return Array.isArray(rows) && rows[0] ? rows[0] : null;
  })();
}

/**
 * Ažurira pdf_storage_path i pdf_generated_at na rev_documents redu.
 * @param {string} docId
 * @param {string} storagePath
 */
export async function updateDocPdfMeta(docId, storagePath) {
  const rows = await sbReqThrow(
    `rev_documents?id=eq.${encodeURIComponent(docId)}`,
    'PATCH',
    {
      pdf_storage_path: storagePath,
      pdf_generated_at: new Date().toISOString(),
    },
    { upsert: false },
  );
  if (!Array.isArray(rows) || !rows[0]) {
    throw new Error('PDF meta update nije vratio red');
  }
}
