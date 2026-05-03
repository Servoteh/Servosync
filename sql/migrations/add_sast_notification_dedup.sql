-- ============================================================================
-- SASTANCI — notification dedup (Sprint 2 — H4)
-- ============================================================================
-- Sprečava duple queued/sent notifikacije za isti event + primaoca.
-- Ne menja stari add_sastanci_notification_triggers.sql in-place.
-- ============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS uniq_sast_notif_queued_per_event
ON public.sastanci_notification_log (kind, recipient_email, related_sastanak_id)
WHERE status IN ('queued', 'sent')
  AND related_akcija_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_sast_notif_queued_per_akcija
ON public.sastanci_notification_log (kind, recipient_email, related_akcija_id)
WHERE status IN ('queued', 'sent')
  AND related_akcija_id IS NOT NULL;

-- ─── Nova akcija → 'akcija_new' za odgovornog ────────────────────────────────

CREATE OR REPLACE FUNCTION public.sast_trg_akcija_new()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_recipient TEXT;
BEGIN
  IF NEW.odgovoran_email IS NULL OR trim(NEW.odgovoran_email) = '' THEN
    RETURN NEW;
  END IF;

  v_recipient := lower(NEW.odgovoran_email);

  IF EXISTS (
    SELECT 1
    FROM public.sastanci_notification_log
    WHERE kind = 'akcija_new'
      AND recipient_email = v_recipient
      AND related_akcija_id = NEW.id
      AND status IN ('queued', 'sent')
  ) THEN
    RETURN NEW;
  END IF;

  PERFORM public.sastanci_enqueue_notification(
    'akcija_new',
    'email',
    NEW.odgovoran_email,
    COALESCE(NEW.odgovoran_label, NEW.odgovoran_text, NEW.odgovoran_email),
    format('Nova akcija: %s', NEW.naslov),
    NULL,
    NULL,
    NEW.sastanak_id,
    NEW.id,
    jsonb_build_object(
      'akcija_id',     NEW.id,
      'naslov',        NEW.naslov,
      'opis',          NEW.opis,
      'rok',           NEW.rok,
      'rok_text',      NEW.rok_text,
      'prioritet',     NEW.prioritet,
      'sastanak_id',   NEW.sastanak_id,
      'odg_label',     COALESCE(NEW.odgovoran_label, NEW.odgovoran_text, NEW.odgovoran_email)
    ),
    NEW.created_by_email
  );

  RETURN NEW;
END;
$$;

-- ─── Promena akcije → 'akcija_changed' ili 'akcija_new' ─────────────────────

CREATE OR REPLACE FUNCTION public.sast_trg_akcija_changed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_odg_promenjen BOOLEAN;
  v_nesto_promenio BOOLEAN;
  v_kind TEXT;
  v_recipient TEXT;
