-- fix_kadr_trigger_weekly_risk_summary_sql_editor.sql
-- kadr_trigger_weekly_risk_summary() je za UI (JWT HR/admin). U Dashboard SQL Editoru
-- nema JWT-a — proširujemo dozvolu na superuser / postgres / supabase_admin.

CREATE OR REPLACE FUNCTION public.kadr_trigger_weekly_risk_summary()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
      public.current_user_is_hr()
      OR public.current_user_is_admin()
      OR session_user::text IN ('postgres', 'supabase_admin')
      OR EXISTS (
        SELECT 1 FROM pg_roles r
        WHERE r.rolname = session_user::name AND r.rolsuper
      )
  ) THEN
    RAISE EXCEPTION 'Access denied: HR or admin only';
  END IF;
  RETURN public.kadr_queue_weekly_risk_summary();
END;
$$;

COMMENT ON FUNCTION public.kadr_trigger_weekly_risk_summary() IS
  'UI wrapper: weekly risk summary; HR/admin preko JWT, ili superuser/postgres u SQL Editoru.';
