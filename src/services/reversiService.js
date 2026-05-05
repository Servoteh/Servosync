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
 * @param {{ status?: string, search?: string, limit?: number, offset?: number }} params
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
      parts.push(`or=(oznaka.ilike.${enc},naziv.ilike.${enc})`);
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
