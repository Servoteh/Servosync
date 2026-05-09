-- PB: Projektni biro — proširen predikat inženjera (Hidraulika + Rukovodstvo inž.)
-- Sinhrono sa sql/migrations/pb_mechanical_engineers_rpc.sql i pb_load_stats_mechanical_engineering.sql

CREATE OR REPLACE FUNCTION public.pb_get_mechanical_projecting_engineers()
RETURNS TABLE (
  id          UUID,
  full_name   TEXT,
  department  TEXT,
  email       TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT e.id, e.full_name, e.department, e.email
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
  ORDER BY e.full_name ASC;
$$;

COMMENT ON FUNCTION public.pb_get_mechanical_projecting_engineers() IS
  'Projektni biro — aktivni zaposleni: Mašinsko projektovanje + Hidraulika + Rukovodstvo inž. + PM tim (LEAD PM/PM) + imenički';

REVOKE ALL ON FUNCTION public.pb_get_mechanical_projecting_engineers() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_get_mechanical_projecting_engineers() TO authenticated;

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
  v_today     DATE := CURRENT_DATE;
  v_end       DATE := CURRENT_DATE + window_days;
  v_workdays  INTEGER;
BEGIN
  SELECT COUNT(*)::INTEGER INTO v_workdays
  FROM generate_series(v_today, v_end, '1 day'::interval) AS gs(d)
  WHERE EXTRACT(DOW FROM gs.d) NOT IN (0, 6);

  RETURN QUERY
  SELECT
    e.id AS employee_id,
    e.full_name,
    COALESCE(SUM(
      LEAST(t.norma_sati_dan, 7) *
      (
        SELECT COUNT(*)::INTEGER
        FROM generate_series(
          GREATEST(t.datum_pocetka_plan, v_today),
          LEAST(t.datum_zavrsetka_plan, v_end),
          '1 day'::interval
        ) AS gs2(d)
        WHERE EXTRACT(DOW FROM gs2.d) NOT IN (0, 6)
      )
    ), 0)::NUMERIC AS total_hours,
    (v_workdays * 7)::NUMERIC AS max_hours,
    CASE WHEN v_workdays * 7 > 0 THEN
      ROUND(
        COALESCE(SUM(
          LEAST(t.norma_sati_dan, 7) *
          (
            SELECT COUNT(*)::INTEGER
            FROM generate_series(
              GREATEST(t.datum_pocetka_plan, v_today),
              LEAST(t.datum_zavrsetka_plan, v_end),
              '1 day'::interval
            ) AS gs3(d)
            WHERE EXTRACT(DOW FROM gs3.d) NOT IN (0, 6)
          )
        ), 0) * 100 / (v_workdays * 7)
      )::INTEGER
    ELSE 0 END AS load_pct
  FROM public.employees e
  LEFT JOIN public.pb_tasks t ON
    t.employee_id = e.id
    AND t.status <> 'Završeno'::public.pb_task_status
    AND t.deleted_at IS NULL
    AND t.datum_pocetka_plan IS NOT NULL
    AND t.datum_zavrsetka_plan IS NOT NULL
    AND t.datum_zavrsetka_plan >= v_today
    AND t.datum_pocetka_plan <= v_end
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
  GROUP BY e.id, e.full_name
  ORDER BY load_pct DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.pb_get_load_stats(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_get_load_stats(INTEGER) TO authenticated;
