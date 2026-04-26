-- ============================================================================
-- SASTANCI — reminder funkcije + pg_cron jobovi (Faza C)
-- ============================================================================
-- Šta dodaje:
--   1) `sastanci_enqueue_action_reminders()`
--      Svaki dan u 07:00 UTC: za svaku otvorenu akciju kojoj rok ističe za
--      TAČNO 1 dan (ili je već prošao ≤ 2 dana) → 'action_reminder' za odgovornog.
--      Idempotent: preskoči ako već postoji queued/sent za isti (akcija, dan).
--
--   2) `sastanci_enqueue_meeting_reminders()`
--      Svakih 30 min: za svaki planiran/u_toku sastanak koji počinje za
--      15–45 minuta → 'meeting_reminder' za svakog učesnika.
--      Idempotent: preskoči ako već postoji queued/sent za isti (sastanak, ucesnik, sat).
--
--   3) pg_cron job 'sast_action_reminders_daily'   → '0 7 * * *'
--   4) pg_cron job 'sast_meeting_reminders_30min'  → '*/30 * * * *'
--
-- Preduslov: `add_sastanci_notification_outbox.sql` primenjen.
--            pg_cron dostupan (Supabase PAID tier).
--
-- Idempotentno — bezbedno za re-run.
--
-- DOWN:
--   SELECT cron.unschedule('sast_action_reminders_daily');
--   SELECT cron.unschedule('sast_meeting_reminders_30min');
--   DROP FUNCTION IF EXISTS public.sastanci_enqueue_action_reminders();
--   DROP FUNCTION IF EXISTS public.sastanci_enqueue_meeting_reminders();
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- ── 1) Action reminders — dnevni (07:00 UTC) ─────────────────────────────────
--
-- Logika: akcija je "otvorena" (status IN ('otvoren','u_toku','kasni')) i
--   - rok = today+1 (dan pre roka)       → standardni reminder
--   - rok BETWEEN today-2 AND today-1    → kasni reminder (prešao rok)
-- Idempotent: ne šalje ako već postoji queued/sent za isti (akcija_id, dan).

CREATE OR REPLACE FUNCTION public.sastanci_enqueue_action_reminders()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rec    RECORD;
  v_today  DATE := current_date;
  v_dupl   BOOLEAN;
  v_cnt    INT := 0;
BEGIN
  FOR v_rec IN
    SELECT a.id,
           a.naslov,
           a.rok,
           a.rok_text,
           a.prioritet,
           a.sastanak_id,
           a.odgovoran_email,
           COALESCE(a.odgovoran_label, a.odgovoran_text, a.odgovoran_email) AS odg_label
    FROM public.akcioni_plan a
    WHERE a.status IN ('otvoren', 'u_toku', 'kasni')
      AND a.odgovoran_email IS NOT NULL
      AND trim(a.odgovoran_email) <> ''
      AND a.rok IS NOT NULL
      AND a.rok BETWEEN (v_today - 2) AND (v_today + 1)
  LOOP
    -- Idempotent: jedan reminder po akciji po danu
    SELECT EXISTS (
      SELECT 1
      FROM public.sastanci_notification_log
      WHERE kind = 'action_reminder'
        AND recipient_email = lower(v_rec.odgovoran_email)
        AND related_akcija_id = v_rec.id
        AND status IN ('queued', 'sent')
        AND created_at >= (now() - INTERVAL '20 hours')
    ) INTO v_dupl;

    IF v_dupl THEN
      CONTINUE;
    END IF;

    PERFORM public.sastanci_enqueue_notification(
      'action_reminder',
      'email',
      v_rec.odgovoran_email,
      v_rec.odg_label,
      CASE
        WHEN v_rec.rok < v_today
          THEN format('Akcija kasni: %s (rok bio %s)', v_rec.naslov, to_char(v_rec.rok, 'DD.MM.YYYY'))
        WHEN v_rec.rok = v_today
          THEN format('Rok danas: %s', v_rec.naslov)
        ELSE format('Rok sutra: %s', v_rec.naslov)
      END,
      NULL,
      NULL,
      v_rec.sastanak_id,
      v_rec.id,
      jsonb_build_object(
        'akcija_id',   v_rec.id,
        'naslov',      v_rec.naslov,
        'rok',         v_rec.rok,
        'rok_text',    v_rec.rok_text,
        'prioritet',   v_rec.prioritet,
        'sastanak_id', v_rec.sastanak_id,
        'odg_label',   v_rec.odg_label,
        'reminder_for', v_today::TEXT
      ),
      NULL
    );

    v_cnt := v_cnt + 1;
  END LOOP;

  RETURN v_cnt;
END;
$$;

COMMENT ON FUNCTION public.sastanci_enqueue_action_reminders() IS
  'Dnevni cron: enqueue action_reminder za sve otvorene akcije kojima rok ističe sutra '
  'ili je već prošao ≤ 2 dana. Idempotent — jedan reminder po akciji po danu.';

REVOKE ALL    ON FUNCTION public.sastanci_enqueue_action_reminders() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sastanci_enqueue_action_reminders() TO service_role;

