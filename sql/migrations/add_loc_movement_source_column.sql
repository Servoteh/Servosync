-- ============================================================================
-- LOKACIJE × MAŠINE — Faza 1: source kolona na loc_location_movements
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru (idempotentno).
--
-- Šta radi:
--   Dodaje `source TEXT NOT NULL DEFAULT 'manual'` na `loc_location_movements`.
--   U Fazi 1 svi pokreti su 'manual' (operater u UI-ju klikne „Premesti").
--   U Fazi 2 worker koji ingest-uje BigTehn prijave umetaće redove sa
--   `source = 'bigtehn'`; trigger na outbound sync-u će tada filtrirati te
--   redove da NE idu MSSQL strani (sprečava sync loop, jer signal je
--   originalno došao iz MSSQL-a).
--
-- ŠTA NE RADI:
--   - Trigger `loc_after_movement_insert` se NE menja u Fazi 1. Svi pokreti
--     i dalje idu u `loc_sync_outbound_events`. Filtriranje po source kolono
--     postoji u Fazi 2 zajedno sa worker-om.
--
-- DOWN:
--   ALTER TABLE public.loc_location_movements DROP COLUMN IF EXISTS source;
-- ============================================================================

ALTER TABLE public.loc_location_movements
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'manual';

/* Tight whitelist da nekoga slučajno ne dovedu u napast da unese random tekst. */
DO $$ BEGIN
  ALTER TABLE public.loc_location_movements
    ADD CONSTRAINT loc_location_movements_source_chk
    CHECK (source IN ('manual','bigtehn','correction','reversi','api'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

/* Indeks samo na ne-manual vrednosti — manual je 99% redova, ne treba index. */
CREATE INDEX IF NOT EXISTS loc_location_movements_source_nonmanual_idx
  ON public.loc_location_movements (source)
  WHERE source <> 'manual';

COMMENT ON COLUMN public.loc_location_movements.source IS
  'Izvor pokreta. „manual" = operater ručno (default Faze 1). „bigtehn" = '
  'rezervisano za Faza 2 worker (ingest iz bigtehn_tech_routing_cache). '
  '„correction" = explicit ispravka. „reversi" = automatika iz Reversi modula.';

-- ── Sanity ──────────────────────────────────────────────────────────────────
DO $sanity$
DECLARE
  v_has_col BOOLEAN;
  v_has_chk BOOLEAN;
BEGIN
  v_has_col := EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema='public' AND table_name='loc_location_movements'
       AND column_name='source'
  );
  v_has_chk := EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname='loc_location_movements_source_chk'
  );
  IF NOT (v_has_col AND v_has_chk) THEN
    RAISE EXCEPTION 'add_loc_movement_source_column failed: col=%, chk=%', v_has_col, v_has_chk;
  END IF;
  RAISE NOTICE 'add_loc_movement_source_column OK.';
END $sanity$;
