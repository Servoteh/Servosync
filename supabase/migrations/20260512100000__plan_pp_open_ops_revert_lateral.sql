-- LATERAL + line_candidates (Faza 1) je u praksi sporiji: za svaku liniju kandidata
-- planer ponovo ulazi u kompletan view-lanac i lako prekorači statement_timeout.
-- Jedan prolaz kroz v_production_operations_effective sa filterom effective_machine_code
-- ostaje ispravan i isproban; indeksi iz 20260511120000 ostaju.

CREATE OR REPLACE FUNCTION public.plan_pp_open_ops_for_machine(p_machine_code text)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO 'public'
SET statement_timeout TO '180s'
AS $$
DECLARE
  mc text;
BEGIN
  mc := btrim(p_machine_code);
  IF mc = '' THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT to_jsonb(e)
  FROM public.v_production_operations_effective e
  WHERE e.effective_machine_code = mc
    AND e.is_done_in_bigtehn IS FALSE
    AND e.rn_zavrsen IS FALSE
    AND e.is_cooperation_effective IS FALSE
    AND (e.local_status IS NULL OR e.local_status <> 'completed')
    AND e.overlay_archived_at IS NULL
  ORDER BY
    e.shift_sort_order ASC NULLS LAST,
    e.auto_sort_bucket ASC NULLS LAST,
    e.rok_izrade ASC NULLS LAST,
    e.prioritet_bigtehn ASC NULLS LAST
  LIMIT 2500;
END;
$$;

COMMENT ON FUNCTION public.plan_pp_open_ops_for_machine(text) IS
  'Plan proizvodnje: otvorene operacije po mašini (jsonb); jedan scan na v_production_operations_effective.';

GRANT EXECUTE ON FUNCTION public.plan_pp_open_ops_for_machine(text) TO authenticated;
REVOKE ALL ON FUNCTION public.plan_pp_open_ops_for_machine(text) FROM PUBLIC;

NOTIFY pgrst, 'reload schema';
