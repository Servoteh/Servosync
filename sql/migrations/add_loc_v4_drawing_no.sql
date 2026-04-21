-- ============================================================================
-- LOKACIJE — v4: explicit drawing_no kolona (RNZ vs short format problem)
-- ============================================================================
-- Primeni NAKON add_loc_v3_order_scope.sql.
--
-- Razlog postojanja:
--   U RNZ formatu nalepnice, `item_ref_id` = broj TP (tehnološki postupak),
--   a broj crteža je ZAKOPAN u `loc_location_movements.note` kao prefix
--   "Crtež:NNNNNN | ...". Zato "pretraga po crtežu" na /m/lookup radi dva
--   upita: direktan nad item_ref_id (short format) + indirektan regex nad
--   note (RNZ format). Dva upita = sporo + mreža 2× + merge u klijentu.
--
--   Rešenje: podići drawing_no u FIRST-CLASS TEXT kolonu u obe tabele,
--   popuniti je iz postojećih movement-a, i natjerati trigger da je propa-
--   gira u placement upsert. Klijent (RPC) može da je šalje eksplicitno
--   (u payload-u) — ako je ne pošalje, trigger je izvuče iz `note`.
--
-- Šta menja:
--   1. `loc_item_placements.drawing_no     TEXT NOT NULL DEFAULT ''`
--   2. `loc_location_movements.drawing_no  TEXT NOT NULL DEFAULT ''`
--   3. Indeks po drawing_no (WHERE <> '') za brzu pretragu.
--   4. Backfill iz `note ~ 'Crtež:([^\s|]+)'`.
--   5. Trigger `loc_after_movement_insert` propagira drawing_no u placement.
--   6. RPC `loc_create_movement` prihvata `drawing_no` iz payload-a i,
--      ako nije dat ali note ima "Crtež:NNN" prefix, izvlači ga regex-om.
--
-- Idempotentno — safe za ponovno pokretanje.
-- ============================================================================

-- ── 1. Dodaj drawing_no kolone ──────────────────────────────────────────────
ALTER TABLE public.loc_item_placements
  ADD COLUMN IF NOT EXISTS drawing_no TEXT NOT NULL DEFAULT '';

ALTER TABLE public.loc_location_movements
  ADD COLUMN IF NOT EXISTS drawing_no TEXT NOT NULL DEFAULT '';

/* Tight limit — crteži su do ~10-12 karaktera u praksi, 40 je sa rezervom. */
DO $$ BEGIN
  ALTER TABLE public.loc_item_placements
    ADD CONSTRAINT loc_item_placements_drawing_no_len_chk CHECK (char_length(drawing_no) <= 40);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE public.loc_location_movements
    ADD CONSTRAINT loc_location_movements_drawing_no_len_chk CHECK (char_length(drawing_no) <= 40);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── 2. Indeksi (partial — samo ne-prazne, da ne napumpavamo) ────────────────
CREATE INDEX IF NOT EXISTS loc_item_placements_drawing_no_idx
  ON public.loc_item_placements (drawing_no)
  WHERE drawing_no <> '';

CREATE INDEX IF NOT EXISTS loc_location_movements_drawing_no_idx
  ON public.loc_location_movements (drawing_no)
  WHERE drawing_no <> '';

-- ── 3. Backfill iz postojećih movement-a ────────────────────────────────────
-- Parsiramo "Crtež:NNN" prefix iz note (podržavamo i "Crtez:" bez đ fallback).
-- substring() s regex grupom vraća samo captured grupu.
UPDATE public.loc_location_movements
   SET drawing_no = substring(note FROM 'Crte[žz]:([^\s|]+)')
 WHERE drawing_no = ''
   AND note IS NOT NULL
   AND note ~ 'Crte[žz]:[^\s|]+';

-- Za placement-e uzmi drawing_no sa NAJNOVIJEG movement-a za taj tuple.
-- Preko LATERAL join-a radi idempotentno i brzo.
UPDATE public.loc_item_placements pl
   SET drawing_no = sub.drawing_no
  FROM (
    SELECT DISTINCT ON (mv.item_ref_table, mv.item_ref_id, mv.order_no)
           mv.item_ref_table, mv.item_ref_id, mv.order_no, mv.drawing_no
      FROM public.loc_location_movements mv
     WHERE mv.drawing_no <> ''
     ORDER BY mv.item_ref_table, mv.item_ref_id, mv.order_no, mv.moved_at DESC
  ) sub
 WHERE pl.drawing_no = ''
   AND pl.item_ref_table = sub.item_ref_table
   AND pl.item_ref_id    = sub.item_ref_id
   AND pl.order_no       = sub.order_no;

