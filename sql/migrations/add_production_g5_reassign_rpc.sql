-- ============================================================================
-- PLAN PROIZVODNJE — G5 bulk REASSIGN + machine group guard + force audit
-- ============================================================================
-- REASSIGN vise ne ide direktnim update-om overlay-a iz frontenda. Svi putevi
-- idu kroz RPC koji validira poslovnu grupu masine i audit-uje force izuzetke.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.production_machine_group_slug(p_rj_code text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_rj_code IS NULL OR btrim(p_rj_code) = '' THEN 'ostalo'

    -- Erodiranje: eksplicitno samo 10.1–10.5.
    WHEN p_rj_code IN ('10.1', '10.2', '10.3', '10.4', '10.5') THEN 'erodiranje'

    -- Azistiranje: samo 8.2.
    WHEN p_rj_code = '8.2' THEN 'azistiranje'

    -- Secenje i savijanje.
    WHEN p_rj_code IN ('1.10', '1.2', '1.30', '1.40', '1.50', '1.60', '1.71', '1.72') THEN 'secenje'

    -- Bravarsko.
    WHEN p_rj_code IN ('4.1', '4.11', '4.12', '4.2', '4.3', '4.4') THEN 'bravarsko'

    -- Farbanje i povrsinska zastita.
    WHEN p_rj_code IN ('5.1', '5.2', '5.3', '5.4', '5.5', '5.6', '5.7', '5.8', '5.11') THEN 'farbanje'

    -- CAM programiranje.
    WHEN p_rj_code IN ('17.0', '17.1') THEN 'cam'

    -- Prefix grupe iz src/ui/planProizvodnje/departments.js.
    WHEN split_part(p_rj_code, '.', 1) = '3' THEN 'glodanje'
    WHEN split_part(p_rj_code, '.', 1) = '2'
      AND p_rj_code NOT IN ('21.1', '21.2') THEN 'struganje'
    WHEN split_part(p_rj_code, '.', 1) = '6'
      AND p_rj_code <> '6.8' THEN 'brusenje'

    ELSE 'ostalo'
  END;
$$;

COMMENT ON FUNCTION public.production_machine_group_slug(text) IS
  'Mapira BigTehn RJ kod u poslovnu grupu masine kao departments.js u Planiranju proizvodnje.';

CREATE OR REPLACE FUNCTION public.can_force_plan_reassign()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles ur
    WHERE lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      AND ur.is_active IS TRUE
      AND ur.role IN ('admin', 'menadzment')
  );
$$;

COMMENT ON FUNCTION public.can_force_plan_reassign() IS
  'TRUE za aktivne admin ili menadzment korisnike koji smeju da forsiraju REASSIGN preko razlicitih grupa masina.';

CREATE TABLE IF NOT EXISTS public.production_reassign_audit (
  id             bigserial PRIMARY KEY,
  work_order_id  bigint NOT NULL,
  line_id        bigint NOT NULL,
  actor_email    text,
  source_machine text,
  target_machine text,
  source_group   text,
  target_group   text,
  force_reason   text NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.production_reassign_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pra_select_force_users" ON public.production_reassign_audit;
CREATE POLICY "pra_select_force_users"
  ON public.production_reassign_audit FOR SELECT
  TO authenticated
  USING (public.can_force_plan_reassign());

DROP POLICY IF EXISTS "pra_no_client_write" ON public.production_reassign_audit;
CREATE POLICY "pra_no_client_write"
  ON public.production_reassign_audit FOR INSERT
  TO authenticated
  WITH CHECK (false);

DROP POLICY IF EXISTS "pra_no_client_update" ON public.production_reassign_audit;
CREATE POLICY "pra_no_client_update"
  ON public.production_reassign_audit FOR UPDATE
  TO authenticated
  USING (false)
  WITH CHECK (false);

DROP POLICY IF EXISTS "pra_no_client_delete" ON public.production_reassign_audit;
CREATE POLICY "pra_no_client_delete"
  ON public.production_reassign_audit FOR DELETE
  TO authenticated
  USING (false);

CREATE INDEX IF NOT EXISTS pra_idx_line
  ON public.production_reassign_audit (work_order_id, line_id, created_at DESC);

CREATE INDEX IF NOT EXISTS pra_idx_created_at
  ON public.production_reassign_audit (created_at DESC);

CREATE OR REPLACE FUNCTION public.reassign_production_line(
  p_work_order_id  bigint,
  p_line_id        bigint,
  p_target_machine text,
  p_force          boolean DEFAULT false,
  p_force_reason   text    DEFAULT NULL
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

  -- Izbor originalne masine tretiramo kao "vrati na original", tj. NULL overlay.
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

  IF v_forced THEN
    INSERT INTO public.production_reassign_audit (
      work_order_id,
      line_id,
      actor_email,
      source_machine,
      target_machine,
      source_group,
      target_group,
      force_reason
    ) VALUES (
      p_work_order_id,
      p_line_id,
      v_actor,
      v_source_machine,
      v_target_machine,
      v_source_group,
      v_target_group,
      btrim(p_force_reason)
    );
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

CREATE OR REPLACE FUNCTION public.bulk_reassign_production_lines(
  p_pairs          jsonb,
  p_target_machine text,
  p_force          boolean DEFAULT false,
  p_force_reason   text    DEFAULT NULL
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
      p_force_reason
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('updated_count', v_count);
END;
$$;

REVOKE ALL ON FUNCTION public.production_machine_group_slug(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.production_machine_group_slug(text) TO authenticated;

REVOKE ALL ON FUNCTION public.can_force_plan_reassign() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_force_plan_reassign() TO authenticated;

REVOKE ALL ON FUNCTION public.reassign_production_line(bigint, bigint, text, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reassign_production_line(bigint, bigint, text, boolean, text) TO authenticated;

REVOKE ALL ON FUNCTION public.bulk_reassign_production_lines(jsonb, text, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.bulk_reassign_production_lines(jsonb, text, boolean, text) TO authenticated;

GRANT SELECT ON public.production_reassign_audit TO authenticated;

COMMENT ON TABLE public.production_reassign_audit IS
  'G5 audit force REASSIGN izuzetaka kada admin ili menadzment prebace operaciju preko razlicitih grupa masina.';

COMMENT ON FUNCTION public.reassign_production_line(bigint, bigint, text, boolean, text) IS
  'G5 jedini server-side entry point za single REASSIGN operacije u Planiranju proizvodnje.';

COMMENT ON FUNCTION public.bulk_reassign_production_lines(jsonb, text, boolean, text) IS
  'G5 bulk REASSIGN za vise operacija; validacija i audit idu kroz reassign_production_line.';
