-- PB Saveti: pisanje uskladiti sa pb_can_edit_tasks (admin, menadzment, pm, leadpm, hr + inženjeri liste)
BEGIN;

CREATE OR REPLACE FUNCTION public.can_write_pb_eng_tips()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    public.pb_can_edit_tasks()
    OR EXISTS (
      SELECT 1
      FROM public.pb_get_mechanical_projecting_engineers() eng
      WHERE eng.id IS NOT DISTINCT FROM public.pb_current_employee_id()
    );
$$;

COMMENT ON FUNCTION public.can_write_pb_eng_tips() IS
  'PB Saveti — pisanje: pb_can_edit_tasks() ili inženjer iz pb_get_mechanical_projecting_engineers().';

NOTIFY pgrst, 'reload schema';

COMMIT;
