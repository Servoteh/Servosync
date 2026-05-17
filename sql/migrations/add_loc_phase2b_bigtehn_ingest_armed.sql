-- ============================================================================
-- LOKACIJE × MAŠINE — Faza 2B: BigTehn ingest worker (ARMED mode)
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru (idempotentno). POSLE Faza 2A.
--
-- ŠTA RADI ovo Faza 2B:
--   1) Pravi sistemskog auth.users korisnika `bigtehn-worker@system.local` sa
--      stabilnim UUID-om — koristi se kao `moved_by` u auto-generisanim
--      movement redovima. FK moved_by → auth.users zahteva pravu row.
--
--   2) Modifikuje trigger `loc_after_movement_insert` — preskače upis u
--      `loc_sync_outbound_events` kad je `source='bigtehn'`. Razlog: signal je
--      originalno došao iz MSSQL-a (BigTehn) preko `bigtehn_tech_routing_cache`
--      sync-a, ne želimo da auto-generisani TRANSFER u Lokacijama ponovo ide
--      MSSQL strani (loop prevention). v4 logika za drawing_no i placement
--      upsert ostaje netaknuta.
--
--   3) Rewrite-uje `loc_bigtehn_ingest_run()` sa armed granom:
--      - INITIAL_PLACEMENT: qty iz `bigtehn_work_orders_cache.komada` (PUN
--        RN total). Ako RN nije u kešu → skip sa razlogom.
--      - CHAIN_TRANSFER / SHELF_TRANSFER: qty = CELA placement qty (operater
--        je fizički doneo sve komade na novu mašinu). Ne deli qty po prijavi.
--      - Skip prijave starije od `p_max_age_days` dana (default 30) — safety
--        net da watermark reset ne backfill-uje 10g istorije.
--      - Skip prijave sa `komada=0` za non-INITIAL akcije (qty=0 = „starting
--        heartbeat", ne nosi premeštaj).
--      - Per-signal exception handler — jedna pokvarena prijava ne ruši batch.
--
-- ARM PROCEDURA:
--   Posle deploy-a, armed=FALSE i dalje. Da aktiviraš auto-TRANSFER:
--     SELECT public.loc_bigtehn_ingest_arm(TRUE);
--   Vratiti:
--     SELECT public.loc_bigtehn_ingest_arm(FALSE);
--
-- DOWN:
--   /* Rollback trigger na v4 — kopiraj v4 telo iz add_loc_v4_drawing_no.sql */
--   /* Rollback worker funkcije na Faza 2A — re-pokreni add_loc_phase2a_*.sql */
-- ============================================================================

-- ── 1) System user za worker writes ─────────────────────────────────────────
-- Stable UUID '00000000-0000-0000-0000-000000000099' = bigtehn-worker pseudo
-- user. Ne loguje se u UI, samo poseduje row u auth.users zbog FK moved_by.
INSERT INTO auth.users (id, email)
VALUES ('00000000-0000-0000-0000-000000000099', 'bigtehn-worker@system.local')
ON CONFLICT (id) DO NOTHING;

-- ── 2) Update trigger: skip MSSQL outbox kad source='bigtehn' ───────────────
-- Telo v4 (drawing_no logika) + jedan IF na kraju za outbox skip.
CREATE OR REPLACE FUNCTION public.loc_after_movement_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_trig$
DECLARE
  pl_status    public.loc_placement_status_enum;
  v_remain     NUMERIC(12,3);
  v_drawing    TEXT;
