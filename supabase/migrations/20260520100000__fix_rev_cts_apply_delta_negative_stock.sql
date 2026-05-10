-- rev_cts_apply_delta: negativan delta na nepostojećem redu je INSERT-ovao on_hand_qty < 0
-- i pucao na CHECK pre nego što se primeni ON CONFLICT logika.
-- Sada prvo proveravamo trenutno stanje (FOR UPDATE kad red postoji), pa tek UPSERT.

CREATE OR REPLACE FUNCTION public.rev_cts_apply_delta(
  p_catalog_id  uuid,
  p_location_id uuid,
  p_delta       numeric
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new numeric;
  v_old numeric;
BEGIN
  IF p_catalog_id IS NULL OR p_location_id IS NULL THEN
    RAISE EXCEPTION 'rev_cts_apply_delta: catalog_id i location_id su obavezni.';
  END IF;
  IF p_delta = 0 THEN
    SELECT on_hand_qty INTO v_old FROM rev_cutting_tool_stock
    WHERE catalog_id = p_catalog_id AND location_id = p_location_id;
    RETURN COALESCE(v_old, 0);
  END IF;

  SELECT on_hand_qty INTO v_old FROM rev_cutting_tool_stock
  WHERE catalog_id = p_catalog_id AND location_id = p_location_id
  FOR UPDATE;

  v_old := COALESCE(v_old, 0);

  IF v_old + p_delta < 0 THEN
    RAISE EXCEPTION 'Nedovoljna količina reznog alata na lokaciji % (catalog=%, trenutno=%, traženo oduzimanje=%).',
      p_location_id, p_catalog_id, v_old, -p_delta
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO rev_cutting_tool_stock (catalog_id, location_id, on_hand_qty, updated_at)
  VALUES (p_catalog_id, p_location_id, p_delta, now())
  ON CONFLICT (catalog_id, location_id) DO UPDATE
    SET on_hand_qty = rev_cutting_tool_stock.on_hand_qty + EXCLUDED.on_hand_qty,
        updated_at  = now()
  RETURNING on_hand_qty INTO v_new;

  IF v_new < 0 THEN
    RAISE EXCEPTION 'Nedovoljna količina reznog alata na lokaciji % (catalog=%, rezultujuće stanje=%).',
      p_location_id, p_catalog_id, v_new
      USING ERRCODE = 'P0001';
  END IF;

  RETURN v_new;
END;
$$;

NOTIFY pgrst, 'reload schema';
