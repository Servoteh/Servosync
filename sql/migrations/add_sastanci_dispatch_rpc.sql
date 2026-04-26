-- ============================================================================
-- SASTANCI — RPC-ovi za Edge worker `sastanci-notify-dispatch` (Faza C)
-- ============================================================================
-- Zavisi od `add_sastanci_notification_outbox.sql`.
--
-- Edge worker (Deno, service_role) zove:
--   • `sastanci_dispatch_dequeue(batch_size)` — uzme batch za slanje,
--      FOR UPDATE SKIP LOCKED, inkrementuje attempts, postavi last_attempt_at.
--      Ne vraća redove koji su dostigli max_attempts.
--   • `sastanci_dispatch_mark_sent(ids[])` — masovno 'sent'.
--   • `sastanci_dispatch_mark_failed(id, err, backoff_sec)` — 'failed' + backoff.
--
-- Sve funkcije: SECURITY DEFINER, dostupne SAMO service_role.
-- Idempotentno — bezbedno za re-run.
--
-- DOWN:
--   DROP FUNCTION IF EXISTS public.sastanci_dispatch_dequeue(int,int);
--   DROP FUNCTION IF EXISTS public.sastanci_dispatch_mark_sent(uuid[]);
--   DROP FUNCTION IF EXISTS public.sastanci_dispatch_mark_failed(uuid,text,int);
-- ============================================================================

-- ── 1) Dequeue ───────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sastanci_dispatch_dequeue(
  p_batch_size    INT DEFAULT 25,
  p_max_attempts  INT DEFAULT 5
)
RETURNS SETOF public.sastanci_notification_log
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN QUERY
  WITH picked AS (
    SELECT id
    FROM public.sastanci_notification_log
    WHERE status IN ('queued', 'failed')
      AND next_attempt_at <= now()
      AND attempts < p_max_attempts
    ORDER BY next_attempt_at ASC, created_at ASC
    LIMIT p_batch_size
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.sastanci_notification_log n
     SET attempts        = n.attempts + 1,
         last_attempt_at = now(),
         status          = 'queued'
    FROM picked p
   WHERE n.id = p.id
  RETURNING n.*;
END;
$$;

COMMENT ON FUNCTION public.sastanci_dispatch_dequeue(int, int) IS
  'Edge worker dequeue. Lock-uje red SKIP LOCKED, inkrementuje attempts, vraća red za slanje.';

-- ── 2) Mark-sent (batch) ─────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sastanci_dispatch_mark_sent(
  p_ids UUID[]
)
RETURNS INT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH upd AS (
    UPDATE public.sastanci_notification_log
       SET status  = 'sent',
           sent_at = now(),
           error   = NULL
     WHERE id = ANY (p_ids)
    RETURNING 1
  )
  SELECT count(*)::int FROM upd;
$$;

COMMENT ON FUNCTION public.sastanci_dispatch_mark_sent(uuid[]) IS
  'Batch mark-sent za Edge worker — zove se kad Resend API uspešno prihvati sve poruke u batchu.';

-- ── 3) Mark-failed sa exponential backoff-om ─────────────────────────────────

CREATE OR REPLACE FUNCTION public.sastanci_dispatch_mark_failed(
  p_id          UUID,
  p_error       TEXT,
  p_backoff_sec INT DEFAULT 60
)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  UPDATE public.sastanci_notification_log
     SET status          = 'failed',
         error           = left(coalesce(p_error, ''), 1000),
         next_attempt_at = now() + make_interval(secs => greatest(p_backoff_sec, 5))
   WHERE id = p_id;
$$;

COMMENT ON FUNCTION public.sastanci_dispatch_mark_failed(uuid, text, int) IS
  'Mark-failed + next_attempt_at za retry. Dequeue preskače red kad attempts >= max_attempts.';

-- ── 4) Dozvole: samo service_role ─────────────────────────────────────────────

REVOKE ALL ON FUNCTION public.sastanci_dispatch_dequeue(int, int)         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sastanci_dispatch_mark_sent(uuid[])          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sastanci_dispatch_mark_failed(uuid, text, int) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.sastanci_dispatch_dequeue(int, int)         TO service_role;
GRANT EXECUTE ON FUNCTION public.sastanci_dispatch_mark_sent(uuid[])          TO service_role;
GRANT EXECUTE ON FUNCTION public.sastanci_dispatch_mark_failed(uuid, text, int) TO service_role;

-- ── 5) Verifikacija ───────────────────────────────────────────────────────────

SELECT routine_name AS funkcija, 'OK' AS status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'sastanci_dispatch_dequeue',
    'sastanci_dispatch_mark_sent',
    'sastanci_dispatch_mark_failed'
  )
ORDER BY routine_name;
