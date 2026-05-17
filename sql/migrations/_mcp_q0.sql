-- ΓöÇΓöÇ 1) System user za worker writes ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
-- Stable UUID '00000000-0000-0000-0000-000000000099' = bigtehn-worker pseudo
-- user. Ne loguje se u UI, samo poseduje row u auth.users zbog FK moved_by.
INSERT INTO auth.users (id, email)
VALUES ('00000000-0000-0000-0000-000000000099', 'bigtehn-worker@system.local')
ON CONFLICT (id) DO NOTHING;

-- ΓöÇΓöÇ 2) Update trigger: skip MSSQL outbox kad source='bigtehn' ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
   * poku┼íaj da ga izvu─ìe┼í iz note (RNZ format ΓÇ₧Crte┼╛:NNN | ΓÇª"). */
  v_drawing := COALESCE(NULLIF(trim(NEW.drawing_no), ''), '');
  IF v_drawing = '' AND NEW.note IS NOT NULL AND NEW.note ~ 'Crte[┼╛z]:[^\s|]+' THEN
    v_drawing := substring(NEW.note FROM 'Crte[┼╛z]:([^\s|]+)');
  END IF;

  IF v_drawing <> '' AND (NEW.drawing_no IS NULL OR NEW.drawing_no = '') THEN
    UPDATE public.loc_location_movements
       SET drawing_no = v_drawing
     WHERE id = NEW.id;
  END IF;

  /* TO lokacija upsert ΓÇö placement state. */
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

  /* Sync outbound event ΓÇö Faza 2B addition: SKIP ako je source='bigtehn'.
   * Signal je ve─ç do┼íao iz MSSQL-a, vra─çanje bi pravilo sync loop. */
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

