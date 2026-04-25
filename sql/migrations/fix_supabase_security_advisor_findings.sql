-- ============================================================================
-- SUPABASE SECURITY ADVISOR — hardening postojećih view-ova i funkcija
-- ============================================================================
-- Rešava stare Supabase advisor nalaze:
--   * security_definer_view: public view-ovi treba da rade kao invoker
--   * function_search_path_mutable: trigger funkcije treba da imaju fiksan
--     search_path da ne zavise od runtime search_path-a pozivaoca.
--
-- Bez promene poslovne logike.
-- ============================================================================

-- View hardening: Postgres 15+ podržava security_invoker za view-ove.
ALTER VIEW public.v_vacation_balance
  SET (security_invoker = true);

ALTER VIEW public.v_employee_current_salary
  SET (security_invoker = true);

ALTER VIEW public.v_employees_safe
  SET (security_invoker = true);

ALTER VIEW public.v_akcioni_plan
  SET (security_invoker = true);

ALTER VIEW public.loc_location_hierarchy_issues
  SET (security_invoker = true);

ALTER VIEW public.v_salary_payroll_month
  SET (security_invoker = true);

ALTER VIEW public.v_pm_teme_pregled
  SET (security_invoker = true);

-- Function hardening: schema-qualify lookup order and keep pg_temp last.
ALTER FUNCTION public.user_roles_set_updated_at()
  SET search_path = public, auth, pg_temp;

ALTER FUNCTION public.loc_touch_updated_at()
  SET search_path = public, auth, pg_temp;

ALTER FUNCTION public.touch_updated_at()
  SET search_path = public, auth, pg_temp;

ALTER FUNCTION public.loc_locations_after_path_change()
  SET search_path = public, auth, pg_temp;

ALTER FUNCTION public.salary_payroll_set_created_by()
  SET search_path = public, auth, pg_temp;

ALTER FUNCTION public.salary_payroll_compute_totals()
  SET search_path = public, auth, pg_temp;

ALTER FUNCTION public.salary_terms_set_created_by()
  SET search_path = public, auth, pg_temp;

ALTER FUNCTION public.salary_terms_close_previous()
  SET search_path = public, auth, pg_temp;

ALTER FUNCTION public.update_updated_at()
  SET search_path = public, auth, pg_temp;

ALTER FUNCTION public.loc_locations_guard_and_path()
  SET search_path = public, auth, pg_temp;

ALTER FUNCTION public.employees_sensitive_guard()
  SET search_path = public, auth, pg_temp;
