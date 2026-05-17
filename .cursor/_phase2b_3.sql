-- ── 4) Update pg_cron schedule da koristi defaults ─────────────────────────
DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    BEGIN
      IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'loc_bigtehn_ingest_5min') THEN
        PERFORM cron.unschedule('loc_bigtehn_ingest_5min');
      END IF;
    EXCEPTION WHEN undefined_table THEN NULL;
              WHEN insufficient_privilege THEN NULL;
    END;

    BEGIN
      PERFORM cron.schedule(
        'loc_bigtehn_ingest_5min',
        '*/5 * * * *',
        $cron_call$SELECT public.loc_bigtehn_ingest_run()$cron_call$
      );
    EXCEPTION WHEN undefined_table THEN NULL;
              WHEN insufficient_privilege THEN NULL;
    END;
  END IF;
END
$cron$;

-- ── 5) Sanity ───────────────────────────────────────────────────────────────
DO $sanity$
DECLARE
  v_has_user   BOOLEAN;
  v_has_trig   BOOLEAN;
  v_has_run_fn BOOLEAN;
BEGIN
  v_has_user := EXISTS (
    SELECT 1 FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000099'
  );
  v_has_trig := EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname='public' AND p.proname='loc_after_movement_insert'
  );
  v_has_run_fn := EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname='public' AND p.proname='loc_bigtehn_ingest_run'
  );

  IF NOT (v_has_user AND v_has_trig AND v_has_run_fn) THEN
    RAISE EXCEPTION
      'add_loc_phase2b_bigtehn_ingest_armed sanity failed: user=%, trig=%, fn=%',
      v_has_user, v_has_trig, v_has_run_fn;
  END IF;

  RAISE NOTICE 'add_loc_phase2b_bigtehn_ingest_armed OK. Worker je SPREMAN. armed=FALSE i dalje (sigurnosno). Da aktiviraš: SELECT loc_bigtehn_ingest_arm(TRUE);';
END
$sanity$;
