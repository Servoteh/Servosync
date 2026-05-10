-- ============================================================================
-- PROJEKTNI BIRO — pb_get_team_load_stats: agregat po pod-odeljenju
-- ============================================================================
-- Svrha:
--   Vraća prosek/min/max opterećenosti i broj članova po pod-odeljenju koje
--   učestvuje u Projektnom birou (ista mehanika kao pb_get_load_stats —
--   samo grupisana po sub_departments).
--
-- Zavisi od: public.pb_get_load_stats(INTEGER), public.sub_departments,
--             public.departments, public.employees.
--
-- DOWN:
--   DROP FUNCTION IF EXISTS public.pb_get_team_load_stats(INTEGER);
-- ============================================================================

CREATE OR REPLACE FUNCTION public.pb_get_team_load_stats(window_days INTEGER DEFAULT 20)
RETURNS TABLE (
  sub_department_id    INTEGER,
  sub_department_name  TEXT,
  department_name      TEXT,
  member_count         INTEGER,
  avg_load_pct         INTEGER,
  max_load_pct         INTEGER,
  total_hours          NUMERIC,
  max_hours            NUMERIC
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH per_emp AS (
    SELECT
      ls.employee_id,
      ls.load_pct,
      ls.total_hours,
      ls.max_hours,
      e.sub_department_id
    FROM public.pb_get_load_stats(window_days) ls
    JOIN public.employees e ON e.id = ls.employee_id
  )
  SELECT
    sd.id                                  AS sub_department_id,
    sd.name                                AS sub_department_name,
    d.name                                 AS department_name,
    COUNT(*)::INTEGER                      AS member_count,
    ROUND(AVG(pe.load_pct))::INTEGER       AS avg_load_pct,
    MAX(pe.load_pct)::INTEGER              AS max_load_pct,
    SUM(pe.total_hours)::NUMERIC           AS total_hours,
    SUM(pe.max_hours)::NUMERIC             AS max_hours
  FROM per_emp pe
  JOIN public.sub_departments sd ON sd.id = pe.sub_department_id
  JOIN public.departments d      ON d.id  = sd.department_id
  GROUP BY sd.id, sd.name, d.name
  ORDER BY avg_load_pct DESC NULLS LAST;
$$;

REVOKE ALL ON FUNCTION public.pb_get_team_load_stats(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_get_team_load_stats(INTEGER) TO authenticated;

-- Sanity: SELECT * FROM public.pb_get_team_load_stats(20);
