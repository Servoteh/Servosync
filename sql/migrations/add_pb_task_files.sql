-- ============================================================================
-- PROJEKTNI BIRO — Prilozi na zadatku (`pb_task_files` + Storage bucket)
-- ============================================================================
-- Svrha:
--   Inženjeri mogu da dodaju dokumentaciju uz zadatak: tehničke crteže (PDF,
--   DWG, DXF, STEP/IGES), fotografije, Office dokumente, specifikacije.
--   Binarni sadržaj je u Supabase Storage bucket-u `pb-task-files` (privatan).
--   Metapodaci su u public.pb_task_files. RLS prati postojeći obrazac iz
--   pb_tasks (čitanje authenticated; pisanje pb_can_edit_tasks()).
--
-- Zavisnosti:
--   public.pb_tasks                    -- iz add_pb_module.sql
--   public.pb_can_edit_tasks()         -- iz add_pb_module.sql
--   public.current_user_is_admin()
--   public.update_updated_at()
--
-- Pokreni JEDNOM u Supabase SQL Editoru (posle backup-a).
-- Idempotentno (CREATE TABLE IF NOT EXISTS, ON CONFLICT DO NOTHING).
--
-- DOWN (ručno, rollback test):
--   DROP POLICY IF EXISTS ptf_select ON public.pb_task_files;
--   DROP POLICY IF EXISTS ptf_insert ON public.pb_task_files;
--   DROP POLICY IF EXISTS ptf_update ON public.pb_task_files;
--   DROP POLICY IF EXISTS ptf_delete ON public.pb_task_files;
--   DROP TABLE IF EXISTS public.pb_task_files;
--   DROP POLICY IF EXISTS "ptf_storage_read"   ON storage.objects;
--   DROP POLICY IF EXISTS "ptf_storage_insert" ON storage.objects;
--   DROP POLICY IF EXISTS "ptf_storage_update" ON storage.objects;
--   DROP POLICY IF EXISTS "ptf_storage_delete" ON storage.objects;
--   DELETE FROM storage.buckets WHERE id = 'pb-task-files';
-- ============================================================================

-- ── 1) Metapodaci ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.pb_task_files (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id         UUID NOT NULL REFERENCES public.pb_tasks(id) ON DELETE CASCADE,

  /* Originalno ime za prikaz; storage_path je UUID-prefixed da izbegne kolizije. */
  file_name       TEXT NOT NULL,
  storage_path    TEXT NOT NULL UNIQUE,

  mime_type       TEXT,
  size_bytes      BIGINT,

  /* Slobodna kategorija (autocomplete u UI): drawing | photo | spec | report | other */
  category        TEXT,
  description     TEXT,

  /* Soft delete (zadržavamo red za audit; binary u Storage brišemo odmah). */
  deleted_at      TIMESTAMPTZ,

  uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  uploaded_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  uploaded_by_email TEXT
);

CREATE INDEX IF NOT EXISTS idx_ptf_task_active
  ON public.pb_task_files (task_id, uploaded_at DESC)
  WHERE deleted_at IS NULL;

COMMENT ON TABLE public.pb_task_files IS
  'Prilozi (PDF, slike, CAD, Office dokumenti) uz pb_tasks zadatak. Binary u Storage bucket-u pb-task-files.';
COMMENT ON COLUMN public.pb_task_files.storage_path IS
  'Relativna putanja u bucket-u, npr. "<task_uuid>/<uuid>_crtez.pdf".';
COMMENT ON COLUMN public.pb_task_files.category IS
  'Tip dokumenta: drawing | photo | spec | report | other (slobodan tekst).';

-- ── 2) RLS ───────────────────────────────────────────────────────────────
ALTER TABLE public.pb_task_files ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ptf_select ON public.pb_task_files;
CREATE POLICY ptf_select ON public.pb_task_files
  FOR SELECT TO authenticated
  USING (deleted_at IS NULL);

DROP POLICY IF EXISTS ptf_insert ON public.pb_task_files;
CREATE POLICY ptf_insert ON public.pb_task_files
  FOR INSERT TO authenticated
  WITH CHECK (
    public.pb_can_edit_tasks()
    AND uploaded_by = auth.uid()
  );

/* Izmena metapodataka (description/category): autor (do 24h) ili admin. */
DROP POLICY IF EXISTS ptf_update ON public.pb_task_files;
CREATE POLICY ptf_update ON public.pb_task_files
  FOR UPDATE TO authenticated
  USING (
    public.current_user_is_admin()
    OR (uploaded_by = auth.uid() AND uploaded_at > now() - interval '24 hours')
  )
  WITH CHECK (
    public.current_user_is_admin()
    OR (uploaded_by = auth.uid() AND uploaded_at > now() - interval '24 hours')
  );

/* Brisanje: pb_can_edit_tasks (svi sa edit pravima u PB-u). */
DROP POLICY IF EXISTS ptf_delete ON public.pb_task_files;
CREATE POLICY ptf_delete ON public.pb_task_files
  FOR DELETE TO authenticated
  USING (public.pb_can_edit_tasks());

-- ── 3) GRANT
REVOKE ALL ON TABLE public.pb_task_files FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pb_task_files TO authenticated;

-- ── 4) Storage bucket ────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'pb-task-files',
  'pb-task-files',
  FALSE,                                       -- privatan
  50 * 1024 * 1024,                            -- 50 MB po fajlu (CAD/STEP mogu da budu veliki)
  ARRAY[
    'application/pdf',
    'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/tiff', 'image/bmp',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain', 'text/csv',
    /* CAD / inženjerski formati — MIME varijante: */
    'image/vnd.dwg', 'application/acad', 'application/x-dwg',
    'image/vnd.dxf', 'application/dxf', 'application/x-dxf',
    'model/step', 'application/step', 'application/x-step',
    'model/iges', 'application/iges',
    'model/stl', 'application/sla', 'application/vnd.ms-pki.stl',
    'application/zip', 'application/x-zip-compressed',
    'application/octet-stream'                 -- fallback (CAD često bez MIME-a)
  ]
)
ON CONFLICT (id) DO NOTHING;

-- ── 5) Storage RLS politike ──────────────────────────────────────────────
DROP POLICY IF EXISTS "ptf_storage_read" ON storage.objects;
CREATE POLICY "ptf_storage_read"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'pb-task-files');

DROP POLICY IF EXISTS "ptf_storage_insert" ON storage.objects;
CREATE POLICY "ptf_storage_insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'pb-task-files'
    AND public.pb_can_edit_tasks()
  );

DROP POLICY IF EXISTS "ptf_storage_update" ON storage.objects;
CREATE POLICY "ptf_storage_update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'pb-task-files'
    AND (public.current_user_is_admin() OR owner = auth.uid())
  )
  WITH CHECK (
    bucket_id = 'pb-task-files'
    AND (public.current_user_is_admin() OR owner = auth.uid())
  );

DROP POLICY IF EXISTS "ptf_storage_delete" ON storage.objects;
CREATE POLICY "ptf_storage_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'pb-task-files'
    AND (
      public.current_user_is_admin()
      OR public.pb_can_edit_tasks()
      OR owner = auth.uid()
    )
  );

-- ── 6) Sanity check ──────────────────────────────────────────────────────
-- SELECT id, public, file_size_limit FROM storage.buckets WHERE id = 'pb-task-files';
-- SELECT polname, cmd FROM pg_policies WHERE schemaname='public' AND tablename='pb_task_files';
