-- ============================================================================
-- SEED: Master lokacije iz BigTehn `dbo.tPozicije` (snimljeno sa servera)
-- ============================================================================
-- JEDNOKRATNA skripta. Idempotentna — bezbedna za ponovno pokretanje.
-- Sadrži 25 realnih polica; preskače placeholder redove `-`, `DEFINISI POLICU`
-- i `H2` koji nisu stvarne police.
--
-- Pokreni u Supabase SQL Editoru (paste celog fajla → Run).
-- ============================================================================

-- ── A — ROOT + VIRTUALNE LOKACIJE ───────────────────────────────────────────
-- MAG       : parent za većinu K-polica (BigTehn flat hijerarhija).
-- HALA 2    : K-kontrolni set K-A1..5, K-B1..5, K-C1..5, K-M (fizički u Hali 2).
-- UGRADJENO : komad ušao u finalni sklop — izlazi iz bilansa.
-- PROIZVODNJA: komad je WIP (u radu), još nije završen.
-- OTPISANO  : softverski škart (za razliku od K-S koji je fizička polica).
INSERT INTO public.loc_locations (location_code, name, location_type, parent_id, is_active)
VALUES
  ('MAG',         'Centralni magacin',                'WAREHOUSE',  NULL, true),
  ('UGRADJENO',   'Ugrađeno u finalni proizvod',      'ASSEMBLY',   NULL, true),
  ('PROIZVODNJA', 'U proizvodnji (work-in-progress)', 'PRODUCTION', NULL, true),
  ('OTPISANO',    'Otpisano / softverski škart',      'SCRAPPED',   NULL, true)
ON CONFLICT (location_code) DO NOTHING;

-- Hala 2 — fizička hala za K-kontrolne police (K-A1..5, K-B1..5, K-C1..5, K-M).
INSERT INTO public.loc_locations (location_code, name, location_type, parent_id, is_active)
VALUES ('HALA 2', 'Hala 2', 'WAREHOUSE', NULL, true)
ON CONFLICT (location_code) DO NOTHING;

-- ── B — POLICE IZ tPozicije (25 redova) ─────────────────────────────────────
-- K-kontrolni set pod HALA 2; ostale K-* police ostaju pod MAG (BigTehn flat hijerarhija).
WITH
mag AS (SELECT id FROM public.loc_locations WHERE location_code = 'MAG' LIMIT 1),
h2 AS (SELECT id FROM public.loc_locations WHERE location_code = 'HALA 2' LIMIT 1),
src (code, naziv, under_hala2) AS (
  VALUES
    ('K-A1',  'FARBANJE', true),
    ('K-A2',  'FARBANJE', true),
    ('K-A3',  'FARBANJE', true),
    ('K-A4',  'FARBANJE', true),
    ('K-A5',  'FARBANJE', true),
    ('K-A6',  'FARBANJE', false),
    ('K-B1',  'ZAVARIVANJE', true),
    ('K-B2',  'ZAVARIVANJE', true),
    ('K-B3',  'ZAVARIVANJE', true),
    ('K-B4',  'ZAVARIVANJE', true),
    ('K-B5',  'ZAVARIVANJE', true),
    ('K-B6',  'ZAVARIVANJE', false),
    ('K-C1',  'ZAVRŠNA', true),
    ('K-C2',  'ZAVRŠNA', true),
    ('K-C3',  'ZAVRŠNA', true),
    ('K-C4',  'ZAVRŠNA', true),
    ('K-C5',  'ZAVRŠNA', true),
    ('K-C6',  'ZAVRŠNA', false),
    ('K-D',   'DORADA', false),
    ('K-M',   'MONTAZA', true),
    ('K-MG',  'MAGACIN', false),
    ('K-MG3', 'MAGACIN_H3', false),
    ('K-MG4', 'MAGACIN_H4', false),
    ('K-MG8', 'MAGACIN_H8', false),
    ('K-S',   'ŠKART', false)
),
ins AS (
  INSERT INTO public.loc_locations (location_code, name, location_type, parent_id, is_active)
  SELECT
    s.code,
    s.naziv,
    'SHELF'::public.loc_type_enum,
    CASE WHEN s.under_hala2 THEN (SELECT id FROM h2) ELSE (SELECT id FROM mag) END,
    true
  FROM src s
  ON CONFLICT (location_code) DO NOTHING
  RETURNING 1
)
SELECT
  (SELECT count(*) FROM src) AS u_ulazu,
  (SELECT count(*) FROM ins) AS ubacenih_novih,
  (SELECT count(*) FROM src) - (SELECT count(*) FROM ins) AS preskocenih_duplikata;

-- ── C — SANITY CHECK (automatski) ───────────────────────────────────────────
-- Pregled svega što je ubačeno, grupisano po tipu.
SELECT location_type, count(*) AS broj, string_agg(location_code, ', ' ORDER BY location_code) AS kodovi
FROM public.loc_locations
GROUP BY location_type
ORDER BY location_type;
