-- ============================================================================
-- LOKACIJE × MAŠINE — Faza 1, Korak 1: proširi loc_type_enum sa 'MACHINE'
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru.
--
-- VAŽNO — zašto je ovo posebna migracija od `add_loc_machine_locations.sql`:
--   PostgreSQL ima ograničenje da `ALTER TYPE ... ADD VALUE` ne dozvoljava
--   korišćenje NOVE enum vrednosti u istoj transakciji u kojoj je dodata.
--   (Vidi PG dokumentaciju, sekcija ALTER TYPE: „The new value cannot be used
--    in the same transaction it was created in".)
--
--   Supabase SQL Editor svaki „Run" tretira kao jednu transakciju, pa
--   miks ALTER TYPE + INSERT sa nove vrednosti u JEDNOM fajlu PUCA:
--     ERROR: invalid input value for enum loc_type_enum: "MACHINE"
--
--   Rešenje: prvo se pokrene OVAJ fajl (samo ALTER TYPE), pa SE COMMIT-uje,
--   pa se onda pokrene `add_loc_machine_locations.sql` (seed iz cache-a).
--
-- DOWN: enum vrednosti se ne mogu drop-ovati u Postgres-u — ostaju doživotno.
-- ============================================================================

DO $enum$
BEGIN
  ALTER TYPE public.loc_type_enum ADD VALUE IF NOT EXISTS 'MACHINE';
EXCEPTION WHEN others THEN
  /* Tiha rekapitulacija — IF NOT EXISTS je već idempotent, ali ostavljamo
   * exception handler za slučaj da neka future verzija PG-a baci nešto neočekivano. */
  RAISE NOTICE 'add_loc_machine_enum: ALTER TYPE failed (možda već dodato): %', SQLERRM;
END
$enum$;

-- Sanity check radi diff-ovog feedback-a u SQL Editoru.
DO $sanity$
DECLARE
  v_has_machine BOOLEAN;
BEGIN
  v_has_machine := EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'loc_type_enum' AND e.enumlabel = 'MACHINE'
  );
  IF NOT v_has_machine THEN
    RAISE EXCEPTION 'add_loc_machine_enum FAILED: MACHINE nije dodat u loc_type_enum.';
  END IF;
  RAISE NOTICE 'add_loc_machine_enum OK — sada možeš da pokreneš add_loc_machine_locations.sql.';
END
$sanity$;
