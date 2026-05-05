-- ═══════════════════════════════════════════════════════════════════════════
-- PB — lista inženjera za filter čipove
-- Uključuje: Mašinsko projektovanje + PM tim (Projekti) + imenovani zaposleni
-- Isti predikat kao pb_get_load_stats u pb_load_stats_mechanical_engineering.sql
-- ═══════════════════════════════════════════════════════════════════════════

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
      -- 4. LEAD PM / PM — legacy position text fallback (position_id nije set)
      OR (
        e.position_id IS NULL
        AND lower(trim(coalesce(e.position, ''))) IN ('lead pm', 'pm', 'projekt menadžer')
        AND (
          e.department_id = (SELECT id FROM public.departments WHERE name = 'Projekti' LIMIT 1)
          OR lower(trim(coalesce(e.department, ''))) LIKE '%projekt%'
        )
      )
      -- 5. Imenički dodati zaposleni (bez obzira na org strukturu)
      OR lower(trim(e.full_name)) IN (
        'milorad jerotić',
        'milorad jerotic',
        'slaviša radosavljević',
        'slavisa radosavljevic',
        'igor voštić',
        'igor vostic'
      )
    )
  ORDER BY e.full_name ASC;
$$;

COMMENT ON FUNCTION public.pb_get_mechanical_projecting_engineers() IS
  'Projektni biro — aktivni zaposleni: Mašinsko projektovanje + PM tim (LEAD PM/PM) + imenički dodati';

REVOKE ALL ON FUNCTION public.pb_get_mechanical_projecting_engineers() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_get_mechanical_projecting_engineers() TO authenticated;
