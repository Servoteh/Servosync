-- ============================================================================
-- LOKACIJE DELOVA — STEP 2: case-insensitive UNIQUE na loc_locations.location_code
-- ============================================================================
-- Cilj: sprečiti operatersku grešku gde se `M1` i `m1` smatraju različitim
-- lokacijama. Stari indeks (case-sensitive) zamenjuje se funkcijskim unikatom
-- nad `lower(location_code)`.
--
-- Zavisi od: sql/migrations/add_loc_module.sql (Step 1).
--
-- Ako već postoje slučajevi sa različitom kombinacijom malih/velikih slova
-- (npr. `M1` i `m1`), CREATE UNIQUE INDEX će PUĆI. Prvi DO-blok detektuje
-- takve slučajeve pre nego što bacimo stari indeks i vraća jasnu grešku.
--
-- DOWN:
--   DROP INDEX IF EXISTS public.loc_locations_code_ci_uq;
--   CREATE UNIQUE INDEX IF NOT EXISTS loc_locations_code_uq
--     ON public.loc_locations (location_code);
-- ============================================================================

-- ── Predproveravanje duplikata po lower(location_code) ─────────────────────
DO $$
DECLARE
  v_dup_count INTEGER;
  v_example TEXT;
BEGIN
  SELECT COUNT(*), string_agg(DISTINCT lower(location_code), ', ')
    INTO v_dup_count, v_example
  FROM public.loc_locations
  GROUP BY lower(location_code)
  HAVING COUNT(*) > 1;

  IF v_dup_count IS NOT NULL AND v_dup_count > 0 THEN
    RAISE EXCEPTION
      'Postoje case-insensitive duplikati u loc_locations.location_code (npr. % ). Očisti ih ručno pre Step 2 migracije.',
      v_example;
  END IF;
END $$;

-- ── Idempotentno: skidanje starog case-sensitive indeksa ───────────────────
DROP INDEX IF EXISTS public.loc_locations_code_uq;

-- ── Novi case-insensitive UNIQUE ───────────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS loc_locations_code_ci_uq
  ON public.loc_locations (lower(location_code));

COMMENT ON INDEX public.loc_locations_code_ci_uq IS
  'Case-insensitive unikat nad location_code (zamenio loc_locations_code_uq).';