BEGIN
  IF NEW.movement_type IN ('SEND_TO_SERVICE', 'SEND_TO_FIELD') THEN
    pl_status := 'IN_TRANSIT'::public.loc_placement_status_enum;
  ELSE
    pl_status := 'ACTIVE'::public.loc_placement_status_enum;
  END IF;

  /* Drawing normalization (v4 logika): ako NEW.drawing_no nije poslat,
   * pokušaj da ga izvučeš iz note (RNZ format „Crtež:NNN | …"). */
  v_drawing := COALESCE(NULLIF(trim(NEW.drawing_no), ''), '');
  IF v_drawing = '' AND NEW.note IS NOT NULL AND NEW.note ~ 'Crte[žz]:[^\s|]+' THEN
    v_drawing := substring(NEW.note FROM 'Crte[žz]:([^\s|]+)');
  END IF;

  IF v_drawing <> '' AND (NEW.drawing_no IS NULL OR NEW.drawing_no = '') THEN
    UPDATE public.loc_location_movements
       SET drawing_no = v_drawing
     WHERE id = NEW.id;
  END IF;

  /* TO lokacija upsert — placement state. */
  IF NEW.to_location_id IS NOT NULL THEN
    INSERT INTO public.loc_item_placements (
      item_ref_table, item_ref_id, order_no, drawing_no, location_id, placement_status,
      quantity, last_movement_id, placed_at, placed_by, notes
    ) VALUES (
      NEW.item_ref_table, NEW.item_ref_id, COALESCE(NEW.order_no, ''),
      v_drawing,
      NEW.to_location_id, pl_status,
      NEW.quantity, NEW.id, NEW.moved_at, NEW.moved_by, NULL
    )
    ON CONFLICT (item_ref_table, item_ref_id, order_no, location_id) DO UPDATE SET
      quantity = public.loc_item_placements.quantity + EXCLUDED.quantity,
      placement_status = EXCLUDED.placement_status,
      last_movement_id = EXCLUDED.last_movement_id,
      placed_at = EXCLUDED.placed_at,
      placed_by = EXCLUDED.placed_by,
      drawing_no = CASE
        WHEN EXCLUDED.drawing_no <> '' THEN EXCLUDED.drawing_no
        ELSE public.loc_item_placements.drawing_no
      END,
      updated_at = now();
  END IF;

  /* FROM lokacija: oduzmi qty. */
  IF NEW.from_location_id IS NOT NULL THEN
    v_remain := (
      SELECT lp.quantity - NEW.quantity
        FROM public.loc_item_placements lp
       WHERE lp.item_ref_table = NEW.item_ref_table
         AND lp.item_ref_id    = NEW.item_ref_id
         AND lp.order_no       = COALESCE(NEW.order_no, '')
         AND lp.location_id    = NEW.from_location_id
    );

    IF v_remain IS NULL THEN
      RAISE EXCEPTION 'loc_after_movement_insert: missing placement on from_location (item=%/%, order=%, loc=%)',
        NEW.item_ref_table, NEW.item_ref_id, COALESCE(NEW.order_no, ''), NEW.from_location_id;
    ELSIF v_remain <= 0 THEN
      DELETE FROM public.loc_item_placements
       WHERE item_ref_table = NEW.item_ref_table
         AND item_ref_id    = NEW.item_ref_id
         AND order_no       = COALESCE(NEW.order_no, '')
         AND location_id    = NEW.from_location_id;
    ELSE
      UPDATE public.loc_item_placements
         SET quantity = v_remain,
             last_movement_id = NEW.id,
             updated_at = now()
       WHERE item_ref_table = NEW.item_ref_table
         AND item_ref_id    = NEW.item_ref_id
         AND order_no       = COALESCE(NEW.order_no, '')
         AND location_id    = NEW.from_location_id;
    END IF;
  END IF;

  /* Sync outbound event — Faza 2B addition: SKIP ako je source='bigtehn'.
   * Signal je već došao iz MSSQL-a, vraćanje bi pravilo sync loop. */
  IF COALESCE(NEW.source, 'manual') <> 'bigtehn' THEN
    INSERT INTO public.loc_sync_outbound_events (
      id, source_table, source_record_id, target_procedure, payload, status
    ) VALUES (
      NEW.id,
      'loc_location_movements',
      NEW.id,
      'dbo.sp_ApplyLocationEvent',
      jsonb_build_object(
        'event_uuid', NEW.id::text,
        'item_ref_table', NEW.item_ref_table,
        'item_ref_id', NEW.item_ref_id,
        'order_no', COALESCE(NEW.order_no, ''),
        'drawing_no', COALESCE(v_drawing, ''),
        'from_location_code', (SELECT llfc.location_code FROM public.loc_locations AS llfc WHERE llfc.id = NEW.from_location_id),
        'to_location_code',   (SELECT lltc.location_code FROM public.loc_locations AS lltc WHERE lltc.id = NEW.to_location_id),
        'movement_type', NEW.movement_type::text,
        'quantity', NEW.quantity,
        'moved_at', to_jsonb(NEW.moved_at),
        'moved_by', NEW.moved_by::text,
        'note', NEW.note
      ),
      'PENDING'::public.loc_sync_status_enum
    );
  END IF;

  RETURN NEW;
