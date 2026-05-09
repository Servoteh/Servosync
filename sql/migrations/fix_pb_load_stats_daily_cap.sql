-- ═══════════════════════════════════════════════════════════════════════════
-- PB — Fix: Opterećenost se računa dan-po-dan sa 7h cap-om PO DANU (ne po zadatku)
-- ═══════════════════════════════════════════════════════════════════════════
-- Razlog promene:
--   Prethodna verzija (pb_load_stats_mechanical_engineering.sql) primjenjuje
--   LEAST(t.norma_sati_dan, 7) per zadatak, pa zbira po danima zadatka. Ako
--   inženjer ima 2 zadatka po 4h istog dana, formula vraća 8h za taj dan,
--   što daje >100% pri kompletno popunjenom prozoru.
--
-- Nova semantika (po specifikaciji korisnika):
--   • window_days = broj RADNIH dana (default 20), ne kalendarskih.
--   • Za svaki radni dan u prozoru, sumira se norma_sati_dan svih AKTIVNIH
--     zadataka koji aktivni tog dana (datum_pocetka_plan ≤ day ≤ datum_zavrsetka_plan).
--   • Day-hours je cap-ovan na 7h pre ukupnog zbira → ako su 4+4 = 8 isti dan,
--     broji se samo 7h.
--   • 100% = svaki radni dan u prozoru popunjen do 7h (n_days × 7).
--   • Ako inženjer nema zadatke → load_pct = 0.
--
-- Status filter: t.status <> 'Završeno' (Pregled i Blokirano se i dalje
-- računaju kao opterećenje — angažovani su).
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.pb_get_load_stats(window_days INTEGER DEFAULT 20)
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
  WITH RECURSIVE
  workday_window AS (
    -- Generišemo dovoljno kalendarskih dana da pokupimo window_days radnih.
    -- 60 kalendarskih dana ≥ 40 radnih, što je dovoljan headroom za window_days do 40.
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
        -- 1. Mašinsko projektovanje (via sub_department FK)
        EXISTS (
          SELECT 1
          FROM public.sub_departments sd
          INNER JOIN public.departments d ON d.id = sd.department_id
          WHERE sd.id = e.sub_department_id
            AND d.name = 'Inženjering i projektovanje'
            AND sd.name = 'Mašinsko projektovanje'
        )
        -- 1b. Mašinsko projektovanje — legacy text fallback
        OR (
          e.sub_department_id IS NULL
          AND (
            lower(trim(coalesce(e.department, ''))) LIKE '%mašinsko%'
            OR lower(trim(coalesce(e.department, ''))) LIKE '%masinski%'
          )
          AND lower(trim(coalesce(e.department, ''))) LIKE '%projektovanje%'
        )
        -- 2. PM tim (Projekti departman) — via sub_department FK
        OR EXISTS (
          SELECT 1
          FROM public.sub_departments sd2
          INNER JOIN public.departments d2 ON d2.id = sd2.department_id
          WHERE sd2.id = e.sub_department_id
            AND d2.name = 'Projekti'
            AND sd2.name = 'PM tim'
        )
        -- 3. LEAD PM / Projekt menadžer — via position_id FK
        OR EXISTS (
          SELECT 1
          FROM public.job_positions jp
          INNER JOIN public.departments d3 ON d3.id = jp.department_id
          WHERE jp.id = e.position_id
            AND d3.name = 'Projekti'
            AND jp.name IN ('LEAD PM', 'Projekt menadžer')
        )
        -- 4. LEAD PM / PM — legacy position text fallback
        OR (
          e.position_id IS NULL
          AND lower(trim(coalesce(e.position, ''))) IN ('lead pm', 'pm', 'projekt menadžer')
          AND (
            e.department_id = (SELECT id FROM public.departments WHERE name = 'Projekti' LIMIT 1)
            OR lower(trim(coalesce(e.department, ''))) LIKE '%projekt%'
          )
        )
        -- 5. Imenički dodati zaposleni
        OR lower(trim(e.full_name)) IN (
          'milorad jerotić',
          'milorad jerotic',
          'slaviša radosavljević',
          'slavisa radosavljevic',
          'igor voštić',
          'igor vostic'
        )
      )
  ),
  per_day AS (
    -- Po danu i zaposlenom: sumiraj norma_sati_dan svih aktivnih zadataka koji
    -- pokrivaju taj dan. LEFT JOIN da bi i zaposleni bez zadataka imali 0 redove.
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

REVOKE ALL ON FUNCTION public.pb_get_load_stats(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_get_load_stats(INTEGER) TO authenticated;
