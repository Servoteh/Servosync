-- Pregled svih lokacija za Reversi magacin HAND+CUTTING:
-- in_warehouse_qty = samo WAREHOUSE, qty_total = sum na svim lokacijama, location_label primaoca ako postoji revers mapiranje.

CREATE OR REPLACE VIEW public.v_rev_inventory_all_locations
WITH (security_invoker = true)
AS
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
  (CASE WHEN t.status = 'active' THEN 1 ELSE 0 END)::numeric(12,3) AS qty_total,
  COALESCE(rrl.recipient_label, lo.name, lo.location_code, '') AS location_label,
  COALESCE(lo.location_code, '') AS location_code,
  t.status,
  t.serijski_broj,
  t.napomena,
  NULL::integer                 AS min_stock_qty
FROM rev_tools t
LEFT JOIN LATERAL (
  SELECT location_id FROM loc_item_placements
  WHERE item_ref_table = 'rev_tools' AND item_ref_id = t.loc_item_ref_id
  ORDER BY placed_at DESC LIMIT 1
) p ON TRUE
LEFT JOIN loc_locations lo ON lo.id = p.location_id
LEFT JOIN rev_recipient_locations rrl ON rrl.loc_location_id = lo.id

UNION ALL

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
  COALESCE(SUM(s.on_hand_qty), 0)::numeric(12,3)      AS qty_total,
  COALESCE(string_agg(DISTINCT
    CASE WHEN s.on_hand_qty > 0 AND l.id IS NOT NULL
      THEN COALESCE(rrl.recipient_label, l.name, l.location_code) || ':' || trim(both FROM s.on_hand_qty::TEXT)
    END,
    ' · '
  ), '')                                              AS location_label,
  COALESCE(string_agg(DISTINCT l.location_code
    FILTER (WHERE s.on_hand_qty > 0 AND l.id IS NOT NULL), ', '), '') AS location_code,
  c.status,
  NULL::text                                          AS serijski_broj,
  c.napomena,
  COALESCE(c.min_stock_qty, 0)                        AS min_stock_qty
FROM rev_cutting_tool_catalog c
LEFT JOIN rev_cutting_tool_stock s ON s.catalog_id = c.id
LEFT JOIN loc_locations l          ON l.id = s.location_id
LEFT JOIN rev_recipient_locations rrl ON rrl.loc_location_id = l.id
GROUP BY c.id, c.barcode, c.oznaka, c.naziv, c.klasa, c.unit, c.status, c.napomena, c.min_stock_qty;

COMMENT ON VIEW public.v_rev_inventory_all_locations IS
  'Ručni + rezni: in_warehouse_qty (samo WH), qty_total (sum svih lokacija), location_label (primalac ili kod lokacije).';

REVOKE ALL ON public.v_rev_inventory_all_locations FROM PUBLIC;
GRANT SELECT ON public.v_rev_inventory_all_locations TO authenticated;
