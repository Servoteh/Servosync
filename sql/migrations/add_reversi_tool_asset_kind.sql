-- REVERSI — Klasa inventarske jedinice (alat vs. radna odeća / obuća / LZO).
-- Idempotentno.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'rev_tools'
      AND column_name = 'asset_kind'
  ) THEN
    ALTER TABLE public.rev_tools
      ADD COLUMN asset_kind text NOT NULL DEFAULT 'GENERAL_TOOL';
  END IF;
END$$;

DO $$
DECLARE v_name text;
BEGIN
  SELECT c.conname INTO v_name
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE n.nspname = 'public'
    AND t.relname = 'rev_tools'
    AND c.conname = 'rev_tools_asset_kind_check';
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.rev_tools DROP CONSTRAINT %I', v_name);
  END IF;
END$$;

ALTER TABLE public.rev_tools
  ADD CONSTRAINT rev_tools_asset_kind_check
  CHECK (asset_kind IN (
    'GENERAL_TOOL',
    'PPE_WORKWEAR',
    'PPE_FOOTWEAR',
    'PPE_OTHER'
  ));

COMMENT ON COLUMN public.rev_tools.asset_kind IS
  'Klasa zadužene stavke: opšti alat/oprema, radna odeća, zaštitna obuća, ostala lična zaštitna sredstva (rukavice, naočare, slušalice, itd.).';

CREATE INDEX IF NOT EXISTS rev_tools_asset_kind_idx ON public.rev_tools (asset_kind);

-- Self-service: kategorija na zaduženjima radnika
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
  t.asset_kind,
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
  'Self-service: zaposleni vidi alate i stavke kooperativnog reversa koje trenutno ima zaduzene (match po email-u). Za TOOL linije: asset_kind iz rev_tools.';
