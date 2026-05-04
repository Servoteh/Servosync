-- ============================================================
-- REVERSI MODUL — Sprint R1
-- Opis: zaduzenje alata i kooperacione robe, integracija sa
--       Lokacije modulom (loc_location_movements).
-- Zavisi od: loc_* (add_loc_module + v2/v3/v4), touch_updated_at(),
--           auth.users, employees, user_roles.
-- ============================================================

-- touch_updated_at() — iz add_maintenance_module / schema; osiguraj ako fali
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'touch_updated_at'
  ) THEN
    CREATE OR REPLACE FUNCTION public.touch_updated_at()
    RETURNS TRIGGER AS $f$
    BEGIN NEW.updated_at := now(); RETURN NEW; END;
    $f$ LANGUAGE plpgsql;
  END IF;
END $$;

-- ------------------------------------------------------------
-- 1. Nove vrednosti u loc_movement_type_enum
-- ------------------------------------------------------------

ALTER TYPE loc_movement_type_enum ADD VALUE IF NOT EXISTS 'REVERSAL_ISSUE';
ALTER TYPE loc_movement_type_enum ADD VALUE IF NOT EXISTS 'REVERSAL_RETURN';

-- ------------------------------------------------------------
-- 2. Tabela rev_tools — inventar alata
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rev_tools (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  oznaka           text        NOT NULL,
  naziv            text        NOT NULL,
  serijski_broj    text,
  datum_kupovine   date,
  -- 'active' | 'scrapped' | 'lost'
  status           text        NOT NULL DEFAULT 'active'
                               CHECK (status IN ('active', 'scrapped', 'lost')),
  napomena         text,
  -- Puni se triggerom: 'rev_tools:' || id::text
  -- Ovaj string je item_ref_id koji ide u loc_item_placements
  loc_item_ref_id  text        UNIQUE,
  created_at       timestamptz NOT NULL DEFAULT now(),
  created_by       uuid        REFERENCES auth.users(id),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION rev_tools_set_item_ref()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.loc_item_ref_id := 'rev_tools:' || NEW.id::text;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS rev_tools_before_insert ON rev_tools;
CREATE TRIGGER rev_tools_before_insert
  BEFORE INSERT ON rev_tools
  FOR EACH ROW EXECUTE FUNCTION rev_tools_set_item_ref();

DROP TRIGGER IF EXISTS rev_tools_updated_at ON rev_tools;
CREATE TRIGGER rev_tools_updated_at
  BEFORE UPDATE ON rev_tools
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

COMMENT ON TABLE rev_tools IS
  'Inventar alata u vlasnistu Servoteh koji se zaduzuju radnicima, odelenjima ili eksternim firmama.';
COMMENT ON COLUMN rev_tools.loc_item_ref_id IS
  'Identifikator za loc_item_placements.item_ref_id. Format: rev_tools:<uuid>.';

-- ------------------------------------------------------------
-- 3. Tabela rev_recipient_locations
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rev_recipient_locations (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- 'EMPLOYEE' | 'DEPARTMENT' | 'EXTERNAL_COMPANY'
  recipient_type   text        NOT NULL
                               CHECK (recipient_type IN ('EMPLOYEE', 'DEPARTMENT', 'EXTERNAL_COMPANY')),
  recipient_key    text        NOT NULL,
  recipient_label  text        NOT NULL,
  loc_location_id  uuid        NOT NULL REFERENCES loc_locations(id),
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (recipient_type, recipient_key)
);

COMMENT ON TABLE rev_recipient_locations IS
  'Mapa: primalac reversala (radnik/odelenje/firma) → virtuelna loc_locations lokacija.';

-- ------------------------------------------------------------
-- 4. Tabela rev_documents
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rev_documents (
  id                       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_number               text        NOT NULL UNIQUE,
  doc_type                 text        NOT NULL
                                       CHECK (doc_type IN ('TOOL', 'COOPERATION_GOODS')),
  recipient_type           text        NOT NULL
                                       CHECK (recipient_type IN ('EMPLOYEE', 'DEPARTMENT', 'EXTERNAL_COMPANY')),
  recipient_employee_id    uuid        REFERENCES employees(id),
  recipient_employee_name  text,
  recipient_department     text,
  recipient_company_name   text,
  recipient_company_pib    text,
  recipient_loc_id         uuid        REFERENCES loc_locations(id),
  expected_return_date     date,
  issued_at                timestamptz NOT NULL DEFAULT now(),
  issued_by                uuid        NOT NULL REFERENCES auth.users(id),
  status                   text        NOT NULL DEFAULT 'OPEN'
                                       CHECK (status IN ('OPEN', 'PARTIALLY_RETURNED', 'RETURNED', 'CANCELLED')),
  return_confirmed_by      uuid        REFERENCES auth.users(id),
  return_confirmed_at      timestamptz,
  return_notes             text,
  pdf_storage_path         text,
  pdf_generated_at         timestamptz,
  napomena                 text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS rev_documents_updated_at ON rev_documents;
CREATE TRIGGER rev_documents_updated_at
  BEFORE UPDATE ON rev_documents
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

COMMENT ON TABLE rev_documents IS
  'Reversal dokument — zaglavlje zaduzenja alata ili kooperacione robe.';
COMMENT ON COLUMN rev_documents.doc_type IS
  'TOOL = zaduzenje alata; COOPERATION_GOODS = roba na medjufaznu uslugu kooperantu.';

-- ------------------------------------------------------------
-- 5. Tabela rev_document_lines
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rev_document_lines (
  id                  uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id         uuid          NOT NULL REFERENCES rev_documents(id) ON DELETE CASCADE,
  sort_order          int           NOT NULL DEFAULT 0,
  line_type           text          NOT NULL
                                    CHECK (line_type IN ('TOOL', 'PRODUCTION_PART')),
  tool_id             uuid          REFERENCES rev_tools(id),
  drawing_no          text,
  work_order_id       uuid,
  part_name           text,
  quantity            numeric(12,3) NOT NULL DEFAULT 1,
  unit                text          NOT NULL DEFAULT 'kom',
  napomena            text,
  issue_movement_id   uuid,
  returned_quantity   numeric(12,3) NOT NULL DEFAULT 0,
  return_movement_id  uuid,
  line_status         text          NOT NULL DEFAULT 'ISSUED'
                                    CHECK (line_status IN ('ISSUED', 'RETURNED', 'LOST', 'SCRAPPED')),
  created_at          timestamptz   NOT NULL DEFAULT now()
);

COMMENT ON TABLE rev_document_lines IS
  'Stavke reversal dokumenta. Svaka stavka ima odgovarajuci loc_location_movements zapis.';
COMMENT ON COLUMN rev_document_lines.napomena IS
  'Slobodan tekst: pribor koji prati alat (baterije, punjaci, dodaci).';

-- ------------------------------------------------------------
-- 6. Indeksi
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS rev_documents_status_idx      ON rev_documents (status);
CREATE INDEX IF NOT EXISTS rev_documents_issued_by_idx   ON rev_documents (issued_by);
CREATE INDEX IF NOT EXISTS rev_documents_issued_at_idx   ON rev_documents (issued_at DESC);
CREATE INDEX IF NOT EXISTS rev_documents_doc_type_idx    ON rev_documents (doc_type, status);
CREATE INDEX IF NOT EXISTS rev_documents_employee_idx    ON rev_documents (recipient_employee_id)
  WHERE recipient_employee_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS rev_document_lines_doc_idx    ON rev_document_lines (document_id);
CREATE INDEX IF NOT EXISTS rev_document_lines_tool_idx   ON rev_document_lines (tool_id)
  WHERE tool_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS rev_document_lines_status_idx ON rev_document_lines (line_status);
CREATE INDEX IF NOT EXISTS rev_tools_status_idx          ON rev_tools (status);
CREATE INDEX IF NOT EXISTS rev_tools_oznaka_idx          ON rev_tools (oznaka);

-- ------------------------------------------------------------
-- 7. Helper: rev_can_manage()
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION rev_can_manage()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE lower(email) = lower(auth.jwt() ->> 'email')
      AND role IN ('admin', 'menadzment', 'pm', 'leadpm', 'magacioner')
      AND (is_active IS NULL OR is_active = true)
  );
$$;

REVOKE ALL ON FUNCTION rev_can_manage() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rev_can_manage() TO authenticated;

COMMENT ON FUNCTION rev_can_manage() IS
  'Vraca true ako prijavljeni korisnik ima ulogu koja dozvoljava kreiranje/potvrdu reversala.';

-- ------------------------------------------------------------
-- 8. RLS politike
-- ------------------------------------------------------------

ALTER TABLE rev_tools               ENABLE ROW LEVEL SECURITY;
ALTER TABLE rev_documents           ENABLE ROW LEVEL SECURITY;
ALTER TABLE rev_document_lines      ENABLE ROW LEVEL SECURITY;
ALTER TABLE rev_recipient_locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rev_tools_select ON rev_tools;
CREATE POLICY rev_tools_select ON rev_tools
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS rev_tools_insert ON rev_tools;
CREATE POLICY rev_tools_insert ON rev_tools
  FOR INSERT TO authenticated
  WITH CHECK (rev_can_manage());

DROP POLICY IF EXISTS rev_tools_update ON rev_tools;
CREATE POLICY rev_tools_update ON rev_tools
  FOR UPDATE TO authenticated
  USING (rev_can_manage())
  WITH CHECK (rev_can_manage());

DROP POLICY IF EXISTS rev_documents_select ON rev_documents;
CREATE POLICY rev_documents_select ON rev_documents
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS rev_documents_insert ON rev_documents;
CREATE POLICY rev_documents_insert ON rev_documents
  FOR INSERT TO authenticated
  WITH CHECK (rev_can_manage());

DROP POLICY IF EXISTS rev_documents_update ON rev_documents;
CREATE POLICY rev_documents_update ON rev_documents
  FOR UPDATE TO authenticated
  USING (rev_can_manage())
  WITH CHECK (rev_can_manage());

DROP POLICY IF EXISTS rev_lines_select ON rev_document_lines;
CREATE POLICY rev_lines_select ON rev_document_lines
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS rev_lines_insert ON rev_document_lines;
CREATE POLICY rev_lines_insert ON rev_document_lines
  FOR INSERT TO authenticated
  WITH CHECK (
    rev_can_manage()
    AND EXISTS (
      SELECT 1 FROM rev_documents d
      WHERE d.id = document_id
        AND d.status = 'OPEN'
    )
  );

DROP POLICY IF EXISTS rev_lines_update ON rev_document_lines;
CREATE POLICY rev_lines_update ON rev_document_lines
  FOR UPDATE TO authenticated
  USING (rev_can_manage())
  WITH CHECK (rev_can_manage());

DROP POLICY IF EXISTS rev_rl_select ON rev_recipient_locations;
CREATE POLICY rev_rl_select ON rev_recipient_locations
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS rev_rl_insert ON rev_recipient_locations;
CREATE POLICY rev_rl_insert ON rev_recipient_locations
  FOR INSERT TO authenticated
  WITH CHECK (rev_can_manage());

-- ------------------------------------------------------------
-- 9. rev_get_or_create_recipient_location()
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION rev_get_or_create_recipient_location(
  p_recipient_type  text,
  p_recipient_key   text,
  p_recipient_label text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_loc_id   uuid;
  v_loc_code text;
  v_loc_type loc_type_enum;
BEGIN
  SELECT loc_location_id INTO v_loc_id
  FROM rev_recipient_locations
  WHERE recipient_type = p_recipient_type
    AND recipient_key  = p_recipient_key;

  IF v_loc_id IS NOT NULL THEN
    RETURN v_loc_id;
  END IF;

  CASE p_recipient_type
    WHEN 'EMPLOYEE' THEN
      v_loc_type := 'FIELD';
      v_loc_code := 'ZADU-R-' || substr(p_recipient_key, 1, 8);
    WHEN 'DEPARTMENT' THEN
      v_loc_type := 'FIELD';
      v_loc_code := 'ZADU-O-' || p_recipient_key;
    WHEN 'EXTERNAL_COMPANY' THEN
      v_loc_type := 'SERVICE';
      v_loc_code := 'ZADU-K-' || p_recipient_key;
    ELSE
      RAISE EXCEPTION 'Nepoznat tip primaoca: %', p_recipient_type;
  END CASE;

  INSERT INTO loc_locations (
    location_code,
    name,
    location_type,
    is_active,
    notes
  )
  VALUES (
    v_loc_code,
    'Zaduzeno: ' || p_recipient_label,
    v_loc_type,
    true,
    'Automatski kreirana virtuelna lokacija za reversal primalac'
  )
  ON CONFLICT (location_code) DO UPDATE
    SET name      = EXCLUDED.name,
        is_active = true
  RETURNING id INTO v_loc_id;

  INSERT INTO rev_recipient_locations (
    recipient_type,
    recipient_key,
    recipient_label,
    loc_location_id
  )
  VALUES (p_recipient_type, p_recipient_key, p_recipient_label, v_loc_id)
  ON CONFLICT (recipient_type, recipient_key) DO UPDATE
    SET recipient_label = EXCLUDED.recipient_label;

  RETURN v_loc_id;
END;
$$;

REVOKE ALL ON FUNCTION rev_get_or_create_recipient_location(text, text, text) FROM PUBLIC;

-- ------------------------------------------------------------
-- 10. rev_next_doc_number(p_doc_type)
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION rev_next_doc_number(p_doc_type text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_prefix  text;
  v_year    text;
  v_max_seq int;
BEGIN
  v_prefix := CASE p_doc_type
    WHEN 'TOOL'              THEN 'REV-TOOL'
    WHEN 'COOPERATION_GOODS' THEN 'REV-KOOP'
    ELSE NULL
  END;

  IF v_prefix IS NULL THEN
    RAISE EXCEPTION 'Nepoznat tip dokumenta: %', p_doc_type;
  END IF;

  v_year := to_char(now(), 'YYYY');

  SELECT COALESCE(
    MAX((regexp_match(doc_number, '-(\d+)$'))[1]::int),
    0
  )
  INTO v_max_seq
  FROM rev_documents
  WHERE doc_number LIKE v_prefix || '-' || v_year || '-%';

  RETURN v_prefix || '-' || v_year || '-' || lpad((v_max_seq + 1)::text, 4, '0');
END;
$$;

REVOKE ALL ON FUNCTION rev_next_doc_number(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rev_next_doc_number(text) TO authenticated;

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
