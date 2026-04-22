-- ============================================================================
-- PLAN MONTAŽE — Faza: polje „Veza sa“ na phases
-- ============================================================================
-- Pokreni JEDNOM u Supabase SQL Editoru.
--
-- Šta radi:
--   1) Dodaje JSONB kolonu `linked_drawings` na `phases` (analogno postojećem
--      `checks` jsonb obrascu). Sadržaj: niz stringova — brojevi sklopnih
--      crteža (drawing_no) potrebnih za fazu, npr. ["SC-12345","SC-12346"].
--   2) CHECK constraint da je vrednost JSON niz.
--   3) GIN index (jsonb_path_ops) za eventualnu pretragu "koje faze koriste
--      crtež X".
--
-- RLS: postojeće `phases_*` policy-je (has_edit_role(project_id)) primenjuju
-- se SAME na ovu kolonu — ne kreiramo posebne policy-je.
--
-- FK: NEMA FK ka `bigtehn_drawings_cache.drawing_no` — cache je
-- eventual-consistent (puni ga Bridge sync) pa bi FK pucao tokom sync-a.
-- ============================================================================

ALTER TABLE public.phases
    ADD COLUMN IF NOT EXISTS linked_drawings jsonb NOT NULL DEFAULT '[]'::jsonb;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'phases_linked_drawings_is_array'
  ) THEN
    ALTER TABLE public.phases
      ADD CONSTRAINT phases_linked_drawings_is_array
      CHECK (jsonb_typeof(linked_drawings) = 'array');
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS phases_linked_drawings_gin_idx
    ON public.phases USING gin (linked_drawings jsonb_path_ops);

COMMENT ON COLUMN public.phases.linked_drawings IS
    'Niz stringova: brojevi sklopnih crteža (drawing_no) potrebnih za ovu fazu. Referencira bigtehn_drawings_cache.drawing_no (bez FK — cache je eventual-consistent).';

-- ============================================================================
-- Smoke test (opciono — odkomentariši):
-- ============================================================================
-- SELECT id, phase_name, linked_drawings
-- FROM public.phases
-- WHERE jsonb_array_length(linked_drawings) > 0
-- LIMIT 10;
