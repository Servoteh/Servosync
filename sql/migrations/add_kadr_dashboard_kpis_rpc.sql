-- Sprint 3.2: KPI za Kadrovska dashboard (scope-aware brojanje).
-- Zavisi od: current_user_is_admin, current_user_is_hr, current_user_managed_departments
--           (extend_kadr_managed_departments_scope.sql).
--
-- Semantika scope-a:
--   v_no_scope := admin OR hr OR (menadžment AND managed_departments IS NULL).
--   Viewer / PM / leadpm / ostali: NISU „pun obim“ samo zato što je managed_departments NULL
--   (funkcija vraća NULL i van menadžment uloge) — filter ostaje strogi (0 redova).

CREATE OR REPLACE FUNCTION public.kadr_dashboard_kpis(
  p_year int DEFAULT NULL,
  p_month int DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_year int := coalesce(p_year, extract(year from current_date)::int);
  v_month int := coalesce(p_month, extract(month from current_date)::int);
  v_month_start date := make_date(v_year, v_month, 1);
  v_month_end date := (v_month_start + interval '1 month' - interval '1 day')::date;
  v_today date := current_date;
  v_is_admin boolean := public.current_user_is_admin();
  v_is_hr boolean := public.current_user_is_hr();
  v_is_menadzment boolean := exists (
    select 1
    from public.user_roles ur
    where lower(ur.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and ur.role = 'menadzment'
      and ur.is_active is true
  );
  v_managed text[] := public.current_user_managed_departments();
  v_no_scope boolean := v_is_admin OR v_is_hr OR (v_is_menadzment AND v_managed is null);
BEGIN
  RETURN jsonb_build_object(
    'year', v_year,
    'month', v_month,
    'scope_kind', (
      case
        when v_is_admin then 'admin'
        when v_is_hr then 'hr'
        when v_is_menadzment and v_managed is null then 'menadzment_full'
        when v_is_menadzment then 'menadzment_scoped'
        else 'viewer'
      end
    ),
    'managed_departments', to_jsonb(v_managed),
    'active_employees', (
      select count(*)::int
      from public.employees e
      where e.is_active is true
        and (v_no_scope or e.department = any (v_managed))
    ),
    'on_absence_today', (
      select count(distinct a.employee_id)::int
      from public.absences a
      join public.employees e on e.id = a.employee_id
      where a.date_from <= v_today
        and a.date_to >= v_today
        and e.is_active is true
        and (v_no_scope or e.department = any (v_managed))
    ),
    'pending_vac_requests', (
      select count(*)::int
      from public.vacation_requests vr
      join public.employees e on e.id = vr.employee_id
      where vr.status = 'pending'
        and e.is_active is true
        and (v_no_scope or e.department = any (v_managed))
    ),
    'grid_fill_percent', (
      with active_emps as (
        select e.id
        from public.employees e
        where e.is_active is true
          and (v_no_scope or e.department = any (v_managed))
      ),
      wd as (
        select count(*)::numeric as n
        from generate_series(v_month_start, v_month_end, interval '1 day') g(dt)
        where extract(isodow from g.dt::date) < 6
      ),
      expected as (
        select
          (select count(*)::numeric from active_emps) * 8.0 * (select n from wd) as hrs
      ),
      actual as (
        select coalesce(sum(wh.hours), 0)::numeric as hrs
        from public.work_hours wh
        where wh.employee_id in (select id from active_emps)
          and wh.work_date >= v_month_start
          and wh.work_date <= v_month_end
      )
      select case
        when (select hrs from expected) = 0 then 0::numeric
        else round(
          (select hrs from actual) * 100.0 / (select hrs from expected),
          1
        )
      end
    )
  );
END
$$;

COMMENT ON FUNCTION public.kadr_dashboard_kpis(int, int) IS
  'JSON KPI za Kadrovska Pregled: scope preko admin/HR/menadžment + managed_departments (NULL=legacy pun obim samo za menadžment).';

REVOKE ALL ON FUNCTION public.kadr_dashboard_kpis(int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kadr_dashboard_kpis(int, int) TO authenticated, service_role;
