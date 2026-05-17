-- ============================================================================
-- PLAN PROIZVODNJE — PP-A/B: TP redni broj (`operacija`) + tech routing za spremnost
-- ============================================================================
-- DRAFT: ne pokretati automatski. Posle pregleda — SQL Editor u Supabase.
--
-- 1. Primenjuje strogu spremnost na `public.v_production_operations_pre_g4`:
--       is_ready_for_machine = NOT EXISTS (cache red sa operacija < tekuća i is_completed = FALSE).
--       Isto vrednosno polje kopirano kao is_ready_for_processing (kompatibilitet kolone).
-- 2. auto_sort_bucket koristi `_ready_chain.is_ready_rb` umesto prev_block za „spremno”.
-- 3. DROP/CREATE javnih view-ova + plan_pp funkcija posle CASCADE.
--
-- Oslonac za spoljašnji omotač: supabase/migrations/20260507100000__plan_final_qc_hide_fix_double_sum.sql
-- Bezbednost: revoke_anon_v_production_operations.sql (samo authenticated).
-- Napomena: PG ne dozvoljava CREATE OR REPLACE kada se menja redosled/imena kolona
-- (npr. is_ready_for_processing ↔ is_ready_for_machine) — prvo DROP zavisnih view-ova.
-- ============================================================================

DROP VIEW IF EXISTS public.v_production_operations_effective CASCADE;

DROP VIEW IF EXISTS public.v_production_operations CASCADE;

DROP VIEW IF EXISTS public.v_production_operations_pre_g4 CASCADE;

