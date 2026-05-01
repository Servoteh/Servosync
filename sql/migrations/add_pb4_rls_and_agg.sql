-- ═══════════════════════════════════════════════════════════════════════════
-- PB4 — pb_work_reports RLS hardening + server-side obračun agregata + helper RPC
-- Zavisi od: add_pb_module.sql, add_pb_notifications.sql (politike na pb_work_reports),
--            add_menadzment_full_edit_kadrovska.sql (has_edit_role),
--            add_kadr_org_structure.sql ili CI bootstrap (employees.sub_department_id,
--            sub_departments).
-- NE izvršavati na produkciji bez pregleda.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Seed pododeljenja ako nedostaje (CI bootstrap ima samo Mašinsko projektovanje)
INSERT INTO public.sub_departments (id, department_id, name, sort_order)
VALUES (5002, 5, 'Rukovodstvo inženjeringa', 15)
ON CONFLICT (id) DO NOTHING;
SELECT setval(
  pg_get_serial_sequence('public.sub_departments', 'id'),
  GREATEST((SELECT COALESCE(MAX(id), 1) FROM public.sub_departments), 5002)
);

-- ── pb_current_employee_id()
CREATE OR REPLACE FUNCTION public.pb_current_employee_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT e.id
  FROM public.employees e
  WHERE lower(trim(coalesce(e.email, ''))) = lower(trim(coalesce(auth.jwt() ->> 'email', '')))
    AND e.is_active IS TRUE
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.pb_current_employee_id() IS
  'Projektni biro PB4 — UUID zaposlenog za JWT email (NULL ako nema reda).';

REVOKE ALL ON FUNCTION public.pb_current_employee_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_current_employee_id() TO authenticated;

-- ── pb_engineering_lead_by_subdept() — „Rukovodstvo inženjeringa“ preko sub_departments.name
CREATE OR REPLACE FUNCTION public.pb_engineering_lead_by_subdept()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.employees e
    INNER JOIN public.sub_departments sd ON sd.id = e.sub_department_id
    WHERE e.is_active IS TRUE
      AND lower(trim(sd.name)) = lower(trim('Rukovodstvo inženjeringa'))
      AND lower(trim(coalesce(e.email, ''))) = lower(trim(coalesce(auth.jwt() ->> 'email', '')))
  );
$$;

REVOKE ALL ON FUNCTION public.pb_engineering_lead_by_subdept() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_engineering_lead_by_subdept() TO authenticated;

-- ── pb_current_user_can_see_all_reports()
CREATE OR REPLACE FUNCTION public.pb_current_user_can_see_all_reports()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  auth_email TEXT := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
BEGIN
  IF auth_email = '' THEN
    RETURN false;
  END IF;

  IF public.current_user_is_admin() THEN
    RETURN true;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.user_roles ur
    WHERE lower(trim(ur.email)) = auth_email
      AND ur.project_id IS NULL
      AND ur.role IN ('leadpm', 'pm', 'menadzment')
      AND ur.is_active IS TRUE
  ) THEN
    RETURN true;
  END IF;

  IF public.pb_engineering_lead_by_subdept() THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

COMMENT ON FUNCTION public.pb_current_user_can_see_all_reports() IS
  'PB4 — admin, leadpm/pm/menadzment (globalno), Rukovodstvo inženjeringa (sub_departments).';

REVOKE ALL ON FUNCTION public.pb_current_user_can_see_all_reports() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_current_user_can_see_all_reports() TO authenticated;

