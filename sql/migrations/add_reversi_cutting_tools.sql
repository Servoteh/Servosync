-- ============================================================
-- REVERSI — Rezni alat (Sprint RZ-1)
-- Opis: Katalog reznog alata (jedna šifra → više komada),
--       stock balance po lokaciji, revers dokument tipa
--       CUTTING_TOOL gde je primalac MAŠINA + radnik kao
--       potpisnik preuzimanja. Operater na mašini zatim ima
--       self-service prikaz svojih trenutnih zaduženja.
-- Zavisi od: add_reversi_module.sql, add_loc_module*,
--            add_kadrovska_module.sql, bigtehn_machines_cache,
--            touch_updated_at(), rev_can_manage().
-- Idempotentno — bezbedno za re-run.
-- DOWN: vidi add_reversi_cutting_tools.down.sql
-- ============================================================

-- ------------------------------------------------------------
-- 1. employees.card_barcode — Code128 sa fizičke kartice radnika
-- ------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'employees'
      AND column_name = 'card_barcode'
  ) THEN
    ALTER TABLE public.employees
      ADD COLUMN card_barcode text;
  END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_employees_card_barcode
  ON public.employees (card_barcode)
  WHERE card_barcode IS NOT NULL AND card_barcode <> '';

COMMENT ON COLUMN public.employees.card_barcode IS
  'Code128 sadržaj sa fizičke ID kartice radnika. Skener vraća ovaj string. Popunjava se ručno ili iz legacy export-a.';

-- ------------------------------------------------------------
-- 2. Proširi CHECK constraint-e: doc_type, recipient_type, line_type
-- ------------------------------------------------------------

DO $$
DECLARE v_name text;
BEGIN
  SELECT conname INTO v_name
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  WHERE t.relname = 'rev_documents'
    AND c.contype = 'c'
    AND pg_get_constraintdef(c.oid) ILIKE '%doc_type%';
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.rev_documents DROP CONSTRAINT %I', v_name);
  END IF;
END$$;

ALTER TABLE public.rev_documents
  ADD CONSTRAINT rev_documents_doc_type_check
  CHECK (doc_type IN ('TOOL', 'COOPERATION_GOODS', 'CUTTING_TOOL'));

DO $$
DECLARE v_name text;
BEGIN
  SELECT conname INTO v_name
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  WHERE t.relname = 'rev_documents'
    AND c.contype = 'c'
    AND pg_get_constraintdef(c.oid) ILIKE '%recipient_type%';
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.rev_documents DROP CONSTRAINT %I', v_name);
  END IF;
END$$;

ALTER TABLE public.rev_documents
  ADD CONSTRAINT rev_documents_recipient_type_check
  CHECK (recipient_type IN ('EMPLOYEE', 'DEPARTMENT', 'EXTERNAL_COMPANY', 'MACHINE'));

DO $$
DECLARE v_name text;
BEGIN
  SELECT conname INTO v_name
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  WHERE t.relname = 'rev_recipient_locations'
    AND c.contype = 'c'
    AND pg_get_constraintdef(c.oid) ILIKE '%recipient_type%';
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.rev_recipient_locations DROP CONSTRAINT %I', v_name);
  END IF;
END$$;

ALTER TABLE public.rev_recipient_locations
  ADD CONSTRAINT rev_recipient_locations_recipient_type_check
  CHECK (recipient_type IN ('EMPLOYEE', 'DEPARTMENT', 'EXTERNAL_COMPANY', 'MACHINE'));

DO $$
DECLARE v_name text;
BEGIN
  SELECT conname INTO v_name
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  WHERE t.relname = 'rev_document_lines'
    AND c.contype = 'c'
    AND pg_get_constraintdef(c.oid) ILIKE '%line_type%';
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.rev_document_lines DROP CONSTRAINT %I', v_name);
  END IF;
END$$;

