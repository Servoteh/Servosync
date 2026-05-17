-- =====================================================================
-- PP Sprint 1B (H1): G5 REASSIGN idempotency
-- =====================================================================
-- Sprečava duplikate u production_reassign_audit kada klijent retry-uje
-- RPC poziv (timeout, network drop, double-click). Klijent generiše UUID v4
-- pre RPC poziva i šalje kao p_client_event_uuid; INSERT u audit ima
-- ON CONFLICT (client_event_uuid, line_id) DO NOTHING.
--
-- Backward compat: parametar je DEFAULT NULL. Stari pozivi bez UUID-a
-- i dalje rade — Postgres UNIQUE ne tretira NULL kao konfliktan, pa
-- istorijski redovi i novi redovi bez UUID-a prolaze.
--
-- Function overloading: CREATE OR REPLACE sa novim parametrom pravi
-- NOVU varijantu funkcije; stara (5/4 parametra) ostaje. PostgREST
-- razrešava overload po payload-u. Posle migracije klijenta (1-2
-- sprint-a), izvršiti DROP FUNCTION stare varijante.
--
-- DRAFT — NE izvršavati automatski; ručno aplicirati u Supabase Studio.
-- =====================================================================

-- 1. Dodaj kolonu za idempotency ključ (idempotentno ALTER)
ALTER TABLE public.production_reassign_audit
  ADD COLUMN IF NOT EXISTS client_event_uuid uuid;

COMMENT ON COLUMN public.production_reassign_audit.client_event_uuid IS
  'H1: klijentski generisan UUID v4 za idempotency. NULL za istorijske redove pre Sprint 1B.';

-- 2. UNIQUE indeks na (client_event_uuid, line_id)
-- Bulk reassign: jedan UUID po RPC pozivu, više line_id-jeva → svi prolaze prvi put.
-- Retry istog bulk-a: svaki par (uuid, line_id) hit-uje ON CONFLICT.
-- NULL-ovi nisu konfliktni → istorijski redovi i klijenti bez UUID-a rade.
CREATE UNIQUE INDEX IF NOT EXISTS pra_uq_client_event_uuid_line
  ON public.production_reassign_audit (client_event_uuid, line_id);

-- 3. reassign_production_line sa novim p_client_event_uuid parametrom
CREATE OR REPLACE FUNCTION public.reassign_production_line(
  p_work_order_id     bigint,
  p_line_id           bigint,
  p_target_machine    text,
  p_force             boolean DEFAULT false,
  p_force_reason      text    DEFAULT NULL,
  p_client_event_uuid uuid    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_original_machine text;
  v_source_machine   text;
  v_target_machine   text := nullif(btrim(p_target_machine), '');
  v_source_group     text;
  v_target_group     text;
  v_actor            text;
  v_forced           boolean := false;
BEGIN
  IF NOT public.can_edit_plan_proizvodnje() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT
    l.machine_code,
    coalesce(o.assigned_machine_code, l.machine_code)
  INTO v_original_machine, v_source_machine
  FROM public.bigtehn_work_order_lines_cache l
  LEFT JOIN public.production_overlays o
    ON o.work_order_id = l.work_order_id
   AND o.line_id = l.id
  WHERE l.work_order_id = p_work_order_id
    AND l.id = p_line_id
  LIMIT 1;

  IF v_original_machine IS NULL THEN
    RAISE EXCEPTION 'operation_not_found' USING ERRCODE = '22023';
  END IF;

  -- Izbor originalne mašine tretiramo kao "vrati na original", tj. NULL overlay.
  IF v_target_machine IS NOT NULL AND v_target_machine = v_original_machine THEN
    v_target_machine := NULL;
  END IF;

  IF v_target_machine IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.bigtehn_machines_cache m
      WHERE m.rj_code = v_target_machine
    ) THEN
      RAISE EXCEPTION 'target_machine_not_found' USING ERRCODE = '22023';
    END IF;

    v_source_group := public.production_machine_group_slug(v_source_machine);
    v_target_group := public.production_machine_group_slug(v_target_machine);

    IF v_source_group IS DISTINCT FROM v_target_group THEN
      IF NOT p_force THEN
        RAISE EXCEPTION 'machine_group_mismatch' USING ERRCODE = '22023';
      END IF;
      IF NOT public.can_force_plan_reassign() THEN
        RAISE EXCEPTION 'force_reassign_forbidden' USING ERRCODE = '42501';
      END IF;
      IF p_force_reason IS NULL OR length(btrim(p_force_reason)) < 3 THEN
        RAISE EXCEPTION 'force_reason_required' USING ERRCODE = '22023';
      END IF;
      v_forced := true;
    END IF;
  ELSE
    v_source_group := public.production_machine_group_slug(v_source_machine);
    v_target_group := public.production_machine_group_slug(v_original_machine);
  END IF;

  v_actor := coalesce(public.current_user_email(), auth.jwt() ->> 'email', 'unknown');

  -- Overlay UPSERT (idempotentno po (work_order_id, line_id))
  INSERT INTO public.production_overlays (
    work_order_id,
    line_id,
    assigned_machine_code,
    created_by,
    updated_by
  ) VALUES (
    p_work_order_id,
    p_line_id,
    v_target_machine,
    v_actor,
    v_actor
  )
  ON CONFLICT (work_order_id, line_id) DO UPDATE SET
    assigned_machine_code = EXCLUDED.assigned_machine_code,
    updated_by = EXCLUDED.updated_by;

  -- Audit INSERT (idempotentno po (client_event_uuid, line_id) ako je UUID poslat)
  IF v_forced THEN
    INSERT INTO public.production_reassign_audit (
      work_order_id,
      line_id,
      actor_email,
      source_machine,
      target_machine,
      source_group,
      target_group,
      force_reason,
      client_event_uuid
    ) VALUES (
      p_work_order_id,
      p_line_id,
      v_actor,
      v_source_machine,
      v_target_machine,
      v_source_group,
      v_target_group,
      btrim(p_force_reason),
      p_client_event_uuid
    )
    ON CONFLICT (client_event_uuid, line_id) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'work_order_id', p_work_order_id,
    'line_id', p_line_id,
    'assigned_machine_code', v_target_machine,
    'source_group', v_source_group,
    'target_group', v_target_group,
    'forced', v_forced
  );
