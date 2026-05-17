-- ============================================================================
-- LOKACIJE × MAŠINE — Faza 1, Korak 2: seed mašinskih lokacija
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru — POSLE `add_loc_machine_enum.sql`.
--
-- VAŽNO — preduslov:
--   Mora biti prvo pokrenut `add_loc_machine_enum.sql` koji dodaje vrednost
--   'MACHINE' u `loc_type_enum`. PostgreSQL ne dozvoljava korišćenje nove
--   enum vrednosti u istoj transakciji u kojoj je dodata (vidi ALTER TYPE
--   ograničenje), pa moraju biti dva odvojena „Run" klika u SQL Editoru.
--
-- Šta radi:
--   1. Seed-uje root „M — Proizvodnja" (location_code = `M`, PRODUCTION).
--   2. Seed-uje 10 grupa po strojnoj podeli iz `src/ui/planProizvodnje/departments.js`
--      (bez taba „Sve") — svaka ima `location_type = OTHER`, parent je root `M`
--      (PRODUCTION kao dete hijerarhijskog pravila nije dozvoljeno).
--   3. Seed-uje mašinske lokacije iz `bigtehn_machines_cache`:
--        - location_code = rj_code (npr. „3.21")
--        - name          = naziv mašine
--        - location_type = MACHINE
--        - parent_id     = po prefiksu rj_code → odgovarajuća pseudo-hala
--      Filter: NE seedujemo mašine sa `no_procedure = true` (kompresor, HVAC,
--      itd.) — one se ne pojavljuju u prijavama operacija.
--
-- ŠTA NE RADI (Faza 1 eksplicitno isključeno):
--   - Nema auto-TRANSFER-a iz BigTehn-a. Mašine SU placement destinacije ali
--     UI ih sakriva iza filtera „Mašine" (vidi predmetTab + modals.js).
--   - Nema sync filter promene; TRANSFER ka mašinama ide kroz isti
--     loc_create_movement RPC kao do sad.
--
-- DOWN (rollback test):
--   DELETE FROM public.loc_locations WHERE location_type = 'MACHINE';
--   DELETE FROM public.loc_locations WHERE location_code LIKE 'M.%';
--   DELETE FROM public.loc_locations WHERE location_code = 'M';
--   /* Enum value se ne može DROP-ovati u Postgres-u — ostaje 'MACHINE'. */
-- ============================================================================

-- ── 1. Preduslov: enum 'MACHINE' MORA postojati ─────────────────────────────
-- Ako nije pokrenut `add_loc_machine_enum.sql` pre ovoga, eksplicitno padamo
-- sa jasnom porukom umesto kasnijeg generičkog ENUM error-a u INSERT-u.
DO $check$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'loc_type_enum' AND e.enumlabel = 'MACHINE'
  ) THEN
    RAISE EXCEPTION
      'add_loc_machine_locations: enum vrednost MACHINE ne postoji. '
      'Prvo pokreni `sql/migrations/add_loc_machine_enum.sql` (pa zatim ovaj fajl).';
  END IF;
END
$check$;

-- ── 2. Seed: root „M — Proizvodnja" + 10 pseudo-grupacija po departments.js ─
-- NAPOMENA o tipovima:
--   - Root „M" je PRODUCTION (hala) → mora biti root (parent_id IS NULL).
--   - Dept sub-grupacije (M.SEC, M.STR, …) NE mogu biti PRODUCTION jer pravilo
--     `add_loc_location_hierarchy_rules.sql` zabranjuje da hall-tipovi imaju
--     parent. Zato koristimo location_type = 'OTHER' za njih — funkcionalno
--     to su grupišuće „kutije", ne fizičke hale. Mašine (MACHINE) ispod njih
--     su dozvoljene (MACHINE nema hijerarhijska ograničenja).
-- Strategija: ON CONFLICT DO NOTHING (bez target-a). Postoje dva moguća unique
-- indeksa na loc_locations.location_code — originalni case-sensitive iz
-- `add_loc_module.sql` i case-insensitive (lower) iz `add_loc_step2_ci_unique.sql`.
-- Targeted ON CONFLICT (lower(location_code)) pada na produkciji koja još nije
-- primenila Step 2 sa „no unique constraint matching ON CONFLICT specification".
-- DO NOTHING bez target-a hvata svaki unique violation iz BILO KOJEG indeksa.

INSERT INTO public.loc_locations
  (location_code, name, location_type, parent_id, is_active, notes)
VALUES
  ('M',       'M — Proizvodnja',                   'PRODUCTION', NULL, TRUE,
    'Seed: root hala za sve mašinske lokacije (Faza 1).'),
  ('M.SEC',   'Sečenje i savijanje',              'OTHER',      NULL, TRUE, 'Seed po departments.js (Faza 1)'),
  ('M.STR',   'Struganje',                        'OTHER',      NULL, TRUE, 'Seed po departments.js (Faza 1)'),
  ('M.GLO',   'Glodanje',                         'OTHER',      NULL, TRUE, 'Seed po departments.js (Faza 1)'),
  ('M.BRA',   'Bravarsko',                        'OTHER',      NULL, TRUE, 'Seed po departments.js (Faza 1)'),
  ('M.FAR',   'Farbanje i površinska zaštita',    'OTHER',      NULL, TRUE, 'Seed po departments.js (Faza 1)'),
  ('M.BRU',   'Brušenje',                         'OTHER',      NULL, TRUE, 'Seed po departments.js (Faza 1)'),
  ('M.AZI',   'Ažistiranje',                      'OTHER',      NULL, TRUE, 'Seed po departments.js (Faza 1)'),
  ('M.ERO',   'Erodiranje',                       'OTHER',      NULL, TRUE, 'Seed po departments.js (Faza 1)'),
  ('M.CAM',   'CAM programiranje',                'OTHER',      NULL, TRUE, 'Seed po departments.js (Faza 1)'),
  ('M.OST',   'Ostalo (mašine bez kategorije)',   'OTHER',      NULL, TRUE, 'Seed po departments.js — fallback')
ON CONFLICT DO NOTHING;

UPDATE public.loc_locations
   SET name = 'M — Proizvodnja'
 WHERE lower(location_code) = 'm'
   AND COALESCE(trim(name),'') <> 'M — Proizvodnja';

-- Postavi parent_id svih M.* na „M" root.
UPDATE public.loc_locations
   SET parent_id = (SELECT id FROM public.loc_locations WHERE location_code = 'M')
 WHERE location_code IN ('M.SEC','M.STR','M.GLO','M.BRA','M.FAR','M.BRU','M.AZI','M.ERO','M.CAM','M.OST')
   AND parent_id IS NULL;

-- ── 4. Seed mašinskih lokacija iz bigtehn_machines_cache ───────────────────
-- Mapping rj_code → pseudo-hala (mora biti usklađen sa departments.js helper-ima).
--
-- Pravila (po departments.js):
--   prefiks „1" + neke specifične → M.SEC
--   prefiks „2" osim 21.x         → M.STR
--   prefiks „3"                   → M.GLO
--   prefiks „4" specifične        → M.BRA
--   prefiks „5" specifične        → M.FAR
--   prefiks „6" osim 6.8          → M.BRU
--   tačno „8.2"                   → M.AZI
--   prefiks „10"                  → M.ERO
--   prefiks „17"                  → M.CAM
--   sve ostalo                    → M.OST
--
-- Funkcija nije perzistirana — koristi se samo u INSERT iz CTE.

WITH dept_for_machine AS (
  SELECT
    m.rj_code,
    m.name,
    CASE
      /* Sečenje i savijanje */
      WHEN m.rj_code IN ('1.10','1.2','1.30','1.40','1.50','1.60','1.71','1.72') THEN 'M.SEC'
      /* Bravarsko */
      WHEN m.rj_code IN ('4.1','4.11','4.12','4.2','4.3','4.4') THEN 'M.BRA'
      /* Farbanje (5.1–5.8 + 5.11) — 5.9 i 5.10 idu u Ostalo */
      WHEN m.rj_code IN ('5.1','5.2','5.3','5.4','5.5','5.6','5.7','5.8','5.11') THEN 'M.FAR'
      /* CAM */
      WHEN m.rj_code IN ('17.0','17.1') THEN 'M.CAM'
      /* Ažistiranje — samo 8.2 */
      WHEN m.rj_code = '8.2' THEN 'M.AZI'
      /* Erodiranje */
      WHEN m.rj_code IN ('10.1','10.2','10.3','10.4','10.5') THEN 'M.ERO'
      /* Brušenje: prefiks 6 osim 6.8 */
      WHEN m.rj_code LIKE '6.%' AND m.rj_code <> '6.8' THEN 'M.BRU'
      WHEN m.rj_code = '6' THEN 'M.BRU'
      /* Glodanje: prefiks 3 */
      WHEN m.rj_code LIKE '3.%' OR m.rj_code = '3' THEN 'M.GLO'
      /* Struganje: prefiks 2 osim 21.x (3D štampa) */
      WHEN (m.rj_code LIKE '2.%' OR m.rj_code = '2') AND m.rj_code NOT LIKE '21.%' AND m.rj_code <> '21' THEN 'M.STR'
      /* Sve ostalo */
      ELSE 'M.OST'
    END AS dept_code
  FROM public.bigtehn_machines_cache m
  WHERE COALESCE(m.no_procedure, FALSE) = FALSE
    AND m.rj_code IS NOT NULL
    AND length(trim(m.rj_code)) > 0
)
INSERT INTO public.loc_locations (location_code, name, location_type, parent_id, is_active, notes)
SELECT
  d.rj_code,
  COALESCE(NULLIF(trim(d.name), ''), 'Mašina ' || d.rj_code),
  'MACHINE'::public.loc_type_enum,
  parent.id,
  TRUE,
  'Seed iz bigtehn_machines_cache (Faza 1).'
FROM dept_for_machine d
LEFT JOIN public.loc_locations parent
  ON parent.location_code = d.dept_code
ON CONFLICT DO NOTHING;

-- ── 5. Sanity check ─────────────────────────────────────────────────────────
DO $sanity$
DECLARE
  v_has_machine_enum BOOLEAN;
  v_root_exists      BOOLEAN;
  v_machines_seeded  INTEGER;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'loc_type_enum' AND e.enumlabel = 'MACHINE'
  ) INTO v_has_machine_enum;

  SELECT EXISTS (
    SELECT 1 FROM public.loc_locations WHERE location_code = 'M'
  ) INTO v_root_exists;

  SELECT COUNT(*) INTO v_machines_seeded
  FROM public.loc_locations
  WHERE location_type = 'MACHINE';

  IF NOT v_has_machine_enum THEN
    RAISE EXCEPTION 'add_loc_machine_locations: enum MACHINE nije dodat';
  END IF;
  IF NOT v_root_exists THEN
    RAISE EXCEPTION 'add_loc_machine_locations: root hala „M" nije kreirana';
  END IF;

  RAISE NOTICE 'add_loc_machine_locations OK: MACHINE enum=%, root M=%, seedovano mašina=%',
    v_has_machine_enum, v_root_exists, v_machines_seeded;
END
$sanity$;

COMMENT ON COLUMN public.loc_locations.location_type IS
  'Tip lokacije (loc_type_enum). MACHINE = pseudo-lokacija mašine — placement destinacija sakrivena iza UI filtera „Mašine" (Faza 1).';
