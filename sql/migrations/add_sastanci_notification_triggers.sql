-- ============================================================================
-- SASTANCI — DB triggeri za enqueue notifikacija (Faza C)
-- ============================================================================
-- Šta dodaje (4 trigger funkcije + 4 triggera):
--
--   A) akcioni_plan AFTER INSERT
--      → 'akcija_new' za odgovoran_email (ako postoji)
--
--   B) akcioni_plan AFTER UPDATE
--      → ako se promenio (status, rok, odgovoran_email, naslov):
--        * ako je odgovoran_email promenjen na novog → 'akcija_new' za novog
--        * inače → 'akcija_changed' za odgovornog
--
--   C) sastanci AFTER UPDATE — status promenjeno u 'zakljucan'
--      → 'meeting_locked' za SVE učesnike (JOIN sastanak_ucesnici)
--
--   D) sastanak_ucesnici AFTER INSERT — parent sastanak je 'planiran'
--      → 'meeting_invite' za novog učesnika
--      (idempotent: ne šalje ako već postoji queued/sent za isti par)
--
-- Preduslov: `add_sastanci_notification_outbox.sql` primenjen.
--
-- Sve funkcije SECURITY DEFINER, SET search_path = public, pg_temp.
-- Idempotentno — bezbedno za re-run.
--
-- DOWN:
--   DROP TRIGGER IF EXISTS sast_notif_akcija_new    ON public.akcioni_plan;
--   DROP TRIGGER IF EXISTS sast_notif_akcija_changed ON public.akcioni_plan;
--   DROP TRIGGER IF EXISTS sast_notif_meeting_locked ON public.sastanci;
--   DROP TRIGGER IF EXISTS sast_notif_ucesnik_invite ON public.sastanak_ucesnici;
--   DROP FUNCTION IF EXISTS public.sast_trg_akcija_new();
--   DROP FUNCTION IF EXISTS public.sast_trg_akcija_changed();
--   DROP FUNCTION IF EXISTS public.sast_trg_meeting_locked();
--   DROP FUNCTION IF EXISTS public.sast_trg_ucesnik_invite();
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- A) Nova akcija → 'akcija_new' za odgovornog
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sast_trg_akcija_new()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Ne slati ako nema odgovornog
  IF NEW.odgovoran_email IS NULL OR trim(NEW.odgovoran_email) = '' THEN
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

DROP TRIGGER IF EXISTS sast_notif_akcija_new ON public.akcioni_plan;
CREATE TRIGGER sast_notif_akcija_new
  AFTER INSERT ON public.akcioni_plan
  FOR EACH ROW
  EXECUTE FUNCTION public.sast_trg_akcija_new();

COMMENT ON FUNCTION public.sast_trg_akcija_new() IS
  'Pri kreiranju akcije enqueue-uje akcija_new notifikaciju za odgovornog.';

-- ────────────────────────────────────────────────────────────────────────────
-- B) Promena akcije → 'akcija_changed' ili 'akcija_new' za novog odgovornog
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sast_trg_akcija_changed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_odg_promenjen BOOLEAN;
  v_nesto_promenio BOOLEAN;
BEGIN
  -- Proveravamo relevantna polja
  v_odg_promenjen := COALESCE(OLD.odgovoran_email, '') <> COALESCE(NEW.odgovoran_email, '');

  v_nesto_promenio :=
    v_odg_promenjen
    OR COALESCE(OLD.status, '') <> COALESCE(NEW.status, '')
    OR COALESCE(OLD.rok::TEXT, '') <> COALESCE(NEW.rok::TEXT, '')
    OR COALESCE(OLD.naslov, '') <> COALESCE(NEW.naslov, '');

  IF NOT v_nesto_promenio THEN
    RETURN NEW;
  END IF;

  -- Ako je odgovoran promenjen → šalji 'akcija_new' novom odgovornom
  IF v_odg_promenjen AND NEW.odgovoran_email IS NOT NULL AND trim(NEW.odgovoran_email) <> '' THEN
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

  -- Inače → 'akcija_changed' za trenutnog odgovornog
  IF NEW.odgovoran_email IS NOT NULL AND trim(NEW.odgovoran_email) <> '' THEN
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
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sast_notif_akcija_changed ON public.akcioni_plan;
CREATE TRIGGER sast_notif_akcija_changed
  AFTER UPDATE OF status, rok, odgovoran_email, naslov ON public.akcioni_plan
  FOR EACH ROW
  EXECUTE FUNCTION public.sast_trg_akcija_changed();

