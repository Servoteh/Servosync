-- PP-F DRAFT — NE POKRETATI bez odobrenja (performanse na cache tabeli).
--
-- Predlog A: posle INSERT/UPDATE started_at na bigtehn_tech_routing_cache,
-- uskladi production_overlays.local_status sa 'in_progress' osim ako je 'blocked'.

CREATE OR REPLACE FUNCTION public.pp_sync_local_status_from_tech_start()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
DECLARE
  lid bigint;
BEGIN
  IF NEW.started_at IS NULL THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE'
     AND NEW.started_at IS NOT DISTINCT FROM OLD.started_at THEN
    RETURN NEW;
  END IF;

  SELECT l.id INTO lid
  FROM public.bigtehn_work_order_lines_cache l
  WHERE l.work_order_id = NEW.work_order_id
    AND l.operacija = NEW.operacija
  ORDER BY l.id
  LIMIT 1;

  IF lid IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.production_overlays (
    work_order_id,
    line_id,
    local_status,
    created_by,
    updated_by
  )
  VALUES (
    NEW.work_order_id,
    lid,
    'in_progress',
    'bridge:tech_routing',
    'bridge:tech_routing'
  )
  ON CONFLICT (work_order_id, line_id) DO UPDATE SET
    local_status = CASE
      WHEN production_overlays.local_status = 'blocked' THEN production_overlays.local_status
      ELSE 'in_progress'
    END,
    updated_by = 'bridge:tech_routing',
    updated_at = now();

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.pp_sync_local_status_from_tech_start() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pp_sync_local_status_from_tech_start() TO service_role;

-- DROP TRIGGER IF EXISTS tr_pp_sync_status_from_routing ON public.bigtehn_tech_routing_cache;
-- CREATE TRIGGER tr_pp_sync_status_from_routing
--   AFTER INSERT OR UPDATE OF started_at ON public.bigtehn_tech_routing_cache
--   FOR EACH ROW
--   EXECUTE FUNCTION public.pp_sync_local_status_from_tech_start();

-- NOTIFY pgrst, 'reload schema';
