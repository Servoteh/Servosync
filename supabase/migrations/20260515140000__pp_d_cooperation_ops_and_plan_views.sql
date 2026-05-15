-- PP-D + PP-F prep: kooperacija po operaciji + operativni plan view + RPC + optional auto-status trigger (draft).
-- NE POKRETATI automatski bez review-a (trigger na cache tabeli).

-- ---------------------------------------------------------------------------
-- 1) Tabela production_cooperation_ops
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.production_cooperation_ops (
  id              bigserial PRIMARY KEY,
  work_order_id   bigint NOT NULL,
  line_id         bigint NOT NULL,
  operacija       integer NOT NULL,
  marked_at       timestamptz NOT NULL DEFAULT now(),
  marked_by       text,
  cleared_at      timestamptz,
  cleared_by      text,
  note            text,
  CONSTRAINT production_cooperation_ops_unique_line_op
    UNIQUE (work_order_id, line_id, operacija)
);

CREATE INDEX IF NOT EXISTS production_cooperation_ops_wo_line_idx
  ON public.production_cooperation_ops (work_order_id, line_id);

COMMENT ON TABLE public.production_cooperation_ops IS
  'PP-D: koje TP operacije (stavke RN) šalju spolja; cleared_at NULL = aktivno.';

ALTER TABLE public.production_cooperation_ops ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pco_read_authenticated ON public.production_cooperation_ops;
CREATE POLICY pco_read_authenticated
  ON public.production_cooperation_ops FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS pco_insert_plan_edit ON public.production_cooperation_ops;
CREATE POLICY pco_insert_plan_edit
  ON public.production_cooperation_ops FOR INSERT
  TO authenticated
  WITH CHECK (public.can_edit_plan_proizvodnje());

DROP POLICY IF EXISTS pco_update_plan_edit ON public.production_cooperation_ops;
CREATE POLICY pco_update_plan_edit
  ON public.production_cooperation_ops FOR UPDATE
  TO authenticated
  USING (public.can_edit_plan_proizvodnje())
  WITH CHECK (public.can_edit_plan_proizvodnje());

DROP POLICY IF EXISTS pco_delete_plan_edit ON public.production_cooperation_ops;
CREATE POLICY pco_delete_plan_edit
  ON public.production_cooperation_ops FOR DELETE
  TO authenticated
  USING (public.can_edit_plan_proizvodnje());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.production_cooperation_ops TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.production_cooperation_ops_id_seq TO authenticated;

-- ---------------------------------------------------------------------------
-- 2) Helper: da li operacija ne ulazi u operativni plan zbog kooperacije
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._pp_cooperation_excludes_from_plan(
  p_work_order_id bigint,
  p_line_id bigint,
  p_operacija integer,
  p_is_cooperation_effective boolean
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT
    EXISTS (
      SELECT 1
      FROM public.production_cooperation_ops c
      WHERE c.work_order_id = p_work_order_id
        AND c.line_id = p_line_id
        AND c.operacija = p_operacija
        AND c.cleared_at IS NULL
    )
    OR (
      COALESCE(p_is_cooperation_effective, false)
      AND NOT EXISTS (
        SELECT 1
        FROM public.production_cooperation_ops h
        WHERE h.work_order_id = p_work_order_id
          AND h.line_id = p_line_id
      )
    );
$$;

REVOKE ALL ON FUNCTION public._pp_cooperation_excludes_from_plan(bigint, bigint, integer, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._pp_cooperation_excludes_from_plan(bigint, bigint, integer, boolean) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3) Views: operativni plan + lista kooperacije
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS public.v_production_operations_operational_plan CASCADE;
CREATE VIEW public.v_production_operations_operational_plan
WITH (security_invoker = true) AS
SELECT
  v.*,
  tr.started_max AS tech_routing_started_at
FROM public.v_production_operations_effective v
LEFT JOIN LATERAL (
  SELECT max(t.started_at) AS started_max
  FROM public.bigtehn_tech_routing_cache t
  WHERE t.work_order_id = v.work_order_id
    AND t.operacija = v.operacija
) tr ON true
WHERE NOT public._pp_cooperation_excludes_from_plan(
  v.work_order_id,
  v.line_id,
  v.operacija,
  v.is_cooperation_effective
);

COMMENT ON VIEW public.v_production_operations_operational_plan IS
  'Plan: v_production_operations_effective minus kooperacija (PP-D) + tech_routing_started_at (PP-F UI).';

GRANT SELECT ON public.v_production_operations_operational_plan TO authenticated;
REVOKE SELECT ON public.v_production_operations_operational_plan FROM anon;

DROP VIEW IF EXISTS public.v_production_operations_cooperation CASCADE;
CREATE VIEW public.v_production_operations_cooperation
WITH (security_invoker = true) AS
SELECT v.*
FROM public.v_production_operations_effective v
WHERE public._pp_cooperation_excludes_from_plan(
  v.work_order_id,
  v.line_id,
  v.operacija,
  v.is_cooperation_effective
);

COMMENT ON VIEW public.v_production_operations_cooperation IS
  'Operacije koje su izuzete iz operativnog plana zbog kooperacije (tab Kooperacija).';

GRANT SELECT ON public.v_production_operations_cooperation TO authenticated;
REVOKE SELECT ON public.v_production_operations_cooperation FROM anon;

-- ---------------------------------------------------------------------------
-- 4) RPC plan_pp_open_ops_for_machine — čitaj operational_plan
-- ---------------------------------------------------------------------------
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
      FROM public.v_production_operations_operational_plan e
      WHERE e.effective_machine_code = mc
        AND e.is_done_in_bigtehn IS FALSE
        AND e.rn_zavrsen IS FALSE
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
  'Plan po mašini: operativni plan view (bez kooperacije po operaciji), jsonb {rows, has_more, next_work_order_offset}.';

GRANT EXECUTE ON FUNCTION public.plan_pp_open_ops_for_machine(text, integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.plan_pp_open_ops_for_machine(text, integer, integer) FROM PUBLIC;

-- PP-F trigger draft: sql/migrations/add_bigtehn_prijava_to_local_status_trigger.sql

NOTIFY pgrst, 'reload schema';
