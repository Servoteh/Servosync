-- ============================================================================
-- Supabase: isti sadrzaj kao sql/migrations/extend_maint_incidents_assets.sql
-- ============================================================================

-- ============================================================================
-- ODRŽAVANJE (CMMS) — incidenti vezani za maint_assets + safety marker
-- ============================================================================
-- MORA posle:
--   * add_maint_assets_supertable.sql
--   * add_maint_work_orders.sql
--   * link_maint_incidents_to_wo.sql
-- ============================================================================

BEGIN;

ALTER TABLE public.maint_incidents
  ADD COLUMN IF NOT EXISTS asset_id UUID REFERENCES public.maint_assets (asset_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS asset_type public.maint_asset_type,
  ADD COLUMN IF NOT EXISTS safety_marker BOOLEAN NOT NULL DEFAULT false;

UPDATE public.maint_incidents i
SET asset_id = m.asset_id,
    asset_type = 'machine'::public.maint_asset_type
FROM public.maint_machines m
WHERE i.asset_id IS NULL
  AND m.machine_code = i.machine_code;

CREATE INDEX IF NOT EXISTS idx_maint_incidents_asset
  ON public.maint_incidents (asset_id)
  WHERE asset_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_maint_incidents_safety_open
  ON public.maint_incidents (safety_marker, status)
  WHERE safety_marker = true
    AND status NOT IN ('resolved', 'closed');

COMMENT ON COLUMN public.maint_incidents.asset_id IS
  'CMMS sredstvo na koje se incident odnosi. Za stare zapise se dobija iz machine_code kada je moguće.';

COMMENT ON COLUMN public.maint_incidents.safety_marker IS
  'Označava incident koji ima bezbednosni rizik i treba da prenese marker na radni nalog.';

CREATE OR REPLACE FUNCTION public.maint_incident_row_visible(
  p_machine_code TEXT,
  p_asset_id UUID
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_asset_id IS NOT NULL THEN public.maint_asset_visible(p_asset_id)
    ELSE public.maint_machine_visible(p_machine_code)
  END;
$$;

COMMENT ON FUNCTION public.maint_incident_row_visible(text, uuid) IS
  'Vidljivost incidenta: novi zapisi preko maint_assets, legacy zapisi preko machine_code.';

GRANT EXECUTE ON FUNCTION public.maint_incident_row_visible(text, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.maint_can_close_incident()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.maint_is_erp_admin_or_management()
      OR public.maint_is_erp_admin()
      OR public.maint_profile_role() IN ('chief', 'admin');
$$;

GRANT EXECUTE ON FUNCTION public.maint_can_close_incident() TO authenticated;

CREATE OR REPLACE FUNCTION public.maint_incidents_set_asset_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_asset public.maint_assets%ROWTYPE;
BEGIN
  IF NEW.asset_id IS NULL THEN
    SELECT a.* INTO v_asset
    FROM public.maint_machines m
    JOIN public.maint_assets a ON a.asset_id = m.asset_id
    WHERE m.machine_code = NEW.machine_code
    LIMIT 1;
  ELSE
    SELECT a.* INTO v_asset
    FROM public.maint_assets a
    WHERE a.asset_id = NEW.asset_id
    LIMIT 1;
  END IF;

  IF v_asset.asset_id IS NOT NULL THEN
    NEW.asset_id := v_asset.asset_id;
    NEW.asset_type := v_asset.asset_type;
    IF NEW.machine_code IS NULL OR length(btrim(NEW.machine_code)) = 0 THEN
      NEW.machine_code := v_asset.asset_code;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS maint_incidents_set_asset_fields ON public.maint_incidents;
CREATE TRIGGER maint_incidents_set_asset_fields
  BEFORE INSERT OR UPDATE OF machine_code, asset_id
  ON public.maint_incidents
  FOR EACH ROW EXECUTE FUNCTION public.maint_incidents_set_asset_fields();

DROP POLICY IF EXISTS maint_incidents_select ON public.maint_incidents;
CREATE POLICY maint_incidents_select ON public.maint_incidents
  FOR SELECT USING (public.maint_incident_row_visible(machine_code, asset_id));

DROP POLICY IF EXISTS maint_incidents_insert ON public.maint_incidents;
CREATE POLICY maint_incidents_insert ON public.maint_incidents
  FOR INSERT WITH CHECK (
    reported_by = auth.uid()
    AND public.maint_incident_row_visible(machine_code, asset_id)
    AND (
      public.maint_is_erp_admin_or_management()
      OR public.maint_is_erp_admin()
      OR public.maint_profile_role() IN ('operator', 'technician', 'chief', 'admin')
    )
  );

DROP POLICY IF EXISTS maint_incidents_update ON public.maint_incidents;
CREATE POLICY maint_incidents_update ON public.maint_incidents
  FOR UPDATE USING (
    public.maint_incident_row_visible(machine_code, asset_id)
    AND (
      public.maint_is_erp_admin_or_management()
      OR public.maint_is_erp_admin()
      OR public.maint_profile_role() IN ('technician', 'chief', 'admin')
    )
  )
  WITH CHECK (
    public.maint_incident_row_visible(machine_code, asset_id)
    AND (
      status <> 'closed'
      OR public.maint_can_close_incident()
      OR public.maint_is_erp_admin_or_management()
      OR public.maint_profile_role() IN ('chief', 'admin')
    )
  );

CREATE OR REPLACE FUNCTION public.maint_incidents_autocreate_work_order()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_asset UUID;
  v_tcode public.maint_asset_type;
  v_pri public.maint_wo_priority;
  v_st public.maint_wo_status;
  v_t public.maint_wo_type := 'incident';
  v_wo UUID;
BEGIN
  IF NEW.severity NOT IN ('major', 'critical') THEN
    RETURN NEW;
  END IF;

  IF NEW.work_order_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.asset_id IS NOT NULL THEN
    SELECT a.asset_id, a.asset_type
    INTO v_asset, v_tcode
    FROM public.maint_assets a
    WHERE a.asset_id = NEW.asset_id;
  ELSE
    SELECT m.asset_id, 'machine'::public.maint_asset_type
    INTO v_asset, v_tcode
    FROM public.maint_machines m
    WHERE m.machine_code = NEW.machine_code
    LIMIT 1;
  END IF;

  IF v_asset IS NULL THEN
    RETURN NEW;
  END IF;

  v_pri := CASE NEW.severity WHEN 'critical' THEN 'p1_zastoj'::public.maint_wo_priority ELSE 'p2_smetnja'::public.maint_wo_priority END;
  v_st  := CASE NEW.severity WHEN 'critical' THEN 'potvrden'::public.maint_wo_status ELSE 'novi'::public.maint_wo_status END;

  INSERT INTO public.maint_work_orders (
    type, asset_id, asset_type, source_incident_id, title, description,
    priority, status, reported_by, assigned_to, safety_marker
  ) VALUES (
    v_t, v_asset, v_tcode, NEW.id, NEW.title, NEW.description,
    v_pri, v_st, NEW.reported_by, NEW.assigned_to, COALESCE(NEW.safety_marker, false)
  ) RETURNING wo_id INTO v_wo;

  UPDATE public.maint_incidents
  SET work_order_id = v_wo
  WHERE id = NEW.id;

  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS maint_incidents_autocreate_wo ON public.maint_incidents;
CREATE TRIGGER maint_incidents_autocreate_wo
  AFTER INSERT ON public.maint_incidents
  FOR EACH ROW EXECUTE FUNCTION public.maint_incidents_autocreate_work_order();

COMMIT;
