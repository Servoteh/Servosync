-- ============================================================================
-- ODRŽAVANJE — RLS/RPC paritet: ERP `menadzment` = isti krug kao ERP `admin`
-- ============================================================================
-- Namena:
--   Sve provere koje su bile samo `maint_is_erp_admin()` proširene su na
--   `maint_is_erp_admin_or_management()` (vidi add_maint_machine_hard_delete.sql).
--   Tako menadžment bez reda u `maint_user_profiles` može da uređuje katalog,
--   šablone, override, incidente (u okviru postojećih pravila), notifikacije,
--   fajlove (uključujući UPDATE/DELETE metadata), itd. — usklađeno sa UI-om.
--
-- Zavisi od: `public.maint_is_erp_admin_or_management()` (mora već postojati).
-- Pokreni u Supabase SQL Editoru. Idempotentno (DROP/CREATE policy).
-- ============================================================================

-- ── 1) Zatvaranje incidenta (WITH CHECK closed) ───────────────────────────
CREATE OR REPLACE FUNCTION public.maint_can_close_incident()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.maint_is_erp_admin_or_management()
      OR public.maint_profile_role() IN ('chief', 'admin');
$$;

-- ── 2) maint_user_profiles ────────────────────────────────────────────────
DROP POLICY IF EXISTS maint_profiles_select ON public.maint_user_profiles;
CREATE POLICY maint_profiles_select ON public.maint_user_profiles
  FOR SELECT USING (
    auth.uid() = user_id
    OR public.maint_is_erp_admin_or_management()
  );

DROP POLICY IF EXISTS maint_profiles_insert ON public.maint_user_profiles;
CREATE POLICY maint_profiles_insert ON public.maint_user_profiles
  FOR INSERT WITH CHECK (public.maint_is_erp_admin_or_management());

DROP POLICY IF EXISTS maint_profiles_update ON public.maint_user_profiles;
CREATE POLICY maint_profiles_update ON public.maint_user_profiles
  FOR UPDATE USING (
    public.maint_is_erp_admin_or_management()
    OR auth.uid() = user_id
  )
  WITH CHECK (
    public.maint_is_erp_admin_or_management()
    OR auth.uid() = user_id
  );

DROP POLICY IF EXISTS maint_profiles_delete ON public.maint_user_profiles;
CREATE POLICY maint_profiles_delete ON public.maint_user_profiles
  FOR DELETE USING (public.maint_is_erp_admin_or_management());

-- ── 3) maint_tasks ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS maint_tasks_insert ON public.maint_tasks;
CREATE POLICY maint_tasks_insert ON public.maint_tasks
  FOR INSERT WITH CHECK (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

DROP POLICY IF EXISTS maint_tasks_update ON public.maint_tasks;
CREATE POLICY maint_tasks_update ON public.maint_tasks
  FOR UPDATE USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  )
  WITH CHECK (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

DROP POLICY IF EXISTS maint_tasks_delete ON public.maint_tasks;
CREATE POLICY maint_tasks_delete ON public.maint_tasks
  FOR DELETE USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

-- ── 4) maint_checks (UPDATE — širi krug uz mašinu) ───────────────────────
DROP POLICY IF EXISTS maint_checks_update ON public.maint_checks;
CREATE POLICY maint_checks_update ON public.maint_checks
  FOR UPDATE USING (
    public.maint_machine_visible(machine_code)
    AND (
      performed_by = auth.uid()
      OR public.maint_is_erp_admin_or_management()
      OR public.maint_profile_role() IN ('chief', 'technician', 'admin')
    )
  )
  WITH CHECK (public.maint_machine_visible(machine_code));

-- ── 5) maint_incidents ───────────────────────────────────────────────────
DROP POLICY IF EXISTS maint_incidents_insert ON public.maint_incidents;
CREATE POLICY maint_incidents_insert ON public.maint_incidents
  FOR INSERT WITH CHECK (
    reported_by = auth.uid()
    AND public.maint_machine_visible(machine_code)
    AND (
      public.maint_is_erp_admin_or_management()
      OR public.maint_profile_role() IN ('operator', 'technician', 'chief', 'admin')
    )
  );

