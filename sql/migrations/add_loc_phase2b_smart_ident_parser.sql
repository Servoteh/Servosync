-- ============================================================================
-- LOKACIJE × MAŠINE — Faza 2B: smart ident_broj parser (predmet hijerarhija)
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru (idempotentno).
--
-- ZAŠTO POSTOJI:
--   Prvobitni parser u `loc_bigtehn_ingest_run` koristio je naivni
--   `split_part(ident_broj, '/', 1) = predmet, split_part 2 = tp`. To je
--   pogrešno za ident-e tipa „9400/1/165" gde:
--     - „9400/1" JE validan broj_predmeta u `bigtehn_items_cache` (sklop hijerarhija)
--     - „165" je leaf TP unutar tog sklopa
--   Naivni parser je davao predmet=„9400", tp=„1" — grupišući sve TP-e iz
--   sklopa „1" pod jednim placement ključem. Pogrešno za 3-segment idente.
--
--   Smart parser pokušava NAJDUŽI predmet prefiks koji postoji u
--   `bigtehn_items_cache` (status='U TOKU' AND datum_zakljucenja IS NULL).
--   Ostatak je TP. Ako nijedan prefiks nije aktivan predmet, fallback na
--   prvi segment (= postojeća v3 RPC konvencija).
--
-- ŠTA RADI:
--   1) `loc_bigtehn_parse_ident(p_ident TEXT) RETURNS jsonb` — vraća
--      `{"predmet": "9400/1", "tp": "165"}` ili `{"predmet": null, "tp": null}`
--      za bad input.
--   2) `loc_bigtehn_ingest_run` rewrite — koristi gornji helper umesto
--      naivnog split_part. Sva ostala logika (klasifikacija, armed grana,
--      heartbeat) ostaje ista.
--
-- ZAVISI OD: `add_loc_phase2b_bigtehn_ingest_armed.sql` (worker shell).
-- ============================================================================

-- ── 1) Helper: parse ident_broj sa lookup-om predmeta ───────────────────────
CREATE OR REPLACE FUNCTION public.loc_bigtehn_parse_ident(p_ident TEXT)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $fn_parse$
DECLARE
  v_ident   TEXT;
  v_parts   TEXT[];
  v_count   INT;
  v_idx     INT;
  v_predmet TEXT;
  v_tp      TEXT;
BEGIN
  v_ident := NULLIF(trim(COALESCE(p_ident, '')), '');
  IF v_ident IS NULL THEN
    RETURN jsonb_build_object('predmet', NULL, 'tp', NULL);
  END IF;

  v_parts := string_to_array(v_ident, '/');
  v_count := COALESCE(array_length(v_parts, 1), 0);

  /* 1 segment → nema TP-a, ident je „bad" za naš cilj. */
  IF v_count < 2 THEN
    RETURN jsonb_build_object('predmet', NULL, 'tp', NULL);
  END IF;

  /* Pokušaj NAJDUŽI predmet prefiks koji je aktivan predmet u kešu, idući od
   * (count-1) ka 1 segmentu. Prvi match dobija. Ostatak je TP. */
  FOR v_idx IN REVERSE (v_count - 1)..1 LOOP
    v_predmet := array_to_string(v_parts[1:v_idx], '/');

    IF EXISTS (
      SELECT 1
        FROM public.bigtehn_items_cache b
       WHERE b.broj_predmeta = v_predmet
         AND b.status = 'U TOKU'
         AND b.datum_zakljucenja IS NULL
       LIMIT 1
    ) THEN
      v_tp := array_to_string(v_parts[(v_idx + 1):v_count], '/');
      v_tp := NULLIF(trim(v_tp), '');
      IF v_tp IS NULL THEN
        /* Ne bi trebalo da se desi, ali safety. */
        CONTINUE;
      END IF;
      RETURN jsonb_build_object('predmet', v_predmet, 'tp', v_tp);
    END IF;
  END LOOP;

  /* Nijedan prefiks nije aktivan predmet → fallback na v3 konvenciju
   * (prvi segment = predmet, drugi segment = tp). Iznad jednog reda da
   * jasno pokažemo koji red NIJE bio prepoznat kao aktivan predmet. */
  v_predmet := v_parts[1];
  v_tp := NULLIF(trim(v_parts[2]), '');
  IF v_predmet IS NULL OR length(trim(v_predmet)) = 0 OR v_tp IS NULL THEN
    RETURN jsonb_build_object('predmet', NULL, 'tp', NULL);
  END IF;
  RETURN jsonb_build_object('predmet', v_predmet, 'tp', v_tp, 'fallback', TRUE);
END;
$fn_parse$;