COMMENT ON FUNCTION public.sast_trg_akcija_changed() IS
  'Pri promeni akcije (status/rok/odg/naslov) enqueue-uje akcija_changed '
  'ili akcija_new (ako je promenjen odgovoran) notifikaciju.';

-- ────────────────────────────────────────────────────────────────────────────
-- C) Sastanak zaključan → 'meeting_locked' za sve učesnike
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sast_trg_meeting_locked()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rec RECORD;
BEGIN
  -- Samo ako status prelazi na 'zakljucan'
  IF NOT (OLD.status <> 'zakljucan' AND NEW.status = 'zakljucan') THEN
    RETURN NEW;
  END IF;

  -- Enqueue za svakog učesnika
  FOR v_rec IN
    SELECT email, label
    FROM public.sastanak_ucesnici
    WHERE sastanak_id = NEW.id
  LOOP
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

DROP TRIGGER IF EXISTS sast_notif_meeting_locked ON public.sastanci;
CREATE TRIGGER sast_notif_meeting_locked
  AFTER UPDATE OF status ON public.sastanci
  FOR EACH ROW
  EXECUTE FUNCTION public.sast_trg_meeting_locked();

COMMENT ON FUNCTION public.sast_trg_meeting_locked() IS
  'Kad se sastanak zaključa, enqueue-uje meeting_locked za sve učesnike.';

-- ────────────────────────────────────────────────────────────────────────────
-- D) Novi učesnik → 'meeting_invite' (ako je sastanak planiran)
--    Idempotent: ne šalje ako već postoji queued/sent za isti par
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sast_trg_ucesnik_invite()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sast  public.sastanci%ROWTYPE;
  v_dupl  BOOLEAN;
BEGIN
  -- Učitaj parent sastanak
  SELECT * INTO v_sast
  FROM public.sastanci
  WHERE id = NEW.sastanak_id;

  -- Šalji pozivnicu samo za 'planiran' (ne za u_toku, zakljucan itd.)
  IF v_sast.status <> 'planiran' THEN
    RETURN NEW;
  END IF;

  -- Idempotent check — ne dupliraj ako već ima queued/sent za ovaj par
  SELECT EXISTS (
    SELECT 1
    FROM public.sastanci_notification_log
    WHERE kind = 'meeting_invite'
      AND recipient_email = lower(NEW.email)
      AND related_sastanak_id = NEW.sastanak_id
      AND status IN ('queued', 'sent')
  ) INTO v_dupl;

  IF v_dupl THEN
    RETURN NEW;
  END IF;

  PERFORM public.sastanci_enqueue_notification(
    'meeting_invite',
    'email',
    NEW.email,
    NEW.label,
    format('Pozivnica: %s — %s',
           v_sast.naslov,
           to_char(v_sast.datum, 'DD.MM.YYYY')),
    NULL,
    NULL,
    NEW.sastanak_id,
    NULL,
    jsonb_build_object(
      'sastanak_id',   v_sast.id,
      'naslov',        v_sast.naslov,
      'datum',         v_sast.datum::TEXT,
      'vreme',         CASE WHEN v_sast.vreme IS NOT NULL THEN left(v_sast.vreme::TEXT, 5) ELSE NULL END,
      'mesto',         v_sast.mesto,
      'tip',           v_sast.tip,
      'organizator',   COALESCE(v_sast.vodio_email, v_sast.created_by_email)
    ),
    NULL
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sast_notif_ucesnik_invite ON public.sastanak_ucesnici;
CREATE TRIGGER sast_notif_ucesnik_invite
  AFTER INSERT ON public.sastanak_ucesnici
  FOR EACH ROW
  EXECUTE FUNCTION public.sast_trg_ucesnik_invite();

COMMENT ON FUNCTION public.sast_trg_ucesnik_invite() IS
  'Kad se doda učesnik na planiran sastanak, šalje mu meeting_invite. '
  'Idempotent — preskače ako queued/sent već postoji za taj par.';

-- ── Verifikacija ──────────────────────────────────────────────────────────────

SELECT routine_name AS funkcija, 'OK' AS status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'sast_trg_akcija_new', 'sast_trg_akcija_changed',
    'sast_trg_meeting_locked', 'sast_trg_ucesnik_invite'
  )
ORDER BY routine_name;
