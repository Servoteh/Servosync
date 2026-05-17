-- ============================================================================
-- add_loc_sync_monitor_dispatch_pulse.sql (Härd-3 nastavak)
-- ============================================================================
-- Nakon deploy-a Edge funkcije `loc-sync-monitor-dispatch`:
--   1) U Vault unesi ceo URL funkcije kao secret ime `loc_sync_monitor_dispatch_url`
--      (vidi README u supabase/functions/loc-sync-monitor-dispatch/).
--   2) Opciono secret `loc_sync_monitor_dispatch_bearer` = ceo Authorization
--      header (`Bearer <service_role_jwt>`) jer je funkcija bez verify_jwt —
--      bez bearer-a funkcija prima anonimni POST (URL mora ostati privatno).
--
-- Šta dodaje:
--   • CREATE EXTENSION pg_net (best-effort, ako tier dozvoljava)
--   • public.loc_sync_pulse_monitor_dispatch() — SECURITY DEFINER, poziva net.http_post
--   • pg_cron job `loc_sync_monitor_dispatch_every_5_min` — schedule */5 * * * *
--
-- DOWN (rollback):
--   SELECT cron.unschedule('loc_sync_monitor_dispatch_every_5_min');
--   DROP FUNCTION IF EXISTS public.loc_sync_pulse_monitor_dispatch();
-- ============================================================================

DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'add_loc_sync_monitor_dispatch_pulse: pg_net nije dostupan (%), cron pulse se neće registrovati', SQLERRM;
END $$;

CREATE OR REPLACE FUNCTION public.loc_sync_pulse_monitor_dispatch()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault, net
AS $fn_pulse$
DECLARE
  v_url             TEXT;
  v_bearer          TEXT;
  v_headers         jsonb;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RETURN;
  END IF;

  SELECT NULLIF(btrim(ds.decrypted_secret), '')
    INTO v_url
    FROM vault.decrypted_secrets ds
   WHERE ds.name = 'loc_sync_monitor_dispatch_url'
   LIMIT 1;

  IF v_url IS NULL THEN
    RETURN;
  END IF;

  SELECT btrim(ds.decrypted_secret)
    INTO v_bearer
    FROM vault.decrypted_secrets ds
   WHERE ds.name = 'loc_sync_monitor_dispatch_bearer'
   LIMIT 1;

  IF v_bearer IS NOT NULL AND length(v_bearer) > 0 THEN
    IF strpos(lower(v_bearer), 'bearer ') = 1 THEN
      v_headers := jsonb_build_object(
        'Authorization', v_bearer,
        'Content-Type', 'application/json'
      );
    ELSE
      v_headers := jsonb_build_object(
        'Authorization', 'Bearer ' || v_bearer,
        'Content-Type', 'application/json'
      );
    END IF;
  ELSE
    v_headers := jsonb_build_object('Content-Type', 'application/json');
  END IF;

  PERFORM net.http_post(
    url     := v_url,
    headers := v_headers,
    body    := '{}'::jsonb
  );
END;
$fn_pulse$;

COMMENT ON FUNCTION public.loc_sync_pulse_monitor_dispatch() IS
  'Härd-3: pg_net POST ka loc-sync-monitor-dispatch (Vault loc_sync_monitor_dispatch_url). Poziva cron job loc_sync_monitor_dispatch_every_5_min.';

REVOKE ALL ON FUNCTION public.loc_sync_pulse_monitor_dispatch() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_sync_pulse_monitor_dispatch() FROM anon, authenticated;

GRANT EXECUTE ON FUNCTION public.loc_sync_pulse_monitor_dispatch() TO postgres;

/* pg_cron job — kao i ostale lokacije CRON migracije sa graceful fallback */
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname IN ('pg_cron', 'pg_net')) THEN
    RAISE NOTICE 'loc_sync_monitor_dispatch_every_5_min: pg_cron ili pg_net nedostaje — cron se ne registruje.';
    RETURN;
  END IF;

  BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'loc_sync_monitor_dispatch_every_5_min') THEN
      PERFORM cron.unschedule('loc_sync_monitor_dispatch_every_5_min');
    END IF;
  EXCEPTION
    WHEN undefined_table THEN NULL;
    WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    PERFORM cron.schedule(
      'loc_sync_monitor_dispatch_every_5_min',
      '*/5 * * * *',
      $cron$SELECT public.loc_sync_pulse_monitor_dispatch();$cron$
    );
    RAISE NOTICE 'pg_cron job scheduled: loc_sync_monitor_dispatch_every_5_min */5';
  EXCEPTION
    WHEN undefined_table THEN
      RAISE NOTICE 'cron.schedule skipped (cron.job nije dostupan)';
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'cron.schedule skipped (insufficient_privilege)';
  END;
END $$;
