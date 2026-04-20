-- ============================================================================
-- ODRŽAVANJE — RPC-ovi za Edge worker `maint-notify-dispatch`
-- ============================================================================
-- Zavisi od `add_maint_notification_outbox.sql` (outbox kolone + enqueue fn).
--
-- Ovi RPC-ovi su SECURITY DEFINER i dostupni SAMO `service_role`-u. Edge
-- funkcija (Deno) koja se autentifikuje service_role ključem zove:
--
--   • `maint_dispatch_dequeue(batch_size)`  — uzme batch za slanje (lock-uje
--      `FOR UPDATE SKIP LOCKED`, inkrementuje `attempts`, postavi
--      `last_attempt_at`). Ne vraća redove koji su prešli `p_max_attempts`.
--   • `maint_dispatch_fanout(parent_id)`    — za stub red (recipient='pending',
--      recipient_user_id IS NULL) kreira child redove po relevantnim
--      primaocima iz `maint_user_profiles` i parent obeleži kao 'sent'
--      sa error='FANOUT_DONE' (revizioni trag).
--   • `maint_dispatch_mark_sent(ids uuid[])` — masovno obeležavanje 'sent'.
--   • `maint_dispatch_mark_failed(id, err, backoff_sec)` — 'failed' + backoff.
--
-- Pokreni u Supabase SQL Editoru. Idempotentno.
--
-- DOWN (ručno):
--   DROP FUNCTION IF EXISTS public.maint_dispatch_dequeue(int,int);
--   DROP FUNCTION IF EXISTS public.maint_dispatch_fanout(uuid);
--   DROP FUNCTION IF EXISTS public.maint_dispatch_mark_sent(uuid[]);
--   DROP FUNCTION IF EXISTS public.maint_dispatch_mark_failed(uuid,text,int);
-- ============================================================================

-- 1) Dequeue — bira red za slanje (jedan/više), lock-uje SKIP LOCKED, beleži pokušaj.
CREATE OR REPLACE FUNCTION public.maint_dispatch_dequeue(
  p_batch_size    INT DEFAULT 25,
  p_max_attempts  INT DEFAULT 8
)
RETURNS SETOF public.maint_notification_log
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH picked AS (
    SELECT id
    FROM public.maint_notification_log
    WHERE status IN ('queued', 'failed')
      AND next_attempt_at <= now()
      AND attempts < p_max_attempts
    ORDER BY next_attempt_at ASC, created_at ASC
    LIMIT p_batch_size
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.maint_notification_log n
     SET attempts        = n.attempts + 1,
         last_attempt_at = now(),
         status          = 'queued'   -- worker će kasnije markirati sent/failed
   FROM picked p
   WHERE n.id = p.id
  RETURNING n.*;
END;
$$;

COMMENT ON FUNCTION public.maint_dispatch_dequeue(int, int) IS
  'Edge worker dequeue. Lock-uje red, inkrementuje attempts, vraća red za slanje.';

-- 2) Fanout — stub red (recipient=pending, recipient_user_id NULL) raspisuje
--    na konkretne primaoce (chief/management profili sa `phone`).
--    Pravila eskalacije (escalation_level):
--      • severity=critical  → šalje se i chief-u i management-u.
--      • severity=major     → samo chief-u.
--      • severity<major     → trigger ionako ne kreira stub (vidi
--        `maint_incidents_enqueue_notify`).
/* Fanout u pure SQL CTE-ima — izbegava plpgsql parser edge-case
   gde `SELECT ... INTO v_x FOR UPDATE` ume da prijavi 42P01
   ("relation v_x does not exist") za INTO varijable.
   Writable CTE se uvek izvršava (side effects), čak i ako nije u finalnom SELECT. */
