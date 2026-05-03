-- ============================================================================
-- SASTANCI — functional lower() indexes for email RLS filters (Sprint 3 — M2)
-- ============================================================================
-- RLS politike porede LOWER(email_kolone) sa LOWER(auth.jwt()->>'email').
-- Plain btree indeksi na email kolonama ne pokrivaju taj izraz, zato dodajemo
-- funkcionalne indekse bez brisanja postojećih indeksa.
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_sast_vodio_email_lower
  ON public.sastanci (LOWER(vodio_email));

CREATE INDEX IF NOT EXISTS idx_sast_zapisnicar_email_lower
  ON public.sastanci (LOWER(zapisnicar_email));

CREATE INDEX IF NOT EXISTS idx_sast_created_by_email_lower
  ON public.sastanci (LOWER(created_by_email));

CREATE INDEX IF NOT EXISTS idx_ap_odgovoran_email_lower
  ON public.akcioni_plan (LOWER(odgovoran_email));

CREATE INDEX IF NOT EXISTS idx_pmt_predlozio_email_lower
  ON public.pm_teme (LOWER(predlozio_email));

CREATE INDEX IF NOT EXISTS idx_su_email_lower
  ON public.sastanak_ucesnici (LOWER(email));

-- Vidi: docs/audit/sastanci-audit-2026-05-03.md M2
