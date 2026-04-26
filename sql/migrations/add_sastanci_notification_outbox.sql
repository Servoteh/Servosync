-- ============================================================================
-- SASTANCI — outbox tabela + enqueue helper (Faza C)
-- ============================================================================
-- Šta dodaje:
--   1) Tabela  `sastanci_notification_log`  — outbox za email/whatsapp
--   2) Indeksi za worker scan i lookup
--   3) RLS politike
--   4) SECURITY DEFINER helper `sastanci_enqueue_notification(...)`:
--      proveri prefs korisnika, INSERT queued ili skipped.
--      Koriste ga triggeri i Edge funkcija — zaobilazi RLS INSERT.
--
-- Pattern: parity sa `maint_notification_log` + `maint_enqueue_notification`.
-- Preduslov: `add_sastanci_notification_prefs.sql` primenjen.
--            `public.current_user_is_management()` prisutna.
--
-- Idempotentno — bezbedno za re-run.
--
-- DOWN:
--   DROP FUNCTION IF EXISTS public.sastanci_enqueue_notification(text,text,text,text,text,text,text,uuid,uuid,jsonb,text);
--   DROP TABLE IF EXISTS public.sastanci_notification_log;
-- ============================================================================

-- ── 1) Tabela ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.sastanci_notification_log (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Tip događaja
  kind                  TEXT        NOT NULL
                          CHECK (kind IN (
                            'akcija_new', 'akcija_changed',
                            'meeting_invite', 'meeting_locked',
                            'action_reminder', 'meeting_reminder'
                          )),

  -- Kanal slanja
  channel               TEXT        NOT NULL DEFAULT 'email'
                          CHECK (channel IN ('email', 'whatsapp')),

  -- Primalac
  recipient_email       TEXT        NOT NULL,  -- lower(email)
  recipient_label       TEXT,

  -- Email sadržaj (subject uvek; body generišu templates.ts)
  subject               TEXT        NOT NULL,
  body_html             TEXT,
  body_text             TEXT,

  -- Veze za audit i rendering
  related_sastanak_id   UUID        REFERENCES public.sastanci(id) ON DELETE SET NULL,
  related_akcija_id     UUID        REFERENCES public.akcioni_plan(id) ON DELETE SET NULL,

  -- Outbox status machine
  status                TEXT        NOT NULL DEFAULT 'queued'
                          CHECK (status IN ('queued', 'sent', 'failed', 'skipped')),

  -- Scheduling i retry
  scheduled_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  next_attempt_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_attempt_at       TIMESTAMPTZ,
  attempts              INT         NOT NULL DEFAULT 0,
  max_attempts          INT         NOT NULL DEFAULT 5,

  -- Error tracking
  error                 TEXT,

  -- Debug payload — originalni event podaci za Edge worker
  payload               JSONB,

  -- Audit
  created_by_email      TEXT,   -- NULL za cron; email za ručne akcije
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at               TIMESTAMPTZ
);

COMMENT ON TABLE  public.sastanci_notification_log IS
  'Outbox tabela za sastanci notifikacije (Faza C). '
  'Edge function `sastanci-notify-dispatch` čita queued redove i šalje email.';
COMMENT ON COLUMN public.sastanci_notification_log.kind IS
  'Tip notifikacije: akcija_new | akcija_changed | meeting_invite | '
  'meeting_locked | action_reminder | meeting_reminder.';
COMMENT ON COLUMN public.sastanci_notification_log.payload IS
  'JSONB sa svim podacima potrebnim Edge worker-u za render email-a '
  '(naslov sastanka, rok akcije, lista zadataka za digest itd.).';

-- ── 2) Indeksi ───────────────────────────────────────────────────────────────

-- Primarni worker scan: queued/failed koji su na redu
CREATE INDEX IF NOT EXISTS idx_sast_notif_queue
  ON public.sastanci_notification_log (status, next_attempt_at)
  WHERE status IN ('queued', 'failed');

-- Lookup po primaocu za UI/debug
CREATE INDEX IF NOT EXISTS idx_sast_notif_recipient
  ON public.sastanci_notification_log (recipient_email, kind, created_at DESC);

-- Lookup za dedup (idempotent check u reminder funkcijama)
CREATE INDEX IF NOT EXISTS idx_sast_notif_sastanak
  ON public.sastanci_notification_log (related_sastanak_id)
  WHERE related_sastanak_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sast_notif_akcija
  ON public.sastanci_notification_log (related_akcija_id)
  WHERE related_akcija_id IS NOT NULL;

-- ── 3) RLS ───────────────────────────────────────────────────────────────────

ALTER TABLE public.sastanci_notification_log ENABLE ROW LEVEL SECURITY;

-- SELECT: sopstvene notifikacije ili admin/menadzment
DROP POLICY IF EXISTS "snl_select" ON public.sastanci_notification_log;
CREATE POLICY "snl_select"
  ON public.sastanci_notification_log
  FOR SELECT TO authenticated
  USING (
    recipient_email = lower(COALESCE(auth.jwt() ->> 'email', ''))
    OR public.current_user_is_management()
  );

