-- ============================================================================
-- LOKACIJE × MAŠINE — Faza 2A: BigTehn ingest worker (DRY-RUN mode)
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru (idempotentno).
--
-- ŠTA DODAJE:
--   1) `loc_bigtehn_ingest_state` — single-row tabela sa watermark-om i `armed`
--      flag-om koji kontroliše ponašanje worker-a (dry-run vs aktivno).
--   2) `loc_bigtehn_ingest_run(p_max_signals)` — funkcija koju pg_cron poziva
--      svakih 5 minuta. Skenira nove `bigtehn_tech_routing_cache` redove
--      (id > watermark) i ANALIZIRA šta bi uradila za svaki: TRANSFER sa
--      police, chain TRANSFER sa druge mašine, INITIAL_PLACEMENT na mašinu,
--      ili SKIP (već je tu). U DRY-RUN modu (armed=FALSE) samo loguje
--      analizu u state.last_run_summary, NE pravi pokrete.
--   3) `loc_bigtehn_ingest_arm(BOOLEAN)` — admin RPC koji prebacuje armed flag.
--      `armed=TRUE` aktivira pravi rad (Faza 2B funkcionalnost — generisanje
--      TRANSFER-a). Ostavlja se za sledeću migraciju da implementira ARMED granu.
--   4) pg_cron job `loc_bigtehn_ingest_5min` — `*/5 * * * *`.
--   5) Heartbeat — reuse `loc_sync_worker_heartbeat_upsert` iz Härd-3.
--
-- ŠTA NE RADI (Faza 2B će dodati):
--   - Nema stvarnog generisanja TRANSFER-a čak ni kad `armed=TRUE`. Funkcija
--     prepoznaje akciju i loguje, ali grana koja zove `loc_create_movement`
--     dolazi u sledećoj migraciji.
--   - Nema trigger filtera za `source='bigtehn'` u outbox-u (čeka 2B).
--
-- KAKO TESTIRATI:
--   1) Pokreni migraciju.
--   2) Sačekaj 5 min (ili pokreni ručno: `SELECT loc_bigtehn_ingest_run();`).
--   3) Pogledaj `SELECT * FROM loc_bigtehn_ingest_state;` — vidi
--      `last_run_summary` JSONB sa brojem analiziranih signala po akciji.
--   4) `SELECT * FROM loc_sync_worker_heartbeat WHERE worker_id='loc-bigtehn-ingest';`
--      vidi heartbeat.
--   5) Posle nedelje produkcijskog dry-run-a, kad si zadovoljan analizom,
--      pokreni 2B migraciju i pozovi `loc_bigtehn_ingest_arm(TRUE)`.
--
-- DOWN:
--   SELECT cron.unschedule('loc_bigtehn_ingest_5min');
--   DROP FUNCTION IF EXISTS public.loc_bigtehn_ingest_run(INT);
--   DROP FUNCTION IF EXISTS public.loc_bigtehn_ingest_arm(BOOLEAN);
--   DROP TABLE IF EXISTS public.loc_bigtehn_ingest_state;
-- ============================================================================

