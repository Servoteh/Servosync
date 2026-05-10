-- ============================================================================
-- PROJEKTNI BIRO — Zavisnosti između zadataka (`pb_task_deps`)
-- ============================================================================
-- Svrha:
--   "Zadatak A čeka da Zadatak B završi" — eksplicitna zavisnost koja se
--   koristi za blokiranje statusa i (kasnije) critical path izračun.
--   Tabela je simple edge-list: (task_id, depends_on_task_id).
--
--   Helper RPC pb_check_dep_cycle(task, dep) — vraća TRUE ako bi dodavanje
--   zavisnosti napravilo ciklus (DFS preko CTE).
--
-- Zavisnosti:
--   public.pb_tasks, public.pb_can_edit_tasks()
--
-- Pokreni JEDNOM u Supabase SQL Editoru.
-- Idempotentno (CREATE TABLE IF NOT EXISTS, CREATE OR REPLACE).
--
-- DOWN:
--   DROP POLICY IF EXISTS ptd_select ON public.pb_task_deps;
--   DROP POLICY IF EXISTS ptd_insert ON public.pb_task_deps;
--   DROP POLICY IF EXISTS ptd_delete ON public.pb_task_deps;
--   DROP TABLE IF EXISTS public.pb_task_deps;
--   DROP FUNCTION IF EXISTS public.pb_check_dep_cycle(UUID, UUID);
-- ============================================================================

-- ── 1) Tabela ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.pb_task_deps (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id               UUID NOT NULL REFERENCES public.pb_tasks(id) ON DELETE CASCADE,
  depends_on_task_id    UUID NOT NULL REFERENCES public.pb_tasks(id) ON DELETE CASCADE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by            TEXT,

  /* Niko ne sme da bude svoja zavisnost. */
  CONSTRAINT pb_task_deps_no_self CHECK (task_id <> depends_on_task_id),
  /* Jedna zavisnost po paru. */
  CONSTRAINT pb_task_deps_unique UNIQUE (task_id, depends_on_task_id)
);

CREATE INDEX IF NOT EXISTS idx_ptd_task ON public.pb_task_deps (task_id);
CREATE INDEX IF NOT EXISTS idx_ptd_depends_on ON public.pb_task_deps (depends_on_task_id);

COMMENT ON TABLE public.pb_task_deps IS
  'Edge-list zavisnosti pb_tasks. task_id čeka da depends_on_task_id završi.';

-- ── 2) Ciklusna provera (DFS preko rekurzivnog CTE-a) ────────────────────
CREATE OR REPLACE FUNCTION public.pb_check_dep_cycle(
  p_task_id UUID,
  p_depends_on UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  /* Vraća TRUE ako bi dodavanje grane (p_task_id → p_depends_on) napravilo ciklus.
     Logika: idemo unazad od p_depends_on prateći postojeće zavisnosti. Ako
     stignemo do p_task_id, znači da p_task_id već (tranzitivno) zavisi od
     p_depends_on, pa bi nova grana napravila petlju. */
  WITH RECURSIVE walk AS (
    SELECT depends_on_task_id AS node
    FROM public.pb_task_deps
    WHERE task_id = p_depends_on
    UNION
    SELECT d.depends_on_task_id
    FROM public.pb_task_deps d
    JOIN walk w ON d.task_id = w.node
  )
  SELECT EXISTS (SELECT 1 FROM walk WHERE node = p_task_id) OR p_task_id = p_depends_on;
$$;

REVOKE ALL ON FUNCTION public.pb_check_dep_cycle(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_check_dep_cycle(UUID, UUID) TO authenticated;

-- ── 3) Trigger koji odbija ciklične insert-e ─────────────────────────────
CREATE OR REPLACE FUNCTION public.pb_task_deps_check_cycle_trg()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.pb_check_dep_cycle(NEW.task_id, NEW.depends_on_task_id) THEN
    RAISE EXCEPTION 'Ciklicna zavisnost izmedju zadataka nije dozvoljena (task_id=%, depends_on=%)',
      NEW.task_id, NEW.depends_on_task_id
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pb_task_deps_no_cycle ON public.pb_task_deps;
CREATE TRIGGER trg_pb_task_deps_no_cycle
  BEFORE INSERT OR UPDATE ON public.pb_task_deps
  FOR EACH ROW EXECUTE FUNCTION public.pb_task_deps_check_cycle_trg();

-- ── 4) RLS ───────────────────────────────────────────────────────────────
ALTER TABLE public.pb_task_deps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ptd_select ON public.pb_task_deps;
CREATE POLICY ptd_select ON public.pb_task_deps
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS ptd_insert ON public.pb_task_deps;
CREATE POLICY ptd_insert ON public.pb_task_deps
  FOR INSERT TO authenticated
  WITH CHECK (public.pb_can_edit_tasks());

DROP POLICY IF EXISTS ptd_delete ON public.pb_task_deps;
CREATE POLICY ptd_delete ON public.pb_task_deps
  FOR DELETE TO authenticated
  USING (public.pb_can_edit_tasks());

-- ── 5) GRANT ─────────────────────────────────────────────────────────────
REVOKE ALL ON TABLE public.pb_task_deps FROM PUBLIC;
GRANT SELECT, INSERT, DELETE ON public.pb_task_deps TO authenticated;

-- ── 6) Sanity check ──────────────────────────────────────────────────────
-- SELECT polname, cmd FROM pg_policies WHERE schemaname='public' AND tablename='pb_task_deps';
-- SELECT public.pb_check_dep_cycle('<a-uuid>'::uuid, '<a-uuid>'::uuid); -- true (self)