-- ── 4. Prepiši trigger da propagira drawing_no ──────────────────────────────
-- Trigger sada:
--   • ako NEW.drawing_no == '' (klijent nije poslao), pokuša da izvuče iz note
--     (RNZ format "Crtež:NNN | ..."). Time staro ponašanje i dalje radi bez
--     izmene klijenta.
--   • u placement upsert kopira drawing_no ILI — ako NEW.drawing_no prazan ali
--     postoji prethodni placement sa drawing_no — čuva stari (ne briše ga).
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

  /* Drawing normalization: ako NEW.drawing_no nije poslat, pokušaj da ga izvučeš
   * iz note. Ako ni to ne uspe, ostaje ''. Ovo je mehanizam koji retroaktivno
   * popunjava drawing_no za legacy klijente koji još ne šalju polje. */
  v_drawing := COALESCE(NULLIF(trim(NEW.drawing_no), ''), '');
  IF v_drawing = '' AND NEW.note IS NOT NULL AND NEW.note ~ 'Crte[žz]:[^\s|]+' THEN
    v_drawing := substring(NEW.note FROM 'Crte[žz]:([^\s|]+)');
  END IF;

  /* Ako smo izvukli drawing_no iz note a polje na movement-u je prazno,
   * popuni ga i u movement-u da backfill ostane konzistentan. */
  IF v_drawing <> '' AND (NEW.drawing_no IS NULL OR NEW.drawing_no = '') THEN
    UPDATE public.loc_location_movements
       SET drawing_no = v_drawing
     WHERE id = NEW.id;
  END IF;

  /* TO lokacija: upsert po (table, id, order_no, location). */
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
      /* Drawing_no: ne briši postojeći ako novi movement ne nosi crtež. */
      drawing_no = CASE
        WHEN EXCLUDED.drawing_no <> '' THEN EXCLUDED.drawing_no
        ELSE public.loc_item_placements.drawing_no
      END,
      updated_at = now();
  END IF;

  /* FROM lokacija: oduzmi qty iz istog (table, id, order_no) bucket-a. */
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

  /* Sync outbound event — dodaj drawing_no u payload. */
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
      'drawing_no', v_drawing,
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

  RETURN NEW;
END;
$fn_trig$;

