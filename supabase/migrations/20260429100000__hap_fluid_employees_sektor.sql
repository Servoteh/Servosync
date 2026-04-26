-- HAP Fluid — sektor u employees prema ažuriranoj listi (apr. 2026)
-- Detalj: docs/reports/hap_fluid_sektor_referenca.md
BEGIN;
SET statement_timeout = '120s';

-- 1) Primarni tim HAP Fluid (full_name = Prezime Ime, kao u public.employees)
UPDATE public.employees
SET
  department = 'HAP Fluid',
  updated_at = now()
WHERE full_name IN (
  'Elek Dragan',
  'Knezevic Nevena',
  'Kostic Dusko',
  'Hajnal Milos',
  'Lukić Nebojša',
  'Mirić Stefan',
  'Obric Andjela',
  'Blagojevic Jovan',
  'Savić Nikola'
);

-- Nikola Savić: komercijalista (zamenio Petra Vaskovića u ulozi u timu)
UPDATE public.employees
SET
  position = 'Komercijalista',
  updated_at = now()
WHERE full_name = 'Savić Nikola';

-- 2) Dragoslav Bajazetov (penzioner) — u listi, često fali u bazi
INSERT INTO public.employees (full_name, department, position, is_active, note)
SELECT
  'Bajazetov Dragoslav',
  'HAP Fluid',
  'Penzioner',
  true,
  'HAP Fluid referenca (apr. 2026), penzioner.'
WHERE NOT EXISTS (
  SELECT 1 FROM public.employees e
  WHERE e.full_name = 'Bajazetov Dragoslav'
     OR (btrim(e.last_name) ILIKE 'bajazetov' AND btrim(e.first_name) ILIKE 'dragoslav')
);

-- 3) Više nisu HAP po novoj listi (starija uvezena evidencija)
UPDATE public.employees
SET
  department = 'Servoteh',
  updated_at = now()
WHERE full_name IN (
  'Janković Mihajlo',
  'Radelić Uroš'
)
  AND department = 'HAP Fluid';

-- 4) Petar Vasković — ne radi; učlanjenje u HAP nije u pitanju
UPDATE public.employees
SET
  is_active = false,
  updated_at = now()
WHERE full_name IN ('Vaskovic Petar', 'Vasković Petar');

COMMIT;
