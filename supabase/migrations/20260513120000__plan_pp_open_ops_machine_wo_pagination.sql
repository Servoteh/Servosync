-- Po mašini: umesto do 2500 operacija odjednom, paginacija po radnom nalogu u istom
-- redosledu kao u aplikaciji (shift_sort_order, auto_sort_bucket, rok_izrade, prioritet_bigtehn).
-- RPC vraća jsonb: { rows, has_more, next_work_order_offset }.

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

NOTIFY pgrst, 'reload schema';
