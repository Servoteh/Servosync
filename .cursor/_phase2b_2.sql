-- ── 3) Worker function (ARMED mode) ─────────────────────────────────────────
DROP FUNCTION IF EXISTS public.loc_bigtehn_ingest_run(INT);
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
  v_action_samples        JSONB := '[]'::jsonb;
  v_max_samples           CONSTANT INT := 25;
  v_started_at            TIMESTAMPTZ := now();
  v_min_age               TIMESTAMPTZ;

  /* per-signal */
  v_order_no              TEXT;
  v_tp_no                 TEXT;
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

  /* Read state. */
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

    /* Safety net: skip stare prijave (npr. >30 dana). */
    IF v_signal.started_at < v_min_age THEN
      v_action := 'too_old';
      v_count_too_old := v_count_too_old + 1;
      GOTO log_sample;
    END IF;

    /* Parse ident: "PREDMET/TP". */
    v_order_no := split_part(v_signal.ident_broj, '/', 1);
    v_tp_no    := NULLIF(split_part(v_signal.ident_broj, '/', 2), '');

    IF v_tp_no IS NULL OR length(trim(v_order_no)) = 0 THEN
      v_action := 'skip_bad_ident';
      v_count_skip_bad_ident := v_count_skip_bad_ident + 1;
      GOTO log_sample;
    END IF;

    /* Mašinska lokacija za machine_code. */
    SELECT ll.id INTO v_machine_loc_id
      FROM public.loc_locations ll
     WHERE ll.location_code = v_signal.machine_code
       AND ll.location_type = 'MACHINE'
       AND ll.is_active = TRUE
     LIMIT 1;

    IF v_machine_loc_id IS NULL THEN
      v_action := 'no_machine_loc';
      v_count_no_machine_loc := v_count_no_machine_loc + 1;
      GOTO log_sample;
    END IF;

    /* Trenutni placement (najveća količina ako split). */
    v_current_loc_id := NULL;
    v_current_loc_code := NULL;
    v_current_loc_type := NULL;
    v_current_qty := NULL;
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

    /* Klasifikuj akciju. */
    IF v_current_loc_id IS NULL THEN
      v_action := 'initial_placement';
    ELSIF v_current_loc_id = v_machine_loc_id THEN
      v_action := 'skip_already_there';
      v_count_skip_already := v_count_skip_already + 1;
      GOTO log_sample;
    ELSIF v_current_loc_type = 'MACHINE' THEN
      v_action := 'chain_transfer';
    ELSE
      v_action := 'shelf_transfer';
    END IF;

    /* INITIAL_PLACEMENT: lookup RN total + drawing_no iz work_orders_cache. */
    IF v_action = 'initial_placement' THEN
      v_rn_total := NULL;
      v_rn_drawing := NULL;
      SELECT wo.komada, NULLIF(trim(wo.broj_crteza), '')
        INTO v_rn_total, v_rn_drawing
        FROM public.bigtehn_work_orders_cache wo
       WHERE wo.id = v_signal.work_order_id
       LIMIT 1;

      IF v_rn_total IS NULL OR v_rn_total <= 0 THEN
        v_action := 'no_rn_in_cache';
        v_count_no_rn_in_cache := v_count_no_rn_in_cache + 1;
        GOTO log_sample;
      END IF;

      v_transfer_qty := v_rn_total;
      v_movement_type := 'INITIAL_PLACEMENT'::public.loc_movement_type_enum;
      v_count_initial := v_count_initial + 1;

    ELSE
      /* TRANSFER (chain ili shelf): cela placement qty. Skip ako prijava komada=0. */
      IF COALESCE(v_signal.komada, 0) = 0 THEN
        /* Operater javio „starting heartbeat" bez qty. Ne pravimo TRANSFER. */
        v_action := 'skip_zero_qty';
        v_count_skip_zero_qty := v_count_skip_zero_qty + 1;
        GOTO log_sample;
      END IF;

      v_transfer_qty := v_current_qty;  /* CELA placement qty, ne prijava qty */
      v_movement_type := 'TRANSFER'::public.loc_movement_type_enum;

      IF v_action = 'chain_transfer' THEN
        v_count_chain_transfer := v_count_chain_transfer + 1;
      ELSE
        v_count_shelf_transfer := v_count_shelf_transfer + 1;
      END IF;
    END IF;

    /* ARMED grana — pravo izvršenje. */
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
          v_current_loc_id,         /* NULL za INITIAL */
          v_machine_loc_id,
          v_movement_type,
          format('Auto iz BigTehn prijave #%s (%s)', v_signal.id, v_signal.operacija),
          v_transfer_qty,
          format('signal=%s op=%s mach=%s qty=%s op=%s',
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
        /* Ne ruši batch — prijavi grešku u sample i nastavi. */
      END;
    END IF;

    <<log_sample>>
    IF v_count_total <= v_max_samples THEN
      v_sample := jsonb_build_object(
        'signal_id',      v_signal.id,
        'work_order_id',  v_signal.work_order_id,
        'ident',          v_signal.ident_broj,
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

  /* Persist state + heartbeat. */
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
             'armed_errors',     v_count_armed_errors
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
      'armed_errors',     v_count_armed_errors
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

REVOKE ALL ON FUNCTION public.loc_bigtehn_ingest_run(INT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_bigtehn_ingest_run(INT, INT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.loc_bigtehn_ingest_run(INT, INT) TO service_role;

COMMENT ON FUNCTION public.loc_bigtehn_ingest_run(INT, INT) IS
  'Faza 2B: ingest worker sa armed granom. Skenira bigtehn_tech_routing_cache, '
  'za svaku novu prijavu klasifikuje akciju i (ako armed=TRUE) generiše TRANSFER '
  'pokret sa source=bigtehn. INITIAL_PLACEMENT koristi RN total iz work_orders_cache, '
  'TRANSFER koristi punu placement qty. Skip stare prijave (>30 dana) i qty=0.';

