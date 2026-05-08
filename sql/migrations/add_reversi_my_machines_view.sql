-- ============================================================================
-- REVERSI — Self-service view "Moje mašine" (Sprint RZ-4)
-- ============================================================================
-- Operater vidi sav rezni alat na MAŠINAMA na kojima trenutno radi
-- (otvorena prijava_rada, finished_at IS NULL). Ovo je glavni mobilni
-- self-service prikaz: kad operater A i operater B dele mašinu 8.3, oba
-- vide isti set alata.
--
-- Zavisi od:
--   - add_reversi_cutting_tools.sql  (rev_cutting_tool_catalog, view target)
--   - production.prijava_rada        (Pracenje proizvodnje init)
--   - core.work_center, core.radnik  (Pracenje proizvodnje init)
--   - public.rev_current_employee_id() (add_reversi_module.sql)
--
-- VAN CI: koristi production / core šeme koje CI minimalna baza nema.
--         Pokreće se ručno na Supabase posle add_reversi_cutting_tools.
--
-- DOWN:
--   DROP VIEW     IF EXISTS public.v_rev_my_machines_cutting_tools;
--   DROP FUNCTION IF EXISTS public.rev_current_machine_codes();
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rev_current_machine_codes()
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, core, production, pg_temp
AS $$
  SELECT COALESCE(array_agg(DISTINCT wc.kod), ARRAY[]::text[])
  FROM production.prijava_rada pr
  JOIN core.radnik r        ON r.id = pr.radnik_id
  JOIN core.work_center wc  ON wc.id = pr.work_center_id
  WHERE pr.finished_at IS NULL
    AND r.aktivan IS TRUE
    AND r.employee_id = public.rev_current_employee_id();
$$;

REVOKE ALL ON FUNCTION public.rev_current_machine_codes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rev_current_machine_codes() TO authenticated;

COMMENT ON FUNCTION public.rev_current_machine_codes() IS
  'Vraća rj_code listu mašina na kojima prijavljeni operater (preko employees.id) trenutno ima otvorenu prijava_rada (finished_at IS NULL).';

CREATE OR REPLACE VIEW public.v_rev_my_machines_cutting_tools
WITH (security_invoker = true)
AS
SELECT
  d.id                                AS document_id,
  d.doc_number,
  d.recipient_machine_code,
  d.issued_at,
  d.expected_return_date,
  d.status                            AS document_status,
  d.issued_to_employee_id,
  d.issued_to_employee_name,
  c.id                                AS catalog_id,
  c.barcode,
  c.oznaka,
  c.naziv,
  c.klasa,
  c.unit,
  l.id                                AS line_id,
  l.quantity,
  l.returned_quantity,
  (l.quantity - l.returned_quantity)  AS remaining_quantity,
  l.line_status,
  d.napomena                          AS napomena_dokumenta
FROM rev_document_lines l
JOIN rev_documents d                  ON d.id = l.document_id
JOIN rev_cutting_tool_catalog c       ON c.id = l.cutting_tool_catalog_id
WHERE
  l.line_type    = 'CUTTING_TOOL'
  AND l.line_status = 'ISSUED'
  AND d.status   IN ('OPEN', 'PARTIALLY_RETURNED')
  AND d.recipient_machine_code = ANY(public.rev_current_machine_codes());

REVOKE ALL ON public.v_rev_my_machines_cutting_tools FROM anon;
GRANT SELECT ON public.v_rev_my_machines_cutting_tools TO authenticated;

COMMENT ON VIEW public.v_rev_my_machines_cutting_tools IS
  'Self-service: rezni alat na mašinama na kojima prijavljeni operater trenutno radi (preko production.prijava_rada). Operater A i B koji dele mašinu 8.3 oba vide isti set alata.';
