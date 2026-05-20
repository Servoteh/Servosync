-- Kategorija Hidraulika za pod-tab u Saveti
BEGIN;

INSERT INTO public.pb_eng_tip_categories (naziv, slug, ikona, boja, redosled, je_aktivna)
VALUES ('Hidraulika', 'hidraulika', '💧', '#0284c7', 15, true)
ON CONFLICT (slug) DO UPDATE SET
  naziv = EXCLUDED.naziv,
  ikona = EXCLUDED.ikona,
  boja = EXCLUDED.boja,
  redosled = EXCLUDED.redosled,
  je_aktivna = true;

NOTIFY pgrst, 'reload schema';

COMMIT;