-- ── 1) State table ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.loc_bigtehn_ingest_state (
  worker_id                 TEXT PRIMARY KEY,
  last_processed_signal_id  BIGINT NOT NULL DEFAULT 0,
  armed                     BOOLEAN NOT NULL DEFAULT FALSE,
  last_run_at               TIMESTAMPTZ,
  last_run_summary          JSONB,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.loc_bigtehn_ingest_state IS
  'Faza 2: state worker-a koji ingest-uje BigTehn prijave u Lokacije placement. '
  'armed=FALSE = dry-run (loguje šta bi uradio); armed=TRUE = pravi TRANSFER-i (Faza 2B).';

COMMENT ON COLUMN public.loc_bigtehn_ingest_state.armed IS
  'Kontrolni flag. FALSE = analiza bez side-effect-a (Faza 2A). TRUE = generiše '
  'TRANSFER pokrete iz BigTehn prijava (Faza 2B mora biti deployovana).';

COMMENT ON COLUMN public.loc_bigtehn_ingest_state.last_processed_signal_id IS
  'Watermark: max(bigtehn_tech_routing_cache.id) iz prethodnog run-a. Sledeći '
  'run obrađuje samo id > watermark.';

-- Seed jedan red ako ne postoji.
INSERT INTO public.loc_bigtehn_ingest_state (worker_id, last_processed_signal_id, armed)
VALUES ('loc-bigtehn-ingest', 0, FALSE)
ON CONFLICT (worker_id) DO NOTHING;

-- updated_at trigger
DROP TRIGGER IF EXISTS loc_bigtehn_ingest_state_touch ON public.loc_bigtehn_ingest_state;
CREATE TRIGGER loc_bigtehn_ingest_state_touch
  BEFORE UPDATE ON public.loc_bigtehn_ingest_state
  FOR EACH ROW EXECUTE FUNCTION public.loc_touch_updated_at();

ALTER TABLE public.loc_bigtehn_ingest_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loc_bigtehn_ingest_state FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS loc_bigtehn_ingest_state_select ON public.loc_bigtehn_ingest_state;
CREATE POLICY loc_bigtehn_ingest_state_select ON public.loc_bigtehn_ingest_state
  FOR SELECT TO authenticated USING (TRUE);

/* UPDATE samo kroz SECURITY DEFINER funkcije ispod. */

-- ── 2) Worker function (DRY-RUN) ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.loc_bigtehn_ingest_run(p_max_signals INT DEFAULT 200)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_run$
DECLARE
  v_armed                 BOOLEAN;
  v_watermark             BIGINT;
  v_new_watermark         BIGINT;
  v_signal                RECORD;
  v_count_total           INT := 0;
  v_count_no_machine_loc  INT := 0;
  v_count_skip_already    INT := 0;
  v_count_chain_transfer  INT := 0;
  v_count_shelf_transfer  INT := 0;
  v_count_initial         INT := 0;
  v_count_armed_executed  INT := 0;
  v_count_armed_skipped   INT := 0;
  v_action_samples        JSONB := '[]'::jsonb;
  v_max_samples           CONST INT := 25;
  v_started_at            TIMESTAMPTZ := now();

  /* per-signal */
  v_order_no              TEXT;
  v_tp_no                 TEXT;
  v_machine_loc_id        UUID;
  v_current_loc_id        UUID;
  v_current_loc_code      TEXT;
  v_current_loc_type      TEXT;
  v_current_qty           NUMERIC;
  v_action                TEXT;
  v_sample                JSONB;
