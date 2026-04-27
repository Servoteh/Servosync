-- ============================================================================
-- ODRŽAVANJE (CMMS) — Preventiva V2: kreiranje WO iz preventivnog roka
-- ============================================================================
-- MORA posle:
--   * add_maint_work_orders.sql
--   * add_maint_settings.sql
-- ============================================================================

BEGIN;

ALTER TABLE public.maint_tasks
  ADD COLUMN IF NOT EXISTS checklist_template JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS asset_id UUID REFERENCES public.maint_assets (asset_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_maint_tasks_asset
  ON public.maint_tasks (asset_id)
  WHERE asset_id IS NOT NULL AND active = true;

CREATE OR REPLACE FUNCTION public.maint_create_preventive_work_order(
  p_task_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_allowed BOOLEAN;
  v_task public.maint_tasks%ROWTYPE;
  v_asset UUID;
  v_asset_type public.maint_asset_type;
  v_existing UUID;
  v_wo UUID;
  v_settings public.maint_settings%ROWTYPE;
BEGIN
  v_allowed := public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('technician', 'chief', 'admin');
  IF NOT v_allowed THEN
    RAISE EXCEPTION 'maint_create_preventive_work_order: not authorized' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_task
  FROM public.maint_tasks
  WHERE id = p_task_id
    AND active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Preventive task not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_task.asset_id IS NOT NULL THEN
    SELECT a.asset_id, a.asset_type
    INTO v_asset, v_asset_type
    FROM public.maint_assets a
    WHERE a.asset_id = v_task.asset_id;
  ELSE
    SELECT m.asset_id, 'machine'::public.maint_asset_type
    INTO v_asset, v_asset_type
    FROM public.maint_machines m
    WHERE m.machine_code = v_task.machine_code
    LIMIT 1;
  END IF;

  IF v_asset IS NULL THEN
    RAISE EXCEPTION 'Preventive task has no CMMS asset' USING ERRCODE = '23503';
  END IF;

  SELECT wo_id INTO v_existing
  FROM public.maint_work_orders
  WHERE source_preventive_task_id = p_task_id
    AND status <> 'otkazan'::public.maint_wo_status
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  SELECT * INTO v_settings
  FROM public.maint_settings
  WHERE id = 1;

  INSERT INTO public.maint_work_orders (
    type, asset_id, asset_type, source_preventive_task_id, title, description,
    priority, status, reported_by, safety_marker, due_at
  ) VALUES (
    'preventive'::public.maint_wo_type,
    v_asset,
    v_asset_type,
    p_task_id,
    'Preventiva: ' || v_task.title,
    v_task.instructions,
    COALESCE(v_settings.default_wo_priority, 'p4_planirano'::public.maint_wo_priority),
    'novi'::public.maint_wo_status,
    auth.uid(),
    false,
    now() + make_interval(days => COALESCE(v_settings.preventive_due_warning_days, 7))
  ) RETURNING wo_id INTO v_wo;

  INSERT INTO public.maint_wo_events (wo_id, actor, event_type, comment)
  VALUES (v_wo, auth.uid(), 'preventive_auto_wo', 'Radni nalog kreiran iz preventivnog roka.');

  RETURN v_wo;
END;
$$;

REVOKE ALL ON FUNCTION public.maint_create_preventive_work_order(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.maint_create_preventive_work_order(UUID) TO authenticated;

COMMIT;
