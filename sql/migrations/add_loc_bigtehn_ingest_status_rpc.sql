-- ============================================================================
-- LOKACIJE × MAŠINE — Faza 2C: BigTehn ingest worker status RPC (admin UI)
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru (idempotentno, CREATE OR REPLACE).
--
-- ŠTA DODAJE:
--   1) `loc_get_bigtehn_ingest_status()` — admin-only RPC koja vraća jedan
--      JSONB sa state-om worker-a (armed flag, watermark, last_run_at,
--      `last_run_summary` JSONB), plus heartbeat row iz
--      `loc_sync_worker_heartbeat` za `worker_id='loc-bigtehn-ingest'`.
--      Cilj: admin UI panel u Lokacije → Sync tabu može jednim pozivom da
--      pokupi sve što treba za render (status badge, by_action histogram,
--      lista samples).
--
--   2) `loc_bigtehn_ingest_run_now()` — admin-only wrapper koji ručno
--      pokreće `loc_bigtehn_ingest_run()` (default args). Korisno za
--      observation period: admin klikne dugme „Pokreni sada" i odmah vidi
--      sample-ove iz poslednjeg pozivanja umesto da čeka pg_cron 5min slot.
--
-- ZAVISI OD: `add_loc_phase2a_bigtehn_ingest_dryrun.sql` (state tabela +
--            `loc_is_admin()` + `loc_bigtehn_ingest_run`).
--
-- DOWN:
--   DROP FUNCTION IF EXISTS public.loc_get_bigtehn_ingest_status();
--   DROP FUNCTION IF EXISTS public.loc_bigtehn_ingest_run_now();
-- ============================================================================

-- ── 1) Status RPC ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.loc_get_bigtehn_ingest_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_state     RECORD;
  v_hb        RECORD;
  v_age_sec   NUMERIC;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'error', 'not_authenticated');
  END IF;
  IF NOT public.loc_is_admin() THEN
    RETURN jsonb_build_object('ok', FALSE, 'error', 'not_admin');
  END IF;

  SELECT worker_id, last_processed_signal_id, armed, last_run_at,
         last_run_summary, created_at, updated_at
    INTO v_state
    FROM public.loc_bigtehn_ingest_state
   WHERE worker_id = 'loc-bigtehn-ingest'
   LIMIT 1;

  IF v_state.worker_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', FALSE,
      'error', 'state_missing',
      'detail', 'loc_bigtehn_ingest_state nije seedovan — pokreni Faza 2A migraciju.'
    );
  END IF;

  /* Heartbeat row (opciono — može da nedostaje ako worker nikad nije pokrenut). */
  SELECT worker_id, last_seen, details
    INTO v_hb
    FROM public.loc_sync_worker_heartbeat
   WHERE worker_id = 'loc-bigtehn-ingest'
   LIMIT 1;

  IF v_hb.worker_id IS NOT NULL THEN
    v_age_sec := EXTRACT(EPOCH FROM (now() - v_hb.last_seen))::numeric(12,1);
  END IF;

  RETURN jsonb_build_object(
    'ok', TRUE,
    'state', jsonb_build_object(
      'worker_id',              v_state.worker_id,
      'armed',                  v_state.armed,
      'watermark',              v_state.last_processed_signal_id,
      'last_run_at',            v_state.last_run_at,
      'last_run_summary',       v_state.last_run_summary,
      'updated_at',             v_state.updated_at
    ),
    'heartbeat', CASE
      WHEN v_hb.worker_id IS NULL THEN NULL
      ELSE jsonb_build_object(
        'last_seen',        v_hb.last_seen,
        'age_seconds',      v_age_sec,
        'is_alive',         (v_age_sec IS NOT NULL AND v_age_sec < 600),
        'details',          v_hb.details
      )
    END,
    'server_now', now()
  );
EXCEPTION WHEN others THEN
  RETURN jsonb_build_object('ok', FALSE, 'error', 'exception', 'detail', SQLERRM);
END;
$fn$;

REVOKE ALL ON FUNCTION public.loc_get_bigtehn_ingest_status() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_get_bigtehn_ingest_status() FROM anon;
GRANT EXECUTE ON FUNCTION public.loc_get_bigtehn_ingest_status() TO authenticated;

COMMENT ON FUNCTION public.loc_get_bigtehn_ingest_status() IS
  'Admin-only status worker-a za BigTehn ingest. Vraća state (armed, watermark, '
  'last_run_summary) + heartbeat (last_seen, is_alive). Koristi se u Lokacije → '
  'Sync admin panelu za monitoring dry-run i armed režima.';

-- ── 2) Ručno pokretanje worker-a (admin) ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.loc_bigtehn_ingest_run_now()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'error', 'not_authenticated');
  END IF;
  IF NOT public.loc_is_admin() THEN
    RETURN jsonb_build_object('ok', FALSE, 'error', 'not_admin');
  END IF;

  /* Default-i kao u pg_cron pozivu — 200 signala, 30 dana safety net. */
  v_result := public.loc_bigtehn_ingest_run();
  RETURN v_result;
EXCEPTION WHEN others THEN
  RETURN jsonb_build_object('ok', FALSE, 'error', 'exception', 'detail', SQLERRM);
END;
$fn$;

REVOKE ALL ON FUNCTION public.loc_bigtehn_ingest_run_now() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_bigtehn_ingest_run_now() FROM anon;
GRANT EXECUTE ON FUNCTION public.loc_bigtehn_ingest_run_now() TO authenticated;

COMMENT ON FUNCTION public.loc_bigtehn_ingest_run_now() IS
  'Admin-only manual trigger za loc_bigtehn_ingest_run() (default args). '
  'Korisno za observation period — admin može da pokrene worker odmah iz '
  'UI-a umesto da čeka 5-min pg_cron slot.';

-- ── 3) Sanity ───────────────────────────────────────────────────────────────
DO $sanity$
DECLARE
  v_has_status BOOLEAN;
  v_has_run    BOOLEAN;
BEGIN
  v_has_status := EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname='public' AND p.proname='loc_get_bigtehn_ingest_status'
  );
  v_has_run := EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname='public' AND p.proname='loc_bigtehn_ingest_run_now'
  );
  IF NOT (v_has_status AND v_has_run) THEN
    RAISE EXCEPTION
      'add_loc_bigtehn_ingest_status_rpc sanity failed: status=%, run_now=%',
      v_has_status, v_has_run;
  END IF;
  RAISE NOTICE 'add_loc_bigtehn_ingest_status_rpc OK. Admin može da poziva loc_get_bigtehn_ingest_status() i loc_bigtehn_ingest_run_now() iz UI-a.';
END
$sanity$;
