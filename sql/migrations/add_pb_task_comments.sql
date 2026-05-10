-- ============================================================================
-- PROJEKTNI BIRO — Komentari na zadacima (`pb_task_comments`)
-- ============================================================================
-- Svrha:
--   Inženjeri ostavljaju komentare/napomene na pb_tasks. Tekst slobodan;
--   @mentions u tekstu su čista markdown konvencija (preview/notifikacije
--   van scope-a ove migracije — kasnije se mogu dodati outbox triggeri).
--
-- Zavisi od: public.pb_tasks, public.pb_can_edit_tasks(), update_updated_at
--
-- DOWN:
--   DROP POLICY IF EXISTS ptc_select ON public.pb_task_comments;
--   DROP POLICY IF EXISTS ptc_insert ON public.pb_task_comments;
--   DROP POLICY IF EXISTS ptc_update ON public.pb_task_comments;
--   DROP POLICY IF EXISTS ptc_delete ON public.pb_task_comments;
--   DROP TABLE IF EXISTS public.pb_task_comments;
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.pb_task_comments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id       UUID NOT NULL REFERENCES public.pb_tasks(id) ON DELETE CASCADE,
  body          TEXT NOT NULL,
  /* Lista @-mention email-ova ili full_name vrednosti za buduće notifikacije. */
  mentions      TEXT[] NOT NULL DEFAULT '{}',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by    TEXT,
  created_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  edited_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ptc_task_created
  ON public.pb_task_comments (task_id, created_at DESC);

COMMENT ON TABLE public.pb_task_comments IS
  'Komentari/napomene na pb_tasks. Slobodan tekst, @mentions su markdown konvencija.';

-- updated_at trigger
DROP TRIGGER IF EXISTS trg_pb_task_comments_updated ON public.pb_task_comments;
CREATE TRIGGER trg_pb_task_comments_updated
  BEFORE UPDATE ON public.pb_task_comments
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- RLS
ALTER TABLE public.pb_task_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ptc_select ON public.pb_task_comments;
CREATE POLICY ptc_select ON public.pb_task_comments
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS ptc_insert ON public.pb_task_comments;
CREATE POLICY ptc_insert ON public.pb_task_comments
  FOR INSERT TO authenticated
  WITH CHECK (
    public.pb_can_edit_tasks()
    AND created_by_user_id = auth.uid()
  );

/* Izmena: samo autor, do 60 min od kreiranja (sprečavanje rewriting istorije). */
DROP POLICY IF EXISTS ptc_update ON public.pb_task_comments;
CREATE POLICY ptc_update ON public.pb_task_comments
  FOR UPDATE TO authenticated
  USING (
    public.current_user_is_admin()
    OR (created_by_user_id = auth.uid() AND created_at > now() - interval '60 minutes')
  )
  WITH CHECK (
    public.current_user_is_admin()
    OR (created_by_user_id = auth.uid() AND created_at > now() - interval '60 minutes')
  );

DROP POLICY IF EXISTS ptc_delete ON public.pb_task_comments;
CREATE POLICY ptc_delete ON public.pb_task_comments
  FOR DELETE TO authenticated
  USING (
    public.current_user_is_admin()
    OR (created_by_user_id = auth.uid() AND created_at > now() - interval '60 minutes')
  );

REVOKE ALL ON TABLE public.pb_task_comments FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pb_task_comments TO authenticated;