-- ── 5. Prepiši loc_create_movement da prihvata drawing_no iz payload-a ──────
CREATE OR REPLACE FUNCTION public.loc_create_movement(payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_cm$
DECLARE
  v_item_table TEXT;
  v_item_id    TEXT;
  v_order      TEXT;
  v_drawing    TEXT;
  v_to         UUID;
  v_from       UUID;
  v_mtype      public.loc_movement_type_enum;
  v_uid        UUID;
  v_qty        NUMERIC(12,3);
  v_avail      NUMERIC(12,3);
  v_existing_any BOOLEAN;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_authenticated');
  END IF;

  v_item_table := nullif(trim(payload->>'item_ref_table'), '');
  v_item_id    := nullif(trim(payload->>'item_ref_id'), '');
  v_order      := COALESCE(trim(payload->>'order_no'), '');
  v_drawing    := COALESCE(trim(payload->>'drawing_no'), '');
  v_mtype      := (payload->>'movement_type')::public.loc_movement_type_enum;

  v_qty := coalesce((payload->>'quantity')::numeric, 1);
  IF v_qty IS NULL OR v_qty <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_quantity');
  END IF;

  IF char_length(v_order) > 40 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_order_no');
  END IF;
  IF char_length(v_drawing) > 40 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_drawing_no');
  END IF;

  IF payload ? 'to_location_id' AND nullif(trim(payload->>'to_location_id'), '') IS NOT NULL THEN
    v_to := (payload->>'to_location_id')::uuid;
  END IF;
  IF payload ? 'from_location_id' AND nullif(trim(payload->>'from_location_id'), '') IS NOT NULL THEN
    v_from := (payload->>'from_location_id')::uuid;
  END IF;

  IF v_item_table IS NULL OR v_item_id IS NULL OR v_to IS NULL OR v_mtype IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'missing_fields');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.loc_locations loc_chk
    WHERE loc_chk.id = v_to AND loc_chk.is_active
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'bad_to_location');
  END IF;

  v_existing_any := EXISTS (
    SELECT 1 FROM public.loc_item_placements lp
     WHERE lp.item_ref_table = v_item_table
       AND lp.item_ref_id    = v_item_id
       AND lp.order_no       = v_order
  );

  IF v_mtype = 'INITIAL_PLACEMENT' THEN
    IF v_existing_any THEN
      RETURN jsonb_build_object('ok', false, 'error', 'already_placed');
    END IF;
    v_from := NULL;
  ELSIF v_mtype = 'INVENTORY_ADJUSTMENT' THEN
    v_from := NULL;
  ELSE
    IF v_from IS NULL THEN
      DECLARE
        v_cnt INTEGER;
      BEGIN
        v_cnt := (
          SELECT count(*)::int
            FROM public.loc_item_placements lp
           WHERE lp.item_ref_table = v_item_table
             AND lp.item_ref_id    = v_item_id
             AND lp.order_no       = v_order
        );
        IF v_cnt = 0 THEN
          RETURN jsonb_build_object('ok', false, 'error', 'no_current_placement');
        ELSIF v_cnt > 1 THEN
          RETURN jsonb_build_object('ok', false, 'error', 'from_ambiguous');
        END IF;
        v_from := (
          SELECT lp.location_id
            FROM public.loc_item_placements lp
           WHERE lp.item_ref_table = v_item_table
             AND lp.item_ref_id    = v_item_id
             AND lp.order_no       = v_order
           LIMIT 1
        );
      END;
    END IF;

    v_avail := (
      SELECT lp.quantity
        FROM public.loc_item_placements lp
       WHERE lp.item_ref_table = v_item_table
         AND lp.item_ref_id    = v_item_id
         AND lp.order_no       = v_order
         AND lp.location_id    = v_from
       LIMIT 1
    );

    IF v_avail IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', 'from_has_no_placement');
    END IF;
    IF v_qty > v_avail THEN
      RETURN jsonb_build_object(
        'ok', false, 'error', 'insufficient_quantity',
        'available', v_avail, 'requested', v_qty
      );
    END IF;
  END IF;

  RETURN (
    WITH ins AS (
      INSERT INTO public.loc_location_movements (
        item_ref_table, item_ref_id, order_no, drawing_no,
        from_location_id, to_location_id,
        movement_type, movement_reason, quantity, note, moved_at, moved_by
      ) VALUES (
        v_item_table,
        v_item_id,
        v_order,
        v_drawing,
        v_from,
        v_to,
        v_mtype,
        nullif(trim(payload->>'movement_reason'), ''),
        v_qty,
        nullif(trim(payload->>'note'), ''),
        coalesce((payload->>'moved_at')::timestamptz, now()),
        v_uid
      )
      RETURNING id
    )
    SELECT jsonb_build_object('ok', true, 'id', ins.id) FROM ins
  );
EXCEPTION
  WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'error', 'exception', 'detail', SQLERRM);
END;
$fn_cm$;

GRANT EXECUTE ON FUNCTION public.loc_create_movement(jsonb) TO authenticated;

-- ── 6. Sanity check ─────────────────────────────────────────────────────────
DO $sanity$
DECLARE
  v_has_pl_dr    BOOLEAN;
  v_has_mv_dr    BOOLEAN;
BEGIN
  v_has_pl_dr := EXISTS(
    SELECT 1 FROM information_schema.columns
     WHERE table_schema='public' AND table_name='loc_item_placements' AND column_name='drawing_no'
  );
  v_has_mv_dr := EXISTS(
    SELECT 1 FROM information_schema.columns
     WHERE table_schema='public' AND table_name='loc_location_movements' AND column_name='drawing_no'
  );

  IF NOT (v_has_pl_dr AND v_has_mv_dr) THEN
    RAISE EXCEPTION 'loc v4 migration sanity failed: pl_drawing=%, mv_drawing=%',
      v_has_pl_dr, v_has_mv_dr;
  END IF;

  RAISE NOTICE 'loc v4 migration applied OK (drawing_no first-class + backfill).';
END
$sanity$;