BEGIN
  v_odg_promenjen := COALESCE(OLD.odgovoran_email, '') <> COALESCE(NEW.odgovoran_email, '');

  v_nesto_promenio :=
    v_odg_promenjen
    OR COALESCE(OLD.status, '') <> COALESCE(NEW.status, '')
    OR COALESCE(OLD.rok::TEXT, '') <> COALESCE(NEW.rok::TEXT, '')
    OR COALESCE(OLD.naslov, '') <> COALESCE(NEW.naslov, '');

  IF NOT v_nesto_promenio THEN
    RETURN NEW;
  END IF;

  IF NEW.odgovoran_email IS NULL OR trim(NEW.odgovoran_email) = '' THEN
    RETURN NEW;
  END IF;

  v_kind := CASE WHEN v_odg_promenjen THEN 'akcija_new' ELSE 'akcija_changed' END;
  v_recipient := lower(NEW.odgovoran_email);

  IF EXISTS (
    SELECT 1
    FROM public.sastanci_notification_log
    WHERE kind = v_kind
      AND recipient_email = v_recipient
      AND related_akcija_id = NEW.id
      AND status IN ('queued', 'sent')
  ) THEN
    RETURN NEW;
  END IF;

  IF v_odg_promenjen THEN
    PERFORM public.sastanci_enqueue_notification(
      'akcija_new',
      'email',
      NEW.odgovoran_email,
      COALESCE(NEW.odgovoran_label, NEW.odgovoran_text, NEW.odgovoran_email),
      format('Nova akcija (premeštena): %s', NEW.naslov),
      NULL,
      NULL,
      NEW.sastanak_id,
      NEW.id,
      jsonb_build_object(
        'akcija_id',     NEW.id,
        'naslov',        NEW.naslov,
        'rok',           NEW.rok,
        'rok_text',      NEW.rok_text,
        'prioritet',     NEW.prioritet,
        'status',        NEW.status,
        'sastanak_id',   NEW.sastanak_id,
        'odg_label',     COALESCE(NEW.odgovoran_label, NEW.odgovoran_text, NEW.odgovoran_email),
        'izmena',        'odgovoran_promenjen'
      ),
      NULL
    );
    RETURN NEW;
  END IF;

  PERFORM public.sastanci_enqueue_notification(
    'akcija_changed',
    'email',
    NEW.odgovoran_email,
    COALESCE(NEW.odgovoran_label, NEW.odgovoran_text, NEW.odgovoran_email),
    format('Akcija ažurirana: %s', NEW.naslov),
    NULL,
    NULL,
    NEW.sastanak_id,
    NEW.id,
    jsonb_build_object(
      'akcija_id',     NEW.id,
      'naslov',        NEW.naslov,
      'rok',           NEW.rok,
      'rok_text',      NEW.rok_text,
      'prioritet',     NEW.prioritet,
      'status_old',    OLD.status,
      'status_new',    NEW.status,
      'rok_old',       OLD.rok,
      'sastanak_id',   NEW.sastanak_id,
      'odg_label',     COALESCE(NEW.odgovoran_label, NEW.odgovoran_text, NEW.odgovoran_email)
    ),
    NULL
  );

  RETURN NEW;
END;
$$;

-- ─── Sastanak zakljucan → 'meeting_locked' za sve učesnike ─────────────────

CREATE OR REPLACE FUNCTION public.sast_trg_meeting_locked()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rec RECORD;
  v_recipient TEXT;
BEGIN
  IF NOT (OLD.status <> 'zakljucan' AND NEW.status = 'zakljucan') THEN
    RETURN NEW;
  END IF;

  FOR v_rec IN
    SELECT email, label
    FROM public.sastanak_ucesnici
    WHERE sastanak_id = NEW.id
  LOOP
    v_recipient := lower(v_rec.email);

    IF EXISTS (
      SELECT 1
      FROM public.sastanci_notification_log
      WHERE kind = 'meeting_locked'
        AND recipient_email = v_recipient
        AND related_sastanak_id = NEW.id
        AND related_akcija_id IS NULL
        AND status IN ('queued', 'sent')
    ) THEN
      CONTINUE;
    END IF;

    PERFORM public.sastanci_enqueue_notification(
      'meeting_locked',
      'email',
      v_rec.email,
      v_rec.label,
      format('Zapisnik: %s', NEW.naslov),
      NULL,
      NULL,
      NEW.id,
      NULL,
      jsonb_build_object(
        'sastanak_id',    NEW.id,
        'naslov',         NEW.naslov,
        'datum',          NEW.datum::TEXT,
        'vreme',          CASE WHEN NEW.vreme IS NOT NULL THEN left(NEW.vreme::TEXT, 5) ELSE NULL END,
        'tip',            NEW.tip,
        'zakljucan_at',   NEW.zakljucan_at,
        'zakljucan_by',   NEW.zakljucan_by_email,
        'organizator',    COALESCE(NEW.vodio_email, NEW.created_by_email)
      ),
      NEW.zakljucan_by_email
    );
  END LOOP;

  RETURN NEW;
END;
$$;

-- Vidi: docs/audit/sastanci-audit-2026-05-03.md H4
