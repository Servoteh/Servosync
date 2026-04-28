-- ═══════════════════════════════════════════════════════════════════════
-- MIGRATION: Org struktura — departments, sub_departments, job_positions
--
-- 1. Kreira referentne tabele za odeljenja / pododeljenja / radna mesta.
-- 2. Seed-uje sve podatke iz SERVOTEH_Pregled_Odeljenja_v1.1 (april 2026).
-- 3. Dodaje FK kolone na employees (department_id, sub_department_id, position_id).
-- 4. Migrira postojeće tekstualne department vrednosti na FK ID-jeve.
-- 5. RLS: SELECT — authenticated; INSERT/UPDATE/DELETE — samo admin.
-- 6. Rekreira v_employees_safe sa JOIN-ovima i novim kolonama.
--
-- Depends on: add_admin_roles.sql (current_user_is_admin),
--             restrict_employee_pii_admin_only.sql (v_employees_safe).
-- Idempotentno, safe za re-run.
-- ═══════════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'current_user_is_admin') THEN
    RAISE EXCEPTION 'Missing current_user_is_admin(). Run add_admin_roles.sql first.';
  END IF;
END $$;

-- ── 1. REFERENTNE TABELE ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.departments (
  id         SERIAL PRIMARY KEY,
  name       TEXT    NOT NULL,
  sort_order SMALLINT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.sub_departments (
  id            SERIAL PRIMARY KEY,
  department_id INTEGER NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
  name          TEXT    NOT NULL,
  sort_order    SMALLINT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.job_positions (
  id                SERIAL PRIMARY KEY,
  department_id     INTEGER NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
  sub_department_id INTEGER          REFERENCES public.sub_departments(id) ON DELETE SET NULL,
  name              TEXT    NOT NULL,
  sort_order        SMALLINT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_sub_departments_dept   ON public.sub_departments(department_id);
CREATE INDEX IF NOT EXISTS idx_job_positions_dept     ON public.job_positions(department_id);
CREATE INDEX IF NOT EXISTS idx_job_positions_subdept  ON public.job_positions(sub_department_id);

-- ── 2. SEED — ODELJENJA ───────────────────────────────────────────────

INSERT INTO public.departments (id, name, sort_order)
VALUES
  (1,  'Menadžment',                          0),
  (2,  'Proizvodnja',                         10),
  (3,  'Montaža',                             20),
  (4,  'Automatika – Elektro',                30),
  (5,  'Inženjering i projektovanje',         40),
  (6,  'Projekti',                            50),
  (7,  'Prodaja i marketing',                 60),
  (8,  'Infrastruktura, logistika i nabavka', 70),
  (9,  'Održavanje i servis',                 80),
  (10, 'Kvalitet',                            90),
  (11, 'Finansije i administracija',          100),
  (12, 'HAP Fluid',                           108),
  (13, 'Servoteh',                            109)
ON CONFLICT (id) DO NOTHING;

SELECT setval('public.departments_id_seq', (SELECT MAX(id) FROM public.departments));

-- ── 3. SEED — PODODELJENJA ────────────────────────────────────────────

INSERT INTO public.sub_departments (department_id, name, sort_order)
SELECT t.dept_id, t.name, t.so
FROM (VALUES
  -- 1 · Menadžment nema pododeljenja (admin može dodati)
  -- 2 · Proizvodnja
  (2, 'Rukovodstvo i tehnologija',  10),
  (2, 'Planiranje i priprema',      20),
  (2, 'Sečenje i rezanje',          30),
  (2, 'Bravarija i zavarivanje',    40),
  (2, 'Farbara',                    50),
  (2, 'Mašinska obrada',            60),
  -- 3 · Montaža
  (3, 'Mašinska montaža',           10),
  -- 4 · Automatika – Elektro
  (4, 'Rukovodstvo automatike',     10),
  (4, 'Elektro projektovanje',      20),
  (4, 'PLC programiranje i SCADA',  30),
  (4, 'Puštanje u rad',             40),
  (4, 'Elektro montaža',            50),
  -- 5 · Inženjering i projektovanje
  (5, 'Rukovodstvo inženjeringa',   10),
  (5, 'Mašinsko projektovanje',     20),
  (5, 'Hidraulika i algoritmi',     30),
  -- 6 · Projekti
  (6, 'PM tim',                     10),
  -- 7 · Prodaja i marketing
  (7, 'Prodaja',                    10),
  (7, 'Ponude i tenderi',           20),
  (7, 'Marketing',                  30),
  -- 8 · Infrastruktura, logistika i nabavka
  (8, 'Rukovodstvo infrastrukture', 10),
  (8, 'Nabavka',                    20),
  (8, 'Magacin i logistika',        30),
  (8, 'Objekti i bezbednost',       40),
  -- 9 · Održavanje i servis
  (9, 'Održavanje opreme',          10),
  (9, 'Terenski servis',            20),
  (9, 'IT',                         30),
  -- 10 · Kvalitet
  (10, 'Kontrola kvaliteta',        10),
  -- 11 · Finansije i administracija
  (11, 'Administracija',            10),
  (11, 'HR i organizacioni razvoj', 20),
  (11, 'Finansije i pravo',         30)
) AS t(dept_id, name, so)
WHERE NOT EXISTS (
  SELECT 1 FROM public.sub_departments sd
  WHERE sd.department_id = t.dept_id AND sd.name = t.name
);

-- ── 4. SEED — RADNA MESTA ─────────────────────────────────────────────

DO $$
DECLARE
  sd_id INTEGER;
BEGIN
  -- ── M · Menadžment (bez pododeljenja, sub_department_id = NULL)
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (1, NULL, 'Generalni direktor (CEO)',                                   10),
    (1, NULL, 'Direktor operacija (COO)',                                   20),
    (1, NULL, 'Direktor finansijsko-pravnog i administrativnog sektora (CFO)', 30),
    (1, NULL, 'Direktor projekata i ključnih kupaca',                       40),
    (1, NULL, 'Direktor prodaje i razvoja poslovanja',                      50)
  ON CONFLICT DO NOTHING;

  -- ── 1 · Proizvodnja — Rukovodstvo i tehnologija
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 2 AND name = 'Rukovodstvo i tehnologija';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (2, sd_id, 'Rukovodilac proizvodnih operacija i tehnologije', 10),
    (2, sd_id, 'Tehnolog mašinske obrade',                        20)
  ON CONFLICT DO NOTHING;

  -- ── 1 · Proizvodnja — Planiranje i priprema
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 2 AND name = 'Planiranje i priprema';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (2, sd_id, 'Menadžer planiranja proizvodnje i kapaciteta', 10),
    (2, sd_id, 'Planer i praćenje proizvodnje',                20)
  ON CONFLICT DO NOTHING;

  -- ── 1 · Proizvodnja — Sečenje i rezanje
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 2 AND name = 'Sečenje i rezanje';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (2, sd_id, 'Tim lider – sečenje/rezanje',   10),
    (2, sd_id, 'Operater na sečenju/rezanju',   20)
  ON CONFLICT DO NOTHING;

  -- ── 1 · Proizvodnja — Bravarija i zavarivanje
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 2 AND name = 'Bravarija i zavarivanje';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (2, sd_id, 'Tim lider – bravarsko-zavarivačko odeljenje', 10),
    (2, sd_id, 'Bravar',                                      20),
    (2, sd_id, 'Bravar – pomoćnik',                           30),
    (2, sd_id, 'Zavarivač',                                   40)
  ON CONFLICT DO NOTHING;

  -- ── 1 · Proizvodnja — Farbara
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 2 AND name = 'Farbara';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (2, sd_id, 'Tim lider – farbara',                     10),
    (2, sd_id, 'Operater pripreme površina za farbanje',  20),
    (2, sd_id, 'Radnik u farbari',                        30)
  ON CONFLICT DO NOTHING;

  -- ── 1 · Proizvodnja — Mašinska obrada
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 2 AND name = 'Mašinska obrada';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (2, sd_id, 'Šef mašinske obrade',                   10),
    (2, sd_id, 'Tim lider – CNC 1',                     20),
    (2, sd_id, 'Tim lider – CNC 2',                     30),
    (2, sd_id, 'Tim lider – Borverk',                   40),
    (2, sd_id, 'Operater na mašini (strugar/glodač)',   50),
    (2, sd_id, 'Radnik na obaranju ivica',               60)
  ON CONFLICT DO NOTHING;

  -- ── 2 · Montaža — Mašinska montaža
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 3 AND name = 'Mašinska montaža';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (3, sd_id, 'Tim lider – mašinska montaža',    10),
    (3, sd_id, 'Mašinski monter',                 20),
    (3, sd_id, 'Mašinski monter – pomoćnik',      30)
  ON CONFLICT DO NOTHING;

  -- ── 4 · Automatika – Elektro — Rukovodstvo automatike
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 4 AND name = 'Rukovodstvo automatike';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (4, sd_id, 'Glavni inženjer automatike i PLC sistema', 10)
  ON CONFLICT DO NOTHING;

  -- ── 4 · Automatika – Elektro — Elektro projektovanje
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 4 AND name = 'Elektro projektovanje';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (4, sd_id, 'Stariji elektro projektant', 10),
    (4, sd_id, 'Elektro projektant',          20),
    (4, sd_id, 'Mlađi elektro projektant',    30)
  ON CONFLICT DO NOTHING;

  -- ── 4 · Automatika – Elektro — PLC programiranje i SCADA
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 4 AND name = 'PLC programiranje i SCADA';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (4, sd_id, 'Stariji PLC programer / automatiičar', 10),
    (4, sd_id, 'PLC programer / automatiičar',         20),
    (4, sd_id, 'Mlađi PLC programer / automatiičar',   30)
  ON CONFLICT DO NOTHING;

  -- ── 4 · Automatika – Elektro — Puštanje u rad
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 4 AND name = 'Puštanje u rad';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (4, sd_id, 'Inženjer puštanja u rad – mehanika, senzori i automatika', 10)
  ON CONFLICT DO NOTHING;

  -- ── 4 · Automatika – Elektro — Elektro montaža
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 4 AND name = 'Elektro montaža';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (4, sd_id, 'Tim lider – elektro montaža', 10),
    (4, sd_id, 'Elektro monter',               20)
  ON CONFLICT DO NOTHING;

  -- ── 5 · Inženjering i projektovanje — Rukovodstvo inženjeringa
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 5 AND name = 'Rukovodstvo inženjeringa';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (5, sd_id, 'Glavni mašinski inženjer i Rukovodilac inženjeringa', 10),
    (5, sd_id, 'Vodeći inženjer (Technical Lead)',                     20)
  ON CONFLICT DO NOTHING;

  -- ── 5 · Inženjering i projektovanje — Mašinsko projektovanje
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 5 AND name = 'Mašinsko projektovanje';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (5, sd_id, 'Stariji mašinski projektant', 10),
    (5, sd_id, 'Viši mašinski projektant',    20),
    (5, sd_id, 'Mašinski projektant',          30),
    (5, sd_id, 'Mlađi mašinski projektant',   40)
  ON CONFLICT DO NOTHING;

  -- ── 5 · Inženjering i projektovanje — Hidraulika i algoritmi
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 5 AND name = 'Hidraulika i algoritmi';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (5, sd_id, 'Projektant hidraulike i algoritama', 10)
  ON CONFLICT DO NOTHING;

  -- ── 6 · Projekti — PM tim
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 6 AND name = 'PM tim';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (6, sd_id, 'LEAD PM', 10),
    (6, sd_id, 'Projekt menadžer',                20),
    (6, sd_id, 'Tehnički lider projekta',          30)
  ON CONFLICT DO NOTHING;

  -- ── 7 · Prodaja i marketing — Prodaja
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 7 AND name = 'Prodaja';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (7, sd_id, 'Inženjer prodaje', 10)
  ON CONFLICT DO NOTHING;

  -- ── 7 · Prodaja i marketing — Ponude i tenderi
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 7 AND name = 'Ponude i tenderi';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (7, sd_id, 'Menadžer ponuda i tendera', 10)
  ON CONFLICT DO NOTHING;

  -- ── 7 · Prodaja i marketing — Marketing
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 7 AND name = 'Marketing';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (7, sd_id, 'Menadžer marketinga', 10)
  ON CONFLICT DO NOTHING;

  -- ── 8 · Infrastruktura — Rukovodstvo infrastrukture
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 8 AND name = 'Rukovodstvo infrastrukture';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (8, sd_id, 'Menadžer operativne infrastrukture i logistike', 10)
  ON CONFLICT DO NOTHING;

  -- ── 8 · Infrastruktura — Nabavka
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 8 AND name = 'Nabavka';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (8, sd_id, 'Tim lider – nabavka',    10),
    (8, sd_id, 'Administrator nabavke',  20)
  ON CONFLICT DO NOTHING;

  -- ── 8 · Infrastruktura — Magacin i logistika
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 8 AND name = 'Magacin i logistika';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (8, sd_id, 'Tim lider – magacin',    10),
    (8, sd_id, 'Magacioner',             20),
    (8, sd_id, 'Viljuškarista',          30),
    (8, sd_id, 'Vozač',                  40),
    (8, sd_id, 'Referent voznog parka',  50)
  ON CONFLICT DO NOTHING;

  -- ── 8 · Infrastruktura — Objekti i bezbednost
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 8 AND name = 'Objekti i bezbednost';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (8, sd_id, 'Domar',                                              10),
    (8, sd_id, 'Higijeničarka / čistačica',                          20),
    (8, sd_id, 'Stručnjak za bezbednost i zaštitu na radu (HSE)',    30),
    (8, sd_id, 'Referent PP zaštite',                                40),
    (8, sd_id, 'Portir',                                             50)
  ON CONFLICT DO NOTHING;

  -- ── 9 · Održavanje i servis — Održavanje opreme
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 9 AND name = 'Održavanje opreme';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (9, sd_id, 'Tim lider održavanja i servisa', 10),
    (9, sd_id, 'Tehničar elektro održavanja',    20),
    (9, sd_id, 'Radnik održavanja',              30)
  ON CONFLICT DO NOTHING;

  -- ── 9 · Održavanje i servis — Terenski servis
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 9 AND name = 'Terenski servis';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (9, sd_id, 'Serviser hidraulike – terenski servis', 10)
  ON CONFLICT DO NOTHING;

  -- ── 9 · Održavanje i servis — IT
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 9 AND name = 'IT';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (9, sd_id, 'IT administrator', 10)
  ON CONFLICT DO NOTHING;

  -- ── 10 · Kvalitet — Kontrola kvaliteta
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 10 AND name = 'Kontrola kvaliteta';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (10, sd_id, 'Tim lider – kontrola kvaliteta', 10),
    (10, sd_id, 'Kontrolor kvaliteta',             20)
  ON CONFLICT DO NOTHING;

  -- ── 11 · Finansije i administracija — Administracija
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 11 AND name = 'Administracija';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (11, sd_id, 'Tim lider – administracija',        10),
    (11, sd_id, 'Poslovni administrator',             20),
    (11, sd_id, 'Administrativni radnik – evidencija', 30)
  ON CONFLICT DO NOTHING;

  -- ── 11 · Finansije i administracija — HR i organizacioni razvoj
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 11 AND name = 'HR i organizacioni razvoj';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (11, sd_id, 'Koordinator za ljudske resurse (HR)',        10),
    (11, sd_id, 'Saradnik za organizacioni razvoj i kučing',  20)
  ON CONFLICT DO NOTHING;

  -- ── 11 · Finansije i administracija — Finansije i pravo
  SELECT id INTO sd_id FROM public.sub_departments WHERE department_id = 11 AND name = 'Finansije i pravo';
  INSERT INTO public.job_positions (department_id, sub_department_id, name, sort_order)
  VALUES
    (11, sd_id, 'Računovođa / knjigovođa',        10),
    (11, sd_id, 'Eksterna advokatska kancelarija', 20)
  ON CONFLICT DO NOTHING;
END $$;

-- ── 5. FK KOLONE NA EMPLOYEES ──────────────────────────────────────────

ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS department_id     INTEGER REFERENCES public.departments(id),
  ADD COLUMN IF NOT EXISTS sub_department_id INTEGER REFERENCES public.sub_departments(id),
  ADD COLUMN IF NOT EXISTS position_id       INTEGER REFERENCES public.job_positions(id);

CREATE INDEX IF NOT EXISTS idx_employees_department_id     ON public.employees(department_id);
CREATE INDEX IF NOT EXISTS idx_employees_sub_department_id ON public.employees(sub_department_id);

-- ── 6. MIGRACIJA POSTOJEĆIH ZAPOSLENIH ────────────────────────────────
-- Mapa: stari tekst → novo odeljenje / pododeljenje

UPDATE public.employees e
SET
  department_id     = d.id,
  sub_department_id = sd.id
FROM public.departments d
LEFT JOIN public.sub_departments sd
  ON sd.department_id = d.id AND sd.name = 'Mašinska montaža'
WHERE e.department = 'Montaža'
  AND d.name = 'Montaža'
  AND e.department_id IS NULL;

UPDATE public.employees e
SET department_id = d.id
FROM public.departments d
WHERE e.department = 'Elektro'
  AND d.name = 'Automatika – Elektro'
  AND e.department_id IS NULL;

UPDATE public.employees e
SET department_id = d.id
FROM public.departments d
WHERE e.department = 'Proizvodnja'
  AND d.name = 'Proizvodnja'
  AND e.department_id IS NULL;

UPDATE public.employees e
SET department_id = d.id
FROM public.departments d
WHERE e.department = 'Projektovanje'
  AND d.name = 'Inženjering i projektovanje'
  AND e.department_id IS NULL;

UPDATE public.employees e
SET
  department_id     = d.id,
  sub_department_id = sd.id
FROM public.departments d
LEFT JOIN public.sub_departments sd
  ON sd.department_id = d.id AND sd.name = 'Administracija'
WHERE e.department = 'Administracija'
  AND d.name = 'Finansije i administracija'
  AND e.department_id IS NULL;

-- ── 7. RLS ────────────────────────────────────────────────────────────

ALTER TABLE public.departments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sub_departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_positions   ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "departments_select"    ON public.departments;
DROP POLICY IF EXISTS "departments_manage"    ON public.departments;
DROP POLICY IF EXISTS "sub_departments_select" ON public.sub_departments;
DROP POLICY IF EXISTS "sub_departments_manage" ON public.sub_departments;
DROP POLICY IF EXISTS "job_positions_select"  ON public.job_positions;
DROP POLICY IF EXISTS "job_positions_manage"  ON public.job_positions;

CREATE POLICY "departments_select"    ON public.departments FOR SELECT TO authenticated USING (true);
CREATE POLICY "departments_manage"    ON public.departments FOR ALL    TO authenticated
  USING      (public.current_user_is_admin())
  WITH CHECK (public.current_user_is_admin());

CREATE POLICY "sub_departments_select" ON public.sub_departments FOR SELECT TO authenticated USING (true);
CREATE POLICY "sub_departments_manage" ON public.sub_departments FOR ALL    TO authenticated
  USING      (public.current_user_is_admin())
  WITH CHECK (public.current_user_is_admin());

CREATE POLICY "job_positions_select"  ON public.job_positions FOR SELECT TO authenticated USING (true);
CREATE POLICY "job_positions_manage"  ON public.job_positions FOR ALL    TO authenticated
  USING      (public.current_user_is_admin())
  WITH CHECK (public.current_user_is_admin());

GRANT SELECT ON public.departments     TO authenticated;
GRANT SELECT ON public.sub_departments TO authenticated;
GRANT SELECT ON public.job_positions   TO authenticated;

-- ── 8. v_employees_safe — dodaj FK ID-jeve i JOIN-ovane nazive ─────────

DROP VIEW IF EXISTS public.v_employees_safe;

CREATE VIEW public.v_employees_safe AS
SELECT
  e.id,
  e.full_name,
  e.first_name,
  e.last_name,
  e.position,
  e.department,
  e.team,
  e.phone          AS phone_work,
  e.email,
  e.hire_date,
  e.is_active,
  e.note,
  e.birth_date,
  e.gender,
  e.slava,
  e.slava_day,
  e.education_level,
  e.education_title,
  e.medical_exam_date,
  e.medical_exam_expires,
  e.work_type,
  e.department_id,
  e.sub_department_id,
  e.position_id,
  d.name   AS department_name,
  sd.name  AS sub_department_name,
  jp.name  AS position_name,
  e.created_at,
  e.updated_at,
  CASE WHEN public.current_user_is_admin() THEN e.personal_id             ELSE NULL END AS personal_id,
  CASE WHEN public.current_user_is_admin() THEN e.bank_name               ELSE NULL END AS bank_name,
  CASE WHEN public.current_user_is_admin() THEN e.bank_account            ELSE NULL END AS bank_account,
  CASE WHEN public.current_user_is_admin() THEN e.address                 ELSE NULL END AS address,
  CASE WHEN public.current_user_is_admin() THEN e.city                    ELSE NULL END AS city,
  CASE WHEN public.current_user_is_admin() THEN e.postal_code             ELSE NULL END AS postal_code,
  CASE WHEN public.current_user_is_admin() THEN e.phone_private           ELSE NULL END AS phone_private,
  CASE WHEN public.current_user_is_admin() THEN e.emergency_contact_name  ELSE NULL END AS emergency_contact_name,
  CASE WHEN public.current_user_is_admin() THEN e.emergency_contact_phone ELSE NULL END AS emergency_contact_phone
FROM public.employees e
LEFT JOIN public.departments     d  ON d.id  = e.department_id
LEFT JOIN public.sub_departments sd ON sd.id = e.sub_department_id
LEFT JOIN public.job_positions   jp ON jp.id = e.position_id;

GRANT SELECT ON public.v_employees_safe TO authenticated;
ALTER VIEW public.v_employees_safe SET (security_invoker = true);

COMMENT ON VIEW public.v_employees_safe IS
  'Maskira JMBG/banku/adresu/privatni telefon za ne-admina. Uključuje nazive odeljenja/pododeljenja/radnog mesta.';