CREATE VIEW public.v_production_operations_pre_g4
WITH (security_invoker = true) AS
SELECT
  l.id                                                  AS line_id,
  l.work_order_id                                       AS work_order_id,
  l.operacija                                           AS operacija,
  l.opis_rada                                           AS opis_rada,
  l.alat_pribor                                         AS alat_pribor,
  l.machine_code                                        AS original_machine_code,
  COALESCE(o.assigned_machine_code, l.machine_code)     AS effective_machine_code,
  l.tpz                                                 AS tpz_min,
  l.tk                                                  AS tk_min,
  l.prioritet                                           AS prioritet_bigtehn,

  wo.ident_broj                                         AS rn_ident_broj,
  wo.broj_crteza                                        AS broj_crteza,
  wo.naziv_dela                                         AS naziv_dela,
  wo.materijal                                          AS materijal,
  wo.dimenzija_materijala                               AS dimenzija_materijala,
  wo.komada                                             AS komada_total,
  wo.rok_izrade                                         AS rok_izrade,
  wo.status_rn                                          AS rn_zavrsen,
  wo.zakljucano                                         AS rn_zakljucano,
  wo.napomena                                           AS rn_napomena,

  c.id                                                  AS customer_id,
  c.name                                                AS customer_name,
  c.short_name                                          AS customer_short,

  m.name                                                AS original_machine_name,
  COALESCE(m.no_procedure, FALSE)                       AS is_non_machining,

  o.id                                                  AS overlay_id,
  o.shift_sort_order                                    AS shift_sort_order,
  o.local_status                                        AS local_status,
  o.shift_note                                          AS shift_note,
  o.assigned_machine_code                               AS assigned_machine_code,
  o.archived_at                                         AS overlay_archived_at,
  o.archived_reason                                     AS overlay_archived_reason,
  o.updated_at                                          AS overlay_updated_at,
  o.updated_by                                          AS overlay_updated_by,
  o.created_at                                          AS overlay_created_at,
  o.created_by                                          AS overlay_created_by,

  COALESCE(tr.komada_done, 0)                           AS komada_done,
  COALESCE(tr.real_seconds, 0)                          AS real_seconds,
  COALESCE(tr.is_done, FALSE)                           AS is_done_in_bigtehn,
  tr.last_finished_at                                   AS last_finished_at,
  tr.prijava_count                                      AS prijava_count,

  COALESCE(d.drawings_count, 0)                         AS drawings_count,

  (bd.drawing_no IS NOT NULL)                           AS has_bigtehn_drawing,
  bd.storage_path                                       AS bigtehn_drawing_path,
  bd.size_bytes                                         AS bigtehn_drawing_size,

  wo.is_mes_active                                      AS is_mes_active,

  COALESCE(o.cam_ready, FALSE)                          AS cam_ready,
  o.cam_ready_at                                        AS cam_ready_at,
  o.cam_ready_by                                        AS cam_ready_by,

  m.rj_code                                             AS rj_group_code,
  m.name                                                AS rj_group_label,
  COALESCE(o.cooperation_status, 'none')                AS cooperation_status,
  o.cooperation_partner                                 AS cooperation_partner,
  o.cooperation_set_by                                  AS cooperation_set_by,
  o.cooperation_set_at                                  AS cooperation_set_at,
  o.cooperation_expected_return                         AS cooperation_expected_return,
  (g.rj_group_code IS NOT NULL)                         AS is_cooperation_auto,
  (COALESCE(o.cooperation_status, 'none') <> 'none')    AS is_cooperation_manual,
  (
    g.rj_group_code IS NOT NULL
    OR COALESCE(o.cooperation_status, 'none') <> 'none'
  )                                                     AS is_cooperation_effective,
  CASE
    WHEN g.rj_group_code IS NOT NULL
     AND COALESCE(o.cooperation_status, 'none') <> 'none' THEN 'auto+manual'
    WHEN g.rj_group_code IS NOT NULL THEN 'auto'
    WHEN COALESCE(o.cooperation_status, 'none') <> 'none' THEN 'manual'
    ELSE 'none'
  END                                                   AS cooperation_source,

  COALESCE(_ready_chain.is_ready_rb, FALSE)              AS is_ready_for_machine,
  COALESCE(_ready_chain.is_ready_rb, FALSE)              AS is_ready_for_processing,
  CASE
    WHEN prev_any.operacija IS NULL THEN 'none'
    WHEN prev_block.operacija IS NULL THEN 'completed'
    WHEN COALESCE(prev_block.komada_done, 0) > 0 THEN 'in_progress'
    ELSE 'not_started'
  END                                                   AS previous_operation_status,
  COALESCE(prev_block.operacija, prev_any.operacija)    AS previous_operation_operacija,
  COALESCE(prev_block.machine_code, prev_any.machine_code)
                                                          AS previous_operation_machine_code,
  (u.work_order_id IS NOT NULL)                         AS is_urgent,
  u.reason                                              AS urgency_reason,
  CASE
    WHEN COALESCE(o.local_status, 'waiting') = 'blocked' THEN 7
    WHEN u.work_order_id IS NOT NULL
     AND _ready_chain.is_ready_rb
     AND COALESCE(o.local_status, 'waiting') = 'in_progress' THEN 1
    WHEN u.work_order_id IS NOT NULL
     AND _ready_chain.is_ready_rb
     AND COALESCE(o.local_status, 'waiting') = 'waiting' THEN 2
    WHEN u.work_order_id IS NOT NULL
     AND NOT _ready_chain.is_ready_rb THEN 3
    WHEN u.work_order_id IS NULL
     AND COALESCE(o.local_status, 'waiting') = 'in_progress' THEN 4
    WHEN u.work_order_id IS NULL
     AND _ready_chain.is_ready_rb
     AND COALESCE(o.local_status, 'waiting') = 'waiting' THEN 5
    WHEN u.work_order_id IS NULL
     AND NOT _ready_chain.is_ready_rb
     AND COALESCE(o.local_status, 'waiting') = 'waiting' THEN 6
    ELSE 8
  END                                                   AS auto_sort_bucket

FROM public.bigtehn_work_order_lines_cache l
INNER JOIN public.v_active_bigtehn_work_orders wo
  ON wo.id = l.work_order_id
 AND wo.is_mes_active IS TRUE
LEFT JOIN public.bigtehn_customers_cache    c
  ON c.id = wo.customer_id
LEFT JOIN public.bigtehn_machines_cache     m
  ON m.rj_code = l.machine_code
LEFT JOIN public.production_auto_cooperation_groups g
  ON g.rj_group_code = m.rj_code
 AND g.removed_at IS NULL
LEFT JOIN public.production_overlays        o
  ON o.work_order_id = l.work_order_id
 AND o.line_id       = l.id
LEFT JOIN public.production_urgency_overrides u
  ON u.work_order_id = l.work_order_id
 AND u.is_urgent IS TRUE
 AND u.cleared_at IS NULL
