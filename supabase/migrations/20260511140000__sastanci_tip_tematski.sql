-- Dodaje tip sastanka 'tematski' (usklađivanje između birova/sektora, jedna glavna tema).
-- Kolona tip koristi CHECK constraint — mora se zameniti celokupan skup dozvoljenih vrednosti.

ALTER TABLE public.sastanci DROP CONSTRAINT IF EXISTS sastanci_tip_check;

ALTER TABLE public.sastanci
  ADD CONSTRAINT sastanci_tip_check
  CHECK (tip IN ('sedmicni', 'projektni', 'tematski'));

COMMENT ON COLUMN public.sastanci.tip IS
  'sedmicni = PM teme + akcioni plan; projektni = presek stanja; tematski = cross-sektor tema + isti tok kao sedmični.';
