-- ── 2) loc_sync_alerts_outbox ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.loc_sync_alerts_outbox (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  kind              TEXT        NOT NULL
                      CHECK (kind IN ('worker_down', 'dead_letter_digest')),
  /* Dedup ključ — sprečava da isti alert ide više puta u istom periodu.
   * Npr. `worker_down:loc-sync-1:2026-05-15` ili
   * `dead_letter_digest:2026-05-15`. */
  dedup_key         TEXT        NOT NULL,
  recipient_email   TEXT        NOT NULL,
  subject           TEXT        NOT NULL,
  body_text         TEXT        NOT NULL,
  payload           JSONB,

  status            TEXT        NOT NULL DEFAULT 'queued'
                      CHECK (status IN ('queued', 'sent', 'failed', 'skipped')),
  scheduled_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  next_attempt_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_attempt_at   TIMESTAMPTZ,
  attempts          INT         NOT NULL DEFAULT 0,
  max_attempts      INT         NOT NULL DEFAULT 5,
  error             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at           TIMESTAMPTZ,

  CONSTRAINT loc_sync_alerts_dedup_uq UNIQUE (dedup_key, recipient_email)
);

COMMENT ON TABLE public.loc_sync_alerts_outbox IS
  'Outbox za sync monitor alerte (Härd-3). Edge funkcija loc-sync-monitor-dispatch '
  'čita queued/failed redove čiji next_attempt_at <= now() i šalje preko Resend.';

CREATE INDEX IF NOT EXISTS idx_loc_sync_alerts_queue
  ON public.loc_sync_alerts_outbox (status, next_attempt_at)
  WHERE status IN ('queued', 'failed');

ALTER TABLE public.loc_sync_alerts_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loc_sync_alerts_outbox FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS loc_sync_alerts_select ON public.loc_sync_alerts_outbox;
CREATE POLICY loc_sync_alerts_select ON public.loc_sync_alerts_outbox
  FOR SELECT TO authenticated USING (public.loc_is_admin());

-- ── 3) Heartbeat upsert (service_role only) ───────────────────────────────
CREATE OR REPLACE FUNCTION public.loc_sync_worker_heartbeat_upsert(
  p_worker_id TEXT,
  p_details   JSONB DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_hb$
BEGIN
  IF p_worker_id IS NULL OR length(trim(p_worker_id)) = 0 THEN
    RAISE EXCEPTION 'worker_id is required';
  END IF;

  INSERT INTO public.loc_sync_worker_heartbeat (worker_id, last_seen, details)
  VALUES (trim(p_worker_id), now(), p_details)
  ON CONFLICT (worker_id) DO UPDATE
     SET last_seen = excluded.last_seen,
         details   = excluded.details;
END;
$fn_hb$;

REVOKE ALL ON FUNCTION public.loc_sync_worker_heartbeat_upsert(TEXT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_sync_worker_heartbeat_upsert(TEXT, JSONB) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.loc_sync_worker_heartbeat_upsert(TEXT, JSONB) TO service_role;

-- ── 4) Admin email lista ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.loc_sync_admin_emails()
RETURNS TEXT[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
    array_agg(DISTINCT lower(trim(ur.email))) FILTER (
      WHERE ur.email IS NOT NULL AND ur.email <> ''
    ),
    ARRAY[]::text[]
  )
  FROM public.user_roles ur
  WHERE ur.is_active = true
    AND lower(ur.role::text) IN ('admin', 'menadzment');
$$;

REVOKE ALL ON FUNCTION public.loc_sync_admin_emails() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.loc_sync_admin_emails() TO service_role;

COMMENT ON FUNCTION public.loc_sync_admin_emails() IS
  'Lista email adresa korisnika sa ulogom admin ili menadzment (is_active=true). '
  'Härd-3: koristi se iz loc_sync_health_check_and_enqueue() za routing alerta.';

-- ── 5) UI helper: health summary ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.loc_sync_health_summary()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn_hs$
DECLARE
  v_dead_letter_count BIGINT;
  v_workers           JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('dead_letter_count', 0, 'workers', '[]'::jsonb);
  END IF;

  v_dead_letter_count := (
    SELECT count(*)
      FROM public.loc_sync_outbound_events
     WHERE status = 'DEAD_LETTER'
  );

  v_workers := coalesce((
    SELECT jsonb_agg(jsonb_build_object(
      'worker_id', h.worker_id,
      'last_seen', h.last_seen,
      'age_seconds', extract(epoch from (now() - h.last_seen))::int,
      'is_alive', (now() - h.last_seen) < interval '10 minutes',
      'details', h.details
    ) ORDER BY h.worker_id)
    FROM public.loc_sync_worker_heartbeat h
  ), '[]'::jsonb);

  RETURN jsonb_build_object(
    'dead_letter_count', v_dead_letter_count,
    'workers', v_workers
  );