-- ── DROP postojećih politika pb_work_reports (imena iz add_pb_module + add_pb_notifications)
DROP POLICY IF EXISTS pb_work_reports_select_authenticated ON public.pb_work_reports;
DROP POLICY IF EXISTS pb_work_reports_insert_editors ON public.pb_work_reports;
DROP POLICY IF EXISTS pb_work_reports_update_editors ON public.pb_work_reports;
DROP POLICY IF EXISTS pb_work_reports_delete_admin ON public.pb_work_reports;
DROP POLICY IF EXISTS pb_work_reports_delete_own_or_admin ON public.pb_work_reports;
DROP POLICY IF EXISTS pb_work_reports_select ON public.pb_work_reports;
DROP POLICY IF EXISTS pb_work_reports_insert ON public.pb_work_reports;
DROP POLICY IF EXISTS pb_work_reports_update ON public.pb_work_reports;
DROP POLICY IF EXISTS pb_work_reports_delete ON public.pb_work_reports;

CREATE POLICY pb_work_reports_select
  ON public.pb_work_reports FOR SELECT
  TO authenticated
  USING (
    public.pb_current_user_can_see_all_reports()
    OR (
      public.pb_current_employee_id() IS NOT NULL
      AND employee_id IS NOT DISTINCT FROM public.pb_current_employee_id()
    )
  );

CREATE POLICY pb_work_reports_insert
  ON public.pb_work_reports FOR INSERT
  TO authenticated
  WITH CHECK (
    public.pb_current_user_can_see_all_reports()
    OR (
      public.pb_can_edit_tasks()
      AND public.pb_current_employee_id() IS NOT NULL
      AND employee_id IS NOT DISTINCT FROM public.pb_current_employee_id()
    )
  );

CREATE POLICY pb_work_reports_update
  ON public.pb_work_reports FOR UPDATE
  TO authenticated
  USING (
    public.pb_current_user_can_see_all_reports()
    OR (
      public.pb_current_employee_id() IS NOT NULL
      AND employee_id IS NOT DISTINCT FROM public.pb_current_employee_id()
    )
  )
  WITH CHECK (
    public.pb_current_user_can_see_all_reports()
    OR (
      public.pb_current_employee_id() IS NOT NULL
      AND employee_id IS NOT DISTINCT FROM public.pb_current_employee_id()
    )
  );

CREATE POLICY pb_work_reports_delete
  ON public.pb_work_reports FOR DELETE
  TO authenticated
  USING (
    public.current_user_is_admin()
    OR (
      public.pb_current_employee_id() IS NOT NULL
      AND employee_id IS NOT DISTINCT FROM public.pb_current_employee_id()
    )
  );

COMMENT ON POLICY pb_work_reports_select ON public.pb_work_reports IS
  'PB4: inženjer vidi samo svoje; admin / leadpm / pm / menadzment / Rukovodstvo inž. vide sve.';

-- ── RPC agregat
CREATE OR REPLACE FUNCTION public.pb_get_work_report_summary(
  p_date_from date,
  p_date_to date,
  p_employee_id uuid DEFAULT NULL
)
RETURNS TABLE (
  employee_id uuid,
  full_name text,
  report_count integer,
  total_hours numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id AS employee_id,
    e.full_name,
    COUNT(wr.id)::integer AS report_count,
    COALESCE(SUM(wr.sati), 0)::numeric AS total_hours
  FROM public.pb_work_reports wr
  INNER JOIN public.employees e ON e.id = wr.employee_id
  WHERE wr.datum BETWEEN p_date_from AND p_date_to
    AND (
      public.pb_current_user_can_see_all_reports()
      OR wr.employee_id IS NOT DISTINCT FROM public.pb_current_employee_id()
    )
    AND (
      p_employee_id IS NULL
      OR wr.employee_id = p_employee_id
    )
  GROUP BY e.id, e.full_name
  ORDER BY total_hours DESC;
END;
$$;

COMMENT ON FUNCTION public.pb_get_work_report_summary(date, date, uuid) IS
  'PB4 — agregat izveštaja sati po zaposlenom u periodu (isti vid kao RLS).';

REVOKE ALL ON FUNCTION public.pb_get_work_report_summary(date, date, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_get_work_report_summary(date, date, uuid) TO authenticated;
