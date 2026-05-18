-- Soft delete preko RPC: UPDATE novog reda ne prolazi SELECT (deleted_at IS NULL).
-- SECURITY DEFINER (owner postgres) zaobilazi RLS na UPDATE; provera pb_can_edit_tasks() ostaje.

CREATE OR REPLACE FUNCTION public.pb_soft_delete_task(p_task_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text := COALESCE(auth.jwt() ->> 'email', '');
BEGIN
  IF p_task_id IS NULL THEN
    RAISE EXCEPTION 'task_id je obavezan' USING ERRCODE = '22023';
  END IF;
  IF NOT public.pb_can_edit_tasks() THEN
    RAISE EXCEPTION 'Nemate pravo da brišete zadatke' USING ERRCODE = '42501';
  END IF;

  UPDATE public.pb_tasks
  SET
    deleted_at = now(),
    updated_by = NULLIF(trim(v_email), '')
  WHERE id = p_task_id
    AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Zadatak nije pronađen ili je već obrisan' USING ERRCODE = 'P0002';
  END IF;
END;
$$;

COMMENT ON FUNCTION public.pb_soft_delete_task(uuid) IS
  'PB soft delete jednog zadatka; zaobilazi RLS SELECT ograničenje na novom redu.';

CREATE OR REPLACE FUNCTION public.pb_soft_delete_tasks(p_task_ids uuid[])
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text := COALESCE(auth.jwt() ->> 'email', '');
  v_n integer;
BEGIN
  IF p_task_ids IS NULL OR array_length(p_task_ids, 1) IS NULL THEN
    RETURN 0;
  END IF;
  IF NOT public.pb_can_edit_tasks() THEN
    RAISE EXCEPTION 'Nemate pravo da brišete zadatke' USING ERRCODE = '42501';
  END IF;

  UPDATE public.pb_tasks
  SET
    deleted_at = now(),
    updated_by = NULLIF(trim(v_email), '')
  WHERE id = ANY (p_task_ids)
    AND deleted_at IS NULL;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;

COMMENT ON FUNCTION public.pb_soft_delete_tasks(uuid[]) IS
  'PB batch soft delete; vraća broj obrisanih redova.';

REVOKE ALL ON FUNCTION public.pb_soft_delete_task(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pb_soft_delete_tasks(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_soft_delete_task(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pb_soft_delete_tasks(uuid[]) TO authenticated;
