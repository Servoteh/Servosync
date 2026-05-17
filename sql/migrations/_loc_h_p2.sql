-- ── 7) Dispatch API za Edge funkciju ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.loc_sync_dispatch_dequeue(p_batch INT DEFAULT 25)
RETURNS SETOF public.loc_sync_alerts_outbox
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_deq$
DECLARE
  v_batch INT := GREATEST(1, LEAST(COALESCE(p_batch, 25), 100));
BEGIN
  RETURN QUERY
  WITH candidate AS (
    SELECT id
      FROM public.loc_sync_alerts_outbox
     WHERE status IN ('queued', 'failed')
       AND next_attempt_at <= now()
       AND attempts < max_attempts
     ORDER BY next_attempt_at ASC
     LIMIT v_batch
     FOR UPDATE SKIP LOCKED
  ),
  locked AS (
    UPDATE public.loc_sync_alerts_outbox o
       SET last_attempt_at = now(),
           attempts        = o.attempts + 1
      FROM candidate c
     WHERE o.id = c.id
     RETURNING o.*
  )
  SELECT * FROM locked;
END;
$fn_deq$;

REVOKE ALL ON FUNCTION public.loc_sync_dispatch_dequeue(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_sync_dispatch_dequeue(INT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.loc_sync_dispatch_dequeue(INT) TO service_role;

CREATE OR REPLACE FUNCTION public.loc_sync_dispatch_mark_sent(p_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_ms$
DECLARE v_count INT;
BEGIN
  UPDATE public.loc_sync_alerts_outbox
     SET status = 'sent', sent_at = now(), error = NULL
   WHERE id = p_id AND status IN ('queued', 'failed');
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count > 0;
END;
$fn_ms$;

CREATE OR REPLACE FUNCTION public.loc_sync_dispatch_mark_failed(p_id UUID, p_error TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_mf$
DECLARE
  v_attempts  INT;
  v_max       INT;
  v_count     INT;
  v_delay_min INT;
  v_final     BOOLEAN;
BEGIN
  SELECT attempts, max_attempts INTO v_attempts, v_max
    FROM public.loc_sync_alerts_outbox WHERE id = p_id;
  IF v_attempts IS NULL THEN RETURN false; END IF;

  v_delay_min := LEAST(360, POWER(2, LEAST(v_attempts, 8))::int);
  v_final := v_attempts >= COALESCE(v_max, 5);

  UPDATE public.loc_sync_alerts_outbox
     SET status        = CASE WHEN v_final THEN 'skipped' ELSE 'failed' END,
         error         = LEFT(COALESCE(p_error, ''), 4000),
         next_attempt_at = CASE WHEN v_final THEN now() ELSE now() + make_interval(mins => v_delay_min) END
   WHERE id = p_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count > 0;
END;
$fn_mf$;

REVOKE ALL ON FUNCTION public.loc_sync_dispatch_mark_sent(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_sync_dispatch_mark_sent(UUID) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.loc_sync_dispatch_mark_sent(UUID) TO service_role;

REVOKE ALL ON FUNCTION public.loc_sync_dispatch_mark_failed(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_sync_dispatch_mark_failed(UUID, TEXT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.loc_sync_dispatch_mark_failed(UUID, TEXT) TO service_role;

-- ── 8) pg_cron job: svaki sat proveri zdravlje ────────────────────────────
/* Postojeća migracija add_loc_step4_pgcron.sql ima EXCEPTION handler za
 * `undefined_table` (kad pg_cron nije dostupan u CI). Pratimo isti obrazac. */
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    /* Unschedule postojeći job ako se migracija reruna. */
    BEGIN
      IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'loc_sync_health_check_hourly') THEN
        PERFORM cron.unschedule('loc_sync_health_check_hourly');
      END IF;
    EXCEPTION WHEN undefined_table THEN NULL;
              WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
      PERFORM cron.schedule(
        'loc_sync_health_check_hourly',
        '15 * * * *',
        $cron$SELECT public.loc_sync_health_check_and_enqueue()$cron$
      );
    EXCEPTION WHEN undefined_table THEN NULL;
              WHEN insufficient_privilege THEN NULL;
    END;
  END IF;
END $$;

-- ── 9) Sanity check ───────────────────────────────────────────────────────
DO $sanity$
DECLARE
  v_hb_table   BOOLEAN;
  v_alerts     BOOLEAN;
  v_health_fn  BOOLEAN;
BEGIN
  v_hb_table := EXISTS(
    SELECT 1 FROM information_schema.tables
     WHERE table_schema='public' AND table_name='loc_sync_worker_heartbeat'
  );
  v_alerts := EXISTS(
    SELECT 1 FROM information_schema.tables
     WHERE table_schema='public' AND table_name='loc_sync_alerts_outbox'
  );
  v_health_fn := EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname='public' AND p.proname='loc_sync_health_check_and_enqueue'
  );

  IF NOT (v_hb_table AND v_alerts AND v_health_fn) THEN
    RAISE EXCEPTION 'add_loc_sync_health_monitor sanity failed: hb=%, alerts=%, fn=%',
      v_hb_table, v_alerts, v_health_fn;
  END IF;

  RAISE NOTICE 'add_loc_sync_health_monitor OK (heartbeat + outbox + dispatch + cron).';
END
$sanity$;