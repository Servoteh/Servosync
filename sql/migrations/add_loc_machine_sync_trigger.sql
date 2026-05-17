-- ============================================================================
-- LOKACIJE × MAŠINE — Faza 2: AUTO-SYNC `maint_machines` → `loc_locations`
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru (idempotentno, safe za reapply).
--
-- ZAŠTO POSTOJI:
--   Faza 1 (`add_loc_machine_locations*.sql`) je bila jednokratan seed.
--   Kada se sada doda nova mašina kroz UI „Podešavanja → Mašine" (ili
--   `/maintenance/catalog`), red u `maint_machines` ne ulazi automatski u
--   `loc_locations`. Operateru zato „nedostaje" lokacija u Loc modulu sve
--   dok admin ručno ne klikne kroz Lokacije.
--
--   Ova migracija pretvara seed u kontinuirani sync kroz trigger.
--
-- ŠTA RADI:
--   1. Helper `maint_machine_dept_code(rj_code TEXT) RETURNS TEXT`
--      — single source of truth za rj_code → M.* dept mapping. Isti CASE
--        kao u `add_loc_machine_locations_from_maint.sql`, samo izdvojeno
--        u funkciju da bi bilo reusable (i iz seed-a i iz trigger-a).
--   2. Trigger funkcija `maint_machines_sync_to_loc()`:
--        * INSERT (active) → INSERT u loc_locations sa MACHINE tipom i
--          parent_id = M.* hala po dept mapping-u. ON CONFLICT DO NOTHING.
--        * UPDATE (name, archived_at, tracked) → UPDATE postojećeg reda
--          u loc_locations (name, is_active).
--        * DELETE → ne dira loc_locations (istorijska placement-i ostaju).
--      SECURITY DEFINER jer ne želimo da maint chief (koji nema admin/pm/leadpm
--      ulogu za `loc_can_manage_locations()`) bude blokiran RLS-om.
--   3. Trigger `trg_maint_machines_loc_sync` AFTER INSERT OR UPDATE.
--   4. Backfill — pokriva mašine dodate između prvog seed-a i ove migracije.
--      Identičan upit kao `add_loc_machine_locations_from_maint.sql` (UNION
--      maint_machines + bigtehn fallback), ON CONFLICT DO NOTHING.
--
-- NAPOMENA o ON CONFLICT:
--   Sva tri INSERT-a koriste `ON CONFLICT DO NOTHING` BEZ targeta. Razlog je
--   isti kao u seed-u: postoje dva moguća unique indeksa na location_code
--   (originalni case-sensitive iz `add_loc_module.sql` i case-insensitive
--   iz `add_loc_step2_ci_unique.sql`). Targeted ON CONFLICT (location_code)
--   ili (lower(location_code)) pada na deploy-evima koji nemaju matching
--   indeks: „42P10 there is no unique or exclusion constraint matching".
--   DO NOTHING bez targeta hvata svaki unique violation iz BILO KOJEG indeksa.
--
-- ŠTA NE RADI:
--   - DELETE iz maint_machines NE briše loc_locations red (ima istorijskih
--     placement-a koji ga referenciraju — DELETE bi pao na FK RESTRICT).
--   - RENAME (`renameMaintMachine`) atomski menja machine_code u svim
--     maint_* tabelama, ali NE menja `loc_locations.location_code`. Razlog:
--     production/pracenje tabele takođe drže lokacije po location_code, pa
--     bi globalna rename promena bila širi posao od ove faze. Admin koji
--     menja šifru mora ručno da ažurira i Lokacije (dokumentovano u UI-ju).
--
-- ZAVISI OD:
--   - `add_loc_machine_enum.sql` (MACHINE enum vrednost)
--   - `add_loc_machine_locations.sql` (M root + M.* dept halls)
--   - `add_maint_machines_catalog.sql` (maint_machines tabela)
--
-- DOWN (rollback):
--   DROP TRIGGER IF EXISTS trg_maint_machines_loc_sync ON public.maint_machines;
--   DROP FUNCTION IF EXISTS public.maint_machines_sync_to_loc();
--   DROP FUNCTION IF EXISTS public.maint_machine_dept_code(TEXT);
--   /* loc_locations redovi ostaju — to je istorija, ne diramo. */
-- ============================================================================

