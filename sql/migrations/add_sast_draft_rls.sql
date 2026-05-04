-- ============================================================================
-- SASTANCI — draft PM teme RLS (Faza D / Structured weekly prep)
-- ============================================================================
-- Sprint 1 `pmt_insert` blokira non-management INSERT za sastanak_id IS NULL.
-- Zato draft teme dobijaju eksplicitne INSERT/UPDATE politike. Politike su
-- permissive i OR-uju se sa postojećim `pmt_*` politikama.
-- ============================================================================

DROP POLICY IF EXISTS "pmt_select" ON public.pm_teme;
CREATE POLICY "pmt_select" ON public.pm_teme
  FOR SELECT TO authenticated
  USING (
    (
      LOWER(COALESCE(predlozio_email, '')) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
      OR public.current_user_is_management()
      OR (sastanak_id IS NOT NULL AND public.is_sastanak_ucesnik(sastanak_id))
    )
    OR (
      status IN ('draft', 'usvojeno', 'odbijeno')
      AND sastanak_id IS NULL
      AND public.has_edit_role()
    )
  );

DROP POLICY IF EXISTS "pm_teme_draft_insert" ON public.pm_teme;
CREATE POLICY "pm_teme_draft_insert" ON public.pm_teme
  FOR INSERT TO authenticated
  WITH CHECK (
    status = 'draft'
    AND sastanak_id IS NULL
    AND public.has_edit_role()
  );

DROP POLICY IF EXISTS "pm_teme_draft_review" ON public.pm_teme;
CREATE POLICY "pm_teme_draft_review" ON public.pm_teme
  FOR UPDATE TO authenticated
  USING (
    status = 'draft'
    AND (
      public.has_edit_role()
      OR public.current_user_is_management()
    )
  )
  WITH CHECK (
    public.has_edit_role()
    OR public.current_user_is_management()
  );

-- Existing Sprint 1 pmt_update is also permissive. Enforce the draft review
-- lifecycle in a trigger so draft cannot move directly to closed/archive states.
CREATE OR REPLACE FUNCTION public.sast_pm_teme_draft_status_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.status = 'draft'
     AND NEW.status <> OLD.status
     AND NEW.status NOT IN ('usvojeno', 'odbijeno') THEN
    RAISE EXCEPTION 'Draft tema može biti samo usvojena ili odbijena.'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sast_trg_pm_teme_draft_status_guard ON public.pm_teme;
CREATE TRIGGER sast_trg_pm_teme_draft_status_guard
  BEFORE UPDATE OF status ON public.pm_teme
  FOR EACH ROW EXECUTE FUNCTION public.sast_pm_teme_draft_status_guard();

NOTIFY pgrst, 'reload schema';

-- Vidi: Faza D / Structured weekly prep
