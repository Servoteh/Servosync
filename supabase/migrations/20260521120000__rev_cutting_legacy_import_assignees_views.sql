-- REVERSI rezni alat: legacy import bez lažnog magacina, više operatera, read model po dokumentima
-- Idempotentno.

-- ---------------------------------------------------------------------------
-- 1) Opcioni ključ idempotentnosti bulk importa
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'rev_documents'
      AND column_name = 'bulk_import_legacy_key'
  ) THEN
    ALTER TABLE public.rev_documents ADD COLUMN bulk_import_legacy_key text;
  END IF;
END$$;

DROP INDEX IF EXISTS public.rev_documents_bulk_import_legacy_key_uidx;

CREATE UNIQUE INDEX rev_documents_bulk_import_legacy_key_uidx
  ON public.rev_documents (bulk_import_legacy_key)
  WHERE bulk_import_legacy_key IS NOT NULL AND btrim(bulk_import_legacy_key) <> '';

COMMENT ON COLUMN public.rev_documents.bulk_import_legacy_key IS
  'Opcioni stabilan ključ (hash) za idempotentan REVERSI bulk import; jedan dokument po ključu.';

-- ---------------------------------------------------------------------------
-- 2) Operateri na zaduženju (rezni alat na mašini) — PRIMARY + SECONDARY
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rev_document_cutting_assignees (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id  uuid NOT NULL REFERENCES public.rev_documents(id) ON DELETE CASCADE,
  employee_id  uuid NOT NULL REFERENCES public.employees(id) ON DELETE RESTRICT,
  role         text NOT NULL CHECK (role IN ('PRIMARY', 'SECONDARY')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (document_id, employee_id)
);

CREATE INDEX IF NOT EXISTS rev_doc_cts_assignees_doc_idx
  ON public.rev_document_cutting_assignees (document_id);

COMMENT ON TABLE public.rev_document_cutting_assignees IS
  'Potpisnici/operateri na revers dokumentu tipa CUTTING_TOOL (mašina); količina je na dokumentu, ne duplira se po operateru.';

ALTER TABLE public.rev_document_cutting_assignees ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rev_doc_cts_assignees_select ON public.rev_document_cutting_assignees;
CREATE POLICY rev_doc_cts_assignees_select ON public.rev_document_cutting_assignees
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS rev_doc_cts_assignees_write ON public.rev_document_cutting_assignees;
CREATE POLICY rev_doc_cts_assignees_write ON public.rev_document_cutting_assignees
  FOR ALL TO authenticated
  USING (public.rev_can_manage())
  WITH CHECK (public.rev_can_manage());

GRANT SELECT ON public.rev_document_cutting_assignees TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.rev_document_cutting_assignees TO authenticated;

-- ---------------------------------------------------------------------------
-- 3) Pregled: zadužena količina po mašini i katalogu (iz dokumenata)
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS public.v_rev_cts_machine_stock;
CREATE VIEW public.v_rev_cts_machine_stock
WITH (security_invoker = true)
AS
SELECT
  d.recipient_machine_code                    AS machine_code,
  l.cutting_tool_catalog_id                   AS catalog_id,
  SUM(l.quantity - COALESCE(l.returned_quantity, 0)) AS outstanding_qty
FROM public.rev_document_lines l
JOIN public.rev_documents d ON d.id = l.document_id
WHERE l.line_type = 'CUTTING_TOOL'
  AND l.line_status = 'ISSUED'
  AND d.doc_type = 'CUTTING_TOOL'
  AND d.status IN ('OPEN', 'PARTIALLY_RETURNED')
  AND d.recipient_machine_code IS NOT NULL
  AND l.cutting_tool_catalog_id IS NOT NULL
GROUP BY d.recipient_machine_code, l.cutting_tool_catalog_id;

REVOKE ALL ON public.v_rev_cts_machine_stock FROM anon;
GRANT SELECT ON public.v_rev_cts_machine_stock TO authenticated;

COMMENT ON VIEW public.v_rev_cts_machine_stock IS
  'Preostala količina reznog alata na mašini (OPEN/PARTIALLY_RETURNED, iz stavki).';

