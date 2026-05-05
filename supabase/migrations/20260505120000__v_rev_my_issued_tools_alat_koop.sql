-- Prošireno self-service zaduženje: alat (TOOL) + stavke reversa kooperacije (PRODUCTION_PART).

CREATE OR REPLACE VIEW public.v_rev_my_issued_tools
WITH (security_invoker = true)
AS
SELECT
  d.doc_type,
  l.line_type,
  d.id                    AS document_id,
  d.doc_number,
  d.issued_at,
  d.expected_return_date,
  d.status                AS document_status,
  t.oznaka,
  t.naziv,
  t.serijski_broj,
  l.part_name,
  l.drawing_no,
  l.quantity,
  l.unit,
  l.napomena              AS pribor,
  l.line_status,
  d.napomena              AS napomena_dokumenta
FROM public.rev_document_lines l
JOIN public.rev_documents d ON d.id = l.document_id
LEFT JOIN public.rev_tools t ON t.id = l.tool_id
WHERE
  l.line_status = 'ISSUED'
  AND d.status IN ('OPEN', 'PARTIALLY_RETURNED')
  AND d.recipient_employee_id IN (
    SELECT id FROM public.employees
    WHERE lower(email) = lower(auth.jwt() ->> 'email')
  )
  AND (
    l.line_type = 'TOOL'
    OR (l.line_type = 'PRODUCTION_PART' AND d.doc_type = 'COOPERATION_GOODS')
  );

COMMENT ON VIEW public.v_rev_my_issued_tools IS
  'Self-service: zaposleni vidi alate i stavke kooperativnog reversa koje trenutno ima zaduzene (match po email-u).';