LEFT JOIN LATERAL (
  SELECT (
    NOT EXISTS (
      SELECT 1
      FROM public.bigtehn_tech_routing_cache tr_rb
      WHERE tr_rb.work_order_id = l.work_order_id
        AND tr_rb.operacija < l.operacija
        AND tr_rb.is_completed IS FALSE
    )
  ) AS is_ready_rb
) _ready_chain ON TRUE
LEFT JOIN LATERAL (
  SELECT
    SUM(t.komada)                AS komada_done,
    SUM(t.prn_timer_seconds)     AS real_seconds,
    BOOL_OR(t.is_completed)      AS is_done,
    MAX(t.finished_at)           AS last_finished_at,
    COUNT(*)                     AS prijava_count
  FROM public.bigtehn_tech_routing_cache t
  WHERE t.work_order_id = l.work_order_id
    AND t.operacija     = l.operacija
) tr ON TRUE
LEFT JOIN LATERAL (
  SELECT COUNT(*) AS drawings_count
  FROM public.production_drawings pd
  WHERE pd.work_order_id = l.work_order_id
    AND pd.line_id       = l.id
    AND pd.deleted_at IS NULL
) d ON TRUE
LEFT JOIN LATERAL (
  SELECT
    l2.operacija,
    l2.machine_code,
    l2.prioritet,
    COALESCE(t2.komada_done, 0) AS komada_done
  FROM public.bigtehn_work_order_lines_cache l2
  LEFT JOIN LATERAL (
    SELECT SUM(t.komada) AS komada_done
    FROM public.bigtehn_tech_routing_cache t
    WHERE t.work_order_id = l2.work_order_id
      AND t.operacija     = l2.operacija
  ) t2 ON TRUE
  WHERE l2.work_order_id = l.work_order_id
    AND l2.prioritet < l.prioritet
  ORDER BY l2.prioritet DESC, l2.operacija DESC
  LIMIT 1
) prev_any ON TRUE
LEFT JOIN LATERAL (
  SELECT
    l2.operacija,
    l2.machine_code,
    l2.prioritet,
    COALESCE(t2.komada_done, 0) AS komada_done
  FROM public.bigtehn_work_order_lines_cache l2
  LEFT JOIN LATERAL (
    SELECT SUM(t.komada) AS komada_done
    FROM public.bigtehn_tech_routing_cache t
    WHERE t.work_order_id = l2.work_order_id
      AND t.operacija     = l2.operacija
  ) t2 ON TRUE
  WHERE l2.work_order_id = l.work_order_id
    AND l2.prioritet < l.prioritet
    AND COALESCE(t2.komada_done, 0) < COALESCE(wo.komada, 0)
  ORDER BY l2.prioritet DESC, l2.operacija DESC
  LIMIT 1
) prev_block ON TRUE
LEFT JOIN public.bigtehn_drawings_cache    bd
  ON bd.drawing_no = wo.broj_crteza
 AND bd.removed_at IS NULL;

COMMENT ON VIEW public.v_production_operations_pre_g4 IS
  'Plan: aktivni RN-ovi + G2 sort i prethodne operacije; PP-A dodaje is_ready_for_machine (stroga provera TP rednog broja naspram tech routing cache-a).';

GRANT SELECT ON public.v_production_operations_pre_g4 TO authenticated;
REVOKE SELECT ON public.v_production_operations_pre_g4 FROM anon;

CREATE VIEW public.v_production_operations
WITH (security_invoker = true) AS
SELECT
  s_inner.*,
  COALESCE(g4.is_rework, false) AS is_rework,
  COALESCE(g4.is_scrap, false) AS is_scrap,
  COALESCE(g4.rework_pieces, 0::numeric) AS rework_pieces,
  COALESCE(g4.scrap_pieces, 0::numeric) AS scrap_pieces,
  COALESCE(g4.rework_scrap_count, 0::bigint) AS rework_scrap_count,
  (
    s_inner.komada_total IS NOT NULL
    AND s_inner.komada_total > 0
    AND COALESCE(fc.final_control_raw_sum, 0::numeric) >= s_inner.komada_total::numeric
    AND COALESCE(fc.final_control_raw_sum, 0::numeric)
      <= s_inner.komada_total::numeric * 1.5
  ) AS plan_rn_final_control_done
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
  SELECT COALESCE((
    SELECT sum(t.komada)::numeric
    FROM public.bigtehn_work_order_lines_cache l
    INNER JOIN public.bigtehn_machines_cache m ON m.rj_code = l.machine_code
    INNER JOIN public.bigtehn_tech_routing_cache t
      ON t.work_order_id = l.work_order_id
     AND t.operacija = l.operacija
     AND t.machine_code IS NOT DISTINCT FROM l.machine_code
     AND t.is_completed IS TRUE
    WHERE l.work_order_id = s_inner.work_order_id
      AND production._pracenje_line_is_final_control(
        l.machine_code,
        m.name,
        COALESCE(m.no_procedure, false)
      )
  ), 0::numeric) AS final_control_raw_sum
) fc ON true;