-- ── 2) Meeting reminders — svake 30 min ──────────────────────────────────────
--
-- Logika: sastanak je 'planiran' i datum+vreme pada u prozor [now()+15min, now()+45min].
-- Idempotent: preskoči ako već postoji queued/sent za isti (sastanak, ucesnik)
--             kreiran u poslednjih 60 min (jedan sat = dva 30-min okidanja).

CREATE OR REPLACE FUNCTION public.sastanci_enqueue_meeting_reminders()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rec   RECORD;
  v_ucr   RECORD;
  v_dupl  BOOLEAN;
  v_cnt   INT := 0;
  v_start TIMESTAMPTZ;
BEGIN
  FOR v_rec IN
    SELECT s.id,
           s.naslov,
           s.datum,
           s.vreme,
           s.mesto,
           s.tip,
           COALESCE(s.vodio_email, s.created_by_email) AS organizator,
           (s.datum + COALESCE(s.vreme, '09:00'::TIME))::TIMESTAMPTZ AS starts_at
    FROM public.sastanci s
    WHERE s.status = 'planiran'
      AND s.datum IS NOT NULL
      AND s.vreme IS NOT NULL
  LOOP
    -- Prozor: između 15 i 45 minuta od sada
    IF v_rec.starts_at NOT BETWEEN (now() + INTERVAL '15 minutes')
                                AND (now() + INTERVAL '45 minutes') THEN
      CONTINUE;
    END IF;

    -- Enqueue za svakog učesnika
    FOR v_ucr IN
      SELECT email, label
      FROM public.sastanak_ucesnici
      WHERE sastanak_id = v_rec.id
    LOOP
      -- Idempotent: jedan reminder po sastanku po učesniku u poslednjih sat vremena
      SELECT EXISTS (
        SELECT 1
        FROM public.sastanci_notification_log
        WHERE kind = 'meeting_reminder'
          AND recipient_email = lower(v_ucr.email)
          AND related_sastanak_id = v_rec.id
          AND status IN ('queued', 'sent')
          AND created_at >= (now() - INTERVAL '1 hour')
      ) INTO v_dupl;

      IF v_dupl THEN
        CONTINUE;
      END IF;

      PERFORM public.sastanci_enqueue_notification(
        'meeting_reminder',
        'email',
        v_ucr.email,
        v_ucr.label,
        format('Podsetnik: %s — %s u %s',
               v_rec.naslov,
               to_char(v_rec.datum, 'DD.MM.YYYY'),
               left(v_rec.vreme::TEXT, 5)),
        NULL,
        NULL,
        v_rec.id,
        NULL,
        jsonb_build_object(
          'sastanak_id',  v_rec.id,
          'naslov',       v_rec.naslov,
          'datum',        v_rec.datum::TEXT,
          'vreme',        left(v_rec.vreme::TEXT, 5),
          'mesto',        v_rec.mesto,
          'tip',          v_rec.tip,
          'organizator',  v_rec.organizator,
          'starts_at',    v_rec.starts_at::TEXT
        ),
        NULL
      );

      v_cnt := v_cnt + 1;
    END LOOP;
  END LOOP;

  RETURN v_cnt;
END;
$$;

COMMENT ON FUNCTION public.sastanci_enqueue_meeting_reminders() IS
  'Svake 30 min: enqueue meeting_reminder za sve učesnike sastanka koji počinje '
  'za 15–45 min. Idempotent — jedan reminder po paru (sastanak, učesnik) po satu.';

REVOKE ALL    ON FUNCTION public.sastanci_enqueue_meeting_reminders() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sastanci_enqueue_meeting_reminders() TO service_role;

-- ── 3) pg_cron — dnevni job za akcione remindere (07:00 UTC) ─────────────────

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'sast_action_reminders_daily') THEN
    PERFORM cron.unschedule('sast_action_reminders_daily');
  END IF;
EXCEPTION
  WHEN undefined_table       THEN NULL;
  WHEN insufficient_privilege THEN NULL;
END $$;

SELECT cron.schedule(
  'sast_action_reminders_daily',
  '0 7 * * *',
  $cron$SELECT public.sastanci_enqueue_action_reminders()$cron$
);

-- ── 4) pg_cron — svaki 30 min za meeting remindere ────────────────────────────

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'sast_meeting_reminders_30min') THEN
    PERFORM cron.unschedule('sast_meeting_reminders_30min');
  END IF;
EXCEPTION
  WHEN undefined_table       THEN NULL;
  WHEN insufficient_privilege THEN NULL;
END $$;

SELECT cron.schedule(
  'sast_meeting_reminders_30min',
  '*/30 * * * *',
  $cron$SELECT public.sastanci_enqueue_meeting_reminders()$cron$
);

-- ── 5) Verifikacija ───────────────────────────────────────────────────────────

SELECT jobname, schedule, active
FROM cron.job
WHERE jobname IN ('sast_action_reminders_daily', 'sast_meeting_reminders_30min')
ORDER BY jobname;