BEGIN
  /* Read state. */
  SELECT armed, last_processed_signal_id
    INTO v_armed, v_watermark
    FROM public.loc_bigtehn_ingest_state
   WHERE worker_id = 'loc-bigtehn-ingest'
   FOR UPDATE;

  IF v_armed IS NULL THEN
    /* State row missing — seed and retry. */
    INSERT INTO public.loc_bigtehn_ingest_state (worker_id, last_processed_signal_id, armed)
    VALUES ('loc-bigtehn-ingest', 0, FALSE)
    ON CONFLICT (worker_id) DO NOTHING;
    v_armed := FALSE;
    v_watermark := 0;
  END IF;

  v_new_watermark := v_watermark;

  /* Process new signals (started_at NOT NULL = komad je krenuo na mašinu).
   * Sortirano po id ASC da chain detection vidi prirodni redosled prijava.
   * LIMIT cap je zaštita od velikog backlog-a (npr. prvi run posle deploy-a). */
  FOR v_signal IN
    SELECT tr.id, tr.work_order_id, tr.ident_broj, tr.operacija, tr.machine_code,
           tr.komada, tr.started_at, tr.finished_at, tr.is_completed,
           NULLIF(trim(tr.potpis), '') AS potpis
      FROM public.bigtehn_tech_routing_cache tr
     WHERE tr.id > v_watermark
       AND tr.started_at IS NOT NULL
       AND tr.machine_code IS NOT NULL
       AND tr.ident_broj IS NOT NULL
     ORDER BY tr.id ASC
     LIMIT GREATEST(1, LEAST(p_max_signals, 1000))
  LOOP
    v_count_total := v_count_total + 1;
    v_new_watermark := GREATEST(v_new_watermark, v_signal.id);

    /* Ident broj format: "PREDMET/TP" → order_no = predmet, item_ref_id = TP. */
    v_order_no := split_part(v_signal.ident_broj, '/', 1);
    v_tp_no    := NULLIF(split_part(v_signal.ident_broj, '/', 2), '');

    IF v_tp_no IS NULL OR length(trim(v_order_no)) = 0 THEN
      v_action := 'skip_bad_ident';
      v_count_skip_already := v_count_skip_already + 1;
      CONTINUE;
    END IF;

    /* Pronađi mašinsku lokaciju za machine_code. */
    SELECT ll.id INTO v_machine_loc_id
      FROM public.loc_locations ll
     WHERE ll.location_code = v_signal.machine_code
       AND ll.location_type = 'MACHINE'
       AND ll.is_active = TRUE
     LIMIT 1;

    IF v_machine_loc_id IS NULL THEN
      v_action := 'no_machine_loc';
      v_count_no_machine_loc := v_count_no_machine_loc + 1;
    ELSE
      /* Trenutni placement za (bigtehn_rn, tp, predmet). Ako ima više
       * placement-a (split na više polica), uzimamo onaj sa najviše komada. */
      SELECT lp.location_id, ll.location_code, ll.location_type::TEXT, lp.quantity
        INTO v_current_loc_id, v_current_loc_code, v_current_loc_type, v_current_qty
        FROM public.loc_item_placements lp
        LEFT JOIN public.loc_locations ll ON ll.id = lp.location_id
       WHERE lp.item_ref_table = 'bigtehn_rn'
         AND lp.item_ref_id    = v_tp_no
         AND lp.order_no       = v_order_no
         AND lp.quantity > 0
       ORDER BY lp.quantity DESC NULLS LAST, lp.updated_at DESC
       LIMIT 1;

      IF v_current_loc_id IS NULL THEN
        v_action := 'initial_placement';
        v_count_initial := v_count_initial + 1;
      ELSIF v_current_loc_id = v_machine_loc_id THEN
        v_action := 'skip_already_there';
        v_count_skip_already := v_count_skip_already + 1;
      ELSIF v_current_loc_type = 'MACHINE' THEN
        v_action := 'chain_transfer';
        v_count_chain_transfer := v_count_chain_transfer + 1;
      ELSE
        v_action := 'shelf_transfer';
        v_count_shelf_transfer := v_count_shelf_transfer + 1;
      END IF;

      /* Armed grana — Faza 2B implementira pravo izvršenje. Za sad samo
       * brojimo koliko bi bilo „izvršeno" da je armed=TRUE. */
      IF v_armed AND v_action IN ('initial_placement', 'chain_transfer', 'shelf_transfer') THEN
        /* TODO Faza 2B: ovde poziv loc_create_movement sa source='bigtehn'.
         * Trenutno samo brojimo. */
        v_count_armed_skipped := v_count_armed_skipped + 1;
      END IF;
    END IF;

    /* Sample za detaljni log (samo prvih v_max_samples redova da JSONB ne raste). */
    IF v_count_total <= v_max_samples THEN
      v_sample := jsonb_build_object(
        'signal_id',      v_signal.id,
        'work_order_id',  v_signal.work_order_id,
        'ident',          v_signal.ident_broj,
        'op',             v_signal.operacija,
        'machine',        v_signal.machine_code,
        'qty',            v_signal.komada,
        'action',         v_action,
        'from_loc',       v_current_loc_code,
        'from_type',      v_current_loc_type,
        'to_machine',     v_signal.machine_code,
        'potpis',         v_signal.potpis,
        'started_at',     v_signal.started_at
      );
      v_action_samples := v_action_samples || jsonb_build_array(v_sample);
    END IF;
  END LOOP;

  /* Persist state + heartbeat. */
  UPDATE public.loc_bigtehn_ingest_state
     SET last_processed_signal_id = v_new_watermark,
         last_run_at = now(),
         last_run_summary = jsonb_build_object(
           'started_at',        v_started_at,
           'finished_at',       now(),
           'duration_seconds',  EXTRACT(EPOCH FROM (now() - v_started_at))::numeric(10,3),
           'armed',             v_armed,
           'watermark_before',  v_watermark,
           'watermark_after',   v_new_watermark,
           'processed_total',   v_count_total,
           'by_action', jsonb_build_object(
             'no_machine_loc',   v_count_no_machine_loc,
             'skip_already',     v_count_skip_already,
             'chain_transfer',   v_count_chain_transfer,
             'shelf_transfer',   v_count_shelf_transfer,
             'initial_placement', v_count_initial,
             'armed_executed',   v_count_armed_executed,
             'armed_skipped',    v_count_armed_skipped
           ),
           'samples', v_action_samples
         )
   WHERE worker_id = 'loc-bigtehn-ingest';

  /* Reuse postojeće heartbeat infrastrukture (Härd-3). */
  PERFORM public.loc_sync_worker_heartbeat_upsert(
    'loc-bigtehn-ingest',
    jsonb_build_object(
      'mode',             CASE WHEN v_armed THEN 'armed' ELSE 'dry-run' END,
      'last_processed',   v_count_total,
      'watermark',        v_new_watermark,
      'last_run_summary', 'see loc_bigtehn_ingest_state.last_run_summary'
    )
  );

  RETURN jsonb_build_object(
    'ok',             TRUE,
    'armed',          v_armed,
    'mode',           CASE WHEN v_armed THEN 'armed' ELSE 'dry-run' END,
    'processed',      v_count_total,
    'watermark',      v_new_watermark,
    'by_action', jsonb_build_object(
      'no_machine_loc',   v_count_no_machine_loc,
      'skip_already',     v_count_skip_already,
      'chain_transfer',   v_count_chain_transfer,
      'shelf_transfer',   v_count_shelf_transfer,
      'initial_placement', v_count_initial,
      'armed_executed',   v_count_armed_executed,
      'armed_skipped',    v_count_armed_skipped
    )
  );