-- ── 0. Preduslov: enum 'MACHINE' i M root moraju postojati ──────────────────
DO $check$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'loc_type_enum' AND e.enumlabel = 'MACHINE'
  ) THEN
    RAISE EXCEPTION
      'add_loc_machine_sync_trigger: enum vrednost MACHINE ne postoji. '
      'Prvo pokreni `add_loc_machine_enum.sql` i `add_loc_machine_locations.sql`.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.loc_locations WHERE location_code = 'M.OST'
  ) THEN
    RAISE EXCEPTION
      'add_loc_machine_sync_trigger: dept hala M.OST ne postoji. '
      'Prvo pokreni `add_loc_machine_locations.sql` (seed M + M.* grupacije).';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
     WHERE table_schema='public' AND table_name='maint_machines'
  ) THEN
    RAISE EXCEPTION
      'add_loc_machine_sync_trigger: tabela `maint_machines` ne postoji. '
      'Prvo pokreni `add_maint_machines_catalog.sql`.';
  END IF;
END
$check$;

-- ── 1. Helper: rj_code → M.* dept location_code ─────────────────────────────
-- Identičan CASE kao u `add_loc_machine_locations_from_maint.sql`. Izdvojeno
-- u funkciju da bi seed i trigger zvali istu logiku (single source of truth).
-- IMMUTABLE jer ne čita ništa iz DB-a.
CREATE OR REPLACE FUNCTION public.maint_machine_dept_code(p_machine_code TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN p_machine_code IS NULL OR length(trim(p_machine_code)) = 0 THEN 'M.OST'
    /* Sečenje i savijanje */
    WHEN p_machine_code IN ('1.10','1.2','1.30','1.40','1.50','1.60','1.71','1.72') THEN 'M.SEC'
    /* Bravarsko */
    WHEN p_machine_code IN ('4.1','4.11','4.12','4.2','4.3','4.4') THEN 'M.BRA'
    /* Farbanje (5.1–5.8 + 5.11) — 5.9 i 5.10 idu u Ostalo */
    WHEN p_machine_code IN ('5.1','5.2','5.3','5.4','5.5','5.6','5.7','5.8','5.11') THEN 'M.FAR'
    /* CAM */
    WHEN p_machine_code IN ('17.0','17.1') THEN 'M.CAM'
    /* Ažistiranje — samo 8.2 */
    WHEN p_machine_code = '8.2' THEN 'M.AZI'
    /* Erodiranje */
    WHEN p_machine_code IN ('10.1','10.2','10.3','10.4','10.5') THEN 'M.ERO'
    /* Brušenje: prefiks 6 osim 6.8 */
    WHEN p_machine_code LIKE '6.%' AND p_machine_code <> '6.8' THEN 'M.BRU'
    WHEN p_machine_code = '6' THEN 'M.BRU'
    /* Glodanje: prefiks 3 */
    WHEN p_machine_code LIKE '3.%' OR p_machine_code = '3' THEN 'M.GLO'
    /* Struganje: prefiks 2 osim 21.x (3D štampa) */
    WHEN (p_machine_code LIKE '2.%' OR p_machine_code = '2')
         AND p_machine_code NOT LIKE '21.%' AND p_machine_code <> '21' THEN 'M.STR'
    /* Sve ostalo */
    ELSE 'M.OST'
  END
$$;

COMMENT ON FUNCTION public.maint_machine_dept_code(TEXT) IS
  'rj_code (machine_code) → M.* dept location_code. Single source of truth za seed i sync trigger.';

GRANT EXECUTE ON FUNCTION public.maint_machine_dept_code(TEXT) TO authenticated, service_role;

-- ── 2. Trigger funkcija: maint_machines → loc_locations ─────────────────────
-- SECURITY DEFINER da bypass-uje `loc_can_manage_locations()` RLS check kad
-- maint chief (bez admin/pm/leadpm role) doda mašinu kroz katalog.
CREATE OR REPLACE FUNCTION public.maint_machines_sync_to_loc()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_parent_id  UUID;
  v_dept_code  TEXT;
  v_should_be_active BOOLEAN;
BEGIN
  IF TG_OP = 'INSERT' THEN
    /* Upiši samo aktivne, praćene mašine (isto pravilo kao postojeći seed). */
    IF NEW.archived_at IS NOT NULL OR NEW.tracked = FALSE THEN
      RETURN NEW;
    END IF;
    IF NEW.machine_code IS NULL OR length(trim(NEW.machine_code)) = 0 THEN
      RETURN NEW;
    END IF;

    v_dept_code := public.maint_machine_dept_code(NEW.machine_code);

    SELECT id INTO v_parent_id
      FROM public.loc_locations
     WHERE location_code = v_dept_code
     LIMIT 1;

    /* Ako fallback hala iz nekog razloga ne postoji, ne diži exception u
     * INSERT-u maint_machines — samo upozori. UI bi inače pao na nečemu što
     * nema veze sa korisnikom. */
    IF v_parent_id IS NULL THEN
      RAISE WARNING
        'maint_machines_sync_to_loc: dept hala % ne postoji za mašinu %; preskačem loc_locations sync.',
        v_dept_code, NEW.machine_code;
      RETURN NEW;
    END IF;

    INSERT INTO public.loc_locations
      (location_code, name, location_type, parent_id, is_active, notes)
    VALUES
      (NEW.machine_code,
       COALESCE(NULLIF(trim(NEW.name), ''), 'Mašina ' || NEW.machine_code),
       'MACHINE'::public.loc_type_enum,
       v_parent_id,
       TRUE,
       'Auto-sync iz maint_machines (Faza 2 trigger).')
    ON CONFLICT DO NOTHING;

    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    /* Promene koje pratimo: name, archived_at, tracked. machine_code (PK)
     * ne pratimo — rename se radi kroz `renameMaintMachine` RPC koji NE
     * dira loc_locations (dokumentovano u header-u migracije). */
    IF NEW.machine_code IS NULL OR length(trim(NEW.machine_code)) = 0 THEN
      RETURN NEW;
    END IF;

    v_should_be_active := (NEW.archived_at IS NULL AND NEW.tracked <> FALSE);

    /* Ako red u loc_locations ne postoji, a mašina je sada aktivna —
     * tretiraj kao INSERT (npr. mašina je bila netracked pa je vraćena). */
    IF NOT EXISTS (
      SELECT 1 FROM public.loc_locations WHERE location_code = NEW.machine_code
    ) THEN
      IF v_should_be_active THEN
        v_dept_code := public.maint_machine_dept_code(NEW.machine_code);
        SELECT id INTO v_parent_id
          FROM public.loc_locations
         WHERE location_code = v_dept_code
         LIMIT 1;
        IF v_parent_id IS NOT NULL THEN
          INSERT INTO public.loc_locations
            (location_code, name, location_type, parent_id, is_active, notes)
          VALUES
            (NEW.machine_code,
             COALESCE(NULLIF(trim(NEW.name), ''), 'Mašina ' || NEW.machine_code),
             'MACHINE'::public.loc_type_enum,
             v_parent_id,
             TRUE,
             'Auto-sync iz maint_machines (UPDATE → INSERT, Faza 2 trigger).')
          ON CONFLICT DO NOTHING;
        END IF;
      END IF;
      RETURN NEW;
    END IF;

    /* Postoji — ažuriraj name + is_active. NULLIF/COALESCE da praznu vrednost
     * ne pretvorimo u prazan string. */
    UPDATE public.loc_locations
       SET name = COALESCE(NULLIF(trim(NEW.name), ''), name),
           is_active = v_should_be_active
     WHERE location_code = NEW.machine_code
       AND (
            name IS DISTINCT FROM COALESCE(NULLIF(trim(NEW.name), ''), name)
         OR is_active IS DISTINCT FROM v_should_be_active
       );

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.maint_machines_sync_to_loc() IS
  'Trigger fn: AFTER INSERT/UPDATE na maint_machines upsertuje red u loc_locations '
  '(type=MACHINE, parent po maint_machine_dept_code). SECURITY DEFINER za bypass '
  'RLS-a na loc_locations kad maint chief dodaje mašinu.';

-- ── 3. Trigger ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_maint_machines_loc_sync ON public.maint_machines;
CREATE TRIGGER trg_maint_machines_loc_sync
  AFTER INSERT OR UPDATE OF name, archived_at, tracked
  ON public.maint_machines
  FOR EACH ROW
  EXECUTE FUNCTION public.maint_machines_sync_to_loc();

-- ── 4. Backfill — mašine dodate posle prvog seed-a ──────────────────────────
-- Idempotentno: ON CONFLICT DO NOTHING. Pokriva i mašine koje su između
-- inicijalnog seed-a (`add_loc_machine_locations_from_maint.sql`) i ove
-- migracije ušle u `maint_machines` (ručno dodate, novi BigTehn import…).
WITH all_known_machines AS (
  SELECT m.machine_code AS rj_code, m.name
    FROM public.maint_machines m
   WHERE m.archived_at IS NULL
     AND m.tracked = TRUE
     AND m.machine_code IS NOT NULL
     AND length(trim(m.machine_code)) > 0
   UNION
  SELECT c.rj_code, c.name
    FROM public.bigtehn_machines_cache c
   WHERE c.rj_code IS NOT NULL
     AND length(trim(c.rj_code)) > 0
     AND NOT EXISTS (
       SELECT 1 FROM public.maint_machines mm
        WHERE mm.machine_code = c.rj_code
          AND mm.archived_at IS NULL
          AND mm.tracked = TRUE
     )
)
INSERT INTO public.loc_locations
  (location_code, name, location_type, parent_id, is_active, notes)
SELECT
  a.rj_code,
  COALESCE(NULLIF(trim(a.name), ''), 'Mašina ' || a.rj_code),
  'MACHINE'::public.loc_type_enum,
  parent.id,
  TRUE,
  'Backfill iz maint_machines + bigtehn fallback (Faza 2 trigger migracija).'
FROM all_known_machines a
LEFT JOIN public.loc_locations parent
  ON parent.location_code = public.maint_machine_dept_code(a.rj_code)
WHERE parent.id IS NOT NULL
ON CONFLICT DO NOTHING;

-- ── 5. Sanity report ───────────────────────────────────────────────────────
DO $sanity$
DECLARE
  v_loc_machine_total   INTEGER;
  v_maint_active_total  INTEGER;
  v_missing             INTEGER;
  v_unparented          INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_loc_machine_total
    FROM public.loc_locations WHERE location_type = 'MACHINE';

  SELECT COUNT(*) INTO v_maint_active_total
    FROM public.maint_machines
   WHERE archived_at IS NULL AND tracked = TRUE;

  SELECT COUNT(*) INTO v_missing
    FROM public.maint_machines m
   WHERE m.archived_at IS NULL
     AND m.tracked = TRUE
     AND NOT EXISTS (
       SELECT 1 FROM public.loc_locations l
        WHERE l.location_code = m.machine_code
          AND l.location_type = 'MACHINE'
     );

  SELECT COUNT(*) INTO v_unparented
    FROM public.loc_locations
   WHERE location_type = 'MACHINE' AND parent_id IS NULL;

  RAISE NOTICE
    'add_loc_machine_sync_trigger OK: loc MACHINE=%, aktivne u maint=%, nedostaju u loc=%, bez parent=%.',
    v_loc_machine_total, v_maint_active_total, v_missing, v_unparented;

  IF v_missing > 0 THEN
    RAISE NOTICE
      'UPOZORENJE: % aktivnih maint mašina nije u loc_locations — verovatno fali dept hala u mappingu.',
      v_missing;
  END IF;
END
$sanity$;
