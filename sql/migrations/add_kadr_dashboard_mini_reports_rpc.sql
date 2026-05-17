-- Sprint 3.3: Kadrovska Pregled — mini izveštaji (Chart.js feed), scope-aware.
-- Pattern kao kadr_dashboard_kpis: admin/HR/menadžment; viewer/ostalo → no_access + prazni nizovi.

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
  v_managed text[] := public.current_user_managed_departments();
  v_is_admin boolean := public.current_user_is_admin();
  v_is_hr boolean := public.current_user_is_hr();
  v_is_menadzment boolean := EXISTS (
    SELECT 1
    FROM public.user_roles ur
    WHERE lower(ur.email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
      AND ur.role = 'menadzment'
      AND ur.is_active IS TRUE
  );
  v_no_scope boolean := v_is_admin OR v_is_hr OR (v_is_menadzment AND v_managed IS NULL);
  v_allow boolean := v_is_admin OR v_is_hr OR v_is_menadzment;
BEGIN
  RETURN jsonb_build_object(
    'year', v_year,
    'month', v_month,
    'scope_kind', CASE
      WHEN v_is_admin THEN 'admin'
      WHEN v_is_hr THEN 'hr'
      WHEN v_is_menadzment AND v_managed IS NULL THEN 'menadzment_full'
      WHEN v_is_menadzment THEN 'menadzment_scoped'
      ELSE 'no_access'
    END,
    'employees_by_department', CASE
      WHEN NOT v_allow THEN '[]'::jsonb
      ELSE COALESCE((
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
            AND (v_no_scope OR e.department = ANY (v_managed))
          GROUP BY 1
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
            AND (v_no_scope OR e.department = ANY (v_managed))
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
            AND (v_no_scope OR e.department = ANY (v_managed))
          GROUP BY a.type
          HAVING SUM(a.days_count) > 0
        ) t
      ), '[]'::jsonb)
    END
  );
END;
$$;

COMMENT ON FUNCTION public.kadr_dashboard_mini_reports(int, int) IS
  'Mini izveštaji za Kadrovska dashboard: donut/line/bar feed; scope kao KPI (viewer → prazan).';

REVOKE ALL ON FUNCTION public.kadr_dashboard_mini_reports(int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kadr_dashboard_mini_reports(int, int) TO authenticated, service_role;
