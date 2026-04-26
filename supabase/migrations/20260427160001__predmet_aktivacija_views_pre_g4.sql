-- Varijanta za baze gde v_production_operations gradi preko v_production_operations_pre_g4 + G4 (rework/scrap).
-- Na čistom G7-only šemu ova migracija nije validna (nema pre_g4).
-- Povezano: DEPLOYED_NOTES__predmet_aktivacija.md

DROP VIEW IF EXISTS public.v_production_operations_effective CASCADE;

DROP VIEW IF EXISTS public.v_production_operations CASCADE;

CREATE VIEW public.v_production_operations
WITH (security_invoker = true) AS
SELECT
  s_inner.*,
  COALESCE(g4.is_rework, false) AS is_rework,
  COALESCE(g4.is_scrap, false) AS is_scrap,
  COALESCE(g4.rework_pieces, 0::numeric) AS rework_pieces,
  COALESCE(g4.scrap_pieces, 0::numeric) AS scrap_pieces,
  COALESCE(g4.rework_scrap_count, 0::bigint) AS rework_scrap_count
FROM (
  SELECT v.*, wo.item_id::integer AS item_id
  FROM v_production_operations_pre_g4 v
  INNER JOIN v_active_bigtehn_work_orders wo ON wo.id = v.work_order_id
) s_inner
LEFT JOIN LATERAL (
  SELECT
    bool_or(c.quality_type_id = 1) AS is_rework,
    bool_or(c.quality_type_id = 2) AS is_scrap,
    COALESCE(sum(c.pieces) FILTER (WHERE c.quality_type_id = 1), 0::numeric) AS rework_pieces,
    COALESCE(sum(c.pieces) FILTER (WHERE c.quality_type_id = 2), 0::numeric) AS scrap_pieces,
    count(*)::bigint AS rework_scrap_count
  FROM bigtehn_rework_scrap_cache c
  WHERE c.work_order_id = s_inner.work_order_id AND c.operacija = s_inner.operacija
) g4 ON true;

COMMENT ON VIEW public.v_production_operations IS 'Plan: pre_g4 + G4 + item_id (predmet aktivacija)';

GRANT SELECT ON public.v_production_operations TO authenticated;
REVOKE SELECT ON public.v_production_operations FROM anon;

CREATE VIEW public.v_production_operations_effective
WITH (security_invoker = true) AS
SELECT ops.*
FROM public.v_production_operations ops
WHERE EXISTS (
  SELECT 1
  FROM production.predmet_aktivacija pa
  WHERE pa.predmet_item_id = ops.item_id
    AND pa.je_aktivan IS TRUE
);

GRANT SELECT ON public.v_production_operations_effective TO authenticated;
REVOKE SELECT ON public.v_production_operations_effective FROM anon;

NOTIFY pgrst, 'reload schema';
