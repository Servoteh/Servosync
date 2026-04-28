-- Planiranje proizvodnje: RN čiji je tehnološki postupak završen kucanjem završne
-- kontrole (RJ 8.3* / ista heuristika kao praćenje izveštaja) više nije u
-- v_production_operations_effective — prati se po lokaciji, ne u planu.

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
  COALESCE(g4.rework_scrap_count, 0::bigint) AS rework_scrap_count,
  COALESCE(fc.plan_rn_final_control_done, false) AS plan_rn_final_control_done
FROM (
  SELECT v.*, wo.item_id::integer AS item_id
  FROM public.v_production_operations_pre_g4 v
  INNER JOIN public.v_active_bigtehn_work_orders wo ON wo.id = v.work_order_id
) s_inner
LEFT JOIN LATERAL (
  SELECT
    bool_or(c.quality_type_id = 1) AS is_rework,
    bool_or(c.quality_type_id = 2) AS is_scrap,
    COALESCE(sum(c.pieces) FILTER (WHERE c.quality_type_id = 1), 0::numeric) AS rework_pieces,
    COALESCE(sum(c.pieces) FILTER (WHERE c.quality_type_id = 2), 0::numeric) AS scrap_pieces,
    count(*)::bigint AS rework_scrap_count
  FROM public.bigtehn_rework_scrap_cache c
  WHERE c.work_order_id = s_inner.work_order_id AND c.operacija = s_inner.operacija
) g4 ON true
LEFT JOIN LATERAL (
  SELECT EXISTS (
    SELECT 1
    FROM public.bigtehn_work_order_lines_cache fl
    LEFT JOIN public.bigtehn_machines_cache m_fc ON m_fc.rj_code = fl.machine_code
    WHERE fl.work_order_id = s_inner.work_order_id
      AND production._pracenje_line_is_final_control(
        fl.machine_code,
        m_fc.name,
        COALESCE(m_fc.no_procedure, false)
      )
      AND EXISTS (
        SELECT 1
        FROM public.bigtehn_tech_routing_cache t
        WHERE t.work_order_id = fl.work_order_id
          AND t.operacija = fl.operacija
          AND t.machine_code IS NOT DISTINCT FROM fl.machine_code
          AND t.is_completed IS TRUE
      )
  ) AS plan_rn_final_control_done
) fc ON true;

COMMENT ON VIEW public.v_production_operations IS
  'Plan: pre_g4 + G4 + item_id; plan_rn_final_control_done = završna kontrola prijavljena u BigTehn-u.';

COMMENT ON COLUMN public.v_production_operations.plan_rn_final_control_done IS
  'TRUE ako postoji stavka završne kontrole (8.3 / heuristika) sa bar jednom is_completed prijavom za taj RN.';

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
)
AND COALESCE(ops.plan_rn_final_control_done, false) IS NOT TRUE;

COMMENT ON VIEW public.v_production_operations_effective IS
  'v_production_operations + predmet aktivacija + isključeni RN posle završne kontrole (plan).';

GRANT SELECT ON public.v_production_operations_effective TO authenticated;
REVOKE SELECT ON public.v_production_operations_effective FROM anon;

NOTIFY pgrst, 'reload schema';
