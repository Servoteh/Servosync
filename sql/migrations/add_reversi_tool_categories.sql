-- ============================================================================
-- REVERSI — kategorija na rev_tools (alat / odelo / oprema / zaštitna)
-- ============================================================================
-- Cilj: razdvojiti ručne alate od radne odeće, opreme, zaštitne opreme itd.
-- u istoj tabeli rev_tools (jedna jedinica = jedan red).
--
-- Vrednosti su slobodan tekst; UI predefiniše: 'alat', 'odelo', 'oprema',
-- 'zastitna_oprema', 'merni'. NULL je dozvoljeno (postojeći redovi pre ove
-- migracije nemaju kategoriju i ostaju NULL = 'alat' u UI default-u).
--
-- Idempotentno.
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'rev_tools'
      AND column_name = 'kategorija'
  ) THEN
    ALTER TABLE public.rev_tools
      ADD COLUMN kategorija text;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS rev_tools_kategorija_idx
  ON public.rev_tools (kategorija)
  WHERE kategorija IS NOT NULL;

COMMENT ON COLUMN public.rev_tools.kategorija IS
  'Slobodan klasifikator: alat / odelo / oprema / zastitna_oprema / merni / ostalo. NULL = legacy red bez kategorije (UI tretira kao "alat").';