END;
$fn_hs$;

GRANT EXECUTE ON FUNCTION public.loc_sync_health_summary() TO authenticated;

COMMENT ON FUNCTION public.loc_sync_health_summary() IS
  'Härd-3: pregled zdravlja sync queue-a za UI banner. Vraća DEAD_LETTER count '
  'i listu workera sa last_seen i is_alive (true ako je heartbeat u poslednjih 10 min).';

-- ── 6) Health check + enqueue alert-a (zove pg_cron) ─────────────────────
CREATE OR REPLACE FUNCTION public.loc_sync_health_check_and_enqueue()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_hc$
DECLARE
  v_admins        TEXT[];
  v_email         TEXT;
  v_today         TEXT := to_char(now(), 'YYYY-MM-DD');
  v_dead_count    BIGINT;
  v_dead_dedup    TEXT;
  v_inserted      INT := 0;
  v_worker        RECORD;
  v_w_dedup       TEXT;
BEGIN
  v_admins := public.loc_sync_admin_emails();
  IF cardinality(v_admins) = 0 THEN
    RETURN jsonb_build_object('skipped', 'no_admin_emails');
  END IF;

  /* (a) DEAD_LETTER digest — enqueue jednom dnevno ako ima stavki. */
  v_dead_count := (
    SELECT count(*) FROM public.loc_sync_outbound_events WHERE status = 'DEAD_LETTER'
  );

  IF v_dead_count > 0 THEN
    v_dead_dedup := 'dead_letter_digest:' || v_today;
    FOREACH v_email IN ARRAY v_admins LOOP
      INSERT INTO public.loc_sync_alerts_outbox (
        kind, dedup_key, recipient_email, subject, body_text, payload
      ) VALUES (
        'dead_letter_digest',
        v_dead_dedup,
        v_email,
        format('[Servoteh / Lokacije] %s sync događaja u DEAD_LETTER', v_dead_count),
        format(
          'U sync queue-u (loc_sync_outbound_events) trenutno ima %s događaja u stanju DEAD_LETTER. '
          'Ova premeštanja NISU stigla do MSSQL-a posle 10 pokušaja worker-a. '
          'Otvori Supabase Studio i pregledaj redove gde je status = DEAD_LETTER.',
          v_dead_count
        ),
        jsonb_build_object('dead_letter_count', v_dead_count, 'date', v_today)
      )
      ON CONFLICT (dedup_key, recipient_email) DO NOTHING;
      IF FOUND THEN v_inserted := v_inserted + 1; END IF;
    END LOOP;
  END IF;

  /* (b) Worker down — last_seen stariji od 10 min, enqueue jednom po danu po
   * worker_id, da admin ne bude spamovan svaki sat dok je worker stopiran. */
  FOR v_worker IN
    SELECT h.worker_id, h.last_seen
      FROM public.loc_sync_worker_heartbeat h
     WHERE (now() - h.last_seen) > interval '10 minutes'
  LOOP
    v_w_dedup := 'worker_down:' || v_worker.worker_id || ':' || v_today;
    FOREACH v_email IN ARRAY v_admins LOOP
      INSERT INTO public.loc_sync_alerts_outbox (
        kind, dedup_key, recipient_email, subject, body_text, payload
      ) VALUES (
        'worker_down',
        v_w_dedup,
        v_email,
        format('[Servoteh / Lokacije] Worker "%s" ne odgovara', v_worker.worker_id),
        format(
          'Worker "%s" nije poslao heartbeat od %s. '
          'Sve premeštanja se i dalje beleže u Supabase, ali NE idu MSSQL strani '
          'dok se worker ne restartuje.',
          v_worker.worker_id,
          to_char(v_worker.last_seen, 'YYYY-MM-DD HH24:MI:SS TZ')
        ),
        jsonb_build_object('worker_id', v_worker.worker_id, 'last_seen', v_worker.last_seen)
      )
      ON CONFLICT (dedup_key, recipient_email) DO NOTHING;
      IF FOUND THEN v_inserted := v_inserted + 1; END IF;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object(
    'dead_letter_count', v_dead_count,
    'alerts_enqueued', v_inserted,
    'admin_count', cardinality(v_admins)
  );
END;
$fn_hc$;

REVOKE ALL ON FUNCTION public.loc_sync_health_check_and_enqueue() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.loc_sync_health_check_and_enqueue() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.loc_sync_health_check_and_enqueue() TO service_role;

