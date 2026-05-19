-- REVERSI — barkod za ručni alat (ALAT-NNNNNN)
-- Idempotentno. DOWN: 20260519140000__rev_tools_barcode.down.sql

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'rev_tools'
      AND column_name = 'barcode'
  ) THEN
    ALTER TABLE public.rev_tools ADD COLUMN barcode text;
  END IF;
END$$;

CREATE SEQUENCE IF NOT EXISTS public.rev_tools_barcode_seq START 1 INCREMENT 1;

CREATE OR REPLACE FUNCTION public.rev_tools_set_barcode()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.barcode IS NULL OR btrim(NEW.barcode) = '' THEN
    NEW.barcode := 'ALAT-' || lpad(nextval('public.rev_tools_barcode_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS rev_tools_before_insert_barcode ON public.rev_tools;
CREATE TRIGGER rev_tools_before_insert_barcode
  BEFORE INSERT ON public.rev_tools
  FOR EACH ROW EXECUTE FUNCTION public.rev_tools_set_barcode();

UPDATE public.rev_tools
SET barcode = 'ALAT-' || lpad(nextval('public.rev_tools_barcode_seq')::text, 6, '0')
WHERE barcode IS NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'rev_tools'
      AND column_name = 'barcode'
      AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE public.rev_tools ALTER COLUMN barcode SET NOT NULL;
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_rev_tools_barcode ON public.rev_tools (barcode);

COMMENT ON COLUMN public.rev_tools.barcode IS
  'Auto-generisan Code128 barkod format ALAT-NNNNNN. Trigger popunjava na INSERT ako nije zadat.';

GRANT USAGE ON SEQUENCE public.rev_tools_barcode_seq TO authenticated;

-- v_rev_warehouse_unified: HAND deo koristi t.barcode umesto loc_item_ref_id
DROP VIEW IF EXISTS public.v_rev_warehouse_unified;

CREATE VIEW public.v_rev_warehouse_unified
WITH (security_invoker = true)
AS
SELECT
  'HAND'::text                  AS grupa,
  t.id::text                    AS item_id,
  t.barcode,
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
  t.napomena,
  NULL::integer                 AS min_stock_qty
FROM rev_tools t
LEFT JOIN LATERAL (
  SELECT location_id FROM loc_item_placements
  WHERE item_ref_table = 'rev_tools' AND item_ref_id = t.loc_item_ref_id
  ORDER BY placed_at DESC LIMIT 1
) p ON TRUE
LEFT JOIN loc_locations lo ON lo.id = p.location_id

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
  COALESCE(string_agg(DISTINCT l.location_code, ', ')
    FILTER (WHERE l.location_type = 'WAREHOUSE' AND s.on_hand_qty > 0), '') AS location_code,
  c.status,
  NULL::text                                          AS serijski_broj,
  c.napomena,
  COALESCE(c.min_stock_qty, 0)                        AS min_stock_qty
FROM rev_cutting_tool_catalog c
LEFT JOIN rev_cutting_tool_stock s ON s.catalog_id  = c.id
LEFT JOIN loc_locations l          ON l.id          = s.location_id
GROUP BY c.id, c.barcode, c.oznaka, c.naziv, c.klasa, c.unit, c.status, c.napomena, c.min_stock_qty;

REVOKE ALL  ON public.v_rev_warehouse_unified FROM anon;
GRANT SELECT ON public.v_rev_warehouse_unified TO authenticated;

COMMENT ON VIEW public.v_rev_warehouse_unified IS
  'Objedinjeni magacinski pregled: rev_tools (HAND) + rev_cutting_tool_catalog (CUTTING). HAND barcode = ALAT-NNNNNN.';

NOTIFY pgrst, 'reload schema';
