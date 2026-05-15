-- Lokacije: validacija predmeta (N-N osnovica), kanonski ključ za 9400-2/415 → 9400 + TP 2/415,
-- loc_create_movement normalizacija + blokada neaktivnog predmeta, konsolidacija duplog smeštaja 1109298,
-- loc_report join za TP ref sa vodećom crticom.

CREATE OR REPLACE FUNCTION public.loc_order_no_in_active_proj_mont(p_order_no text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, production, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM (
      SELECT NULLIF(trim(both ' ' FROM p_order_no), '') AS broj
      UNION ALL
      SELECT split_part(trim(both ' ' FROM p_order_no), '-', 1)
      WHERE trim(both ' ' FROM p_order_no) ~ '^[0-9]+-[0-9]+$'
    ) c
    INNER JOIN public.bigtehn_items_cache i ON i.broj_predmeta = c.broj
    INNER JOIN production.predmet_aktivacija pa ON pa.predmet_item_id = i.id
    WHERE c.broj IS NOT NULL
      AND pa.je_aktivan IS TRUE
      AND pa.je_projektovanje_montaza IS TRUE
  );
$$;

COMMENT ON FUNCTION public.loc_order_no_in_active_proj_mont(text) IS
  'Za modul Lokacije/sken: da li p_order_no (ili osnovica pre prve crtice N-N) postoji u podešavanjima kao aktivan predmet sa uključenom montažom/projektovanjem.';

REVOKE ALL ON FUNCTION public.loc_order_no_in_active_proj_mont(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.loc_order_no_in_active_proj_mont(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.loc_normalize_loc_movement_keys(p_order text, p_item_ref text)
RETURNS TABLE(out_order text, out_item_ref text)
LANGUAGE plpgsql
IMMUTABLE
AS $norm$
DECLARE
  o text := nullif(trim(both FROM coalesce(p_order, '')), '');
  r text := nullif(trim(both FROM coalesce(p_item_ref, '')), '');
BEGIN
  IF o IS NULL THEN
    o := '';
  END IF;
  IF r IS NULL THEN
    r := '';
  END IF;
  IF o = '' OR r = '' THEN
    out_order := o;
    out_item_ref := r;
    RETURN NEXT;
    RETURN;
  END IF;

  IF o ~ '^9400-[0-9]+$' AND r ~ '^[0-9]+$' THEN
    out_order := '9400';
    out_item_ref := substring(o FROM '^9400-([0-9]+)$') || '/' || r;
    RETURN NEXT;
    RETURN;
  END IF;

  IF o = '9400' AND r ~ '^-?[0-9]+/[0-9]+$' THEN
    out_order := '9400';
    out_item_ref := regexp_replace(r, '^-', '');
    RETURN NEXT;
    RETURN;
  END IF;

  out_order := o;
  out_item_ref := r;
  RETURN NEXT;
END;
$norm$;

COMMENT ON FUNCTION public.loc_normalize_loc_movement_keys(text, text) IS
  'Kanonski nalog/TP za lokacije (npr. 9400-2 + 415 → 9400 / 2/415; uklanja vodeću crticu ako je ostala iz starog zapisa).';

REVOKE ALL ON FUNCTION public.loc_normalize_loc_movement_keys(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.loc_normalize_loc_movement_keys(text, text) TO authenticated;

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
  v_new_id     UUID;
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

  SELECT n.out_order, n.out_item_ref
    INTO v_order, v_item_id
  FROM public.loc_normalize_loc_movement_keys(v_order, v_item_id) n;

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

  IF v_order <> '' AND NOT public.loc_order_no_in_active_proj_mont(v_order) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'inactive_predmet');
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
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('ok', true, 'id', v_new_id);
EXCEPTION
  WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'error', 'exception', 'detail', SQLERRM);
END;
$fn_cm$;

COMMENT ON FUNCTION public.loc_create_movement(jsonb) IS
  'Kreira loc_location_movements red; normalizuje 9400/TP i zahteva aktivan predmet (montaža/proj.).';

-- Konsolidacija: istorijski duplikat 9400 vs 9400-2 sa TP=415, crtež 1109298 — novija lokacija ostaje.
WITH candidates AS (
  SELECT lp.id, lp.location_id, lp.quantity, lp.updated_at
  FROM public.loc_item_placements lp
  WHERE lp.item_ref_table = 'bigtehn_rn'
    AND trim(lp.drawing_no) = '1109298'
    AND trim(lp.item_ref_id) = '415'
    AND trim(lp.order_no) IN ('9400', '9400-2')
),
ranked AS (
  SELECT id, location_id, quantity,
    row_number() OVER (ORDER BY updated_at DESC NULLS LAST, id DESC) AS rk
  FROM candidates
),
winner AS (
  SELECT id, location_id, quantity FROM ranked WHERE rk = 1
)
UPDATE public.loc_item_placements p
SET
  order_no = '9400',
  item_ref_id = '2/415',
  location_id = w.location_id,
  quantity = w.quantity,
  updated_at = now()
FROM winner w
WHERE p.id = w.id;

WITH candidates AS (
  SELECT lp.id, lp.updated_at
  FROM public.loc_item_placements lp
  WHERE lp.item_ref_table = 'bigtehn_rn'
    AND trim(lp.drawing_no) = '1109298'
    AND trim(lp.item_ref_id) = '415'
    AND trim(lp.order_no) IN ('9400', '9400-2')
),
ranked AS (
  SELECT id,
    row_number() OVER (ORDER BY updated_at DESC NULLS LAST, id DESC) AS rk
  FROM candidates
)
DELETE FROM public.loc_item_placements p
WHERE p.id IN (SELECT id FROM ranked WHERE rk > 1);

NOTIFY pgrst, 'reload schema';
