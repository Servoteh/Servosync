-- Reversi R1 (part 1): matches sql/migrations/add_reversi_module.sql §§1–10.
-- Applied on hosted Supabase as migration version 20260504062645.

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