ALTER TABLE public.rev_document_lines
  ADD CONSTRAINT rev_document_lines_line_type_check
  CHECK (line_type IN ('TOOL', 'PRODUCTION_PART', 'CUTTING_TOOL'));

-- ------------------------------------------------------------
-- 3. Nove kolone na rev_documents (mašina kao primalac, potpisnik)
-- ------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'rev_documents'
      AND column_name = 'recipient_machine_code'
  ) THEN
    ALTER TABLE public.rev_documents ADD COLUMN recipient_machine_code text;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'rev_documents'
      AND column_name = 'issued_to_employee_id'
  ) THEN
    ALTER TABLE public.rev_documents
      ADD COLUMN issued_to_employee_id uuid REFERENCES public.employees(id);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'rev_documents'
      AND column_name = 'issued_to_employee_name'
  ) THEN
    ALTER TABLE public.rev_documents ADD COLUMN issued_to_employee_name text;
  END IF;
END$$;

COMMENT ON COLUMN public.rev_documents.recipient_machine_code IS
  'Mašina-primalac (rj_code iz bigtehn_machines_cache). NOT NULL kad je doc_type=CUTTING_TOOL.';
COMMENT ON COLUMN public.rev_documents.issued_to_employee_id IS
  'Operater koji je potpisao preuzimanje reznog alata na mašinu. Kasnije se može razlikovati od recipient_employee_id.';

CREATE INDEX IF NOT EXISTS rev_documents_machine_code_idx
  ON public.rev_documents (recipient_machine_code)
  WHERE recipient_machine_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS rev_documents_issued_to_emp_idx
  ON public.rev_documents (issued_to_employee_id)
  WHERE issued_to_employee_id IS NOT NULL;

