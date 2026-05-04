-- Reversi R1 (continuation): matches sql/migrations/add_reversi_module.sql §§12–14.
-- Split from the monolithic file so Supabase hosted migrations stay bounded.
-- Applied on hosted Supabase as migration version 20260504062903.

-- ------------------------------------------------------------
-- 12. RPC: rev_confirm_return(jsonb)
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION rev_confirm_return(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_doc_id         uuid;
  v_doc            rev_documents%ROWTYPE;
  v_line           jsonb;
  v_line_row       rev_document_lines%ROWTYPE;
  v_move_res       jsonb;
  v_movement_id    uuid;
  v_item_ref_table text;
  v_item_ref_id    text;
  v_drawing_no     text;
  v_order_no       text;
  v_ret_qty        numeric(12,3);
  v_all_returned   boolean;
BEGIN
  IF NOT rev_can_manage() THEN
    RAISE EXCEPTION 'Nemate pravo da potvrdite povracaj.'
      USING ERRCODE = '42501';
  END IF;

  v_doc_id := (p_payload->>'doc_id')::uuid;

  SELECT * INTO v_doc
  FROM rev_documents
  WHERE id = v_doc_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Dokument nije pronadjen: %', v_doc_id
      USING ERRCODE = 'P0002';
  END IF;

  IF v_doc.status IN ('RETURNED', 'CANCELLED') THEN
    RAISE EXCEPTION 'Dokument je vec zatvoren (status: %).', v_doc.status
      USING ERRCODE = 'P0001';
  END IF;

  FOR v_line IN SELECT * FROM jsonb_array_elements(COALESCE(p_payload->'returned_lines', '[]'::jsonb))
  LOOP
    SELECT * INTO v_line_row
    FROM rev_document_lines
    WHERE id = (v_line->>'line_id')::uuid
      AND document_id = v_doc_id;

    IF NOT FOUND THEN CONTINUE; END IF;
    IF v_line_row.line_status = 'RETURNED' THEN CONTINUE; END IF;

    v_ret_qty := COALESCE((v_line->>'returned_quantity')::numeric, 0);
    IF v_ret_qty <= 0 THEN CONTINUE; END IF;

    IF v_line_row.tool_id IS NOT NULL THEN
      SELECT loc_item_ref_id INTO v_item_ref_id FROM rev_tools WHERE id = v_line_row.tool_id;
      IF v_item_ref_id IS NULL THEN
        RAISE EXCEPTION 'Alat nema loc_item_ref_id: %', v_line_row.tool_id;
      END IF;
      v_item_ref_table := 'rev_tools';
      v_drawing_no     := '';
      v_order_no       := '';
    ELSE
      v_item_ref_table := 'bigtehn_drawings_cache';
      v_item_ref_id    := COALESCE(v_line_row.drawing_no, 'UNKNOWN');
      v_drawing_no     := COALESCE(v_line_row.drawing_no, '');
      v_order_no       := COALESCE(v_line_row.work_order_id::text, '');
    END IF;

    v_move_res := loc_create_movement(jsonb_build_object(
      'item_ref_table',   v_item_ref_table,
      'item_ref_id',      v_item_ref_id,
      'from_location_id', v_doc.recipient_loc_id,
      'to_location_id',   (p_payload->>'return_to_location_id')::uuid,
      'movement_type',    'REVERSAL_RETURN',
      'movement_reason',  'Povracaj: ' || v_doc.doc_number,
      'note',             COALESCE(p_payload->>'return_notes', ''),
      'quantity',         v_ret_qty,
      'drawing_no',       v_drawing_no,
      'order_no',         v_order_no
    ));

    IF COALESCE((v_move_res->>'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'loc_create_movement neuspesan: %', v_move_res->>'error'
        USING DETAIL = v_move_res::text;
    END IF;

    v_movement_id := (v_move_res->>'id')::uuid;

    UPDATE rev_document_lines
    SET
      returned_quantity  = v_line_row.returned_quantity + v_ret_qty,
      return_movement_id = v_movement_id,
      line_status        = CASE
        WHEN v_line_row.returned_quantity + v_ret_qty >= v_line_row.quantity
          THEN 'RETURNED'
        ELSE 'ISSUED'
      END
    WHERE id = v_line_row.id;

  END LOOP;

  SELECT NOT EXISTS (
    SELECT 1 FROM rev_document_lines
    WHERE document_id = v_doc_id
      AND line_status = 'ISSUED'
  ) INTO v_all_returned;

  UPDATE rev_documents
  SET
    status              = CASE WHEN v_all_returned THEN 'RETURNED' ELSE 'PARTIALLY_RETURNED' END,
    return_confirmed_by = auth.uid(),
    return_confirmed_at = now(),
    return_notes        = p_payload->>'return_notes'
  WHERE id = v_doc_id;

  RETURN jsonb_build_object(
    'success',      true,
    'all_returned', v_all_returned,
    'doc_id',       v_doc_id
  );
END;
$$;

REVOKE ALL ON FUNCTION rev_confirm_return(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rev_confirm_return(jsonb) TO authenticated;

-- ------------------------------------------------------------
-- 13. View: v_rev_my_issued_tools
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW v_rev_my_issued_tools
WITH (security_invoker = true)
AS
SELECT
  d.id                    AS document_id,
  d.doc_number,
  d.issued_at,
  d.expected_return_date,
  d.status                AS document_status,
  t.oznaka,
  t.naziv,
  t.serijski_broj,
  l.quantity,
  l.unit,
  l.napomena              AS pribor,
  l.line_status,
  d.napomena              AS napomena_dokumenta
FROM rev_document_lines l
JOIN rev_documents d ON d.id = l.document_id
LEFT JOIN rev_tools t ON t.id = l.tool_id
WHERE
  l.line_type    = 'TOOL'
  AND l.line_status = 'ISSUED'
  AND d.status   IN ('OPEN', 'PARTIALLY_RETURNED')
  AND d.recipient_employee_id IN (
    SELECT id FROM employees
    WHERE lower(email) = lower(auth.jwt() ->> 'email')
  );

REVOKE ALL ON v_rev_my_issued_tools FROM anon;
GRANT SELECT ON v_rev_my_issued_tools TO authenticated;

COMMENT ON VIEW v_rev_my_issued_tools IS
  'Self-service: svaki zaposleni vidi alate koje trenutno ima zaduzene (matchuje po email-u).';

-- ------------------------------------------------------------
-- 14. PostgREST: tabelni GRANT-ovi (RLS i dalje filtrira)
-- ------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE ON rev_tools TO authenticated;
GRANT SELECT, INSERT, UPDATE ON rev_documents TO authenticated;
GRANT SELECT, INSERT, UPDATE ON rev_document_lines TO authenticated;
GRANT SELECT, INSERT ON rev_recipient_locations TO authenticated;
