-- ============================================================================
-- PROJEKTNI BIRO — Quiet hours + digest podrška za notifikacije
-- ============================================================================
-- Svrha:
--   1) Dodaje konfiguraciju "tih sati" — pb_dispatch_dequeue NE vraća
--      pending poruke kada je trenutno vreme između quiet_hours_start i
--      quiet_hours_end (timezone-aware, podrazumevano Europe/Belgrade).
--   2) Dodaje `digest_mode` flag — kada je TRUE, Edge function može da
--      grupiše više pending poruka za istog primaoca u jedan mejl (logika
--      je u Edge functionu; SQL samo izlaže flag).
--
-- Zavisnosti: add_pb_notifications.sql
--
-- Idempotentno (ADD COLUMN IF NOT EXISTS, CREATE OR REPLACE FUNCTION).
--
-- DOWN:
--   ALTER TABLE public.pb_notification_config
--     DROP COLUMN IF EXISTS quiet_hours_start,
--     DROP COLUMN IF EXISTS quiet_hours_end,
--     DROP COLUMN IF EXISTS quiet_hours_tz,
--     DROP COLUMN IF EXISTS digest_mode;
--   /* pb_dispatch_dequeue: vrati staru verziju iz add_pb_notifications.sql */
-- ============================================================================

ALTER TABLE public.pb_notification_config
  ADD COLUMN IF NOT EXISTS quiet_hours_start TIME,                -- npr. '22:00'
  ADD COLUMN IF NOT EXISTS quiet_hours_end   TIME,                -- npr. '06:00'
  ADD COLUMN IF NOT EXISTS quiet_hours_tz    TEXT NOT NULL DEFAULT 'Europe/Belgrade',
  ADD COLUMN IF NOT EXISTS digest_mode       BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.pb_notification_config.quiet_hours_start IS
  'Tihi sati — početak prozora kada se notifikacije pauziraju (NULL = isključeno).';
COMMENT ON COLUMN public.pb_notification_config.quiet_hours_end IS
  'Tihi sati — kraj prozora (može biti manji od start za preko-noći npr. 22:00→06:00).';
COMMENT ON COLUMN public.pb_notification_config.digest_mode IS
  'Ako TRUE, Edge function grupiše više pending poruka istog primaoca u jedan mejl.';

-- Helper: vraća TRUE ako je trenutno vreme unutar tihih sati prema konfiguraciji.
CREATE OR REPLACE FUNCTION public.pb_in_quiet_hours()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.pb_notification_config%ROWTYPE;
  v_now TIME;
BEGIN
  SELECT * INTO v_cfg FROM public.pb_notification_config WHERE id = 1;
  IF NOT FOUND OR v_cfg.quiet_hours_start IS NULL OR v_cfg.quiet_hours_end IS NULL THEN
    RETURN FALSE;
  END IF;
  v_now := (now() AT TIME ZONE COALESCE(v_cfg.quiet_hours_tz, 'Europe/Belgrade'))::TIME;
  IF v_cfg.quiet_hours_start < v_cfg.quiet_hours_end THEN
    /* Isti dan, npr. 12:00 → 14:00 */
    RETURN v_now >= v_cfg.quiet_hours_start AND v_now < v_cfg.quiet_hours_end;
  ELSE
    /* Preko ponoći, npr. 22:00 → 06:00 */
    RETURN v_now >= v_cfg.quiet_hours_start OR v_now < v_cfg.quiet_hours_end;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.pb_in_quiet_hours() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_in_quiet_hours() TO authenticated, service_role;

-- Patch dispatch: ako je tihi sat, ne vraćaj poruke (Edge function će u sledećem
-- batch-u pokušati ponovo; cron tick ne mora da se menja).
-- DROP ako je starija verzija imala drugačiji RETURNS (42P13 bez ovoga).
DROP FUNCTION IF EXISTS public.pb_dispatch_dequeue(INTEGER);

CREATE FUNCTION public.pb_dispatch_dequeue(batch_size INTEGER DEFAULT 10)
RETURNS TABLE (
  id          UUID,
  channel     TEXT,
  recipient   TEXT,
  subject     TEXT,
  body        TEXT,
  attempts    INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.pb_in_quiet_hours() THEN
    /* Vraćamo prazan kursor — poruke ostaju u 'pending' do sledećeg poziva. */
    RETURN;
  END IF;

  RETURN QUERY
  UPDATE public.pb_notification_log nl
  SET status = 'processing',
      processed_at = now(),
      attempts = nl.attempts + 1
  WHERE nl.id IN (
    SELECT nl2.id FROM public.pb_notification_log nl2
    WHERE nl2.status = 'pending'
    ORDER BY nl2.created_at ASC
    LIMIT GREATEST(1, COALESCE(batch_size, 10))
    FOR UPDATE SKIP LOCKED
  )
  RETURNING nl.id, nl.channel::TEXT, nl.recipient, nl.subject, nl.body, nl.attempts;
END;
$$;

REVOKE ALL ON FUNCTION public.pb_dispatch_dequeue(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pb_dispatch_dequeue(INTEGER) TO service_role;

-- ── Sanity ───────────────────────────────────────────────────────────────
-- SELECT public.pb_in_quiet_hours();
-- UPDATE public.pb_notification_config SET quiet_hours_start='22:00', quiet_hours_end='06:00' WHERE id=1;