END;
$$;

-- 4. bulk_reassign_production_lines sa novim p_client_event_uuid parametrom
-- Svi parovi u bulk pozivu dele isti UUID; idempotency je po (uuid, line_id).
CREATE OR REPLACE FUNCTION public.bulk_reassign_production_lines(
  p_pairs             jsonb,
  p_target_machine    text,
  p_force             boolean DEFAULT false,
  p_force_reason      text    DEFAULT NULL,
  p_client_event_uuid uuid    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_pair   jsonb;
  v_count  integer := 0;
  v_result jsonb;
BEGIN
  IF NOT public.can_edit_plan_proizvodnje() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  IF jsonb_typeof(p_pairs) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'pairs_must_be_array' USING ERRCODE = '22023';
  END IF;

  FOR v_pair IN SELECT value FROM jsonb_array_elements(p_pairs) LOOP
    v_result := public.reassign_production_line(
      (v_pair ->> 'wo')::bigint,
      (v_pair ->> 'line')::bigint,
      p_target_machine,
      p_force,
      p_force_reason,
      p_client_event_uuid
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('updated_count', v_count);
END;
$$;

-- 5. GRANT-i za nove varijante (stare ostaju netaknute)
REVOKE ALL ON FUNCTION public.reassign_production_line(bigint, bigint, text, boolean, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reassign_production_line(bigint, bigint, text, boolean, text, uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.bulk_reassign_production_lines(jsonb, text, boolean, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.bulk_reassign_production_lines(jsonb, text, boolean, text, uuid) TO authenticated;

COMMENT ON FUNCTION public.reassign_production_line(bigint, bigint, text, boolean, text, uuid) IS
  'G5 + H1 idempotency: jedini server-side entry point za single REASSIGN. UUID parametar sprečava duplikate u audit-u kod retry-a.';

COMMENT ON FUNCTION public.bulk_reassign_production_lines(jsonb, text, boolean, text, uuid) IS
  'G5 + H1 idempotency: bulk REASSIGN. Svi parovi dele isti UUID; idempotency po (uuid, line_id) u audit-u.';

-- 6. PostgREST schema reload
NOTIFY pgrst, 'reload schema';

-- =====================================================================
-- TODO (Sprint 1B+1, posle migracije svih klijenata):
-- =====================================================================
-- DROP FUNCTION IF EXISTS public.reassign_production_line(bigint, bigint, text, boolean, text);
-- DROP FUNCTION IF EXISTS public.bulk_reassign_production_lines(jsonb, text, boolean, text);
-- =====================================================================