-- ---------------------------------------------------------------------------
-- 4) rev_issue_cutting_reversal: legacy_skip_source_decrement, assignees, bulk key
-- ---------------------------------------------------------------------------
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
  v_legacy_skip     boolean;
  v_bulk_key        text;
  v_existing_id     uuid;
  v_existing_no     text;
  v_assignee        jsonb;
BEGIN
  IF NOT rev_can_manage() THEN
    RAISE EXCEPTION 'Nemate pravo da kreirate revers reznog alata.'
      USING ERRCODE = '42501';
  END IF;

  v_legacy_skip := COALESCE((p_payload->>'legacy_skip_source_decrement')::boolean, false);

  v_bulk_key := nullif(btrim(COALESCE(p_payload->>'bulk_import_legacy_key', '')), '');
  IF v_bulk_key IS NOT NULL THEN
    SELECT d.id, d.doc_number INTO v_existing_id, v_existing_no
    FROM public.rev_documents d
    WHERE d.bulk_import_legacy_key = v_bulk_key
    LIMIT 1;
    IF v_existing_id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', true,
        'doc_id', v_existing_id,
        'doc_number', v_existing_no,
        'idempotent', true
      );
    END IF;
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
  IF v_source_loc IS NULL AND NOT v_legacy_skip THEN
    RAISE EXCEPTION 'Nije moguće odrediti izvornu lokaciju (source_location_id ili ALAT-MAG-01).';
  END IF;

  IF jsonb_array_length(COALESCE(p_payload->'lines', '[]'::jsonb)) = 0 THEN
    RAISE EXCEPTION 'Dokument mora imati najmanje jednu stavku.';
  END IF;

  IF jsonb_array_length(COALESCE(p_payload->'assignees', '[]'::jsonb)) > 0 THEN
    IF (
      SELECT COUNT(*) FROM jsonb_array_elements(p_payload->'assignees') a
      WHERE upper(btrim(COALESCE(a->>'role', ''))) = 'PRIMARY'
    ) <> 1 THEN
      RAISE EXCEPTION 'assignees mora da sadrži tačno jednog PRIMARY operatera (role=PRIMARY).';
    END IF;
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
    napomena,
    bulk_import_legacy_key
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
    p_payload->>'napomena',
    v_bulk_key
  ) RETURNING id INTO v_doc_id;

  IF jsonb_array_length(COALESCE(p_payload->'assignees', '[]'::jsonb)) > 0 THEN
    FOR v_assignee IN SELECT * FROM jsonb_array_elements(p_payload->'assignees') LOOP
      INSERT INTO public.rev_document_cutting_assignees (document_id, employee_id, role)
      VALUES (
        v_doc_id,
        (v_assignee->>'employee_id')::uuid,
        CASE upper(btrim(COALESCE(v_assignee->>'role', 'SECONDARY')))
          WHEN 'PRIMARY' THEN 'PRIMARY'
          ELSE 'SECONDARY'
        END
      )
      ON CONFLICT (document_id, employee_id) DO UPDATE
        SET role = EXCLUDED.role;
    END LOOP;
  ELSE
    INSERT INTO public.rev_document_cutting_assignees (document_id, employee_id, role)
    VALUES (v_doc_id, v_employee_id, 'PRIMARY')
    ON CONFLICT (document_id, employee_id) DO NOTHING;
  END IF;

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

    IF v_legacy_skip THEN
      PERFORM rev_cts_apply_delta(v_catalog.id, v_recipient_loc, v_qty);
    ELSE
      PERFORM rev_cts_apply_delta(v_catalog.id, v_source_loc,    -v_qty);
      PERFORM rev_cts_apply_delta(v_catalog.id, v_recipient_loc,  v_qty);
    END IF;

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

    IF NOT v_legacy_skip THEN
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
    END IF;
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

COMMENT ON FUNCTION public.rev_issue_cutting_reversal(jsonb) IS
  'Kreira CUTTING_TOOL revers. legacy_skip_source_decrement=true ne dira magacin. Opcioni bulk_import_legacy_key za idempotentan import; assignees [{employee_id,role}].';

