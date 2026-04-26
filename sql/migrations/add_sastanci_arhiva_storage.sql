-- ============================================================================
-- SASTANCI — Storage bucket 'sastanci-arhiva' za PDF zapisnike (Faza C)
-- ============================================================================
-- Šta dodaje:
--   1) Storage bucket 'sastanci-arhiva' — private, max 20 MB, samo PDF
--   2) Storage RLS politike (INSERT/SELECT/DELETE)
--      • INSERT: has_edit_role() → samo autentifikovani s pravom upisa
--      • SELECT: učesnik OR is_management — ucesnik čita zapise svog sastanka,
--               menadzment čita sve
--      • DELETE: is_management() — samo admin/menadzment brišu
--   3) Kolona `zapisnik_storage_path` u `sastanak_arhiva` već postoji
--      (dodata u add_sastanci_module.sql) — ova migracija ne menja tabelu.
--
-- Napomena o putanjama:
--   Sve PDF datoteke upisuju se pod:
--     sastanci-arhiva/{sastanak_id}/{archive_id}.pdf
--   Edge funkcija kreira ime, JS PDF generator čita/kreira putem:
--     supabase.storage.from('sastanci-arhiva').upload(path, blob)
--
-- Preduslov: `add_sastanci_module.sql` primenjen (tabele postoje).
--
-- Idempotentno — bezbedno za re-run.
--
-- DOWN:
--   DELETE FROM storage.objects WHERE bucket_id = 'sastanci-arhiva';
--   DELETE FROM storage.buckets WHERE id = 'sastanci-arhiva';
-- ============================================================================

-- ── 1) Bucket ────────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'sastanci-arhiva',
  'sastanci-arhiva',
  false,                              -- private
  20971520,                           -- 20 MB
  ARRAY['application/pdf']
)
ON CONFLICT (id) DO UPDATE
  SET public              = false,
      file_size_limit     = 20971520,
      allowed_mime_types  = ARRAY['application/pdf'];

COMMENT ON TABLE storage.buckets IS
  'Napomena: bucket sastanci-arhiva čuva PDF zapisnike zaključanih sastanaka (Faza C).';

-- ── 2) Storage RLS politike ───────────────────────────────────────────────────
--
-- Supabase Storage RLS se primenjuje na tabelu storage.objects.
-- Politike filtriraju po bucket_id = 'sastanci-arhiva'.
-- Putanja: sastanci-arhiva/{sastanak_id}/{archive_id}.pdf
-- Iz putanje izvlačimo sastanak_id kao (string_to_array(name, '/'))[1].

-- INSERT: has_edit_role() — isti uslov kao za upis podataka u sastanak tabele
DROP POLICY IF EXISTS "sa_insert" ON storage.objects;
CREATE POLICY "sa_insert"
  ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'sastanci-arhiva'
    AND public.has_edit_role()
  );

-- SELECT: učesnik svog sastanka OR menadzment
-- sastanak_id se čita iz prve komponente putanje (name)
DROP POLICY IF EXISTS "sa_select" ON storage.objects;
CREATE POLICY "sa_select"
  ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'sastanci-arhiva'
    AND (
      public.current_user_is_management()
      OR public.is_sastanak_ucesnik(
           (string_to_array(name, '/'))[1]::uuid
         )
    )
  );

-- DELETE: samo menadzment (ili admin koji je tipa menadzment)
DROP POLICY IF EXISTS "sa_delete" ON storage.objects;
CREATE POLICY "sa_delete"
  ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'sastanci-arhiva'
    AND public.current_user_is_management()
  );

-- ── 3) Verifikacija ───────────────────────────────────────────────────────────

SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id = 'sastanci-arhiva';