DROP POLICY IF EXISTS maint_incidents_update ON public.maint_incidents;
CREATE POLICY maint_incidents_update ON public.maint_incidents
  FOR UPDATE USING (
    public.maint_machine_visible(machine_code)
    AND (
      public.maint_is_erp_admin_or_management()
      OR public.maint_profile_role() IN ('technician', 'chief', 'admin')
    )
  )
  WITH CHECK (
    public.maint_machine_visible(machine_code)
    AND (
      status <> 'closed'
      OR public.maint_can_close_incident()
    )
  );

-- ── 6) maint_machine_notes ───────────────────────────────────────────────
DROP POLICY IF EXISTS maint_notes_insert ON public.maint_machine_notes;
CREATE POLICY maint_notes_insert ON public.maint_machine_notes
  FOR INSERT WITH CHECK (
    author = auth.uid()
    AND public.maint_machine_visible(machine_code)
    AND (
      public.maint_is_erp_admin_or_management()
      OR public.maint_profile_role() IN ('operator', 'technician', 'chief', 'admin')
    )
  );

DROP POLICY IF EXISTS maint_notes_update ON public.maint_machine_notes;
CREATE POLICY maint_notes_update ON public.maint_machine_notes
  FOR UPDATE USING (
    public.maint_machine_visible(machine_code)
    AND (
      public.maint_is_erp_admin_or_management()
      OR public.maint_profile_role() IN ('chief', 'admin')
      OR (
        author = auth.uid()
        AND created_at > now() - interval '24 hours'
        AND public.maint_profile_role() IN ('operator', 'technician')
      )
    )
  )
  WITH CHECK (public.maint_machine_visible(machine_code));

-- ── 7) maint_machine_status_override ─────────────────────────────────────
DROP POLICY IF EXISTS maint_override_insert ON public.maint_machine_status_override;
CREATE POLICY maint_override_insert ON public.maint_machine_status_override
  FOR INSERT WITH CHECK (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

DROP POLICY IF EXISTS maint_override_update ON public.maint_machine_status_override;
CREATE POLICY maint_override_update ON public.maint_machine_status_override
  FOR UPDATE USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  )
  WITH CHECK (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

DROP POLICY IF EXISTS maint_override_delete ON public.maint_machine_status_override;
CREATE POLICY maint_override_delete ON public.maint_machine_status_override
  FOR DELETE USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

-- ── 8) maint_notification_log ─────────────────────────────────────────────
DROP POLICY IF EXISTS maint_notif_select ON public.maint_notification_log;
CREATE POLICY maint_notif_select ON public.maint_notification_log
  FOR SELECT USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'management', 'admin')
  );

-- ── 9) maint_machines (katalog — INSERT/UPDATE; DELETE već u hard_delete) ─
DROP POLICY IF EXISTS maint_machines_insert ON public.maint_machines;
CREATE POLICY maint_machines_insert ON public.maint_machines
  FOR INSERT WITH CHECK (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

DROP POLICY IF EXISTS maint_machines_update ON public.maint_machines;
CREATE POLICY maint_machines_update ON public.maint_machines
  FOR UPDATE USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  )
  WITH CHECK (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

DROP POLICY IF EXISTS maint_machines_delete ON public.maint_machines;
CREATE POLICY maint_machines_delete ON public.maint_machines
  FOR DELETE USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
  );

-- ── 10) maint_machine_files + storage (menadžment i menja/briše) ────────
DROP POLICY IF EXISTS mmf_update ON public.maint_machine_files;
CREATE POLICY mmf_update ON public.maint_machine_files
  FOR UPDATE USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
    OR (
      uploaded_by = auth.uid()
      AND uploaded_at > now() - interval '24 hours'
      AND public.maint_profile_role() IN ('operator', 'technician')
    )
  )
  WITH CHECK (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
    OR (
      uploaded_by = auth.uid()
      AND uploaded_at > now() - interval '24 hours'
      AND public.maint_profile_role() IN ('operator', 'technician')
    )
  );

