-- ============================================================================
-- ODRŽAVANJE — outbox infrastruktura za notifikacije (WhatsApp/email)
-- ============================================================================
-- Kontekst: postojeća tabela `maint_notification_log` već ima status enum
-- (queued/sent/failed) i polja za poruku, primaoca, error i sent_at. Ova
-- migracija je nadograđuje u pravu outbox tabelu (worker-friendly):
--   • dodaje `scheduled_at`, `next_attempt_at`, `last_attempt_at`, `attempts`,
--     `payload jsonb` (slobodan dodatni JSON koji worker razume),
--   • dodaje `phone` u `maint_user_profiles` (broj na koji ide WhatsApp),
--   • daje SECURITY DEFINER funkciju `public.maint_enqueue_notification(...)`
--     koja zaobilazi `INSERT WITH CHECK (false)` policy (queueing iz triggera),
--   • dodaje AFTER INSERT trigger na `maint_incidents` koji za major/critical
--     queue-uje stub red (worker razrešava primaoca/eskalaciju kasnije),
--   • dodaje composite index za queue scan (`status, next_attempt_at`).
--
-- Pokreni u Supabase SQL Editoru. Idempotentno.
--
-- DOWN (ručno):
--   DROP TRIGGER IF EXISTS maint_incidents_enqueue_notify ON public.maint_incidents;
--   DROP FUNCTION IF EXISTS public.maint_incidents_enqueue_notify();
--   DROP FUNCTION IF EXISTS public.maint_enqueue_notification(
--     public.maint_notification_channel, text, uuid, text, text, text, uuid, text, int, jsonb
--   );
--   ALTER TABLE public.maint_notification_log
--     DROP COLUMN IF EXISTS scheduled_at,
--     DROP COLUMN IF EXISTS next_attempt_at,
--     DROP COLUMN IF EXISTS last_attempt_at,
--     DROP COLUMN IF EXISTS attempts,
--     DROP COLUMN IF EXISTS payload;
--   ALTER TABLE public.maint_user_profiles DROP COLUMN IF EXISTS phone;
-- ============================================================================

-- 1) Telefon u profilu održavanja (E.164 preporučljivo, npr. "+38163123456").
ALTER TABLE public.maint_user_profiles
  ADD COLUMN IF NOT EXISTS phone TEXT;

COMMENT ON COLUMN public.maint_user_profiles.phone IS
  'Telefon u E.164 formatu (npr. +38163123456) — koristi ga worker za WhatsApp Business slanje.';

-- 2) Outbox kolone na `maint_notification_log`.
ALTER TABLE public.maint_notification_log
  ADD COLUMN IF NOT EXISTS scheduled_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS next_attempt_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS last_attempt_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS attempts         INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS payload          JSONB;

COMMENT ON COLUMN public.maint_notification_log.scheduled_at IS
  'Najraniji trenutak slanja (queue-time logika; worker poštuje >= now()).';
COMMENT ON COLUMN public.maint_notification_log.next_attempt_at IS
  'Sledeći pokušaj (na fail-u worker postavlja exponential backoff).';
COMMENT ON COLUMN public.maint_notification_log.attempts IS
  'Broj već izvršenih pokušaja slanja.';
COMMENT ON COLUMN public.maint_notification_log.payload IS
  'Opcioni JSON koji worker razume (npr. WhatsApp template id, parametri).';

-- 3) Index za worker scan (čita queued/failed-with-retry koji su za sad).
CREATE INDEX IF NOT EXISTS idx_maint_notif_queue
  ON public.maint_notification_log (status, next_attempt_at)
  WHERE status IN ('queued', 'failed');

-- 4) SECURITY DEFINER enqueue funkcija — koristi se iz triggera ili Edge poziva.
--    Zaobilazi `INSERT WITH CHECK (false)` policy.
CREATE OR REPLACE FUNCTION public.maint_enqueue_notification(
  p_channel              public.maint_notification_channel,
  p_recipient            TEXT,
  p_recipient_user_id    UUID,
  p_subject              TEXT,
  p_body                 TEXT,
  p_related_entity_type  TEXT,
  p_related_entity_id    UUID,
  p_machine_code         TEXT,
  p_escalation_level     INT DEFAULT 0,
  p_payload              JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.maint_notification_log (
    channel, recipient, recipient_user_id, subject, body,
    related_entity_type, related_entity_id, machine_code,
    escalation_level, status, scheduled_at, next_attempt_at, payload
  ) VALUES (
    p_channel,
    coalesce(p_recipient, 'pending'),
    p_recipient_user_id,
    p_subject,
    p_body,
    p_related_entity_type,
    p_related_entity_id,
    p_machine_code,
    coalesce(p_escalation_level, 0),
    'queued',
    now(), now(),
    p_payload
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION public.maint_enqueue_notification(
  public.maint_notification_channel, text, uuid, text, text, text, uuid, text, int, jsonb
) IS 'Outbox enqueue. SECURITY DEFINER da bi se mogao zvati iz triggera/UI-ja (RLS insert je zatvoren).';

-- Niko sem service_role-a (worker) ne treba ručno da zove ovo iz UI-ja.
REVOKE ALL ON FUNCTION public.maint_enqueue_notification(
  public.maint_notification_channel, text, uuid, text, text, text, uuid, text, int, jsonb
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.maint_enqueue_notification(
  public.maint_notification_channel, text, uuid, text, text, text, uuid, text, int, jsonb
) TO service_role;

-- 5) Trigger: kreiran incident (major/critical) → enqueue stub red.
--    Recipient razrešava worker (čita maint_user_profiles po ulogama i šalje
--    eskalaciono). Body je generisan iz incident podataka.
CREATE OR REPLACE FUNCTION public.maint_incidents_enqueue_notify()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_subject TEXT;
  v_body TEXT;
BEGIN
  IF NEW.severity NOT IN ('major', 'critical') THEN
    RETURN NEW;
  END IF;

  v_subject := format('[Održavanje] %s incident: %s',
    upper(NEW.severity::text), NEW.title);
  v_body := format('Mašina %s — %s (%s). Status: %s.',
    NEW.machine_code,
    NEW.title,
    NEW.severity,
    NEW.status);

  PERFORM public.maint_enqueue_notification(
    'whatsapp'::public.maint_notification_channel,
    NULL,                  -- recipient phone razrešava worker
    NULL,                  -- recipient_user_id razrešava worker
    v_subject,
    v_body,
    'maint_incident',
    NEW.id,
    NEW.machine_code,
    0,
    jsonb_build_object(
      'severity', NEW.severity,
      'reported_by', NEW.reported_by,
      'assigned_to', NEW.assigned_to
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS maint_incidents_enqueue_notify ON public.maint_incidents;
CREATE TRIGGER maint_incidents_enqueue_notify
  AFTER INSERT ON public.maint_incidents
  FOR EACH ROW
  EXECUTE FUNCTION public.maint_incidents_enqueue_notify();

COMMENT ON FUNCTION public.maint_incidents_enqueue_notify() IS
  'Pri kreiranju major/critical incidenta queue-uje stub red u maint_notification_log; recipient i kanal-specifični payload završava worker.';
