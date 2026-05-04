-- Mirrors sql/migrations/add_reversi_reversal_pdf_storage.sql for Supabase CLI deploys.

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