DROP POLICY IF EXISTS mmf_delete ON public.maint_machine_files;
CREATE POLICY mmf_delete ON public.maint_machine_files
  FOR DELETE USING (
    public.maint_is_erp_admin_or_management()
    OR public.maint_profile_role() IN ('chief', 'admin')
    OR (
      uploaded_by = auth.uid()
      AND uploaded_at > now() - interval '24 hours'
      AND public.maint_profile_role() IN ('operator', 'technician')
    )
  );

DROP POLICY IF EXISTS "mmf_storage_update" ON storage.objects;
CREATE POLICY "mmf_storage_update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'maint-machine-files'
    AND (
      public.maint_is_erp_admin_or_management()
      OR public.maint_profile_role() IN ('chief', 'admin')
    )
  )
  WITH CHECK (
    bucket_id = 'maint-machine-files'
    AND (
      public.maint_is_erp_admin_or_management()
      OR public.maint_profile_role() IN ('chief', 'admin')
    )
  );

DROP POLICY IF EXISTS "mmf_storage_delete" ON storage.objects;
CREATE POLICY "mmf_storage_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'maint-machine-files'
    AND (
      public.maint_is_erp_admin_or_management()
      OR public.maint_profile_role() IN ('chief', 'admin')
      OR owner = auth.uid()
    )
  );

