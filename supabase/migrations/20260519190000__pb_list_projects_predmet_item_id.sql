-- pb_list_projects: + predmet_item_id za sort po Top prioritetu (get_predmet_plan_prioritet_ids) na klijentu.

DROP FUNCTION IF EXISTS public.pb_list_projects();

CREATE FUNCTION public.pb_list_projects()
RETURNS TABLE (
  id uuid,
  project_code text,
  project_name text,
  status text,
  predmet_item_id integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
  SELECT p.id, p.project_code, p.project_name, p.status, p.bigtehn_item_id AS predmet_item_id
  FROM public.projects p
  INNER JOIN production.predmet_aktivacija pa ON pa.predmet_item_id = p.bigtehn_item_id
  WHERE p.bigtehn_item_id IS NOT NULL
    AND pa.je_aktivan IS TRUE
    AND pa.je_projektovanje_montaza IS TRUE
  ORDER BY p.project_code ASC NULLS LAST, p.project_name ASC;
$$;

COMMENT ON FUNCTION public.pb_list_projects() IS
  'Projektni biro / Plan montaže: lista projekata po aktivacija + predmet_item_id za prioritet sort u aplikaciji.';