REVOKE ALL ON FUNCTION public.loc_bigtehn_parse_ident(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.loc_bigtehn_parse_ident(TEXT) TO authenticated, service_role;

COMMENT ON FUNCTION public.loc_bigtehn_parse_ident(TEXT) IS
  'Pretvara BigTehn ident_broj (npr. „9400/1/165") u {predmet, tp} koristeći '
  'longest-match protiv bigtehn_items_cache aktivnih predmeta. Ako nijedan '
  'prefiks nije aktivan, fallback na (split 1 / split 2). Vraća JSONB sa '
  'opcionim „fallback":true flag-om kad se koristi fallback grana.';

-- ── 2) Worker function update (samo parser deo se menja) ────────────────────
DROP FUNCTION IF EXISTS public.loc_bigtehn_ingest_run(INT, INT);

CREATE OR REPLACE FUNCTION public.loc_bigtehn_ingest_run(
  p_max_signals  INT DEFAULT 200,
  p_max_age_days INT DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_run$
DECLARE
  v_system_user_id        CONSTANT UUID := '00000000-0000-0000-0000-000000000099';
  v_armed                 BOOLEAN;
  v_watermark             BIGINT;
  v_new_watermark         BIGINT;
  v_signal                RECORD;
  v_count_total           INT := 0;
  v_count_too_old         INT := 0;
  v_count_no_machine_loc  INT := 0;
  v_count_no_rn_in_cache  INT := 0;
  v_count_skip_already    INT := 0;
  v_count_skip_zero_qty   INT := 0;
  v_count_skip_bad_ident  INT := 0;
  v_count_chain_transfer  INT := 0;
  v_count_shelf_transfer  INT := 0;
  v_count_initial         INT := 0;
  v_count_armed_executed  INT := 0;
  v_count_armed_errors    INT := 0;
  v_count_fallback_parser INT := 0;
  v_action_samples        JSONB := '[]'::jsonb;
  v_max_samples           CONSTANT INT := 25;
  v_started_at            TIMESTAMPTZ := now();
  v_min_age               TIMESTAMPTZ;

  /* per-signal */
  v_parsed                JSONB;
  v_order_no              TEXT;
  v_tp_no                 TEXT;
  v_parser_fallback       BOOLEAN;
  v_machine_loc_id        UUID;
  v_current_loc_id        UUID;
  v_current_loc_code      TEXT;
  v_current_loc_type      TEXT;
  v_current_qty           NUMERIC;
  v_rn_total              NUMERIC;
  v_rn_drawing            TEXT;
  v_action                TEXT;
  v_transfer_qty          NUMERIC;
  v_movement_id           UUID;
  v_movement_type         public.loc_movement_type_enum;
  v_armed_error           TEXT;
  v_sample                JSONB;
BEGIN
  v_min_age := now() - make_interval(days => GREATEST(1, COALESCE(p_max_age_days, 30)));

  SELECT armed, last_processed_signal_id
    INTO v_armed, v_watermark
    FROM public.loc_bigtehn_ingest_state
   WHERE worker_id = 'loc-bigtehn-ingest'
   FOR UPDATE;

  IF v_armed IS NULL THEN
    INSERT INTO public.loc_bigtehn_ingest_state (worker_id, last_processed_signal_id, armed)
    VALUES ('loc-bigtehn-ingest', 0, FALSE)
    ON CONFLICT (worker_id) DO NOTHING;
    v_armed := FALSE;
    v_watermark := 0;
  END IF;

  v_new_watermark := v_watermark;

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
    v_action := NULL;
    v_armed_error := NULL;
    v_current_loc_id := NULL;
    v_current_loc_code := NULL;
    v_current_loc_type := NULL;
    v_current_qty := NULL;
    v_rn_total := NULL;
    v_rn_drawing := NULL;
    v_transfer_qty := NULL;
    v_parser_fallback := FALSE;
    v_order_no := NULL;
    v_tp_no := NULL;

    <<signal_inner>>
    LOOP
      IF v_signal.started_at < v_min_age THEN
        v_action := 'too_old';
        v_count_too_old := v_count_too_old + 1;
        EXIT signal_inner;
      END IF;

      /* SMART parser: longest active predmet prefix match. */
      v_parsed := public.loc_bigtehn_parse_ident(v_signal.ident_broj);
      v_order_no := v_parsed->>'predmet';
      v_tp_no    := v_parsed->>'tp';
      v_parser_fallback := COALESCE((v_parsed->>'fallback')::BOOLEAN, FALSE);
      IF v_parser_fallback THEN
        v_count_fallback_parser := v_count_fallback_parser + 1;
      END IF;

      IF v_order_no IS NULL OR v_tp_no IS NULL THEN
        v_action := 'skip_bad_ident';
        v_count_skip_bad_ident := v_count_skip_bad_ident + 1;
        EXIT signal_inner;
      END IF;

      SELECT ll.id INTO v_machine_loc_id
        FROM public.loc_locations ll
       WHERE ll.location_code = v_signal.machine_code
         AND ll.location_type = 'MACHINE'
         AND ll.is_active = TRUE
       LIMIT 1;

      IF v_machine_loc_id IS NULL THEN
        v_action := 'no_machine_loc';
        v_count_no_machine_loc := v_count_no_machine_loc + 1;
        EXIT signal_inner;
      END IF;

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
      ELSIF v_current_loc_id = v_machine_loc_id THEN
        v_action := 'skip_already_there';
        v_count_skip_already := v_count_skip_already + 1;
        EXIT signal_inner;
      ELSIF v_current_loc_type = 'MACHINE' THEN
        v_action := 'chain_transfer';
      ELSE
        v_action := 'shelf_transfer';
      END IF;

      IF v_action = 'initial_placement' THEN
        SELECT wo.komada, NULLIF(trim(wo.broj_crteza), '')
          INTO v_rn_total, v_rn_drawing
          FROM public.bigtehn_work_orders_cache wo
         WHERE wo.id = v_signal.work_order_id
         LIMIT 1;

        IF v_rn_total IS NULL OR v_rn_total <= 0 THEN
          v_action := 'no_rn_in_cache';
          v_count_no_rn_in_cache := v_count_no_rn_in_cache + 1;
          EXIT signal_inner;
        END IF;

        v_transfer_qty := v_rn_total;
        v_movement_type := 'INITIAL_PLACEMENT'::public.loc_movement_type_enum;
        v_count_initial := v_count_initial + 1;

      ELSE
        IF COALESCE(v_signal.komada, 0) = 0 THEN
          v_action := 'skip_zero_qty';
          v_count_skip_zero_qty := v_count_skip_zero_qty + 1;
          EXIT signal_inner;
        END IF;

        v_transfer_qty := v_current_qty;
        v_movement_type := 'TRANSFER'::public.loc_movement_type_enum;

        IF v_action = 'chain_transfer' THEN
          v_count_chain_transfer := v_count_chain_transfer + 1;
        ELSE
          v_count_shelf_transfer := v_count_shelf_transfer + 1;
        END IF;
      END IF;

      IF v_armed THEN
        BEGIN
          v_movement_id := gen_random_uuid();
          INSERT INTO public.loc_location_movements (
            id,
            item_ref_table, item_ref_id, order_no, drawing_no,
            from_location_id, to_location_id,
            movement_type, movement_reason,
            quantity, note,
            moved_at, moved_by,
            source
          ) VALUES (
            v_movement_id,
            'bigtehn_rn', v_tp_no, v_order_no,
            COALESCE(v_rn_drawing, ''),
            v_current_loc_id,
            v_machine_loc_id,
            v_movement_type,
            format('Auto iz BigTehn prijave #%s (%s)', v_signal.id, v_signal.operacija),
            v_transfer_qty,
            format('signal=%s op=%s mach=%s qty=%s pot=%s',
                   v_signal.id, v_signal.operacija, v_signal.machine_code,
                   v_signal.komada, COALESCE(v_signal.potpis, '?')),
            v_signal.started_at,
            v_system_user_id,
            'bigtehn'
          );
          v_count_armed_executed := v_count_armed_executed + 1;
        EXCEPTION WHEN others THEN
          v_armed_error := SQLERRM;
          v_count_armed_errors := v_count_armed_errors + 1;
        END;
      END IF;

      EXIT signal_inner;
    END LOOP;

    IF v_count_total <= v_max_samples THEN
      v_sample := jsonb_build_object(
        'signal_id',      v_signal.id,
        'work_order_id',  v_signal.work_order_id,
        'ident',          v_signal.ident_broj,
        'predmet',        v_order_no,
        'tp',             v_tp_no,
        'parser_fallback', v_parser_fallback,
        'op',             v_signal.operacija,
        'machine',        v_signal.machine_code,
        'prijava_qty',    v_signal.komada,
        'action',         v_action,
        'from_loc',       v_current_loc_code,
        'from_type',      v_current_loc_type,
        'to_machine',     v_signal.machine_code,
        'transfer_qty',   v_transfer_qty,
        'rn_total',       v_rn_total,
        'started_at',     v_signal.started_at,
        'armed_executed', (v_armed AND v_armed_error IS NULL AND v_action IN ('initial_placement','chain_transfer','shelf_transfer')),
        'armed_error',    v_armed_error
      );
      v_action_samples := v_action_samples || jsonb_build_array(v_sample);
    END IF;
  END LOOP;

  UPDATE public.loc_bigtehn_ingest_state
     SET last_processed_signal_id = v_new_watermark,
         last_run_at = now(),
         last_run_summary = jsonb_build_object(
           'started_at',       v_started_at,
           'finished_at',      now(),
           'duration_seconds', EXTRACT(EPOCH FROM (now() - v_started_at))::numeric(10,3),
           'armed',            v_armed,
           'max_age_days',     p_max_age_days,
           'watermark_before', v_watermark,
           'watermark_after',  v_new_watermark,
           'processed_total',  v_count_total,
           'by_action', jsonb_build_object(
             'too_old',          v_count_too_old,
             'no_machine_loc',   v_count_no_machine_loc,
             'no_rn_in_cache',   v_count_no_rn_in_cache,
             'skip_already',     v_count_skip_already,
             'skip_zero_qty',    v_count_skip_zero_qty,
             'skip_bad_ident',   v_count_skip_bad_ident,
             'chain_transfer',   v_count_chain_transfer,
             'shelf_transfer',   v_count_shelf_transfer,
             'initial_placement', v_count_initial,
             'armed_executed',   v_count_armed_executed,
             'armed_errors',     v_count_armed_errors,
             'parser_fallback',  v_count_fallback_parser
           ),
           'samples', v_action_samples
         )
   WHERE worker_id = 'loc-bigtehn-ingest';

  PERFORM public.loc_sync_worker_heartbeat_upsert(
    'loc-bigtehn-ingest',
    jsonb_build_object(
      'mode',           CASE WHEN v_armed THEN 'armed' ELSE 'dry-run' END,
      'last_processed', v_count_total,
      'armed_executed', v_count_armed_executed,
      'armed_errors',   v_count_armed_errors,
      'parser_fallback', v_count_fallback_parser,
      'watermark',      v_new_watermark
    )
  );

  RETURN jsonb_build_object(
    'ok',             TRUE,
    'armed',          v_armed,
    'mode',           CASE WHEN v_armed THEN 'armed' ELSE 'dry-run' END,
    'processed',      v_count_total,
    'watermark',      v_new_watermark,
    'by_action', jsonb_build_object(
      'too_old',          v_count_too_old,
      'no_machine_loc',   v_count_no_machine_loc,
      'no_rn_in_cache',   v_count_no_rn_in_cache,
      'skip_already',     v_count_skip_already,
      'skip_zero_qty',    v_count_skip_zero_qty,
      'skip_bad_ident',   v_count_skip_bad_ident,
      'chain_transfer',   v_count_chain_transfer,
      'shelf_transfer',   v_count_shelf_transfer,
      'initial_placement', v_count_initial,
      'armed_executed',   v_count_armed_executed,
      'armed_errors',     v_count_armed_errors,
      'parser_fallback',  v_count_fallback_parser
    )
  );
EXCEPTION
  WHEN others THEN
    PERFORM public.loc_sync_worker_heartbeat_upsert(
      'loc-bigtehn-ingest',
      jsonb_build_object('mode','error','error', SQLERRM, 'sqlstate', SQLSTATE)
    );
    RETURN jsonb_build_object('ok', FALSE, 'error', SQLERRM, 'sqlstate', SQLSTATE);
END;
$fn_run$;

REVOKE ALL ON FUNCTION public.loc_bigtehn_ingest_run(INT, INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.loc_bigtehn_ingest_run(INT, INT) TO service_role;

COMMENT ON FUNCTION public.loc_bigtehn_ingest_run(INT, INT) IS
  'Faza 2B + smart parser: koristi loc_bigtehn_parse_ident za longest active '
  'predmet match. „9400/1/165" → predmet=„9400/1" tp=„165" ako je „9400/1" '
  'aktivan predmet. Inače fallback (predmet=split 1, tp=split 2). Brojač '
  'parser_fallback prati koliko puta je fallback aktiviran u poslednjem run-u.';

-- ── 3) Sanity ───────────────────────────────────────────────────────────────
DO $sanity$
DECLARE
  v_test_simple jsonb;
  v_test_hier   jsonb;
BEGIN
  /* Test 1: simple 2-segment ident — uvek koristi fallback (osim ako je
   * tačno taj predmet aktivan u kešu, što i jeste tipičan slučaj). */
  v_test_simple := public.loc_bigtehn_parse_ident('TEST_PROBA/999');
  /* Test 2: bad ident */
  v_test_hier := public.loc_bigtehn_parse_ident('0000.0');

  /* Bez konkretne provere protiv keš-a (CI nema podataka); samo log. */
  RAISE NOTICE 'loc_bigtehn_parse_ident smoke: simple=%, bad=%', v_test_simple, v_test_hier;
  RAISE NOTICE 'add_loc_phase2b_smart_ident_parser OK. Pokreni `SELECT loc_bigtehn_ingest_run();` da vidiš novu klasifikaciju (parser_fallback brojač u by_action).';
END
$sanity$;