-- ------------------------------------------------------------
-- 4. Tabela rev_cutting_tool_catalog — katalog reznog alata
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.rev_cutting_tool_catalog (
  id                       uuid           PRIMARY KEY DEFAULT gen_random_uuid(),
  barcode                  text           UNIQUE,
  oznaka                   text           NOT NULL,
  naziv                    text           NOT NULL,
  klasa                    text,
  compatible_machine_codes text[]         NOT NULL DEFAULT ARRAY[]::text[],
  unit                     text           NOT NULL DEFAULT 'kom',
  status                   text           NOT NULL DEFAULT 'active'
                                          CHECK (status IN ('active', 'scrapped')),
  napomena                 text,
  created_at               timestamptz    NOT NULL DEFAULT now(),
  created_by               uuid           REFERENCES auth.users(id),
  updated_at               timestamptz    NOT NULL DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS public.rev_cutting_tool_barcode_seq START 1 INCREMENT 1;

CREATE OR REPLACE FUNCTION public.rev_cutting_tool_set_barcode()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.barcode IS NULL OR btrim(NEW.barcode) = '' THEN
    NEW.barcode := 'RZN-' || lpad(nextval('public.rev_cutting_tool_barcode_seq')::text, 6, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS rev_cutting_tool_catalog_before_insert ON public.rev_cutting_tool_catalog;
CREATE TRIGGER rev_cutting_tool_catalog_before_insert
  BEFORE INSERT ON public.rev_cutting_tool_catalog
  FOR EACH ROW EXECUTE FUNCTION public.rev_cutting_tool_set_barcode();

DROP TRIGGER IF EXISTS rev_cutting_tool_catalog_updated_at ON public.rev_cutting_tool_catalog;
CREATE TRIGGER rev_cutting_tool_catalog_updated_at
  BEFORE UPDATE ON public.rev_cutting_tool_catalog
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE INDEX IF NOT EXISTS rev_cutting_tool_catalog_status_idx
  ON public.rev_cutting_tool_catalog (status);
CREATE INDEX IF NOT EXISTS rev_cutting_tool_catalog_oznaka_idx
  ON public.rev_cutting_tool_catalog (oznaka);
CREATE INDEX IF NOT EXISTS rev_cutting_tool_catalog_klasa_idx
  ON public.rev_cutting_tool_catalog (klasa)
  WHERE klasa IS NOT NULL;
CREATE INDEX IF NOT EXISTS rev_cutting_tool_catalog_machines_gin
  ON public.rev_cutting_tool_catalog USING gin (compatible_machine_codes);

COMMENT ON TABLE public.rev_cutting_tool_catalog IS
  'Katalog reznog alata: jedna šifra (oznaka) = jedan red, količina se prati kroz rev_cutting_tool_stock po lokaciji.';
COMMENT ON COLUMN public.rev_cutting_tool_catalog.barcode IS
  'Auto-generisan format RZN-NNNNNN (Code128 nalepnica). Trigger popunjava na INSERT ako nije zadat.';
COMMENT ON COLUMN public.rev_cutting_tool_catalog.compatible_machine_codes IS
  'Soft FK ka bigtehn_machines_cache.rj_code. UI samo upozorava ako se zaduži na nekompatibilnu mašinu (warn, ne hard error).';

-- ------------------------------------------------------------
-- 5. Tabela rev_cutting_tool_stock — balance po lokaciji
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.rev_cutting_tool_stock (
  catalog_id    uuid           NOT NULL REFERENCES public.rev_cutting_tool_catalog(id) ON DELETE CASCADE,
  location_id   uuid           NOT NULL REFERENCES public.loc_locations(id) ON DELETE RESTRICT,
  on_hand_qty   numeric(12,3)  NOT NULL DEFAULT 0,
  updated_at    timestamptz    NOT NULL DEFAULT now(),
  PRIMARY KEY (catalog_id, location_id),
  CHECK (on_hand_qty >= 0)
);

CREATE INDEX IF NOT EXISTS rev_cutting_tool_stock_loc_idx
  ON public.rev_cutting_tool_stock (location_id);
CREATE INDEX IF NOT EXISTS rev_cutting_tool_stock_nonzero_idx
  ON public.rev_cutting_tool_stock (catalog_id)
  WHERE on_hand_qty > 0;

COMMENT ON TABLE public.rev_cutting_tool_stock IS
  'Balance reznog alata po lokaciji. Sum on_hand_qty preko svih lokacija = ukupno stanje. Updateuje se isključivo kroz rev_cts_apply_delta() iz RPC-a (ne ručno).';

-- ------------------------------------------------------------
-- 6. rev_document_lines.cutting_tool_catalog_id
-- ------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'rev_document_lines'
      AND column_name = 'cutting_tool_catalog_id'
  ) THEN
    ALTER TABLE public.rev_document_lines
      ADD COLUMN cutting_tool_catalog_id uuid REFERENCES public.rev_cutting_tool_catalog(id);
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS rev_document_lines_cts_catalog_idx
  ON public.rev_document_lines (cutting_tool_catalog_id)
  WHERE cutting_tool_catalog_id IS NOT NULL;

-- ------------------------------------------------------------
-- 7. rev_get_or_create_recipient_location: dodaj MACHINE
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.rev_get_or_create_recipient_location(
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
    WHEN 'MACHINE' THEN
      v_loc_type := 'PRODUCTION';
      v_loc_code := 'ZADU-M-' || regexp_replace(p_recipient_key, '[^A-Za-z0-9._-]', '_', 'g');
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

REVOKE ALL ON FUNCTION public.rev_get_or_create_recipient_location(text, text, text) FROM PUBLIC;

-- ------------------------------------------------------------
-- 8. rev_next_doc_number: dodaj CUTTING_TOOL → REV-RZN
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.rev_next_doc_number(p_doc_type text)
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
    WHEN 'CUTTING_TOOL'      THEN 'REV-RZN'
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

REVOKE ALL ON FUNCTION public.rev_next_doc_number(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rev_next_doc_number(text) TO authenticated;

-- ------------------------------------------------------------
-- 9. rev_cts_apply_delta — UPSERT balance, sa CHECK >= 0
-- ------------------------------------------------------------

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
BEGIN
  IF p_catalog_id IS NULL OR p_location_id IS NULL THEN
    RAISE EXCEPTION 'rev_cts_apply_delta: catalog_id i location_id su obavezni.';
  END IF;
  IF p_delta = 0 THEN
    SELECT on_hand_qty INTO v_new FROM rev_cutting_tool_stock
    WHERE catalog_id = p_catalog_id AND location_id = p_location_id;
    RETURN COALESCE(v_new, 0);
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

REVOKE ALL ON FUNCTION public.rev_cts_apply_delta(uuid, uuid, numeric) FROM PUBLIC;

COMMENT ON FUNCTION public.rev_cts_apply_delta(uuid, uuid, numeric) IS
  'UPSERT balance reznog alata po lokaciji. Zove se isključivo iz rev_issue_cutting_reversal i rev_confirm_cutting_return. Negativan delta dekrementuje, pozitivan inkrementuje.';

-- ------------------------------------------------------------
-- 10. RPC: rev_issue_cutting_reversal(jsonb)
--     Payload:
--       {
--         "recipient_machine_code": "8.3",
--         "issued_to_employee_id": "uuid",
--         "issued_to_employee_name": "Ime Prezime",
--         "source_location_id": "uuid|null",        -- default ALAT-MAG-01
--         "expected_return_date": "YYYY-MM-DD|null",
--         "napomena": "tekst|null",
--         "lines": [
--           { "catalog_id": "uuid", "quantity": 5, "napomena": "..." }, ...
--         ]
--       }
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.rev_issue_cutting_reversal(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_doc_id          uuid;
  v_doc_number      text;
  v_recipient_loc   uuid;
  v_machine_code    text;
  v_employee_id     uuid;
  v_employee_name   text;
  v_source_loc      uuid;
  v_line            jsonb;
  v_catalog         rev_cutting_tool_catalog%ROWTYPE;
  v_qty             numeric;
  v_line_id         uuid;
  v_move_res        jsonb;
  v_movement_id     uuid;
BEGIN
  IF NOT rev_can_manage() THEN
    RAISE EXCEPTION 'Nemate pravo da kreirate revers reznog alata.'
      USING ERRCODE = '42501';
  END IF;

  v_machine_code := nullif(btrim(p_payload->>'recipient_machine_code'), '');
  IF v_machine_code IS NULL THEN
    RAISE EXCEPTION 'recipient_machine_code je obavezan za revers reznog alata.';
  END IF;

  v_employee_id := nullif(p_payload->>'issued_to_employee_id', '')::uuid;
  IF v_employee_id IS NULL THEN
    RAISE EXCEPTION 'issued_to_employee_id (potpisnik preuzimanja) je obavezan.';
  END IF;
  v_employee_name := COALESCE(p_payload->>'issued_to_employee_name', '');

  v_source_loc := nullif(p_payload->>'source_location_id', '')::uuid;
  IF v_source_loc IS NULL THEN
    SELECT id INTO v_source_loc FROM loc_locations WHERE location_code = 'ALAT-MAG-01' LIMIT 1;
  END IF;
  IF v_source_loc IS NULL THEN
    RAISE EXCEPTION 'Nije moguće odrediti izvornu lokaciju (source_location_id ili ALAT-MAG-01).';
  END IF;

  IF jsonb_array_length(COALESCE(p_payload->'lines', '[]'::jsonb)) = 0 THEN
    RAISE EXCEPTION 'Dokument mora imati najmanje jednu stavku.';
  END IF;

  v_doc_number    := rev_next_doc_number('CUTTING_TOOL');
  v_recipient_loc := rev_get_or_create_recipient_location(
    'MACHINE',
    v_machine_code,
    'Mašina ' || v_machine_code
  );

  INSERT INTO rev_documents (
    doc_number,
    doc_type,
    recipient_type,
    recipient_machine_code,
    recipient_loc_id,
    issued_to_employee_id,
    issued_to_employee_name,
    expected_return_date,
    issued_by,
    napomena
  ) VALUES (
    v_doc_number,
    'CUTTING_TOOL',
    'MACHINE',
    v_machine_code,
    v_recipient_loc,
    v_employee_id,
    v_employee_name,
    nullif(p_payload->>'expected_return_date','')::date,
    auth.uid(),
    p_payload->>'napomena'
  ) RETURNING id INTO v_doc_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_payload->'lines') LOOP
    SELECT * INTO v_catalog FROM rev_cutting_tool_catalog
      WHERE id = nullif(v_line->>'catalog_id','')::uuid;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Šifra reznog alata nije pronađena: %', v_line->>'catalog_id';
    END IF;

    v_qty := COALESCE((v_line->>'quantity')::numeric, 0);
    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'Količina mora biti > 0 (catalog=%).', v_catalog.id;
    END IF;

    PERFORM rev_cts_apply_delta(v_catalog.id, v_source_loc,    -v_qty);
    PERFORM rev_cts_apply_delta(v_catalog.id, v_recipient_loc,  v_qty);

    INSERT INTO rev_document_lines (
      document_id,
      sort_order,
      line_type,
      cutting_tool_catalog_id,
      part_name,
      quantity,
      unit,
      napomena
    ) VALUES (
      v_doc_id,
      COALESCE((v_line->>'sort_order')::int, 0),
      'CUTTING_TOOL',
      v_catalog.id,
      v_catalog.naziv,
      v_qty,
      v_catalog.unit,
      v_line->>'napomena'
    ) RETURNING id INTO v_line_id;

    v_move_res := loc_create_movement(jsonb_build_object(
      'item_ref_table',   'rev_cutting_tool_catalog',
      'item_ref_id',      v_catalog.barcode,
      'from_location_id', v_source_loc,
      'to_location_id',   v_recipient_loc,
      'movement_type',    'REVERSAL_ISSUE',
      'movement_reason',  'Rezni alat: ' || v_doc_number,
      'note',             COALESCE(v_line->>'napomena', ''),
      'quantity',         v_qty,
      'order_no',         '',
      'drawing_no',       ''
    ));

    IF COALESCE((v_move_res->>'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'loc_create_movement neuspesan: %', v_move_res->>'error'
        USING DETAIL = v_move_res::text;
    END IF;

    v_movement_id := (v_move_res->>'id')::uuid;
    UPDATE rev_document_lines SET issue_movement_id = v_movement_id WHERE id = v_line_id;
  END LOOP;

  RETURN jsonb_build_object(
    'success',    true,
    'doc_id',     v_doc_id,
    'doc_number', v_doc_number
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rev_issue_cutting_reversal(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rev_issue_cutting_reversal(jsonb) TO authenticated;

-- ------------------------------------------------------------
-- 11. RPC: rev_confirm_cutting_return(jsonb)
--     Payload:
--       {
--         "doc_id": "uuid",
--         "return_to_location_id": "uuid|null",  -- default ALAT-MAG-01
--         "return_notes": "tekst|null",
--         "returned_lines": [
--           { "line_id": "uuid", "returned_quantity": 3 }, ...
--         ]
--       }
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.rev_confirm_cutting_return(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_doc_id        uuid;
  v_doc           rev_documents%ROWTYPE;
  v_return_loc    uuid;
  v_line          jsonb;
  v_line_row      rev_document_lines%ROWTYPE;
  v_qty           numeric;
  v_move_res      jsonb;
  v_movement_id   uuid;
  v_all_returned  boolean;
BEGIN
  IF NOT rev_can_manage() THEN
    RAISE EXCEPTION 'Nemate pravo da potvrdite povraćaj reznog alata.'
      USING ERRCODE = '42501';
  END IF;

  v_doc_id := (p_payload->>'doc_id')::uuid;

  SELECT * INTO v_doc FROM rev_documents WHERE id = v_doc_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Dokument nije pronadjen: %', v_doc_id USING ERRCODE = 'P0002';
  END IF;
  IF v_doc.doc_type <> 'CUTTING_TOOL' THEN
    RAISE EXCEPTION 'rev_confirm_cutting_return je samo za doc_type=CUTTING_TOOL (dobijeno: %).', v_doc.doc_type;
  END IF;
  IF v_doc.status IN ('RETURNED', 'CANCELLED') THEN
    RAISE EXCEPTION 'Dokument je već zatvoren (status: %).', v_doc.status USING ERRCODE = 'P0001';
  END IF;

  v_return_loc := nullif(p_payload->>'return_to_location_id', '')::uuid;
  IF v_return_loc IS NULL THEN
    SELECT id INTO v_return_loc FROM loc_locations WHERE location_code = 'ALAT-MAG-01' LIMIT 1;
  END IF;
  IF v_return_loc IS NULL THEN
    RAISE EXCEPTION 'Nedostaje return_to_location_id (ni ALAT-MAG-01).';
  END IF;

  FOR v_line IN SELECT * FROM jsonb_array_elements(COALESCE(p_payload->'returned_lines', '[]'::jsonb)) LOOP
    SELECT * INTO v_line_row FROM rev_document_lines
      WHERE id = nullif(v_line->>'line_id','')::uuid AND document_id = v_doc_id;
    IF NOT FOUND THEN CONTINUE; END IF;
    IF v_line_row.line_status = 'RETURNED' THEN CONTINUE; END IF;
    IF v_line_row.cutting_tool_catalog_id IS NULL THEN CONTINUE; END IF;

    v_qty := COALESCE((v_line->>'returned_quantity')::numeric, 0);
    IF v_qty <= 0 THEN CONTINUE; END IF;
    IF v_line_row.returned_quantity + v_qty > v_line_row.quantity THEN
      RAISE EXCEPTION 'Vraćena količina premašuje izdato (linija %, izdato=%, već vraćeno=%, novo=%).',
        v_line_row.id, v_line_row.quantity, v_line_row.returned_quantity, v_qty;
    END IF;

    PERFORM rev_cts_apply_delta(v_line_row.cutting_tool_catalog_id, v_doc.recipient_loc_id, -v_qty);
    PERFORM rev_cts_apply_delta(v_line_row.cutting_tool_catalog_id, v_return_loc,            v_qty);

    v_move_res := loc_create_movement(jsonb_build_object(
      'item_ref_table',   'rev_cutting_tool_catalog',
      'item_ref_id',      (SELECT barcode FROM rev_cutting_tool_catalog WHERE id = v_line_row.cutting_tool_catalog_id),
      'from_location_id', v_doc.recipient_loc_id,
      'to_location_id',   v_return_loc,
      'movement_type',    'REVERSAL_RETURN',
      'movement_reason',  'Povratak rezni alat: ' || v_doc.doc_number,
      'note',             COALESCE(p_payload->>'return_notes', ''),
      'quantity',         v_qty,
      'order_no',         '',
      'drawing_no',       ''
    ));

    IF COALESCE((v_move_res->>'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'loc_create_movement neuspesan: %', v_move_res->>'error'
        USING DETAIL = v_move_res::text;
    END IF;

    v_movement_id := (v_move_res->>'id')::uuid;

    UPDATE rev_document_lines SET
      returned_quantity  = v_line_row.returned_quantity + v_qty,
      return_movement_id = v_movement_id,
      line_status        = CASE
        WHEN v_line_row.returned_quantity + v_qty >= v_line_row.quantity THEN 'RETURNED'
        ELSE 'ISSUED'
      END
    WHERE id = v_line_row.id;
  END LOOP;

  SELECT NOT EXISTS (
    SELECT 1 FROM rev_document_lines
    WHERE document_id = v_doc_id AND line_status = 'ISSUED'
  ) INTO v_all_returned;

  UPDATE rev_documents SET
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

REVOKE ALL ON FUNCTION public.rev_confirm_cutting_return(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rev_confirm_cutting_return(jsonb) TO authenticated;

-- ------------------------------------------------------------
-- 12. View: v_rev_my_issued_cutting_tools
--     Self-service: rezni alat koji je prijavljeni operater
--     POTPISANO PREUZEO (issued_to_employee_id). U Sprint RZ-4
--     dodaće se i view po mašini (sve što je trenutno na mašinama
--     na kojima operater radi).
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.v_rev_my_issued_cutting_tools
WITH (security_invoker = true)
AS
SELECT
  d.id                              AS document_id,
  d.doc_number,
  d.recipient_machine_code,
  d.issued_at,
  d.expected_return_date,
  d.status                          AS document_status,
  c.id                              AS catalog_id,
  c.barcode,
  c.oznaka,
  c.naziv,
  c.klasa,
  c.unit,
  l.id                              AS line_id,
  l.quantity,
  l.returned_quantity,
  (l.quantity - l.returned_quantity) AS remaining_quantity,
  l.line_status,
  d.napomena                        AS napomena_dokumenta
FROM rev_document_lines l
JOIN rev_documents d                ON d.id = l.document_id
JOIN rev_cutting_tool_catalog c     ON c.id = l.cutting_tool_catalog_id
WHERE
  l.line_type    = 'CUTTING_TOOL'
  AND l.line_status = 'ISSUED'
  AND d.status   IN ('OPEN', 'PARTIALLY_RETURNED')
  AND d.issued_to_employee_id = public.rev_current_employee_id();

REVOKE ALL ON public.v_rev_my_issued_cutting_tools FROM anon;
GRANT SELECT ON public.v_rev_my_issued_cutting_tools TO authenticated;

COMMENT ON VIEW public.v_rev_my_issued_cutting_tools IS
  'Self-service: rezni alat koji je prijavljeni operater preuzeo i potpisao (issued_to_employee_id).';

-- ------------------------------------------------------------
-- 13. RLS politike za nove tabele
-- ------------------------------------------------------------

ALTER TABLE public.rev_cutting_tool_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rev_cutting_tool_stock   ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rev_cts_catalog_select ON public.rev_cutting_tool_catalog;
CREATE POLICY rev_cts_catalog_select ON public.rev_cutting_tool_catalog
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS rev_cts_catalog_insert ON public.rev_cutting_tool_catalog;
CREATE POLICY rev_cts_catalog_insert ON public.rev_cutting_tool_catalog
  FOR INSERT TO authenticated WITH CHECK (rev_can_manage());

DROP POLICY IF EXISTS rev_cts_catalog_update ON public.rev_cutting_tool_catalog;
CREATE POLICY rev_cts_catalog_update ON public.rev_cutting_tool_catalog
  FOR UPDATE TO authenticated
  USING (rev_can_manage())
  WITH CHECK (rev_can_manage());

DROP POLICY IF EXISTS rev_cts_stock_select ON public.rev_cutting_tool_stock;
CREATE POLICY rev_cts_stock_select ON public.rev_cutting_tool_stock
  FOR SELECT TO authenticated USING (true);

-- INSERT/UPDATE na stock tabeli isključivo kroz SECURITY DEFINER
-- funkciju rev_cts_apply_delta — direktan PostgREST upis je odbijen.

-- ------------------------------------------------------------
-- 14. PostgREST GRANT-ovi
-- ------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE ON public.rev_cutting_tool_catalog TO authenticated;
GRANT SELECT                  ON public.rev_cutting_tool_stock   TO authenticated;
GRANT USAGE                   ON SEQUENCE public.rev_cutting_tool_barcode_seq TO authenticated;
