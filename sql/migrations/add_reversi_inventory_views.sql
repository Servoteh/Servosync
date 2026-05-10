-- ============================================================================
-- REVERSI — Pregledi inventara: po mašini, po zaposlenom, magacin (UNION)
-- ============================================================================
-- Tri view-a za RZ-5:
--
--   1. v_rev_cts_by_machine     — agregat reznog alata po mašini
--   2. v_rev_cts_by_employee    — agregat reznog alata po zaposlenom potpisniku
--   3. v_rev_warehouse_unified  — UNION rev_tools (RUCNI) + rev_cutting_tool_catalog (REZNI)
--                                  sa stanjem u magacinu (WAREHOUSE lokacijama)
--
-- Svi view-ovi su security_invoker = true (RLS poštovan).
-- Idempotentno — bezbedno za re-run.
--
-- NAPOMENA: koristi DROP VIEW IF EXISTS pre CREATE jer CREATE OR REPLACE VIEW
-- ne podnosi promenu kolona (Postgres greška 42P16). Tako se može menjati
-- definicija u sledećim iteracijama bez ručnih DROP poziva.
-- ============================================================================

DROP VIEW IF EXISTS public.v_rev_cts_by_machine;
DROP VIEW IF EXISTS public.v_rev_cts_by_employee;
DROP VIEW IF EXISTS public.v_rev_warehouse_unified;

-- ------------------------------------------------------------
-- 1. v_rev_cts_by_machine — rezni alat po mašini
-- ------------------------------------------------------------

CREATE VIEW public.v_rev_cts_by_machine
WITH (security_invoker = true)
AS
SELECT
  d.recipient_machine_code                          AS machine_code,
  m.name                                            AS machine_name,
  m.no_procedure                                    AS machine_no_procedure,
  c.id                                              AS catalog_id,
  c.barcode,
  c.oznaka,
  c.naziv,
  c.klasa,
  c.unit,
  SUM(l.quantity - l.returned_quantity)             AS remaining_qty,
  COUNT(DISTINCT d.id)                              AS doc_count,
  MAX(d.issued_at)                                  AS last_issued_at,
  (array_agg(d.issued_to_employee_name ORDER BY d.issued_at DESC))[1] AS last_issued_to_name
FROM rev_document_lines l
JOIN rev_documents d              ON d.id = l.document_id
JOIN rev_cutting_tool_catalog c   ON c.id = l.cutting_tool_catalog_id
LEFT JOIN bigtehn_machines_cache m ON m.rj_code = d.recipient_machine_code
WHERE l.line_type    = 'CUTTING_TOOL'
  AND l.line_status  = 'ISSUED'
  AND d.status       IN ('OPEN', 'PARTIALLY_RETURNED')
  AND d.recipient_machine_code IS NOT NULL
GROUP BY
  d.recipient_machine_code, m.name, m.no_procedure,
  c.id, c.barcode, c.oznaka, c.naziv, c.klasa, c.unit;

REVOKE ALL  ON public.v_rev_cts_by_machine FROM anon;
GRANT SELECT ON public.v_rev_cts_by_machine TO authenticated;

COMMENT ON VIEW public.v_rev_cts_by_machine IS
  'Agregat reznog alata po mašini (samo aktivni reversi, line_status=ISSUED). Jedan red = (mašina, šifra) sa preostalom količinom.';

-- ------------------------------------------------------------
-- 2. v_rev_cts_by_employee — rezni alat po zaposlenom (potpisniku)
-- ------------------------------------------------------------

CREATE VIEW public.v_rev_cts_by_employee
WITH (security_invoker = true)
AS
SELECT
  d.issued_to_employee_id                           AS employee_id,
  COALESCE(e.full_name, d.issued_to_employee_name)  AS employee_name,
  e.department,
  c.id                                              AS catalog_id,
  c.barcode,
  c.oznaka,
  c.naziv,
  c.klasa,
  c.unit,
  SUM(l.quantity - l.returned_quantity)             AS remaining_qty,
  array_agg(DISTINCT d.recipient_machine_code)
    FILTER (WHERE d.recipient_machine_code IS NOT NULL) AS machine_codes,
  COUNT(DISTINCT d.id)                              AS doc_count,
  MAX(d.issued_at)                                  AS last_issued_at