-- INSERT: triggeri i Edge funkcije upisuju (has_edit_role OR service_role)
DROP POLICY IF EXISTS "snl_insert" ON public.sastanci_notification_log;
CREATE POLICY "snl_insert"
  ON public.sastanci_notification_log
  FOR INSERT TO authenticated
  WITH CHECK (public.has_edit_role());

-- UPDATE/DELETE: admin/menadzment only
DROP POLICY IF EXISTS "snl_update" ON public.sastanci_notification_log;
CREATE POLICY "snl_update"
  ON public.sastanci_notification_log
  FOR UPDATE TO authenticated
  USING (public.current_user_is_management());

DROP POLICY IF EXISTS "snl_delete" ON public.sastanci_notification_log;
CREATE POLICY "snl_delete"
  ON public.sastanci_notification_log
  FOR DELETE TO authenticated
  USING (public.current_user_is_management());

-- ── 4) SECURITY DEFINER enqueue helper ───────────────────────────────────────
--
-- Zove se iz DB triggera (koji rade pod initiator-ovim kontekstom, ali
-- INSERT WITH CHECK ograničava šta se može pisati). SECURITY DEFINER
-- zaobilazi INSERT RLS — analogno `maint_enqueue_notification`.

CREATE OR REPLACE FUNCTION public.sastanci_enqueue_notification(
  p_kind                TEXT,
  p_channel             TEXT,
  p_recipient_email     TEXT,
  p_recipient_label     TEXT,
  p_subject             TEXT,
  p_body_html           TEXT        DEFAULT NULL,
  p_body_text           TEXT        DEFAULT NULL,
  p_related_sastanak_id UUID        DEFAULT NULL,
  p_related_akcija_id   UUID        DEFAULT NULL,
  p_payload             JSONB       DEFAULT NULL,
  p_created_by_email    TEXT        DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_prefs     public.sastanci_notification_prefs%ROWTYPE;
  v_opted_in  BOOLEAN;
  v_status    TEXT;
  v_id        UUID;
  v_email     TEXT;
BEGIN
  v_email := lower(COALESCE(p_recipient_email, ''));
  IF v_email = '' THEN
    RETURN NULL;
  END IF;

  -- Pročitaj prefs (ako ne postoje → default = sve true)
  SELECT * INTO v_prefs
  FROM public.sastanci_notification_prefs
  WHERE email = v_email;

  -- Odredi opt-in status po kind-u; ako reda nema, default je TRUE
  v_opted_in := CASE p_kind
    WHEN 'akcija_new'        THEN COALESCE(v_prefs.on_new_akcija,       TRUE)
    WHEN 'akcija_changed'    THEN COALESCE(v_prefs.on_change_akcija,    TRUE)
    WHEN 'meeting_invite'    THEN COALESCE(v_prefs.on_meeting_invite,   TRUE)
    WHEN 'meeting_locked'    THEN COALESCE(v_prefs.on_meeting_locked,   TRUE)
    WHEN 'action_reminder'   THEN COALESCE(v_prefs.on_action_reminder,  TRUE)
    WHEN 'meeting_reminder'  THEN COALESCE(v_prefs.on_meeting_reminder, TRUE)
    ELSE TRUE
  END;

  v_status := CASE WHEN v_opted_in THEN 'queued' ELSE 'skipped' END;

  INSERT INTO public.sastanci_notification_log (
    kind, channel,
    recipient_email, recipient_label,
    subject, body_html, body_text,
    related_sastanak_id, related_akcija_id,
    status, scheduled_at, next_attempt_at,
    payload, created_by_email
  ) VALUES (
    p_kind, COALESCE(p_channel, 'email'),
    v_email, p_recipient_label,
    COALESCE(p_subject, p_kind), p_body_html, p_body_text,
    p_related_sastanak_id, p_related_akcija_id,
    v_status, now(), now(),
    p_payload, p_created_by_email
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION public.sastanci_enqueue_notification(text,text,text,text,text,text,text,uuid,uuid,jsonb,text) IS
  'Outbox enqueue za sastanci notifikacije. Proverava prefs primaoca — '
  'ako je opt-out, INSERT sa status=skipped; inače status=queued. '
  'SECURITY DEFINER — zaobilazi RLS INSERT; poziva se iz DB triggera i Edge funkcije.';

-- Samo service_role (Edge) i triggeri (postgres) smeju direktno zvati
REVOKE ALL    ON FUNCTION public.sastanci_enqueue_notification(text,text,text,text,text,text,text,uuid,uuid,jsonb,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sastanci_enqueue_notification(text,text,text,text,text,text,text,uuid,uuid,jsonb,text) TO service_role;

-- ── 5) Verifikacija ───────────────────────────────────────────────────────────

SELECT 'sastanci_notification_log' AS tabela,
       COUNT(*)::TEXT AS redova
FROM   public.sastanci_notification_log;
