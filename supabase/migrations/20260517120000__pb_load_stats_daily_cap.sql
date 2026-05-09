-- PB: pb_get_load_stats — cap 7h po RADNOM DANU (zbir normi po danu), ne po zadatku.
-- Predikat zaposlenih ostaje kao u 20260516120000__pb_extend_mechanical_engineers_predicate.sql.
-- window_days = broj radnih dana unapred od CURRENT_DATE (Supabase podrazumevano 30 kao ranije).

CREATE OR REPLACE FUNCTION public.pb_get_load_stats(window_days INTEGER DEFAULT 30)
RETURNS TABLE (
  employee_id   UUID,
  full_name     TEXT,
  total_hours   NUMERIC,
  max_hours     NUMERIC,
  load_pct      INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_today DATE := CURRENT_DATE;
BEGIN
  RETURN QUERY
  WITH
  workday_window AS (
    SELECT
      gs.d::date AS day,
      ROW_NUMBER() OVER (ORDER BY gs.d) AS rn
    FROM generate_series(v_today, v_today + (window_days * 2 + 14), '1 day'::interval) AS gs(d)
    WHERE EXTRACT(DOW FROM gs.d) NOT IN (0, 6)
  ),
  window_days_cte AS (
    SELECT day FROM workday_window WHERE rn <= window_days
  ),
  window_size AS (
    SELECT COUNT(*)::INTEGER AS n_days FROM window_days_cte
  ),
  candidate_employees AS (
    SELECT e.id AS employee_id, e.full_name
    FROM public.employees e
    WHERE e.is_active = TRUE
      AND (
        EXISTS (
          SELECT 1
          FROM public.sub_departments sd
          INNER JOIN public.departments d ON d.id = sd.department_id
          WHERE sd.id = e.sub_department_id
            AND d.name = 'Inženjering i projektovanje'
            AND sd.name = 'Mašinsko projektovanje'
        )
        OR (
          e.sub_department_id IS NULL
          AND (
            lower(trim(coalesce(e.department, ''))) LIKE '%mašinsko%'
            OR lower(trim(coalesce(e.department, ''))) LIKE '%masinski%'
          )
          AND lower(trim(coalesce(e.department, ''))) LIKE '%projektovanje%'
        )
        OR EXISTS (
          SELECT 1
          FROM public.sub_departments sd_ip
          INNER JOIN public.departments d_ip ON d_ip.id = sd_ip.department_id
          WHERE sd_ip.id = e.sub_department_id
            AND d_ip.name = 'Inženjering i projektovanje'
            AND sd_ip.name IN ('Hidraulika i algoritmi', 'Rukovodstvo inženjeringa')
        )
        OR EXISTS (
          SELECT 1
          FROM public.sub_departments sd2
          INNER JOIN public.departments d2 ON d2.id = sd2.department_id
          WHERE sd2.id = e.sub_department_id
            AND d2.name = 'Projekti'
            AND sd2.name = 'PM tim'
        )
        OR EXISTS (
          SELECT 1
          FROM public.job_positions jp
          INNER JOIN public.departments d3 ON d3.id = jp.department_id
          WHERE jp.id = e.position_id
            AND d3.name = 'Projekti'
            AND jp.name IN ('LEAD PM', 'Projekt menadžer')
        )
        OR (
          e.position_id IS NULL
          AND lower(trim(coalesce(e.position, ''))) IN ('lead pm', 'pm', 'projekt menadžer')
          AND (
            e.department_id = (SELECT id FROM public.departments WHERE name = 'Projekti' LIMIT 1)
            OR lower(trim(coalesce(e.department, ''))) LIKE '%projekt%'
          )
        )
        OR lower(trim(e.full_name)) IN (
          'milorad jerotić',
          'milorad jerotic',
          'slaviša radosavljević',
          'slavisa radosavljevic',
          'radosavljević slaviša',
          'radosavljevic slavisa',
          'radisavljević slaviša',
          'radisavljevic slavisa',
          'slaviša radisavljević',
          'igor voštić',
          'igor vostic',
          'voštić igor',
          'vostic igor',
          'gnjidić tatjana',
          'tatjana gnjidić'
        )
      )
  ),
  per_day AS (
    SELECT
      ce.employee_id,
      ce.full_name,
      w.day,
      COALESCE(SUM(t.norma_sati_dan), 0)::NUMERIC AS day_hours
    FROM candidate_employees ce
    CROSS JOIN window_days_cte w
    LEFT JOIN public.pb_tasks t ON
      t.employee_id = ce.employee_id
      AND t.status <> 'Završeno'::public.pb_task_status
      AND t.deleted_at IS NULL
      AND t.datum_pocetka_plan IS NOT NULL
      AND t.datum_zavrsetka_plan IS NOT NULL
      AND w.day BETWEEN t.datum_pocetka_plan AND t.datum_zavrsetka_plan
    GROUP BY ce.employee_id, ce.full_name, w.day
  ),
  per_employee AS (
    SELECT
      pd.employee_id,
      pd.full_name,
      SUM(LEAST(pd.day_hours, 7))::NUMERIC AS total_hours
    FROM per_day pd
    GROUP BY pd.employee_id, pd.full_name
  )
  SELECT
    pe.employee_id,
    pe.full_name,
    pe.total_hours,
    (ws.n_days * 7)::NUMERIC AS max_hours,
    CASE WHEN ws.n_days > 0
      THEN ROUND(pe.total_hours * 100.0 / (ws.n_days * 7))::INTEGER
      ELSE 0
    END AS load_pct
  FROM per_employee pe
  CROSS JOIN window_size ws
  ORDER BY load_pct DESC, pe.full_name;
END;
$$;

COMMENT ON FUNCTION public.pb_get_load_stats(INTEGER) IS
  'PB opterećenje: zbir normi po radnom danu, max 7h/dan; wb radnih dana; isti skup zaposlenih kao pb_get_mechanical_projecting_engineers + PM/LEAD PM.';

REVOKE ALL ON FUNCTION public.pb_get_load_stats(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_get_load_stats(INTEGER) TO authenticated;