CREATE OR REPLACE FUNCTION public.maint_dispatch_fanout(
  p_parent_id UUID
)
RETURNS INT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH parent AS (
    SELECT *
      FROM public.maint_notification_log
     WHERE id = p_parent_id
  ),
  targets AS (
    SELECT p.user_id, p.full_name, p.phone
      FROM public.maint_user_profiles p, parent
     WHERE p.active = true
       AND p.role::text = ANY (
         CASE WHEN (parent.payload->>'severity') = 'critical'
              THEN ARRAY['chief', 'management']
              ELSE ARRAY['chief']
         END
       )
       AND p.phone IS NOT NULL
       AND p.phone <> ''
  ),
  inserted AS (
    INSERT INTO public.maint_notification_log (
      channel, recipient, recipient_user_id, subject, body,
      related_entity_type, related_entity_id, machine_code,
      escalation_level, status, scheduled_at, next_attempt_at, payload
    )
    SELECT
      parent.channel, t.phone, t.user_id, parent.subject, parent.body,
      parent.related_entity_type, parent.related_entity_id, parent.machine_code,
      parent.escalation_level, 'queued', now(), now(),
      coalesce(parent.payload, '{}'::jsonb)
        || jsonb_build_object('fanout_parent', parent.id, 'to_name', t.full_name)
      FROM parent, targets t
    RETURNING 1
  ),
  cnt AS (
    SELECT count(*)::int AS c FROM inserted
  ),
  upd AS (
    UPDATE public.maint_notification_log
       SET status  = 'sent',
           sent_at = now(),
           error   = format('FANOUT_DONE: %s recipients', (SELECT c FROM cnt))
     WHERE id = p_parent_id
       AND EXISTS (SELECT 1 FROM parent)
    RETURNING 1
  )
  SELECT coalesce((SELECT c FROM cnt), 0);
$$;

COMMENT ON FUNCTION public.maint_dispatch_fanout(uuid) IS
  'Fan-out stub reda na pojedinačne primaoce po ulogama iz payload.severity.';

-- 3) Masovno mark-sent (kad HTTP poziv prođe).
CREATE OR REPLACE FUNCTION public.maint_dispatch_mark_sent(
  p_ids UUID[]
)
RETURNS INT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH upd AS (
    UPDATE public.maint_notification_log
       SET status  = 'sent',
           sent_at = now(),
           error   = NULL
     WHERE id = ANY (p_ids)
    RETURNING 1
  )
  SELECT count(*)::int FROM upd;
$$;

COMMENT ON FUNCTION public.maint_dispatch_mark_sent(uuid[]) IS
  'Batch mark-sent za Edge worker.';

-- 4) Mark-failed sa exponential backoff-om. Worker određuje `backoff_sec`.
CREATE OR REPLACE FUNCTION public.maint_dispatch_mark_failed(
  p_id          UUID,
  p_error       TEXT,
  p_backoff_sec INT DEFAULT 60
)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.maint_notification_log
     SET status          = 'failed',
         error           = left(coalesce(p_error, ''), 1000),
         next_attempt_at = now() + make_interval(secs => greatest(p_backoff_sec, 5))
   WHERE id = p_id;
$$;

COMMENT ON FUNCTION public.maint_dispatch_mark_failed(uuid, text, int) IS
  'Mark-failed + next_attempt_at za retry. Dequeue će preskočiti ako attempts>=max.';

-- 5) Dozvole: svi dispatch RPC-ovi su samo za service_role.
REVOKE ALL ON FUNCTION public.maint_dispatch_dequeue(int,int)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.maint_dispatch_fanout(uuid)            FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.maint_dispatch_mark_sent(uuid[])       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.maint_dispatch_mark_failed(uuid,text,int) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.maint_dispatch_dequeue(int,int)        TO service_role;
GRANT EXECUTE ON FUNCTION public.maint_dispatch_fanout(uuid)            TO service_role;
GRANT EXECUTE ON FUNCTION public.maint_dispatch_mark_sent(uuid[])       TO service_role;
GRANT EXECUTE ON FUNCTION public.maint_dispatch_mark_failed(uuid,text,int) TO service_role;
