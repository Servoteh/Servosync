-- ============================================================================
-- SASTANCI — pozivnice: reset meeting_invite pri brisanju učesnika
-- ============================================================================
-- Bulk zamena liste (saveUcesnici: DELETE ALL + INSERT) ostavlja stare redove
-- u sastanci_notification_log, pa idempotencija + uniq indeks sprečavaju novi
-- meeting_invite pri ponovnom dodavanju istog emaila. Brišemo log redove za taj
-- par (sastanak + email + kind) kada učesnik napusti listu.
--
-- Preduslov: add_sastanci_notification_outbox.sql, add_sastanci_notification_triggers.sql
-- Idempotentno.
-- DOWN:
--   DROP TRIGGER IF EXISTS sast_notif_ucesnik_invite_cleanup ON public.sastanak_ucesnici;
--   DROP FUNCTION IF EXISTS public.sast_trg_ucesnik_invite_cleanup();
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sast_trg_ucesnik_invite_cleanup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  DELETE FROM public.sastanci_notification_log
  WHERE kind = 'meeting_invite'
    AND related_sastanak_id = OLD.sastanak_id
    AND recipient_email = lower(OLD.email);
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS sast_notif_ucesnik_invite_cleanup ON public.sastanak_ucesnici;
CREATE TRIGGER sast_notif_ucesnik_invite_cleanup
  AFTER DELETE ON public.sastanak_ucesnici
  FOR EACH ROW
  EXECUTE FUNCTION public.sast_trg_ucesnik_invite_cleanup();

COMMENT ON FUNCTION public.sast_trg_ucesnik_invite_cleanup() IS
  'Briše meeting_invite outbox za uklonjenog učesnika da ponovno dodavanje '
  'može da enqueue-uje novu pozivnicu.';