END;
$fn_trig$;

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
    v_current_loc_id := NULL;
    v_current_loc_code := NULL;
    v_current_loc_type := NULL;
    v_current_qty := NULL;
    v_rn_total := NULL;
    v_rn_drawing := NULL;
    v_transfer_qty := NULL;

    /* PL/pgSQL nema GOTO; jednom-prolazni labeled LOOP daje nam „EXIT signal_inner"
     * kao ekvivalent ranog izlaza — sve early-exit grane skoče na kraj LOOP-a,
     * gde sledi log_sample blok. */
    <<signal_inner>>
    LOOP
      /* Safety net: skip stare prijave (npr. >30 dana). */
      IF v_signal.started_at < v_min_age THEN
        v_action := 'too_old';
        v_count_too_old := v_count_too_old + 1;
        EXIT signal_inner;
      END IF;

      /* Parse ident: "PREDMET/TP". */
      v_order_no := split_part(v_signal.ident_broj, '/', 1);
      v_tp_no    := NULLIF(split_part(v_signal.ident_broj, '/', 2), '');

      IF v_tp_no IS NULL OR length(trim(v_order_no)) = 0 THEN
        v_action := 'skip_bad_ident';
        v_count_skip_bad_ident := v_count_skip_bad_ident + 1;
        EXIT signal_inner;
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
        EXIT signal_inner;
      END IF;

      /* Trenutni placement (najveća količina ako split). */
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
        EXIT signal_inner;
      ELSIF v_current_loc_type = 'MACHINE' THEN
        v_action := 'chain_transfer';
      ELSE
        v_action := 'shelf_transfer';
      END IF;

      /* INITIAL_PLACEMENT: lookup RN total + drawing_no iz work_orders_cache. */
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
        /* TRANSFER (chain ili shelf): cela placement qty. Skip ako prijava komada=0. */
        IF COALESCE(v_signal.komada, 0) = 0 THEN
          /* Operater javio „starting heartbeat" bez qty. Ne pravimo TRANSFER. */
          v_action := 'skip_zero_qty';
          v_count_skip_zero_qty := v_count_skip_zero_qty + 1;
          EXIT signal_inner;
        END IF;

        v_transfer_qty := v_current_qty;  /* CELA placement qty, ne prijava qty */
        v_movement_type := 'TRANSFER'::public.loc_movement_type_enum;

        IF v_action = 'chain_transfer' THEN
          v_count_chain_transfer := v_count_chain_transfer + 1;
        ELSE
          v_count_shelf_transfer := v_count_shelf_transfer + 1;
        END IF;
      END IF;

      /* ARMED grana — pravo izvršenje. Per-signal exception handler da
       * pokvarena prijava ne ruši ceo batch. */
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

      EXIT signal_inner;  /* uvek izađi posle jedne iteracije */
    END LOOP;  /* signal_inner */

    /* Log sample (svih akcija — i early-exit i full path). */
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