FROM rev_document_lines l
JOIN rev_documents d              ON d.id = l.document_id
JOIN rev_cutting_tool_catalog c   ON c.id = l.cutting_tool_catalog_id
LEFT JOIN employees e             ON e.id = d.issued_to_employee_id
WHERE l.line_type    = 'CUTTING_TOOL'
  AND l.line_status  = 'ISSUED'
  AND d.status       IN ('OPEN', 'PARTIALLY_RETURNED')
  AND d.issued_to_employee_id IS NOT NULL
GROUP BY
  d.issued_to_employee_id, e.full_name, d.issued_to_employee_name, e.department,
  c.id, c.barcode, c.oznaka, c.naziv, c.klasa, c.unit;

REVOKE ALL  ON public.v_rev_cts_by_employee FROM anon;
GRANT SELECT ON public.v_rev_cts_by_employee TO authenticated;

COMMENT ON VIEW public.v_rev_cts_by_employee IS
  'Agregat reznog alata po zaposlenom koji je potpisao preuzimanje. Jedan red = (zaposleni, šifra) sa preostalom količinom i listom mašina.';

-- ------------------------------------------------------------
-- 3. v_rev_warehouse_unified — UNION rev_tools + rev_cutting_tool_catalog
--    Stanje u magacinu (WAREHOUSE lokacijama) za oba tipa alata.
-- ------------------------------------------------------------

CREATE VIEW public.v_rev_warehouse_unified
WITH (security_invoker = true)
AS
-- HAND tools (rev_tools): jedinična jedinica = 1 komad
SELECT
  'HAND'::text                  AS grupa,
  t.id::text                    AS item_id,
  t.loc_item_ref_id             AS barcode,
  t.oznaka,
  t.naziv,
  NULL::text                    AS klasa,
  'kom'::text                   AS unit,
  CASE
    WHEN t.status <> 'active' THEN 0
    WHEN EXISTS (
      SELECT 1 FROM rev_document_lines dl
      JOIN rev_documents d2 ON d2.id = dl.document_id
      WHERE dl.tool_id = t.id
        AND dl.line_status = 'ISSUED'
        AND d2.status IN ('OPEN', 'PARTIALLY_RETURNED')
    ) THEN 0
    WHEN p.location_id IS NULL THEN 1
    WHEN lo.location_type = 'WAREHOUSE' THEN 1
    ELSE 0
  END::numeric(12,3)            AS in_warehouse_qty,
  COALESCE(lo.location_code, '')  AS location_code,
  t.status,
  t.serijski_broj,
  t.napomena
FROM rev_tools t
LEFT JOIN LATERAL (
  SELECT location_id FROM loc_item_placements
  WHERE item_ref_table = 'rev_tools' AND item_ref_id = t.loc_item_ref_id
  ORDER BY placed_at DESC LIMIT 1
) p ON TRUE
LEFT JOIN loc_locations lo ON lo.id = p.location_id

UNION ALL

-- CUTTING tools (rev_cutting_tool_catalog): qty po WAREHOUSE lokaciji (sumirano)
SELECT
  'CUTTING'::text                                     AS grupa,
  c.id::text                                          AS item_id,
  c.barcode,
  c.oznaka,
  c.naziv,
  c.klasa,
  c.unit,
  COALESCE(SUM(s.on_hand_qty)
    FILTER (WHERE l.location_type = 'WAREHOUSE'), 0)::numeric(12,3) AS in_warehouse_qty,
  COALESCE(string_agg(DISTINCT l.location_code, ', ')
    FILTER (WHERE l.location_type = 'WAREHOUSE' AND s.on_hand_qty > 0), '') AS location_code,
  c.status,
  NULL::text                                          AS serijski_broj,
  c.napomena
FROM rev_cutting_tool_catalog c
LEFT JOIN rev_cutting_tool_stock s ON s.catalog_id  = c.id
LEFT JOIN loc_locations l          ON l.id          = s.location_id
GROUP BY c.id, c.barcode, c.oznaka, c.naziv, c.klasa, c.unit, c.status, c.napomena;

REVOKE ALL  ON public.v_rev_warehouse_unified FROM anon;
GRANT SELECT ON public.v_rev_warehouse_unified TO authenticated;

COMMENT ON VIEW public.v_rev_warehouse_unified IS
  'Objedinjeni magacinski pregled: rev_tools (grupa=HAND, 1 komad = 1 red) + rev_cutting_tool_catalog (grupa=CUTTING, qty sumirano po WAREHOUSE lokacijama). Filter na FE: grupa, status, search, klasa.';
