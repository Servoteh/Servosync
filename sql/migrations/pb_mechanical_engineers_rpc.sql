-- ═══════════════════════════════════════════════════════════════════════════
-- PB — lista inženjera za filter čipove (Mašinsko projektovanje / legacy tekst)
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
    )
  ORDER BY e.full_name ASC;
$$;

COMMENT ON FUNCTION public.pb_get_mechanical_projecting_engineers() IS
  'Projektni biro — aktivni zaposleni iz Mašinskog projektovanja (filter čipovi / dodela)';

REVOKE ALL ON FUNCTION public.pb_get_mechanical_projecting_engineers() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_get_mechanical_projecting_engineers() TO authenticated;