EXCEPTION
  WHEN others THEN
    /* Ne ruši cron — vrati error u JSONB. */
    PERFORM public.loc_sync_worker_heartbeat_upsert(
      'loc-bigtehn-ingest',
      jsonb_build_object('mode','error','error', SQLERRM, 'sqlstate', SQLSTATE)
    );
    RETURN jsonb_build_object('ok', FALSE, 'error', SQLERRM, 'sqlstate', SQLSTATE);
END;
$fn_run$;

REVOKE ALL ON FUNCTION public.loc_bigtehn_ingest_run(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_bigtehn_ingest_run(INT) FROM anon, authenticated;
/* Auto-pozive radi pg_cron sa service_role. Admin može i ručno kroz Studio. */
GRANT EXECUTE ON FUNCTION public.loc_bigtehn_ingest_run(INT) TO service_role;

COMMENT ON FUNCTION public.loc_bigtehn_ingest_run(INT) IS
  'Faza 2A: ingest worker. Skenira bigtehn_tech_routing_cache (id > watermark), '
  'analizira šta bi uradio za svaku prijavu (TRANSFER / chain / INITIAL / skip), '
  'i u dry-run modu samo loguje. Faza 2B grana će dodati pravo izvršenje.';

-- ── 3) Admin RPC: arm/disarm worker ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.loc_bigtehn_ingest_arm(p_armed BOOLEAN)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_arm$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'error', 'not_authenticated');
  END IF;
  IF NOT public.loc_is_admin() THEN
    RETURN jsonb_build_object('ok', FALSE, 'error', 'not_admin');
  END IF;
  IF p_armed IS NULL THEN
    RETURN jsonb_build_object('ok', FALSE, 'error', 'bad_arg');
  END IF;

  UPDATE public.loc_bigtehn_ingest_state
     SET armed = p_armed,
         updated_at = now()
   WHERE worker_id = 'loc-bigtehn-ingest';

  RETURN jsonb_build_object('ok', TRUE, 'armed', p_armed);
END;
$fn_arm$;

REVOKE ALL ON FUNCTION public.loc_bigtehn_ingest_arm(BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_bigtehn_ingest_arm(BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION public.loc_bigtehn_ingest_arm(BOOLEAN) TO authenticated;

COMMENT ON FUNCTION public.loc_bigtehn_ingest_arm(BOOLEAN) IS
  'Admin-only: aktivira (TRUE) ili gasi (FALSE) Faza 2 worker za auto-TRANSFER '
  'iz BigTehn prijava. U Fazi 2A ne radi ništa — Faza 2B grana implementira pravu logiku.';

-- ── 4) pg_cron schedule (every 5 min) ──────────────────────────────────────
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
  v_has_state BOOLEAN;
  v_has_fn    BOOLEAN;
  v_has_arm   BOOLEAN;
  v_state_row INT;
BEGIN
  v_has_state := EXISTS (
    SELECT 1 FROM information_schema.tables
     WHERE table_schema='public' AND table_name='loc_bigtehn_ingest_state'
  );
  v_has_fn := EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname='public' AND p.proname='loc_bigtehn_ingest_run'
  );
  v_has_arm := EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname='public' AND p.proname='loc_bigtehn_ingest_arm'
  );
  SELECT COUNT(*)::int INTO v_state_row
    FROM public.loc_bigtehn_ingest_state
   WHERE worker_id = 'loc-bigtehn-ingest';

  IF NOT (v_has_state AND v_has_fn AND v_has_arm AND v_state_row = 1) THEN
    RAISE EXCEPTION
      'add_loc_phase2a_bigtehn_ingest_dryrun sanity failed: state=%, fn=%, arm=%, state_row=%',
      v_has_state, v_has_fn, v_has_arm, v_state_row;
  END IF;

  RAISE NOTICE 'add_loc_phase2a_bigtehn_ingest_dryrun OK — dry-run mode aktiviran. Pokreni `SELECT loc_bigtehn_ingest_run();` ručno, ili sačekaj 5 min za cron.';
END
$sanity$;