COMMENT ON VIEW public.v_production_operations IS
  'Plan: pre_g4 + G4 + item_id; plan_rn_final_control_done = KK pokriva lot, suma umerena (nema duplih).';

COMMENT ON COLUMN public.v_production_operations.plan_rn_final_control_done IS
  'TRUE ako suma KK prijava >= komada_total i <= komada_total×1.5.';

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



-- ========================================================================
-- Ponovo funkcija koja zavisi od v_production_operations_effective (posle CASCADE)
-- ========================================================================

-- Po mašini: umesto do 2500 operacija odjednom, paginacija po radnom nalogu u istom
-- redosledu kao u aplikaciji (shift_sort_order, auto_sort_bucket, rok_izrade, prioritet_bigtehn).
-- RPC vraća jsonb: { rows, has_more, next_work_order_offset }.

DROP FUNCTION IF EXISTS public.plan_pp_open_ops_for_machine(text, integer, integer);
DROP FUNCTION IF EXISTS public.plan_pp_open_ops_for_machine(text);

CREATE OR REPLACE FUNCTION public.plan_pp_open_ops_for_machine(
  p_machine_code     text,
  p_work_order_limit integer DEFAULT 100,
  p_work_order_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO 'public'
SET statement_timeout TO '180s'
AS $$
DECLARE
  mc  text;
  lim int;
  off int;
BEGIN
  mc := btrim(p_machine_code);
  IF mc = '' THEN
    RETURN jsonb_build_object(
      'rows', '[]'::jsonb,
      'has_more', false,
      'next_work_order_offset', 0
    );
  END IF;

  lim := COALESCE(p_work_order_limit, 100);
  IF lim < 1 THEN
    lim := 100;
  END IF;
  IF lim > 250 THEN
    lim := 250;
  END IF;

  off := GREATEST(COALESCE(p_work_order_offset, 0), 0);

  RETURN (
    WITH filtered AS (
      SELECT e.*
      FROM public.v_production_operations_effective e
      WHERE e.effective_machine_code = mc
        AND e.is_done_in_bigtehn IS FALSE
        AND e.rn_zavrsen IS FALSE
        AND e.is_cooperation_effective IS FALSE
        AND (e.local_status IS NULL OR e.local_status <> 'completed')
        AND e.overlay_archived_at IS NULL
    ),
    ordered AS (
      SELECT
        f.*,
        ROW_NUMBER() OVER (
          ORDER BY
            f.shift_sort_order ASC NULLS LAST,
            f.auto_sort_bucket ASC NULLS LAST,
            f.rok_izrade ASC NULLS LAST,
            f.prioritet_bigtehn ASC NULLS LAST
        ) AS _sort_idx
      FROM filtered f
    ),
    wo_first AS (
      SELECT work_order_id, MIN(_sort_idx) AS first_sort
      FROM ordered
      GROUP BY work_order_id
    ),
    wo_numbered AS (
      SELECT
        work_order_id,
        ROW_NUMBER() OVER (ORDER BY first_sort) AS wo_seq
      FROM wo_first
    ),
    picked_wo AS (
      SELECT work_order_id
      FROM wo_numbered
      WHERE wo_seq > off
        AND wo_seq <= off + lim
    ),
    picked_count AS (
      SELECT COUNT(*)::int AS c FROM picked_wo
    ),
    has_more_val AS (
      SELECT EXISTS (
        SELECT 1
        FROM wo_numbered w
        WHERE w.wo_seq > off + lim
      ) AS v
    ),
    row_json AS (
      SELECT COALESCE(
        jsonb_agg(
          (to_jsonb(o) - '_sort_idx')
          ORDER BY o._sort_idx
        ),
        '[]'::jsonb
      ) AS ja
      FROM ordered o
      WHERE o.work_order_id IN (SELECT work_order_id FROM picked_wo)
    )
    SELECT jsonb_build_object(
      'rows', (SELECT ja FROM row_json),
      'has_more', (SELECT v FROM has_more_val),
      'next_work_order_offset', off + (SELECT c FROM picked_count)
    )
  );
END;
$$;

COMMENT ON FUNCTION public.plan_pp_open_ops_for_machine(text, integer, integer) IS
  'Plan po mašini: otvorene operacije, jsonb {rows, has_more, next_work_order_offset}. Paginacija po RN u sort redosledu liste.';

GRANT EXECUTE ON FUNCTION public.plan_pp_open_ops_for_machine(text, integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.plan_pp_open_ops_for_machine(text, integer, integer) FROM PUBLIC;
