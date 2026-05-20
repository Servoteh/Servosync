-- ============================================================================
-- SASTANCI — dashboard KPI counts (Sprint 3)
-- ============================================================================
-- SECURITY INVOKER: brojevi poštuju RLS vidljivosti pozivaoca.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sast_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_today date := current_date;
  v_in14  date := current_date + 14;
BEGIN
  RETURN jsonb_build_object(
    'sastanc_upcoming', (
      SELECT count(*)::int
      FROM public.sastanci s
      WHERE s.status = 'planiran'
        AND s.datum >= v_today
        AND s.datum <= v_in14
    ),
    'sastanc_u_toku', (
      SELECT count(*)::int
      FROM public.sastanci s
      WHERE s.status = 'u_toku'
    ),
    'akcije_otvoreno', (
      SELECT count(*)::int
      FROM public.v_akcioni_plan v
      WHERE v.effective_status IN ('otvoren', 'u_toku', 'kasni')
    ),
    'akcije_kasni', (
      SELECT count(*)::int
      FROM public.v_akcioni_plan v
      WHERE v.effective_status = 'kasni'
    ),
    'pm_teme_na_cekanju', (
      SELECT count(*)::int
      FROM public.pm_teme t
      WHERE t.status = 'predlog'
    )
  );
END;
$$;

COMMENT ON FUNCTION public.sast_dashboard_stats() IS
  'KPI brojevi za Sastanci Pregled tab; RLS-filtered counts.';

REVOKE ALL ON FUNCTION public.sast_dashboard_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sast_dashboard_stats() TO authenticated;
