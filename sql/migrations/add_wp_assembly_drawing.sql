-- ============================================================================
-- PLAN MONTAŽE — Work Package (RN/„nalog montaže"): polje „Glavni crtež sklopa"
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru.
--
-- Šta radi:
--   1) Dodaje TEXT kolonu `assembly_drawing_no` na `work_packages`.
--      Sadržaj: jedan broj sklopnog crteža (drawing_no) koji predstavlja
--      crtež CELOG sklopa ili podsklopa za taj nalog montaže (npr. "SC-12345").
--      Razlika u odnosu na `phases.linked_drawings`:
--        • `phases.linked_drawings` = niz brojeva crteža potrebnih za jednu fazu
--        • `work_packages.assembly_drawing_no` = JEDAN „glavni" crtež celog WP-a
--   2) CHECK constraint: maksimalna dužina (sanity), bez praznih razmaka samo.
--
-- RLS: postojeće `wp_*` policy-je (has_edit_role(project_id)) primenjuju se
-- na ovu kolonu — ne kreiramo posebne policy-je.
--
-- FK: NEMA FK ka `bigtehn_drawings_cache.drawing_no` — cache je
-- eventual-consistent (puni ga Bridge sync) pa bi FK pucao tokom sync-a.
-- Front-end pri unosu prikazuje ⚠ ako broj još nije u cache-u.
-- ============================================================================

ALTER TABLE public.work_packages
    ADD COLUMN IF NOT EXISTS assembly_drawing_no text NOT NULL DEFAULT '';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'work_packages_assembly_drawing_no_len'
  ) THEN
    ALTER TABLE public.work_packages
      ADD CONSTRAINT work_packages_assembly_drawing_no_len
      CHECK (char_length(assembly_drawing_no) <= 120);
  END IF;
END$$;

COMMENT ON COLUMN public.work_packages.assembly_drawing_no IS
    'Broj sklopnog crteža (drawing_no) celog sklopa/podsklopa za ovaj WP. Prazan string znači da nije postavljen. Referencira bigtehn_drawings_cache.drawing_no (bez FK — cache je eventual-consistent).';

-- ============================================================================
-- Smoke test (opciono — odkomentariši):
-- ============================================================================
-- SELECT id, name, rn_code, assembly_drawing_no
-- FROM public.work_packages
-- WHERE assembly_drawing_no <> ''
-- LIMIT 10;
