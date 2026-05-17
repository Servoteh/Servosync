-- ============================================================================
-- LOKACIJE × MAŠINE — Faza 1, Korak 2b: sync seed-a iz `maint_machines`
-- ============================================================================
-- Pokreni JEDNOM (i kasnije po potrebi) u Supabase SQL Editoru. Idempotentno.
--
-- ZAŠTO POSTOJI ova migracija:
--   `maint_machines` je AUTORITATIVNI lokalni katalog mašina u ERP-u (vidi
--   `add_maint_machines_catalog.sql`). Održavanje modul ga održava — inicijalno
--   seed iz BigTehn-a, dalje se menja ručno (chief/admin dodaje, arhivira).
--
--   Prvi seed (`add_loc_machine_locations.sql`) je čitao iz
--   `bigtehn_machines_cache` sa `no_procedure=FALSE` filterom — što je u prvom
--   pasusu uradilo isto što i ovo. Ali kad admin kroz Održavanje doda novu
--   mašinu (npr. KOMP-01 manuelno), ona neće biti u BigTehn-u nikad. Ovo
--   povezuje dva izvora tako što čita lokalni katalog umesto BigTehn keš-a.
--
--   NAPOMENA: CAM stanice (17.0, 17.1) NISU ovde — flagovane su
--   `no_procedure=TRUE` u BigTehn-u i namerno NISU dodate u `maint_machines`
--   (CAM = programiranje na PC-u, komad fizički ne ide tamo).
--
-- Šta radi:
--   1. Čita sve aktivne mašine iz `maint_machines` (archived_at IS NULL,
--      tracked = TRUE).
--   2. Mapira `machine_code` na dept grupaciju (M.SEC, M.STR, …, M.OST fallback)
--      preko istog CASE-a kao u originalnom seed-u.
--   3. INSERT ... ON CONFLICT DO NOTHING — postojeći redovi ostaju nedirnuti.
--
-- Preduslov: `add_loc_machine_enum.sql` i `add_loc_machine_locations.sql`
-- moraju biti pre ovoga (root M, dept halls, MACHINE enum vrednost).
--
-- KORIŠĆENJE U BUDUĆNOSTI: kad chief doda novu mašinu u Održavanje → Katalog,
-- re-pokreni ovu migraciju da je dodaš u Lokacije. (Faza 2 može da to radi
-- automatski preko trigger-a na `maint_machines` AFTER INSERT.)
--
-- DOWN: nije potrebno; INSERT je samo dopuna.
-- ============================================================================

DO $check$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'loc_type_enum' AND e.enumlabel = 'MACHINE'
  ) THEN
    RAISE EXCEPTION
      'add_loc_machine_locations_from_maint: enum vrednost MACHINE ne postoji. '
      'Prvo pokreni `add_loc_machine_enum.sql` pa `add_loc_machine_locations.sql`.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.loc_locations WHERE location_code = 'M'
  ) THEN
    RAISE EXCEPTION
      'add_loc_machine_locations_from_maint: root „M" hala ne postoji. '
      'Prvo pokreni `add_loc_machine_locations.sql`.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
     WHERE table_schema='public' AND table_name='maint_machines'
  ) THEN
    RAISE EXCEPTION
      'add_loc_machine_locations_from_maint: tabela `maint_machines` ne postoji. '
      'Prvo pokreni `add_maint_machines_catalog.sql`.';
  END IF;
END
$check$;

