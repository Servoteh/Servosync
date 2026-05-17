-- Sprint 4.0b-priprema: KPI active_employees po istom scope-u kao ostali brojevi;
-- mini_reports donut — admin/HR/menadžment pun obim: agregat po sektoru (employees.department);
-- menadžment sužen: agregat po imenu pododeljenja (sub_departments.name).
--
-- Depends: update_dashboard_rpcs_for_sub_dept_scope.sql
-- Idempotentno: CREATE OR REPLACE.

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
  v_managed_ids int[] := public.current_user_managed_sub_department_ids();
  -- Prazan niz iz kolone/ORM ponaša se kao „nema liste“: isto što i SQL NULL za pun obim.
  v_managed_eff int[] := nullif(v_managed_ids, array[]::int[]);
  v_no_scope boolean := v_is_admin OR v_is_hr OR (v_is_menadzment AND v_managed_eff is null);
BEGIN
  RETURN jsonb_build_object(
    'year', v_year,
    'month', v_month,
    'scope_kind', (
      case
        when v_is_admin then 'admin'
        when v_is_hr then 'hr'
        when v_is_menadzment and v_managed_eff is null then 'menadzment_full'
        when v_is_menadzment then 'menadzment_scoped'
        else 'viewer'
      end
    ),
    'managed_sub_department_ids', to_jsonb(v_managed_eff),
    'active_employees', (
      select count(*)::int
      from public.employees e
      where e.is_active is true
        and (v_no_scope or e.sub_department_id = any (v_managed_eff))
    ),
    'on_absence_today', (
      select count(distinct a.employee_id)::int
      from public.absences a
      join public.employees e on e.id = a.employee_id
      where a.date_from <= v_today
        and a.date_to >= v_today
        and e.is_active is true
        and (v_no_scope or e.sub_department_id = any (v_managed_eff))
    ),
    'pending_vac_requests', (
      select count(*)::int
      from public.vacation_requests vr
      join public.employees e on e.id = vr.employee_id
      where vr.status = 'pending'
        and e.is_active is true
        and (v_no_scope or e.sub_department_id = any (v_managed_eff))
    ),
    'grid_fill_percent', (
      with active_emps as (
        select e.id
        from public.employees e
        where e.is_active is true
          and (v_no_scope or e.sub_department_id = any (v_managed_eff))
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
  'JSON KPI: svi brojevi po istom scope-u (admin/HR/menadžment pun obim vs managed_sub_department_ids).';

REVOKE ALL ON FUNCTION public.kadr_dashboard_kpis(int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kadr_dashboard_kpis(int, int) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.kadr_dashboard_mini_reports(
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
  v_year int := COALESCE(p_year, EXTRACT(year FROM CURRENT_DATE)::int);
  v_month int := COALESCE(p_month, EXTRACT(month FROM CURRENT_DATE)::int);
  v_month_start date := make_date(v_year, v_month, 1);
  v_month_end date := (v_month_start + INTERVAL '1 month' - INTERVAL '1 day')::date;
  v_managed_ids int[] := public.current_user_managed_sub_department_ids();
  v_managed_eff int[] := nullif(v_managed_ids, array[]::int[]);
  v_is_admin boolean := public.current_user_is_admin();
  v_is_hr boolean := public.current_user_is_hr();
  v_is_menadzment boolean := EXISTS (
    SELECT 1
    FROM public.user_roles ur
    WHERE lower(ur.email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
      AND ur.role = 'menadzment'
      AND ur.is_active IS TRUE
  );
  v_no_scope boolean := v_is_admin OR v_is_hr OR (v_is_menadzment AND v_managed_eff IS NULL);
  v_allow boolean := v_is_admin OR v_is_hr OR v_is_menadzment;
BEGIN
  RETURN jsonb_build_object(
    'year', v_year,
    'month', v_month,
    'scope_kind', CASE
      WHEN v_is_admin THEN 'admin'
      WHEN v_is_hr THEN 'hr'
      WHEN v_is_menadzment AND v_managed_eff IS NULL THEN 'menadzment_full'
      WHEN v_is_menadzment THEN 'menadzment_scoped'
      ELSE 'no_access'
    END,
    'managed_sub_department_ids', to_jsonb(v_managed_eff),
    'employees_by_department', CASE
      WHEN NOT v_allow THEN '[]'::jsonb
      WHEN v_no_scope THEN COALESCE((
        SELECT jsonb_agg(
                 jsonb_build_object('department', dept, 'count', cnt)
                 ORDER BY cnt DESC
               )
        FROM (
          SELECT
            COALESCE(e.department, 'Bez odeljenja') AS dept,
            COUNT(*)::int AS cnt
          FROM public.employees e
          WHERE e.is_active IS TRUE
          GROUP BY 1
        ) t
      ), '[]'::jsonb)
      ELSE COALESCE((
        SELECT jsonb_agg(
                 jsonb_build_object('department', dept, 'count', cnt)
                 ORDER BY cnt DESC
               )
        FROM (
          SELECT
            COALESCE(sd.name, 'Bez pododeljenja') AS dept,
            COUNT(*)::int AS cnt
          FROM public.employees e
          LEFT JOIN public.sub_departments sd ON sd.id = e.sub_department_id
          WHERE e.is_active IS TRUE
            AND e.sub_department_id = ANY (v_managed_eff)
          GROUP BY COALESCE(sd.name, 'Bez pododeljenja')
        ) t
      ), '[]'::jsonb)
    END,
    'hours_per_day', CASE
      WHEN NOT v_allow THEN '[]'::jsonb
      ELSE COALESCE((
        SELECT jsonb_agg(
                 jsonb_build_object(
                   'date', to_char(days.day_d, 'YYYY-MM-DD'),
                   'hours', COALESCE(daily.hrs, 0)
                 )
                 ORDER BY days.day_d
               )
        FROM (
          SELECT (g.d)::date AS day_d
          FROM generate_series(v_month_start, v_month_end, INTERVAL '1 day') AS g(d)
        ) days
        LEFT JOIN (
          SELECT wh.work_date, SUM(wh.hours)::numeric(8, 2) AS hrs
          FROM public.work_hours wh
          JOIN public.employees e ON e.id = wh.employee_id
          WHERE wh.work_date >= v_month_start
            AND wh.work_date <= v_month_end
            AND e.is_active IS TRUE
            AND (v_no_scope OR e.sub_department_id = ANY (v_managed_eff))
          GROUP BY wh.work_date
        ) daily ON daily.work_date = days.day_d
      ), '[]'::jsonb)
    END,
    'absences_by_type', CASE
      WHEN NOT v_allow THEN '[]'::jsonb
      ELSE COALESCE((
        SELECT jsonb_agg(
                 jsonb_build_object('type', a_type, 'days', a_days)
                 ORDER BY a_days DESC
               )
        FROM (
          SELECT
            a.type AS a_type,
            SUM(a.days_count)::int AS a_days
          FROM public.absences a
          JOIN public.employees e ON e.id = a.employee_id
          WHERE a.date_from <= v_month_end
            AND a.date_to >= v_month_start
            AND e.is_active IS TRUE
            AND (v_no_scope OR e.sub_department_id = ANY (v_managed_eff))
          GROUP BY a.type
          HAVING SUM(a.days_count) > 0
        ) t
      ), '[]'::jsonb)
    END
  );
END;
$$;

COMMENT ON FUNCTION public.kadr_dashboard_mini_reports(int, int) IS
  'Mini izveštaji: pun obim → donut po employees.department; sužen menadžment → po sub_departments.name.';

REVOKE ALL ON FUNCTION public.kadr_dashboard_mini_reports(int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kadr_dashboard_mini_reports(int, int) TO authenticated, service_role;