-- ── 11) RPC: isto telo kao u originalnim migracijama; širi `v_allowed` ────
CREATE OR REPLACE FUNCTION public.maint_machines_import_from_cache(
  p_codes TEXT[]
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_allowed BOOLEAN;
  v_count   INT := 0;
BEGIN
  v_allowed := public.maint_is_erp_admin_or_management()
            OR public.maint_profile_role() IN ('chief', 'admin');
  IF NOT v_allowed THEN
    RAISE EXCEPTION 'maint_machines_import_from_cache: not authorized' USING ERRCODE = '42501';
  END IF;

  IF p_codes IS NULL OR cardinality(p_codes) = 0 THEN
    RETURN 0;
  END IF;

  INSERT INTO public.maint_machines (
    machine_code, name, department_id, source, tracked, archived_at, updated_by
  )
  SELECT
    c.rj_code,
    COALESCE(NULLIF(TRIM(c.name), ''), c.rj_code),
    c.department_id,
    'bigtehn',
    TRUE,
    NULL,
    auth.uid()
  FROM public.bigtehn_machines_cache c
  WHERE c.rj_code = ANY (p_codes)
  ON CONFLICT (machine_code) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION public.maint_machines_import_from_cache(TEXT[]) IS
  'Uvozi odabrane rj_code iz bigtehn_machines_cache u maint_machines (source=bigtehn). ERP admin/menadžment ili chief/admin maint.';

REVOKE ALL ON FUNCTION public.maint_machines_import_from_cache(TEXT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.maint_machines_import_from_cache(TEXT[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.maint_machine_rename(
  p_old_code TEXT,
  p_new_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_allowed    BOOLEAN;
  v_cnt_tasks  INT := 0;
  v_cnt_checks INT := 0;
  v_cnt_inc    INT := 0;
  v_cnt_notes  INT := 0;
  v_cnt_ovr    INT := 0;
  v_cnt_notif  INT := 0;
BEGIN
  v_allowed := public.maint_is_erp_admin_or_management()
            OR public.maint_profile_role() IN ('chief', 'admin');
  IF NOT v_allowed THEN
    RAISE EXCEPTION 'maint_machine_rename: not authorized' USING ERRCODE = '42501';
  END IF;

  IF p_old_code IS NULL OR btrim(p_old_code) = '' THEN
    RAISE EXCEPTION 'maint_machine_rename: old code is required';
  END IF;
  IF p_new_code IS NULL OR btrim(p_new_code) = '' THEN
    RAISE EXCEPTION 'maint_machine_rename: new code is required';
  END IF;
  IF p_old_code = p_new_code THEN
    RAISE EXCEPTION 'maint_machine_rename: old and new codes are the same';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.maint_machines WHERE machine_code = p_old_code) THEN
    RAISE EXCEPTION 'maint_machine_rename: machine "%" does not exist', p_old_code;
  END IF;
  IF EXISTS (SELECT 1 FROM public.maint_machines WHERE machine_code = p_new_code) THEN
    RAISE EXCEPTION 'maint_machine_rename: machine "%" already exists', p_new_code;
  END IF;

  INSERT INTO public.maint_machines (
    machine_code, name, type, manufacturer, model, serial_number,
    year_of_manufacture, year_commissioned, location, department_id,
    power_kw, weight_kg, notes, tracked, archived_at, source,
    created_at, updated_at, updated_by
  )
  SELECT
    p_new_code, name, type, manufacturer, model, serial_number,
    year_of_manufacture, year_commissioned, location, department_id,
    power_kw, weight_kg, notes, tracked, archived_at, source,
    created_at, now(), auth.uid()
  FROM public.maint_machines
  WHERE machine_code = p_old_code;

  UPDATE public.maint_tasks SET machine_code = p_new_code
   WHERE machine_code = p_old_code;
  GET DIAGNOSTICS v_cnt_tasks = ROW_COUNT;

  UPDATE public.maint_checks SET machine_code = p_new_code
   WHERE machine_code = p_old_code;
  GET DIAGNOSTICS v_cnt_checks = ROW_COUNT;

  UPDATE public.maint_incidents SET machine_code = p_new_code
   WHERE machine_code = p_old_code;
  GET DIAGNOSTICS v_cnt_inc = ROW_COUNT;

  UPDATE public.maint_machine_notes SET machine_code = p_new_code
   WHERE machine_code = p_old_code;
  GET DIAGNOSTICS v_cnt_notes = ROW_COUNT;

  UPDATE public.maint_machine_status_override SET machine_code = p_new_code
   WHERE machine_code = p_old_code;
  GET DIAGNOSTICS v_cnt_ovr = ROW_COUNT;

  UPDATE public.maint_notification_log SET machine_code = p_new_code
   WHERE machine_code = p_old_code;
  GET DIAGNOSTICS v_cnt_notif = ROW_COUNT;

  DELETE FROM public.maint_machines WHERE machine_code = p_old_code;

  RETURN jsonb_build_object(
    'old_code',     p_old_code,
    'new_code',     p_new_code,
    'tasks',        v_cnt_tasks,
    'checks',       v_cnt_checks,
    'incidents',    v_cnt_inc,
    'notes',        v_cnt_notes,
    'overrides',    v_cnt_ovr,
    'notifications', v_cnt_notif
  );
END;
$$;

COMMENT ON FUNCTION public.maint_machine_rename(TEXT, TEXT) IS
  'Atomski preimenuje machine_code u svim maint_* tabelama. ERP admin/menadžment ili chief/admin maint.';

REVOKE ALL ON FUNCTION public.maint_machine_rename(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.maint_machine_rename(TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.maint_notification_retry(
  p_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_allowed BOOLEAN;
BEGIN
  v_allowed := public.maint_is_erp_admin_or_management()
            OR public.maint_profile_role() IN ('chief', 'admin');
  IF NOT v_allowed THEN
    RAISE EXCEPTION 'maint_notification_retry: not authorized' USING ERRCODE = '42501';
  END IF;

  UPDATE public.maint_notification_log
     SET status          = 'queued',
         error           = NULL,
         next_attempt_at = now(),
         /* Spusti attempts na max-1 = 7 ako je dostigao plafon, inače zadrži. */
         attempts        = LEAST(attempts, 7)
   WHERE id = p_id;

  RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION public.maint_notification_retry(uuid) IS
  'Vraća notifikaciju u queue (retry) — chief/admin maint ili ERP admin/menadžment.';

REVOKE ALL ON FUNCTION public.maint_notification_retry(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.maint_notification_retry(uuid) TO authenticated;

COMMENT ON FUNCTION public.maint_can_close_incident() IS
  'True ako sme closed: ERP admin/menadžment ili šef/admin maint profila.';