-- ── Sync iz maint_machines ──────────────────────────────────────────────────
WITH all_known_machines AS (
  /* JEDINI izvor: maint_machines (lokalni autoritativni katalog).
   * CAM stanice (17.x) i druge no_procedure=TRUE pomoćne operacije NISU ovde
   * — namerno, jer komad fizički ne ide tamo (CAM = programiranje na PC-u). */
  SELECT
    m.machine_code AS rj_code,
    m.name
  FROM public.maint_machines m
  WHERE m.archived_at IS NULL
    AND m.tracked = TRUE
    AND m.machine_code IS NOT NULL
    AND length(trim(m.machine_code)) > 0
),
dept_for_machine AS (
  SELECT
    a.rj_code,
    a.name,
    CASE
      /* Sečenje i savijanje */
      WHEN a.rj_code IN ('1.10','1.2','1.30','1.40','1.50','1.60','1.71','1.72') THEN 'M.SEC'
      /* Bravarsko */
      WHEN a.rj_code IN ('4.1','4.11','4.12','4.2','4.3','4.4') THEN 'M.BRA'
      /* Farbanje (5.1–5.8 + 5.11) — 5.9 i 5.10 idu u Ostalo */
      WHEN a.rj_code IN ('5.1','5.2','5.3','5.4','5.5','5.6','5.7','5.8','5.11') THEN 'M.FAR'
      /* CAM */
      WHEN a.rj_code IN ('17.0','17.1') THEN 'M.CAM'
      /* Ažistiranje — samo 8.2 */
      WHEN a.rj_code = '8.2' THEN 'M.AZI'
      /* Erodiranje */
      WHEN a.rj_code IN ('10.1','10.2','10.3','10.4','10.5') THEN 'M.ERO'
      /* Brušenje: prefiks 6 osim 6.8 */
      WHEN a.rj_code LIKE '6.%' AND a.rj_code <> '6.8' THEN 'M.BRU'
      WHEN a.rj_code = '6' THEN 'M.BRU'
      /* Glodanje: prefiks 3 */
      WHEN a.rj_code LIKE '3.%' OR a.rj_code = '3' THEN 'M.GLO'
      /* Struganje: prefiks 2 osim 21.x (3D štampa) */
      WHEN (a.rj_code LIKE '2.%' OR a.rj_code = '2') AND a.rj_code NOT LIKE '21.%' AND a.rj_code <> '21' THEN 'M.STR'
      /* Sve ostalo */
      ELSE 'M.OST'
    END AS dept_code
  FROM all_known_machines a
)
INSERT INTO public.loc_locations (location_code, name, location_type, parent_id, is_active, notes)
SELECT
  d.rj_code,
  COALESCE(NULLIF(trim(d.name), ''), 'Mašina ' || d.rj_code),
  'MACHINE'::public.loc_type_enum,
  parent.id,
  TRUE,
  'Seed iz maint_machines (+ bigtehn_machines_cache fallback). Faza 1.'
FROM dept_for_machine d
LEFT JOIN public.loc_locations parent
  ON parent.location_code = d.dept_code
ON CONFLICT DO NOTHING;

-- ── Sanity / izveštaj o stanju ──────────────────────────────────────────────
DO $sanity$
DECLARE
  v_count_per_dept TEXT;
  v_total          INTEGER;
  v_unparented     INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM public.loc_locations
  WHERE location_type = 'MACHINE';

  /* Mašina bez roditelja je verovatno bug — javljamo. */
  SELECT COUNT(*) INTO v_unparented
  FROM public.loc_locations
  WHERE location_type = 'MACHINE' AND parent_id IS NULL;

  SELECT string_agg(
    COALESCE(p.location_code, '(no-parent)') || '=' || cnt::text,
    ', ' ORDER BY p.location_code NULLS LAST
  )
  INTO v_count_per_dept
  FROM (
    SELECT parent_id, COUNT(*) AS cnt
    FROM public.loc_locations
    WHERE location_type = 'MACHINE'
    GROUP BY parent_id
  ) g
  LEFT JOIN public.loc_locations p ON p.id = g.parent_id;

  RAISE NOTICE 'add_loc_machine_locations_from_maint OK: total mašina=%, bez roditelja=%, po grupi=[%].',
    v_total, v_unparented, v_count_per_dept;

  IF v_unparented > 0 THEN
    RAISE NOTICE 'UPOZORENJE: % mašina bez parent_id — dept_code mapping nije matchovao postojeću M.* halu. Proveri da li su seed-ovane dept grupacije (M.SEC, M.STR, ...).', v_unparented;
  END IF;
END
$sanity$;
