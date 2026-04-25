-- ============================================================================
-- PLAN PROIZVODNJE - G6 auto in_progress iz BigTehn prijava
-- ============================================================================
-- Poziva se iz bridge/backfill toka posle osvezavanja bigtehn_tech_routing_cache.
-- Nema triggera na cache tabelama: sync je batch/brisi-i-puni i ovo mora ostati
-- kontrolisana batch operacija.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.mark_in_progress_from_tech_routing()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_updated integer := 0;
  v_inserted integer := 0;
BEGIN
  WITH started_ops AS (
    SELECT
      l.work_order_id,
      l.id AS line_id
    FROM public.bigtehn_work_order_lines_cache l
    INNER JOIN public.v_active_bigtehn_work_orders wo
      ON wo.id = l.work_order_id
     AND wo.is_mes_active IS TRUE
    INNER JOIN public.bigtehn_tech_routing_cache t
      ON t.work_order_id = l.work_order_id
     AND t.operacija = l.operacija
    WHERE COALESCE(t.komada, 0) > 0
    GROUP BY l.work_order_id, l.id
    HAVING BOOL_OR(COALESCE(t.is_completed, false)) IS NOT TRUE
  ),
  upd AS (
    UPDATE public.production_overlays o
       SET local_status = 'in_progress',
           updated_by = 'system:bridge:g6'
      FROM started_ops s
     WHERE o.work_order_id = s.work_order_id
       AND o.line_id = s.line_id
       AND o.archived_at IS NULL
       AND o.local_status = 'waiting'
    RETURNING 1
  )
  SELECT count(*) INTO v_updated FROM upd;

  WITH started_ops AS (
    SELECT
      l.work_order_id,
      l.id AS line_id
    FROM public.bigtehn_work_order_lines_cache l
    INNER JOIN public.v_active_bigtehn_work_orders wo
      ON wo.id = l.work_order_id
     AND wo.is_mes_active IS TRUE
    INNER JOIN public.bigtehn_tech_routing_cache t
      ON t.work_order_id = l.work_order_id
     AND t.operacija = l.operacija
    WHERE COALESCE(t.komada, 0) > 0
    GROUP BY l.work_order_id, l.id
    HAVING BOOL_OR(COALESCE(t.is_completed, false)) IS NOT TRUE
  ),
  ins AS (
    INSERT INTO public.production_overlays (
      work_order_id,
      line_id,
      local_status,
      created_by,
      updated_by
    )
    SELECT
      s.work_order_id,
      s.line_id,
      'in_progress',
      'system:bridge:g6',
      'system:bridge:g6'
    FROM started_ops s
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.production_overlays o
      WHERE o.work_order_id = s.work_order_id
        AND o.line_id = s.line_id
    )
    RETURNING 1
  )
  SELECT count(*) INTO v_inserted FROM ins;

  RETURN jsonb_build_object(
    'updated', v_updated,
    'inserted', v_inserted,
    'total', v_updated + v_inserted
  );
END;
$$;

REVOKE ALL ON FUNCTION public.mark_in_progress_from_tech_routing() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_in_progress_from_tech_routing() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.mark_in_progress_from_tech_routing() TO service_role;

COMMENT ON FUNCTION public.mark_in_progress_from_tech_routing() IS
  'G6 batch RPC: iz BigTehn tTehPostupak prijava automatski postavlja production_overlays.local_status=in_progress za waiting ili nepostojece overlay-e. Blocked/completed se ne diraju.';
