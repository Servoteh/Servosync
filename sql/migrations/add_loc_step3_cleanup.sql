-- ============================================================================
-- LOKACIJE DELOVA — STEP 3: čišćenje + retention helper
-- ============================================================================
-- 1) Skida fulltext GIN indeks koji FE ne koristi (loc_locations_path_gin_idx).
-- 2) Dodaje helper funkciju za purge `loc_sync_outbound_events` — zove je admin
--    ručno ili Supabase scheduled job (pg_cron / external cron).
-- 3) Precizira `loc_create_movement` greške — ukida katch-all exception koji je
--    vraćao sve kao 'exception', i uvodi code-e `bad_from_uuid`, `bad_to_uuid`.
--
-- Zavisi od: Step 1 (add_loc_module.sql), Step 2 (opciono).
--
-- DOWN:
--   CREATE INDEX IF NOT EXISTS loc_locations_path_gin_idx
--     ON public.loc_locations USING gin (to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(path_cached,'')));
--   DROP FUNCTION IF EXISTS public.loc_purge_synced_events(integer);
-- ============================================================================

-- ── 1. Drop GIN fulltext indeks ────────────────────────────────────────────
DROP INDEX IF EXISTS public.loc_locations_path_gin_idx;

-- ── 2. Retention: briše SYNCED redove starije od N dana ────────────────────
CREATE OR REPLACE FUNCTION public.loc_purge_synced_events(p_retention_days integer DEFAULT 90)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_purge$
DECLARE
  v_deleted integer;
BEGIN
  IF NOT public.loc_is_admin() THEN
    RAISE EXCEPTION 'forbidden: only admin can purge sync events';
  END IF;

  IF p_retention_days IS NULL OR p_retention_days < 1 THEN
    RAISE EXCEPTION 'retention_days must be >= 1';
  END IF;

  v_deleted := (
    WITH d AS (
      DELETE FROM public.loc_sync_outbound_events
      WHERE status = 'SYNCED'
        AND synced_at IS NOT NULL
        AND synced_at < now() - make_interval(days => p_retention_days)
      RETURNING 1
    )
    SELECT COUNT(*) FROM d
  );

  RETURN v_deleted;
END;
$fn_purge$;

GRANT EXECUTE ON FUNCTION public.loc_purge_synced_events(integer) TO authenticated;

COMMENT ON FUNCTION public.loc_purge_synced_events(integer) IS
  'Briše SYNCED redove iz loc_sync_outbound_events starije od p_retention_days (default 90). Samo admin.';

-- ── 3. Precizniji RPC: kontrolisane greške umesto catch-all EXCEPTION ──────
CREATE OR REPLACE FUNCTION public.loc_create_movement(payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_move$
DECLARE
  v_item_table TEXT;
  v_item_id TEXT;
  v_to UUID;
  v_from UUID;
  v_mtype public.loc_movement_type_enum;
  v_uid UUID;
  v_cur UUID;
  v_to_raw TEXT;
  v_from_raw TEXT;
  v_mtype_raw TEXT;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  v_item_table := nullif(trim(payload->>'item_ref_table'), '');
  v_item_id := nullif(trim(payload->>'item_ref_id'), '');
  v_mtype_raw := payload->>'movement_type';

  BEGIN
    v_mtype := v_mtype_raw::public.loc_movement_type_enum;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_movement_type', 'detail', v_mtype_raw);
  WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_movement_type', 'detail', v_mtype_raw);
  END;

  v_to_raw := nullif(trim(payload->>'to_location_id'), '');
  IF v_to_raw IS NOT NULL THEN
    BEGIN
      v_to := v_to_raw::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
      RETURN jsonb_build_object('ok', false, 'error', 'bad_to_uuid');
    WHEN OTHERS THEN
      RETURN jsonb_build_object('ok', false, 'error', 'bad_to_uuid');
    END;
  ELSE
    v_to := NULL;
  END IF;

  IF v_item_table IS NULL OR v_item_id IS NULL OR v_to IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_fields');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.loc_locations loc_chk
    WHERE loc_chk.id = (SELECT v_to) AND loc_chk.is_active
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_to_location');
  END IF;

  v_from_raw := nullif(trim(payload->>'from_location_id'), '');
  IF v_from_raw IS NOT NULL THEN
    BEGIN
      v_from := v_from_raw::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
      RETURN jsonb_build_object('ok', false, 'error', 'bad_from_uuid');
    WHEN OTHERS THEN
      RETURN jsonb_build_object('ok', false, 'error', 'bad_from_uuid');
    END;
  ELSE
    v_from := NULL;
  END IF;

  v_cur := (
    SELECT lp.location_id
    FROM public.loc_item_placements lp
    WHERE lp.item_ref_table = (SELECT v_item_table)
      AND lp.item_ref_id = (SELECT v_item_id)
    LIMIT 1
  );

  IF v_mtype = 'INITIAL_PLACEMENT' THEN
    IF v_cur IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', 'already_placed');
    END IF;
    v_from := NULL;
  ELSE
    IF v_cur IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', 'no_current_placement');
    END IF;
    IF v_from IS NOT NULL AND v_from <> v_cur THEN
      RETURN jsonb_build_object('ok', false, 'error', 'from_mismatch');
    END IF;
    v_from := v_cur;
  END IF;

  RETURN (
    WITH ins AS (
      INSERT INTO public.loc_location_movements (
        item_ref_table, item_ref_id, from_location_id, to_location_id,
        movement_type, movement_reason, note, moved_at, moved_by
      ) VALUES (
        v_item_table,
        v_item_id,
        v_from,
        v_to,
        v_mtype,
        nullif(trim(payload->>'movement_reason'), ''),
        nullif(trim(payload->>'note'), ''),
        coalesce((payload->>'moved_at')::timestamptz, now()),
        v_uid
      )
      RETURNING id
    )
    SELECT jsonb_build_object('ok', true, 'id', ins.id) FROM ins
  );
END;
$fn_move$;

GRANT EXECUTE ON FUNCTION public.loc_create_movement(jsonb) TO authenticated;
