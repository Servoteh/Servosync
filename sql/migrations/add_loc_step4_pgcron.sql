-- ============================================================================
-- LOKACIJE DELOVA — pg_cron job za periodičnu retenciju SYNCED event-a
-- ============================================================================
-- Preduslovi:
--   • Supabase projekat (PAID tier) — pg_cron je dostupan u `extensions` šemi.
--   • Već primenjeni: add_loc_module.sql, add_loc_step3_cleanup.sql.
--
-- Šta radi ova migracija:
--   1) Kreira SECURITY DEFINER funkciju `_loc_purge_synced_events_cron(days)`
--      koja NE proverava admin rolu — zove se samo iz cron-a pod Postgres
--      superuser identitetom. Odvojena je od `loc_purge_synced_events` da
--      zadrži admin gating kada se zove iz UI-ja / RPC-a.
--   2) REVOKE prava svima osim `postgres` — auth korisnici ne mogu direktno.
--   3) Raspoređuje dnevni job u 03:15 UTC za čišćenje `SYNCED` event-a
--      starijih od 90 dana (retencija).
--
-- DOWN (rollback):
--   SELECT cron.unschedule('loc_purge_synced_daily');
--   DROP FUNCTION IF EXISTS public._loc_purge_synced_events_cron(integer);
-- ============================================================================

-- ── pg_cron (Supabase ga isporučuje u `extensions` šemi) ─────────────────
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- ── Interna cron-only verzija (bez admin check-a) ────────────────────────
CREATE OR REPLACE FUNCTION public._loc_purge_synced_events_cron(p_retention_days integer DEFAULT 90)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_days integer := GREATEST(1, COALESCE(p_retention_days, 90));
  v_deleted integer;
BEGIN
  DELETE FROM public.loc_sync_outbound_events
   WHERE status = 'SYNCED'
     AND synced_at IS NOT NULL
     AND synced_at < (now() - make_interval(days => v_days));
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  /* Lightweight audit u `loc_sync_outbound_events` nije potreban — broj
   * obrisanih redova ostaje u cron.job_run_details (pg_cron metadata). */
  RETURN v_deleted;
END;
$$;

REVOKE ALL ON FUNCTION public._loc_purge_synced_events_cron(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._loc_purge_synced_events_cron(integer) FROM anon, authenticated;

COMMENT ON FUNCTION public._loc_purge_synced_events_cron(integer) IS
  'Internal cron-only helper. NE zovi direktno — koristi se iz pg_cron job-a "loc_purge_synced_daily".';

-- ── Scheduled job ─────────────────────────────────────────────────────────
-- 03:15 UTC svakog dana. Ako job već postoji (re-run migracije), unschedule-uj prvo.
-- Koristimo EXISTS inline + EXCEPTION fallback (ako `cron` šema nije vidljiva
-- pod trenutnom rolom, tiho preskačemo — CREATE EXTENSION gore postavlja grant-ove).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'loc_purge_synced_daily') THEN
    PERFORM cron.unschedule('loc_purge_synced_daily');
  END IF;
EXCEPTION
  WHEN undefined_table THEN
    /* cron.job nije vidljiv (npr. pg_cron nije instaliran / nema privilegija).
     * SELECT cron.schedule(...) ispod će svejedno pokušati i dati jasnu grešku. */
    NULL;
  WHEN insufficient_privilege THEN
    NULL;
END $$;

SELECT cron.schedule(
  'loc_purge_synced_daily',
  '15 3 * * *',
  $cron$SELECT public._loc_purge_synced_events_cron(90)$cron$
);

-- ── Verifikacija (samo za ručni re-run u SQL editoru) ────────────────────
-- SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = 'loc_purge_synced_daily';
-- SELECT * FROM cron.job_run_details WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'loc_purge_synced_daily') ORDER BY start_time DESC LIMIT 10;
