-- ═══════════════════════════════════════════════════════════════════════════
-- Kadrovska — striktan HR helper za RLS (Faza 2.2 šablon)
--
-- current_user_is_hr_or_admin() u add_menadzment_full_edit_kadrovska.sql uključuje
-- i menadzment. Za politike koje moraju biti „samo HR (i posebno admin)” koristiti
-- current_user_is_admin() OR current_user_is_hr().
--
-- Šablon za write scope sa menadžmentom po odeljenju (posle extend_kadr_*):
--   USING (
--     public.current_user_is_admin()
--     OR public.current_user_is_hr()
--     OR (public.has_edit_role() AND public.current_user_manages_employee(employee_id))
--   )
--
-- Depends: user_roles, auth.jwt() (Supabase), opciono extend_kadr_managed_departments_scope.sql
--   za current_user_manages_employee().
-- Idempotentno.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.current_user_is_hr()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      AND role = 'hr'
      AND is_active IS TRUE
  );
$$;

REVOKE ALL ON FUNCTION public.current_user_is_hr() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_is_hr() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_hr() TO service_role;

COMMENT ON FUNCTION public.current_user_is_hr() IS
  'Striktno hr rola. Ne uključuje menadžment niti admina. Koristi se kad '
  'current_user_is_hr_or_admin() ne odgovara (jer ta funkcija u ovoj bazi '
  'uključuje i menadžment — vidi add_menadzment_full_edit_kadrovska.sql). '
  'TODO Faza 2: preimenovati current_user_is_hr_or_admin u tačnije ime.';

-- ═══════════════════════════════════════════════════════════════════════════
-- Faza 2.2 — write RLS: menadžment samo u managed_departments scope-u
--
-- Preduslov: extend_kadr_managed_departments_scope.sql (current_user_manages_employee).
-- NE dira: SELECT politike, employee_children, vr_select / vr_update / vr_delete,
--   salary_*, kadr_holidays, kadr_notification_*.
--
-- ┌── Rollback referenca: pre-22 politike (snapshot Audit 3; pun tekst u
-- │   docs/migration/kadrovska/02e-pre-22-policies.sql kad postoji).
-- │
-- │   absences / work_hours / contracts (add_kadrovska_phase1.sql):
-- │     INSERT/UPDATE WITH CHECK (has_edit_role());
-- │     UPDATE USING (has_edit_role());
-- │     DELETE USING (has_edit_role());
-- │
-- │   vacation_entitlements (add_kadr_employee_extended.sql):
-- │     INSERT WITH CHECK (has_edit_role());
-- │     UPDATE USING (has_edit_role()) WITH CHECK (has_edit_role());
-- │     DELETE USING (has_edit_role());
-- │
-- │   employees (add_kadrovska_module.sql):
-- │     INSERT WITH CHECK (has_edit_role());
-- │     UPDATE USING (has_edit_role()) WITH CHECK (has_edit_role());
-- │     DELETE USING (has_edit_role());
-- │
-- │   vacation_requests.vr_insert (add_kadr_vacation_requests.sql):
-- │     WITH CHECK (lower(submitted_by) = lower(auth.jwt() ->> 'email'));
-- └──
--
-- Napomena (employees UPDATE): umesto odvojenog helpera current_user_manages_department,
-- koristi se current_user_manages_employee(id) — id je PK reda u employees, ista semantika
-- department scope-a unutar postojeće funkcije.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── absences ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "absences_insert" ON public.absences;
DROP POLICY IF EXISTS "absences_update" ON public.absences;
DROP POLICY IF EXISTS "absences_delete" ON public.absences;

CREATE POLICY "absences_insert" ON public.absences
  FOR INSERT TO authenticated
  WITH CHECK (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );

CREATE POLICY "absences_update" ON public.absences
  FOR UPDATE TO authenticated
  USING (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  )
  WITH CHECK (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );

CREATE POLICY "absences_delete" ON public.absences
  FOR DELETE TO authenticated
  USING (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );

-- ── work_hours ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "work_hours_insert" ON public.work_hours;
DROP POLICY IF EXISTS "work_hours_update" ON public.work_hours;
DROP POLICY IF EXISTS "work_hours_delete" ON public.work_hours;

CREATE POLICY "work_hours_insert" ON public.work_hours
  FOR INSERT TO authenticated
  WITH CHECK (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );

CREATE POLICY "work_hours_update" ON public.work_hours
  FOR UPDATE TO authenticated
  USING (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  )
  WITH CHECK (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );

CREATE POLICY "work_hours_delete" ON public.work_hours
  FOR DELETE TO authenticated
  USING (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );

-- ── vacation_entitlements ──────────────────────────────────────────────────
DROP POLICY IF EXISTS "vac_ent_insert" ON public.vacation_entitlements;
DROP POLICY IF EXISTS "vac_ent_update" ON public.vacation_entitlements;
DROP POLICY IF EXISTS "vac_ent_delete" ON public.vacation_entitlements;

CREATE POLICY "vac_ent_insert" ON public.vacation_entitlements
  FOR INSERT TO authenticated
  WITH CHECK (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );

CREATE POLICY "vac_ent_update" ON public.vacation_entitlements
  FOR UPDATE TO authenticated
  USING (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  )
  WITH CHECK (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );

CREATE POLICY "vac_ent_delete" ON public.vacation_entitlements
  FOR DELETE TO authenticated
  USING (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );

-- ── contracts ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "contracts_insert" ON public.contracts;
DROP POLICY IF EXISTS "contracts_update" ON public.contracts;
DROP POLICY IF EXISTS "contracts_delete" ON public.contracts;

CREATE POLICY "contracts_insert" ON public.contracts
  FOR INSERT TO authenticated
  WITH CHECK (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );

CREATE POLICY "contracts_update" ON public.contracts
  FOR UPDATE TO authenticated
  USING (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  )
  WITH CHECK (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );

CREATE POLICY "contracts_delete" ON public.contracts
  FOR DELETE TO authenticated
  USING (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );

-- ── employees — menadžment ne INSERT / ne DELETE ─────────────────────────
DROP POLICY IF EXISTS "employees_insert" ON public.employees;
DROP POLICY IF EXISTS "employees_update" ON public.employees;
DROP POLICY IF EXISTS "employees_delete" ON public.employees;

CREATE POLICY "employees_insert" ON public.employees
  FOR INSERT TO authenticated
  WITH CHECK (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
  );

CREATE POLICY "employees_update" ON public.employees
  FOR UPDATE TO authenticated
  USING (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(id)
    )
  )
  WITH CHECK (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(id)
    )
  );

CREATE POLICY "employees_delete" ON public.employees
  FOR DELETE TO authenticated
  USING (
    public.current_user_is_admin()
    OR public.current_user_is_hr()
  );

-- ── vacation_requests — samo vr_insert (ostalo u extend_kadr_*) ───────────
DROP POLICY IF EXISTS vr_insert ON public.vacation_requests;

CREATE POLICY vr_insert ON public.vacation_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    lower(submitted_by) = lower(coalesce(auth.jwt() ->> 'email', ''))
    OR public.current_user_is_admin()
    OR public.current_user_is_hr()
    OR (
      public.has_edit_role()
      AND public.current_user_manages_employee(employee_id)
    )
  );
