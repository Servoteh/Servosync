-- Jednokratna korekcija: CUTTING_TOOL reverz dokumenti iz bulk uvoza — deljenje količina na
-- stavkama (podrazumevano /3), premeštaj zaliha na lokaciju mašine 2.60, PRIMARY operater.

-- ═══════════════════════════════════════════════════════════════════════════
-- Opciono: fiksiran UUID operatera. Ostavi NULL — skripta pokušava Predraga Ćirovića
-- iz employees (Čirović/Cirovic + Predrag).
-- ═══════════════════════════════════════════════════════════════════════════
-- SELECT id, full_name FROM public.employees
-- WHERE full_name ILIKE '%predrag%' OR full_name ILIKE '%cirov%' OR full_name ILIKE '%ćirov%';

-- ═══════════════════════════════════════════════════════════════════════════
-- KORAK 2 — obavezna dijagnostika PRE skripte (kopiraj u Editor, vidi broj/redove):
--
-- SELECT id, doc_number, status, recipient_machine_code,
--        bulk_import_legacy_key IS NOT NULL AS ima_bulk_kljuc,
--        left(bulk_import_legacy_key, 8) AS bulk_pref
-- FROM public.rev_documents
-- WHERE doc_type = 'CUTTING_TOOL' AND status IN ('OPEN', 'PARTIALLY_RETURNED');
--
-- Ako sve kolone ima_bulk_kljuc = false, skripta sa podrazumevanim filtrom NIŠTA ne menja —
-- postavi v_only_documents_with_bulk_key := false ispod (oprez: hvata sve otvorene CUTTING).
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

DO $$
DECLARE
  v_machine       text := '2.60';
  v_divisor       numeric := 3;
  -- true = samo bulk (bulk_import_legacy_key Popunjen); false = svi CUTTING OPEN/PARTIAL (oprez)
  v_only_documents_with_bulk_key boolean := true;
  v_employee_id   uuid := NULL;   -- opciono; ako NULL → auto-upit ispod
  v_employee_name text;
  v_new_loc       uuid;
  v_doc           record;
  v_line          record;
  v_old_loc       uuid;
  v_old           numeric;
  v_new           numeric;
  v_targets       uuid[];
BEGIN
  IF v_employee_id IS NOT NULL THEN
    SELECT full_name INTO v_employee_name FROM public.employees WHERE id = v_employee_id;
  ELSE
    SELECT e.id, e.full_name INTO v_employee_id, v_employee_name
    FROM public.employees e
    WHERE COALESCE(e.is_active, true)
      AND e.full_name ILIKE '%predrag%'
      AND (
        e.full_name ILIKE '%irović%'
        OR e.full_name ILIKE '%irovic%'
        OR e.full_name ILIKE '%Ćirović%'
      )
    ORDER BY e.full_name
    LIMIT 1;
  END IF;

  IF v_employee_id IS NULL OR v_employee_name IS NULL THEN
    RAISE EXCEPTION 'Nije pronađen zaposleni (Predrag Ćirović). Izvrši u Editoru: '
      'SELECT id, full_name FROM public.employees WHERE full_name ILIKE ''%%predrag%%'' '
      'AND (full_name ILIKE ''%%irovi%%'' OR full_name ILIKE ''%%ćirovi%%''); '
      'zatim u skripti postavi v_employee_id := ''<uuid>''::uuid.';
  END IF;

  RAISE NOTICE '[repair_cutting_bulk] masina=% delilac=% only_bulk_legacy=%',
    v_machine, v_divisor, v_only_documents_with_bulk_key;

  v_new_loc := public.rev_get_or_create_recipient_location(
    'MACHINE',
    nullif(btrim(v_machine), ''),
    'Mašina ' || v_machine
  );

  v_targets := ARRAY(
    SELECT d.id
    FROM public.rev_documents d
    WHERE d.doc_type = 'CUTTING_TOOL'
      AND d.status IN ('OPEN', 'PARTIALLY_RETURNED')
      AND (
        NOT v_only_documents_with_bulk_key
        OR (
          d.bulk_import_legacy_key IS NOT NULL
          AND btrim(d.bulk_import_legacy_key) <> ''
        )
      )
      -- AND d.issued_at::date = '2026-05-10'::date
      -- AND d.id = ANY (ARRAY['...']::uuid[])
  );

  RAISE WARNING '[repair_cutting_bulk] broj dokumenta za obradu: % (ukupno CUTTING OPEN/PARTIAL u bazi: %)',
    cardinality(v_targets),
    (
      SELECT count(*) FROM public.rev_documents d2
      WHERE d2.doc_type = 'CUTTING_TOOL'
        AND d2.status IN ('OPEN', 'PARTIALLY_RETURNED')
    );

  IF cardinality(v_targets) = 0 THEN
    RAISE WARNING '[repair_cutting_bulk] NIŠTA nije menjano: niko ne prolazi filter. '
      'Ako dokumenti postoje ali nemaju bulk_import_legacy_key, u skripti postavi '
      'v_only_documents_with_bulk_key := false i ponovo pokreni (sa suženjem po datumu/ID ako treba).';
    RETURN;
  END IF;

  FOR v_doc IN
    SELECT id, recipient_loc_id, doc_number
    FROM public.rev_documents
    WHERE id = ANY (v_targets)
  LOOP
    v_old_loc := v_doc.recipient_loc_id;

    FOR v_line IN
      SELECT id, cutting_tool_catalog_id, quantity
      FROM public.rev_document_lines
      WHERE document_id = v_doc.id AND line_type = 'CUTTING_TOOL'
    LOOP
      v_old := COALESCE(v_line.quantity, 0);
      IF v_old <= 0 THEN
        CONTINUE;
      END IF;

      v_new := round(v_old::numeric / v_divisor, 0);
      IF v_new < 1 THEN
        v_new := 1;
      END IF;

      PERFORM public.rev_cts_apply_delta(v_line.cutting_tool_catalog_id, v_old_loc, -v_old);
      PERFORM public.rev_cts_apply_delta(v_line.cutting_tool_catalog_id, v_new_loc, v_new);

      UPDATE public.rev_document_lines SET quantity = v_new WHERE id = v_line.id;
    END LOOP;

    UPDATE public.rev_documents
    SET
      recipient_machine_code = v_machine,
      recipient_loc_id = v_new_loc,
      issued_to_employee_id = v_employee_id,
      issued_to_employee_name = v_employee_name
    WHERE id = v_doc.id;

    DELETE FROM public.rev_document_cutting_assignees WHERE document_id = v_doc.id;
    INSERT INTO public.rev_document_cutting_assignees (document_id, employee_id, role)
    VALUES (v_doc.id, v_employee_id, 'PRIMARY');

    RAISE NOTICE 'OK doc % (%) → mašina %, operater %',
      v_doc.doc_number, v_doc.id, v_machine, v_employee_name;
  END LOOP;
END $$;

COMMIT;
