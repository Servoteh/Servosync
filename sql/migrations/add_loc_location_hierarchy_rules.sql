-- ============================================================================
-- LOKACIJE DELOVA — dijagnostika i pravila HALA -> POLICA
-- ============================================================================
-- Kompatibilno sa postojećim podacima: view prijavljuje stare nelogičnosti, a
-- trigger sprečava nove unose/izmene odnosa koji bi razbili dogovoreni model.

CREATE OR REPLACE VIEW public.loc_location_hierarchy_issues AS
SELECT
  child.id,
  child.location_code,
  child.name,
  child.location_type,
  child.parent_id,
  parent.location_code AS parent_location_code,
  parent.location_type AS parent_location_type,
  CASE
    WHEN child.location_type IN ('SHELF','RACK','BIN') AND child.parent_id IS NULL
      THEN 'shelf_without_hall'
    WHEN child.location_type IN ('SHELF','RACK','BIN')
      AND COALESCE(parent.location_type::text, '') NOT IN ('WAREHOUSE','PRODUCTION','ASSEMBLY','FIELD','TEMP')
      THEN 'shelf_parent_not_hall'
    WHEN child.location_type IN ('WAREHOUSE','PRODUCTION','ASSEMBLY','FIELD','TEMP') AND child.parent_id IS NOT NULL
      THEN 'hall_has_parent'
    ELSE 'ok'
  END AS issue
FROM public.loc_locations AS child
LEFT JOIN public.loc_locations AS parent ON parent.id = child.parent_id
WHERE
  (child.location_type IN ('SHELF','RACK','BIN') AND child.parent_id IS NULL)
  OR (
    child.location_type IN ('SHELF','RACK','BIN')
    AND COALESCE(parent.location_type::text, '') NOT IN ('WAREHOUSE','PRODUCTION','ASSEMBLY','FIELD','TEMP')
  )
  OR (
    child.location_type IN ('WAREHOUSE','PRODUCTION','ASSEMBLY','FIELD','TEMP')
    AND child.parent_id IS NOT NULL
  );

GRANT SELECT ON public.loc_location_hierarchy_issues TO authenticated;

CREATE OR REPLACE FUNCTION public.loc_locations_enforce_business_hierarchy()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_parent_type text;
BEGIN
  IF NEW.location_type IN ('WAREHOUSE','PRODUCTION','ASSEMBLY','FIELD','TEMP') AND NEW.parent_id IS NOT NULL THEN
    RAISE EXCEPTION 'loc_locations: HALA mora biti root lokacija (parent_id NULL)';
  END IF;

  IF NEW.location_type IN ('SHELF','RACK','BIN') THEN
    IF NEW.parent_id IS NULL THEN
      RAISE EXCEPTION 'loc_locations: POLICA mora imati roditeljsku HALU';
    END IF;

    SELECT location_type::text INTO v_parent_type
    FROM public.loc_locations
    WHERE id = NEW.parent_id;

    IF COALESCE(v_parent_type, '') NOT IN ('WAREHOUSE','PRODUCTION','ASSEMBLY','FIELD','TEMP') THEN
      RAISE EXCEPTION 'loc_locations: roditelj POLICE mora biti HALA';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS loc_locations_business_hierarchy_trg ON public.loc_locations;
CREATE TRIGGER loc_locations_business_hierarchy_trg
  BEFORE INSERT OR UPDATE OF location_type, parent_id ON public.loc_locations
  FOR EACH ROW EXECUTE FUNCTION public.loc_locations_enforce_business_hierarchy();