-- ---------------------------------------------------------------------------
-- 5) BACKFILL: postojeći dokumenti dobijaju PRIMARY u assignees tabeli
-- ---------------------------------------------------------------------------
INSERT INTO public.rev_document_cutting_assignees (document_id, employee_id, role)
SELECT d.id, d.issued_to_employee_id, 'PRIMARY'
FROM public.rev_documents d
WHERE d.doc_type = 'CUTTING_TOOL'
  AND d.issued_to_employee_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.rev_document_cutting_assignees x WHERE x.document_id = d.id
  )
ON CONFLICT (document_id, employee_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6) Replace v_rev_cts_by_machine — operator_names (assignees + employees)
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS public.v_rev_cts_by_machine;

CREATE VIEW public.v_rev_cts_by_machine
WITH (security_invoker = true)
AS
WITH agg AS (
  SELECT
    d.recipient_machine_code                                                          AS machine_code,
    m.name                                                                            AS machine_name,
    m.no_procedure                                                                    AS machine_no_procedure,
    c.id                                                                              AS catalog_id,
    c.barcode,
    c.oznaka,
    c.naziv,
    c.klasa,
    c.unit,
    SUM(l.quantity - COALESCE(l.returned_quantity, 0))                                 AS remaining_qty,
    COUNT(DISTINCT d.id)                                                              AS doc_count,
    MAX(d.issued_at)                                                                  AS last_issued_at,
    (ARRAY_AGG(d.issued_to_employee_name ORDER BY d.issued_at DESC))[1]               AS last_issued_to_name,
    ARRAY_AGG(DISTINCT d.id)                                                          AS doc_ids
  FROM public.rev_document_lines l
  JOIN public.rev_documents d ON d.id = l.document_id
  JOIN public.rev_cutting_tool_catalog c ON c.id = l.cutting_tool_catalog_id
  LEFT JOIN public.bigtehn_machines_cache m ON m.rj_code = d.recipient_machine_code
  WHERE l.line_type = 'CUTTING_TOOL'
    AND l.line_status = 'ISSUED'
    AND d.status IN ('OPEN', 'PARTIALLY_RETURNED')
    AND d.recipient_machine_code IS NOT NULL
  GROUP BY
    d.recipient_machine_code, m.name, m.no_procedure,
    c.id, c.barcode, c.oznaka, c.naziv, c.klasa, c.unit
)
SELECT
  agg.machine_code,
  agg.machine_name,
  agg.machine_no_procedure,
  agg.catalog_id,
  agg.barcode,
  agg.oznaka,
  agg.naziv,
  agg.klasa,
  agg.unit,
  agg.remaining_qty,
  agg.doc_count,
  agg.last_issued_at,
  agg.last_issued_to_name,
  (
    SELECT STRING_AGG(x.n, ', ' ORDER BY x.sort_key, x.n)
    FROM (
      SELECT DISTINCT COALESCE(e.full_name, d2.issued_to_employee_name) AS n,
        0::int AS sort_key
      FROM unnest(agg.doc_ids) AS u_doc(doc_id)
      JOIN public.rev_documents d2 ON d2.id = u_doc.doc_id
      LEFT JOIN public.rev_document_cutting_assignees ca
        ON ca.document_id = d2.id AND ca.role = 'PRIMARY'
      LEFT JOIN public.employees e ON e.id = COALESCE(ca.employee_id, d2.issued_to_employee_id)
      WHERE COALESCE(e.full_name, d2.issued_to_employee_name) IS NOT NULL
      UNION
      SELECT e.full_name AS n,
        1::int AS sort_key
      FROM unnest(agg.doc_ids) AS u2(doc_id)
      JOIN public.rev_document_cutting_assignees ca ON ca.document_id = u2.doc_id AND ca.role = 'SECONDARY'
      JOIN public.employees e ON e.id = ca.employee_id
    ) AS x
  ) AS operator_names
FROM agg;

REVOKE ALL ON public.v_rev_cts_by_machine FROM anon;
GRANT SELECT ON public.v_rev_cts_by_machine TO authenticated;

COMMENT ON VIEW public.v_rev_cts_by_machine IS
  'Agregat reznog alata po mašini sa operator_names (PRIMARY + SECONDARY).';

NOTIFY pgrst, 'reload schema';