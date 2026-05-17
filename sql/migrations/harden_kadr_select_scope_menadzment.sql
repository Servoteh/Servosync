-- Kadrovska — SELECT scope: menadžment vidi samo zaposlene koje pokriva
-- current_user_manages_employee (isto kao write RLS i KPI/mini_reports).
-- Pre: employees / absences / work_hours / contracts / vacation_entitlements
-- SELECT je bio USING (true) za sve authenticated — menadžment je video ceo korpus.
--
-- Depends: refactor_managed_to_sub_department_ids.sql (current_user_manages_employee).

DROP POLICY IF EXISTS "employees_select" ON public.employees;
CREATE POLICY "employees_select" ON public.employees
  FOR SELECT TO authenticated
  USING (
    public.current_user_manages_employee(id)
    OR (
      lower(coalesce(email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
      AND coalesce(email, '') <> ''
    )
  );

DROP POLICY IF EXISTS "absences_select" ON public.absences;
CREATE POLICY "absences_select" ON public.absences
  FOR SELECT TO authenticated
  USING (
    public.current_user_manages_employee(employee_id)
    OR employee_id IN (
      SELECT e.id
      FROM public.employees AS e
      WHERE lower(coalesce(e.email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
        AND coalesce(e.email, '') <> ''
    )
  );

DROP POLICY IF EXISTS "work_hours_select" ON public.work_hours;
CREATE POLICY "work_hours_select" ON public.work_hours
  FOR SELECT TO authenticated
  USING (
    public.current_user_manages_employee(employee_id)
    OR employee_id IN (
      SELECT e.id
      FROM public.employees AS e
      WHERE lower(coalesce(e.email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
        AND coalesce(e.email, '') <> ''
    )
  );

DROP POLICY IF EXISTS "contracts_select" ON public.contracts;
CREATE POLICY "contracts_select" ON public.contracts
  FOR SELECT TO authenticated
  USING (
    public.current_user_manages_employee(employee_id)
    OR employee_id IN (
      SELECT e.id
      FROM public.employees AS e
      WHERE lower(coalesce(e.email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
        AND coalesce(e.email, '') <> ''
    )
  );

DROP POLICY IF EXISTS "vac_ent_select" ON public.vacation_entitlements;
CREATE POLICY "vac_ent_select" ON public.vacation_entitlements
  FOR SELECT TO authenticated
  USING (
    public.current_user_manages_employee(employee_id)
    OR employee_id IN (
      SELECT e.id
      FROM public.employees AS e
      WHERE lower(coalesce(e.email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
        AND coalesce(e.email, '') <> ''
    )
  );
