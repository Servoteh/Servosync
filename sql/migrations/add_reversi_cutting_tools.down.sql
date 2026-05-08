-- ============================================================
-- DOWN za add_reversi_cutting_tools.sql
-- ============================================================
-- Skida sve što je gornja migracija dodala. Ne dira postojeće
-- rev_documents/rev_document_lines/rev_recipient_locations
-- redove (ali vraća CHECK constraint-e na originalne vrednosti).
-- ============================================================

BEGIN;

-- 1. RPC + helper funkcije
DROP FUNCTION IF EXISTS public.rev_confirm_cutting_return(jsonb);
DROP FUNCTION IF EXISTS public.rev_issue_cutting_reversal(jsonb);
DROP FUNCTION IF EXISTS public.rev_cts_apply_delta(uuid, uuid, numeric);

-- 2. View
DROP VIEW IF EXISTS public.v_rev_my_issued_cutting_tools;

-- 3. Vraćanje rev_next_doc_number na originalnu definiciju
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

-- 4. Vraćanje rev_get_or_create_recipient_location na originalnu definiciju
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
    ELSE
      RAISE EXCEPTION 'Nepoznat tip primaoca: %', p_recipient_type;
  END CASE;

  INSERT INTO loc_locations (location_code, name, location_type, is_active, notes)
  VALUES (v_loc_code, 'Zaduzeno: ' || p_recipient_label, v_loc_type, true,
          'Automatski kreirana virtuelna lokacija za reversal primalac')
  ON CONFLICT (location_code) DO UPDATE
    SET name = EXCLUDED.name, is_active = true
  RETURNING id INTO v_loc_id;

  INSERT INTO rev_recipient_locations (recipient_type, recipient_key, recipient_label, loc_location_id)
  VALUES (p_recipient_type, p_recipient_key, p_recipient_label, v_loc_id)
  ON CONFLICT (recipient_type, recipient_key) DO UPDATE
    SET recipient_label = EXCLUDED.recipient_label;

  RETURN v_loc_id;
END;
$$;

REVOKE ALL ON FUNCTION public.rev_get_or_create_recipient_location(text, text, text) FROM PUBLIC;

-- 5. Drop tabela (stock pre catalog zbog FK)
DROP TABLE IF EXISTS public.rev_cutting_tool_stock;

DROP TRIGGER IF EXISTS rev_cutting_tool_catalog_before_insert ON public.rev_cutting_tool_catalog;
DROP TRIGGER IF EXISTS rev_cutting_tool_catalog_updated_at    ON public.rev_cutting_tool_catalog;
DROP FUNCTION IF EXISTS public.rev_cutting_tool_set_barcode();
DROP TABLE    IF EXISTS public.rev_cutting_tool_catalog;
DROP SEQUENCE IF EXISTS public.rev_cutting_tool_barcode_seq;

-- 6. Skini cutting_tool_catalog_id sa rev_document_lines
ALTER TABLE public.rev_document_lines DROP COLUMN IF EXISTS cutting_tool_catalog_id;

-- 7. Vrati CHECK constraint-e na originalne vrednosti
DO $$
DECLARE v_name text;
BEGIN
  SELECT conname INTO v_name FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'rev_document_lines' AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) ILIKE '%line_type%';
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.rev_document_lines DROP CONSTRAINT %I', v_name);
  END IF;
END$$;
ALTER TABLE public.rev_document_lines
  ADD CONSTRAINT rev_document_lines_line_type_check
  CHECK (line_type IN ('TOOL', 'PRODUCTION_PART'));

DO $$
DECLARE v_name text;
BEGIN
  SELECT conname INTO v_name FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'rev_recipient_locations' AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) ILIKE '%recipient_type%';
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.rev_recipient_locations DROP CONSTRAINT %I', v_name);
  END IF;
END$$;
ALTER TABLE public.rev_recipient_locations
  ADD CONSTRAINT rev_recipient_locations_recipient_type_check
  CHECK (recipient_type IN ('EMPLOYEE', 'DEPARTMENT', 'EXTERNAL_COMPANY'));

DO $$
DECLARE v_name text;
BEGIN
  SELECT conname INTO v_name FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'rev_documents' AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) ILIKE '%recipient_type%';
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.rev_documents DROP CONSTRAINT %I', v_name);
  END IF;
END$$;
ALTER TABLE public.rev_documents
  ADD CONSTRAINT rev_documents_recipient_type_check
  CHECK (recipient_type IN ('EMPLOYEE', 'DEPARTMENT', 'EXTERNAL_COMPANY'));

DO $$
DECLARE v_name text;
BEGIN
  SELECT conname INTO v_name FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'rev_documents' AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) ILIKE '%doc_type%';
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.rev_documents DROP CONSTRAINT %I', v_name);
  END IF;
END$$;
ALTER TABLE public.rev_documents
  ADD CONSTRAINT rev_documents_doc_type_check
  CHECK (doc_type IN ('TOOL', 'COOPERATION_GOODS'));

-- 8. Skini nove kolone sa rev_documents
ALTER TABLE public.rev_documents DROP COLUMN IF EXISTS issued_to_employee_name;
ALTER TABLE public.rev_documents DROP COLUMN IF EXISTS issued_to_employee_id;
ALTER TABLE public.rev_documents DROP COLUMN IF EXISTS recipient_machine_code;

-- 9. Skini employees.card_barcode (čuvamo u dodatnoj proveri)
DROP INDEX IF EXISTS public.ux_employees_card_barcode;
ALTER TABLE public.employees DROP COLUMN IF EXISTS card_barcode;

COMMIT;
