-- ============================================================================
-- REVERSI — Storage bucket `reversal-pdf` + RLS na storage.objects
-- ============================================================================
-- Namena: arhiva PDF potpisnica generisanih u browseru (Sprint R4).
--
-- Preduslov: `storage.buckets` i `storage.objects` (Supabase ili CI stub
-- `sql/ci/storage_stub.sql`). Preduslov funkcija: `public.rev_can_manage()`
-- (`add_reversi_module.sql`).
--
-- Idempotentno — bezbedno za re-run.
--
-- DOWN (ručno):
--   DROP POLICY IF EXISTS "reversal_pdf_select" ON storage.objects;
--   DROP POLICY IF EXISTS "reversal_pdf_insert" ON storage.objects;
--   DROP POLICY IF EXISTS "reversal_pdf_update" ON storage.objects;
--   DELETE FROM storage.objects WHERE bucket_id = 'reversal-pdf';
--   DELETE FROM storage.buckets WHERE id = 'reversal-pdf';
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'reversal-pdf',
  'reversal-pdf',
  false,
  10485760,
  ARRAY['application/pdf']::TEXT[]
)
ON CONFLICT (id) DO UPDATE
  SET public             = false,
      file_size_limit    = 10485760,
      allowed_mime_types = ARRAY['application/pdf']::TEXT[];

DROP POLICY IF EXISTS "reversal_pdf_select" ON storage.objects;
CREATE POLICY "reversal_pdf_select"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'reversal-pdf');

DROP POLICY IF EXISTS "reversal_pdf_insert" ON storage.objects;
CREATE POLICY "reversal_pdf_insert"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'reversal-pdf'
    AND public.rev_can_manage()
  );

DROP POLICY IF EXISTS "reversal_pdf_update" ON storage.objects;
CREATE POLICY "reversal_pdf_update"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'reversal-pdf'
    AND public.rev_can_manage()
  )
  WITH CHECK (
    bucket_id = 'reversal-pdf'
    AND public.rev_can_manage()
  );
