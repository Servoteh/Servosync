-- Reversi R1 (continuation): matches sql/migrations/add_reversi_module.sql §11.
-- Split from the monolithic file so Supabase hosted migrations stay bounded.
-- Applied on hosted Supabase as migration version 20260504062851.

-- ------------------------------------------------------------
-- 11. RPC: rev_issue_reversal(jsonb)
--     loc_create_movement(jsonb) vraća jsonb { ok, id } (vidi add_loc_v4_drawing_no.sql).
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION rev_issue_reversal(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_doc_id          uuid;
  v_doc_number      text;
  v_loc_id          uuid;
  v_line            jsonb;
  v_line_id         uuid;
  v_move_res        jsonb;
  v_movement_id     uuid;
  v_recipient_key   text;
  v_recipient_label text;
  v_item_ref_table  text;
  v_item_ref_id     text;
  v_drawing_no      text;
  v_order_no        text;
  v_from_loc        uuid;
  v_tool_row        rev_tools%ROWTYPE;
BEGIN
  IF NOT rev_can_manage() THEN
    RAISE EXCEPTION 'Nemate pravo da kreirate reversal dokument.'
      USING ERRCODE = '42501';
  END IF;

  IF p_payload->>'doc_type' IS NULL THEN
    RAISE EXCEPTION 'doc_type je obavezan.';
  END IF;
  IF p_payload->>'recipient_type' IS NULL THEN
    RAISE EXCEPTION 'recipient_type je obavezan.';
  END IF;
  IF jsonb_array_length(COALESCE(p_payload->'lines', '[]'::jsonb)) = 0 THEN
    RAISE EXCEPTION 'Dokument mora imati najmanje jednu stavku.';
  END IF;

  CASE p_payload->>'recipient_type'
    WHEN 'EMPLOYEE' THEN
      v_recipient_key   := p_payload->>'recipient_employee_id';
      v_recipient_label := COALESCE(p_payload->>'recipient_employee_name', 'Nepoznat radnik');
    WHEN 'DEPARTMENT' THEN
      v_recipient_key   := lower(regexp_replace(
        COALESCE(p_payload->>'recipient_department', 'nepoznato'),
        '[^a-z0-9]', '-', 'g'
      ));
      v_recipient_label := COALESCE(p_payload->>'recipient_department', 'Nepoznato odeljenje');
    WHEN 'EXTERNAL_COMPANY' THEN
      v_recipient_key   := lower(regexp_replace(
        COALESCE(p_payload->>'recipient_company_name', 'nepoznata'),
        '[^a-z0-9]', '-', 'g'
      ));
      v_recipient_label := COALESCE(p_payload->>'recipient_company_name', 'Nepoznata firma');
    ELSE
      RAISE EXCEPTION 'Nepoznat recipient_type: %', p_payload->>'recipient_type';
  END CASE;

  IF v_recipient_key IS NULL OR v_recipient_key = '' THEN
    RAISE EXCEPTION 'Primalac nije ispravno definisan (recipient_key je prazan).';
  END IF;

  v_doc_number := rev_next_doc_number(p_payload->>'doc_type');

  v_loc_id := rev_get_or_create_recipient_location(
    p_payload->>'recipient_type',
    v_recipient_key,
    v_recipient_label
  );

  INSERT INTO rev_documents (
    doc_number,
    doc_type,
    recipient_type,
    recipient_employee_id,
    recipient_employee_name,
    recipient_department,
    recipient_company_name,
    recipient_company_pib,
    recipient_loc_id,
    expected_return_date,
    issued_by,
    napomena
  ) VALUES (
    v_doc_number,
    p_payload->>'doc_type',
    p_payload->>'recipient_type',
    NULLIF(p_payload->>'recipient_employee_id', '')::uuid,
    p_payload->>'recipient_employee_name',
    p_payload->>'recipient_department',
    p_payload->>'recipient_company_name',
    p_payload->>'recipient_company_pib',
    v_loc_id,
    NULLIF(p_payload->>'expected_return_date', '')::date,
    auth.uid(),
    p_payload->>'napomena'
  )
  RETURNING id INTO v_doc_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_payload->'lines')
  LOOP
    IF (v_line->>'line_type') = 'TOOL' THEN
      IF NULLIF(trim(v_line->>'tool_id'), '') IS NULL THEN
        RAISE EXCEPTION 'TOOL stavka zahteva tool_id.';
      END IF;
      SELECT * INTO v_tool_row FROM rev_tools WHERE id = (v_line->>'tool_id')::uuid;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Alat nije pronadjen: %', v_line->>'tool_id';
      END IF;
      v_item_ref_table := 'rev_tools';
      v_item_ref_id    := v_tool_row.loc_item_ref_id;
      v_drawing_no     := '';
      v_order_no       := '';
      SELECT lp.location_id INTO v_from_loc
      FROM loc_item_placements lp
      WHERE lp.item_ref_table = 'rev_tools'
        AND lp.item_ref_id = v_tool_row.loc_item_ref_id
      ORDER BY lp.placed_at DESC
      LIMIT 1;
    ELSE
      v_item_ref_table := 'bigtehn_drawings_cache';
      v_item_ref_id    := COALESCE(v_line->>'drawing_no', v_line->>'part_name', 'UNKNOWN');
      v_drawing_no     := COALESCE(v_line->>'drawing_no', '');
      v_order_no       := COALESCE(v_line->>'work_order_id', '');
      v_from_loc       := NULL;
    END IF;

    INSERT INTO rev_document_lines (
      document_id,
      sort_order,
      line_type,
      tool_id,
      drawing_no,
      work_order_id,
      part_name,
      quantity,
      unit,
      napomena
    ) VALUES (
      v_doc_id,
      COALESCE((v_line->>'sort_order')::int, 0),
      v_line->>'line_type',
      NULLIF(v_line->>'tool_id', '')::uuid,
      v_line->>'drawing_no',
      NULLIF(v_line->>'work_order_id', '')::uuid,
      v_line->>'part_name',
      COALESCE((v_line->>'quantity')::numeric, 1),
      COALESCE(v_line->>'unit', 'kom'),
      v_line->>'napomena'
    )
    RETURNING id INTO v_line_id;

    v_move_res := loc_create_movement(jsonb_build_object(
      'item_ref_table',  v_item_ref_table,
      'item_ref_id',     v_item_ref_id,
      'from_location_id', v_from_loc,
      'to_location_id',  v_loc_id,
      'movement_type',   'REVERSAL_ISSUE',
      'movement_reason', 'Reversal: ' || v_doc_number,
      'note',            COALESCE(v_line->>'napomena', ''),
      'quantity',        COALESCE((v_line->>'quantity')::numeric, 1),
      'order_no',        v_order_no,
      'drawing_no',      v_drawing_no
    ));

    IF COALESCE((v_move_res->>'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'loc_create_movement neuspesan: %', v_move_res->>'error'
        USING DETAIL = v_move_res::text;
    END IF;

    v_movement_id := (v_move_res->>'id')::uuid;

    UPDATE rev_document_lines
    SET issue_movement_id = v_movement_id
    WHERE id = v_line_id;

  END LOOP;

  RETURN jsonb_build_object(
    'success',    true,
    'doc_id',     v_doc_id,
    'doc_number', v_doc_number
  );
END;
$$;

REVOKE ALL ON FUNCTION rev_issue_reversal(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rev_issue_reversal(jsonb) TO authenticated;

