-- ============================================================================
-- SASTANCI — PM teme draft status (Faza D / Structured weekly prep)
-- ============================================================================
-- Dodaje status 'draft' bez uklanjanja postojećih vrednosti koje frontend koristi.
-- Approval trail već pokrivaju postojeće kolone:
--   resio_email, resio_label, resio_at, resio_napomena.
-- ============================================================================

ALTER TABLE public.pm_teme
  DROP CONSTRAINT IF EXISTS pm_teme_status_check;

ALTER TABLE public.pm_teme
  ADD CONSTRAINT pm_teme_status_check
  CHECK (status IN ('draft','predlog','usvojeno','odbijeno','odlozeno','zatvoreno'));

CREATE INDEX IF NOT EXISTS idx_pm_teme_draft_projekat
  ON public.pm_teme (projekat_id, status)
  WHERE status = 'draft';

-- Vidi: Faza D / Structured weekly prep
